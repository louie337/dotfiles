---
name: foreman
description: >-
  Foreman mode — orchestrate a long, high-rigor migration or refactor as a PM who never
  writes code. Spawn isolated `claude -p` workers in tmux (fresh context each, not the Agent
  tool), run a SERIALIZED diff→QA→fix loop with one commit per feature on a shared branch, and
  gate every commit behind an independent adversarial QA worker that re-runs everything with
  runtime evidence before the next launches. Asks the user which model to run workers on before
  starting; keeps a living progress checklist + a decision log throughout; and gates the merge
  behind an HTML report + comprehension quiz the user must pass. Use when the work is too large
  for one context, must stay green at every commit, and correctness matters more than speed
  (engine swaps, chunk→new-engine migrations, "crush the legacy path" deletions, anything where
  a silent data-loss bug is unacceptable). Triggers: "be the PM", "orchestrate this", "run isolated workers",
  "diff agent + QA agent", "one commit per feature", "keep momentum", or a plan with a
  commit-by-commit execution table. NOT for independent-feature fan-out (use `mission`) or
  single-context tasks.
metadata:
  author: subanana
  origin: subtitle-editor Loro unification (37 commits, 2026-07)
---

# Foreman Mode

You are the PM. You launch tasks, assign a diff agent, assign a QA agent, keep momentum. You do
**not** write code, run tests, or edit files yourself — every unit of work goes to an isolated
worker. Your job is the loop, the briefs, the rulings, and the report-reading.

Distinct from `mission`: mission fans out independent features via the Agent tool and workers
self-validate. Foreman **serializes** commit-per-feature on ONE shared branch and gates each
behind a **separate QA worker** that distrusts the diff report. Reach for foreman when every
commit must be independently verifiable and the branch must never go red.

## STEP 0: pin the worker model(s) — ask before launching anything

Do NOT assume a model. Before the first worker, ask the user which model to run workers on —
and whether diff/impl and QA/review should differ (a common split: a stronger model for diff,
a faster one for QA; or all-one-model). Offer the choices (AskUserQuestion), record the answer,
and put `--model <x>` in every launch. If the user changes it mid-run, apply from the next
launch; never kill a worker mid-commit to swap models. (This run flip-flopped opus↔fable before
settling on all-opus — asking up front avoids the churn.)

**Default allocation** (offer as the recommended option; user can override):

| Worker task type | Model |
|---|---|
| Resource-related (discovery, search, gathering) | Sonnet |
| Coding (diff/impl workers, fix workers) | Opus |
| Execution (builds, tests, mechanical steps) | Sonnet |
| QA / review (adversarial QA workers) | Opus |
| Design / analysis (planning, root-cause) | Fable 5 if available, else Opus |

## Two living docs (create both at STEP 0, before the first worker)

Under the PM scratch dir (`/tmp/pm-<slug>/`), maintain two files for the whole run:

1. **`progress.md` — the checklist.** One row per planned commit: `status` (pending /
   in_progress / QA / fix / done), the SHA once landed, the QA verdict, and a one-line result.
   The PM owns the header/structure. **Every worker brief carries a mandatory final step: "update
   your row in `/tmp/pm-<slug>/progress.md` before you finish — set status + SHA + a one-line
   result."** For robustness, also wire a Stop hook in the worker's `--setting-sources` scope that
   appends its status, so a worker that forgets still records. This doc is the always-current
   source of truth — a resumed or crashed PM reads it to know exactly where the run is.
2. **`implementation-notes.md` (or `.html`) — the decision log.** The *why*, not the status.
   The PM appends to it at every ruling, discovery, STOP-report, scope change, and dead-end:
   what was decided, the alternatives rejected, and the reason. This is what a *next attempt*
   reads to avoid re-deriving the same calls. Keep it chronological and blunt ("A1 cancelled:
   server must never author ops — rejected the sidecar-append design; corrections go client-side").

## Why isolated `claude -p`, not the Agent tool

Each worker gets a genuinely fresh context window, so a 30-commit migration never bloats the
PM's context — you read one-page reports, never worker transcripts. Workers commit to the real
branch, so QA reviews real commits with real `git show`. The cost: you manage tmux + watchers
yourself (below).

## The loop (per commit)

```
brief → diff worker → (commit + report) → QA worker → VERDICT
  PASS → next commit
  FAIL → fix worker (QA's findings) → re-QA → PASS
```

One committing worker at a time. NEVER two in parallel on the shared branch — a `--amend` or
a concurrent commit entangles even non-overlapping files. Serialize dependent slices; only use
`isolation:"worktree"` for genuinely independent parallel ones.

## Launch mechanics (learned the hard way)

Model split per the user's call (this run used opus for all; earlier diff=opus/QA=fable).

Two launch engines — both respawn a tmux window per worker slot and both signal completion
with an `EXIT:` sentinel appended to the report file, so the completion-poll below is identical
either way. Pick per the quota situation:

### Engine A — headless `claude -p` (default)

```bash
# respawn-window -k with a DIRECT pane command — NOT send-keys, because the -p command reads the
# brief from stdin at launch (send-keys would drop the Enter during shell init).
tmux respawn-window -k -t pm:<slot> \
  "/opt/homebrew/bin/claude -p --model opus --dangerously-skip-permissions \
   --setting-sources project,local < /tmp/pm/prompts/<x>.md \
   > /tmp/pm/reports/<x>.out 2>&1; echo EXIT:\$? >> /tmp/pm/reports/<x>.out; sleep 86400"
```

Fresh context per slice, full stdout captured to the report file, rock-solid `EXIT:$?`. The one
liability: headless `-p` draws on a quota pool that can hit a **weekly** limit (distinct from the
hourly/session limit) — when it does, every `-p` worker dies instantly on launch (`EXIT:1`,
"weekly limit … resets <date>"), blocked until reset or an account switch. Interactive sessions
survive that block, which is why Engine B exists.

### Engine B — interactive `claude` driven by `send-keys` (quota-resilient)

When the `-p` pool is weekly-blocked (or you just want to ride the interactive quota), launch an
INTERACTIVE claude in the window and feed it a SHORT send-keys instruction that tells it to read
its brief file and self-write the sentinel. send-keys of a huge multi-line prompt into a TUI is
fragile — keep the typed instruction to one line and let the worker Read the brief itself.

```bash
# per slice: respawn interactive claude (no -p), wait for TUI init, type instruction, THEN Enter
# separately (the reliable send-keys pattern), then poll the same EXIT: sentinel.
tmux respawn-window -k -c <worktree> -t pm:<slot> \
  "/opt/homebrew/bin/claude --model opus --dangerously-skip-permissions --setting-sources project,local; sleep 86400"
sleep 14   # TUI must be ready before typing, or keys are dropped
tmux send-keys -t pm:<slot> "Read /tmp/pm/prompts/<x>.md in full and execute EVERY step. Write your full report to /tmp/pm/reports/<x>.out via Bash, and as your ABSOLUTE FINAL action append a line EXIT:0 to it (echo EXIT:0 >> /tmp/pm/reports/<x>.out)."
sleep 2
tmux send-keys -t pm:<slot> Enter
```

- Fresh context per slice (the window is respawned each time — do NOT reuse one session across
  slices; it accumulates every slice's transcript and defeats the whole fresh-context point).
- The worker self-writes the `EXIT:` sentinel via its final Bash call → completion detection is
  unchanged. Verdicts/progress rows already go to files, so losing auto-stdout-capture is fine
  (have the worker tee its report to the .out file as the instruction says).
- Wrap it in a tiny launcher script (`sk-launch.sh <slot> <worktree> <brief-basename>`) so you
  don't hand-type the send-keys dance each slice. Validate the mechanism once on a spare window
  (send a no-op that writes a sentinel) before trusting it for real work.

### Both engines

- **Absolute** claude path (aliases don't resolve in respawn — `command -v claude` returns the
  user's alias text, not a path). Verify cwd is the worktree (`lsof -p <child> | awk '$4=="cwd"'`)
  after every launch — a dropped inline `cd` or wrong `-c` loads the wrong project context.
- `--setting-sources project,local` so the worker inherits repo CLAUDE.md + hooks (also avoids a
  headless agent firing the parent's Stop hooks).
- Watch for completion with a background Bash loop, never by polling yourself:
  `until grep -q '^EXIT:' report.out; do sleep 60; done` (run_in_background). The `EXIT:`
  sentinel is how you know it finished vs. died.

## THE trap: foreground-only (three workers died to this)

A headless `claude -p` that backgrounds a long run (a test suite, a build) and says "I'll get
the completion notification" **dies immediately** — headless agents receive no notifications.
Put in EVERY brief that runs anything slow:

> OPERATING RULE: every long command runs FOREGROUND and you WAIT for it. Never background-and-
> stand-by. Sequential, one at a time.

When a worker dies mid-task (this rule, or a transient API socket error), its partial work sits
uncommitted in the worktree. Inspect it — if coherent, launch a **continuation** brief that
inherits the partial work and only finishes/verifies/commits; if not, `git checkout` and restart.

## Brief anatomy (the diff worker)

Each brief is a file under `/tmp/pm/prompts/`. Include, every time:
1. **Exactly ONE commit** of scope. Name the commit message + trailer.
2. **Mandatory reading FIRST** — repo CLAUDE.md, the plan row, the prior commits' change-logs,
   the L2/L3 of files touched. (GEB reverse-flow if the repo is GEB.)
3. **The rule that matters** stated as an automatic-FAIL condition (e.g. "never rewrite the
   focused contenteditable", "server is never an editing peer", "no DOM truncation before the
   dispatch admits it"). Mine these from the project's bug-history memory.
4. **STOP-guard**: "if premise X turns out false, STOP and report — do not plow ahead." This is
   how the biggest discoveries surface (a 'dead' path still load-bearing; a re-point that would
   ship a false freshness contract). Trust workers that stop over workers that guess.
5. **Runtime-evidence verification** — not "tests pass" but "paste the network capture / psql /
   MCP spot-check / latency numbers". Static green is not evidence.
6. **GEB/doc obligations** in the same commit (change-log, L2/L3, plan-row update).
7. **Update `progress.md`** — the mandatory final step (above): set the row's status + SHA +
   one-line result before finishing.

## Brief anatomy (the QA worker) — the adversary

The QA worker is where the value is. It caught, this run: a cross-instance PeerID race, two
rounds of live-RPC leakage a green build hid, two reproduced data-loss bugs, a stale-baseline
that would have reverted users' edits, and a feature unreachable from its own button. Its brief:
- **Distrust the diff report** — re-run every check yourself, re-derive every claim in code.
- **Scope check first**: `git show --stat` — did it touch forbidden paths (the untouchable UI
  layer, devops/, gitlinks)? Any = FAIL.
- **The one hard thing**, flagged for hard judgment (the race, the equivalence, the behavior
  change) — with the specific interleaving/diff to check.
- **Live/runtime evidence mandatory** where the risk is real (browser, psql, MCP). If a check
  is genuinely infeasible in-agent (real hardware IME, live transcription), say so explicitly —
  a named deferral, never a silent one.
- **Fake-fidelity**: read the new tests — a fake that would pass a broken impl (a repo fake that
  last-writes when the real DB is insert-if-absent) invalidates the test.
- First line of the verdict file: `VERDICT: PASS` or `VERDICT: FAIL`; findings pinpointed
  (file:line, what's wrong, what correct looks like) so the fix worker needs no re-investigation.

## Momentum discipline

- A task board (TaskCreate) mirroring the commit plan; mark in_progress/completed as you go.
- Report each verdict + any PM ruling to the user in 3-5 lines; stage the NEXT brief while the
  current QA runs so PASS → instant next launch.
- Checkpoint to memory at phase boundaries (what landed, the SHA, the decisions, what's held).
- When a discovery expands scope beyond the plan (a load-bearing 'dead' path, a product-wide
  blast radius), that's a **user decision** — surface it with a recommendation (AskUserQuestion),
  don't autonomously re-architect. Everything else, proceed automatically.
- HOLD the one irreversible commit (a `DROP TABLE`, a push) for explicit user go-ahead; land
  everything reversible first so rollback = revert.

## Merge gate: quiz the user (do NOT call it done until they pass)

A migration the user doesn't *understand* isn't safe to merge — they own it in review and at
3am. Before declaring merge-ready, produce a **single self-contained HTML report** (open-able in
a browser) covering: the context/problem, the intuition behind the approach, what each phase did,
the key decisions + rejected alternatives (pull from `implementation-notes.md`), the traps hit,
and the runtime evidence. End it with a **quiz the user must pass** — questions that only someone
who understood the change can answer (why X over Y, what breaks if Z, where the data-loss risk
was, what's still deferred). Canonical ask to hand the report-builder:

> "I want to make sure I understand everything that's happened in this change. Give me an HTML
> report on the changes for me to read and understand — with context, intuition, what was done,
> etc. — and a quiz at the bottom on the changes that I must pass."

Grade the answers. On a miss, expand that area and re-quiz. **Only after a perfect pass do you
call the work merge-ready.** The quiz is a comprehension gate on the *human*, distinct from the
QA gate on the *code* — both must pass.

## Teardown

At mission end (after the quiz passes): `tmux kill-session`, confirm zero worker processes,
remove transient prompt/log files, **keep `progress.md`, `implementation-notes.md`, the HTML
report, and the QA/diff reports** as the audit trail + the learning input for the next attempt.
Final grep-zero proof that the thing you set out to remove is actually gone.

## Minimal check

Before trusting a "done" report: `git log --oneline base..HEAD` (commit count matches the plan),
`git diff --shortstat` (the deletion actually happened), and one grep proving the target is gone.
The report can lie; the tree can't.

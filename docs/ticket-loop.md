# Linear Ticket Implementation Loop

## Entry Point

The slash command is `.config/opencode/commands/ticket-loop.md` and selects the
`.config/opencode/agents/ticket-loop-mastermind.md` primary agent.

```text
/ticket-loop <LINEAR-ID> [--approve-plan] [--until mergeable|merged]
```

Plan approval is interactive by default. `--approve-plan` explicitly authorizes autonomous plan
approval. `--until` defaults to `mergeable`.

## Workflow

```text
Linear read -> requirements -> Mission-format plan -> approval -> Foreman commits and commit QA
  -> whole-branch integration PM -> normal push -> find/create MR -> MR loop
```

Linear supplies requirements only. Ticket-loop never comments on, edits, transitions, assigns, or
otherwise updates Linear.

Mission contributes requirement acquisition and decomposition. In ticket-loop it runs in
planning-only mode and does not execute parallel workers. Foreman executes the approved plan using
OpenCode task subagents, one mutating worker at a time, followed by a fresh adversarial QA worker for
each exact commit. Foreman never launches tmux, `claude -p`, or another agent process.

Planning, orchestration, commit QA, and integration review use `gpt-5.6-sol`. Implementation and fix
workers use `gpt-5.6-terra` with the `medium` reasoning variant to reduce execution latency.

## Local Publication Gate

`ticket-loop-integration-pm` independently reviews the complete exact-SHA branch after all Foreman
units pass. It receives the ticket snapshot, clarified requirements, approved plan revision, base
and HEAD SHAs, commit QA reports, decisions, tests, and known deferrals. It is read-only and returns
PASS, FAIL, BLOCKED, or STALE.

A FAIL returns to Foreman for one focused repair commit, commit QA, and a fresh integration review.
Only two automatic integration repair cycles are allowed. BLOCKED requires a product or scope
decision. STALE rebuilds the evidence envelope.

Only the mastermind may push or create/find an MR. After PASS it revalidates HEAD, pushes normally,
finds an MR by exact project/source/target identity, or creates one automatically. It then transfers
control to `mr-loop-mastermind` with the exact MR URL and requested terminal condition.

## Durable State

Resumable state lives under `/tmp/ticket-loop-<linear-id>/` in `state.json`, `requirements.md`,
`plan.md`, `progress.md`, `implementation-notes.md`, and `reports/`. SHA or identity changes invalidate
worker reports and must be reconciled before mutation.

## Safety

Ticket-loop prohibits reset, clean, stash, local rebase, amend, force-push, discarded user work, and
concurrent mutating workers. Its MR phase uses the canonical `mr-loop-mastermind`; see
`docs/mr-loop.md` for remote synchronization, repair, CI, and merge safeguards.

Run the policy contracts after changing ticket-loop, Mission, Foreman, or their agents:

```sh
sh tests/ticket-loop-test.sh
sh tests/mr-loop-test.sh
```

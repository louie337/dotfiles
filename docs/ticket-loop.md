# Linear Ticket Implementation Loop

## Entry Point

The slash command is `.config/opencode/commands/ticket-loop.md` and selects the
`.config/opencode/agents/ticket-loop-mastermind.md` primary agent.

```text
/ticket-loop <LINEAR-ID> [--approve-plan] [--until mergeable|merged]
```

Approval is interactive by default. Before asking, ticket-loop explains the affected system or
feature for someone new to the codebase and then presents the implementation plan. `--approve-plan`
explicitly authorizes autonomous approval, but does not skip that briefing. `--until` defaults to
`mergeable`.

## Workflow

```text
Linear read -> requirements and code inspection -> affected-system overview -> Mission-format plan
  -> approval -> Foreman commits and commit QA
  -> whole-branch integration PM -> normal push -> find/create MR -> MR loop
```

Linear supplies requirements only. Ticket-loop never comments on, edits, transitions, assigns, or
otherwise updates Linear.

Mission contributes requirement acquisition and decomposition. In ticket-loop it runs in
planning-only mode and does not execute parallel workers. Foreman executes the approved plan using
OpenCode task subagents, one mutating worker at a time, followed by a fresh adversarial QA worker for
each exact commit. Foreman never launches tmux, `claude -p`, or another agent process.

## Pre-implementation Briefing

Before approval or implementation, the mastermind inspects the relevant code, tests,
configuration, and call sites. It presents an evidence-backed overview that assumes no prior
codebase knowledge and covers:

- What the affected system or feature does and why it exists.
- The relevant components, their responsibilities, and concrete repository paths.
- The end-to-end runtime, data, or control flow and external dependencies.
- Current behavior, the ticket's intended change, and what is outside scope.
- Important terminology, constraints, risks, and test seams.

Verified repository behavior, ticket requirements, and assumptions or open questions are identified
separately. The Mission-format implementation plan follows the overview. Interactive approval is
requested only after both are visible. `--approve-plan` records approval automatically only after
showing the same briefing. A material change to the requirements, system understanding, or scope
invalidates approval and requires revised overview and plan versions.

Planning, orchestration, commit QA, and integration review use `gpt-5.6-sol`. Implementation and fix
workers use `gpt-5.6-terra` with the `medium` reasoning variant to reduce execution latency.

## Verification Policy

Ticket-loop runs service-free local verification first: formatting, static analysis, compilation,
documentation checks, and focused or unit tests known not to require external services. Before
implementation it inspects the target repository's GitLab CI includes and path-selection rules for
planned paths, then repeats that mapping for final changed paths before publication. It maps
resource-heavy verification to exact existing automatic jobs and does not invent job names or claim
coverage that the configuration does not demonstrate.

Database integration, backend-service integration, Docker-dependent, browser/Playwright,
full-stack, preview-environment, and similar expensive checks default to GitLab CI. Ticket-loop and
its workers do not run `just infra-up`, Docker Compose, local databases, service stacks, or browser
stacks merely to reproduce those jobs. Pending CI and missing remote coverage are distinct: pending
jobs are handed to MR-loop after the normal publication push. Temporarily inaccessible or incomplete
CI evidence is also pending and never authorizes an invented job name. A coverage gap requires
complete readable configuration proving no automatic equivalent and carries an expected CI
follow-up.

No no-op commit, extra push, MR creation/update, or explicit pipeline creation is allowed solely to
trigger verification. If a genuinely required check has no remote equivalent, ticket-loop explains
the gap and asks before starting local infrastructure. Approval permits only the targeted dependency
needed for isolated reproduction, never an entire stack for one service and never production or
shared customer data. Repository-documented local startup remains an opt-in fallback for explicitly
requested reproduction or interactive debugging.

## Local Publication Gate

`ticket-loop-integration-pm` independently reviews the complete exact-SHA branch after all Foreman
units pass. It receives the ticket snapshot, clarified requirements, approved plan revision, base
and HEAD SHAs, commit QA reports, decisions, service-free checks, pending automatic CI, coverage
gaps, and known deferrals. It is read-only and returns PASS, FAIL, BLOCKED, or STALE. PASS means the
branch is suitable for its normal publication and remote CI; it does not convert pending CI into a
passing result.

A FAIL returns to Foreman for one focused repair commit, commit QA, and a fresh integration review.
Only two automatic integration repair cycles are allowed. BLOCKED requires a product or scope
decision. STALE rebuilds the evidence envelope.

Only the mastermind may push or create/find an MR. After PASS it revalidates HEAD, pushes normally,
finds an MR by exact project/source/target identity, or creates one automatically. It then transfers
control to `mr-loop-mastermind` with the exact MR URL and requested terminal condition.

## Durable State

Resumable state lives under `/tmp/ticket-loop-<linear-id>/` in `state.json`, `requirements.md`,
`system-overview.md`, `plan.md`, `progress.md`, `implementation-notes.md`, and `reports/`. SHA or
identity changes invalidate worker reports and must be reconciled before mutation.

## Safety

Ticket-loop prohibits reset, clean, stash, local rebase, amend, force-push, discarded user work, and
concurrent mutating workers. Its MR phase uses the canonical `mr-loop-mastermind`; see
`docs/mr-loop.md` for remote synchronization, repair, CI, and merge safeguards.

Run the policy contracts after changing ticket-loop, Mission, Foreman, or their agents:

```sh
sh tests/ticket-loop-test.sh
sh tests/mr-loop-test.sh
```

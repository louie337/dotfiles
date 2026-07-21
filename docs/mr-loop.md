# GitLab MR Agent Loop

## Source Of Truth

The active MR loop is the OpenCode standalone/all-mode agent at
`.config/opencode/agents/mr-loop-mastermind.md`. It is the sole state-machine,
scheduler, mutation owner, and final-output authority.

The slash-command entry point is `.config/opencode/commands/mr-loop.md`.
It only forwards arguments, documents the default, and selects the active agent.
The ticket implementation workflow may also invoke this same agent as an OpenCode
subagent after it creates an MR; MR-loop retains sole ownership of its remote state
machine and safety policy during that control transfer.

Reusable procedures live in `.config/opencode/skills/mr-loop-*/SKILL.md`:

- `mr-loop-evidence`: immutable evidence envelopes, policy IDs, worker result
  contracts, and stale-result rejection.
- `mr-loop-snapshot`: startup checks, exact MR snapshots, target-branch evidence,
  discussion pagination, and same-SHA evidence collection.
- `mr-loop-synchronization`: source convergence, exact target synchronization,
  GitLab-side rebase, and guarded local branch realignment.
- `mr-loop-conflict-analysis`: read-only conflict classification, generated-file
  detection, deterministic intent evidence, and worker guidance.
- `mr-loop-conflict-integration`: isolated exact merge fallback, conflict phases,
  `resolved_uncommitted` boundary, commit/push, cleanup, and interruption
  recovery.
- `mr-loop-review-repair`: post-sync review, discussion repair, local repair
  batching, and autonomous engineering decisions.
- `mr-loop-pipeline`: exact-SHA recursive CI graph polling, failed-job
  classification, pipeline serialization, and guarded cancellation.
- `mr-loop-linear-context`: exact Linear lookup from `SUB-[0-9]+` source branches
  and domain conflict precedence.

The executable policy contract is `tests/mr-loop-test.sh`. Structured
conflict transition cases are in
`tests/fixtures/mr-loop-conflict-scenarios.json`.

The dotfiles repository is installed with Stow, so files under
`~/.config/opencode/` are links to these source-controlled definitions. Edit the
repository files, not copied or generated installation paths. Older documents
under `docs/superpowers/` describe the removed `.local/bin/mr-loop` shell
supervisor and are retained only as historical records.

## Worker Model

The primary agent may invoke hidden read-only subagents for parallel evidence
collection:

- `mr-loop-review-investigator` inspects independent diff, code, and discussion
  scopes.
- `mr-loop-conflict-investigator` analyzes independent conflict groups under
  exact source and target SHAs.
- `mr-loop-ci-investigator` classifies focused exact-SHA failed CI traces,
  bridges, and downstream jobs.

Workers receive immutable envelopes from `mr-loop-evidence` and return advisory
evidence only. They cannot edit files or perform Git/GitLab mutations. The
primary discards worker results if MR identity, source SHA, or target SHA changes
before action.

## Safety Boundaries

Local rebase, reset, clean, stash, amend, force-push, force-with-lease, history
rewrite, and discarded user work remain prohibited at the agent permission layer.

Only the primary loop edits, stages, commits, pushes, replies, resolves
discussions, requests GitLab rebase, cancels pipelines, merges, moves branch
pointers, or changes loop state.

The synchronization gate must open before ordinary repair. Safe merge-conflict
integration is the sole editing exception and uses an isolated detached worktree,
`git merge --no-ff --no-commit <exact-target-sha>`, deterministic resolution,
focused verification, a preserved two-parent merge commit, one normal push, and a
fresh startup after SHA convergence.

Active required CI owns a hard recursive-poll deadline no later than 30 seconds
after each complete graph snapshot. Optional workers and broad investigation
cannot delay that poll.

## Verification Policy

MR-loop runs service-free checks locally first: formatting, static analysis,
compilation, documentation checks, and focused or unit tests known not to require
external services. It inspects the target repository's GitLab CI includes, job
commands, and path-selection rules, then records exact automatic jobs that cover
database integration, backend services, Docker, browser/Playwright, full-stack,
preview environments, or other resource-heavy verification. It never invents a
job name or infers coverage from a name alone.

Every mapped verification-required job is paired with its expected pipeline graph
and must appear and succeed there, even if GitLab marks it `allow_failure`. A
same-named job in another graph is not a substitute. MR-loop does not become
mergeable while mapped jobs or CI evidence are pending. In an expected completed
graph, an absent, `manual`, `skipped`, or otherwise terminal non-successful mapped
job is a selection/execution gap, not a passing result; the agent does not play it
or replace it with local verification.

Resource-heavy verification defaults to those exact-SHA GitLab jobs. MR-loop does
not run `just infra-up`, Docker Compose, local databases, service stacks, browser
stacks, or preview environments merely to reproduce CI. It also never creates a
no-op commit, pushes unchanged code, updates an MR, or explicitly creates a
pipeline solely to trigger verification. Normal synchronized repair pushes remain
allowed because they publish actual code intended to merge and automatically
select CI by path.

If automatic remote verification or its configuration is temporarily not
observable, MR-loop runs available service-free checks and reports the evidence
as pending without inventing job names. A coverage gap requires readable,
complete CI configuration and path rules proving no automatic equivalent. A
mapped job omitted by its expected complete terminal graph is instead a
non-substitutable selection gap. A no-capability gap is recorded with an expected
CI follow-up, not treated as permission to start local services. If local
infrastructure is genuinely necessary, the agent explains the gap and asks first;
approval permits only a targeted dependency using isolated test data. A
successful approved fallback remains bound to the exact SHA and does not erase
the reported CI gap. Whole-stack startup for one service and production or shared
customer data are prohibited. Documented local startup procedures remain opt-in
fallbacks for explicit reproduction or interactive debugging requests.

## Testing Note

Run the path-specific executable policy contract after changing the agent,
command, skills, worker agents, or this documentation:

```sh
sh tests/mr-loop-test.sh
```

Before completion, also run `git diff --check` and review the branch-wide diff.
This repository has no separate executable path-rule dispatcher; the test above
is the applicable repository-local rule check. The MR agent itself must discover
and run a target repository's dispatcher and path-specific instructions before
editing conflicts and branch-wide before completing an MR repair.

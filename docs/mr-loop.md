# GitLab MR Agent Loop

## Source Of Truth

The active MR loop is the OpenCode primary agent at
`.config/opencode/agents/mr-loop.md`. It is the sole state-machine,
scheduler, mutation owner, and final-output authority.

The slash-command entry point is `.config/opencode/commands/mr-loop.md`.
It only forwards arguments, documents the default, and selects the active agent.

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

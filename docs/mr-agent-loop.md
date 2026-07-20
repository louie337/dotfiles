# GitLab MR Agent Loop

## Source Of Truth

The active MR loop is the OpenCode primary agent at
`.config/opencode/agents/mr-agent-loop.md`. The slash-command entry point is
`.config/opencode/commands/mr-agent-loop.md`, and
`tests/mr-agent-loop-test.sh` is its executable policy contract. The required
state-transition cases are recorded in
`tests/fixtures/mr-agent-loop-conflict-scenarios.json`.

The dotfiles repository is installed with Stow, so files under
`~/.config/opencode/` are links to these source-controlled definitions. Edit the
repository files, not a copied or generated installation. The older documents
under `docs/superpowers/` describe the removed `.local/bin/mr-loop` shell
supervisor and are retained only as historical records.

The agent loads the source-controlled `gitlab-cli-skills` and `glab` skill
snapshots for general GitLab CLI guidance. They are not the MR loop state machine
and do not override the agent's safety policy.

## Target Synchronization

The loop first asks GitLab to rebase a source branch that is behind its target.
A successful GitLab rebase is fetched and the loop restarts on the new SHA; no
local merge fallback runs.

When GitLab specifically reports that conflicts require local resolution, the
same agent state machine may create one normal merge commit. It revalidates the
MR and exact source/target SHAs, works in a temporary detached worktree at the MR
source SHA, merges the exact target SHA with `git merge --no-ff --no-commit`,
resolves only deterministic conflicts, verifies the result, and normally pushes
`HEAD` to the MR source branch. It then waits for GitLab SHA convergence and
restarts from a fresh snapshot.

Local rebase, reset, clean, stash, amend, force-push, force-with-lease, and other
history rewriting remain prohibited. Existing worktrees and local branch
pointers are not used for conflict editing. Before commit, only a fully owned
isolated attempt may be aborted; after commit, the merge is preserved under a
local ref if the normal push cannot complete.

## Conflict Policy

The loop combines non-overlapping source and target behavior only when code,
tests, ticket evidence, and repository rules establish one result. Generated
files are recreated from resolved source definitions with the canonical
generator. Product ambiguity, policy-sensitive migrations, unsupported security
acceptance, unclear reviewer intent, missing generation context, unrelated local
changes, failed required checks, and uncertain fork push permission stop the
attempt without a push.

Read-only explore subagents may recommend resolutions for independent conflict
groups, but the primary loop remains the only editor and owner of Git/GitLab
state transitions. Recommendations expire whenever the source or target SHA
changes.

## Testing Note

Run the path-specific executable policy contract after changing the agent,
command, or this documentation:

```sh
sh tests/mr-agent-loop-test.sh
```

Before completion, also run `git diff --check` and review the branch-wide diff.
This repository has no separate executable path-rule dispatcher; the test above
is the applicable repository-local rule check. The MR agent itself must discover
and run a target repository's dispatcher and path-specific instructions before
editing conflicts and branch-wide before completing an MR repair.

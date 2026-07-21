---
name: mr-loop-conflict-integration
description: Use for GitLab MR loop exact merge fallback, isolated worktree lifecycle, conflict phase persistence, commit, push, cleanup, and interruption recovery.
---

# MR Loop Conflict Integration

This skill defines the only local target-conflict integration path: one ordinary
two-parent merge commit from the exact MR source SHA and exact current target SHA,
followed by one normal push. It does not permit local rebase, force-push, branch
rewriting, or a supervisor script.

## Fresh Guards And Isolation

Before creating or resuming an attempt:

1. Re-fetch MR identity and require the same host, target project path, IID,
   opened state, source/target projects, source/target branches, and expected
   source SHA. Require `rebase_in_progress=false`.
2. Query the target project's branch endpoint and record `<exact-target-sha>`.
   Local target branches and stale `diff_refs` are insufficient.
3. Prove source push and target fetch authority for same-project or fork topology.
4. Run GitLab write identity preflight.
5. Fetch exact source and target branch refspecs without moving local branches;
   save each SHA before the next fetch.
6. Require clean index and worktree including untracked files before creating the
   attempt. Never stash, clean, reset, or absorb user work.
7. Create one loop-owned detached worktree:

```sh
git worktree add --detach /tmp/mr-loop-worktree-<conflict-attempt-id> <expected-source-sha>
```

Verify detached `HEAD`, exact SHA, clean tree, no merge state, and ownership by
the current `conflict_attempt_id`. Do not move existing worktrees or branch
pointers.

## Exact Merge

In only the isolated worktree, run exactly:

```sh
git merge --no-ff --no-commit <exact-target-sha>
```

Set `conflict_phase=unresolved_merge` and verify `MERGE_HEAD` equals the exact
target SHA and `HEAD` equals expected source SHA. Capture `git ls-files -u`,
unmerged paths, conflict types, and merge-created changes.

## Resolved Uncommitted Boundary

Set `conflict_phase=resolved_uncommitted` only after all of these are true:

- every reviewed conflict path and proven regenerated output is staged;
- `git ls-files -u` is empty;
- no unmerged status entries remain;
- conflict marker checks pass;
- `git diff --check` passes;
- no unrelated staged or unstaged changes exist;
- required service-free path-specific rules, canonical generation, and focused
  verification have completed successfully or are proven not applicable;
- resource-heavy verification is mapped to exact automatic GitLab jobs that will
  run after the normal merge-commit push, has temporarily unavailable evidence
  recorded as pending, or has a proven remote coverage gap requiring primary-agent
  handling.

This phase exists before the commit so recovery can distinguish a fully resolved
but still abortable attempt from an unresolved merge.

Do not start `just infra-up`, Docker Compose, containers, local databases, queues,
object stores, backend stacks, browser stacks, preview environments, or similar
infrastructure to cross this boundary. If no remote equivalent exists and the
check is genuinely required before commit, the primary must explain the gap and
obtain user approval first. Use only the approved targeted dependency with
isolated test data; never start a whole stack for one service or use production or
shared customer data.

## Commit And Push

Immediately before commit, re-run identity, MR identity, exact source fetch, exact
target fetch, and target-branch API query. If target changed before commit,
safely abort and remove only this owned uncommitted attempt, then restart at
`startup`. If source or identity changed, do not push; safely abort only when
ownership is proven, then restart or report `blocked_remote_changed`.

Create exactly one conventional merge commit such as
`chore(merge): integrate <target-branch>`. Its body must include
`Target-SHA: <exact-target-sha>` and `Conflicts-Resolved-By: MR agent loop`.
Verify exactly two parents in order: expected source SHA then exact target SHA.
Set `conflict_phase=committed_unpushed`, record the merge SHA, and preserve it:

```sh
git update-ref refs/mr-loop/conflicts/<conflict-attempt-id> <merge-commit-sha>
```

Immediately before push, rerun identity preflight, pipeline serialization gate,
MR identity snapshot, exact source fetch, exact target fetch, and target-branch
API query. If anything changed after commit, do not push, delete, amend, or
rewrite the merge; verify the preservation ref and report the blocker.

Push normally and only to the verified source branch:

```sh
git push origin HEAD:<source-branch>
```

On failed or non-fast-forward push, leave the merge commit and preservation ref
intact, retain the clean isolated worktree, and report the blocker.

After successful push, set `conflict_phase=pushed_awaiting_gitlab` and poll fresh
source-ref and MR snapshots until both report the pushed merge SHA. Then perform
guarded cleanup and restart at `startup` from a fresh same-SHA snapshot.

## Decision Log And Cleanup

Persist JSON at `/tmp/mr-loop-state-<conflict-attempt-id>.json`, never in a
Git worktree. Record phase, source SHA, target SHA, conflicted paths and types,
per-path evidence, generated paths, rule dispatch, verification, merge SHA,
pending automatic CI jobs or evidence, proven remote coverage gaps, any approved
targeted local fallback, preservation ref, pushed SHA, cleanup state, and residual
risks.

Before a merge commit exists, abort an isolated attempt only when ownership is
fully proven. After a merge commit exists, never abort, delete, amend, reset,
rebase, or rewrite it. Remove only the owned worktree without `--force` after the
pushed SHA converges or the user resolves the blocker and all cleanup guards pass.

## Interruption Recovery

- `unresolved_merge` or `resolved_uncommitted`: resume only if worktree,
  `MERGE_HEAD`, identity, source SHA, target SHA, and current changes still belong
  to the attempt. A changed target permits narrowly guarded uncommitted abort.
- `committed_unpushed`: require a clean owned worktree, preservation ref at the
  recorded merge commit, exactly two parents, and fresh pre-push guards.
- `pushed_awaiting_gitlab`: never recreate, amend, or push the commit again;
  fetch source and MR state until both equal `pushed_merge_sha`, then clean up and
  restart. Unexpected SHA is `blocked_remote_changed`.

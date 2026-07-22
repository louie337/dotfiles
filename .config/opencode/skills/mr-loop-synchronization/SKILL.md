---
name: mr-loop-synchronization
description: Use for GitLab MR loop source convergence, exact target synchronization, GitLab-side rebase, local target fast-forward, and guarded branch realignment.
---

# MR Loop Synchronization

This skill opens the synchronization gate for ordinary repair. It does not
authorize local rebase, force-push, reset, clean, stash, or history rewrite.

## Gate Definition

The synchronization gate is open only when one fresh snapshot proves:

- local `HEAD` equals remote-source SHA and MR SHA;
- source commit contains the fetched target SHA as an ancestor using
  `git merge-base --is-ancestor <fetched-target-sha> <mr-sha>`;
- `rebase_in_progress` is false;
- `has_conflicts` is false;
- `merge_error` is null;
- GitLab does not report `need_rebase` or another target-synchronization need.

The gate expires before every repair edit, commit, normal push, target merge, and
CI or mergeability evaluation. Refresh MR identity, remote-source SHA, and remote
target ref immediately before acting.

## Safe Dual Sync

1. Fetch the exact MR source branch from the verified push remote and the exact
   target branch from the verified target-project remote.
2. Record `FETCH_HEAD` after each fetch as `<remote-source-sha>` and
   `<fetched-target-sha>` before the next fetch can overwrite it.
3. Require fetched source to equal expected MR head SHA and fetched target to
   equal the target-branch API SHA.
4. For ordinary repair only, check out or switch to the local source branch when
   the tree is clean. Conflict integration uses a detached worktree instead.
5. If local is behind the MR source branch, fast-forward only.
6. If local is ahead or diverged, preserve the old local tip under a unique local
   backup ref, then realign to the authoritative MR SHA only when every guard
   passes. Never push the ahead local commits before synchronization.
7. When synchronization is needed, revalidate actor, MR identity, source SHA, and
   target SHA, pass the pipeline serialization gate, then request GitLab-side
   rebase with `glab mr rebase <iid> --repo <project>` or the equivalent API.
8. GitLab-side rebase success means fetch the new source SHA and restart at
   `startup`; do not run local merge fallback.
9. Enter safe merge-conflict integration only when GitLab explicitly reports a
   local conflict resolution requirement such as `Rebase failed: Rebase locally,
   resolve all conflicts, then push the branch.`

Auth, permission, network, unknown, or non-conflict rebase failures do not
authorize local integration.

## Pre-Synchronization Causal Metadata Exception

`INV-NO-PRESYNC-REPAIR` still prohibits unrelated repair before the gate opens.
`INV-PRESYNC-CAUSAL-METADATA-REPAIR` permits only validation-enabling repository
metadata proven under `mr-loop-conflict-analysis` and verified under
`mr-loop-conflict-integration`. It is part of the existing exact merge attempt and
its single ordinary two-parent commit, not a separate repair phase, branch, MR,
commit, or push.

A target-owned validation failure does not automatically require a separate MR.
Use one only when the user explicitly requests it or the repair cannot safely
belong to the current integration commit. Never merge a helper MR merely because
its path-selected MR pipeline passes; before an explicitly authorized helper MR
is merged, prove coverage equivalent to all required checks affected by the
repair or report the coverage gap and do not merge it.

## Local Target Synchronization

Local target synchronization is optional. MR comparison and conflict integration
must use the freshly fetched target-project SHA directly.

- Create a missing local target branch at verified `FETCH_HEAD` only if still
  absent immediately before creation.
- Fast-forward a local target branch with `git branch -f <target-branch>
  FETCH_HEAD` only when it is not checked out in any worktree, its current tip is
  an ancestor, and branch occupancy is rechecked immediately before mutation.
- A checked-out target worktree may use `git pull --ff-only` only after proving it
  is clean, on the exact target branch, has no unique commits, and no active
  process or uncommitted work will be disturbed.
- Otherwise leave stale, occupied, dirty, divergent, or uniquely advanced local
  target branches intact and record the reason.

## Guarded Source Branch Realignment

When a clean local source branch diverges from the remote MR source, preserve old
local `HEAD` under `mr-loop-backup/<source-branch>/<timestamp>-<sha>` or an
equivalent local ref before moving any pointer. Then realign without reset,
local rebase, or force-push:

```sh
git switch --detach <mr-sha>
git branch -f <source-branch> <mr-sha>
git switch <source-branch>
```

After realignment, verify branch name, `HEAD`, clean tree, and backup ref. Restart
from a fresh MR snapshot.

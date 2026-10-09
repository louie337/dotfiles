---
name: subanana-local-space-clean
description: Inventory disk space used by Subanana repository worktrees and related temporary files, check corresponding Linear issue statuses and tmux ownership, and report cleanup candidates before any deletion.
---

# Subanana local space cleanup

Start with a **read-only inventory**. Invoking this skill, or asking generally to free space, does not authorize cleanup. Present the exact paths and proposed actions, then wait for the user's explicit authorization before running `git worktree remove`, `git worktree prune`, deleting temporary files, or changing Git registrations. Never run a real prune during the inventory; `git worktree prune --dry-run --verbose` is allowed.

## Inventory

1. Resolve the repository's main checkout and list its worktrees with `git worktree list --porcelain`. Record each path, branch or detached HEAD, Git's `prunable` flag, and whether the directory still exists.
2. For existing worktrees, record directory creation date, disk use, branch progress relative to the current main branch, and tracked and untracked changes. Distinguish creation date from the latest commit date. A branch with zero new commits may still contain valuable uncommitted work.
3. Inspect tmux sessions **and pane current directories**. Treat a session as owning a worktree when a pane uses that path or other direct evidence links them; a matching session name alone is tentative and should protect the worktree pending clarification. A linked session protects its worktree even if detached or idle; do not label it stale. If tmux cannot be read, mark ownership unknown rather than inferring that no session exists. A new clean worktree with no commits and a session may be in planning.
4. Check `/private/tmp` (`/tmp` may link there) for registered detached worktrees, prunable records with surviving directories, and caches or other files whose names or contents clearly tie them to a worktree or issue. State whether each match is certain or tentative. Keep temporary files tied to active tmux projects out of cleanup candidates.
5. Before proposing cleanup, identify corresponding Linear issues from branch names, paths, or other direct evidence and fetch their current statuses read-only. Record each issue ID, status, and completion date when available; distinguish certain associations from tentative ones. Do not infer completion from branch age, local merge state, or zero unique commits. Preserve worktrees and correlated temporary data for active issues (including In Progress and In Review). If Linear is unavailable, an issue is missing, or the association is uncertain, report its status as unknown and exclude it from cleanup candidates pending clarification. Done supports candidacy but does not override local changes, tmux ownership, submodule safety, explicit exclusions, or the approval boundary. Never change Linear issues as part of cleanup.
6. Lead the report with potentially reclaimable space by candidate path and proposed action. Separate near-zero Git registration pruning from substantial surviving directories and caches. Then list all existing worktrees, likely stale *clean* worktrees without tmux ownership, and dirty worktrees to preserve. Give path, size, relevant dates, corresponding Linear status, and reason. `du` estimates are not a promise of space reclaimed on filesystems with shared blocks.

## Authorization boundary

End the first pass with the proposed removal set and ask the user to approve those specific paths and actions. A worktree's age, cleanliness, or Git's `prunable` flag is not authorization; an existing approval applies only to the exact paths and actions it covers. Preserve branch references unless the user explicitly asks to delete them.

Recheck the selected issues' Linear statuses immediately before deletion; stop cleanup for any issue that is now active or whose status cannot be verified.

After approval, recheck the selected worktrees, tmux ownership, and temporary paths immediately before deletion. For each initialized submodule, inspect tracked and untracked changes, compare its checked-out commit with the parent's recorded gitlink, and check whether any differing or detached commit remains reachable from a ref or object store that will survive deletion. Ordinary parent `git status` can hide changed gitlink pointers, and submodule Git data may live under the worktree's Git metadata. If a checkout has local file changes, an unpreserved submodule commit, or new tmux ownership, stop that deletion and report it. Remove only the approved items, then verify the paths and registrations are gone. If an approval reviewer rejects an action, do not bypass it through another command; gather evidence or report the blocked item to the user.

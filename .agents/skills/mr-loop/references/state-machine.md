# MR-loop state machine

Use these canonical states and always return to `snapshot` after a mutation or identity change.

1. `snapshot`: establish immutable local, primary MR, optional paired DevOps MR, target, discussion,
   and pipeline identity.
2. `bootstrap_mr`: when no matching MR exists, bind the local branch/HEAD, GitLab project and actor,
   and exact target SHA; publish a missing remote branch and create one MR, restarting at `snapshot`
   after each write.
3. `classify_infrastructure`: determine from ticket, code, diff, and repository rules whether the app
   implementation requires an actual DevOps repository diff.
4. `ensure_worktrees`: reuse or create the app worktree and, only for required infrastructure work,
   the same-named DevOps worktree.
5. `bootstrap_devops_mr`: only after a verified non-empty infrastructure diff exists, publish the
   same-named DevOps branch and create one paired MR when no exact match exists.
6. `synchronize`: converge each required MR source with its exact target through the safest
   supported remote operation.
7. `collect_review`: inspect current diffs, rules, reports, and unresolved discussions.
8. `triage`: classify each finding and identify decision boundaries.
9. `repair`: create one small atomic local batch in one repository with focused tests and
   service-free checks.
10. `publish_repair`: revalidate the pair, commit, and normally push exactly one batch.
11. `await_pipeline`: poll each bound pipeline and recursive graph in discrete foreground steps.
12. `investigate_ci`: classify exact-SHA failures and route deterministic repairs back to `repair`.
13. `integrate_conflict`: perform guarded exact-target merge work in an isolated detached worktree.
14. `verify_mergeable`: prove both required MRs satisfy synchronization, review disposition,
   conflict state, and required CI.
15. `merge`: revalidate per-MR authorization and merge only MRs covered by the requested target.

Immediately restart at `snapshot` when either source SHA, target SHA, MR identity, canonical
pipeline, infrastructure classification, or local branch identity changes. Serialize mutations
across the pair. A worker result is advisory until the root thread revalidates its envelope. If no
executable transition exists because product intent, authorization, or an irreversible action is
undecidable, explain the exact boundary and ask the user.

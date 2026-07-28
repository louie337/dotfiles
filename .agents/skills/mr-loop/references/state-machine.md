# MR-loop state machine

Use these canonical states and always return to `snapshot` after a mutation or identity change.

1. `snapshot`: establish immutable local, MR, target, discussion, and pipeline identity.
2. `synchronize`: converge source with exact target through the safest supported remote operation.
3. `collect_review`: inspect current diff, rules, reports, and unresolved discussions.
4. `triage`: classify each finding and identify decision boundaries.
5. `repair`: create one small atomic local batch with focused tests and service-free checks.
6. `publish_repair`: revalidate, commit, and normally push exactly one batch.
7. `await_pipeline`: poll the bound pipeline and recursive graph in discrete foreground steps.
8. `investigate_ci`: classify exact-SHA failures and route deterministic repairs back to `repair`.
9. `integrate_conflict`: perform guarded exact-target merge work in an isolated detached worktree.
10. `verify_mergeable`: prove synchronization, review disposition, conflict state, and required CI.
11. `merge`: revalidate authorization and merge only when the requested target is `merged`.

Immediately restart at `snapshot` when the source SHA, target SHA, MR identity, canonical pipeline,
or local branch identity changes. A worker result is advisory until the root thread revalidates its
envelope. If no executable transition exists because product intent, authorization, or an
irreversible action is undecidable, explain the exact boundary and ask the user.

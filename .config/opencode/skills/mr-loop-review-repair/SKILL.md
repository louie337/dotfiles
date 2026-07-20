---
name: mr-loop-review-repair
description: Use for GitLab MR loop post-synchronization review, unresolved discussion handling, local repair batching, and autonomous engineering decisions.
---

# MR Loop Review Repair

This skill applies only after the synchronization gate opens. Findings collected
before synchronization are provisional and must be revalidated against the fresh
post-sync diff before editing.

## Review Priorities

For every new MR SHA, review the diff for blockers before waiting on CI. Focus on
correctness, security, required behavior, and missing tests. Avoid cosmetic churn.

Read-only review investigators may inspect independent files, discussion groups,
or code areas in parallel using the assignment envelope from `mr-loop-evidence`.
Their findings are advisory and expire when source SHA, target SHA, or identity
changes.

## Discussion Repair

Process unresolved resolvable discussions oldest first as one local repair batch.
Do not commit or push after each discussion.

1. Capture stable discussion ID, non-system notes, note bodies, author IDs,
   resolvable/resolved flags, suggestions, and stable position fields excluding
   GitLab-managed base/start/head SHAs.
2. Classify feedback as valid, invalid, obsolete, or blocked.
3. For valid feedback, make the smallest code change and keep it local as part of
   the current batch. Perform only checks allowed by the local verification
   budget. Continue through currently actionable discussions, yielding whenever
   the active pipeline poll deadline is due.
4. For invalid or obsolete feedback, leave the tree clean, re-fetch the exact
   discussion, reply with a technical rationale, then resolve.
5. For blocked feedback, stop without replying or resolving.
6. Before reply and again before resolve, revalidate actor, MR identity, MR SHA,
   local branch, local HEAD, and discussion snapshot.
7. After processing the current set, fetch all discussions again and add newly
   arrived actionable feedback to the same local batch until one fresh fetch has
   none.
8. Reopen the synchronization gate before finalizing the batch. If the target
   advanced, restart synchronization without pushing.
9. Reply to and resolve fixed discussions only after the repair push has converged
   to the MR SHA.

Reply must succeed before resolution. Use `glab mr note create ... --reply` or
the discussion notes API, then `glab mr note resolve ...` or the resolve API.

## Autonomous Engineering Decisions

Choose and implement the safest bounded repair instead of asking the user when:

- the issue is an engineering tradeoff, or a domain conflict resolved by
  `mr-loop-linear-context`;
- it is not unresolved reviewer intent, deployment approval, destructive data
  policy, or unsupported security acceptance;
- code, tests, job trace, discussion, or repository rules identify a bounded fix;
- the approach is deterministic, race-safe, resource-bounded, and consistent with
  nearby patterns;
- the change can be kept focused and verified by exact-SHA CI, with only cheap
  local checks unless conflict integration requires stricter checks.

Prefer the smallest safe approach that fixes the defect class, not only one
failing example. For concurrency and reconciliation bugs, prefer bounded
batching, durable pagination/checkpointing, explicit partial-settlement
semantics, idempotency, and clear retry behavior over unbounded N+1 loops.

Record every autonomous decision: problem, chosen approach, reason, rejected
alternatives, verification, and residual risk. If no safe bounded option exists,
stop and report the missing decision or context.

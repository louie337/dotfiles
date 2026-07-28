# Ticket-loop lifecycle

1. `acquire`: validate issue ID and read the exact Linear issue without mutation.
2. `brief`: inspect the affected repository and explain current behavior and constraints.
3. `plan`: produce small atomic commit-sized units and verification mapping; obtain or consume
   approval.
4. `implement_unit`: assign one worker against an expected parent SHA.
5. `commit_qa`: independently verify the exact resulting commit.
6. `repair_unit`: assign focused corrections as new commits, then repeat QA.
7. `integration_gate`: review the whole base-to-head branch against the issue and plan.
8. `publish`: push the unchanged gated HEAD and create the GitLab MR.
9. `mr_loop`: use `$mr-loop` until mergeable or merged.

Persist enough evidence in the root thread to reconstruct the current state after interruption:
issue read timestamp, plan revision, base/branch/head SHAs, each worker assignment and result, each QA
verdict, checks, CI mappings, deferrals, and MR identity. Treat every delegated result as stale until
its SHA envelope is revalidated.

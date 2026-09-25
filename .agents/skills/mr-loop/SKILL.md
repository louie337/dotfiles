---
name: mr-loop
description: Drive a GitLab merge request from its current exact SHA to mergeable or merged through guarded synchronization, review repair, CI triage, conflict integration, and paired deployment-MR tracking. Use when the user invokes $mr-loop, provides an MR URL and asks to repair or babysit it, or asks to continue until mergeable or merged.
---

# GitLab MR loop

Own the workflow in the root thread. Load `gitlab-cli-skills` and `glab` before using GitLab CLI.
Delegate bounded read-only investigations to the `mr-loop-review-investigator`,
`mr-loop-conflict-investigator`, or `mr-loop-ci-investigator` custom agents. Keep every mutation,
state transition, user decision, and final claim in the root thread.

Read [references/state-machine.md](references/state-machine.md) before the first mutation or when
resuming an interrupted loop. Before triaging review findings, read
[Proportional Review Triage](../../../docs/mr-loop.md#proportional-review-triage) and follow its
suppression syntax, authorization checks, and post-write verification.

## Parse the request

Accept an MR URL or an unambiguous local repository branch, plus an optional target `mergeable` or
`merged`; default to `mergeable`. When the local branch has no open MR, treat invocation as
authorization to publish that branch and create one against the explicitly requested target branch
or the repository default branch. Resolve the GitLab host, project, actor, local source branch and
SHA, target branch and exact SHA, and prove that no matching open MR exists before the first write.
Reject ambiguous repository, branch, target, or multiple-MR identity before mutation. Treat a
terminal request such as “finish” or “do not stop” as persistence toward the target, not broader
authorization.

For a Subanana app MR, treat `/Users/louie/Documents/subanana/subanana-main` as the primary
repository and `/Users/louie/Documents/subanana/subanana-devops-main` as an optional paired
repository. The exact app source-branch name is the pair key. A paired DevOps worktree, remote
branch, and MR are required only when the app change also requires an actual infrastructure change.
For a DevOps MR, reverse the primary/optional repository roles while retaining the exact same
source-branch pair key; discover an APP counterpart only when the ticket and diff require an APP
change too.

The app's `services:all:deploy:dev` job uses that same branch name as its DevOps deployment
selector. In an app pipeline it takes `CI_MERGE_REQUEST_SOURCE_BRANCH_NAME` (or
`CI_COMMIT_REF_NAME`), clones the exact matching branch from
`dogcoin/subanana/subanana-devops`, and applies that branch's `dev/subanana-autopilot`
manifests/settings. If no matching DevOps branch exists, the job falls back to DevOps `master`.
Thus same-named APP and DevOps source branches are required for a dev deployment to consume the
corresponding DevOps MR branch; MR or ticket association alone is insufficient. When using a dev
deploy as evidence, bind the resolved DevOps branch and head SHA and distinguish an exact paired
branch deployment from a `master` fallback.

Before mutating anything, determine how many MRs are required for complete deployment and record
the deployment MR set: `1 MR` when only one repository is in scope (APP-only or DevOps-only), or
`2 MRs` when the ticket, implementation, code, or repository rules require an APP change plus an
actual paired DevOps change. Count both required MRs even when the DevOps diff or MR is not yet
present; a verified, non-empty DevOps diff is the gate before its MR can be reused or created. When
invoked from a DevOps MR or branch, resolve the exact APP counterpart when the ticket and diff
require one; a same-ticket association is not sufficient. Never count unrelated, helper, or empty
MRs toward complete deployment.

## Invariants

- Never reset, clean, stash, locally rebase, amend, rewrite history, force-push, or discard work.
- Require every loop-owned worktree to be clean before taking ownership, except for one clearly
  scoped initial implementation batch per affected repository produced for the active request.
  Attribute every dirty path to its repository's batch, verify and commit it atomically, then
  require that worktree to be clean. Do not absorb unrelated changes.
- Bind every decision to host, project, IID, source/target projects and branches, exact source SHA,
  and exact target SHA fetched from GitLab’s target-branch endpoint.
- When a paired DevOps MR is required, bind it independently to its project, IID, exact source and
  target SHAs, and use exactly the same source-branch name as the app MR. Never substitute a
  similarly named branch or ticket association.
- Discard worker results when any bound identity or SHA changes.
- Keep Linear read-only. Use a matching ticket only as requirement evidence.
- Perform one pipeline-producing or merge-affecting mutation at a time, then rediscover canonical
  state before another.
- Keep commits small and atomic: put one logical concern in each independently reviewable and
  verifiable commit. Split unrelated repairs into separate commits, keep required tests and
  documentation with the change they verify, and never combine independent concerns into one
  omnibus commit or fragment one tightly coupled change artificially.
- Do not create no-op commits, helper MRs, or pipelines merely to obtain CI evidence.
- Never create a DevOps worktree, branch, or MR merely because the app MR exists, shares a ticket,
  needs deployment, or needs CI evidence. Require concrete ticket, diff, code, or repository-rule
  evidence that infrastructure files must change. Never create an empty DevOps MR.
- Prefer existing automatic CI for service-heavy verification. Do not start local infrastructure
  without explicit user approval and isolated test resources.

## Operate the loop

1. Snapshot local Git state, remotes, GitLab identity, MR metadata, exact source/target SHAs,
   discussions, review findings, mergeability, and recursively expanded pipeline state.
   In the same snapshot, record the deployment MR count (`1` or `2`) and the canonical web URL of
   every required APP or DevOps MR. If a required counterpart is absent or its URL cannot be
   resolved, record that as a blocking identity gap rather than treating the deployment set as
   complete.
   If no matching MR or remote source branch exists, first establish a pre-MR envelope from the
   exact local branch and HEAD, GitLab project, acting user, and exact target-branch endpoint. For a
   missing MR, complete the one-versus-two-MR deployment classification from the local ticket and
   diff before publishing or creating anything, and carry that count into the pre-MR envelope. Push
   the source branch normally when absent, restart the snapshot, create one MR only after proving
   again that no matching open MR exists, then restart from the canonical MR snapshot. Never create
   an MR from a detached HEAD, default/protected branch, ambiguous fork, empty/no-op branch, or
   unrelated dirty worktree.
2. Inspect applicable repository instructions, changed-path rules, ticket scope, implementation
   requirements, and exact CI path selection. Classify whether deployment requires an actual
   DevOps repository diff and/or an APP counterpart; record the evidence and update the required MR
   count. Reuse an existing worktree already checked out on the exact source branch rather than
   creating a duplicate. If APP is in the classified deployment set and its worktree does not
   exist, create or switch it from `/Users/louie/Documents/subanana/subanana-main` with the exact
   source-branch name, using
   `wt -C /Users/louie/Documents/subanana/subanana-main switch --create <source-branch>` only when
   the app branch is genuinely new, and omitting `--create` when it already exists.
3. Only when the deployment classification requires a DevOps repository MR, ensure the DevOps
   worktree exists on that same exact source-branch name. Use
   `wt -C /Users/louie/Documents/subanana/subanana-devops-main switch --create <source-branch>` when
   the DevOps branch is genuinely new, or omit `--create` when it already exists. Verify a newly
   created branch starts from the intended exact DevOps target before editing. If infrastructure
   changes are not required, do not create a DevOps worktree, branch, or MR.
4. When the classification requires both APP and DevOps MRs, discover the paired DevOps MR by exact
   DevOps project, same source-branch name, and intended target. Reuse one matching open MR only
   after verifying it contains a non-empty infrastructure diff. Reject multiple matches, an empty
   MR, or a same-ticket MR on a different branch.
   If no matching DevOps MR exists, defer creation until the required infrastructure implementation
   has a verified, non-empty diff against the exact DevOps target. Then commit the coherent DevOps
   batch, push the same-named branch normally when absent, prove again that no matching open MR
   exists, create exactly one DevOps MR, and restart with fresh snapshots of both MRs. Do not create
   or update the DevOps MR when the infrastructure classification is false.
   When a DevOps MR is primary and the classification also requires an APP MR, apply the same
   exact-project, source-branch, target, non-empty-diff, uniqueness, and fresh-snapshot gates to the
   APP counterpart; never treat the DevOps MR alone as the complete deployment set.
5. Resolve source/target drift for each required MR through GitLab-side rebase when safe and
   supported. Restart from a fresh paired snapshot after convergence.
6. Triage current findings into must-fix, suppress-with-reason, already-fixed-or-stale, or
   needs-human-decision. Classify an irrelevant, non-critical, or subjective comment as
   `suppress-with-reason` when exact-diff and repository-rule evidence proves that leaving the code
   unchanged carries no material risk; do not edit code merely to satisfy it. Apply and verify the
   documented canonical suppression rather than only resolving its discussion thread. Never
   suppress a valid error, a material risk, or an uncertain product or safety decision. A resolved
   thread alone is not a disposition.
7. Form small atomic repair batches within one repository at a time, add focused tests, and run
   service-free checks. Keep an active CI polling deadline; do useful local work between discrete
   polls.
8. Commit and normally push one coherent repair batch in one repository only after revalidating
   the classified MR set, authorization, worktree scope, and pipeline serialization.
9. For merge conflicts, use one detached loop-owned worktree and one ordinary two-parent merge
   commit against the exact target SHA. Ask for a decision when intent is not deterministic.
10. After every remote mutation in either repository, restart from the paired snapshot step. Never
    reason from stale state.
11. Stop only at the requested terminal condition or a genuine decision/authority boundary.

## Terminal conditions

For `mergeable`, require every required MR to have its current source SHA synchronized, conflict-free,
free of unresolved blocking findings, and supported by successful required exact-SHA CI evidence. For
`merged`, also revalidate merge authorization separately for every required MR; do not infer
authorization to merge the paired DevOps MR from an app-only merge request. Perform or observe each
authorized merge in dependency-safe order. Report every required MR identity and exact evidence, or
state which counterpart, if any, is not required; do not finish with a mere “next step” while an
authorized executable state remains.

## Final summary

Every terminal or blocked report must include a **Deployment MRs** block. State the exact number of
MRs required for complete deployment (`1` MR in the sole affected repository, or `2` APP + DevOps
MRs), then list each relevant MR with its project, IID, source/target branches, exact source SHA,
terminal status, and canonical GitLab URL as a Markdown link. For a paired deployment, include both
URLs and identify the dependency-safe merge/deployment order. For an APP-only deployment,
explicitly state that no DevOps MR is required; for a DevOps-only deployment, state that no APP MR
is required. Use one entry per MR rather than one umbrella link. If a required MR is missing,
ambiguous, or inaccessible, include `URL unavailable` with the reason and do not claim the deployment
is complete or the pair is mergeable.

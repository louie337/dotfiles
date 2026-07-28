---
name: ticket-loop
description: Implement a Linear ticket through an approved plan, serialized implementation and independent QA, whole-branch publication gating, GitLab MR creation, and MR-loop completion. Use when the user invokes $ticket-loop, supplies a Linear issue ID for end-to-end implementation, or asks to turn a ticket into a mergeable or merged MR.
---

# Ticket implementation loop

Own planning, workflow state, user decisions, Git/GitLab publication, and Linear reads in the root
thread. Delegate one approved implementation unit at a time to `ticket-loop-worker`, each exact
commit review to `ticket-loop-commit-qa`, and the final branch gate to `ticket-loop-integration-pm`.
Use `$mr-loop` after publication.

Read [references/lifecycle.md](references/lifecycle.md) before implementation.

## Parse and brief

Accept a Linear issue ID, optional plan preapproval, and optional target `mergeable` or `merged`;
default to `mergeable`. Read the issue and relevant repository code, instructions, CI rules, tests,
and architecture. Keep Linear read-only.

Before editing, present a newcomer-friendly briefing covering current behavior, affected components,
data/control flow, constraints, risks, acceptance criteria, verification mapping, and a commit-sized
plan. Require explicit approval unless the user preapproved the plan. Preapproval skips only the
pause, never the briefing.

## Execute

- Freeze an approved plan revision and immutable base SHA.
- Only when the resulting MR requires infrastructure changes, create the corresponding devops
  worktree from `/Users/louie/Documents/subanana/subanana-devops-main` with the exact implementation
  branch name that will become the MR source branch. Use
  `wt -C /Users/louie/Documents/subanana/subanana-devops-main switch --create <source-branch>` when
  the devops branch is new, or omit `--create` when it already exists. Do not create this worktree
  for an MR that does not require infrastructure changes.
- Assign exactly one coherent work unit with expected parent SHA, allowed scope, acceptance evidence,
  checks, and commit message.
- Make each work unit one small atomic commit containing a single logical concern that is
  independently reviewable and verifiable. Split unrelated changes into separate commits, keep
  required tests and documentation with the change they verify, and never combine independent
  concerns into one omnibus commit or fragment one tightly coupled change artificially.
- Allow one mutating worker at a time in the shared branch. Never parallelize shared-worktree edits.
- Revalidate the returned commit SHA and inspect its complete diff.
- Have a fresh QA agent independently review every exact commit. Repair failures through a new
  bounded worker assignment and QA cycle; never amend or rewrite history.
- Preserve unrelated work. Never reset, clean, stash, locally rebase, amend, or force-push.
- Run service-free local checks. Map service-heavy checks to exact automatic GitLab jobs; do not
  start infrastructure without explicit approval.

## Gate and publish

After all units pass commit QA, provide the integration PM an immutable envelope containing the issue
snapshot, approved plan, base/head SHAs, commit evidence, checks, CI mapping, and deferrals. Publish
only after a PASS against the unchanged exact HEAD.

Create the MR with the approved scope, evidence, pending automatic checks, and known deferrals.
Revalidate the remote source SHA after pushing. Then invoke `$mr-loop` with the MR URL and requested
target. During MR review triage, suppress irrelevant, non-critical, or subjective findings when the
exact diff and repository rules prove that leaving the code unchanged carries no material risk; do
not implement them merely to satisfy a comment. Follow
[Proportional Review Triage](../../../docs/mr-loop.md#proportional-review-triage) for the canonical
suppression comment, authorization, and verification lifecycle. Never suppress valid errors,
material risks, or uncertain product or safety decisions. Do not claim ticket completion merely
because an MR exists.

## Stop conditions

Stop for missing product intent, incompatible acceptance criteria, authority required for an
irreversible action, or a proven verification gap needing user-approved infrastructure. Otherwise
continue until the requested MR terminal condition is established with current evidence.

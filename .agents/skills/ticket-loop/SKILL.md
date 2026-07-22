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
- Assign exactly one coherent work unit with expected parent SHA, allowed scope, acceptance evidence,
  checks, and commit message.
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
target. Do not claim ticket completion merely because an MR exists.

## Stop conditions

Stop for missing product intent, incompatible acceptance criteria, authority required for an
irreversible action, or a proven verification gap needing user-approved infrastructure. Otherwise
continue until the requested MR terminal condition is established with current evidence.

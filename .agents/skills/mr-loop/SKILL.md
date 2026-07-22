---
name: mr-loop
description: Drive a GitLab merge request from its current exact SHA to mergeable or merged through guarded synchronization, review repair, CI triage, and conflict integration. Use when the user invokes $mr-loop, provides an MR URL and asks to repair or babysit it, or asks to continue until mergeable or merged.
---

# GitLab MR loop

Own the workflow in the root thread. Load `gitlab-cli-skills` and `glab` before using GitLab CLI.
Delegate bounded read-only investigations to the `mr-loop-review-investigator`,
`mr-loop-conflict-investigator`, or `mr-loop-ci-investigator` custom agents. Keep every mutation,
state transition, user decision, and final claim in the root thread.

Read [references/state-machine.md](references/state-machine.md) before the first mutation or when
resuming an interrupted loop.

## Parse the request

Accept an MR URL and optional target `mergeable` or `merged`; default to `mergeable`. Reject missing
or ambiguous identity before mutation. Treat a terminal request such as “finish” or “do not stop” as
persistence toward the target, not broader authorization.

## Invariants

- Never reset, clean, stash, locally rebase, amend, rewrite history, force-push, or discard work.
- Require a clean primary worktree before taking ownership. Do not absorb unrelated changes.
- Bind every decision to host, project, IID, source/target projects and branches, exact source SHA,
  and exact target SHA fetched from GitLab’s target-branch endpoint.
- Discard worker results when any bound identity or SHA changes.
- Keep Linear read-only. Use a matching ticket only as requirement evidence.
- Perform one pipeline-producing or merge-affecting mutation at a time, then rediscover canonical
  state before another.
- Do not create no-op commits, helper MRs, or pipelines merely to obtain CI evidence.
- Prefer existing automatic CI for service-heavy verification. Do not start local infrastructure
  without explicit user approval and isolated test resources.

## Operate the loop

1. Snapshot local Git state, remotes, GitLab identity, MR metadata, exact source/target SHAs,
   discussions, review findings, mergeability, and recursively expanded pipeline state.
2. Inspect applicable repository instructions, changed-path rules, and exact CI path selection.
3. Resolve source/target drift through GitLab-side rebase when safe and supported. Restart from a
   fresh snapshot after convergence.
4. Triage current findings into must-fix, suppress-with-reason, already-fixed-or-stale, or
   needs-human-decision. A resolved thread alone is not a disposition.
5. Batch compatible local repairs, add focused tests, and run service-free checks. Keep an active CI
   polling deadline; do useful local work between discrete polls.
6. Commit and normally push one coherent repair batch only after revalidating identity, SHAs,
   authorization, worktree scope, and pipeline serialization.
7. For merge conflicts, use one detached loop-owned worktree and one ordinary two-parent merge
   commit against the exact target SHA. Ask for a decision when intent is not deterministic.
8. After every remote mutation, restart from the snapshot step. Never reason from stale state.
9. Stop only at the requested terminal condition or a genuine decision/authority boundary.

## Terminal conditions

For `mergeable`, require the current source SHA to be synchronized, conflict-free, free of unresolved
blocking findings, and supported by successful required exact-SHA CI evidence. For `merged`, also
revalidate merge authorization and perform or observe the merge. Report exact evidence and any
non-blocking caveats; do not finish with a mere “next step” while an executable state remains.

---
name: mr-loop-evidence
description: Use for GitLab MR loop immutable evidence envelopes, read-only worker assignments, freshness checks, policy IDs, and stale-result rejection.
---

# MR Loop Evidence

This skill defines the shared contracts used by the `mr-loop` orchestrator,
its reusable skills, and its read-only investigator subagents.

## Policy IDs

- `INV-NO-HISTORY-REWRITE`: never reset, clean, stash, locally rebase, amend,
  rewrite history, force-push, force-with-lease, or discard user work.
- `INV-PRIMARY-MUTATION-OWNER`: only the primary `mr-loop` edits, stages,
  commits, pushes, replies, resolves discussions, requests rebase, cancels
  pipelines, merges, or changes Git branch pointers.
- `INV-EXACT-SHA-EVIDENCE`: every finding is bound to host, project path, IID,
  source project, target project, source branch, target branch, MR head SHA, and
  exact target-branch SHA from GitLab's target branch endpoint.
- `INV-DISCARD-STALE-WORK`: discard any worker result when MR identity, source
  SHA, or target SHA changes before the primary acts on it.
- `INV-PIPELINE-DEADLINE-FIRST`: active required CI owns the next deadline; no
  optional work or subagent result can delay the primary's due recursive poll.
- `INV-ONE-PIPELINE-MUTATION`: before a push, GitLab rebase, retry, cancellation,
  or merge-producing action, every relevant pipeline must be terminal; perform one
  mutation, then wait for its canonical pipeline before another.
- `INV-NO-PRESYNC-REPAIR`: before the synchronization gate opens, repair findings
  are provisional and cannot produce edits, commits, pushes, replies, discussion
  resolution, CI evaluation, or success claims. Safe merge-conflict integration is
  the only editing exception because it opens the gate.
- `INV-PRESYNC-CAUSAL-METADATA-REPAIR`: within that exact merge attempt only, a
  repository metadata path may be treated as a proven causal integration path
  when mandatory service-free validation fails solely on target-introduced
  immutable, generated, vendored, byte-identical, or canonical-source content;
  the path-scoped metadata rule is the smallest non-behavioral fix and preserves
  validation for first-party and unrelated paths. This extends conflict
  integration, not ordinary pre-synchronization repair.
- `INV-CONFLICT-COMMIT-PRESERVED`: after a conflict merge commit exists, never
  abort, amend, delete, reset, rebase, rewrite, or hide it; preserve it under
  `refs/mr-loop/conflicts/<conflict-attempt-id>` on concurrency or push
  failure.

## Immutable Assignment Envelope

Every read-only worker assignment must include this envelope:

```json
{
  "mrUrl": "https://gitlab.example.com/group/project/-/merge_requests/123",
  "host": "gitlab.example.com",
  "projectPath": "group/project",
  "iid": 123,
  "sourceProjectPath": "group/project",
  "targetProjectPath": "group/project",
  "sourceBranch": "feature/SUB-1234-example",
  "targetBranch": "main",
  "expectedSourceSha": "<exact-mr-head-sha>",
  "exactTargetSha": "<target-branch-api-sha>",
  "snapshotCollectedAt": "<iso-8601>",
  "pollDeadline": "<iso-8601-or-null>",
  "scope": ["path/or/discussion/or/job"],
  "question": "one narrow read-only question"
}
```

Workers must not infer missing identity fields. If the envelope is incomplete,
return `status=needs_primary_reassignment` with `missingInput` and do not inspect
unrelated context. This is not a blocker or terminal state; it tells the primary
`mr-loop` agent to supply a complete envelope, narrow the scope, or perform the
reasoning itself.

## Worker Result Contract

Read-only workers return concise evidence, not patches:

```json
{
  "status": "ok|no_finding|needs_primary_reassignment|stale_risk",
  "identity": {
    "expectedSourceSha": "<same-as-assignment>",
    "exactTargetSha": "<same-as-assignment>"
  },
  "scopeReviewed": ["path/or/discussion/or/job"],
  "missingInput": ["field-or-scope-needed"],
  "findings": [
    {
      "location": "path:line or GitLab object ID",
      "problem": "bounded technical issue",
      "evidence": "file lines, blob stage, job trace, discussion text, or rule",
      "recommendation": "smallest safe primary-agent action",
      "risk": "residual uncertainty or none"
    }
  ],
  "mustDiscardIf": ["source sha changed", "target sha changed", "identity changed"]
}
```

Do not return edited file content unless the primary explicitly requested a small
snippet for review. Do not run mutating commands.

## Parallel Dispatch Rules

- Dispatch independent read-only scopes in parallel only after a fresh immutable
  envelope exists.
- Prefer smaller workers: one conflict group, one discussion cluster, one failed
  job family, or one focused code area per task.
- Treat `needs_primary_reassignment` as a primary-agent routing signal, never as
  a terminal blocker. The primary owns replanning, rescoping, and any judgment
  needed to keep the MR loop automatic.
- Never wait for optional workers while `next_pipeline_poll_deadline` is due.
- The primary must revalidate the assignment envelope immediately before acting
  on a result.
- A worker recommendation is advisory. The primary independently verifies it
  before editing or writing to GitLab.

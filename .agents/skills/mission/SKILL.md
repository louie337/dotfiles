---
name: mission
description: Execute a large approved or user-provided implementation plan through dependency-aware parallel Codex subagents, milestone integration, and whole-result validation. Use when the user invokes $mission, asks to execute a multi-phase plan autonomously, or has several independent features that benefit from parallel workers.
---

# Mission execution

Keep mission control in the root thread: requirements, decomposition, dependency graph, worker
assignments, integration decisions, user decisions, and completion evidence. Use native Codex
subagents for independent bounded work; never launch nested CLI processes or shell supervisors.

## Prepare

1. Acquire the plan from the current conversation, a supplied document, or a read-only issue lookup.
2. Inspect repository instructions and enough code to validate the plan’s assumptions.
3. Split work into features with explicit scope, dependencies, acceptance evidence, writable paths,
   and validation commands.
4. Identify conflicts before delegation. Serialize work that shares files, generated outputs,
   migrations, schemas, or mutable infrastructure.

## Execute

- Spawn parallel agents only for genuinely independent work.
- Give each agent a bounded brief with repository root, expected base SHA, allowed scope, forbidden
  scope, acceptance criteria, checks, and required result format.
- Prefer custom specialist agents when their descriptions match; otherwise use Codex’s worker.
- Keep at most one mutating agent per shared path set. Parallel read-only investigation freely.
- Treat agent reports as advisory. Inspect diffs and revalidate SHAs before integration.
- When a worker needs architecture, product, or scope judgment, decide in the root thread or ask the
  user; do not let the worker broaden its assignment.

## Integrate and finish

Integrate completed features in dependency order. Run focused checks after each integration boundary
and a whole-plan validation at the end. Review the final diff against every acceptance criterion and
remove accidental scope. Report implemented features, verification, remaining authorized deferrals,
and any remote checks still pending. Do not declare success while an approved executable unit remains.

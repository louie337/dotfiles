---
name: mission
description: Mission mode — break a large plan into features, spawn parallel worker agents, coordinate dependencies, and track progress. Use when the user wants to execute a multi-phase implementation plan autonomously.
metadata:
  author: subanana
---

# Mission Mode

Execute large, multi-feature implementation plans by orchestrating parallel worker agents. Inspired by Factory Droid's Mission Mode — you are the mission controller.

## When to use

- User says "/mission" with a Linear issue ID, a plan description, or asks to "run the mission"
- User wants to execute a structured implementation plan across multiple files/services
- Work can be parallelized into independent features or phases

## Mission Controller Role

You are **Mission Control**. You do NOT write code yourself. You:
1. Build or receive a structured plan
2. Break it into parallelizable work units (features)
3. Spawn worker agents for each unit
4. Track progress, unblock workers, handle failures
5. Coordinate handoffs between dependent phases
6. Validate results at each milestone

## STEP 1: Acquire the Mission Plan

Determine where the plan comes from:

**Option A — Linear issue**: If the user provides a Linear issue ID (e.g., "SUB-500"), fetch it using the available Linear MCP `linear_get_issue` tool. Parse the description for structured sections: phases, tasks, edge cases, acceptance criteria. Reading a ticket does not authorize comments, status transitions, or other Linear writes.

**Option B — Inline plan**: If the user describes the work, collaborate to structure it into the mission format below.

**Option C — Current conversation**: If a plan was already discussed in the conversation, use that.

## STEP 2: Structure the Mission

Organize the work into this hierarchy:

```
Mission: {title}
  Phase 1: {name} — {goal}
    Feature 1.1: {name}
      - Tasks: [list]
      - Files: [expected files to touch]
      - Dependencies: [none | feature IDs that must complete first]
      - Validation: [how to verify success]
    Feature 1.2: {name}
      ...
  Phase 2: {name} — {goal}
    ...
  Acceptance Criteria:
    - [list from plan]
```

**Rules for structuring:**
- Features within a phase that have NO dependencies on each other MUST be marked as parallelizable
- Features that depend on other features MUST list those dependencies explicitly
- Each feature should be a coherent unit of work that one agent can complete (typically 1-5 files)
- Proto/schema changes that other features depend on should be their own feature in an early phase
- Keep phases small enough that you can validate before moving on

## STEP 3: Present Plan and Get Approval

Show the user the structured mission plan in a clear table format:

```
## Mission: {title}

### Phase 1: {name}
| # | Feature | Parallel? | Depends on | Est. files |
|---|---------|-----------|------------|------------|
| 1.1 | ... | Yes | — | 3 |
| 1.2 | ... | Yes | — | 2 |
| 1.3 | ... | No | 1.1 | 1 |

### Phase 2: {name}
| # | Feature | Parallel? | Depends on | Est. files |
...
```

**Wait for user approval before executing.** The user may want to:
- Reorder features
- Remove or add features
- Change parallelization strategy
- Skip phases
- Adjust scope

If the user says "go", "run it", "execute", or similar — proceed to execution.

When another primary workflow uses Mission for planning only, stop after returning the approved,
versioned plan to that parent workflow. Do not spawn Mission workers. A parent may bypass the pause
only when its invocation contains an explicit autonomous-plan flag such as `--approve-plan`; absence
of that flag always requires user approval.

## STEP 4: Execute Phase by Phase

For each phase, follow this protocol:

### 4a. Launch parallel workers

For all features in the current phase that have no unmet dependencies, spawn worker agents **in a single message** using the Agent tool. This is critical for parallelism.

Each worker agent prompt MUST include:
1. **Mission context**: Brief summary of the overall mission goal
2. **Feature assignment**: Exact description of what this worker must implement
3. **Scope boundaries**: Which files to touch, which NOT to touch
4. **Coding instructions**: Reference to CLAUDE.md conventions, proto patterns, etc.
5. **Dependencies satisfied**: Any outputs from previously completed features that this worker needs
6. **Validation criteria**: How the worker should verify its own work (compile, test, lint)
7. **Explicit instruction to write code**: Tell the agent it must implement, not just research
8. **Test requirements**: What tests to write or update — every feature worker must include unit tests for the code it touches

**Worker agent prompt template:**
```
You are a worker agent executing Feature {id} of Mission "{title}".

## Mission Context
{1-2 sentence summary of the overall mission}

## Your Assignment: {feature name}
{detailed description of what to implement}

## Scope
- Files to create/modify: {list}
- Files NOT to touch: {list}
- Branch: Work on the current branch

## Technical Context
{relevant architecture notes, patterns to follow, conventions from CLAUDE.md}

## Dependencies
{outputs from prior features, e.g., "Proto changes from Feature 1.1 are already merged — the new enum values are available"}

## Validation
After implementation:
{specific validation steps — compile, test, lint commands}

## Tests
You MUST write or update unit tests for the code you implement:
- Backend (Kotlin/JUnit): Add tests in the corresponding test directory mirroring the source path
- Frontend (React/Vitest): Add tests alongside components or in __tests__ directories
- Tests must cover: happy path, key edge cases, and error/failure paths
- Run the tests and confirm they pass before reporting completion
{specific test instructions for this feature}

## Important
- Follow the project's CLAUDE.md conventions
- Do NOT modify files outside your scope
- If you encounter a blocker, document it clearly in your response rather than guessing
- Do NOT skip tests — implementation without tests is incomplete
```

### 4b. Monitor and coordinate

After spawning workers:
- Report to the user which workers are running and what they're doing
- When workers complete, summarize their results
- If a worker fails or hits a blocker:
  - Analyze the failure
  - Decide: retry with adjusted prompt, or escalate to user
  - Do NOT retry more than once without user input

### 4c. Validate milestone

Before moving to the next phase:
- Run any relevant build/compile/test commands to verify the phase's work
- Run the test suite for affected modules to confirm all tests pass (including newly added tests)
- Check that all features in the phase completed successfully
- Report status to the user:

```
## Phase {n} Complete

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1.1 | ... | Done | — |
| 1.2 | ... | Done | — |
| 1.3 | ... | Blocked | {reason} |

Validation: {build/test results}
```

- If all features passed: proceed to next phase (or ask user)
- If any features failed: present options to the user (retry, skip, adjust plan)

### 4d. Advance to next phase

Repeat 4a-4c for each phase. Between phases:
- Summarize cumulative progress
- Note any plan adjustments needed based on what was learned
- Get user go-ahead for the next phase if the plan changed

## STEP 5: Mission Complete

When all phases are done:

1. Run final validation (full build, test suite, lint)
2. Present a mission summary:

```
## Mission Complete: {title}

### Results
| Phase | Features | Passed | Failed | Skipped |
|-------|----------|--------|--------|---------|
| 1 | 3 | 3 | 0 | 0 |
| 2 | 4 | 3 | 0 | 1 |

### Files Changed
{list of all files created/modified across all workers}

### Acceptance Criteria
- [x] Criterion 1
- [x] Criterion 2
- [ ] Criterion 3 (skipped: reason)

### Remaining Work
{anything that was deferred, blocked, or needs manual follow-up}
```

3. If the mission originated from a Linear issue, offer to update the issue with results

## Guidelines

- **You are the controller, not a worker.** Do not write implementation code yourself. Spawn agents for all code work.
- **Maximize parallelism.** Always launch independent features simultaneously in a single message with multiple Agent tool calls.
- **Fail fast, escalate early.** If a worker fails twice on the same task, stop and ask the user. Don't burn context retrying.
- **Keep the user informed.** Report status at natural milestones (phase start, phase complete, blockers). Don't go silent during long executions.
- **Respect scope.** Workers should not modify files outside their assigned scope. If cross-cutting changes are needed, that's a new feature or a coordination issue for Mission Control to handle.
- **Use worktree isolation when appropriate.** For features that modify the same files or might conflict, use `isolation: "worktree"` on the Agent tool to give workers their own copy. Merge results afterward.
- **Tests are mandatory.** Every feature worker must write unit tests for the code it implements. A feature without tests is not complete. Backend: JUnit Jupiter tests. Frontend: Vitest tests. Workers must run their tests and confirm they pass before reporting done.
- **Documentation is part of the mission.** Per CLAUDE.md, every non-docs-only change needs changelog and feature notes. Include documentation as a feature in the final phase or as part of each worker's scope.

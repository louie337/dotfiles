---
name: conflict-aware-developer
description: Adopt a mindset that prevents parallel edit conflicts by assessing overlap risk, isolating work via git worktree when needed, and coordinating hand-offs between agents or subagents.
license: MIT
compatibility: opencode
metadata:
  audience: agents, subagents
  workflow: parallel-development
---

## What I do

I help agents avoid edit conflicts when multiple agents or subagents are working on the same codebase — either in sequence or in parallel. I assess risk, choose isolation strategies, coordinate hand-offs, and clean up safely after finishing.

---

## Conflict Risk Assessment

Before touching any file, ask:

1. **Is this file shared?** Screens, core services, config files, and theme tokens are high-risk shared areas.
2. **Is another agent working nearby?** If another helper has been assigned to a related area, the risk of conflict is high.
3. **How broad is the change?** A single isolated component is low risk. Cross-cutting changes (e.g., theme, routing, API layer) are high risk.

**Decision rule:**
- Low risk (isolated file, no parallel agent) → work directly in the current tree.
- High risk (shared files, parallel agents) → isolate in a `git worktree` branch first.
- Always document your decision: state *why* you chose isolation or not.

---

## When to use git worktree

Use `git worktree` when:
- You are assigned a subtask that touches shared areas (`src/components`, `src/theme`, `src/services`, `src/config`).
- Another agent or subagent is actively working in the same repository.
- The scope of your change spans multiple directories.

Do **not** use `git worktree` when:
- The change is confined to a single screen or a clearly owned module.
- You are the only agent working in the repo right now.
- The task is a quick read-only analysis.

---

## Worktree lifecycle

When isolation is appropriate, follow this lifecycle strictly:

1. **Create**: Use the `worktree_create` tool (or `bash`) to spin up an isolated branch:
   ```
   git worktree add ../<feature-name> feature/<feature-name>
   ```
2. **Work**: Make all edits, run tests, and verify within that worktree directory only.
3. **Report**: Before merging, produce a short summary: branch name, files changed, test results.
4. **Merge**: Switch to main and merge:
   ```
   git switch main && git merge feature/<feature-name>
   ```
5. **Clean up**: Use the `worktree_cleanup` tool only **after confirming the branch was merged** and **only with explicit permission** from the coordinator or user. Never self-clean without confirmation.

---

## Hand-off protocol

When delegating to a subagent or receiving work from one:
- State clearly which files and directories each agent owns.
- Log the worktree path so other agents can discover it.
- Before merging another agent's branch, run a diff to verify no unintended overlaps.

---

## When to use me

Load this skill whenever:
- You're about to start a task that might conflict with another agent's work.
- You've been assigned parallel work on a shared codebase.
- You're the coordinator managing multiple subagents across the same repo.
- You need to decide whether to create or skip a worktree for the current task.

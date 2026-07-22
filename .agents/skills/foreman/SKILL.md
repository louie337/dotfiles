---
name: foreman
description: Execute an approved implementation plan as serialized commit-sized work units with one Codex worker and a fresh independent QA agent per unit. Use when the user invokes $foreman or asks for high-rigor, one-commit-at-a-time implementation where auditability matters more than parallel speed.
---

# Foreman execution

Keep planning, sequencing, state, and acceptance decisions in the root thread. Use native Codex
subagents; never launch tmux, another CLI process, or a shell agent supervisor.

## Contract

- Start from an approved plan, known base SHA, and clean understanding of unrelated work.
- Convert each plan unit into one coherent commit with explicit expected parent SHA, allowed paths,
  acceptance evidence, checks, and commit message.
- Run exactly one mutating worker at a time in the shared worktree.
- After each returned commit, revalidate its parent/SHA and inspect the complete diff.
- Spawn a fresh read-only QA agent that distrusts the implementation report and verifies scope,
  behavior, regression tests, and feasible service-free checks.
- A failed QA verdict produces a new focused repair unit and normal commit. Never amend, reset,
  locally rebase, stash, clean, or rewrite history.
- Keep the branch coherent and service-free checks passing after every accepted commit.

## Verification

Run formatting, static analysis, compilation, documentation checks, and focused tests that do not
require material infrastructure. Map service-heavy validation to existing CI when its configuration
proves coverage. Ask before starting containers, databases, browser stacks, or shared services.

Finish with a whole-branch review against the approved plan, exact base/head SHAs, accepted QA
reports, and remaining deferrals. Return an auditable summary of commits and verification evidence.

---
name: foreman
description: >-
  Foreman mode orchestrates high-rigor implementation as serialized, one-commit work units on one
  branch. It uses OpenCode task subagents for implementation and independent adversarial QA, keeps
  the branch green after every commit, and never launches tmux or external agent processes. Use for
  approved plans where correctness and commit-level evidence matter more than parallelism.
metadata:
  author: subanana
---

# Foreman Mode

Foreman is an execution protocol for a PM/controller. The controller does not implement code. It
assigns every implementation, test, and review operation to OpenCode subagents through the `task`
tool. Never launch tmux, `claude -p`, another OpenCode process, or a shell-based agent supervisor.

Distinct from `mission`: Mission can fan out independent features whose workers self-validate.
Foreman serializes one commit per plan unit on one shared branch and requires a fresh, independent
QA worker to distrust and verify each implementation worker's result.

## Verification Policy

Keep local verification service-free by default. Formatting, static analysis, compilation,
documentation checks, and focused or unit tests known not to require external services are normal
local checks. Database integration, backend-service integration, Docker-dependent,
browser/Playwright, full-stack, preview-environment, and similar expensive verification belongs to
existing automatic path-selected GitLab CI whenever that coverage can be proven from the target
repository's CI configuration.

Never run `just infra-up`, Docker Compose, containers, local databases, queues, object stores,
backend stacks, browser stacks, or similar infrastructure merely to reproduce verification covered
by GitLab CI. If CI cannot run yet, run the available service-free checks and report exact remote
jobs as pending. Do not push, create or update an MR, or add a no-op commit solely to trigger CI;
Foreman never publishes in any case.

Do not invent CI job names or coverage. Temporarily inaccessible or incomplete CI evidence is
pending, with the failed evidence source recorded. Only readable, complete CI configuration and path
rules can prove missing automatic remote coverage and establish a gap with an expected CI follow-up.
If local infrastructure is genuinely needed for that proven gap, return it to the parent so it can
explain the need and obtain user approval before startup. After approval, the parent must include the
authorization and boundary in a worker brief; use a targeted workflow for only the required
dependency and never start an entire stack for one service. Treat local infrastructure as an opt-in
debugging fallback and never use production or shared customer data in place of isolated test
resources.

## Inputs

Require an approved plan containing, for every work unit:

- Stable ID, objective, and acceptance criteria.
- Expected file scope and explicit dependencies.
- Required tests and runtime evidence.
- Commit message.
- STOP conditions for invalid assumptions or expanded product scope.

Record the immutable plan revision, base SHA, current branch, and repository path before execution.
The parent controller owns `/tmp/<workflow>/progress.md` and `implementation-notes.md`; workers
return reports to the controller and must not concurrently edit shared workflow artifacts.

## Serialized Loop

For each work unit, in dependency order:

```text
implementation worker -> commit -> fresh QA worker -> PASS
                                      |
                                      +-> FAIL -> focused fix worker -> fresh re-QA
```

Rules:

1. Launch exactly one mutating worker at a time on the shared branch.
2. Use the OpenCode `task` tool and an appropriate repository-configured execution agent. Do not
   ask the user to choose an external worker model.
3. The implementation worker must read repository instructions, implement only its assigned unit,
   add or update tests, run focused service-free validation in the foreground, and create exactly one
   normal commit. The only exception is a targeted local dependency check whose brief includes the
   user's explicit approval and isolation boundary. It must report automatic remote jobs as pending
   evidence sources and proven remote coverage gaps by name. Never amend, rebase, reset, clean,
   stash, force-push, or push.
4. Re-read `HEAD`, status, and the committed diff after the worker returns. Reject a report whose
   expected parent SHA or resulting SHA does not match the branch.
5. Launch a fresh read-only QA worker for the exact commit SHA. QA must inspect scope, re-run feasible
   service-free checks, assess test fidelity, verify the hard behavioral claim independently where
   possible, and audit remote-job mappings and gaps without starting infrastructure.
6. QA returns `VERDICT: PASS`, `VERDICT: FAIL`, or `VERDICT: BLOCKED`, followed by exact evidence.
7. On FAIL, launch one focused mutating fix worker using the findings, then launch a fresh QA worker.
   The parent workflow defines retry limits. Never hide a failed verdict by folding it into the next
   unrelated work unit.
8. On BLOCKED or a STOP condition involving requirements, product behavior, irreversible action, or
   expanded scope, return the decision to the parent controller.
9. Update progress and decision artifacts after each worker result. The controller writes these
   updates so they remain serialized and resumable.

## Worker Brief

Every implementation or fix brief includes:

- Workflow and approved-plan context.
- Exact expected parent SHA and current branch.
- One work unit and one commit message.
- Allowed and forbidden file scope.
- Repository instructions and relevant prior decisions.
- Acceptance criteria, tests, runtime evidence, and STOP conditions.
- An explicit instruction to implement, run service-free validation in the foreground, commit
  normally, and report the resulting SHA, commands run, pending automatic CI jobs or evidence, and
  proven coverage gaps.

Every QA brief includes:

- Immutable base, parent, and commit SHAs.
- The work-unit requirements and forbidden paths.
- The implementation report as untrusted context.
- Mandatory `git show --stat` scope inspection and independent feasible service-free checks.
- The highest-risk behavior, race, migration, security property, or equivalence claim to challenge.
- A requirement to identify fake-fidelity tests and named verification deferrals.

## Completion Contract

Foreman completes only when every planned unit has a matching normal commit and an independent PASS
verdict, the worktree is clean, and branch-wide service-free validation passes. A PASS may carry
resource-heavy verification as pending when mapped to exact automatic GitLab jobs, when its evidence
source is temporarily unavailable, or when recorded as a proven remote coverage gap; it must not
claim those checks passed. Foreman returns the exact base SHA, HEAD SHA, commit list, progress
artifact, decision log, validation evidence, pending remote jobs or evidence, proven coverage gaps,
and known deferrals to its parent controller. Foreman does not push, create an MR, merge, or update
external tickets.

# GitLab MR Agent Loop

## Source Of Truth

The active MR loop is the Codex skill at `.agents/skills/mr-loop/SKILL.md`. Invoke
it as `$mr-loop` with an MR URL and optional `mergeable` or `merged` target. The
root Codex thread owns the state machine, scheduling, mutations, and final claims.

Its compact canonical transition map is
`.agents/skills/mr-loop/references/state-machine.md`. Read-only investigation is
delegated to the custom agents under `.codex/agents/`:

- `mr-loop-review-investigator`
- `mr-loop-conflict-investigator`
- `mr-loop-ci-investigator`

The previous OpenCode definitions remain temporarily under `.config/opencode/`
as migration reference and rollback material; they are no longer authoritative.
The historical controller is `.config/opencode/agents/mr-loop-mastermind.md`, and
its historical supporting source set is `.config/opencode/skills/mr-loop-*/SKILL.md`.
Their reusable procedure split was:

- `mr-loop-evidence`: immutable evidence envelopes, policy IDs, worker result
  contracts, and stale-result rejection.
- `mr-loop-snapshot`: startup checks, exact MR snapshots, target-branch evidence,
  discussion pagination, and same-SHA evidence collection.
- `mr-loop-synchronization`: source convergence, exact target synchronization,
  GitLab-side rebase, and guarded local branch realignment.
- `mr-loop-conflict-analysis`: read-only conflict classification, generated-file
  detection, deterministic intent evidence, and worker guidance.
- `mr-loop-conflict-integration`: isolated exact merge fallback, conflict phases,
  `resolved_uncommitted` boundary, commit/push, cleanup, and interruption
  recovery.
- `mr-loop-review-repair`: exact-SHA agent-review triage, proportional repair or
  suppression, discussion repair, local repair batching, and autonomous
  engineering decisions.
- `mr-loop-pipeline`: exact-SHA recursive CI graph polling, failed-job
  classification, pipeline serialization, and guarded cancellation.
- `mr-loop-linear-context`: exact Linear lookup from `SUB-[0-9]+` source branches
  and domain conflict precedence.

The Codex migration contract is `tests/codex-migration-test.sh`. The legacy
OpenCode policy contract remains `tests/mr-loop-test.sh`. Structured conflict
transition cases are in `tests/fixtures/mr-loop-conflict-scenarios.json`, and
proportional review dispositions are in
`tests/fixtures/mr-loop-review-triage-scenarios.json`.

The dotfiles repository is installed with Stow, so `~/.codex/config.toml`,
`~/.codex/AGENTS.md`, `~/.codex/agents/`, and `~/.agents/skills/` resolve to these
source-controlled definitions. Edit repository files, not generated installation
paths. Older documents
under `docs/superpowers/` describe the removed `.local/bin/mr-loop` shell
supervisor and are retained only as historical records.

## Worker Model

The primary agent may invoke hidden read-only subagents for parallel evidence
collection:

- `mr-loop-review-investigator` inspects independent diff, code, and discussion
  scopes.
- `mr-loop-conflict-investigator` analyzes independent conflict groups under
  exact source and target SHAs.
- `mr-loop-ci-investigator` classifies focused exact-SHA failed CI traces,
  bridges, and downstream jobs.

Workers receive immutable envelopes from `mr-loop-evidence` and return advisory
evidence only. They cannot edit files or perform Git/GitLab mutations. The
primary discards worker results if MR identity, source SHA, or target SHA changes
before action.

## Safety Boundaries

Local rebase, reset, clean, stash, amend, force-push, force-with-lease, history
rewrite, and discarded user work remain prohibited at the agent permission layer.

Only the primary loop edits, stages, commits, pushes, replies, resolves
discussions, requests GitLab rebase, cancels pipelines, merges, moves branch
pointers, or changes loop state.

The synchronization gate must open before ordinary repair. Safe merge-conflict
integration is the sole editing exception and uses an isolated detached worktree,
`git merge --no-ff --no-commit <exact-target-sha>`, deterministic resolution,
focused verification, a preserved two-parent merge commit, one normal push, and a
fresh startup after SHA convergence.

`INV-PRESYNC-CAUSAL-METADATA-REPAIR` narrowly extends that integration attempt.
When mandatory service-free validation fails solely on target-introduced content
that documented vendor, generated, byte-identical, immutable, or canonical-source
rules prohibit editing, the same merge commit may include the smallest exact-path
metadata rule needed to validate the complete candidate. The loop must prove
protected bytes unchanged, intended and unrelated path behavior, complete staged
scope, and no product/runtime/security/deployment/schema decision. Broad
validation weakening and unrelated cleanup fail closed. A target-owned failure
does not automatically create a helper MR; an explicitly authorized helper MR
cannot merge on path-selected CI alone without equivalent required coverage.

Active required CI owns a hard recursive-poll deadline no later than 30 seconds
after each complete graph snapshot. Optional workers and broad investigation
cannot delay that poll.

## Proportional Review Triage

After synchronization, MR-loop inventories every finding in the latest trusted
agent-review report, including findings whose inline thread was manually
resolved. It binds each finding to the exact source SHA, exact target SHA, trusted
review head/base markers, stable finding ID, cited rule, severity, bot identity,
and human adjudication evidence.

The canonical policy in `mr-loop-review-repair` assigns exactly one disposition:

- `must-fix`: a valid error or any material business, security, authorization,
  data, compatibility, parity, documentation, accessibility, reliability,
  performance, resource, or operational risk. Material warnings are fixed too.
- `suppress-with-reason`: a non-blocking false positive, explicit rule exception,
  accepted tradeoff, or harmless preference with evidence that leaving the code
  unchanged carries no material risk.
- `already-fixed-or-stale`: the finding no longer applies to the exact current
  SHA. MR-loop makes no code edit and waits for the documented review lifecycle.
- `needs-human-decision`: product intent, safety, rule applicability, or an
  acceptable tradeoff remains uncertain. The finding stays unresolved and blocks
  merge readiness pending the exact human decision.

Severity informs the decision but does not replace risk analysis. MR-loop never
suppresses a warning that exposes a real regression and never suppresses a valid
error merely to make CI green. For `must-fix`, it follows the cited rule's
`## Fix`, makes the smallest correct repair, adds focused regression tests when
behavior changes, and uses required commit references such as
`Fixes RULE-0007`.

Suppression is a guarded GitLab side effect owned by the primary agent. The loop
uses only an exact finding ID from the trusted report or bot marker, proves its
acting GitLab user has Developer-or-higher access, and posts one non-resolvable MR
comment with both lines:

```text
agent-review: suppress <exact-finding-id>

Reason: <evidence from the exact diff and repository rules>
```

It then re-fetches the comment and membership evidence. Missing authorization,
an unavailable member lookup, a missing reason, or a failed post-write check
leaves suppression incomplete. Loop-authored completion evidence must use the
canonical whole comment body with exactly one finding ID and one `Reason:`; a
quote, code block, negation, or multi-ID directive is not accepted as the loop's
proof. After posting, the loop revalidates the exact source SHA, exact target SHA,
review head/base markers, finding body, discussion, persisted comment, actor, and
membership before recording the side effect. The next normal
`mr:review:agent` run applies the directive. If exact head/base dedup prevents
that run, the loop may manually resolve only the matching verified bot-created
thread after the suppression is verified. Manual resolution by itself is never a
finding disposition.

Every finding disposition and its completion evidence are part of merge
readiness. There must be no valid error, pending fix/stale lifecycle, or human
decision remaining, and final required documentation plus the repository's
branch-wide review-rule dispatch must match the final diff. In Subanana, that
final dispatch is:

```sh
git diff --name-only master... | node scripts/rules-for-paths.js -
```

The loop first proves local `master` equals GitLab's exact target SHA. If it does
not, the loop leaves the branch untouched and also dispatches the authoritative
immutable diff:

```sh
git diff --name-only <exact-target-sha>...<expected-source-sha> | node scripts/rules-for-paths.js -
```

An `already-fixed-or-stale` finding completes only after a trusted exact-current
review omits it. While that automatic review is pending, the loop may report
`awaiting_review_lifecycle`; if no normal review path exists, it returns
`manual_action_required` rather than creating a no-op commit or waiting forever.

Failed CI remains independent of review-thread triage. MR-loop still traverses
the exact-current-SHA parent, child, bridge, and downstream pipeline graph, reads
failed job traces, and repairs deterministic code failures through
`mr-loop-pipeline`. Pipeline failures cannot be suppressed through an
agent-review finding or hidden by resolving its thread.

## Verification Policy

MR-loop runs service-free checks locally first: formatting, static analysis,
compilation, documentation checks, and focused or unit tests known not to require
external services. It inspects the target repository's GitLab CI includes, job
commands, and path-selection rules, then records exact automatic jobs that cover
database integration, backend services, Docker, browser/Playwright, full-stack,
preview environments, or other resource-heavy verification. It never invents a
job name or infers coverage from a name alone.

Every mapped verification-required job is paired with its expected pipeline graph
and must appear and succeed there, even if GitLab marks it `allow_failure`. A
same-named job in another graph is not a substitute. MR-loop does not become
mergeable while mapped jobs or CI evidence are pending. In an expected completed
graph, an absent, `manual`, `skipped`, or otherwise terminal non-successful mapped
job is a selection/execution gap, not a passing result; the agent does not play it
or replace it with local verification.

Resource-heavy verification defaults to those exact-SHA GitLab jobs. MR-loop does
not run `just infra-up`, Docker Compose, local databases, service stacks, browser
stacks, or preview environments merely to reproduce CI. It also never creates a
no-op commit, pushes unchanged code, updates an MR, or explicitly creates a
pipeline solely to trigger verification. Normal synchronized repair pushes remain
allowed because they publish actual code intended to merge and automatically
select CI by path.

If automatic remote verification or its configuration is temporarily not
observable, MR-loop runs available service-free checks and reports the evidence
as pending without inventing job names. A coverage gap requires readable,
complete CI configuration and path rules proving no automatic equivalent. A
mapped job omitted by its expected complete terminal graph is instead a
non-substitutable selection gap. A no-capability gap is recorded with an expected
CI follow-up, not treated as permission to start local services. If local
infrastructure is genuinely necessary, the agent explains the gap and asks first;
approval permits only a targeted dependency using isolated test data. A
successful approved fallback remains bound to the exact SHA and does not erase
the reported CI gap. Whole-stack startup for one service and production or shared
customer data are prohibited. Documented local startup procedures remain opt-in
fallbacks for explicit reproduction or interactive debugging requests.

## Testing Note

Run the Codex migration contract after changing the skill, custom agents,
configuration, or this documentation:

```sh
sh tests/codex-migration-test.sh
```

When changing retained OpenCode rollback material, also run its legacy contract:

```sh
sh tests/mr-loop-test.sh
```

Before completion, also run `git diff --check` and review the branch-wide diff.
This repository has no separate executable path-rule dispatcher; the test above
is the applicable repository-local rule check. The MR agent itself must discover
and run a target repository's dispatcher and path-specific instructions before
editing conflicts and branch-wide before completing an MR repair.

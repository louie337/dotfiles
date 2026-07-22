---
name: mr-loop-review-repair
description: Use for GitLab MR loop exact-SHA finding triage, proportional repair or suppression, unresolved discussion handling, and local repair batching.
---

# MR Loop Review Repair

Before the synchronization gate opens, this skill may build a provisional local
repair batch only in a dedicated detached worktree rooted at the exact source SHA.
Keep the primary worktree clean; the isolated index may preserve the batch, but do
not commit it or move a branch ref. Treat every finding and check as provisional.
After synchronization, revalidate against the fresh post-sync diff and port only
the still-applicable changes into the primary worktree before commit or push.

## Review Priorities

For every new MR SHA, review the diff for blockers before waiting on CI. Focus on
correctness, security, required behavior, and missing tests. Avoid cosmetic churn.

Read-only review investigators may inspect independent files, discussion groups,
or code areas in parallel using the assignment envelope from `mr-loop-evidence`.
Their findings are advisory and expire when source SHA, target SHA, or identity
changes.

Once an exact-SHA CI or review failure is classified as deterministic and
repairable, begin the local repair immediately. Do not wait for unrelated active
jobs or automatic retries when existing evidence is sufficient. During active CI,
continue fetching evidence, inspecting and editing exact-SHA code, adding tests or
required documentation, running service-free focused checks, and maintaining one
uncommitted repair batch. Yield at bounded safe checkpoints for recursive polling
no later than `next_pipeline_poll_deadline`; never sleep while safe actionable
repair work remains.

Active CI forbids remote side effects: do not push, retry or cancel CI, request
rebase, merge, post to or resolve any discussion, including discussion actions
dependent on unpushed changes, or perform another pipeline-producing mutation.
Read-only investigators may analyze known failures concurrently under the
`mr-loop-evidence` handoff contract, but must never mutate files, Git state, or
GitLab.

## Agent-Review Finding Triage

This section is the canonical classification policy for findings emitted by the
repository's agent-review system. A discussion is an agent-review finding only
when the snapshot contains its exact stable finding ID from the review report or
`<!-- mr-review-finding-id: <id> -->` marker. Never calculate, infer, repair,
borrow, or reuse an ID. If identity is missing or ambiguous, use
`needs-human-decision` and do not suppress.

Re-evaluate every finding after synchronization and against one immutable
source/target SHA envelope. Read and record evidence from all of the following:

1. The exact cumulative MR diff and current source SHA, including the
   MR-introduced causal path alleged by the finding.
2. The cited `RULE-nnnn` file, including its frontmatter exceptions and `## Fix`
   section. For an uncited or legacy finding, read the matching category rule.
3. `docs/agent/core/conventions.md` and its applicable `CONV-*` requirements.
4. Every applicable category file under `docs/agent/review/`, selected from the
   changed path and finding subject rather than severity alone.
5. Relevant focused tests, existing runtime behavior, and exact-SHA CI evidence.
6. Existing human comments and Developer-or-higher adjudications. Do not silently
   override an explicit human product, safety, or tradeoff decision.

Record one and only one classification for each finding ID at the current
evidence envelope:

- `must-fix`
- `suppress-with-reason`
- `already-fixed-or-stale`
- `needs-human-decision`

Severity is an input, not the decision. Use concrete breakage and material risk
as the boundary.

### `must-fix`

Use `must-fix` for a valid `error` finding and whenever the evidence shows any
of these, including when the finding is only a warning:

- broken or changed business behavior, user-visible regression, or a material
  mismatch with explicit product intent;
- security, authentication, authorization, permission-lifecycle, secret, or
  prompt-injection exposure;
- data loss, corruption, schema drift, unsafe migration, or state-consistency
  risk;
- API, proto, configuration, persistence, or other compatibility breakage;
- Kotlin/Go behavior, permission, field-mapping, gateway, or worker parity drift
  where repository policy requires parity;
- missing required regression tests, generated artifacts, or CI wiring;
- missing or inaccurate mandatory `CONV-D1` or `CONV-D6` documentation;
- an accessibility failure that blocks an intended interaction;
- meaningful reliability, timeout, retry, concurrency, performance,
  resource-exhaustion, cost, or operational risk;
- any warning with a concrete material breakage scenario or a valid required
  repository-contract violation.

For `must-fix`, read and follow the cited rule's `## Fix` section, make the
smallest correct change, add or update focused regression coverage when behavior
changes, preserve unrelated work, and run affected service-free lint, typecheck,
tests, and builds plus the mapped exact-SHA CI. A rule-cited repair must use the
repository-required commit reference such as `Fixes RULE-0007`.

### `suppress-with-reason`

Use `suppress-with-reason` only when every condition below is proven:

- the finding is a warning, info, or otherwise non-blocking advisory finding;
- it is a demonstrable false positive, an already accepted and documented
  tradeoff, an inapplicable rule or explicit exception, or a harmless
  stylistic/preference concern;
- leaving the code unchanged cannot break business logic, product intent,
  security, authorization, data integrity, compatibility, accessibility,
  reliability, operations, or a required repository contract;
- the exact diff, rule text and exceptions, tests/runtime behavior, and any human
  adjudication provide an auditable explanation.

Do not suppress merely because a finding is inconvenient, expensive, or a
warning. Do not suppress a valid error to make CI green. A blocking error that
appears false-positive but is not stale requires `needs-human-decision`, because
this loop does not autonomously waive a blocking repository gate.

The primary integration layer owns the GitLab comment and thread side effects.
Return the exact finding ID plus a concise `Reason:` grounded in the recorded
evidence. Classification alone, an unauthorized comment, or manual thread
resolution does not complete suppression.

### `already-fixed-or-stale`

Use `already-fixed-or-stale` only after proving the allegation does not apply to
the exact current source SHA. Make no code edit for this disposition and never
edit code solely to change thread state. Let the next review run remove the
finding and let bot-created stale threads follow the repository's documented
lifecycle. This disposition completes only when a trusted review for the exact
current head/base omits the finding. If that exact-current review still emits the
finding, reclassify it as `must-fix`, `suppress-with-reason`, or
`needs-human-decision`; it is not stale. If no normal automatic review can occur
without a no-op or verification-only mutation, return `manual_action_required`
with the lifecycle gap instead of manufacturing a push.

### `needs-human-decision`

Use `needs-human-decision` when product intent, safety, authorization, data
policy, user-visible behavior, rule applicability, finding identity, or an
acceptable tradeoff remains uncertain. Also use it when a blocking finding would
need adjudication rather than a code fix. State the exact decision and evidence
needed. Do not edit, suppress, reply as if decided, or resolve the finding.

## Disposition Evidence

For every finding, return a disposition record containing the exact finding ID,
source SHA, target SHA, severity, cited rule when present, classification,
material-risk analysis, evidence, intended action, and completion condition.
Code-change state and thread-resolution state are evidence fields, not
classifications. A manually resolved thread with no classification is still
untriaged.

The primary must independently revalidate this record immediately before any
edit or GitLab write. A new source SHA, target SHA, finding body, human
adjudication, or discussion snapshot invalidates the action and requires fresh
triage.

## Verification Boundary

Run service-free local checks first. Formatting, static analysis, compilation,
documentation checks, and focused or unit tests known not to require external
services are normal. Resource-heavy verification uses the exact automatic GitLab
jobs mapped by `mr-loop-snapshot`.

Do not start `just infra-up`, Docker Compose, containers, local databases, queues,
object stores, backend stacks, browser stacks, or preview environments merely to
verify a repair. Report mapped CI or temporarily unavailable evidence as pending.
Report missing remote coverage as a gap only when complete readable evidence
proves it. If that uncovered check genuinely requires local infrastructure,
return it to the primary to explain and obtain user approval. After approval use
only a targeted dependency workflow, never a whole stack for one service, and
never production or shared customer data.

## Discussion Repair

Process unresolved resolvable discussions oldest first as one local repair batch.
Do not commit or push after each discussion.

1. Capture stable discussion ID, non-system notes, note bodies, author IDs,
   resolvable/resolved flags, suggestions, and stable position fields excluding
   GitLab-managed base/start/head SHAs.
2. Route verified agent-review findings through `Agent-Review Finding Triage`.
   Do not translate `suppress-with-reason` into a code repair merely because its
   inline thread is unresolved.
3. For ordinary human review discussions, retain the existing classification:
   valid, invalid, obsolete, or blocked.
4. For valid ordinary feedback and `must-fix` agent findings, make the smallest
   code change and keep it local as part of the current batch. Perform only checks
   allowed by the local verification budget. Continue through currently
   actionable discussions, yielding whenever the active pipeline poll deadline
   is due.
5. For invalid or obsolete ordinary feedback, return a technical rationale to the
   primary integration layer and leave the tree clean. For
   `already-fixed-or-stale`, make no edit and follow the agent-review lifecycle
   rather than treating an ordinary reply as suppression.
6. For blocked ordinary feedback or `needs-human-decision`, stop without
   representing the issue as decided.
7. After processing the current set, fetch all discussions again and add newly
   arrived actionable feedback to the same local batch until one fresh fetch has
   none.
8. Immediately before commit and push, refresh MR identity, exact target SHA, all
   discussions, and the complete recursive pipeline graph. Fold newly discovered
   actionable failures into the same uncommitted batch, then refresh again. If any
   relevant pipeline remains active, continue bounded local work and polling but
   do not commit, push, retry or cancel CI, request rebase, write discussions, or
   merge.
9. Reopen the synchronization gate before finalizing the batch. If the target
   advanced, restart synchronization without pushing.
10. Return side-effect intents to the primary. This skill does not equate a reply
   or resolution with a completed agent-review disposition.

## Autonomous Engineering Decisions

Choose and implement the safest bounded repair instead of asking the user when:

- the issue is an engineering tradeoff, or a domain conflict resolved by
  `mr-loop-linear-context`;
- it is not unresolved reviewer intent, deployment approval, destructive data
  policy, or unsupported security acceptance;
- code, tests, job trace, discussion, or repository rules identify a bounded fix;
- the approach is deterministic, race-safe, resource-bounded, and consistent with
  nearby patterns;
- the change can be kept focused and verified by exact-SHA CI, with only cheap
  local checks unless conflict integration requires stricter checks.

Prefer the smallest safe approach that fixes the defect class, not only one
failing example. For concurrency and reconciliation bugs, prefer bounded
batching, durable pagination/checkpointing, explicit partial-settlement
semantics, idempotency, and clear retry behavior over unbounded N+1 loops.

Record every autonomous decision: problem, chosen approach, reason, rejected
alternatives, verification, and residual risk. If no safe bounded option exists,
stop and report the missing decision or context.

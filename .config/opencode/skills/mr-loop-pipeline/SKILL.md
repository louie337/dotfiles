---
name: mr-loop-pipeline
description: Use for GitLab MR loop exact-SHA recursive CI graph polling, failed-job classification, pipeline serialization, and guarded cancellation.
---

# MR Loop Pipeline

This skill governs CI evidence for the exact current MR SHA. It does not permit
creating verification pipelines or hiding polling inside shell loops.

## Exact-SHA Pipeline Repair

- Maintain `verification_sha` and `canonical_pipeline_id`. After each normal push
  converges, discover the relevant pipeline for that SHA once and bind its ID.
- Poll that same pipeline ID and its complete recursively expanded job graph every
  30 seconds until terminal.
- Never silently switch to a newer pipeline ID for the same SHA without proving
  why the canonical pipeline disappeared, was replaced, or became irrelevant.
- Never explicitly create a pipeline for verification. Do not use `glab ci run`,
  pipeline-create APIs, job play actions, or equivalent commands.
- Use the repository's existing automatically path-selected jobs as the default
  resource-heavy verification. Compare the exact job mapping from
  `mr-loop-snapshot` with its expected relevant exact-SHA pipeline graph. Treat
  each mapped `(pipeline graph selector, job name)` occurrence as required
  verification even when GitLab marks it `allow_failure`. A same-named job in
  another graph cannot satisfy the mapping. A mapped occurrence absent while its
  expected graph is active or incomplete is pending, never a basis for claiming
  that category passed.
- Never create a no-op or verification-only commit, push unchanged code, or
  create/update an MR solely to make CI run. Pipelines must arise from the normal
  push of actual synchronized repair code or existing GitLab workflow behavior.
- Retry only positively identified transient infrastructure failures, only after
  the canonical pipeline is terminal, and only after the serialization gate proves
  no relevant pipeline is active.
- Never decide from a branch pipeline whose SHA differs from the current MR SHA.
  Ignore every pre-rebase or pre-fix pipeline after SHA convergence changes.

## Recursive Pipeline Graph Poll

Run one discrete poll step at a time so the primary regains control after every
snapshot. Never delegate waiting to a shell `while`, `until`, watcher, background
command, script, or long-running polling loop.

For each poll:

1. Start with `canonical_pipeline_id` and enumerate every other relevant pipeline
   for the MR source branch and exact current SHA. Fetch each fresh pipeline
   record, all paginated direct jobs with retried jobs included, and all paginated
   bridges.
2. From every bridge, extract downstream project ID and pipeline ID. Recursively
   repeat pipeline, jobs, and bridges fetches for each unseen `(project_id,
   pipeline_id)` pair. Include every descendant depth and multi-project pipeline.
3. Normalize jobs and bridges without losing graph identity: retain root pipeline,
   source, parent/child path, project ID, pipeline ID, job ID, name, stage, status,
   `allow_failure`, failure reason, web URL, and current-attempt identity. Match
   each verification requirement to its expected graph and job independently.
4. Before aggregate pipeline status, search every current job and bridge for
   `failed` or `canceled`. Required, verification-required mapped, or
   merge-blocking failures immediately preempt waiting, fetch the exact node
   record and trace, classify the failure, and enter local repair in the same
   iteration. `allow_failure` does not waive mapped verification evidence.
5. A terminal failed or canceled pipeline with no exposed required failed job is
   immediate investigation evidence too.
6. Only when no graph-wide required or verification-required node failed may
   active states drive waiting. If any such node remains active, update
   `last_recursive_pipeline_poll_at`, set `next_pipeline_poll_deadline` no later
   than 30 seconds later, and retain `next_state=recursive_pipeline_poll`.
7. For each mapped occurrence, only `success` passes. Active states continue
   polling. `failed` or `canceled` enters trace classification and repair or the
   guarded transient-infrastructure retry path. `manual`, `skipped`, and every
   other terminal non-success state are mapped selection/execution gaps and
   transition to `manual_action_required`; never play the job.
8. Aggregate success requires every current required job and bridge at every
   discovered depth and every mapped graph/job occurrence to appear and succeed,
   with no relevant graph node active. Once an expected graph is complete and
   terminal, an absent mapped occurrence is a selection gap and blocks success.

Use GitLab's pipeline, jobs, and bridges endpoints for every discovered pipeline;
the parent pipeline jobs endpoint alone is never complete. Useful endpoints:

```sh
glab api --hostname <host> --paginate "projects/<encoded-project>/pipelines/<pipeline-id>/jobs?per_page=100&include_retried=true"
glab api --hostname <host> --paginate "projects/<encoded-project>/pipelines/<pipeline-id>/bridges?per_page=100"
```

## Active Poll Deadline

When a complete recursive snapshot contains active required CI, set
`last_recursive_pipeline_poll_at` to snapshot completion time and
`next_pipeline_poll_deadline` no later than 30 seconds afterward. This deadline
is the primary's highest-priority non-atomic transition.

- After every bounded action, compare current time to the deadline before doing
  anything else. If due, poll first.
- Do not launch optional subagents or broad investigation that may outlast the
  remaining interval.
- Never wait for optional subagents while required CI is active.
- If suspension or a tool call misses a deadline, record expected and actual
  resume time, then poll immediately before optional work.

## Pipeline Serialization Gate

Before every normal push, transient-infrastructure retry, GitLab-side rebase, or
other pipeline-producing mutation:

1. Re-fetch MR identity and current SHA.
2. Enumerate every pipeline for the MR source branch and exact current SHA,
   including push, `merge_request_event`, parent, child, and bridge-triggered
   pipelines.
3. Treat `created`, `waiting_for_resource`, `preparing`, `pending`, `running`, and
   `scheduled` as active. If any relevant pipeline is active, do not mutate; run a
   recursive poll immediately.
4. Repeat until every relevant pipeline is terminal.
5. Immediately before mutation, fetch pipelines once more. If active CI appeared,
   close the gate and resume polling. Otherwise perform exactly one mutation and
   wait for its resulting canonical pipeline to become terminal before another.

If one push creates multiple relevant pipelines for the same SHA, record all IDs,
select the MR-associated required pipeline as canonical, and wait for every
active relevant pipeline to become terminal. Do not push again to solve duplicate
workflow rules.

If remote configuration or pipeline evidence is temporarily unavailable, leave
verification pending without an extra Git mutation. Only complete readable CI
configuration and path rules can prove that a required verification obligation
has no automatic remote capability and establish a no-capability coverage gap;
exact-SHA user-approved targeted fallback evidence may cover only this case. If a
mapped occurrence is absent or terminally non-successful in its expected graph,
record a selection/execution gap and return `manual_action_required`; never
relabel it as no-capability or substitute a local fallback. Do not replace missing
remote coverage with unapproved local Docker, databases, service stacks, browser
stacks, production data, or shared customer data.

## Known-Failure Cancellation

Cancel only wasted CI for a SHA whose required failure has already been inspected
and classified as deterministic code failure. Revalidate identity, MR, pipeline,
and jobs before cancellation. Never cancel pipelines for manual deployment states,
unknown failures, unrelated refs, or a SHA that might still become mergeable.

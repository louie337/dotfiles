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

1. Start with `canonical_pipeline_id`. Fetch its fresh pipeline record, all
   paginated direct jobs with retried jobs included, and all paginated bridges.
2. From every bridge, extract downstream project ID and pipeline ID. Recursively
   repeat pipeline, jobs, and bridges fetches for each unseen `(project_id,
   pipeline_id)` pair. Include every descendant depth and multi-project pipeline.
3. Normalize jobs and bridges into a graph-wide set with project ID, pipeline ID,
   job ID, name, stage, status, `allow_failure`, failure reason, web URL, and
   current-attempt identity.
4. Before aggregate pipeline status, search every current job and bridge for
   `failed` or `canceled`. Required or merge-blocking failures immediately
   preempt waiting, fetch the exact node record and trace, classify the failure,
   and enter local repair in the same iteration.
5. A terminal failed or canceled pipeline with no exposed required failed job is
   immediate investigation evidence too.
6. Only when no graph-wide required node failed may active states drive waiting.
   If required nodes remain active, update `last_recursive_pipeline_poll_at`, set
   `next_pipeline_poll_deadline` no later than 30 seconds later, and retain
   `next_state=recursive_pipeline_poll`.
7. Success requires every current required job and bridge at every discovered
   depth to succeed and no relevant graph node to remain active.

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

## Known-Failure Cancellation

Cancel only wasted CI for a SHA whose required failure has already been inspected
and classified as deterministic code failure. Revalidate identity, MR, pipeline,
and jobs before cancellation. Never cancel pipelines for manual deployment states,
unknown failures, unrelated refs, or a SHA that might still become mergeable.

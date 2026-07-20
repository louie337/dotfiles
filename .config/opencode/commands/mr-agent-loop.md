---
description: Use glab skills to repeatedly repair a GitLab MR until mergeable or merged.
agent: mr-agent-loop
---

Run the GitLab MR agent loop with these arguments:

```text
$ARGUMENTS
```

Interpret the arguments as:

```text
/mr-agent-loop <MR URL> [--until mergeable|merged]
```

Default `--until` to `mergeable`. Use the `gitlab-cli-skills` and `glab`
skills plus the installed `glab` CLI for all GitLab inspection and mutations.
Synchronize the source branch with the latest fetched remote target and wait for
SHA convergence before review fixes, repair commits, pushes, or CI evaluation.
If GitLab-side rebase encounters bounded deterministic conflicts, integrate the
exact fetched remote target with a guarded normal merge and normal push. Never
locally rebase or force-push. For source branches containing a `SUB-XXXX` Linear
issue key, fetch the issue through Linear MCP. Explicit ticket requirements win;
otherwise preserve the exact freshly fetched target-branch behavior.
Treat deterministic conflict intent separately from tool availability. If one
mechanical command is denied, exhaust safe stage/blob inspection, repository
file-editing, conflict-marker, and deterministic regeneration fallbacks without
asking for implementation approval. Use `blocked_conflicts` only for unresolved
intent; use `manual_action_required` only after every safe mechanism is exhausted.
Batch all actionable discussion and failed-pipeline repairs locally before one
push. Before every push or CI retry, require that every relevant pipeline is
terminal; while one is active, fetch its jobs and status every 30 seconds without
triggering another pipeline. Bind each pushed SHA to one canonical pipeline and
wait for it to finish before the next pipeline-producing mutation.
Each poll must recursively fetch the canonical pipeline's paginated jobs,
bridges, downstream pipelines, and descendant jobs. A failed or canceled required
job at any depth interrupts waiting immediately and starts investigation and
local repair even while a parent pipeline remains running. Use one discrete poll
and one foreground 30-second sleep at a time; never hide polling in a shell loop.
Track `last_recursive_pipeline_poll_at` and a hard poll deadline no more than 30
seconds later whenever required CI is active. Keep recursive polling as the
highest-priority `next_state`: after every bounded action, poll first when due;
defer optional or long-running work that could cross the deadline, and never wait
for optional subagents. Every deadline poll must freshly reload the complete
parent and descendant graph without cached nodes.

Examples:

```text
/mr-agent-loop https://gitlab.com/group/project/-/merge_requests/123
/mr-agent-loop https://gitlab.com/group/project/-/merge_requests/123 --until merged
```

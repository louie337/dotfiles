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
Always prefer GitLab-side rebase and, when it succeeds, restart on GitLab's new
SHA without a local merge. Only GitLab's specific conflict-required-local-
resolution failure enters the agent state machine's Safe Merge-Conflict
Resolution fallback.

For that fallback, refresh and lock the complete open-MR identity, source SHA,
current GitLab target SHA, no-rebase state, actor, source push permission, and
clean local state. Fetch both exact branches, create a loop-owned isolated
detached worktree at the expected source SHA, and run only `git merge --no-ff
--no-commit <exact-target-sha>`. Resolve only Git-reported unmerged paths when
repository evidence is deterministic; combine compatible content and add/add
changes, resolve source definitions before regenerating generated output, run
path-specific rules and focused verification, and stop on ambiguity, unrelated
changes, missing generation context, or failed checks.

Create one conventional two-parent merge commit whose body records the target
SHA and that the MR agent loop resolved conflicts. Re-run identity, exact source
and target SHA, permission, and pipeline-serialization guards immediately before
`git push origin HEAD:<source-branch>`. Push normally, wait for GitLab to report
the pushed SHA, then restart from a fresh same-SHA snapshot. Preserve a committed
but unpushed merge under a local ref on any push or concurrency failure; abort
only a proven loop-owned uncommitted attempt. Existing worktrees and local branch
pointers remain untouched.

Never locally rebase, reset, clean, stash, amend, rewrite history, force-push, or
use force-with-lease. A GitLab-side rebase conflict triggers the guarded fallback;
only an ambiguous or safely unresolvable conflict is a hard blocker. Never reply,
resolve discussions, evaluate success, or merge from the pre-merge SHA.

For source branches containing a `SUB-XXXX` Linear issue key, fetch the issue
through Linear MCP. Explicit ticket requirements win; otherwise preserve the
exact freshly fetched target-branch behavior.
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

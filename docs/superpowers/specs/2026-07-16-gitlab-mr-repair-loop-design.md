# GitLab MR Repair Loop Design

## Goal

Provide an OpenCode slash command that synchronizes and monitors a GitLab merge
request from the current repository, repairs unresolved discussions and failed
pipelines, and continues until the merge request is green and mergeable or a
safety limit is reached.

The supervisor owns polling, Git and GitLab mutations, state, and termination.
OpenCode is invoked only to evaluate one unresolved discussion or diagnose and
repair a terminal pipeline failure.

## User Interface

The command is:

```text
/mr-loop <MR URL> [--on-success notify|merge]
```

`--on-success` defaults to `notify`.

- `notify`: stop after confirming the latest MR SHA has a successful pipeline
  and GitLab reports the MR mergeable.
- `merge`: repeat the success checks immediately before running
  `glab mr merge`.

The command runs in the foreground so the user can inspect progress and stop it
with `Ctrl-C`.

## Components

### Slash Command

The OpenCode command validates its arguments and launches the supervisor from
the repository root. It does not implement the repair loop in its prompt.

### Supervisor

A deterministic shell program coordinates the run. It:

1. Validates the local repository and MR.
2. Acquires a repository-scoped lock.
3. Checks out and tracks the MR source branch in the current checkout.
4. Pushes a clean local head when it is a descendant of the MR SHA.
5. Requests and waits for a GitLab rebase when the source is behind the target.
6. Evaluates, replies to, and resolves unresolved discussions one at a time.
7. Polls GitLab for the exact MR SHA pipeline and merge status.
8. Invokes a repair agent after a terminal pipeline failure.
9. Verifies, commits, and pushes generated repairs.
10. Stops on success, cancellation, or a safety condition.

The supervisor uses `glab` and `git` directly. Machine-readable `glab` output
is preferred so control flow never depends on formatted tables.

### Repair Agents

A dedicated pipeline-repair agent receives:

- The MR URL, source branch, and current SHA.
- Failed job names and relevant log output.
- The current repair attempt number.
- Instructions to diagnose the root cause, make the smallest correct repair,
  recommend relevant local checks, and leave changes uncommitted.

The discussion-repair agent receives one unresolved resolvable thread at a
time, including its complete notes, position, current MR SHA, and relevant
repository context. It returns a machine-readable disposition:

- `fixed`: the feedback is valid and repository changes were made.
- `invalid`: the feedback does not apply, with a technical rationale.
- `obsolete`: the current MR already makes the feedback inapplicable.
- `blocked`: the thread cannot be handled safely or needs a human decision.

The supervisor, not either agent, performs commits, pushes, discussion replies,
resolution, rebases, and merges. This makes the repair limit and stale-state
guards enforceable outside model behavior.

The agents may read and edit the repository. They have no shell access and must
not stage, commit, push, merge, resolve discussions, rewrite history, change
branches, or stash work. Existing global permissions remain unchanged; the
supervisor performs the explicitly requested Git and GitLab operations itself.

## Preconditions

The supervisor refuses to start unless:

- `git`, `glab`, and `opencode` are installed.
- The current directory belongs to a Git repository.
- `glab auth status` succeeds for the MR host.
- The MR URL belongs to the current repository's GitLab project.
- The MR is open and its source branch is available to push.
- The working tree and index are clean, including untracked files.
- No other repair loop holds the repository lock.

It never stashes, discards, or overwrites local work.

After switching to the MR source branch, the supervisor compares local `HEAD`
with the current MR SHA:

- Equal SHAs continue without mutation.
- A clean local `HEAD` that descends from the MR SHA is pushed normally to the
  source branch, then the supervisor waits for the MR to report that SHA.
- A local branch behind the MR or divergent from it stops without resetting,
  rebasing, or overwriting either history.

## State Machine

### Synchronize

Fetch current MR metadata and confirm the local branch relationship described
in Preconditions. A normal push of pre-existing descendant commits is a
synchronization action and does not consume the generated-repair budget.

If GitLab reports that the source branch is behind its target branch, request a
rebase through the GitLab merge-request rebase API. Poll while
`rebase_in_progress` is true and continue only after GitLab publishes the new
MR SHA. A GitLab rebase does not consume the generated-repair budget. Stop on
conflicts, `merge_error`, API failure, timeout, or an unexpected MR identity
change. Never fall back to a local rebase or force-push.

### Discussions

Fetch all MR discussions and select the oldest unresolved resolvable thread.
Process only one thread per iteration so each disposition, repair, reply, and
resolution remains attributable to one review item.

For a `fixed` disposition:

1. Require repository changes while branch and `HEAD` remain otherwise stable.
2. Re-fetch the MR and thread to reject stale state.
3. Commit and normally push the repair.
4. Wait for the MR to report the pushed SHA.
5. Post the technical reply and resolve the thread.

For `invalid` or `obsolete`, require a non-empty technical rationale, re-fetch
the thread, post the reply, and then resolve it without a push. For `blocked`,
stop without resolving the thread. A reply must succeed before resolution, and
resolution must target the exact discussion that was evaluated.

### Observe Pipeline

Fetch current MR metadata and identify the latest pipeline for the exact MR
head SHA.

- If no matching pipeline exists yet, poll again after a bounded delay.
- If the matching pipeline is pending or running, continue polling.
- If it succeeded, evaluate mergeability.
- If it failed or was canceled, enter Repair.
- If it is skipped, manual, or otherwise terminal without success, stop and
  report that human intervention is required.

Polling uses a fixed interval with a configurable default of 30 seconds. The
run has a default wall-clock timeout of four hours so waiting for runners cannot
continue indefinitely.

### Repair

Before invoking OpenCode, confirm that the local branch, remote MR SHA, and
failed pipeline SHA still match. Fetch failed job traces and trim each trace to
a bounded size while preserving the failing tail and job identity.

Run a fresh non-interactive OpenCode session for each attempt. A fresh session
prevents stale pipeline assumptions from carrying into later repairs; the
prompt contains all required attempt context.

After OpenCode exits:

- Stop if the command failed or timed out.
- Stop if the working tree has no changes.
- Stop if forbidden repository state changed, including branch or HEAD.
- Report the repair agent's recommended verification commands for execution by
  CI; the shell-restricted agent does not execute repository-controlled code.
- Commit all intended tracked and untracked repair files with a concise repair
  message.
- Push normally to the MR source branch. Never force-push.
- Increment the repair-push count and return to Synchronize.

The default maximum is 12 generated repair pushes, configurable through the
existing environment override. Discussion and pipeline repair pushes share the
same budget. Pre-existing local descendant pushes and GitLab rebases do not
consume it. Reaching the limit without a green, mergeable MR stops the run and
reports the remaining failure or discussion.

### Success

Success requires all of the following for the same current MR SHA:

- No unresolved resolvable discussions remain.
- The latest applicable pipeline completed successfully.
- GitLab reports no merge conflicts.
- GitLab reports the MR mergeable rather than checking, blocked, or unknown.
- Required approvals and other project merge checks are satisfied.

For `notify`, print a summary and exit successfully.

For `merge`, fetch MR state again immediately before merging. Abort if the SHA
or any success condition changed. Otherwise run a normal `glab mr merge`
without bypassing approvals, pipeline requirements, or protected-branch rules.

## Concurrency And State Safety

The lock is stored under the repository's Git metadata so concurrent runs for
the same checkout cannot overlap. The lock records the process ID and MR URL
for diagnostics and is removed on normal exit and handled signals. A stale lock
may be removed only after confirming its recorded process is not running.

The supervisor records the initial branch and HEAD for reporting. It does not
automatically restore the initial branch because successful repairs leave the
current checkout on the MR branch by design.

At every mutating transition, the remote MR SHA and identity are re-fetched and
authoritative. If another actor pushes to the MR while a repair is underway,
the supervisor stops rather than pushing work, replying, or resolving a thread
based on obsolete state.

## Error Handling And Reporting

Every stop condition prints:

- MR URL and source branch.
- Last observed MR and pipeline SHAs.
- Pipeline status and merge status.
- Number of repair pushes used.
- Last failed jobs, when applicable.
- Whether files or commits remain locally.
- The reason for stopping and the next manual action.

`Ctrl-C`, termination signals, authentication failures, network failures beyond
a bounded retry count, command timeouts, unexpected branch changes, rejected
pushes, and changed MR SHAs all stop safely and release the lock.

No credentials or complete job traces are written to persistent state.

## Notifications

The first implementation reports status through command output. It may also
use the existing OpenCode notifier behavior when the command completes. A new
notification service or background daemon is out of scope.

## Testing

The supervisor is split into small command-oriented functions so external
commands can be stubbed in tests. Tests cover:

- Argument parsing and the default success policy.
- Dirty-worktree and concurrent-run rejection.
- Pipeline-to-SHA matching.
- Pending, running, failed, successful, manual, and missing pipeline states.
- Clean local descendant push and remote-SHA convergence.
- Rejection of local-behind and divergent histories.
- GitLab rebase request, polling, conflict, error, and timeout behavior.
- Unresolved discussion selection and structured dispositions.
- Reply-before-resolve ordering and stale-thread rejection.
- Shared 12-repair-push enforcement.
- Changed remote SHA before repair, push, and merge.
- Notify and merge success policies.
- Merge refusal when approvals, conflicts, or merge checks block the MR.
- Signal cleanup and stale-lock handling.
- Redaction and bounded failed-job log collection.

A dry-run fixture test simulates local synchronization, a GitLab rebase, one
discussion repair, one pipeline repair, a successful new pipeline, and both
success policies without contacting GitLab or a model.

## Out Of Scope

- Monitoring multiple MRs in one process.
- Running as a background daemon or launchd service.
- GitLab CI-based self-repair loops.
- Force-pushing, local rebasing, or rewriting MR history outside GitLab's
  guarded merge-request rebase API.
- Automatically approving merge requests or bypassing required approvals.
- Repairing MRs from forks without a pushable source branch.
- Restoring or cleaning the user's checkout automatically.

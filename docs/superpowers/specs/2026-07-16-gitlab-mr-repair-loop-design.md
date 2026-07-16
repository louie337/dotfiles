# GitLab MR Repair Loop Design

## Goal

Provide an OpenCode slash command that monitors a GitLab merge request from the
current repository, repairs failed pipelines, and continues until the merge
request is green and mergeable or a safety limit is reached.

The supervisor owns polling, state, and termination. OpenCode is invoked only
to diagnose and repair a terminal pipeline failure.

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
4. Polls GitLab for the MR SHA, pipeline, and merge status.
5. Invokes the repair agent after a terminal pipeline failure.
6. Verifies, commits, and pushes a repair.
7. Waits for a pipeline associated with the pushed SHA.
8. Stops on success, cancellation, or a safety condition.

The supervisor uses `glab` and `git` directly. Machine-readable `glab` output
is preferred so control flow never depends on formatted tables.

### Repair Agent

A dedicated primary OpenCode agent receives:

- The MR URL, source branch, and current SHA.
- Failed job names and relevant log output.
- The current repair attempt number.
- Instructions to diagnose the root cause, make the smallest correct repair,
  run relevant local checks, and leave changes uncommitted.

The supervisor, not the agent, performs commits and pushes. This makes the
three-push limit enforceable outside model behavior.

The agent may read and edit the repository and run development commands. It
must not push, merge, force-push, rewrite history, change branches, or stash
work. Existing global permissions remain unchanged; the supervisor performs
the explicitly requested Git operations itself.

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

## State Machine

### Observe

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
- Run repository-relevant verification selected by the repair agent and report
  its results in the session output.
- Commit all intended tracked and untracked repair files with a concise repair
  message.
- Push normally to the MR source branch. Never force-push.
- Increment the repair-push count and return to Observe.

The maximum is three repair pushes. Reaching three without a green, mergeable
MR stops the run and reports the remaining failure.

### Success

Success requires all of the following for the same current MR SHA:

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

At every transition, the remote MR SHA is authoritative. If another actor
pushes to the MR while a repair is underway, the supervisor stops rather than
pushing work based on an obsolete SHA.

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
- Three-push enforcement.
- Changed remote SHA before repair, push, and merge.
- Notify and merge success policies.
- Merge refusal when approvals, conflicts, or merge checks block the MR.
- Signal cleanup and stale-lock handling.
- Redaction and bounded failed-job log collection.

A dry-run fixture test simulates a failure, one repair push, a successful new
pipeline, and both success policies without contacting GitLab or a model.

## Out Of Scope

- Monitoring multiple MRs in one process.
- Running as a background daemon or launchd service.
- GitLab CI-based self-repair loops.
- Automatically resolving review discussions or approval requests.
- Force-pushing, rebasing, or rewriting MR history.
- Repairing MRs from forks without a pushable source branch.
- Restoring or cleaning the user's checkout automatically.

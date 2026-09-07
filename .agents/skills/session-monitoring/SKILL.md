---
name: session-monitoring
description: Monitor selected Codex CLI sessions in tmux for ready or idle transitions, then pause until the user explicitly restarts monitoring. Use for tmux-based Codex session monitoring, not general tmux management.
---

# Session monitoring

Monitor terminal state read-only. Do not send keys, type into a pane, kill processes, restart
sessions, detach clients, or otherwise mutate tmux. Do not print full pane captures: terminal
output may contain secrets or user data. Report only pane identity, process evidence, status,
timestamps, and a short sanitized indicator when useful.

## Phase 1: inventory and selection

Do this scan once when the skill starts, and again after an explicit restart request:

1. Verify that `tmux` is available. List sessions with
   `tmux list-sessions -F '#{session_name}\t#{session_windows}\t#{session_attached}'`.
   If there are no sessions, report that and stop; do not create one.
2. List every pane with stable and human-readable identifiers:
   `tmux list-panes -a -F '#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_pid}\t#{pane_current_command}\t#{pane_title}\t#{pane_start_command}'`.
   Prefer the stable `%<number>` `pane_id` as the monitoring key, and show
   `session:window.pane` in reports.
3. For each pane, establish that a Codex CLI process is still running. Use the pane's
   `pane_pid` and inspect its live process tree (for example, `ps -ww -o pid=,ppid=,command=`
   followed by recursive `pgrep -P`/equivalent child traversal), and inspect
   `pane_current_command`/`pane_start_command`. Treat a pane as a candidate only when an actual
   executable/process command contains the `codex` executable (not merely because the captured
   text mentions the word “codex”). If process inspection and pane metadata disagree, report the
   uncertainty and exclude the pane until it can be confirmed.
4. For confirmed candidates, capture only a bounded recent tail for status classification, for
   example `tmux capture-pane -p -J -t %<id> -S -80`. Strip ANSI/control sequences before matching.
5. Report the candidate table (pane ID, location, command, and a terse active/ready indication)
   and ask: **“Which pane(s) should I monitor? Reply with the `%pane_id` values or
   `session:window.pane` locations.”** Accept a comma-separated selection. Do not start the loop
   until the user answers. Reject selections that are not among the confirmed candidates and show
   the valid choices again.

If sessions exist but no pane has a confirmed live Codex process, report “no ongoing Codex CLI
panes found” and stop; do not ask the user to select a non-candidate.

## Phase 2: one-minute polling loop

After selection, save a baseline for each selected pane: its pane ID, location, Codex process
identity (PID or command line), and whether its latest bounded capture is active or ready/idle.
Use the pane ID for subsequent lookups so renamed sessions/windows do not silently change the
target. A pane that is destroyed and later recreated is a new pane and must be re-confirmed.

Repeat the following as bounded one-minute iterations (never leave one tool call blocked for more
than 60 seconds):

1. Confirm the pane still exists (`tmux list-panes -a` or `tmux display-message -p -t %<id>`), and
   confirm the Codex process is still alive in that pane's process tree.
2. Capture a bounded recent tail and classify its state. Use explicit `ready`/`idle` indicators
   when present, and the CLI's input prompt (commonly a lone `›`/`>` prompt) only when the Codex
   process is alive. Do not call a pane ready merely because prose contains those words. Treat
   spinners, tool execution, streaming output, and an absent/dead process as active or unavailable,
   not ready. Keep the classifier consistent between iterations.
3. Alert only on a transition from active to ready/idle (or from unavailable to ready after a
   confirmed process restart). Include pane ID/location and the observation time; do not include
   unredacted pane text.
4. Once any monitored pane reaches ready/idle, report the transition and **pause the loop**. If a
   monitored pane disappears or its Codex process exits, report that condition and pause as well;
   never silently retarget another pane. If several panes transition in the same iteration, report
   them together before pausing.
5. If no transition occurs, use the host's recurring-monitoring/wait mechanism, or a bounded wait
   of about 60 seconds, and perform the next iteration. Keep progress messages sparse (for example,
   only when a pane disappears or state changes); do not spam a minute-by-minute transcript.

## Paused and restart behavior

After an alert or an unavailable-pane report, remain paused and wait for user instruction. Do not
poll in the background or infer permission to resume. On an explicit “restart”, “resume”, or
“continue monitoring” instruction, rescan sessions and panes from Phase 1 and ask for pane
selection again, unless the user names specific still-valid `%pane_id` values; even then, confirm
they are live Codex panes before polling. A new user request replaces this workflow.

If `tmux` is unavailable, access is denied, or status cannot be classified reliably, report the
exact limitation and pause rather than guessing or changing the environment.

#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AGENT="$ROOT/.config/opencode/agents/mr-agent-loop.md"
COMMAND="$ROOT/.config/opencode/commands/mr-agent-loop.md"
PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf 'ok %s - %s\n' "$((PASS + FAIL))" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf 'not ok %s - %s\n' "$((PASS + FAIL))" "$1"
}

assert_file() {
  description=$1
  path=$2
  if [ -f "$path" ]; then
    pass "$description"
  else
    fail "$description ($path is missing)"
  fi
}

assert_contains() {
  description=$1
  path=$2
  text=$3
  if grep -Fq -- "$text" "$path"; then
    pass "$description"
  else
    fail "$description"
  fi
}

assert_order() {
  description=$1
  path=$2
  first=$3
  second=$4
  first_line=$(grep -nF -- "$first" "$path" | cut -d: -f1 | sed -n '1p')
  second_line=$(grep -nF -- "$second" "$path" | cut -d: -f1 | sed -n '1p')
  if [ -n "$first_line" ] && [ -n "$second_line" ] && [ "$first_line" -lt "$second_line" ]; then
    pass "$description"
  else
    fail "$description"
  fi
}

assert_file "active MR agent exists" "$AGENT"
assert_file "active MR command exists" "$COMMAND"

assert_contains "command selects active agent" "$COMMAND" "agent: mr-agent-loop"
assert_contains "command exposes local rebase authorization" "$COMMAND" "--allow-local-rebase"
assert_contains "command exposes lease authorization" "$COMMAND" "--allow-force-with-lease"

assert_order "state machine precedes snapshot" "$AGENT" "## Synchronization-First State Machine" "## Loop Snapshot"
assert_order "safe synchronization precedes repair" "$AGENT" "## Safe Synchronization" "## MR Review And Discussion Repair"
assert_order "repair precedes CI evaluation" "$AGENT" "## MR Review And Discussion Repair" "## Pipeline Repair"

# Scenario 1: an already synchronized source proceeds through the explicit gate.
assert_contains "scenario 1 checks target ancestry" "$AGENT" 'git merge-base --is-ancestor <fetched-target-sha> <mr-sha>'
assert_contains "scenario 1 defines the open gate" "$AGENT" "The synchronization gate is open only when"

# Scenario 2: a conflict-free behind source uses GitLab rebase before repair.
assert_contains "scenario 2 requests server-side rebase" "$AGENT" 'glab mr rebase <iid> --repo <project>'
assert_contains "scenario 2 restarts after new SHA" "$AGENT" 'restart at `startup`'

# Scenario 3: conflicts stop before repairs unless explicitly authorized.
assert_contains "scenario 3 has blocked-conflicts state" "$AGENT" '`blocked_conflicts`'
assert_contains "scenario 3 prohibits unrelated pre-rebase repair" "$AGENT" "Do not implement or push unrelated"

# Scenario 4: stale or occupied local target is not the rebase base.
assert_contains "scenario 4 preserves occupied local target" "$AGENT" "not checked out in any worktree"
assert_contains "scenario 4 uses remote target ref" "$AGENT" 'refs/remotes/origin/<target-branch>'

# Scenario 5: concurrent source changes abort stale mutations.
assert_contains "scenario 5 defines remote-changed state" "$AGENT" '`blocked_remote_changed`'
assert_contains "scenario 5 rechecks source lease SHA" "$AGENT" '<pre-rebase-remote-source-sha>'
assert_contains "scenario 5 refreshes target before mutation" "$AGENT" "The gate expires before every repair edit"

# Scenario 6: stale pipelines are ignored after SHA changes.
assert_contains "scenario 6 ignores pre-rebase pipelines" "$AGENT" "Ignore every pre-rebase or pre-fix pipeline"
assert_contains "scenario 6 requires exact-SHA jobs" "$AGENT" "Every pipeline for the exact current MR head SHA"

# Scenario 7: pre-sync findings are provisional and revalidated.
assert_contains "scenario 7 marks findings provisional" "$AGENT" "record findings as provisional"
assert_contains "scenario 7 revalidates rebased findings" "$AGENT" "collected earlier are provisional"

# Scenario 8: authorized local rebase is backed up, skill-driven, and leased.
assert_contains "scenario 8 allows conflict skill" "$AGENT" "resolve-conflicts: allow"
assert_contains "scenario 8 requires both flags" "$AGENT" "Local conflict resolution is disabled unless"
assert_contains "scenario 8 creates backup ref" "$AGENT" "Create a unique local backup ref"
assert_contains "scenario 8 uses SHA-bound lease" "$AGENT" '--force-with-lease=refs/heads/<source-branch>:<pre-rebase-remote-source-sha>'
assert_contains "scenario 8 forbids plain force" "$AGENT" 'Never use plain `--force`'
assert_order "unsafe trailing force denial follows lease permission" "$AGENT" '"git push *--force-with-lease=refs/heads/*:*": ask' '"git push *--force-with-lease=refs/heads/*:* *--force*": deny'

assert_contains "invariant forbids disposable repair pipeline" "$AGENT" "No repair commit should be pushed merely to trigger verification"
assert_contains "ahead local commit is not pushed before sync" "$AGENT" "If local is ahead of the MR source SHA during"
assert_contains "interrupted repair is reapplied after sync" "$AGENT" "never push the pre-synchronization commit"
assert_contains "terminal awaiting pipeline is defined" "$AGENT" '`awaiting_pipeline`'
assert_contains "awaiting pipeline remains non-success" "$AGENT" "observational non-success state"
assert_contains "terminal failed job is defined" "$AGENT" '`failed_required_job`'
assert_contains "already merged result is consistent" "$AGENT" 'return `merged` for either requested'
assert_contains "final report includes fetched target" "$AGENT" "latest fetched target SHA"

printf '1..%s\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]

#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AGENT="$ROOT/.config/opencode/agents/mr-agent-loop.md"
COMMAND="$ROOT/.config/opencode/commands/mr-agent-loop.md"
CONFIG="$ROOT/.config/opencode/opencode.json"
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
assert_file "global OpenCode config exists" "$CONFIG"

assert_contains "command selects active agent" "$COMMAND" "agent: mr-agent-loop"
assert_contains "command prohibits history rewriting" "$COMMAND" "locally rebase or force-push"
assert_contains "command requires Linear lookup" "$COMMAND" "fetch the issue through Linear MCP"
assert_contains "command separates intent from tooling" "$COMMAND" "Treat deterministic conflict intent separately from tool availability"

assert_order "state machine precedes snapshot" "$AGENT" "## Synchronization-First State Machine" "## Loop Snapshot"
assert_order "safe synchronization precedes repair" "$AGENT" "## Safe Synchronization" "## MR Review And Discussion Repair"
assert_order "repair precedes CI evaluation" "$AGENT" "## MR Review And Discussion Repair" "## Pipeline Repair"

# Scenario 1: an already synchronized source proceeds through the explicit gate.
assert_contains "scenario 1 checks target ancestry" "$AGENT" 'git merge-base --is-ancestor <fetched-target-sha> <mr-sha>'
assert_contains "scenario 1 defines the open gate" "$AGENT" "The synchronization gate is open only when"

# Scenario 2: a conflict-free behind source uses GitLab rebase before repair.
assert_contains "scenario 2 requests server-side rebase" "$AGENT" 'glab mr rebase <iid> --repo <project>'
assert_contains "scenario 2 restarts after new SHA" "$AGENT" 'restart at `startup`'

# Scenario 3: conflicts use guarded normal target integration before blocking.
assert_contains "scenario 3 has blocked-conflicts state" "$AGENT" '`blocked_conflicts`'
assert_contains "scenario 3 prohibits unrelated pre-rebase repair" "$AGENT" "Do not implement or push unrelated"
assert_contains "scenario 3 prefers normal merge" "$AGENT" 'git merge --no-commit --no-ff refs/remotes/origin/<target-branch>'

# Scenario 4: stale or occupied local target is not the rebase base.
assert_contains "scenario 4 preserves occupied local target" "$AGENT" "not checked out in any worktree"
assert_contains "scenario 4 uses remote target ref" "$AGENT" 'refs/remotes/origin/<target-branch>'
assert_contains "scenario 4 permits guarded worktree pull" "$AGENT" 'git pull --ff-only'

# Scenario 5: concurrent source changes abort stale mutations.
assert_contains "scenario 5 defines remote-changed state" "$AGENT" '`blocked_remote_changed`'
assert_contains "scenario 5 rechecks source SHA" "$AGENT" "remote source and MR SHA still equal the original source tip"
assert_contains "scenario 5 refreshes target before mutation" "$AGENT" "The gate expires before every repair edit"

# Scenario 6: stale pipelines are ignored after SHA changes.
assert_contains "scenario 6 ignores pre-rebase pipelines" "$AGENT" "Ignore every pre-rebase or pre-fix pipeline"
assert_contains "scenario 6 requires exact-SHA jobs" "$AGENT" "Every pipeline for the exact current MR head SHA"

# Scenario 7: pre-sync findings are provisional and revalidated.
assert_contains "scenario 7 marks findings provisional" "$AGENT" "record findings as provisional"
assert_contains "scenario 7 revalidates rebased findings" "$AGENT" "collected earlier are provisional"

# Scenario 8: conflict integration is backed up, bounded, and normally pushed.
assert_contains "scenario 8 creates backup ref" "$AGENT" "unique local backup ref for the original source tip"
assert_contains "scenario 8 permits bounded conflicts" "$AGENT" "additive imports"
assert_contains "scenario 8 pushes normally" "$AGENT" "Push normally without force"
assert_contains "scenario 8 permits safe merge abort" "$AGENT" "is permitted only to abort the merge started by the current loop"

# Scenario 9: domain conflicts use explicit ticket scope, then fetched target behavior.
assert_contains "scenario 9 detects Linear issue key" "$AGENT" '`SUB-[0-9]+`'
assert_contains "scenario 9 requires exact Linear lookup" "$AGENT" "fetch that exact issue"
assert_contains "scenario 9 gives explicit ticket priority" "$AGENT" "explicit ticket requirement"
assert_contains "scenario 9 defaults to target behavior" "$AGENT" "ticket requirement means target behavior wins"
assert_contains "scenario 9 uses fetched target evidence" "$AGENT" 'freshly fetched `origin/<target>` SHA'
assert_contains "scenario 9 verifies authorization boundaries" "$AGENT" "including authorization boundaries"

# Scenario A: a denied convenience command falls back to allowed file editing.
assert_contains "scenario A denied checkout is not ambiguity" "$AGENT" 'If `git checkout --ours`'
assert_contains "scenario A inspects index stages" "$AGENT" 'git show :1:<path>'
assert_contains "scenario A inspects exact blobs" "$AGENT" "source/target blobs using the recorded exact"
assert_contains "scenario A uses repository edit tools" "$AGENT" "Use repository read and edit tools"
assert_contains "scenario A resolves markers directly" "$AGENT" "resolve conflict markers manually"
assert_contains "scenario A avoids mechanism approval" "$AGENT" "Do not ask the user to approve a low-level resolution mechanism"
assert_contains "scenario A continues through commit and push" "$AGENT" "create the conventional integration commit"

# Scenario B: abort diagnostics distinguish a clean tree from compatibility.
assert_contains "scenario B preserves machine-readable report" "$AGENT" "preserve a machine-readable conflict"
assert_contains "scenario B records conflict SHAs" "$AGENT" "Include source SHA, target SHA"
assert_contains "scenario B explains aborted clean tree" "$AGENT" "working tree is clean because the temporary merge was aborted"
assert_contains "scenario B reports remaining conflict" "$AGENT" "State that they still conflict"
assert_contains "scenario B gives reproduction command" "$AGENT" 'git merge --no-commit --no-ff <exact-fetched-target-sha>'

# Scenario C: deterministic conflict with no write mechanism needs environment help.
assert_contains "scenario C exhausts safe mechanisms" "$AGENT" "Try every applicable safe mechanism"
assert_contains "scenario C reports attempted mechanisms" "$AGENT" "every mechanism attempted"
assert_contains "scenario C uses manual action state" "$AGENT" 'return
`manual_action_required`, not `blocked_conflicts`'

# Scenario D: genuine intent ambiguity remains a conflict blocker.
assert_contains "scenario D reserves blocked conflicts for intent" "$AGENT" "deterministic conflict intent cannot be established"
assert_contains "scenario D lists product ambiguity" "$AGENT" "unresolved product judgment"
assert_contains "scenario D excludes denied commands" "$AGENT" "Never use this state solely because a command"

if jq -e '.mcp.linear.type == "remote" and .mcp.linear.url == "https://mcp.linear.app/mcp" and .mcp.linear.enabled == true' "$CONFIG" >/dev/null; then
  pass "Linear MCP is globally enabled"
else
  fail "Linear MCP is globally enabled"
fi

assert_contains "invariant forbids disposable repair pipeline" "$AGENT" "No repair commit should be pushed merely to trigger verification"
assert_contains "ahead local commit is not pushed before sync" "$AGENT" "If local is ahead of the MR source SHA during"
assert_contains "interrupted repair is reapplied after sync" "$AGENT" "never push the pre-synchronization commit"
assert_contains "terminal awaiting pipeline is defined" "$AGENT" '`awaiting_pipeline`'
assert_contains "awaiting pipeline remains non-success" "$AGENT" "observational non-success state"
assert_contains "continuation invariant prohibits checkpoint stop" "$AGENT" "completed push, SHA convergence"
assert_contains "push convergence restarts startup" "$AGENT" 'convergence -> `startup`'
assert_contains "discussion reply transitions to resolution" "$AGENT" "discussion reply -> discussion resolution"
assert_contains "transient pipeline polls" "$AGENT" "transient exact-SHA pipeline state -> sleep and poll"
assert_contains "watchdog controls returns" "$AGENT" '`external_return_required` is set by the'
assert_contains "checkpoints require forced suspension" "$AGENT" "voluntarily, and never treat one as a terminal result"
assert_contains "awaiting pipeline requires imposed suspension" "$AGENT" "permitted only when the"
assert_contains "final guard performs executable next state" "$AGENT" "perform it instead of describing it"
assert_contains "next response proves invalid stop" "$AGENT" 'contains `Next:`'
assert_contains "pipeline verification is preferred" "$AGENT" "Prefer exact-SHA GitLab CI for substantive verification"
assert_contains "local suites prohibited by default" "$AGENT" "do not run test"
assert_contains "unknown local cost defers to CI" "$AGENT" "If a command's cost is unknown, do not run it locally"
assert_contains "cheap file checks remain allowed" "$AGENT" "file-scoped syntax, parse, or format checks"
assert_contains "complete repair is normally pushed" "$AGENT" "complete repair is ready, commit"
assert_contains "exact SHA CI is authoritative" "$AGENT" "pipeline as authoritative verification"
assert_contains "disposable CI commits remain prohibited" "$AGENT" "disposable, incomplete, or"
assert_contains "terminal failed job is defined" "$AGENT" '`failed_required_job`'
assert_contains "already merged result is consistent" "$AGENT" 'return `merged` for either requested'
assert_contains "final report includes fetched target" "$AGENT" "latest fetched target SHA"

printf '1..%s\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]

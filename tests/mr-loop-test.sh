#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/.local/bin/mr-loop"
AGENT="$ROOT/.config/opencode/agents/mr-repair.md"
COMMAND="$ROOT/.config/opencode/commands/mr-loop.md"
PASS=0
FAIL=0

if [ ! -f "$SCRIPT" ]; then
  printf 'FAIL: supervisor exists (%s is missing)\n' "$SCRIPT"
  exit 1
fi

# shellcheck source=/dev/null
. "$SCRIPT"

pass() {
  PASS=$((PASS + 1))
  printf 'ok %s - %s\n' "$PASS" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf 'not ok %s - %s\n' "$((PASS + FAIL))" "$1"
}

assert_eq() {
  name=$1
  expected=$2
  actual=$3
  if [ "$expected" = "$actual" ]; then
    pass "$name"
  else
    fail "$name (expected '$expected', got '$actual')"
  fi
}

assert_status() {
  name=$1
  expected=$2
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  actual=$?
  set -e
  assert_eq "$name" "$expected" "$actual"
}

set -e

parse_args "https://gitlab.com/acme/widget/-/merge_requests/17"
assert_eq "default success action" "notify" "$ON_SUCCESS"
assert_eq "MR URL retained" "https://gitlab.com/acme/widget/-/merge_requests/17" "$MR_URL"

parse_args "https://gitlab.com/acme/widget/-/merge_requests/17" --on-success merge
assert_eq "explicit merge action" "merge" "$ON_SUCCESS"

assert_status "reject invalid success action" 2 parse_args \
  "https://gitlab.com/acme/widget/-/merge_requests/17" --on-success explode
assert_status "reject missing MR URL" 2 parse_args
assert_status "reject malformed MR URL" 2 parse_args "https://gitlab.com/acme/widget/issues/17"

pipelines='[
  {"id": 5, "sha": "old", "status": "success", "web_url": "old-url"},
  {"id": 8, "sha": "new", "status": "failed", "web_url": "new-url"},
  {"id": 7, "sha": "new", "status": "running", "web_url": "running-url"}
]'
selected=$(printf '%s' "$pipelines" | pipeline_for_sha "new")
assert_eq "select newest pipeline for exact SHA" "8" "$(printf '%s' "$selected" | jq -r .id)"
assert_eq "ignore pipeline for old SHA" "failed" "$(printf '%s' "$selected" | jq -r .status)"
assert_eq "missing SHA yields null" "null" "$(printf '%s' "$pipelines" | pipeline_for_sha "absent")"

assert_eq "running pipeline waits" "wait" "$(pipeline_action running)"
assert_eq "pending pipeline waits" "wait" "$(pipeline_action pending)"
assert_eq "successful pipeline checks merge" "check-merge" "$(pipeline_action success)"
assert_eq "failed pipeline repairs" "repair" "$(pipeline_action failed)"
assert_eq "canceled pipeline repairs" "repair" "$(pipeline_action canceled)"
assert_eq "manual pipeline stops" "stop" "$(pipeline_action manual)"
assert_eq "skipped pipeline stops" "stop" "$(pipeline_action skipped)"

mergeable='{"sha":"abc","has_conflicts":false,"detailed_merge_status":"mergeable","blocking_discussions_resolved":true,"approved":true}'
assert_status "accept mergeable MR" 0 mr_is_mergeable "$mergeable" "abc"
assert_status "reject changed MR SHA" 1 mr_is_mergeable "$mergeable" "def"
assert_status "reject conflicts" 1 mr_is_mergeable \
  '{"sha":"abc","has_conflicts":true,"detailed_merge_status":"mergeable","blocking_discussions_resolved":true,"approved":true}' "abc"
assert_status "reject missing approval" 1 mr_is_mergeable \
  '{"sha":"abc","has_conflicts":false,"detailed_merge_status":"mergeable","blocking_discussions_resolved":true,"approved":false}' "abc"

assert_status "allow repair before limit" 0 repair_allowed 2 3
assert_status "stop repair at limit" 1 repair_allowed 3 3

assert_eq "wait for transient merge check" "wait" "$(merge_status_action checking)"
assert_eq "wait for approval synchronization" "wait" "$(merge_status_action approvals_syncing)"
assert_eq "accept mergeable status" "ready" "$(merge_status_action mergeable)"
assert_eq "stop on stable blocked status" "stop" "$(merge_status_action blocked_status)"

expected_mr='{"state":"opened","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}'
assert_status "accept unchanged MR identity" 0 mr_matches_expected "$expected_mr" "abc" "fix-ci" "7"
assert_status "reject closed MR identity" 1 mr_matches_expected \
  '{"state":"closed","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}' "abc" "fix-ci" "7"
assert_status "reject changed source branch" 1 mr_matches_expected "$expected_mr" "abc" "other" "7"

assert_status "bounded command succeeds" 0 run_with_timeout 2 sh -c 'exit 0'
started=$(date +%s)
captured=$(run_with_timeout 5 printf 'ready')
elapsed=$(($(date +%s) - started))
assert_eq "bounded command preserves stdout" "ready" "$captured"
if [ "$elapsed" -lt 3 ]; then
  pass "bounded command returns before timeout"
else
  fail "bounded command returns before timeout (took ${elapsed}s)"
fi
assert_status "bounded command times out" 142 run_with_timeout 1 sleep 2
assert_status "bounded command kills TERM-resistant process" 142 run_with_timeout 1 sh -c \
  'trap "" TERM; while :; do sleep 1; done'
pid_file=$(mktemp "${TMPDIR:-/tmp}/mr-loop-timeout.XXXXXX")
assert_status "bounded command times out process tree" 142 run_with_timeout 1 sh -c \
  'sleep 20 & echo $! >"$1"; wait' sh "$pid_file"
child_pid=$(sed -n '1p' "$pid_file")
rm -f "$pid_file"
assert_status "timed out child is terminated" 1 kill -0 "$child_pid"
assert_status "fatal guard terminates caller" 1 sh -c \
  '. "$1"; die "stop"; exit 0' sh "$SCRIPT"

api() { return 1; }
assert_status "trace download failure is propagated" 1 fetch_job_trace 99
unset -f api 2>/dev/null || true

redacted=$(printf 'Authorization: Bearer secret-token\nPRIVATE-TOKEN: abc123\nnormal failure\n' | redact_log)
assert_eq "redact bearer token" "Authorization: Bearer [REDACTED]" "$(printf '%s' "$redacted" | sed -n '1p')"
assert_eq "redact private token" "PRIVATE-TOKEN: [REDACTED]" "$(printf '%s' "$redacted" | sed -n '2p')"
assert_eq "preserve normal log" "normal failure" "$(printf '%s' "$redacted" | sed -n '3p')"

if [ -f "$AGENT" ]; then
  pass "repair agent exists"
else
  fail "repair agent exists ($AGENT is missing)"
fi
if [ -f "$AGENT" ] && grep -Eq '"?\*"?: deny' "$AGENT" && grep -Eq '"?git push \*"?: deny' "$AGENT" && grep -Eq '"?git commit \*"?: deny' "$AGENT"; then
  pass "repair agent denies shell by default, commit, and push"
else
  fail "repair agent denies shell by default, commit, and push"
fi
if [ -f "$AGENT" ] && ! grep -Eq '"?(npm|pnpm|yarn|bun|pytest|go test|cargo test|make test)' "$AGENT"; then
  pass "repair agent cannot execute repository-controlled tests"
else
  fail "repair agent cannot execute repository-controlled tests"
fi
if [ -f "$COMMAND" ]; then
  pass "slash command exists"
else
  fail "slash command exists ($COMMAND is missing)"
fi
if [ -f "$COMMAND" ] && grep -q '\$HOME/.local/bin/mr-loop \$ARGUMENTS' "$COMMAND"; then
  pass "slash command forwards arguments to supervisor"
else
  fail "slash command forwards arguments to supervisor"
fi

printf '1..%s\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]

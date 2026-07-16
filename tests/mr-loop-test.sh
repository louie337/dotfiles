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

assert_eq "request rebase when behind" request "$(rebase_action \
  '{"diverged_commits_count":2,"rebase_in_progress":false,"merge_error":null}')"
assert_eq "accept up-to-date target branch" ready "$(rebase_action \
  '{"diverged_commits_count":0,"rebase_in_progress":false,"merge_error":null}')"
assert_eq "wait for active GitLab rebase" wait "$(rebase_action \
  '{"diverged_commits_count":2,"rebase_in_progress":true,"merge_error":null}')"
assert_eq "stop on GitLab rebase error" error "$(rebase_action \
  '{"diverged_commits_count":2,"rebase_in_progress":false,"merge_error":"conflict"}')"

expected_mr='{"state":"opened","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}'
assert_status "accept unchanged MR identity" 0 mr_matches_expected "$expected_mr" "abc" "fix-ci" "7"
assert_status "reject closed MR identity" 1 mr_matches_expected \
  '{"state":"closed","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}' "abc" "fix-ci" "7"
assert_status "reject changed source branch" 1 mr_matches_expected "$expected_mr" "abc" "other" "7"

assert_eq "default generated repair limit" "12" "$MAX_REPAIRS"

rebase_calls=$(mktemp "${TMPDIR:-/tmp}/mr-loop-rebase.XXXXXX")
rebase_fetch_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-rebase-state.XXXXXX")
rm -f "$rebase_fetch_state"
api() {
  printf '%s\n' "$*" >>"$rebase_calls"
  case $* in
    *--method\ PUT*rebase*) printf '{"rebase_in_progress":true}\n' ;;
    *) return 1 ;;
  esac
}
fetch_mr() {
  if [ ! -e "$rebase_fetch_state" ]; then
    : >"$rebase_fetch_state"
    printf '%s\n' '{"state":"opened","sha":"old","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}'
  else
    printf '%s\n' '{"state":"opened","sha":"new","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}'
  fi
}
POLL_INTERVAL=0
EXPECTED_LOCAL_SHA=old
align_after_gitlab_rebase() { printf 'align %s %s %s\n' "$@" >>"$rebase_calls"; }
request_gitlab_rebase old fix-ci 7
assert_eq "request rebase before local alignment" \
  "--method PUT projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/rebase" \
  "$(sed -n '1p' "$rebase_calls")"
assert_eq "align checkout to server rebase" "align fix-ci old new" "$(sed -n '2p' "$rebase_calls")"
rm -f "$rebase_calls" "$rebase_fetch_state"
unset -f api fetch_mr align_after_gitlab_rebase 2>/dev/null || true

active_rebase_calls=$(mktemp "${TMPDIR:-/tmp}/mr-loop-active-rebase.XXXXXX")
active_rebase_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-active-rebase-state.XXXXXX")
printf '0\n' >"$active_rebase_state"
fetch_mr() {
  active_rebase_fetches=$(sed -n '1p' "$active_rebase_state")
  active_rebase_fetches=$((active_rebase_fetches + 1))
  printf '%s\n' "$active_rebase_fetches" >"$active_rebase_state"
  case $active_rebase_fetches in
    1) printf '%s\n' '{"sha":"old","rebase_in_progress":true,"merge_error":null}' ;;
    2) printf '%s\n' '{"sha":"old","rebase_in_progress":false,"merge_error":null}' ;;
    *) printf '%s\n' '{"sha":"new","rebase_in_progress":false,"merge_error":null}' ;;
  esac
}
align_after_gitlab_rebase() { printf 'align %s %s %s\n' "$@" >>"$active_rebase_calls"; }
wait_for_gitlab_rebase old fix-ci
assert_eq "active rebase waits for new SHA before alignment" "align fix-ci old new" \
  "$(sed -n '1p' "$active_rebase_calls")"
assert_eq "active rebase polls past unchanged completed SHA" "3" \
  "$(sed -n '1p' "$active_rebase_state")"
rm -f "$active_rebase_calls" "$active_rebase_state"
unset -f fetch_mr align_after_gitlab_rebase 2>/dev/null || true

ancestry_repo=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-ancestry.XXXXXX")
git -C "$ancestry_repo" init -q
git -C "$ancestry_repo" config user.name test
git -C "$ancestry_repo" config user.email test@example.com
printf 'base\n' >"$ancestry_repo/file"
git -C "$ancestry_repo" add file
git -C "$ancestry_repo" commit -qm base
base_sha=$(git -C "$ancestry_repo" rev-parse HEAD)
printf 'ahead\n' >>"$ancestry_repo/file"
git -C "$ancestry_repo" commit -qam ahead
ahead_sha=$(git -C "$ancestry_repo" rev-parse HEAD)
git -C "$ancestry_repo" switch -q --detach "$base_sha"
printf 'diverged\n' >"$ancestry_repo/other"
git -C "$ancestry_repo" add other
git -C "$ancestry_repo" commit -qm diverged
diverged_sha=$(git -C "$ancestry_repo" rev-parse HEAD)

REPO_ROOT=$ancestry_repo
assert_eq "equal local head relation" "equal" "$(local_head_relation "$base_sha" "$base_sha")"
assert_eq "ahead local head relation" "ahead" "$(local_head_relation "$base_sha" "$ahead_sha")"
assert_eq "behind local head relation" "behind" "$(local_head_relation "$ahead_sha" "$base_sha")"
assert_eq "diverged local head relation" "diverged" "$(local_head_relation "$ahead_sha" "$diverged_sha")"
rm -rf "$ancestry_repo"
REPO_ROOT=

sync_root=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-sync.XXXXXX")
git init -q --bare "$sync_root/remote.git"
git clone -q "$sync_root/remote.git" "$sync_root/work"
git -C "$sync_root/work" config user.name test
git -C "$sync_root/work" config user.email test@example.com
printf 'base\n' >"$sync_root/work/file"
git -C "$sync_root/work" add file
git -C "$sync_root/work" commit -qm base
git -C "$sync_root/work" branch -M fix-ci
git -C "$sync_root/work" push -qu origin fix-ci
remote_sha=$(git -C "$sync_root/work" rev-parse HEAD)
printf 'local\n' >>"$sync_root/work/file"
git -C "$sync_root/work" commit -qam local
local_sha=$(git -C "$sync_root/work" rev-parse HEAD)
REPO_ROOT=$sync_root/work
fetch_mr() {
  printf '{"state":"opened","sha":"%s","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}\n' "$remote_sha"
}
wait_for_mr_sha() { [ "$1" = "$local_sha" ]; }
sync_local_descendant fix-ci "$remote_sha" 7
assert_eq "push local descendant to MR branch" "$local_sha" \
  "$(git --git-dir="$sync_root/remote.git" rev-parse refs/heads/fix-ci)"
unset -f fetch_mr wait_for_mr_sha 2>/dev/null || true
rm -rf "$sync_root"
REPO_ROOT=

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

api() {
  case $1 in
    */pipelines/100/jobs*) printf '[]\n' ;;
    */pipelines/100/bridges*) printf '[{"status":"failed","downstream_pipeline":{"id":200}}]\n' ;;
    */pipelines/200/jobs*) printf '[{"id":300,"name":"child:test","status":"failed"}]\n' ;;
    */pipelines/200/bridges*) printf '[]\n' ;;
    *) return 1 ;;
  esac
}
child_jobs=$(collect_failed_jobs 100)
assert_eq "collect failed job from downstream pipeline" "300	child:test" "$child_jobs"
unset -f api 2>/dev/null || true

redacted=$(printf 'Authorization: Bearer secret-token\nPRIVATE-TOKEN: abc123\nnormal failure\n' | redact_log)
assert_eq "redact bearer token" "Authorization: Bearer [REDACTED]" "$(printf '%s' "$redacted" | sed -n '1p')"
assert_eq "redact private token" "PRIVATE-TOKEN: [REDACTED]" "$(printf '%s' "$redacted" | sed -n '2p')"
assert_eq "preserve normal log" "normal failure" "$(printf '%s' "$redacted" | sed -n '3p')"

fake_bin=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-bin.XXXXXX")
fake_args=$(mktemp "${TMPDIR:-/tmp}/mr-loop-args.XXXXXX")
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$@" >"$MR_LOOP_FAKE_ARGS"' >"$fake_bin/opencode"
chmod +x "$fake_bin/opencode"
original_path=$PATH
PATH="$fake_bin:$PATH"
export PATH
MR_LOOP_FAKE_ARGS=$fake_args
export MR_LOOP_FAKE_ARGS
REPO_ROOT=$ROOT
LAST_MR_SHA=abc
REPAIRS=0
MAX_REPAIRS=3
fetch_failed_logs() { printf 'failed log\n'; }
run_repair_agent '{}' '{"id":7,"web_url":"pipeline-url"}'
prompt_line=$(grep -n '^Diagnose the attached failed jobs' "$fake_args" | cut -d: -f1)
file_line=$(grep -n '^--file$' "$fake_args" | cut -d: -f1)
if [ -n "$prompt_line" ] && [ -n "$file_line" ] && [ "$prompt_line" -lt "$file_line" ]; then
  pass "repair prompt precedes array-valued file option"
else
  fail "repair prompt precedes array-valued file option"
fi
PATH=$original_path
export PATH
rm -rf "$fake_bin"
rm -f "$fake_args"
unset -f fetch_failed_logs 2>/dev/null || true

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

#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/.local/bin/mr-loop"
AGENT="$ROOT/.config/opencode/agents/mr-repair.md"
DISCUSSION_AGENT="$ROOT/.config/opencode/agents/mr-discussion-repair.md"
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
  ASSERT_EXPECTED=$2
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  actual=$?
  set -e
  assert_eq "$name" "$ASSERT_EXPECTED" "$actual"
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

mergeable='{"state":"opened","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"has_conflicts":false,"detailed_merge_status":"mergeable","blocking_discussions_resolved":true,"approved":true}'
assert_status "accept mergeable MR" 0 mr_is_mergeable "$mergeable" "abc"
assert_status "reject changed MR SHA" 1 mr_is_mergeable "$mergeable" "def"
assert_status "reject conflicts" 1 mr_is_mergeable \
  '{"sha":"abc","has_conflicts":true,"detailed_merge_status":"mergeable","blocking_discussions_resolved":true,"approved":true}' "abc"
assert_status "reject missing approval" 1 mr_is_mergeable \
  '{"sha":"abc","has_conflicts":false,"detailed_merge_status":"mergeable","blocking_discussions_resolved":true,"approved":false}' "abc"
assert_status "accept healthy MR with no discussions" 0 mr_is_healthy \
  "$mergeable" "abc" '[]' success
assert_status "reject healthy status with unresolved discussion" 1 mr_is_healthy \
  "$mergeable" "abc" '[{"id":"thread","notes":[{"resolvable":true,"resolved":false}]}]' success
assert_status "reject healthy status with failed exact-SHA pipeline" 1 mr_is_healthy \
  "$mergeable" "abc" '[]' failed

merge_gate_calls=$(mktemp "${TMPDIR:-/tmp}/mr-loop-merge-gate.XXXXXX")
fetch_mr() {
  printf 'fetch-mr\n' >>"$merge_gate_calls"
  printf '%s\n' "$mergeable"
}
fetch_discussions() {
  printf 'fetch-discussions\n' >>"$merge_gate_calls"
  printf '%s\n' '[]'
}
fetch_pipelines() {
  printf 'fetch-pipelines\n' >>"$merge_gate_calls"
  printf '%s\n' '[{"id":9,"sha":"abc","status":"success"}]'
}
run_with_timeout() { printf 'merge:%s\n' "$*" >>"$merge_gate_calls"; }
merge_mr abc fix-ci 7
assert_eq "merge refreshes all health inputs before mutation" \
  "fetch-mr fetch-discussions fetch-pipelines fetch-mr merge:120 glab mr merge 17 --repo acme/widget --sha abc --auto-merge=false --yes" \
  "$(paste -sd ' ' "$merge_gate_calls")"
: >"$merge_gate_calls"
fetch_discussions() {
  printf 'fetch-discussions\n' >>"$merge_gate_calls"
  printf '%s\n' '[{"id":"thread","notes":[{"resolvable":true,"resolved":false}]}]'
}
merge_mr_in_subshell() { ( merge_mr "$@" ); }
assert_status "fresh unresolved discussion prevents merge" 1 merge_mr_in_subshell abc fix-ci 7
assert_eq "rejected health gate prevents merge mutation" \
  "fetch-mr fetch-discussions fetch-pipelines fetch-mr" "$(paste -sd ' ' "$merge_gate_calls")"
: >"$merge_gate_calls"
fresh_mr_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-health-state.XXXXXX")
printf '0\n' >"$fresh_mr_state"
fetch_mr() {
  count=$(sed -n '1p' "$fresh_mr_state")
  count=$((count + 1))
  printf '%s\n' "$count" >"$fresh_mr_state"
  if [ "$count" -eq 1 ]; then
    printf '%s\n' "$mergeable"
  else
    printf '%s\n' "$(printf '%s' "$mergeable" | jq -c '.sha = "changed"')"
  fi
}
assert_status "fresh health check rejects SHA changed during snapshot" 1 \
  fresh_health_check abc fix-ci 7
rm -f "$fresh_mr_state"
rm -f "$merge_gate_calls"
unset -f fetch_mr fetch_discussions fetch_pipelines run_with_timeout merge_mr_in_subshell 2>/dev/null || true
. "$SCRIPT"

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

discussions='[
  {"id":"newer","notes":[{"created_at":"2026-07-16T11:00:00Z","resolvable":true,"resolved":false}]},
  {"id":"resolved","notes":[{"created_at":"2026-07-16T09:00:00Z","resolvable":true,"resolved":true}]},
  {"id":"older","notes":[{"created_at":"2026-07-16T10:00:00Z","resolvable":true,"resolved":false}]}
]'
assert_eq "select oldest unresolved discussion" "older" \
  "$(printf '%s' "$discussions" | next_unresolved_discussion | jq -r .id)"
assert_eq "no unresolved discussion yields null" "null" \
  "$(printf '%s' '[{"id":"done","notes":[{"resolvable":true,"resolved":true}]}]' | next_unresolved_discussion)"

evaluated_discussion='{"id":"thread-1","position":{"new_path":"src/a.c","new_line":9},"notes":[{"id":11,"body":"Fix this","resolvable":true,"resolved":false}]}'
evaluated_snapshot=$(printf '%s' "$evaluated_discussion" | discussion_snapshot)
evaluated_content_snapshot=$(printf '%s' "$evaluated_discussion" | discussion_content_snapshot)
assert_status "accept identical evaluated discussion snapshot" 0 discussion_matches_snapshot "$evaluated_snapshot" "$evaluated_discussion"
assert_status "accept GitLab-managed position SHA refresh" 0 discussion_matches_snapshot "$evaluated_snapshot" \
  '{"id":"thread-1","position":{"new_path":"src/a.c","new_line":9,"base_sha":"base","start_sha":"start","head_sha":"new-head"},"notes":[{"id":11,"body":"Fix this","resolvable":true,"resolved":false}]}'
positioned_discussion='{"id":"thread-2","notes":[{"id":21,"body":"Fix this","resolvable":true,"resolved":false,"position":{"new_path":"src/a.c","new_line":9,"base_sha":"old-base","start_sha":"old-start","head_sha":"old-head"}}]}'
positioned_snapshot=$(printf '%s' "$positioned_discussion" | discussion_snapshot)
assert_status "accept post-push note position SHA refresh" 0 discussion_matches_snapshot "$positioned_snapshot" \
  '{"id":"thread-2","notes":[{"id":21,"body":"Fix this","resolvable":true,"resolved":false,"position":{"new_path":"src/a.c","new_line":9,"base_sha":"new-base","start_sha":"new-start","head_sha":"new-head"}}]}'
assert_status "ignore push-generated system note" 0 discussion_matches_snapshot "$positioned_snapshot" \
  '{"id":"thread-2","notes":[{"id":21,"body":"Fix this","resolvable":true,"resolved":false,"position":{"new_path":"src/a.c","new_line":9,"base_sha":"new-base","start_sha":"new-start","head_sha":"new-head"}},{"id":22,"body":"changed this line in version 2","system":true,"resolvable":false,"resolved":null,"position":{"new_path":"src/a.c","new_line":9}}]}'
assert_status "reject changed note position after push" 1 discussion_matches_snapshot "$positioned_snapshot" \
  '{"id":"thread-2","notes":[{"id":21,"body":"Fix this","resolvable":true,"resolved":false,"position":{"new_path":"src/b.c","new_line":9,"base_sha":"new-base","start_sha":"new-start","head_sha":"new-head"}}]}'
assert_status "reject changed discussion note content" 1 discussion_matches_snapshot "$evaluated_snapshot" \
  '{"id":"thread-1","position":{"new_path":"src/a.c","new_line":9},"notes":[{"id":11,"body":"Changed","resolvable":true,"resolved":false}]}'
assert_status "reject changed discussion position" 1 discussion_matches_snapshot "$evaluated_snapshot" \
  '{"id":"thread-1","position":{"new_path":"src/b.c","new_line":9},"notes":[{"id":11,"body":"Fix this","resolvable":true,"resolved":false}]}'

pagination_args=$(mktemp "${TMPDIR:-/tmp}/mr-loop-pagination.XXXXXX")
api() {
  printf '%s\n' "$1" >"$pagination_args"
  printf '%s\n' '[{"id":"page-1"}]' '[{"id":"page-2"}]'
}
assert_eq "merge paginated discussion arrays" "page-1 page-2" \
  "$(fetch_discussions | jq -r 'map(.id) | join(" ")')"
assert_eq "fetch discussions requests pagination" "--paginate" "$(sed -n '1p' "$pagination_args")"
rm -f "$pagination_args"
unset -f api 2>/dev/null || true

api() { return 1; }
assert_status "propagate paginated discussion API failure" 1 fetch_discussions
unset -f api 2>/dev/null || true

api() { return 0; }
assert_status "reject empty paginated discussion response" 1 fetch_discussions
unset -f api 2>/dev/null || true

api() { printf '[]\n'; }
assert_eq "retain valid empty discussion array" "[]" "$(fetch_discussions)"
unset -f api 2>/dev/null || true

discussion_calls=$(mktemp "${TMPDIR:-/tmp}/mr-loop-discussion-calls.XXXXXX")
discussion_fetch_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-discussion-state.XXXXXX")
discussion_local_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-discussion-local.XXXXXX")
discussion_request_body=$(mktemp "${TMPDIR:-/tmp}/mr-loop-discussion-body.XXXXXX")
discussion_request_path=$(mktemp "${TMPDIR:-/tmp}/mr-loop-discussion-path.XXXXXX")
discussion_repo=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-discussion-repo.XXXXXX")
REPO_ROOT=$discussion_repo
reply_note='{"id":12,"body":"Fixed in the current MR head.","author":{"id":2,"username":"louie"},"type":"DiffNote","resolvable":true,"resolved":false,"system":false,"position":{"base_sha":"old-base","start_sha":"old-start","head_sha":"old-head","new_path":"src/a.c","new_line":9}}'
fetched_reply_note='{"id":12,"body":"Fixed in the current MR head.","author":{"id":2,"username":"louie","name":"Louie"},"type":"DiffNote","resolvable":true,"resolved":false,"resolved_at":null,"system":false,"position":{"base_sha":"new-base","start_sha":"new-start","head_sha":"new-head","new_path":"src/renamed.c","new_line":14}}'
system_note='{"id":10,"body":"changed this line in version 2","system":true,"resolvable":false,"resolved":null,"position":{"new_path":"src/a.c","new_line":9}}'
GITLAB_USER_ID=2
printf '0\n' >"$discussion_fetch_state"
printf 'fix-ci abc\n' >"$discussion_local_state"
git() {
  case $* in
    *branch*--show-current*) sed -n 's/ .*//p' "$discussion_local_state" ;;
    *rev-parse*HEAD*) sed -n 's/.* //p' "$discussion_local_state" ;;
    *) command git "$@" ;;
  esac
}
fetch_mr() {
  printf '%s\n' '{"state":"opened","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}'
}
fetch_discussion() {
  printf 'fetch-discussion:%s\n' "$1" >>"$discussion_calls"
  discussion_fetches=$(sed -n '1p' "$discussion_fetch_state")
  discussion_fetches=$((discussion_fetches + 1))
  printf '%s\n' "$discussion_fetches" >"$discussion_fetch_state"
  if [ "$discussion_fetches" -eq 1 ]; then
    printf '%s' "$evaluated_discussion" | jq -c --argjson system_note "$system_note" '.notes += [$system_note]'
  elif [ "$discussion_fetches" -eq 2 ]; then
    printf '%s' "$evaluated_discussion" | jq -c --argjson system_note "$system_note" --argjson reply_note "$fetched_reply_note" \
      '.notes += [$system_note, $reply_note]'
  else
    printf '%s' "$evaluated_discussion" | jq -c --argjson system_note "$system_note" --argjson reply_note "$fetched_reply_note" \
      '.notes = ((.notes | map(.resolved = true)) + [$system_note, ($reply_note | .resolved = true)])'
  fi
}
api_once() {
  printf 'api-argc:%s\n' "$#" >>"$discussion_calls"
  for api_arg in "$@"; do
    printf 'api-arg:%s\n' "$api_arg" >>"$discussion_calls"
  done
  case $* in
    *--method\ POST*)
      previous_arg=
      for api_arg in "$@"; do
        [ "$previous_arg" = --input ] && {
          printf '%s\n' "$api_arg" >"$discussion_request_path"
          jq -c . "$api_arg" >"$discussion_request_body"
        }
        previous_arg=$api_arg
      done
      printf '%s\n' "$reply_note"
      ;;
    *) printf '{}\n' ;;
  esac
}
api() {
  printf 'api-argc:%s\n' "$#" >>"$discussion_calls"
  for api_arg in "$@"; do
    printf 'api-arg:%s\n' "$api_arg" >>"$discussion_calls"
  done
  case $* in
    *PUT*) printf '{}\n' ;;
    *) printf '{}\n' ;;
  esac
}
reply_and_resolve_discussion thread-1 "Fixed in the current MR head." abc fix-ci 7 "$evaluated_content_snapshot" fix-ci abc
assert_eq "re-fetch exact discussion before reply" "fetch-discussion:thread-1" \
  "$(sed -n '1p' "$discussion_calls")"
assert_eq "discussion reply uses JSON input" "api-arg:--input" "$(sed -n '5p' "$discussion_calls")"
assert_eq "discussion reply JSON preserves text" '{"body":"Fixed in the current MR head."}' \
  "$(sed -n '1p' "$discussion_request_body")"
assert_status "discussion reply request file is cleaned" 1 test -e "$(sed -n '1p' "$discussion_request_path")"
assert_eq "reply discussion before resolve" "api-arg:POST" "$(sed -n '4p' "$discussion_calls")"
assert_eq "resolve discussion second" "api-arg:PUT" "$(grep 'api-arg:PUT' "$discussion_calls")"

special_reply_body=$(mktemp "${TMPDIR:-/tmp}/mr-loop-special-reply.XXXXXX")
api_once() {
  previous_arg=
  for api_arg in "$@"; do
    [ "$previous_arg" = --input ] && jq -c . "$api_arg" >"$special_reply_body"
    previous_arg=$api_arg
  done
  printf '%s\n' "$reply_note"
}
post_discussion_reply thread-1 '[fixed]' >/dev/null
assert_eq "discussion JSON preserves bracketed reply" '{"body":"[fixed]"}' "$(sed -n '1p' "$special_reply_body")"
rm -f "$special_reply_body"

GITLAB_USER_ID=
api() { printf '%s\n' '{"id":null}'; }
assert_status "reject missing authenticated GitLab user id" 1 ensure_gitlab_user
api() { printf '%s\n' '{"id":1.5}'; }
assert_status "reject fractional authenticated GitLab user id" 1 ensure_gitlab_user
api() { printf '%s\n' '{"id":2}'; }
assert_status "accept numeric authenticated GitLab user id" 0 ensure_gitlab_user
assert_eq "retain authenticated GitLab user id" "2" "$GITLAB_USER_ID"

: >"$discussion_calls"
printf '0\n' >"$discussion_fetch_state"
fetch_discussion() {
  discussion_fetches=$(sed -n '1p' "$discussion_fetch_state")
  discussion_fetches=$((discussion_fetches + 1))
  printf '%s\n' "$discussion_fetches" >"$discussion_fetch_state"
  if [ "$discussion_fetches" -eq 1 ]; then
    printf '%s\n' "$evaluated_discussion"
  elif [ "$discussion_fetches" -lt 4 ]; then
    printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" '.notes += [$reply_note]'
  else
    printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" \
      '.notes = ((.notes | map(.resolved = true)) + [($reply_note | .resolved = true)])'
  fi
}
api_once() {
  case $* in
    *--method\ POST*) printf 'post-once\n' >>"$discussion_calls"; return 1 ;;
    *) printf 'resolve-once\n' >>"$discussion_calls"; return 1 ;;
  esac
}
api() {
  printf '%s\n' "$*" >>"$discussion_calls"
  printf '{}\n'
}
assert_status "recover ambiguous discussion reply without retry" 0 \
  reply_and_resolve_discussion thread-1 "Fixed in the current MR head." abc fix-ci 7 "$evaluated_content_snapshot" fix-ci abc
assert_eq "ambiguous reply uses one POST attempt" "1" "$(grep -c '^post-once$' "$discussion_calls")"
assert_eq "ambiguous reply recovery resolves once" "1" "$(grep -c '^resolve-once$' "$discussion_calls")"

: >"$discussion_calls"
printf '0\n' >"$discussion_fetch_state"
resolution_reopen_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-resolution-reopen.XXXXXX")
: >"$resolution_reopen_state"
fetch_discussion() {
  discussion_fetches=$(sed -n '1p' "$discussion_fetch_state")
  discussion_fetches=$((discussion_fetches + 1))
  printf '%s\n' "$discussion_fetches" >"$discussion_fetch_state"
  if [ -s "$resolution_reopen_state" ]; then
    printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" '.notes += [$reply_note, {"id":99,"body":"Concurrent note","author":{"id":3,"username":"reviewer"},"type":"DiscussionNote","resolvable":true,"resolved":false,"system":false}]'
  else
    case $discussion_fetches in
      1) printf '%s\n' "$evaluated_discussion" ;;
      2) printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" '.notes += [$reply_note]' ;;
      *) printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" '.notes = ((.notes | map(.resolved = true)) + [($reply_note | .resolved = true), {"id":99,"body":"Concurrent note","author":{"id":3,"username":"reviewer"},"type":"DiscussionNote","resolvable":true,"resolved":true,"system":false}])' ;;
    esac
  fi
}
api_once() {
  printf '%s\n' "$*" >>"$discussion_calls"
  case $* in
    *--method\ POST*) printf '%s\n' "$reply_note" ;;
    *resolved=false*) printf 'reopened\n' >"$resolution_reopen_state"; printf '{}\n' ;;
    *) printf '{}\n' ;;
  esac
}
assert_status "reopen discussion changed during resolution" 1 \
  reply_and_resolve_discussion thread-1 "Fixed in the current MR head." abc fix-ci 7 "$evaluated_content_snapshot" fix-ci abc
assert_eq "resolution race reopens discussion" "1" "$(grep -c -- '--field resolved=false' "$discussion_calls")"
assert_eq "resolution race reports reopened thread" \
  "discussion thread-1 changed during resolution and was reopened" "$DISCUSSION_ERROR"
rm -f "$resolution_reopen_state"

: >"$discussion_calls"
printf '0\n' >"$discussion_fetch_state"
unresolved_reopen_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-unresolved-reopen.XXXXXX")
: >"$unresolved_reopen_state"
fetch_discussion() {
  discussion_fetches=$(sed -n '1p' "$discussion_fetch_state")
  discussion_fetches=$((discussion_fetches + 1))
  printf '%s\n' "$discussion_fetches" >"$discussion_fetch_state"
  if [ "$discussion_fetches" -eq 1 ]; then
    printf '%s\n' "$evaluated_discussion"
  else
    printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" '.notes += [$reply_note]'
  fi
}
api_once() {
  printf '%s\n' "$*" >>"$discussion_calls"
  case $* in
    *--method\ POST*) printf '%s\n' "$reply_note" ;;
    *resolved=false*) printf 'reopened\n' >"$unresolved_reopen_state"; printf '{}\n' ;;
    *) printf '{}\n' ;;
  esac
}
assert_status "reopen unresolved resolution confirmation" 1 \
  reply_and_resolve_discussion thread-1 "Fixed in the current MR head." abc fix-ci 7 "$evaluated_content_snapshot" fix-ci abc
assert_eq "unresolved confirmation triggers reopen" "1" "$(grep -c -- '--field resolved=false' "$discussion_calls")"
assert_eq "unresolved confirmation reports reopen" \
  "GitLab did not confirm resolution of discussion thread-1 and it was reopened" "$DISCUSSION_ERROR"
rm -f "$unresolved_reopen_state"

: >"$discussion_calls"
fetch_discussion() {
  printf '%s' "$evaluated_discussion" | jq -c '.notes |= map(.resolved = true)'
}
api() { printf '%s\n' "$*" >>"$discussion_calls"; }
assert_status "accept discussion resolved concurrently after repair" 0 \
  reply_and_resolve_discussion thread-1 "Already resolved." abc fix-ci 7 "$evaluated_content_snapshot" fix-ci abc
assert_eq "concurrent resolution needs no API mutation" "0" "$(wc -l <"$discussion_calls" | tr -d ' ')"
assert_eq "concurrent resolution leaves no discussion error" "" "$DISCUSSION_ERROR"

: >"$discussion_calls"
printf '0\n' >"$discussion_fetch_state"
fetch_discussion() {
  discussion_fetches=$(sed -n '1p' "$discussion_fetch_state")
  discussion_fetches=$((discussion_fetches + 1))
  printf '%s\n' "$discussion_fetches" >"$discussion_fetch_state"
  if [ "$discussion_fetches" -eq 1 ]; then
    printf '%s\n' "$evaluated_discussion"
  else
    printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$reply_note" '.notes += [
      {"id":99,"body":"Concurrent note","author":{"id":3,"username":"reviewer"},"type":"DiscussionNote","resolvable":false,"resolved":false},
      $reply_note
    ]'
  fi
}
api_once() {
  printf '%s\n' "$*" >>"$discussion_calls"
  printf '%s\n' "$reply_note"
}
assert_status "reject concurrent note before discussion resolution" 1 \
  reply_and_resolve_discussion thread-1 "Fixed in the current MR head." abc fix-ci 7 "$evaluated_content_snapshot" fix-ci abc
assert_eq "concurrent note prevents discussion resolution" "0" \
  "$(grep -c -- '--method PUT' "$discussion_calls" || true)"
assert_eq "concurrent note reports precise failure" \
  "discussion thread-1 changed while its reply was posted" "$DISCUSSION_ERROR"

: >"$discussion_calls"
fetch_mr() {
  printf '%s\n' '{"state":"opened","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}'
}
fetch_discussion() {
  printf '%s' "$evaluated_discussion" | jq -c '.position.new_line = 10'
}
assert_status "reject no-push position change before reply" 1 \
  reply_and_resolve_discussion thread-1 "Stale position." abc fix-ci 7 \
    "$evaluated_content_snapshot" fix-ci abc "$evaluated_snapshot"
assert_eq "no-push position change prevents API mutation" "0" "$(wc -l <"$discussion_calls" | tr -d ' ')"
assert_eq "no-push position change reports stale discussion" \
  "discussion thread-1 changed after evaluation" "$DISCUSSION_ERROR"

: >"$discussion_calls"
printf '0\n' >"$discussion_fetch_state"
resolution_guard_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-resolution-guard.XXXXXX")
resolution_guard_case=
printf 'before\n' >"$resolution_guard_state"
fetch_mr() {
  case $(sed -n '1p' "$resolution_guard_state") in
    after-sha) printf '%s\n' '{"state":"opened","sha":"changed","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}' ;;
    *) printf '%s\n' '{"state":"opened","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}' ;;
  esac
}
fetch_discussion() {
  discussion_fetches=$(sed -n '1p' "$discussion_fetch_state")
  discussion_fetches=$((discussion_fetches + 1))
  printf '%s\n' "$discussion_fetches" >"$discussion_fetch_state"
  if [ "$discussion_fetches" -eq 1 ]; then
    printf '%s\n' "$evaluated_discussion"
  elif [ "$(sed -n '1p' "$resolution_guard_state")" = reopened ]; then
    printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" '.notes += [$reply_note]'
  elif [ "$discussion_fetches" -eq 2 ]; then
    printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" '.notes += [$reply_note]'
  else
    printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" \
      '.notes = ((.notes | map(.resolved = true)) + [($reply_note | .resolved = true)])'
  fi
}
api_once() {
  printf '%s\n' "$*" >>"$discussion_calls"
  case $* in
    *--method\ POST*) printf '%s\n' "$reply_note" ;;
    *resolved=true*)
      case $resolution_guard_case in
        sha) printf 'after-sha\n' >"$resolution_guard_state" ;;
        head) printf 'fix-ci changed\n' >"$discussion_local_state" ;;
      esac
      printf '{}\n'
      ;;
    *resolved=false*) printf 'reopened\n' >"$resolution_guard_state"; printf '{}\n' ;;
  esac
}
for resolution_guard_case in sha head; do
  : >"$discussion_calls"
  printf '0\n' >"$discussion_fetch_state"
  printf 'before\n' >"$resolution_guard_state"
  printf 'fix-ci abc\n' >"$discussion_local_state"
  assert_status "reject $resolution_guard_case change during resolution" 1 \
    reply_and_resolve_discussion thread-1 "Fixed in the current MR head." abc fix-ci 7 \
      "$evaluated_content_snapshot" fix-ci abc
  assert_eq "$resolution_guard_case resolution race reopens discussion" "1" \
    "$(grep -c -- '--field resolved=false' "$discussion_calls")"
  assert_eq "$resolution_guard_case resolution race reports reopen" \
    "MR, branch, or HEAD changed during resolution of discussion thread-1 and it was reopened" "$DISCUSSION_ERROR"
done
rm -f "$resolution_guard_state"

post_guard_mr_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-post-mr.XXXXXX")
post_guard_reply_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-post-reply.XXXXXX")
post_guard_case=
fetch_mr() {
  case $(sed -n '1p' "$post_guard_mr_state") in
    before) printf '%s\n' '{"state":"opened","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}' ;;
    after-sha) printf '%s\n' '{"state":"opened","sha":"changed","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}' ;;
    after-identity) printf '%s\n' '{"state":"opened","sha":"abc","source_branch":"other","source_project_id":7,"target_project_id":7}' ;;
  esac
}
fetch_discussion() {
  if [ -s "$post_guard_reply_state" ]; then
    printf '%s' "$evaluated_discussion" | jq -c --argjson reply_note "$fetched_reply_note" '.notes += [$reply_note]'
  elif [ "$(sed -n '1p' "$post_guard_mr_state")" = before ]; then
    printf '%s\n' "$evaluated_discussion"
  else
    printf '%s' "$evaluated_discussion" | jq -c '.notes += [{"id":12,"body":"Fixed in the current MR head.","resolvable":false,"resolved":false}]'
  fi
}
api_once() {
  printf '%s\n' "$*" >>"$discussion_calls"
  printf 'posted\n' >"$post_guard_reply_state"
  case $post_guard_case in
    sha|identity) printf 'after-%s\n' "$post_guard_case" >"$post_guard_mr_state" ;;
    branch) printf 'other abc\n' >"$discussion_local_state" ;;
    head) printf 'fix-ci changed\n' >"$discussion_local_state" ;;
  esac
  printf '%s\n' "$reply_note"
}
for post_guard_case in sha identity branch head; do
  : >"$discussion_calls"
  : >"$post_guard_reply_state"
  printf 'before\n' >"$post_guard_mr_state"
  printf 'fix-ci abc\n' >"$discussion_local_state"
  assert_status "reject $post_guard_case change between reply and resolve" 1 \
    reply_and_resolve_discussion thread-1 "Fixed in the current MR head." abc fix-ci 7 "$evaluated_content_snapshot" fix-ci abc
  assert_eq "$post_guard_case change prevents discussion resolution" "0" \
    "$(grep -c -- '--method PUT' "$discussion_calls" || true)"
  case $post_guard_case in
    sha|identity) expected_guard_error="MR changed after replying to discussion thread-1" ;;
    branch|head) expected_guard_error="local branch or HEAD changed before resolving discussion thread-1" ;;
  esac
  assert_eq "$post_guard_case change reports exact guard" "$expected_guard_error" "$DISCUSSION_ERROR"
done
rm -f "$post_guard_mr_state" "$post_guard_reply_state"

: >"$discussion_calls"
printf 'fix-ci abc\n' >"$discussion_local_state"
fetch_mr() {
  printf '%s\n' '{"state":"opened","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}'
}
fetch_discussion() { printf '%s\n' "$evaluated_discussion"; }
api_once() {
  printf '%s\n' "$*" >>"$discussion_calls"
  return 1
}
assert_status "propagate discussion reply failure" 1 \
  reply_and_resolve_discussion thread-1 "Cannot post." abc fix-ci 7 "$evaluated_content_snapshot" fix-ci abc
assert_eq "do not resolve after reply failure" "0" \
  "$(grep -c -- '--method PUT' "$discussion_calls" || true)"
assert_eq "reply failure reaches one POST" "1" "$(grep -c -- '--method POST' "$discussion_calls")"

: >"$discussion_calls"
fetch_mr() { printf '%s\n' '{"sha":"changed"}'; }
assert_status "reject changed MR before discussion reply" 1 \
  reply_and_resolve_discussion thread-1 "Stale reply." abc fix-ci 7 "$evaluated_content_snapshot" fix-ci abc
assert_eq "changed MR prevents discussion API mutation" "0" "$(wc -l <"$discussion_calls" | tr -d ' ')"
rm -f "$discussion_calls" "$discussion_fetch_state" "$discussion_local_state" \
  "$discussion_request_body" "$discussion_request_path"
rm -rf "$discussion_repo"
unset -f fetch_mr fetch_discussion api api_once git 2>/dev/null || true
GITLAB_USER_ID=
REPO_ROOT=

process_root=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-process.XXXXXX")
REPO_ROOT=$process_root
REPAIRS=4
LAST_MR_SHA=abc
run_discussion_agent() {
  DISCUSSION_DISPOSITION=$(printf '%s' "$2" | jq -r .id)
  DISCUSSION_REPLY="Reply with spaces."
  [ -z "${AGENT_MUTATION_BRANCH:-}" ] || printf '%s\n' "$AGENT_MUTATION_BRANCH" >"$process_root/test-branch"
  [ -z "${AGENT_MUTATION_HEAD:-}" ] || printf '%s\n' "$AGENT_MUTATION_HEAD" >"$process_root/test-head"
}
process_discussion_json() {
  jq -cn --arg id "$1" '{id: $id, notes: [{id: 1, body: "Feedback", resolvable: true, resolved: false}]}'
}
fetch_discussion() { process_discussion_json "$1"; }
git() {
  case $* in
    *branch*--show-current*) sed -n '1p' "$process_root/test-branch" 2>/dev/null || printf '%s\n' fix-ci ;;
    *rev-parse*HEAD*) sed -n '1p' "$process_root/test-head" 2>/dev/null || printf '%s\n' abc ;;
    *status*porcelain*) [ ! -e "$process_root/change" ] || printf 'changed\n' ;;
    *) command git "$@" ;;
  esac
}
commit_generated_repair() {
  printf '%s\n' "$*" >"$process_root/commit"
  REPAIRS=$((REPAIRS + 1))
  LAST_MR_SHA=def
}
reply_and_resolve_discussion() { printf '%s|%s|%s\n' "$1" "$2" "$3" >"$process_root/reply"; }
mr='{"sha":"abc"}'
commit_and_push fix-ci abc 7
assert_eq "pipeline repair preserves validated project identity" \
  "fix-ci abc 7 fix(ci): repair failed pipeline" "$(sed -n '1p' "$process_root/commit")"

rm -f "$process_root/commit"
REPAIRS=4
process_discussion "$mr" "$(process_discussion_json fixed)" fix-ci 7
assert_eq "fixed discussion uses review commit message" \
  "fix-ci abc 7 fix(review): resolve MR feedback fix-ci abc" "$(sed -n '1p' "$process_root/commit")"
assert_eq "fixed discussion replies only after converged push" \
  "fixed|Reply with spaces.|def" "$(sed -n '1p' "$process_root/reply")"
assert_eq "fixed discussion shares repair budget" "5" "$REPAIRS"

rm -f "$process_root/commit" "$process_root/reply"
fetch_discussion() {
  process_discussion_json "$1" | jq -c '.notes[0].body = "Edited feedback"'
}
assert_status "stale feedback blocks fixed repair commit" 1 \
  process_discussion "$mr" "$(process_discussion_json fixed)" fix-ci 7
assert_status "stale feedback prevents repair commit" 1 test -e "$process_root/commit"
assert_eq "stale feedback reports evaluation race" \
  "discussion fixed changed during evaluation" "$DISCUSSION_ERROR"
fetch_discussion() { process_discussion_json "$1"; }

rm -f "$process_root/commit" "$process_root/reply"
process_discussion "$mr" "$(process_discussion_json invalid)" fix-ci 7
assert_status "invalid discussion rejects code changes" 1 test -e "$process_root/commit"
assert_eq "invalid discussion replies without push" \
  "invalid|Reply with spaces.|abc" "$(sed -n '1p' "$process_root/reply")"

printf 'changed\n' >"$process_root/change"
assert_status "obsolete discussion rejects agent code changes" 1 \
  process_discussion "$mr" "$(process_discussion_json obsolete)" fix-ci 7
rm -f "$process_root/change" "$process_root/reply"
assert_status "blocked discussion requires human intervention" 2 \
  process_discussion "$mr" "$(process_discussion_json blocked)" fix-ci 7
assert_status "blocked discussion remains unresolved" 1 test -e "$process_root/reply"
rm -f "$process_root/commit" "$process_root/reply"
AGENT_MUTATION_HEAD=changed
assert_status "discussion agent HEAD change stops all mutations" 1 \
  process_discussion "$mr" "$(process_discussion_json invalid)" fix-ci 7
assert_status "changed discussion-agent HEAD prevents reply" 1 test -e "$process_root/reply"
assert_status "changed discussion-agent HEAD prevents commit" 1 test -e "$process_root/commit"
unset AGENT_MUTATION_HEAD
rm -f "$process_root/test-head"
AGENT_MUTATION_BRANCH=other
assert_status "discussion agent branch change stops all mutations" 1 \
  process_discussion "$mr" "$(process_discussion_json invalid)" fix-ci 7
assert_status "changed discussion-agent branch prevents reply" 1 test -e "$process_root/reply"
assert_status "changed discussion-agent branch prevents commit" 1 test -e "$process_root/commit"
unset AGENT_MUTATION_BRANCH
unset -f run_discussion_agent process_discussion_json fetch_discussion commit_generated_repair reply_and_resolve_discussion git 2>/dev/null || true
rm -rf "$process_root"
. "$SCRIPT"
parse_args "https://gitlab.com/acme/widget/-/merge_requests/17"
REPO_ROOT=$ROOT
REPAIRS=0

result_root=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-result.XXXXXX")
REPO_ROOT=$result_root
DISCUSSION_RESULT_FILE="$REPO_ROOT/.mr-loop-discussion-result.json"
printf '%s\n' '{"disposition":"invalid","reply":"The current code already validates this state."}' >"$DISCUSSION_RESULT_FILE"
parse_discussion_result
assert_eq "parse discussion disposition" "invalid" "$DISCUSSION_DISPOSITION"
assert_eq "parse discussion reply" "The current code already validates this state." "$DISCUSSION_REPLY"
assert_status "reject unknown discussion disposition" 1 sh -c \
  'printf "%s\n" '\''{"disposition":"maybe","reply":"x"}'\'' >"$1"; . "$2"; REPO_ROOT=$(dirname "$1"); DISCUSSION_RESULT_FILE=$1; parse_discussion_result' \
  sh "$DISCUSSION_RESULT_FILE" "$SCRIPT"
for invalid_result in \
  '{' \
  '{"disposition":"invalid","reply":"x","extra":true}' \
  '{"disposition":"invalid"}' \
  '{"disposition":1,"reply":"x"}' \
  '{"disposition":"invalid","reply":false}' \
  '{"disposition":"invalid","reply":"  \n\t"}'
do
  printf '%s\n' "$invalid_result" >"$DISCUSSION_RESULT_FILE"
  assert_status "reject malformed or non-contract discussion result: $invalid_result" 1 parse_discussion_result
done
rm -rf "$result_root"
REPO_ROOT=$ROOT

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
  rebase_fetches=$(sed -n '1p' "$rebase_fetch_state" 2>/dev/null || printf '0\n')
  rebase_fetches=$((rebase_fetches + 1))
  printf '%s\n' "$rebase_fetches" >"$rebase_fetch_state"
  case $rebase_fetches in
    1) printf '%s\n' '{"state":"opened","sha":"old","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}' ;;
    2) printf '%s\n' '{"state":"opened","sha":"old","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":true,"merge_error":null}' ;;
    *) printf '%s\n' '{"state":"opened","sha":"new","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}' ;;
  esac
}
POLL_INTERVAL=0
EXPECTED_LOCAL_SHA=old
align_after_gitlab_rebase() { printf 'align %s %s %s\n' "$@" >>"$rebase_calls"; }
request_gitlab_rebase old fix-ci 7
assert_eq "request rebase before local alignment" \
  "--method PUT projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/rebase" \
  "$(sed -n '1p' "$rebase_calls")"
assert_eq "align checkout to server rebase" "align fix-ci old new" "$(sed -n '2p' "$rebase_calls")"
assert_eq "request observes active MR state before alignment" "3" "$(sed -n '1p' "$rebase_fetch_state")"
rm -f "$rebase_calls" "$rebase_fetch_state"
unset -f api fetch_mr align_after_gitlab_rebase 2>/dev/null || true

immediate_rebase_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-immediate-rebase.XXXXXX")
printf '0\n' >"$immediate_rebase_state"
api() { printf '%s\n' '{"rebase_in_progress":true}'; }
fetch_mr() {
  immediate_fetches=$(sed -n '1p' "$immediate_rebase_state")
  immediate_fetches=$((immediate_fetches + 1))
  printf '%s\n' "$immediate_fetches" >"$immediate_rebase_state"
  if [ "$immediate_fetches" -eq 1 ]; then
    printf '%s\n' '{"state":"opened","sha":"old","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}'
  else
    printf '%s\n' '{"state":"opened","sha":"new","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}'
  fi
}
align_after_gitlab_rebase() { printf 'aligned\n' >>"$immediate_rebase_state"; }
assert_status "request rejects immediate new inactive MR state" 1 request_gitlab_rebase old fix-ci 7
assert_eq "immediate unobserved rebase result is not aligned" "0" \
  "$(grep -c aligned "$immediate_rebase_state" || true)"
rm -f "$immediate_rebase_state"
unset -f api fetch_mr align_after_gitlab_rebase 2>/dev/null || true

active_rebase_calls=$(mktemp "${TMPDIR:-/tmp}/mr-loop-active-rebase.XXXXXX")
active_rebase_state=$(mktemp "${TMPDIR:-/tmp}/mr-loop-active-rebase-state.XXXXXX")
printf '0\n' >"$active_rebase_state"
fetch_mr() {
  active_rebase_fetches=$(sed -n '1p' "$active_rebase_state")
  active_rebase_fetches=$((active_rebase_fetches + 1))
  printf '%s\n' "$active_rebase_fetches" >"$active_rebase_state"
  case $active_rebase_fetches in
    1) printf '%s\n' '{"state":"opened","sha":"old","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":true,"merge_error":null}' ;;
    *) printf '%s\n' '{"state":"opened","sha":"new","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}' ;;
  esac
}
align_after_gitlab_rebase() { printf 'align %s %s %s\n' "$@" >>"$active_rebase_calls"; }
wait_for_gitlab_rebase old fix-ci 7
assert_eq "active rebase waits for new SHA before alignment" "align fix-ci old new" \
  "$(sed -n '1p' "$active_rebase_calls")"
assert_eq "active rebase requires direct active-to-new transition" "2" \
  "$(sed -n '1p' "$active_rebase_state")"
rm -f "$active_rebase_calls" "$active_rebase_state"
unset -f fetch_mr align_after_gitlab_rebase 2>/dev/null || true

fetch_mr() {
  printf '%s\n' '{"state":"opened","sha":"other","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":true,"merge_error":null}'
}
align_after_gitlab_rebase() { return 0; }
assert_status "reject unrelated SHA change during active rebase" 1 wait_for_gitlab_rebase old fix-ci 7
fetch_mr() {
  printf '%s\n' '{"state":"closed","sha":"new","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}'
}
assert_status "reject closed MR while rebase converges" 1 wait_for_gitlab_rebase old fix-ci 7
fetch_mr() {
  printf '%s\n' '{"state":"opened","sha":"old","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}'
}
assert_status "reject ambiguous inactive rebase without new SHA" 1 wait_for_gitlab_rebase old fix-ci 7
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
leader_exit_child_file=$(mktemp "${TMPDIR:-/tmp}/mr-loop-leader-exit.XXXXXX")
assert_status "bounded command kills child after leader exits on TERM" 142 run_with_timeout 1 sh -c \
  'trap "exit 0" TERM; sh -c '\''trap "" TERM; while :; do sleep 1; done'\'' & printf "%s\n" "$!" >"$1"; wait' \
  sh "$leader_exit_child_file"
leader_exit_child_pid=$(sed -n '1p' "$leader_exit_child_file")
rm -f "$leader_exit_child_file"
assert_status "leader-exit child is terminated" 1 kill -0 "$leader_exit_child_pid"
pid_file=$(mktemp "${TMPDIR:-/tmp}/mr-loop-timeout.XXXXXX")
assert_status "bounded command times out process tree" 142 run_with_timeout 1 sh -c \
  'sleep 20 & echo $! >"$1"; wait' sh "$pid_file"
child_pid=$(sed -n '1p' "$pid_file")
rm -f "$pid_file"
assert_status "timed out child is terminated" 1 kill -0 "$child_pid"
assert_status "fatal guard terminates caller" 1 sh -c \
  '. "$1"; die "stop"; exit 0' sh "$SCRIPT"

interrupt_child_file=$(mktemp "${TMPDIR:-/tmp}/mr-loop-interrupt-child.XXXXXX")
interrupt_repo=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-interrupt-repo.XXXXXX")
sh -c '
  . "$1"
  REPO_ROOT=$2
  print_summary() { :; }
  initialize_active_command_file || exit 1
  trap "handle_interrupt" INT TERM HUP
  trap "cleanup" EXIT
  run_with_timeout 30 sh -c '\''trap "" TERM; printf "%s\n" "$$" >"$1"; while :; do sleep 1; done'\'' sh "$3"
' sh "$SCRIPT" "$interrupt_repo" "$interrupt_child_file" &
interrupt_supervisor_pid=$!
interrupt_wait=0
while [ ! -s "$interrupt_child_file" ] && [ "$interrupt_wait" -lt 50 ]; do
  sleep 0.1
  interrupt_wait=$((interrupt_wait + 1))
done
interrupt_child_pid=$(sed -n '1p' "$interrupt_child_file")
kill -TERM "$interrupt_supervisor_pid"
set +e
wait "$interrupt_supervisor_pid"
interrupt_status=$?
set -e
assert_eq "interrupt exits supervisor with 130" "130" "$interrupt_status"
assert_status "interrupt terminates active child" 1 kill -0 "$interrupt_child_pid"
rm -f "$interrupt_child_file"
rm -rf "$interrupt_repo"

transport_bin=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-transport-bin.XXXXXX")
transport_repo=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-transport-repo.XXXXXX")
transport_body=$(mktemp "${TMPDIR:-/tmp}/mr-loop-transport-body.XXXXXX")
printf '%s\n' '#!/bin/sh' \
  'previous_arg=' \
  'for arg do' \
  '  if [ "$previous_arg" = --input ]; then cp "$arg" "$MR_LOOP_TRANSPORT_BODY"; fi' \
  '  previous_arg=$arg' \
  'done' \
  'printf '\''%s\n'\'' '\''{"id":12,"body":"[fixed]","author":{"id":2},"type":"DiffNote"}'\''' \
  >"$transport_bin/glab"
chmod +x "$transport_bin/glab"
transport_path=$PATH
PATH="$transport_bin:$PATH"
export PATH
MR_LOOP_TRANSPORT_BODY=$transport_body
export MR_LOOP_TRANSPORT_BODY
REPO_ROOT=$transport_repo
COMMAND_TIMEOUT=5
post_discussion_reply thread-1 '[fixed]'
assert_eq "timeout wrapper preserves discussion JSON file" '{"body":"[fixed]"}' \
  "$(jq -c . "$transport_body")"
assert_eq "timeout wrapper returns posted discussion note" "[fixed]" \
  "$(printf '%s' "$POSTED_NOTE" | jq -r .body)"
assert_eq "discussion request path clears after real transport" "" "$DISCUSSION_REQUEST_FILE"
assert_eq "discussion response path clears after real transport" "" "$DISCUSSION_RESPONSE_FILE"
PATH=$transport_path
export PATH
rm -rf "$transport_bin" "$transport_repo"
rm -f "$transport_body"
REPO_ROOT=

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
agent_repo=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-agent-repo.XXXXXX")
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$@" >"$MR_LOOP_FAKE_ARGS"' >"$fake_bin/opencode"
chmod +x "$fake_bin/opencode"
original_path=$PATH
PATH="$fake_bin:$PATH"
export PATH
MR_LOOP_FAKE_ARGS=$fake_args
export MR_LOOP_FAKE_ARGS
REPO_ROOT=$agent_repo
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
repair_context_path=$(sed -n "$((file_line + 1))p" "$fake_args")
case $repair_context_path in
  "$agent_repo"/.mr-loop-context.*) pass "repair context stays inside repository" ;;
  *) fail "repair context stays inside repository (got '$repair_context_path')" ;;
esac
printf '%s\n' '#!/bin/sh' \
  'printf "%s\n" "$@" >"$MR_LOOP_FAKE_ARGS"' \
  'for arg do context_path=$arg; done' \
  'cp "$context_path" "$MR_LOOP_FAKE_DISCUSSION_CONTEXT"' \
  'printf "%s\n" '\''{"disposition":"obsolete","reply":"The referenced code has already been removed."}'\'' >"$MR_LOOP_FAKE_DISCUSSION_RESULT"' \
  >"$fake_bin/opencode"
MR_LOOP_FAKE_DISCUSSION_RESULT="$agent_repo/.mr-loop-discussion-result.json"
MR_LOOP_FAKE_DISCUSSION_CONTEXT=$(mktemp "${TMPDIR:-/tmp}/mr-loop-discussion-context.XXXXXX")
export MR_LOOP_FAKE_DISCUSSION_RESULT
export MR_LOOP_FAKE_DISCUSSION_CONTEXT
run_discussion_agent '{"sha":"abc","title":"Fix project names","description":"SUB-1016 scope","source_branch":"fix-ci","target_branch":"main"}' '{"id":"discussion-1"}'
discussion_file_line=$(grep -n '^--file$' "$fake_args" | cut -d: -f1)
discussion_context_path=$(sed -n "$((discussion_file_line + 1))p" "$fake_args")
case $discussion_context_path in
  "$agent_repo"/.mr-loop-discussion.*) pass "discussion context stays inside repository" ;;
  *) fail "discussion context stays inside repository (got '$discussion_context_path')" ;;
esac
assert_status "discussion context includes MR title" 0 grep -q '^MR title: Fix project names$' "$MR_LOOP_FAKE_DISCUSSION_CONTEXT"
assert_status "discussion context includes MR description" 0 grep -q '^SUB-1016 scope$' "$MR_LOOP_FAKE_DISCUSSION_CONTEXT"
assert_status "discussion context includes source branch" 0 grep -q '^Source branch: fix-ci$' "$MR_LOOP_FAKE_DISCUSSION_CONTEXT"
assert_status "discussion context includes target branch" 0 grep -q '^Target branch: main$' "$MR_LOOP_FAKE_DISCUSSION_CONTEXT"
assert_eq "discussion agent disposition retained after cleanup" "obsolete" "$DISCUSSION_DISPOSITION"
assert_eq "discussion agent reply retained after cleanup" "The referenced code has already been removed." "$DISCUSSION_REPLY"
assert_status "discussion result removed before repository inspection" 1 test -e "$MR_LOOP_FAKE_DISCUSSION_RESULT"
assert_eq "discussion context cleared after invocation" "" "$DISCUSSION_CONTEXT_FILE"
printf '%s\n' '#!/bin/sh' \
  'printf "%s\n" '\''{"disposition":"invalid","reply":"   "}'\'' >"$MR_LOOP_FAKE_DISCUSSION_RESULT"' \
  >"$fake_bin/opencode"
assert_status "discussion agent rejects invalid result" 1 \
  run_discussion_agent '{"sha":"abc"}' '{"id":"discussion-1"}'
assert_status "failed discussion agent cleans result file" 1 test -e "$MR_LOOP_FAKE_DISCUSSION_RESULT"
assert_eq "failed discussion agent clears context path" "" "$DISCUSSION_CONTEXT_FILE"
assert_eq "failed discussion agent clears result path" "" "$DISCUSSION_RESULT_FILE"
printf '%s\n' '#!/bin/sh' 'exit 1' >"$fake_bin/opencode"
assert_status "discussion agent propagates invocation failure" 1 \
  run_discussion_agent '{"sha":"abc"}' '{"id":"discussion-1"}'
assert_status "invocation failure cleans discussion result" 1 test -e "$MR_LOOP_FAKE_DISCUSSION_RESULT"
assert_eq "invocation failure clears context path" "" "$DISCUSSION_CONTEXT_FILE"
assert_eq "invocation failure clears result path" "" "$DISCUSSION_RESULT_FILE"
PATH=$original_path
export PATH
rm -rf "$fake_bin" "$agent_repo"
rm -f "$fake_args" "$MR_LOOP_FAKE_DISCUSSION_CONTEXT"
unset -f fetch_failed_logs 2>/dev/null || true
REPO_ROOT=$ROOT

if [ -f "$DISCUSSION_AGENT" ]; then
  pass "discussion repair agent exists"
else
  fail "discussion repair agent exists ($DISCUSSION_AGENT is missing)"
fi
if [ -f "$DISCUSSION_AGENT" ] && \
   grep -Eq '"?\*"?: deny' "$DISCUSSION_AGENT" && \
   grep -Eq 'external_directory: deny' "$DISCUSSION_AGENT" && \
   grep -Eq 'webfetch: deny' "$DISCUSSION_AGENT" && \
   grep -q 'fixed.*invalid.*obsolete.*blocked' "$DISCUSSION_AGENT" && \
   grep -q '.mr-loop-discussion-result.json' "$DISCUSSION_AGENT"; then
  pass "discussion agent is restricted and structured"
else
  fail "discussion agent is restricted and structured"
fi

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
if [ -f "$AGENT" ] && grep -Eq 'external_directory: deny' "$AGENT" && grep -Eq 'webfetch: deny' "$AGENT"; then
  pass "repair agent denies external directories and network fetches"
else
  fail "repair agent denies external directories and network fetches"
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
if [ -f "$COMMAND" ] && grep -qi 'synchronize, repair discussions' "$COMMAND"; then
  pass "slash command describes expanded supervisor"
else
  fail "slash command describes expanded supervisor"
fi

fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/mr-loop-fixture.XXXXXX")
fixture_events="$fixture_root/events"
fixture_phase="$fixture_root/phase"
printf 'sync\n' >"$fixture_phase"
REPO_ROOT=$fixture_root
EXPECTED_LOCAL_SHA=local
REPAIRS=0
POLL_INTERVAL=0
MAX_RUNTIME=60
local_head_relation() { printf 'ahead\n'; }
git() {
  case $* in
    *branch*--show-current*) printf 'fix-ci\n' ;;
    *rev-parse*HEAD*) printf '%s\n' "$EXPECTED_LOCAL_SHA" ;;
    *status*--porcelain*) return 0 ;;
    *) return 0 ;;
  esac
}
run_with_timeout() {
  case $* in
    *git*push*) printf 'descendant-sync\n' >>"$fixture_events" ;;
    *glab*merge*) printf 'merge\n' >>"$fixture_events" ;;
  esac
}
wait_for_mr_sha() { return 0; }
fetch_mr() {
  case $(sed -n '1p' "$fixture_phase") in
    sync) printf '%s\n' '{"state":"opened","sha":"remote","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}' ;;
    rebase) printf '%s\n' '{"state":"opened","sha":"local","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"diverged_commits_count":1,"rebase_in_progress":false,"merge_error":null,"detailed_merge_status":"checking"}' ;;
    discussion) printf '%s\n' '{"state":"opened","sha":"rebased","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"diverged_commits_count":0,"rebase_in_progress":false,"merge_error":null,"detailed_merge_status":"checking"}' ;;
    pipeline) printf '%s\n' '{"state":"opened","sha":"discussion","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"diverged_commits_count":0,"rebase_in_progress":false,"merge_error":null,"detailed_merge_status":"checking"}' ;;
    healthy) printf '%s\n' '{"state":"opened","sha":"final","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"diverged_commits_count":0,"rebase_in_progress":false,"merge_error":null,"has_conflicts":false,"detailed_merge_status":"mergeable","blocking_discussions_resolved":true,"approved":true}' ;;
  esac
}
request_gitlab_rebase() {
  printf 'rebase\n' >>"$fixture_events"
  EXPECTED_LOCAL_SHA=rebased
  printf 'discussion\n' >"$fixture_phase"
}
fetch_discussions() {
  case $(sed -n '1p' "$fixture_phase") in
    discussion) printf '%s\n' '[{"id":"thread","notes":[{"created_at":"2026-07-16T10:00:00Z","resolvable":true,"resolved":false}]}]' ;;
    *) printf '[]\n' ;;
  esac
}
process_discussion() {
  printf 'discussion-repair\n' >>"$fixture_events"
  REPAIRS=$((REPAIRS + 1))
  EXPECTED_LOCAL_SHA=discussion
  printf 'pipeline\n' >"$fixture_phase"
}
fetch_pipelines() {
  case $(sed -n '1p' "$fixture_phase") in
    pipeline) printf '%s\n' '[{"id":31,"sha":"discussion","status":"failed"}]' ;;
    healthy) printf '%s\n' '[{"id":44,"sha":"final","status":"success"}]' ;;
  esac
}
run_repair_agent() { printf 'pipeline-repair\n' >>"$fixture_events"; }
commit_and_push() {
  REPAIRS=$((REPAIRS + 1))
  EXPECTED_LOCAL_SHA=final
  printf 'pipeline-push\n' >>"$fixture_events"
  printf 'healthy\n' >"$fixture_phase"
}
print_summary() { printf '%s\n' "$1" >>"$fixture_events"; }
sync_local_descendant fix-ci remote 7
printf 'rebase\n' >"$fixture_phase"
ON_SUCCESS=notify
monitor
ON_SUCCESS=merge
monitor
assert_eq "stubbed production orchestration covers approved state flow" \
  "descendant-sync rebase discussion-repair pipeline-repair pipeline-push ready merge merged" \
  "$(paste -sd ' ' "$fixture_events")"
assert_eq "stubbed orchestration shares discussion and pipeline repair budget" "2" "$REPAIRS"
rm -rf "$fixture_root"
unset -f local_head_relation git run_with_timeout wait_for_mr_sha fetch_mr request_gitlab_rebase \
  fetch_discussions process_discussion fetch_pipelines run_repair_agent commit_and_push print_summary 2>/dev/null || true

printf '1..%s\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]

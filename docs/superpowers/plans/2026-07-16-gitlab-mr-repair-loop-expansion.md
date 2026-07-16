# GitLab MR Repair Loop Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `mr-loop` to push safe local descendant commits, request GitLab rebases, repair and resolve MR discussions, repair failed pipelines, and notify or merge only when the MR is healthy.

**Architecture:** Keep one deterministic POSIX-shell state machine in `.local/bin/mr-loop`. Add small functions for each guarded transition, while restricted OpenCode agents only evaluate or edit; the supervisor remains the sole owner of Git commits, pushes, GitLab replies, resolutions, rebases, and merges.

**Tech Stack:** POSIX shell, Git, `glab` REST API, `jq`, OpenCode agents, dependency-free shell tests

## Global Constraints

- Do not run `mr-loop` against MR `2127` or any live merge request while implementing or testing.
- Never force-push, locally rebase, reset, stash, discard local work, or support fork MRs.
- Push a clean local `HEAD` only when the current MR SHA is its ancestor; stop when local history is behind or divergent.
- Use only GitLab's merge-request rebase API when the source branch is behind the target.
- Process unresolved resolvable discussions one at a time; reply before resolving.
- Generated discussion and pipeline repair pushes share a default budget of 12.
- Pre-existing local descendant pushes and GitLab rebases do not consume the generated-repair budget.
- Re-fetch and validate MR identity and SHA before every remote mutation.
- The agents have no shell access and never stage, commit, push, rebase, reply, resolve, or merge.

---

### Task 1: Safe Local Descendant Synchronization

**Files:**
- Modify: `.local/bin/mr-loop:5-30,318-340,478-489`
- Modify: `tests/mr-loop-test.sh:52-105`

**Interfaces:**
- Produces: `local_head_relation <mr_sha> <local_sha>` printing `equal|ahead|behind|diverged`.
- Produces: `wait_for_mr_sha <expected_sha>` returning only when the open MR reports that SHA.
- Changes: `checkout_mr_branch <mr_json>` normally pushes a clean descendant and sets `EXPECTED_LOCAL_SHA` to local `HEAD`.

- [ ] **Step 1: Add failing ancestry and budget tests**

Add temporary-repository tests after the existing MR identity assertions:

```sh
assert_eq "default generated repair limit" "12" "$MAX_REPAIRS"

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
```

Add a guarded-push test using a bare remote and working clone so no network is
involved:

```sh
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
```

- [ ] **Step 2: Run tests and verify RED**

Run: `sh tests/mr-loop-test.sh`

Expected: failures for the default limit (`3`, not `12`) and missing `local_head_relation`.

- [ ] **Step 3: Implement local relationship and convergence helpers**

Change the default and add these functions before `checkout_mr_branch`:

```sh
MAX_REPAIRS=${MR_LOOP_MAX_REPAIRS:-12}
STATE_CHANGE_TIMEOUT=${MR_LOOP_STATE_CHANGE_TIMEOUT:-600}

local_head_relation() {
  mr_sha=$1
  local_sha=$2
  if [ "$mr_sha" = "$local_sha" ]; then
    printf 'equal\n'
  elif git -C "$REPO_ROOT" merge-base --is-ancestor "$mr_sha" "$local_sha"; then
    printf 'ahead\n'
  elif git -C "$REPO_ROOT" merge-base --is-ancestor "$local_sha" "$mr_sha"; then
    printf 'behind\n'
  else
    printf 'diverged\n'
  fi
}

wait_for_mr_sha() {
  expected_sha=$1
  deadline=$(($(date +%s) + STATE_CHANGE_TIMEOUT))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    current_mr=$(fetch_mr) || return 1
    [ "$(printf '%s' "$current_mr" | jq -r .state)" = opened ] || return 1
    if [ "$(printf '%s' "$current_mr" | jq -r .sha)" = "$expected_sha" ]; then
      return 0
    fi
    sleep "$POLL_INTERVAL"
  done
  return 1
}

sync_local_descendant() {
  source_branch=$1
  remote_sha=$2
  project_id=$3
  local_sha=$(git -C "$REPO_ROOT" rev-parse HEAD) || return 1
  [ "$(local_head_relation "$remote_sha" "$local_sha")" = ahead ] || return 1
  latest_mr=$(fetch_mr) || return 1
  mr_matches_expected "$latest_mr" "$remote_sha" "$source_branch" "$project_id" || return 1
  run_with_timeout "$COMMAND_TIMEOUT" git -C "$REPO_ROOT" push origin "HEAD:$source_branch" || return 1
  wait_for_mr_sha "$local_sha" || return 1
  EXPECTED_LOCAL_SHA=$local_sha
}
```

Replace the strict equality tail of `checkout_mr_branch` with:

```sh
  local_sha=$(git rev-parse HEAD)
  case $(local_head_relation "$remote_sha" "$local_sha") in
    equal) ;;
    ahead)
      sync_local_descendant "$source_branch" "$remote_sha" "$target_project_id" || \
        die "Unable to push local descendant commits or converge MR state"
      ;;
    behind) die "Local branch is behind MR SHA $remote_sha" ;;
    diverged) die "Local branch diverges from MR SHA $remote_sha" ;;
  esac
  EXPECTED_LOCAL_SHA=$(git -C "$REPO_ROOT" rev-parse HEAD)
```

- [ ] **Step 4: Run dependency-free tests and syntax check**

Run: `sh -n .local/bin/mr-loop && sh tests/mr-loop-test.sh`

Expected: shell syntax succeeds and all tests print `ok` with zero `not ok` lines.

- [ ] **Step 5: Commit the local synchronization change**

```bash
git add .local/bin/mr-loop tests/mr-loop-test.sh
git commit -m "fix: sync local MR descendants"
```

### Task 2: Guarded GitLab Rebase Convergence

**Files:**
- Modify: `.local/bin/mr-loop:206-218,318-340,412-475`
- Modify: `tests/mr-loop-test.sh:95-145`

**Interfaces:**
- Produces: `rebase_action <mr_json>` printing `ready|request|wait|error`.
- Produces: `request_gitlab_rebase <expected_sha> <source_branch> <project_id>`.
- Produces: `align_after_gitlab_rebase <source_branch> <old_sha> <new_sha>` for the clean checkout after the server-generated rebase.

- [ ] **Step 1: Add failing rebase-state tests**

Add pure checks near the merge-status tests:

```sh
assert_eq "request rebase when behind" request "$(rebase_action \
  '{"diverged_commits_count":2,"rebase_in_progress":false,"merge_error":null}')"
assert_eq "accept up-to-date target branch" ready "$(rebase_action \
  '{"diverged_commits_count":0,"rebase_in_progress":false,"merge_error":null}')"
assert_eq "wait for active GitLab rebase" wait "$(rebase_action \
  '{"diverged_commits_count":2,"rebase_in_progress":true,"merge_error":null}')"
assert_eq "stop on GitLab rebase error" error "$(rebase_action \
  '{"diverged_commits_count":2,"rebase_in_progress":false,"merge_error":"conflict"}')"
```

Add a stubbed API ordering test:

```sh
rebase_calls=$(mktemp "${TMPDIR:-/tmp}/mr-loop-rebase.XXXXXX")
api() {
  printf '%s\n' "$*" >>"$rebase_calls"
  case $* in
    *--method\ PUT*rebase*) printf '{"rebase_in_progress":true}\n' ;;
    *) return 1 ;;
  esac
}
fetch_mr() {
  rebase_fetches=$((rebase_fetches + 1))
  if [ "$rebase_fetches" -eq 1 ]; then
    printf '%s\n' '{"state":"opened","sha":"old","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}'
  else
    printf '%s\n' '{"state":"opened","sha":"new","source_branch":"fix-ci","source_project_id":7,"target_project_id":7,"rebase_in_progress":false,"merge_error":null}'
  fi
}
POLL_INTERVAL=0
EXPECTED_LOCAL_SHA=old
rebase_fetches=0
align_after_gitlab_rebase() { printf 'align %s %s %s\n' "$@" >>"$rebase_calls"; }
request_gitlab_rebase old fix-ci 7
assert_eq "request rebase before local alignment" \
  "--method PUT projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/rebase" \
  "$(sed -n '1p' "$rebase_calls")"
assert_eq "align checkout to server rebase" "align fix-ci old new" "$(sed -n '2p' "$rebase_calls")"
rm -f "$rebase_calls"
unset -f api fetch_mr align_after_gitlab_rebase 2>/dev/null || true
```

- [ ] **Step 2: Run tests and verify RED**

Run: `sh tests/mr-loop-test.sh`

Expected: missing `rebase_action` and `request_gitlab_rebase` failures.

- [ ] **Step 3: Include rebase state in MR reads and implement the transition**

Change `fetch_mr` to request rebase state:

```sh
  mr=$(api "projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID?include_rebase_in_progress=true&include_diverged_commits_count=true") || return 1
```

Add:

```sh
rebase_action() {
  printf '%s' "$1" | jq -r '
    if (.merge_error // null) != null then "error"
    elif (.rebase_in_progress // false) then "wait"
    elif (.diverged_commits_count // 0) > 0 then "request"
    else "ready"
    end
  '
}

align_after_gitlab_rebase() {
  source_branch=$1
  old_sha=$2
  new_sha=$3
  [ -z "$(git status --porcelain --untracked-files=normal)" ] || return 1
  [ "$(git branch --show-current)" = "$source_branch" ] || return 1
  [ "$(git rev-parse HEAD)" = "$old_sha" ] || return 1
  retry run_with_timeout "$COMMAND_TIMEOUT" git fetch origin "$source_branch" || return 1
  [ "$(git rev-parse FETCH_HEAD)" = "$new_sha" ] || return 1
  git switch --detach "$new_sha" >/dev/null || return 1
  git branch -f "$source_branch" "$new_sha" >/dev/null || return 1
  git switch "$source_branch" >/dev/null || return 1
  EXPECTED_LOCAL_SHA=$new_sha
}

request_gitlab_rebase() {
  expected_sha=$1
  source_branch=$2
  project_id=$3
  latest_mr=$(fetch_mr) || return 1
  mr_matches_expected "$latest_mr" "$expected_sha" "$source_branch" "$project_id" || return 1
  api --method PUT "projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/rebase" >/dev/null || return 1
  deadline=$(($(date +%s) + STATE_CHANGE_TIMEOUT))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    latest_mr=$(fetch_mr) || return 1
    [ "$(printf '%s' "$latest_mr" | jq -r '.merge_error // empty')" = "" ] || return 1
    if [ "$(printf '%s' "$latest_mr" | jq -r '.rebase_in_progress // false')" = false ]; then
      new_sha=$(printf '%s' "$latest_mr" | jq -r .sha)
      if [ "$new_sha" != "$expected_sha" ]; then
        align_after_gitlab_rebase "$source_branch" "$expected_sha" "$new_sha"
        return $?
      fi
    fi
    sleep "$POLL_INTERVAL"
  done
  return 1
}
```

At the start of each monitor iteration, before discussion or pipeline work:

```sh
    case $(rebase_action "$mr_json") in
      ready) ;;
      request)
        project_id=$(printf '%s' "$mr_json" | jq -r .target_project_id)
        request_gitlab_rebase "$LAST_MR_SHA" "$source_branch" "$project_id" || \
          die "GitLab rebase failed or did not converge"
        continue
        ;;
      wait)
        log "GitLab rebase is in progress; waiting ${POLL_INTERVAL}s"
        sleep "$POLL_INTERVAL"
        continue
        ;;
      error) die "GitLab rebase reported an error" ;;
    esac
```

- [ ] **Step 4: Run tests and syntax check**

Run: `sh -n .local/bin/mr-loop && sh tests/mr-loop-test.sh`

Expected: all tests pass without contacting GitLab.

- [ ] **Step 5: Commit the rebase transition**

```bash
git add .local/bin/mr-loop tests/mr-loop-test.sh
git commit -m "feat: rebase behind MR branches"
```

### Task 3: Structured Discussion Repair Agent

**Files:**
- Create: `.config/opencode/agents/mr-discussion-repair.md`
- Modify: `.local/bin/mr-loop:13-30,310-365`
- Modify: `tests/mr-loop-test.sh:6-9,150-202`

**Interfaces:**
- Produces: `run_discussion_agent <mr_json> <discussion_json>`.
- Produces validated globals: `DISCUSSION_DISPOSITION` and `DISCUSSION_REPLY`.
- Uses: `$REPO_ROOT/.mr-loop-discussion-result.json`, deleted before repository-change decisions.

- [ ] **Step 1: Add failing agent contract tests**

Define `DISCUSSION_AGENT` beside the existing test paths and add assertions:

```sh
DISCUSSION_AGENT="$ROOT/.config/opencode/agents/mr-discussion-repair.md"

if [ -f "$DISCUSSION_AGENT" ]; then
  pass "discussion repair agent exists"
else
  fail "discussion repair agent exists ($DISCUSSION_AGENT is missing)"
fi
if [ -f "$DISCUSSION_AGENT" ] && \
   grep -Eq '"?\*"?: deny' "$DISCUSSION_AGENT" && \
   grep -q 'fixed.*invalid.*obsolete.*blocked' "$DISCUSSION_AGENT" && \
   grep -q '.mr-loop-discussion-result.json' "$DISCUSSION_AGENT"; then
  pass "discussion agent is restricted and structured"
else
  fail "discussion agent is restricted and structured"
fi
```

Add parser tests using a temporary repository root:

```sh
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
rm -rf "$result_root"
REPO_ROOT=$ROOT
```

- [ ] **Step 2: Run tests and verify RED**

Run: `sh tests/mr-loop-test.sh`

Expected: missing discussion agent and `parse_discussion_result` failures.

- [ ] **Step 3: Create the restricted discussion agent**

Create `.config/opencode/agents/mr-discussion-repair.md`:

```markdown
---
description: Evaluates and repairs one unresolved GitLab MR discussion without Git or GitLab mutations.
mode: primary
color: "#B45309"
permission:
  edit: allow
  bash:
    "*": deny
    "git *": deny
    "glab *": deny
---

You evaluate exactly one unresolved GitLab merge-request discussion from the
attached context. Verify the feedback against the current checkout before
editing. Make the smallest correct change only when the feedback is valid.

Do not run shell commands, stage, commit, push, switch branches, rebase, reply,
resolve discussions, or merge. Preserve unrelated work.

Write `.mr-loop-discussion-result.json` at the repository root with exactly:

```json
{"disposition":"fixed|invalid|obsolete|blocked","reply":"technical explanation"}
```

Use `fixed` only when you changed repository files. Use `invalid` when the
feedback is technically incorrect, `obsolete` when current code already makes
it inapplicable, and `blocked` when a safe decision requires a human. The reply
must be non-empty, specific, and suitable for posting verbatim to the thread.
Do not include extra keys or create any other bookkeeping file.
```

- [ ] **Step 4: Implement result parsing and agent invocation**

Add globals and cleanup support:

```sh
DISCUSSION_CONTEXT_FILE=
DISCUSSION_RESULT_FILE=
DISCUSSION_DISPOSITION=
DISCUSSION_REPLY=
```

Add:

```sh
parse_discussion_result() {
  [ -f "$DISCUSSION_RESULT_FILE" ] || return 1
  jq -e '
    (keys | sort) == ["disposition", "reply"] and
    (.disposition | IN("fixed", "invalid", "obsolete", "blocked")) and
    (.reply | type == "string" and length > 0)
  ' "$DISCUSSION_RESULT_FILE" >/dev/null || return 1
  DISCUSSION_DISPOSITION=$(jq -r .disposition "$DISCUSSION_RESULT_FILE")
  DISCUSSION_REPLY=$(jq -r .reply "$DISCUSSION_RESULT_FILE")
}

run_discussion_agent() {
  mr_json=$1
  discussion_json=$2
  DISCUSSION_CONTEXT_FILE=$(mktemp "${TMPDIR:-/tmp}/mr-loop-discussion.XXXXXX") || return 1
  DISCUSSION_RESULT_FILE="$REPO_ROOT/.mr-loop-discussion-result.json"
  rm -f "$DISCUSSION_RESULT_FILE"
  {
    printf '# GitLab MR discussion repair context\n\n'
    printf 'MR: %s\n' "$MR_URL"
    printf 'MR SHA: %s\n' "$(printf '%s' "$mr_json" | jq -r .sha)"
    printf 'Generated repair attempt: %s of %s\n\n' "$((REPAIRS + 1))" "$MAX_REPAIRS"
    printf '## Discussion JSON\n\n```json\n%s\n```\n' "$discussion_json"
  } >"$DISCUSSION_CONTEXT_FILE" || return 1
  run_with_timeout "$AGENT_TIMEOUT" opencode run \
    "Evaluate the attached discussion, repair it if valid, and write the required result file." \
    --agent mr-discussion-repair --dir "$REPO_ROOT" --file "$DISCUSSION_CONTEXT_FILE" || return 1
  parse_discussion_result || return 1
  rm -f "$DISCUSSION_RESULT_FILE" "$DISCUSSION_CONTEXT_FILE"
  DISCUSSION_RESULT_FILE=
  DISCUSSION_CONTEXT_FILE=
}
```

Extend `cleanup` to remove both files when non-empty.

- [ ] **Step 5: Run contract tests and syntax check**

Run: `sh -n .local/bin/mr-loop && sh tests/mr-loop-test.sh`

Expected: all agent contract and existing tests pass.

- [ ] **Step 6: Commit the discussion agent contract**

```bash
git add .config/opencode/agents/mr-discussion-repair.md .local/bin/mr-loop tests/mr-loop-test.sh
git commit -m "feat: add MR discussion repair agent"
```

### Task 4: Reply-And-Resolve Discussion State

**Files:**
- Modify: `.local/bin/mr-loop:206-265,342-384,412-475`
- Modify: `tests/mr-loop-test.sh:128-177`

**Interfaces:**
- Produces: `fetch_discussions`, `next_unresolved_discussion`, and `fetch_discussion <id>`.
- Produces: `reply_and_resolve_discussion <id> <reply> <expected_sha>` with reply-before-resolve ordering.
- Produces: `process_discussion <mr_json> <discussion_json> <source_branch> <project_id>` returning to synchronization after one thread.

- [ ] **Step 1: Add failing selection and ordering tests**

Add discussion selection fixtures:

```sh
discussions='[
  {"id":"newer","notes":[{"created_at":"2026-07-16T11:00:00Z","resolvable":true,"resolved":false}]},
  {"id":"resolved","notes":[{"created_at":"2026-07-16T09:00:00Z","resolvable":true,"resolved":true}]},
  {"id":"older","notes":[{"created_at":"2026-07-16T10:00:00Z","resolvable":true,"resolved":false}]}
]'
assert_eq "select oldest unresolved discussion" "older" \
  "$(printf '%s' "$discussions" | next_unresolved_discussion | jq -r .id)"
assert_eq "no unresolved discussion yields null" "null" \
  "$(printf '%s' '[{"id":"done","notes":[{"resolvable":true,"resolved":true}]}]' | next_unresolved_discussion)"
```

Add API ordering coverage:

```sh
discussion_calls=$(mktemp "${TMPDIR:-/tmp}/mr-loop-discussion-calls.XXXXXX")
fetch_mr() {
  printf '%s\n' '{"state":"opened","sha":"abc","source_branch":"fix-ci","source_project_id":7,"target_project_id":7}'
}
fetch_discussion() {
  printf '%s\n' '{"id":"thread-1","notes":[{"resolvable":true,"resolved":false}]}'
}
api() { printf '%s\n' "$*" >>"$discussion_calls"; printf '{}\n'; }
reply_and_resolve_discussion thread-1 "Fixed in the current MR head." abc
assert_eq "reply discussion first" \
  "--method POST --field body=Fixed in the current MR head. projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/discussions/thread-1/notes" \
  "$(sed -n '1p' "$discussion_calls")"
assert_eq "resolve discussion second" \
  "--method PUT --field resolved=true projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/discussions/thread-1" \
  "$(sed -n '2p' "$discussion_calls")"
rm -f "$discussion_calls"
unset -f fetch_mr fetch_discussion api 2>/dev/null || true
```

- [ ] **Step 2: Run tests and verify RED**

Run: `sh tests/mr-loop-test.sh`

Expected: missing selection and reply/resolve function failures.

- [ ] **Step 3: Implement discussion API helpers**

Add:

```sh
fetch_discussions() {
  api --paginate "projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/discussions?per_page=100" | jq -s 'add // []'
}

fetch_discussion() {
  api "projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/discussions/$1"
}

next_unresolved_discussion() {
  jq -c '
    [.[] | select(any(.notes[]; .resolvable == true and .resolved == false))]
    | sort_by([.notes[] | select(.resolvable == true and .resolved == false) | .created_at] | min)
    | first // null
  '
}

discussion_is_unresolved() {
  expected_id=$1
  jq -e --arg id "$expected_id" '
    .id == $id and any(.notes[]; .resolvable == true and .resolved == false)
  ' >/dev/null
}

reply_and_resolve_discussion() {
  discussion_id=$1
  reply=$2
  expected_sha=$3
  latest_mr=$(fetch_mr) || return 1
  [ "$(printf '%s' "$latest_mr" | jq -r .sha)" = "$expected_sha" ] || return 1
  latest_discussion=$(fetch_discussion "$discussion_id") || return 1
  printf '%s' "$latest_discussion" | discussion_is_unresolved "$discussion_id" || return 1
  api --method POST --field "body=$reply" \
    "projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/discussions/$discussion_id/notes" >/dev/null || return 1
  api --method PUT --field resolved=true \
    "projects/$MR_PROJECT_ENCODED/merge_requests/$MR_IID/discussions/$discussion_id" >/dev/null
}
```

- [ ] **Step 4: Implement disposition processing with the shared budget**

Add a generalized commit/push helper and discussion processor:

```sh
commit_generated_repair() {
  source_branch=$1
  expected_sha=$2
  project_id=$3
  message=$4
  repair_allowed "$REPAIRS" "$MAX_REPAIRS" || return 1
  [ -n "$(git status --porcelain --untracked-files=normal)" ] || return 1
  latest_mr=$(fetch_mr) || return 1
  mr_matches_expected "$latest_mr" "$expected_sha" "$source_branch" "$project_id" || return 1
  git add --all || return 1
  git commit -m "$message" || return 1
  new_sha=$(git rev-parse HEAD)
  latest_mr=$(fetch_mr) || return 1
  mr_matches_expected "$latest_mr" "$expected_sha" "$source_branch" "$project_id" || return 1
  run_with_timeout "$COMMAND_TIMEOUT" git push origin "HEAD:$source_branch" || return 1
  wait_for_mr_sha "$new_sha" || return 1
  REPAIRS=$((REPAIRS + 1))
  LAST_MR_SHA=$new_sha
  EXPECTED_LOCAL_SHA=$new_sha
}

process_discussion() {
  mr_json=$1
  discussion_json=$2
  source_branch=$3
  project_id=$4
  expected_sha=$(printf '%s' "$mr_json" | jq -r .sha)
  discussion_id=$(printf '%s' "$discussion_json" | jq -r .id)
  run_discussion_agent "$mr_json" "$discussion_json" || return 1
  case $DISCUSSION_DISPOSITION in
    fixed)
      commit_generated_repair "$source_branch" "$expected_sha" "$project_id" \
        "fix(review): resolve MR feedback" || return 1
      reply_and_resolve_discussion "$discussion_id" "$DISCUSSION_REPLY" "$LAST_MR_SHA"
      ;;
    invalid|obsolete)
      [ -z "$(git status --porcelain --untracked-files=normal)" ] || return 1
      reply_and_resolve_discussion "$discussion_id" "$DISCUSSION_REPLY" "$expected_sha"
      ;;
    blocked) return 2 ;;
    *) return 1 ;;
  esac
}
```

Refactor existing pipeline `commit_and_push` to call `commit_generated_repair` with `fix(ci): repair failed pipeline`, so both paths increment the same `REPAIRS` counter exactly once.

- [ ] **Step 5: Insert discussion processing before pipeline observation**

In `monitor`, after synchronization/rebase and before `fetch_pipelines`:

```sh
    discussions=$(fetch_discussions) || die "Unable to fetch MR discussions"
    discussion=$(printf '%s' "$discussions" | next_unresolved_discussion)
    if [ "$discussion" != null ]; then
      project_id=$(printf '%s' "$mr_json" | jq -r .target_project_id)
      process_discussion "$mr_json" "$discussion" "$source_branch" "$project_id"
      discussion_status=$?
      [ "$discussion_status" -eq 0 ] || {
        [ "$discussion_status" -eq 2 ] && die "Discussion repair requires human intervention"
        die "Unable to repair and resolve discussion"
      }
      continue
    fi
```

- [ ] **Step 6: Run all stubbed tests and syntax checks**

Run: `sh -n .local/bin/mr-loop && sh tests/mr-loop-test.sh`

Expected: all tests pass; no GitLab MR or pipeline is contacted.

- [ ] **Step 7: Commit discussion processing**

```bash
git add .local/bin/mr-loop tests/mr-loop-test.sh
git commit -m "feat: repair and resolve MR discussions"
```

### Task 5: Final Health Gates, Documentation, And Regression Verification

**Files:**
- Modify: `.local/bin/mr-loop:386-475`
- Modify: `.config/opencode/commands/mr-loop.md:1-12`
- Modify: `tests/mr-loop-test.sh:178-205`
- Modify: `docs/superpowers/specs/2026-07-16-gitlab-mr-repair-loop-design.md:1-275` only if implementation details require a factual correction

**Interfaces:**
- Changes: success requires a fresh empty unresolved-discussion set plus exact-SHA successful pipeline and existing merge checks.
- Preserves: `/mr-loop <MR URL> [--on-success notify|merge]`.

- [ ] **Step 1: Add failing final-gate tests**

Add a helper expectation near `mr_is_mergeable` tests:

```sh
assert_status "accept healthy MR with no discussions" 0 mr_is_healthy \
  "$mergeable" "abc" '[]' success
assert_status "reject healthy status with unresolved discussion" 1 mr_is_healthy \
  "$mergeable" "abc" '[{"id":"thread","notes":[{"resolvable":true,"resolved":false}]}]' success
assert_status "reject healthy status with failed exact-SHA pipeline" 1 mr_is_healthy \
  "$mergeable" "abc" '[]' failed
```

Update command-file assertions to require the expanded description:

```sh
if [ -f "$COMMAND" ] && grep -q 'synchronize, repair discussions' "$COMMAND"; then
  pass "slash command describes expanded supervisor"
else
  fail "slash command describes expanded supervisor"
fi
```

- [ ] **Step 2: Run tests and verify RED**

Run: `sh tests/mr-loop-test.sh`

Expected: missing `mr_is_healthy` and command-description failures.

- [ ] **Step 3: Implement the aggregate success predicate**

Add:

```sh
mr_is_healthy() {
  mr_json=$1
  expected_sha=$2
  discussions_json=$3
  pipeline_status=$4
  [ "$pipeline_status" = success ] || return 1
  mr_is_mergeable "$mr_json" "$expected_sha" || return 1
  [ "$(printf '%s' "$discussions_json" | next_unresolved_discussion)" = null ]
}
```

In the successful-pipeline branch, fetch discussions again and replace the mergeability-only condition:

```sh
        latest_discussions=$(fetch_discussions) || die "Unable to refresh discussions before success"
        if mr_is_healthy "$mr_json" "$LAST_MR_SHA" "$latest_discussions" "$LAST_PIPELINE_STATUS"; then
```

In `merge_mr`, fetch discussions immediately before merge and require `mr_is_healthy` with the refreshed exact-SHA pipeline status before invoking `glab mr merge`.

- [ ] **Step 4: Update the slash-command description without changing execution behavior**

Change only the frontmatter description and explanatory sentence:

```markdown
description: Synchronize, repair discussions and pipelines, then finish a GitLab merge request.
```

```markdown
Run the deterministic GitLab MR supervisor below to synchronize the source
branch, repair and resolve discussions, repair CI, and relay its output.
```

Keep the prohibition on extra GitLab/Git operations and the exact command invocation unchanged.

- [ ] **Step 5: Run fresh full verification without running the supervisor**

Run:

```bash
sh -n .local/bin/mr-loop
sh tests/mr-loop-test.sh
git diff --check
```

Expected: syntax exits zero, every TAP assertion is `ok`, final TAP plan matches the assertion count, and `git diff --check` has no output.

- [ ] **Step 6: Verify installation path content without executing it**

Run:

```bash
cmp .local/bin/mr-loop "$HOME/.local/bin/mr-loop"
```

Expected: exit zero. If the dotfile deployment uses a symlink, this confirms it already points at the modified script; otherwise install through the repository's existing dotfile deployment mechanism, then repeat `cmp`. Do not invoke `mr-loop`.

- [ ] **Step 7: Commit the final health gates and command text**

```bash
git add .local/bin/mr-loop .config/opencode/commands/mr-loop.md tests/mr-loop-test.sh docs/superpowers/specs/2026-07-16-gitlab-mr-repair-loop-design.md
git commit -m "feat: complete GitLab MR repair loop"
```

- [ ] **Step 8: Restart OpenCode before manually invoking `/mr-loop` later**

Quit and restart OpenCode so the new command and discussion agent definitions are loaded. Do not run the live MR loop as part of this implementation session.

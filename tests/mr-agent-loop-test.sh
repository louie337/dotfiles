#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AGENT="$ROOT/.config/opencode/agents/mr-agent-loop.md"
COMMAND="$ROOT/.config/opencode/commands/mr-agent-loop.md"
CONFIG="$ROOT/.config/opencode/opencode.json"
DOC="$ROOT/docs/mr-agent-loop.md"
SCENARIOS="$ROOT/tests/fixtures/mr-agent-loop-conflict-scenarios.json"
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
assert_file "active MR loop documentation exists" "$DOC"
assert_file "merge fallback scenario fixture exists" "$SCENARIOS"

assert_contains "command selects active agent" "$COMMAND" "agent: mr-agent-loop"
assert_contains "command prohibits history rewriting" "$COMMAND" "Never locally rebase, reset, clean, stash, amend, rewrite history, force-push"
assert_contains "command requires Linear lookup" "$COMMAND" "through Linear MCP"
assert_contains "command separates intent from tooling" "$COMMAND" "Treat deterministic conflict intent separately from tool availability"
assert_contains "command batches repairs before one push" "$COMMAND" "Batch all actionable discussion and failed-pipeline repairs locally before one"
assert_contains "command blocks push during active CI" "$COMMAND" "require that every relevant pipeline is"
assert_contains "agent safety overrides generic skill examples" "$AGENT" "override generic skill"

assert_order "state machine precedes snapshot" "$AGENT" "## Synchronization-First State Machine" "## Loop Snapshot"
assert_order "safe synchronization precedes repair" "$AGENT" "## Safe Synchronization" "## MR Review And Discussion Repair"
assert_order "repair precedes CI evaluation" "$AGENT" "## MR Review And Discussion Repair" "## Pipeline Repair"

# Scenario 1: an already synchronized source proceeds through the explicit gate.
assert_contains "scenario 1 checks target ancestry" "$AGENT" 'git merge-base --is-ancestor <fetched-target-sha> <mr-sha>'
assert_contains "scenario 1 defines the open gate" "$AGENT" "The synchronization gate is open only when"

# Scenario 2: a conflict-free behind source uses GitLab rebase before repair and
# never enters the local merge fallback when that rebase succeeds.
assert_contains "scenario 2 requests server-side rebase" "$AGENT" 'glab mr rebase <iid> --repo <project>'
assert_contains "scenario 2 restarts after new SHA" "$AGENT" 'restart at `startup`'
assert_contains "scenario 2 successful rebase skips fallback" "$AGENT" "without starting a local merge fallback"

# Scenario 3: GitLab's conflict response enters guarded normal target
# integration and completes with a normal push before blocking.
assert_contains "scenario 3 has blocked-conflicts state" "$AGENT" '`blocked_conflicts`'
assert_contains "scenario 3 prohibits unrelated pre-rebase repair" "$AGENT" "Do not implement or push unrelated"
assert_contains "scenario 3 matches conflict-required response" "$AGENT" 'resolve all conflicts, then push the branch.'
assert_contains "scenario 3 enters fallback state" "$AGENT" '`safe_merge_conflict_resolution`'
assert_contains "scenario 3 merges exact target SHA" "$AGENT" 'git merge --no-ff --no-commit <exact-target-sha>'
assert_contains "scenario 3 normally pushes detached HEAD" "$AGENT" 'git push origin HEAD:<source-branch>'
assert_contains "scenario 3 waits for pushed SHA" "$AGENT" 'until both report that exact SHA'

# Scenario 4: stale or occupied local target is not the rebase base.
assert_contains "scenario 4 preserves occupied local target" "$AGENT" "not checked out in any worktree"
assert_contains "scenario 4 uses exact target project SHA" "$AGENT" "freshly fetched target-project SHA"
assert_contains "scenario 4 permits guarded worktree pull" "$AGENT" 'git pull --ff-only'

# Scenario 5: concurrent source changes abort stale mutations.
assert_contains "scenario 5 defines remote-changed state" "$AGENT" '`blocked_remote_changed`'
assert_contains "scenario 5 rechecks source SHA" "$AGENT" "MR and fetched
   source still equal the original expected source SHA"
assert_contains "scenario 5 refreshes target before mutation" "$AGENT" "The gate expires before every repair edit"

# Scenario 6: stale pipelines are ignored after SHA changes.
assert_contains "scenario 6 ignores pre-rebase pipelines" "$AGENT" "Ignore every pre-rebase or pre-fix pipeline"
assert_contains "scenario 6 requires exact-SHA jobs" "$AGENT" "Every pipeline for the exact current MR head SHA"

# Scenario 7: pre-sync findings are provisional and revalidated.
assert_contains "scenario 7 marks findings provisional" "$AGENT" "record findings as provisional"
assert_contains "scenario 7 revalidates rebased findings" "$AGENT" "collected earlier are provisional"

# Scenario 8: conflict integration is isolated, bounded, and normally pushed.
assert_contains "scenario 8 creates isolated worktree" "$AGENT" 'git worktree add
   --detach /tmp/mr-agent-loop-worktree-<conflict-attempt-id>'
assert_contains "scenario 8 permits bounded conflicts" "$AGENT" "repository evidence establishes one intended"
assert_contains "scenario 8 pushes normally" "$AGENT" "Push normally and only to the verified source branch"
assert_contains "scenario 8 permits only owned abort" "$AGENT" "Before a merge commit exists, abort an isolated attempt only when"

# Scenario 9: domain conflicts use explicit ticket scope, then fetched target behavior.
assert_contains "scenario 9 detects Linear issue key" "$AGENT" '`SUB-[0-9]+`'
assert_contains "scenario 9 requires exact Linear lookup" "$AGENT" "fetch that exact issue"
assert_contains "scenario 9 gives explicit ticket priority" "$AGENT" "explicit ticket requirement"
assert_contains "scenario 9 defaults to target behavior" "$AGENT" "ticket requirement means target behavior wins"
assert_contains "scenario 9 uses fetched target evidence" "$AGENT" "exact recorded SHA fetched from the target project"
assert_contains "scenario 9 verifies authorization boundaries" "$AGENT" "including authorization boundaries"

# Scenario A: a denied convenience command falls back to allowed file editing.
assert_contains "scenario A denied checkout is not ambiguity" "$AGENT" 'If `git checkout --ours`'
assert_contains "scenario A inspects index stages" "$AGENT" 'git show :1:<path>'
assert_contains "scenario A inspects exact blobs" "$AGENT" "source/target blobs using the recorded exact"
assert_contains "scenario A uses repository edit tools" "$AGENT" "Use repository read and edit tools"
assert_contains "scenario A resolves markers directly" "$AGENT" "resolve conflict markers manually"
assert_contains "scenario A avoids mechanism approval" "$AGENT" "Do not ask the user to approve a low-level resolution mechanism"
assert_contains "scenario A continues through commit and push" "$AGENT" "create the conventional integration commit"

# Scenario B: abort diagnostics distinguish an isolated clean tree from source/
# target compatibility.
assert_contains "scenario B preserves machine-readable log" "$AGENT" "preserve the machine-readable decision log"
assert_contains "scenario B records conflict SHAs" "$AGENT" "exact source/target SHAs"
assert_contains "scenario B explains isolated abort" "$AGENT" "isolated worktree is clean because this"
assert_contains "scenario B does not claim compatibility" "$AGENT" "not because source and target are conflict-free"
assert_contains "scenario B gives reproduction command" "$AGENT" 'git merge --no-ff --no-commit <exact-target-sha>'

# Scenario C: deterministic conflict with no write mechanism needs environment help.
assert_contains "scenario C exhausts safe mechanisms" "$AGENT" "Try every applicable safe mechanism"
assert_contains "scenario C reports attempted mechanisms" "$AGENT" "every mechanism attempted"
assert_contains "scenario C uses manual action state" "$AGENT" 'return
`manual_action_required`, not `blocked_conflicts`'

# Scenario D: genuine intent ambiguity remains a conflict blocker.
assert_contains "scenario D reserves blocked conflicts for intent" "$AGENT" "deterministic conflict intent cannot be established"
assert_contains "scenario D lists product ambiguity" "$AGENT" "unresolved product judgment"
assert_contains "scenario D excludes denied commands" "$AGENT" "Never use this state solely because a command"

# Merge fallback scenario 1: clear content conflicts preserve combined behavior.
assert_contains "fallback content conflict requires clear evidence" "$AGENT" "Content conflicts
   with a clear contract"
assert_contains "fallback preserves both parents' behavior" "$AGENT" "Preserve non-overlapping behavior from both parents"
assert_contains "fallback preserves MR feature" "$AGENT" "preserve the MR's intended feature"

# Merge fallback scenario 2: compatible add/add definitions are combined.
assert_contains "fallback permits compatible add-add" "$AGENT" "add/add conflicts containing compatible definitions"
assert_contains "fallback deduplicates compatible definitions" "$AGENT" "deduplicate and combine them without dropping"

# Merge fallback scenario 3: generated conflicts resolve from sources.
assert_contains "fallback detects SQLC and protobuf output" "$AGENT" "including SQLC and"
assert_contains "fallback resolves generated sources first" "$AGENT" "Identify and resolve the source schema, query, proto"
assert_contains "fallback runs canonical generator" "$AGENT" "Run the repository's canonical generator"
assert_contains "fallback forbids unsupported generated hand edits" "$AGENT" "Do not hand-edit generated output unless"
assert_contains "fallback rejects unrelated generated drift" "$AGENT" "verify no unrelated generated drift"

# Merge fallback scenario 4: target changes before commit abort and restart, with
# no stale push.
assert_contains "fallback refreshes target branch endpoint" "$AGENT" "query the current target SHA"
assert_contains "fallback target change aborts owned attempt" "$AGENT" "If the target changed, safely abort and remove"
assert_contains "fallback target change restarts startup" "$AGENT" 'restart from `startup`'

# Merge fallback scenario 5: source changes stop or restart safely without push.
assert_contains "fallback source change prevents push" "$AGENT" "identity changed, do not push"
assert_contains "fallback source change requires owned cleanup" "$AGENT" "safely abort only when cleanup ownership is proven"
assert_contains "fallback source change classifies remote change" "$AGENT" 'report `blocked_remote_changed`'

# Merge fallback scenario 6: a dirty initial worktree stops without cleanup.
assert_contains "fallback requires clean initial index" "$AGENT" "Require the current index and working tree to be clean"
assert_contains "fallback dirty initial tree is blocker" "$AGENT" "A dirty initial worktree is a"
assert_contains "fallback never cleans user work" "$AGENT" "never stash, clean, reset, or absorb it"

# Merge fallback scenario 7: unrelated changes during resolution stop.
assert_contains "fallback limits repair paths to Git conflicts" "$AGENT" "Only paths Git reports as unmerged are conflict-repair paths"
assert_contains "fallback detects unrelated changes" "$AGENT" "treat it as an unrelated or concurrent change"
assert_contains "fallback does not stage unrelated changes" "$AGENT" "do not stage or commit it"

# Merge fallback scenario 8: ambiguous product conflicts stop pre-commit/push.
assert_contains "fallback stops on product ambiguity" "$AGENT" "Stop without commit or push for
   product ambiguity"
assert_contains "fallback stops on policy migrations" "$AGENT" "migrations needing rollout or data-policy decisions"
assert_contains "fallback stops on reviewer ambiguity" "$AGENT" "reviewer-intent ambiguity"

# Merge fallback scenario 9: focused verification failure prevents commit/push.
assert_contains "fallback runs focused verification" "$AGENT" "Run path-specific rule dispatch and focused verification"
assert_contains "fallback failed verification stops push" "$AGENT" "failed
   focused verification stops the attempt without commit or push"
assert_contains "fallback does not weaken tests" "$AGENT" "Never weaken, skip, or delete tests"

# Merge fallback scenario 10: failed normal push preserves the merge commit.
assert_contains "fallback preserves merge before push" "$AGENT" 'refs/mr-agent-loop/conflicts/<conflict-attempt-id>'
assert_contains "fallback failed push retains commit" "$AGENT" "On any failed or non-fast-forward push"
assert_contains "fallback failed push never rewrites" "$AGENT" "never retry by rewriting history"

# Merge fallback scenario 11: fork MRs require unambiguous push permission.
assert_contains "fallback checks fork topology" "$AGENT" "prove unambiguous fork topology and push"
assert_contains "fallback ambiguous fork stops" "$AGENT" 'stop with
   `blocked_permissions` before a merge attempt'

# Merge fallback scenario 12: unresolved entries and markers cannot be committed.
assert_contains "fallback checks unresolved index" "$AGENT" 'require `git ls-files -u` to be empty'
assert_contains "fallback checks conflict markers" "$AGENT" "no conflict
   markers"
assert_contains "fallback requires two merge parents" "$AGENT" "exactly two parents in order"

# Merge fallback scenario 13: isolation leaves worktrees and branch pointers intact.
assert_contains "fallback records worktree inventory" "$AGENT" "Record the pre-attempt worktree inventory"
assert_contains "fallback keeps source pointer unchanged" "$AGENT" "source branch pointer need not and must not change"
assert_contains "fallback never cleans another worktree" "$AGENT" "Never clean up another worktree"

# Merge fallback scenario 14: interruption recovery resumes all three phases.
assert_contains "fallback persists unresolved phase" "$AGENT" '`unresolved_merge` or `resolved_uncommitted`'
assert_contains "fallback resumes unresolved merge safely" "$AGENT" "resume only if the worktree is"
assert_contains "fallback persists committed phase" "$AGENT" '`committed_unpushed`'
assert_contains "fallback resumes committed push" "$AGENT" "Re-run all
  pre-push guards"
assert_contains "fallback persists convergence phase" "$AGENT" '`pushed_awaiting_gitlab`'
assert_contains "fallback resumes GitLab convergence" "$AGENT" "do not recreate, amend, or push the commit again"

# Policy guardrails remain enforceable at the agent permission layer.
assert_contains "permissions deny local rebase" "$AGENT" '"git rebase *": deny'
assert_contains "permissions deny reset" "$AGENT" '"git reset *": deny'
assert_contains "permissions deny clean" "$AGENT" '"git clean *": deny'
assert_contains "permissions deny stash" "$AGENT" '"git stash *": deny'
assert_contains "permissions deny amend" "$AGENT" '"git commit --amend*": deny'
assert_contains "permissions deny force push" "$AGENT" '"git push *--force*": deny'
assert_contains "permissions allow exact merge form" "$AGENT" '"git merge --no-ff --no-commit *": allow'
assert_contains "permissions allow detached loop worktree" "$AGENT" '"git worktree add --detach /tmp/mr-agent-loop-* *": allow'
assert_contains "permissions prohibit force worktree cleanup" "$AGENT" '"git worktree remove *": deny'
assert_contains "permissions deny explicit force worktree cleanup" "$AGENT" '"git worktree remove *--force*": deny'
assert_contains "permissions deny forced refspec push" "$AGENT" '"git push * +*": deny'

# Documentation identifies active sources and the testing contract.
assert_contains "docs identify authoritative agent" "$DOC" '.config/opencode/agents/mr-agent-loop.md'
assert_contains "docs distinguish historical supervisor" "$DOC" 'removed `.local/bin/mr-loop` shell'
assert_contains "docs record merge-only fallback" "$DOC" 'git merge --no-ff --no-commit'
assert_contains "docs record policy test" "$DOC" 'sh tests/mr-agent-loop-test.sh'

if jq -e '
  length == 16 and
  ([.[].scenario] | unique | length) == 16 and
  (map(select(.scenario == "gitlab_rebase_succeeds" and .localMerge == false)) | length) == 1 and
  (map(select(.scenario == "gitlab_rebase_conflicts" and .localMerge == true and .pushMode == "normal")) | length) == 1 and
  (map(select(.scenario == "clear_content_conflict" and .resolution == "combine_evidenced_behavior")) | length) == 1 and
  (map(select(.scenario == "compatible_add_add_conflict" and .resolution == "deduplicate_compatible_definitions")) | length) == 1 and
  (map(select(.scenario == "generated_file_conflict" and .resolution == "resolve_sources_then_regenerate")) | length) == 1 and
  (map(select(.scenario == "target_changes_before_commit" and .push == false)) | length) == 1 and
  (map(select(.scenario == "source_changes_before_commit" and .push == false)) | length) == 1 and
  (map(select(.scenario == "dirty_initial_worktree" and .commit == false and .push == false)) | length) == 1 and
  (map(select(.scenario == "unrelated_change_appears" and .commit == false and .push == false)) | length) == 1 and
  (map(select(.scenario == "ambiguous_product_conflict" and .commit == false and .push == false)) | length) == 1 and
  (map(select(.scenario == "focused_verification_fails" and .commit == false and .push == false)) | length) == 1 and
  (map(select(.scenario == "normal_push_fails" and .preserveMergeRef == true and .historyRewrite == false)) | length) == 1 and
  (map(select(.scenario == "fork_permission_ambiguous" and .localMerge == false and .push == false)) | length) == 1 and
  (map(select(.scenario == "unresolved_index_or_markers" and .commit == false and .push == false)) | length) == 1 and
  (map(select(.scenario == "isolated_worktree_preserves_local_state" and .existingWorktreesChanged == false and .branchPointersChanged == false)) | length) == 1 and
  (map(select(.scenario == "interruption_recovery" and .resumePhases == ["unresolved_merge", "committed_unpushed", "pushed_awaiting_gitlab"])) | length) == 1
' "$SCENARIOS" >/dev/null; then
  pass "all 16 merge fallback state scenarios are specified"
else
  fail "all 16 merge fallback state scenarios are specified"
fi

if jq -e '.mcp.linear.type == "remote" and .mcp.linear.url == "https://mcp.linear.app/mcp" and .mcp.linear.enabled == true' "$CONFIG" >/dev/null; then
  pass "Linear MCP is globally enabled"
else
  fail "Linear MCP is globally enabled"
fi

assert_contains "invariant forbids disposable repair pipeline" "$AGENT" "No repair commit should be pushed merely to trigger verification"
assert_contains "ahead local commit is not pushed before sync" "$AGENT" "If local is ahead of the MR source SHA during"
assert_contains "interrupted repair is reapplied after sync" "$AGENT" "never push a pre-synchronization ordinary repair"
assert_contains "terminal awaiting pipeline is defined" "$AGENT" '`awaiting_pipeline`'
assert_contains "awaiting pipeline remains non-success" "$AGENT" "observational non-success state"
assert_contains "continuation invariant prohibits checkpoint stop" "$AGENT" "completed push, SHA convergence"
assert_contains "push convergence restarts startup" "$AGENT" 'bind one canonical pipeline and `startup`'
assert_contains "discussion reply transitions to resolution" "$AGENT" "discussion reply -> discussion resolution"
assert_contains "transient pipeline polls" "$AGENT" 'deadline-driven `recursive_pipeline_poll`'
assert_contains "repairs accumulate locally" "$AGENT" "actionable discussion and pipeline repair locally"
assert_contains "discussions do not push individually" "$AGENT" "Do not commit or push after each discussion"
assert_contains "discussion refresh extends repair batch" "$AGENT" "Add newly arrived actionable feedback to the same local batch"
assert_contains "pipeline serialization gate exists" "$AGENT" "## Pipeline Serialization Gate"
assert_contains "active pipeline blocks push and retry" "$AGENT" "If any relevant pipeline is active, do not push"
assert_contains "active pipelines poll every 30 seconds" "$AGENT" "only a graph with no terminal required failure may sleep 30 seconds"
assert_contains "one mutation follows open gate" "$AGENT" "exactly one mutation and do not perform another"
assert_contains "canonical pipeline is bound to pushed SHA" "$AGENT" 'Maintain `verification_sha` and `canonical_pipeline_id`'
assert_contains "canonical pipeline ID remains stable" "$AGENT" "Poll that same pipeline ID"
assert_contains "agent cannot explicitly create verification CI" "$AGENT" "Never explicitly create a pipeline merely for verification"
assert_contains "retry requires terminal canonical pipeline" "$AGENT" "only after the canonical pipeline is terminal"
assert_contains "duplicate GitLab pipelines do not cause another push" "$AGENT" "Do not attempt to solve"
assert_contains "recursive pipeline graph poll exists" "$AGENT" "### Recursive Pipeline Graph Poll"
assert_contains "poll fetches bridges endpoint" "$AGENT" 'pipelines/<pipeline-id>/bridges?per_page=100'
assert_contains "poll traverses downstream project and pipeline" "$AGENT" 'each unseen `(project_id, pipeline_id)` pair'
assert_contains "poll includes every descendant depth" "$AGENT" "Include every descendant depth"
assert_contains "poll checks jobs before aggregate status" "$AGENT" "Before inspecting any aggregate pipeline status"
assert_contains "poll observes every failed job" "$AGENT" "search every current job and"
assert_contains "poll reports every failed job" "$AGENT" "report each one"
assert_contains "child failure interrupts parent wait" "$AGENT" "Do not wait for the parent pipeline to become"
assert_contains "failed job starts immediate repair" "$AGENT" "begin the local repair"
assert_contains "parent running cannot hide child failure" "$AGENT" 'A parent pipeline remaining `running`'
assert_contains "poll is one discrete step" "$AGENT" "Run one discrete poll step at a time"
assert_contains "shell polling loops are forbidden" "$AGENT" 'Never delegate waiting to a shell `while`'
assert_contains "poll uses standalone sleep" "$AGENT" 'one standalone foreground `sleep 30`'
assert_contains "poll refreshes graph after sleep" "$AGENT" "fetch a completely fresh graph"
assert_contains "bash denies while pipeline poll" "$AGENT" '"*while*glab api*pipelines/*": deny'
assert_contains "bash denies until pipeline poll" "$AGENT" '"*until*glab api*pipelines/*": deny'
assert_contains "bash denies API then sleep loop" "$AGENT" '"*glab api*pipelines/*sleep 30*": deny'
assert_contains "bash denies sleep then API loop" "$AGENT" '"*sleep 30*glab api*pipelines/*": deny'
assert_contains "command requires recursive child polling" "$COMMAND" "bridges, downstream pipelines, and descendant jobs"
assert_contains "command makes child failure preempt wait" "$COMMAND" "interrupts waiting immediately"
assert_contains "command forbids hidden shell polling" "$COMMAND" "never hide polling in a shell loop"

# Deadline scenario 1: a running child that fails is observed by T+30.
assert_contains "deadline records last recursive poll" "$AGENT" '`last_recursive_pipeline_poll_at`'
assert_contains "deadline is at most 30 seconds" "$AGENT" "no later than 30 seconds afterward"
assert_contains "deadline checks after every bounded action" "$AGENT" "After every tool batch, subagent launch, subagent result"
assert_contains "deadline poll runs before other actions" "$AGENT" "before doing anything else"
assert_contains "failed node preempts auxiliary work" "$AGENT" "immediately preempt all auxiliary work"
assert_contains "failed node fetches exact trace" "$AGENT" "exact failed node record and trace immediately"

# Deadline scenario 2: optional subagents never delay a due poll.
assert_contains "optional subagent cannot outlast deadline" "$AGENT" "Do not launch an optional subagent or broad investigation"
assert_contains "active CI never waits for optional subagent" "$AGENT" "Never wait for an optional subagent while required CI"
assert_contains "subagent result is not consumed before poll" "$AGENT" "without waiting for or consuming its result first"

# Deadline scenario 3: a running parent cannot mask a failed child.
assert_contains "running parent cannot justify auxiliary review" "$AGENT" "can never justify another sleep or auxiliary review"

# Deadline scenario 4: local repair is bounded and cannot push while CI runs.
assert_contains "local repair continues only in bounded steps" "$AGENT" "Local repair may continue between deadlines only as bounded steps"
assert_contains "long tool call is deferred" "$AGENT" "A tool call expected to exceed the remaining interval"
assert_contains "active repair preserves poll next state" "$AGENT" "preserve the deadline-driven recursive"

# Deadline scenario 5: terminal graph clears the deadline.
assert_contains "terminal graph clears deadline" "$AGENT" 'Clear `next_pipeline_poll_deadline` only'
assert_contains "normal flow resumes after terminal graph" "$AGENT" "then resume normal"

# Deadline scenario 6: bridge-only discovery applies recursively at every depth.
assert_contains "unexposed descendants count as active" "$AGENT" "not yet terminal or fully exposed"
assert_contains "each deadline fetches fresh parent graph" "$AGENT" "cached parent, job, or bridge data cannot"
assert_contains "each deadline fetches fresh descendants" "$AGENT" "no cached descendant node may satisfy it"

assert_contains "missed deadline is recorded" "$AGENT" "record the expected deadline and actual resume time"
assert_contains "missed deadline polls before optional work" "$AGENT" "Do not continue or"
assert_contains "parallelism cannot delay active poll" "$AGENT" "Useful parallelism never includes work that can obscure"
assert_contains "command exposes hard poll deadline" "$COMMAND" "hard poll deadline no more than 30"
assert_contains "watchdog controls returns" "$AGENT" '`external_return_required` is set by the'
assert_contains "checkpoints require forced suspension" "$AGENT" "voluntarily, and never treat one as a terminal result"
assert_contains "awaiting pipeline requires imposed suspension" "$AGENT" "permitted only when the"
assert_contains "final guard performs executable next state" "$AGENT" "perform it instead of describing it"
assert_contains "next response proves invalid stop" "$AGENT" 'contains `Next:`'
assert_contains "pipeline verification is preferred" "$AGENT" "Prefer exact-SHA GitLab CI for substantive verification"
assert_contains "local suites prohibited by default" "$AGENT" "do not run test"
assert_contains "unknown local cost defers to CI" "$AGENT" "other command's cost is unknown, do not run it locally"
assert_contains "cheap file checks remain allowed" "$AGENT" "file-scoped syntax, parse, or format"
assert_contains "complete repair is normally pushed" "$AGENT" "complete repair is ready, commit"
assert_contains "exact SHA CI is authoritative" "$AGENT" "pipeline as authoritative verification"
assert_contains "disposable CI commits remain prohibited" "$AGENT" "disposable, incomplete, or"
assert_contains "terminal failed job is defined" "$AGENT" '`failed_required_job`'
assert_contains "already merged result is consistent" "$AGENT" 'return `merged` for either requested'
assert_contains "final report includes fetched target" "$AGENT" "latest fetched target SHA"

printf '1..%s\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]

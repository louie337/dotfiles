#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AGENT="$ROOT/.config/opencode/agents/mr-loop.md"
COMMAND="$ROOT/.config/opencode/commands/mr-loop.md"
CONFIG="$ROOT/.config/opencode/opencode.json"
DOC="$ROOT/docs/mr-loop.md"
SCENARIOS="$ROOT/tests/fixtures/mr-loop-conflict-scenarios.json"
SKILL_DIR="$ROOT/.config/opencode/skills"
AGENT_DIR="$ROOT/.config/opencode/agents"
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

assert_not_contains() {
  description=$1
  path=$2
  text=$3
  if grep -Fq -- "$text" "$path"; then
    fail "$description"
  else
    pass "$description"
  fi
}

assert_tree_not_contains() {
  description=$1
  pattern=$2
  if grep -R -F -q -- "$pattern" "$ROOT/.config/opencode/agents" "$ROOT/.config/opencode/skills"; then
    fail "$description"
  else
    pass "$description"
  fi
}

assert_skill() {
  name=$1
  path="$SKILL_DIR/$name/SKILL.md"
  assert_file "skill $name exists" "$path"
  assert_contains "skill $name has matching name" "$path" "name: $name"
  assert_contains "agent allows skill $name" "$AGENT" "$name: allow"
  assert_contains "docs list skill $name" "$DOC" "\`$name\`"
}

assert_worker() {
  name=$1
  path="$AGENT_DIR/$name.md"
  assert_file "worker $name exists" "$path"
  assert_contains "worker $name is hidden" "$path" "hidden: true"
  assert_contains "worker $name is subagent" "$path" "mode: subagent"
  assert_contains "worker $name uses terra low model" "$path" "model: datax_openai/gpt-5.6-terra"
  assert_contains "worker $name uses low variant" "$path" "variant: low"
  assert_contains "worker $name denies edits" "$path" "edit: deny"
  assert_contains "worker $name denies default bash" "$path" '"*": deny'
  assert_contains "worker $name is execution-only" "$path" "Execution-only contract"
  assert_contains "worker $name requests primary reassignment" "$path" "needs_primary_reassignment"
  assert_contains "agent may invoke worker $name" "$AGENT" "$name: allow"
  assert_contains "docs list worker $name" "$DOC" "\`$name\`"
}

assert_terra_low_agent() {
  name=$1
  path="$AGENT_DIR/$name.md"
  assert_file "agent $name exists" "$path"
  assert_contains "agent $name uses terra model" "$path" "model: datax_openai/gpt-5.6-terra"
  assert_contains "agent $name uses low variant" "$path" "variant: low"
}

assert_file "active MR agent exists" "$AGENT"
assert_file "active MR command exists" "$COMMAND"
assert_file "global OpenCode config exists" "$CONFIG"
assert_file "active MR loop documentation exists" "$DOC"
assert_file "merge fallback scenario fixture exists" "$SCENARIOS"
assert_tree_not_contains "workers do not report blocked input" "blocked_input"

for agent in \
  docker-developer \
  golang-developer \
  react-native-expo-developer \
  typescript-developer \
  mr-loop \
  patch \
  teach
do
  assert_terra_low_agent "$agent"
done

assert_contains "build uses terra low" "$CONFIG" '"build": {'
if jq -e '.agent.build.model == "datax_openai/gpt-5.6-terra" and .agent.build.variant == "low" and .agent.plan.model == "datax_openai/gpt-5.6-terra" and .agent.plan.variant == "low" and .agent.patch.model == "datax_openai/gpt-5.6-terra" and .agent.patch.variant == "low" and .agent.teach.model == "datax_openai/gpt-5.6-terra" and .agent.teach.variant == "low"' "$CONFIG" >/dev/null; then
  pass "inline agents use terra low"
else
  fail "inline agents use terra low"
fi

for exec_agent in \
  docker-developer \
  golang-developer \
  react-native-expo-developer \
  typescript-developer
do
  assert_contains "agent $exec_agent has execution-only contract" "$AGENT_DIR/$exec_agent.md" "## Execution-Only Contract"
  assert_contains "agent $exec_agent does not own broad strategy" "$AGENT_DIR/$exec_agent.md" "Do not create project plans"
  assert_contains "agent $exec_agent returns reassignment signal" "$AGENT_DIR/$exec_agent.md" "needs_primary_reassignment"
done

assert_contains "command selects active agent" "$COMMAND" "agent: mr-loop"
assert_contains "command documents invocation" "$COMMAND" "/mr-loop <MR URL> [--until mergeable|merged]"
assert_contains "command defaults mergeable" "$COMMAND" 'Default `--until` to `mergeable`.'
assert_not_contains "command does not duplicate history policy" "$COMMAND" "Never locally rebase"
assert_not_contains "command does not duplicate recursive CI policy" "$COMMAND" "bridges, downstream pipelines"

for skill in \
  mr-loop-evidence \
  mr-loop-snapshot \
  mr-loop-synchronization \
  mr-loop-conflict-analysis \
  mr-loop-conflict-integration \
  mr-loop-review-repair \
  mr-loop-pipeline \
  mr-loop-linear-context
do
  assert_skill "$skill"
done

for worker in \
  mr-loop-review-investigator \
  mr-loop-conflict-investigator \
  mr-loop-ci-investigator
do
  assert_worker "$worker"
done

assert_contains "agent loads GitLab skill" "$AGENT" 'Load `gitlab-cli-skills`'
assert_contains "agent loads glab skill" "$AGENT" 'Load `glab`'
assert_contains "agent states skills do not override state" "$AGENT" "Skills provide procedures and"
assert_contains "agent retains primary mutation ownership" "$AGENT" "INV-PRIMARY-MUTATION-OWNER"
assert_contains "agent retains no history rewrite invariant" "$AGENT" "INV-NO-HISTORY-REWRITE"
assert_contains "agent retains pre-sync repair invariant" "$AGENT" "INV-NO-PRESYNC-REPAIR"
assert_contains "agent retains deadline invariant" "$AGENT" "INV-PIPELINE-DEADLINE-FIRST"
assert_contains "agent retains permission override" "$AGENT" "override generic skill"
assert_contains "agent delegates only execution scopes" "$AGENT" "Subagents are execution-only helpers"
assert_contains "agent keeps planning in primary" "$AGENT" "Do not ask subagents to plan"
assert_contains "agent handles reassignment signal" "$AGENT" "do not treat it as a blocker"
assert_contains "agent continues after reassignment" "$AGENT" "continue the loop whenever a safe next"
assert_contains "agent has canonical state machine" "$AGENT" "## Canonical State Machine"
assert_contains "agent defines safe merge conflict transition" "$AGENT" "safe_merge_conflict_resolution"
assert_contains "agent defines terminal guard" "$AGENT" 'there is no executable `next_state`'
assert_contains "agent rejects Next final stop" "$AGENT" 'containing `Next:`'

assert_contains "evidence defines immutable envelope" "$SKILL_DIR/mr-loop-evidence/SKILL.md" "Immutable Assignment Envelope"
assert_contains "evidence defines worker result contract" "$SKILL_DIR/mr-loop-evidence/SKILL.md" "Worker Result Contract"
assert_contains "evidence discards stale workers" "$SKILL_DIR/mr-loop-evidence/SKILL.md" "SHA, or target SHA changes"
assert_contains "snapshot requires exact target endpoint" "$SKILL_DIR/mr-loop-snapshot/SKILL.md" "target project's branch endpoint"
assert_contains "snapshot paginates discussions" "$SKILL_DIR/mr-loop-snapshot/SKILL.md" "all paginated discussion pages"
assert_contains "sync defines gate" "$SKILL_DIR/mr-loop-synchronization/SKILL.md" "The synchronization gate is open only when"
assert_contains "sync checks target ancestry" "$SKILL_DIR/mr-loop-synchronization/SKILL.md" 'git merge-base --is-ancestor <fetched-target-sha> <mr-sha>'
assert_contains "sync requests GitLab rebase" "$SKILL_DIR/mr-loop-synchronization/SKILL.md" 'glab mr rebase <iid> --repo <project>'
assert_contains "sync successful rebase skips local merge" "$SKILL_DIR/mr-loop-synchronization/SKILL.md" "do not run local merge fallback"
assert_contains "sync permits guarded target pull" "$SKILL_DIR/mr-loop-synchronization/SKILL.md" 'git pull --ff-only'
assert_contains "conflict analysis preserves both parents" "$SKILL_DIR/mr-loop-conflict-analysis/SKILL.md" "Preserve non-overlapping behavior from both parents"
assert_contains "conflict analysis handles add-add" "$SKILL_DIR/mr-loop-conflict-analysis/SKILL.md" "add/add conflicts containing"
assert_contains "conflict analysis detects generated files" "$SKILL_DIR/mr-loop-conflict-analysis/SKILL.md" "SQLC output, protobuf"
assert_contains "conflict analysis separates mechanism from intent" "$SKILL_DIR/mr-loop-conflict-analysis/SKILL.md" "Conflict intent and mechanism availability are separate"
assert_contains "conflict integration creates detached worktree" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'git worktree add --detach /tmp/mr-loop-worktree-<conflict-attempt-id>'
assert_contains "conflict integration merges exact target" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'git merge --no-ff --no-commit <exact-target-sha>'
assert_contains "conflict integration defines resolved boundary" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'Set `conflict_phase=resolved_uncommitted` only after'
assert_contains "conflict integration preserves merge ref" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'refs/mr-loop/conflicts/<conflict-attempt-id>'
assert_contains "conflict integration pushes detached head" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'git push origin HEAD:<source-branch>'
assert_contains "review repair batches discussions" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" "Do not commit or push after each discussion"
assert_contains "review repair records decisions" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" "Record every autonomous decision"
assert_contains "pipeline defines canonical pipeline" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" 'Maintain `verification_sha` and `canonical_pipeline_id`'
assert_contains "pipeline recursively fetches bridges" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" 'pipelines/<pipeline-id>/bridges?per_page=100'
assert_contains "pipeline checks jobs before aggregate" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" "Before aggregate pipeline status"
assert_contains "pipeline forbids shell polling loops" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" 'Never delegate waiting to a shell `while`'
assert_contains "pipeline serializes mutations" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" "perform exactly one mutation"
assert_contains "linear context requires exact lookup" "$SKILL_DIR/mr-loop-linear-context/SKILL.md" "Fetch that exact issue"
assert_contains "linear context defaults target behavior" "$SKILL_DIR/mr-loop-linear-context/SKILL.md" "target behavior wins"
assert_contains "linear context checks authorization tests" "$SKILL_DIR/mr-loop-linear-context/SKILL.md" "including authorization boundaries"

assert_contains "permissions deny local rebase" "$AGENT" '"git rebase *": deny'
assert_contains "permissions deny reset" "$AGENT" '"git reset *": deny'
assert_contains "permissions deny clean" "$AGENT" '"git clean *": deny'
assert_contains "permissions deny stash" "$AGENT" '"git stash *": deny'
assert_contains "permissions deny amend" "$AGENT" '"git commit --amend*": deny'
assert_contains "permissions deny force push" "$AGENT" '"git push *--force*": deny'
assert_contains "permissions allow exact merge form" "$AGENT" '"git merge --no-ff --no-commit *": allow'
assert_contains "permissions allow detached loop worktree" "$AGENT" '"git worktree add --detach /tmp/mr-loop-* *": allow'
assert_contains "permissions prohibit force worktree cleanup" "$AGENT" '"git worktree remove *": deny'
assert_contains "permissions deny forced refspec push" "$AGENT" '"git push * +*": deny'
assert_contains "permissions deny hidden while polling" "$AGENT" '"*while*glab api*pipelines/*": deny'
assert_contains "permissions deny hidden until polling" "$AGENT" '"*until*glab api*pipelines/*": deny'

assert_contains "review worker loads evidence" "$AGENT_DIR/mr-loop-review-investigator.md" "mr-loop-evidence: allow"
assert_contains "conflict worker loads conflict analysis" "$AGENT_DIR/mr-loop-conflict-investigator.md" "mr-loop-conflict-analysis: allow"
assert_contains "ci worker loads pipeline" "$AGENT_DIR/mr-loop-ci-investigator.md" "mr-loop-pipeline: allow"
assert_contains "review worker forbids writes" "$AGENT_DIR/mr-loop-review-investigator.md" "Do not make GitLab writes"
assert_contains "conflict worker forbids Git mutation" "$AGENT_DIR/mr-loop-conflict-investigator.md" "Do not edit files, resolve markers"
assert_contains "ci worker forbids retries" "$AGENT_DIR/mr-loop-ci-investigator.md" "Do not retry, cancel, create"

assert_contains "docs identify authoritative agent" "$DOC" '.config/opencode/agents/mr-loop.md'
assert_contains "docs identify skill source" "$DOC" '.config/opencode/skills/mr-loop-*/SKILL.md'
assert_contains "docs identify worker model" "$DOC" "## Worker Model"
assert_contains "docs distinguish historical supervisor" "$DOC" 'removed `.local/bin/mr-loop` shell'
assert_contains "docs record policy test" "$DOC" 'sh tests/mr-loop-test.sh'

if jq -e '
  length == 19 and
  ([.[].scenario] | unique | length) == 19 and
  all(.[]; (.from | type == "string") and (.event | type == "string") and (.guards | type == "array") and (.actions | type == "array") and (.to | type == "string") and (.forbidden | type == "array")) and
  (map(select(.scenario == "gitlab_rebase_succeeds" and .to == "startup" and (.forbidden | index("local_merge")))) | length) == 1 and
  (map(select(.scenario == "gitlab_rebase_conflicts" and .to == "safe_merge_conflict_resolution" and (.forbidden | index("local_rebase")))) | length) == 1 and
  (map(select(.scenario == "clear_content_conflict" and .to == "resolved_uncommitted" and (.actions | index("set_resolved_uncommitted")))) | length) == 1 and
  (map(select(.scenario == "compatible_add_add_conflict" and .to == "resolved_uncommitted" and (.actions | index("set_resolved_uncommitted")))) | length) == 1 and
  (map(select(.scenario == "generated_file_conflict" and .to == "resolved_uncommitted" and (.actions | index("stage_sources_and_generated_outputs")))) | length) == 1 and
  (map(select(.scenario == "resolved_uncommitted_commits" and .from == "resolved_uncommitted" and .to == "committed_unpushed" and (.actions | index("preserve_merge_ref")))) | length) == 1 and
  (map(select(.scenario == "target_changes_before_commit" and .from == "resolved_uncommitted" and .to == "startup" and (.forbidden | index("push")))) | length) == 1 and
  (map(select(.scenario == "source_changes_before_commit" and .from == "resolved_uncommitted" and .to == "startup_or_blocked_remote_changed")) | length) == 1 and
  (map(select(.scenario == "dirty_initial_worktree" and .to == "manual_action_required" and (.forbidden | index("clean")))) | length) == 1 and
  (map(select(.scenario == "normal_push_fails" and .from == "committed_unpushed" and .to == "blocked_remote_changed" and (.forbidden | index("force_push")))) | length) == 1 and
  (map(select(.scenario == "interruption_recovery_unresolved" and (.event | contains("resolved_uncommitted")))) | length) == 1 and
  (map(select(.scenario == "interruption_recovery_committed" and (.forbidden | index("amend")))) | length) == 1 and
  (map(select(.scenario == "interruption_recovery_pushed" and (.forbidden | index("push_again")))) | length) == 1
' "$SCENARIOS" >/dev/null; then
  pass "structured merge fallback state scenarios are specified"
else
  fail "structured merge fallback state scenarios are specified"
fi

if jq -e '.mcp.linear.type == "remote" and .mcp.linear.url == "https://mcp.linear.app/mcp" and .mcp.linear.enabled == true' "$CONFIG" >/dev/null; then
  pass "Linear MCP is globally enabled"
else
  fail "Linear MCP is globally enabled"
fi

printf '1..%s\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]

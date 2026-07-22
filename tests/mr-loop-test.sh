#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AGENT="$ROOT/.config/opencode/agents/mr-loop-mastermind.md"
COMMAND="$ROOT/.config/opencode/commands/mr-loop.md"
CONFIG="$ROOT/.config/opencode/opencode.json"
DOC="$ROOT/docs/mr-loop.md"
SCENARIOS="$ROOT/tests/fixtures/mr-loop-conflict-scenarios.json"
TRIAGE_SCENARIOS="$ROOT/tests/fixtures/mr-loop-review-triage-scenarios.json"
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

assert_not_contains "mastermind is not execution model" "$AGENT" "model: datax_openai/gpt-5.6-terra"
assert_contains "mastermind uses low reasoning" "$AGENT" "variant: low"

assert_terra_low_agent() {
  name=$1
  path="$AGENT_DIR/$name.md"
  assert_file "agent $name exists" "$path"
  assert_contains "agent $name uses terra model" "$path" "model: datax_openai/gpt-5.6-terra"
  assert_contains "agent $name uses low variant" "$path" "variant: low"
}

assert_sol_low_agent() {
  name=$1
  path="$AGENT_DIR/$name.md"
  assert_file "agent $name exists" "$path"
  assert_contains "agent $name uses sol model" "$path" "model: datax_openai/gpt-5.6-sol"
  assert_contains "agent $name uses low variant" "$path" "variant: low"
}

assert_file "active MR agent exists" "$AGENT"
assert_file "active MR command exists" "$COMMAND"
assert_file "global OpenCode config exists" "$CONFIG"
assert_file "active MR loop documentation exists" "$DOC"
assert_file "merge fallback scenario fixture exists" "$SCENARIOS"
assert_file "review triage scenario fixture exists" "$TRIAGE_SCENARIOS"
assert_tree_not_contains "workers do not report blocked input" "blocked_input"

for agent in \
  docker-developer \
  golang-developer \
  react-native-expo-developer \
  typescript-developer
do
  assert_terra_low_agent "$agent"
done

for agent in \
  mr-loop-mastermind
do
  assert_sol_low_agent "$agent"
done

assert_contains "build is configured" "$CONFIG" '"build": {'
if jq -e '.agent.build.model == "datax_openai/gpt-5.6-sol" and .agent.build.variant == "low" and .agent.plan.model == "datax_openai/gpt-5.6-sol" and .agent.plan.variant == "low" and .agent.patch.model == "datax_openai/gpt-5.6-terra" and .agent.patch.variant == "low" and .agent.teach.model == "datax_openai/gpt-5.6-terra" and .agent.teach.variant == "low"' "$CONFIG" >/dev/null; then
  pass "inline agents use role-based models"
else
  fail "inline agents use role-based models"
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

assert_contains "command selects active agent" "$COMMAND" "agent: mr-loop-mastermind"
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
assert_contains "agent defines causal metadata exception" "$AGENT" "INV-PRESYNC-CAUSAL-METADATA-REPAIR"
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
assert_contains "conflict analysis scopes causal metadata" "$SKILL_DIR/mr-loop-conflict-analysis/SKILL.md" "Validation-Enabling Metadata"
assert_contains "conflict analysis separates mechanism from intent" "$SKILL_DIR/mr-loop-conflict-analysis/SKILL.md" "Conflict intent and mechanism availability are separate"
assert_contains "conflict integration creates detached worktree" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'git worktree add --detach /tmp/mr-loop-worktree-<conflict-attempt-id>'
assert_contains "conflict integration merges exact target" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'git merge --no-ff --no-commit <exact-target-sha>'
assert_contains "conflict integration defines resolved boundary" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'Set `conflict_phase=resolved_uncommitted` only after'
assert_contains "conflict integration verifies metadata attributes" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" '`git check-attr`'
assert_contains "conflict integration keeps metadata in merge commit" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" "two-parent commit on the existing MR branch"
assert_contains "conflict integration preserves merge ref" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'refs/mr-loop/conflicts/<conflict-attempt-id>'
assert_contains "conflict integration pushes detached head" "$SKILL_DIR/mr-loop-conflict-integration/SKILL.md" 'git push origin HEAD:<source-branch>'
assert_contains "review repair batches discussions" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" "Do not commit or push after each discussion"
assert_contains "review repair records decisions" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" "Record every autonomous decision"
assert_contains "review repair defines exact four-way triage" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" '`must-fix`'
assert_contains "review repair defines warning suppression" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" '`suppress-with-reason`'
assert_contains "review repair defines stale findings" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" '`already-fixed-or-stale`'
assert_contains "review repair defines human decisions" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" '`needs-human-decision`'
assert_contains "review repair makes material risk decisive" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" "Severity is an input, not the decision"
assert_contains "review repair requires cited fix guidance" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" "read and follow the cited rule's \`## Fix\` section"
assert_contains "review repair forbids inferred finding ids" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" "Never calculate, infer, repair"
assert_contains "review repair keeps stale findings edit-free" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" "Make no code edit for this disposition"
assert_contains "review repair routes stale lifecycle gaps to humans" "$SKILL_DIR/mr-loop-review-repair/SKILL.md" "return \`manual_action_required\`"
assert_contains "snapshot preserves resolved findings" "$SKILL_DIR/mr-loop-snapshot/SKILL.md" "Preserve findings even when"
assert_contains "snapshot collects authorization trust" "$SKILL_DIR/mr-loop-snapshot/SKILL.md" 'Developer-or-higher authorization (`access_level >= 30`)'
assert_contains "snapshot fails closed on commenter trust" "$SKILL_DIR/mr-loop-snapshot/SKILL.md" "Never fall back to trusting every commenter"
assert_contains "snapshot revalidates target after collection" "$SKILL_DIR/mr-loop-snapshot/SKILL.md" "exact target SHA changed"
assert_contains "mastermind tracks one finding disposition" "$AGENT" "Each current agent-review"
assert_contains "mastermind posts exact suppression directive" "$AGENT" "agent-review: suppress <exact-finding-id>"
assert_contains "mastermind requires suppression reason" "$AGENT" "Reason: <concise evidence"
assert_contains "mastermind verifies developer authorization" "$AGENT" '`access_level >= 30`'
assert_contains "mastermind requires canonical suppression body" "$AGENT" "entire persisted body has the canonical one-finding form"
assert_contains "mastermind revalidates envelope after suppression" "$AGENT" "review head/base markers, finding body/ID"
assert_contains "mastermind handles duplicate stable ids" "$AGENT" "multiple distinct current findings"
assert_contains "mastermind makes manual resolution insufficient" "$AGENT" "Manual thread resolution alone is never a disposition"
assert_contains "mastermind keeps pipeline logs out of suppression" "$AGENT" "job trace, bridge, or downstream pipeline is pipeline evidence, not a suppressible"
assert_contains "mastermind requires final branch-wide dispatch" "$AGENT" "branch-wide review-rule"
assert_contains "mastermind records exact Subanana dispatch" "$AGENT" 'git diff --name-only master... | node scripts/rules-for-paths.js -'
assert_contains "mastermind dispatches authoritative exact SHA diff" "$AGENT" 'git diff --name-only <exact-target-sha>...<expected-source-sha> | node scripts/rules-for-paths.js -'
assert_contains "mastermind defines review lifecycle wait" "$AGENT" '`awaiting_review_lifecycle`'
assert_contains "pipeline defines canonical pipeline" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" 'Maintain `verification_sha` and `canonical_pipeline_id`'
assert_contains "pipeline recursively fetches bridges" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" 'pipelines/<pipeline-id>/bridges?per_page=100'
assert_contains "pipeline checks jobs before aggregate" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" "Before aggregate pipeline status"
assert_contains "pipeline forbids shell polling loops" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" 'Never delegate waiting to a shell `while`'
assert_contains "pipeline serializes mutations" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" "perform exactly one mutation"
assert_contains "pipeline rejects helper path-only coverage" "$SKILL_DIR/mr-loop-pipeline/SKILL.md" "path-selected helper-MR pipeline"
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

assert_contains "docs identify authoritative agent" "$DOC" '.config/opencode/agents/mr-loop-mastermind.md'
assert_contains "docs identify skill source" "$DOC" '.config/opencode/skills/mr-loop-*/SKILL.md'
assert_contains "docs identify worker model" "$DOC" "## Worker Model"
assert_contains "docs distinguish historical supervisor" "$DOC" 'removed `.local/bin/mr-loop` shell'
assert_contains "docs record policy test" "$DOC" 'sh tests/mr-loop-test.sh'

if jq -e '
  length == 23 and
  ([.[].scenario] | unique | length) == 23 and
  all(.[]; (.from | type == "string") and (.event | type == "string") and (.guards | type == "array") and (.actions | type == "array") and (.to | type == "string") and (.forbidden | type == "array")) and
  (map(select(.scenario == "gitlab_rebase_succeeds" and .to == "startup" and (.forbidden | index("local_merge")))) | length) == 1 and
  (map(select(.scenario == "gitlab_rebase_conflicts" and .to == "safe_merge_conflict_resolution" and (.forbidden | index("local_rebase")))) | length) == 1 and
  (map(select(.scenario == "clear_content_conflict" and .to == "resolved_uncommitted" and (.actions | index("set_resolved_uncommitted")))) | length) == 1 and
  (map(select(.scenario == "compatible_add_add_conflict" and .to == "resolved_uncommitted" and (.actions | index("set_resolved_uncommitted")))) | length) == 1 and
  (map(select(.scenario == "generated_file_conflict" and .to == "resolved_uncommitted" and (.actions | index("stage_sources_and_generated_outputs")))) | length) == 1 and
  (map(select(.scenario == "path_scoped_vendor_whitespace_metadata" and .to == "resolved_uncommitted" and (.actions | index("stage_causal_metadata_with_merge")) and (.forbidden | index("create_helper_mr")))) | length) == 1 and
  (map(select(.scenario == "repository_wide_whitespace_disable_denied" and .to == "manual_action_required" and (.forbidden | index("stage_metadata")))) | length) == 1 and
  (map(select(.scenario == "unrelated_first_party_lint_disable_denied" and .to == "manual_action_required" and (.guards | index("unrelated_validation_weakened")))) | length) == 1 and
  (map(select(.scenario == "runtime_config_validation_bypass_denied" and .to == "manual_action_required" and (.forbidden | index("stage_runtime_config")))) | length) == 1 and
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

if jq -e '
  length == 18 and
  ([.[].scenario] | unique | length) == 18 and
  all(.[];
    (.scenario | type == "string") and
    (.severity | IN("error", "warning", "info")) and
    (.finding_id | test("^[0-9a-f]{10}$")) and
    (.facts | type == "array") and
    ((.classification == null) or (.classification | IN("must-fix", "suppress-with-reason", "already-fixed-or-stale", "needs-human-decision"))) and
    (.code_edit | type == "boolean") and
    ((.suppression_comment == null) or (.suppression_comment | type == "string")) and
    ((.actor_authorized == null) or (.actor_authorized | type == "boolean")) and
    (.thread_resolved | type == "boolean") and
    (.disposition_recorded | type == "boolean") and
    (.complete | type == "boolean") and
    (.merge_ready | type == "boolean") and
    (.state | type == "string")
  ) and
  (map(select(.scenario == "valid_error_requires_fix" and .severity == "error" and .classification == "must-fix" and .code_edit == true and .merge_ready == false)) | length) == 1 and
  (map(select(.scenario == "material_warning_requires_fix" and .severity == "warning" and .classification == "must-fix" and (.facts | index("material_breakage_scenario")) and .code_edit == true)) | length) == 1 and
  (map(select(.scenario == "harmless_false_positive_warning" and .classification == "suppress-with-reason" and (.facts | index("no_material_risk")) and .code_edit == false)) | length) == 1 and
  (map(select(.scenario == "uncertain_warning_needs_human" and .classification == "needs-human-decision" and .state == "manual_action_required" and .code_edit == false)) | length) == 1 and
  (map(select(.scenario == "authorized_suppression_has_exact_id_and_reason" and .actor_authorized == true and (. as $scenario | .suppression_comment | startswith("agent-review: suppress " + $scenario.finding_id + "\n\nReason: ")) and (.facts | index("post_write_comment_persisted")) and (.facts | index("post_write_membership_verified")) and (.facts | index("post_write_envelope_unchanged")) and .complete == true)) | length) == 1 and
  (map(select(.scenario == "unauthorized_suppression_is_incomplete" and .actor_authorized == false and .complete == false and .merge_ready == false and .state == "manual_action_required")) | length) == 1 and
  (map(select(.scenario == "authorization_lookup_unavailable_is_incomplete" and .actor_authorized == null and .suppression_comment == null and .complete == false and .state == "manual_action_required")) | length) == 1 and
  (map(select(.scenario == "manual_resolution_is_not_a_disposition" and .thread_resolved == true and .disposition_recorded == false and .classification == null and .merge_ready == false)) | length) == 1 and
  (map(select(.scenario == "stale_finding_does_not_edit_code" and .classification == "already-fixed-or-stale" and (.facts | index("automatic_review_pending")) and .code_edit == false and .complete == false and .state == "awaiting_review_lifecycle")) | length) == 1 and
  (map(select(.scenario == "dedup_allows_matching_bot_thread_resolution" and (.facts | index("authorized_suppression_verified")) and (.facts | index("post_write_envelope_unchanged")) and (.facts | index("exact_head_base_dedup")) and (.facts | index("matching_bot_thread")) and .actor_authorized == true and .thread_resolved == true and .complete == true)) | length) == 1 and
  (map(select(.scenario == "post_write_comment_missing_is_incomplete" and (.facts | index("post_write_comment_missing")) and .complete == false and .state == "manual_action_required")) | length) == 1 and
  (map(select(.scenario == "post_write_envelope_change_requires_retriage" and (.facts | index("source_sha_changed_after_comment")) and .complete == false and .state == "triage_required")) | length) == 1 and
  (map(select(.scenario == "quoted_directive_is_not_canonical_completion" and (.suppression_comment | startswith("> agent-review:")) and .complete == false)) | length) == 1 and
  (map(select(.scenario == "multi_id_directive_is_not_canonical_completion" and (.facts | index("multiple_finding_ids")) and .complete == false)) | length) == 1 and
  (map(select(.scenario == "info_suppression_is_incomplete_until_lifecycle" and .severity == "info" and .classification == "suppress-with-reason" and .complete == false and .merge_ready == false and .state == "awaiting_review_lifecycle")) | length) == 1 and
  (map(select(.scenario == "failed_pipeline_trace_is_not_suppressible" and (.facts | index("failed_job_trace_fetched")) and .classification == "must-fix" and .suppression_comment == null and .code_edit == true)) | length) == 1 and
  (map(select(.scenario == "duplicate_stable_id_requires_human_decision" and (.facts | index("same_id_multiple_current_occurrences")) and .classification == "needs-human-decision" and .state == "manual_action_required")) | length) == 1 and
  (map(select(.scenario == "stale_finding_without_review_path_needs_manual_action" and (.facts | index("no_automatic_review_path")) and .classification == "already-fixed-or-stale" and .code_edit == false and .state == "manual_action_required")) | length) == 1
' "$TRIAGE_SCENARIOS" >/dev/null; then
  pass "structured proportional review triage scenarios are specified"
else
  fail "structured proportional review triage scenarios are specified"
fi

if jq -e '.mcp.linear.type == "remote" and .mcp.linear.url == "https://mcp.linear.app/mcp" and .mcp.linear.enabled == true' "$CONFIG" >/dev/null; then
  pass "Linear MCP is globally enabled"
else
  fail "Linear MCP is globally enabled"
fi

printf '1..%s\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]

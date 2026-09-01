#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG="$ROOT/.codex/config.toml"
OPENCODE_CONFIG="$ROOT/.config/opencode/opencode.json"
PI_MCP_CONFIG="$ROOT/.pi/agent/mcp.json"
AGENTS_DIR="$ROOT/.codex/agents"
SKILLS_DIR="$ROOT/.agents/skills"

failures=0

pass() { printf 'ok - %s\n' "$1"; }
fail() { printf 'not ok - %s\n' "$1"; failures=$((failures + 1)); }

assert_file() {
  if [ -f "$2" ]; then pass "$1"; else fail "$1 ($2 missing)"; fi
}

assert_contains() {
  if grep -F -q -- "$3" "$2"; then pass "$1"; else fail "$1 ($3 missing from $2)"; fi
}

assert_file "global Codex guidance exists" "$ROOT/.codex/AGENTS.md"
assert_contains "native TUI notifications enabled" "$CONFIG" "notifications = true"
assert_contains "Linear MCP configured" "$CONFIG" "[mcp_servers.linear]"
assert_contains "artifact-drop MCP configured" "$CONFIG" "[mcp_servers.artifact-drop]"
assert_contains "Chrome MCP retained disabled" "$CONFIG" "[mcp_servers.chrome-devtools]"
assert_contains "subagent nesting is bounded" "$CONFIG" "max_depth = 1"
assert_file "global execpolicy exists" "$ROOT/.codex/rules/global.rules"
assert_contains "execpolicy forbids rm" "$ROOT/.codex/rules/global.rules" 'pattern = ["rm"]'
assert_contains "execpolicy forbids chmod" "$ROOT/.codex/rules/global.rules" 'pattern = ["chmod"]'
assert_contains "execpolicy forbids reset" "$ROOT/.codex/rules/global.rules" 'pattern = ["git", "reset"]'
assert_contains "execpolicy forbids force push" "$ROOT/.codex/rules/global.rules" '"--force-with-lease"'

for skill in mr-loop ticket-loop test-loop double-check mission foreman patch teach; do
  path="$SKILLS_DIR/$skill/SKILL.md"
  assert_file "skill $skill exists" "$path"
  assert_contains "skill $skill has matching name" "$path" "name: $skill"
  assert_file "skill $skill has UI metadata" "$SKILLS_DIR/$skill/agents/openai.yaml"
done

assert_contains "mr-loop bootstraps a missing MR" "$SKILLS_DIR/mr-loop/SKILL.md" \
  "When the local branch has no open MR"
assert_contains "mr-loop state machine includes MR bootstrap" \
  "$SKILLS_DIR/mr-loop/references/state-machine.md" '`bootstrap_mr`'
assert_contains "mr-loop bootstrap rechecks MR uniqueness" "$SKILLS_DIR/mr-loop/SKILL.md" \
  "create one MR only after proving"
assert_contains "mr-loop pairs exact source branch names" "$SKILLS_DIR/mr-loop/SKILL.md" \
  "use exactly the same source-branch name as the app MR"
assert_contains "mr-loop creates missing app worktree" "$SKILLS_DIR/mr-loop/SKILL.md" \
  'wt -C /Users/louie/Documents/subanana/subanana-main switch --create <source-branch>'
assert_contains "mr-loop gates DevOps artifacts on infrastructure" "$SKILLS_DIR/mr-loop/SKILL.md" \
  "changes are not required, do not create a DevOps worktree, branch, or MR"
assert_contains "mr-loop requires non-empty DevOps diff" "$SKILLS_DIR/mr-loop/SKILL.md" \
  "verified, non-empty diff against the exact DevOps target"
assert_contains "mr-loop bootstraps paired DevOps MR" "$SKILLS_DIR/mr-loop/SKILL.md" \
  "create exactly one DevOps MR"
assert_contains "mr-loop state machine includes paired DevOps bootstrap" \
  "$SKILLS_DIR/mr-loop/references/state-machine.md" '`bootstrap_devops_mr`'
assert_contains "mr-loop gates pair mergeability" "$SKILLS_DIR/mr-loop/SKILL.md" \
  "require every required MR in the pair"

assert_contains "test-loop uses MR deploy environments first" "$SKILLS_DIR/test-loop/SKILL.md" \
  "MR deploy environment (preferred)"
assert_contains "test-loop has the consumer dev fallback" "$SKILLS_DIR/test-loop/SKILL.md" \
  "https://dev-plus.subanana.com/"
assert_contains "test-loop gates MR preview on deploy job" "$SKILLS_DIR/test-loop/SKILL.md" \
  '`dev:ci-deploy:mr` job exists and has succeeded'
assert_contains "test-loop checks dev deploy is runnable" "$SKILLS_DIR/test-loop/SKILL.md" \
  '`services:all:deploy:dev` is runnable'
assert_contains "test-loop never runs dev deploy" "$SKILLS_DIR/test-loop/SKILL.md" \
  'Never play, trigger,'
assert_contains "test-loop gates production" "$SKILLS_DIR/test-loop/SKILL.md" \
  "after the user explicitly approves production testing"
assert_contains "test-loop names staff profile" "$SKILLS_DIR/test-loop/SKILL.md" \
  'Chrome MCP `Development` profile'
assert_contains "test-loop names free profile" "$SKILLS_DIR/test-loop/SKILL.md" \
  'Chrome MCP `louielee.learn@gmail.com` profile'
assert_contains "test-loop names paid profile" "$SKILLS_DIR/test-loop/SKILL.md" \
  'Chrome MCP `louielee.dev@gmail.com` profile'
assert_contains "test-loop names Subanana profile" "$SKILLS_DIR/test-loop/SKILL.md" \
  'Chrome MCP `Subanana` profile'

assert_contains "double-check resolves ticket from branch" "$SKILLS_DIR/double-check/SKILL.md" \
  'Extract the case-insensitive `SUB-[0-9]+` key from the current branch name'
assert_contains "double-check uses Linear MCP" "$SKILLS_DIR/double-check/SKILL.md" \
  "Fetch that exact issue through Linear MCP"
assert_contains "double-check inspects related scope" "$SKILLS_DIR/double-check/SKILL.md" \
  "direct siblings that share the same parent"
assert_contains "double-check keeps Linear read-only" "$SKILLS_DIR/double-check/SKILL.md" \
  "Keep Linear strictly read-only"
assert_contains "double-check reports scope verdict" "$SKILLS_DIR/double-check/SKILL.md" \
  'overall `matches`, `partially matches`, `does not match`, or `cannot determine` verdict'
assert_contains "double-check reports verification plan" "$SKILLS_DIR/double-check/SKILL.md" \
  '**Verification plan**'
assert_contains "double-check reports follow-up gaps" "$SKILLS_DIR/double-check/SKILL.md" \
  '**Missing parts and follow-up**'

for agent in \
  docker-developer \
  golang-developer \
  typescript-developer \
  react-native-expo-developer \
  mr-loop-review-investigator \
  mr-loop-conflict-investigator \
  mr-loop-ci-investigator \
  ticket-loop-worker \
  ticket-loop-commit-qa \
  ticket-loop-integration-pm
do
  path="$AGENTS_DIR/$agent.toml"
  assert_file "custom agent $agent exists" "$path"
  assert_contains "custom agent $agent has matching name" "$path" "name = \"$agent\""
  assert_contains "custom agent $agent has developer instructions" "$path" "developer_instructions ="
done

for agent in mr-loop-review-investigator mr-loop-conflict-investigator mr-loop-ci-investigator ticket-loop-commit-qa ticket-loop-integration-pm; do
  assert_contains "read-only agent $agent is sandboxed" "$AGENTS_DIR/$agent.toml" 'sandbox_mode = "read-only"'
done

python3 - "$CONFIG" "$OPENCODE_CONFIG" "$PI_MCP_CONFIG" "$AGENTS_DIR" <<'PY'
import glob
import json
import os
import sys
import tomllib

config_path, opencode_path, pi_path, agents_dir = sys.argv[1:]
files = [config_path, *glob.glob(os.path.join(agents_dir, "*.toml"))]
for path in files:
    with open(path, "rb") as stream:
        tomllib.load(stream)
print(f"ok - parsed {len(files)} Codex TOML files")

with open(config_path, "rb") as stream:
    codex_mcp = set(tomllib.load(stream).get("mcp_servers", {}))
with open(opencode_path, encoding="utf-8") as stream:
    opencode_mcp = set(json.load(stream).get("mcp", {}))
with open(pi_path, encoding="utf-8") as stream:
    pi_mcp = json.load(stream)

if codex_mcp != opencode_mcp:
    missing = sorted(codex_mcp - opencode_mcp)
    extra = sorted(opencode_mcp - codex_mcp)
    raise SystemExit(f"Codex/OpenCode MCP sets differ: missing={missing}, extra={extra}")
if "codex" not in pi_mcp.get("imports", []):
    raise SystemExit("Pi MCP config must import the shared Codex MCP set")
print(f"ok - {len(codex_mcp)} MCP servers are shared across Codex, OpenCode, and Pi")
PY

decision=$(codex execpolicy check --rules "$ROOT/.codex/rules/global.rules" -- git reset --hard HEAD)
case "$decision" in
  *'"decision":"forbidden"'*|*'"decision": "forbidden"'*) pass "execpolicy blocks destructive reset" ;;
  *) fail "execpolicy blocks destructive reset" ;;
esac

decision=$(codex execpolicy check --rules "$ROOT/.codex/rules/global.rules" -- rm -rf /tmp/example)
case "$decision" in
  *'"decision":"forbidden"'*|*'"decision": "forbidden"'*) pass "execpolicy blocks rm" ;;
  *) fail "execpolicy blocks rm" ;;
esac

decision=$(codex execpolicy check --rules "$ROOT/.codex/rules/global.rules" -- chmod -R 777 /tmp/example)
case "$decision" in
  *'"decision":"forbidden"'*|*'"decision": "forbidden"'*) pass "execpolicy blocks chmod" ;;
  *) fail "execpolicy blocks chmod" ;;
esac

if [ "$failures" -ne 0 ]; then
  printf '%s\n' "$failures migration contract(s) failed" >&2
  exit 1
fi

printf '%s\n' "all Codex migration contracts passed"

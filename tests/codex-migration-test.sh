#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG="$ROOT/.codex/config.toml"
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
assert_contains "execpolicy forbids reset" "$ROOT/.codex/rules/global.rules" 'pattern = ["git", "reset"]'
assert_contains "execpolicy forbids force push" "$ROOT/.codex/rules/global.rules" '"--force-with-lease"'

for skill in mr-loop ticket-loop mission foreman patch teach; do
  path="$SKILLS_DIR/$skill/SKILL.md"
  assert_file "skill $skill exists" "$path"
  assert_contains "skill $skill has matching name" "$path" "name: $skill"
  assert_file "skill $skill has UI metadata" "$SKILLS_DIR/$skill/agents/openai.yaml"
done

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

python3 - "$CONFIG" "$AGENTS_DIR" <<'PY'
import glob
import os
import sys
import tomllib

files = [sys.argv[1], *glob.glob(os.path.join(sys.argv[2], "*.toml"))]
for path in files:
    with open(path, "rb") as stream:
        tomllib.load(stream)
print(f"ok - parsed {len(files)} Codex TOML files")
PY

decision=$(codex execpolicy check --rules "$ROOT/.codex/rules/global.rules" -- git reset --hard HEAD)
case "$decision" in
  *'"decision":"forbidden"'*|*'"decision": "forbidden"'*) pass "execpolicy blocks destructive reset" ;;
  *) fail "execpolicy blocks destructive reset" ;;
esac

if [ "$failures" -ne 0 ]; then
  printf '%s\n' "$failures migration contract(s) failed" >&2
  exit 1
fi

printf '%s\n' "all Codex migration contracts passed"

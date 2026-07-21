#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MASTER="$ROOT/.config/opencode/agents/ticket-loop-mastermind.md"
INTEGRATION="$ROOT/.config/opencode/agents/ticket-loop-integration-pm.md"
WORKER="$ROOT/.config/opencode/agents/ticket-loop-worker.md"
QA="$ROOT/.config/opencode/agents/ticket-loop-commit-qa.md"
COMMAND="$ROOT/.config/opencode/commands/ticket-loop.md"
MISSION="$ROOT/.config/opencode/skills/mission/SKILL.md"
FOREMAN="$ROOT/.config/opencode/skills/foreman/SKILL.md"
DOC="$ROOT/docs/ticket-loop.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'ok %s - %s\n' "$((PASS + FAIL))" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'not ok %s - %s\n' "$((PASS + FAIL))" "$1"; }
assert_file() { if [ -f "$2" ]; then pass "$1"; else fail "$1 ($2 missing)"; fi; }
assert_contains() { if grep -Fq -- "$3" "$2"; then pass "$1"; else fail "$1"; fi; }
assert_not_contains() { if grep -Fq -- "$3" "$2"; then fail "$1"; else pass "$1"; fi; }

for file in "$MASTER" "$INTEGRATION" "$WORKER" "$QA" "$COMMAND" "$MISSION" "$FOREMAN" "$DOC"; do
  assert_file "$(basename "$file") exists" "$file"
done

assert_contains "command selects mastermind" "$COMMAND" "agent: ticket-loop-mastermind"
assert_contains "command defaults approval pause" "$COMMAND" "Require explicit plan approval"
assert_contains "command supports autonomous approval" "$COMMAND" "--approve-plan"
assert_contains "command defaults mergeable" "$COMMAND" "Default \`--until\` to"

assert_contains "mastermind reads exact Linear issue" "$MASTER" "linear_get_issue"
assert_contains "mastermind makes Linear read-only" "$MASTER" "Linear is read-only"
assert_contains "mastermind forbids Linear update" "$MASTER" "Never comment"
assert_contains "mastermind persists state" "$MASTER" "state.json"
assert_contains "mastermind requires approval by default" "$MASTER" "Default plan policy is explicit user approval"
assert_contains "mastermind serializes mutation" "$MASTER" "One mutating implementation worker runs at a time"
assert_contains "mastermind limits integration fixes" "$MASTER" "at most two automatic integration"
assert_contains "mastermind pushes automatically" "$MASTER" "perform one normal push"
assert_contains "mastermind creates MR automatically" "$MASTER" "otherwise create one automatically"
assert_contains "mastermind transfers to MR loop" "$MASTER" "invoke \`mr-loop-mastermind\`"
assert_contains "mastermind allows MR loop task" "$MASTER" "mr-loop-mastermind: allow"
assert_contains "mastermind planning uses sol" "$MASTER" "model: datax_openai/gpt-5.6-sol"
assert_contains "mastermind routes execution to generic worker" "$MASTER" "Use \`ticket-loop-worker\` for"
assert_contains "mastermind denies rebase" "$MASTER" '"git rebase *": deny'
assert_contains "mastermind denies force push" "$MASTER" '"git push *--force*": deny'

assert_contains "Mission uses current Linear tool" "$MISSION" "linear_get_issue"
assert_not_contains "Mission drops obsolete Linear tool" "$MISSION" "mcp__linear-server__get_issue"
assert_contains "Mission supports planning-only parent" "$MISSION" "planning only"

assert_contains "Foreman uses OpenCode task" "$FOREMAN" "OpenCode \`task\` tool"
assert_contains "Foreman serializes commits" "$FOREMAN" "exactly one mutating worker"
assert_contains "Foreman requires independent QA" "$FOREMAN" "fresh QA worker"
assert_not_contains "Foreman removes claude process launch" "$FOREMAN" "claude -p --model"
assert_not_contains "Foreman removes tmux launch" "$FOREMAN" "tmux respawn-window"

assert_contains "implementation worker is hidden" "$WORKER" "hidden: true"
assert_contains "implementation worker uses terra" "$WORKER" "model: datax_openai/gpt-5.6-terra"
assert_contains "implementation worker uses medium reasoning" "$WORKER" "variant: medium"
assert_contains "implementation worker cannot push" "$WORKER" '"git push*": deny'
assert_contains "commit QA is read-only" "$QA" "edit: deny"
assert_contains "commit QA uses sol" "$QA" "model: datax_openai/gpt-5.6-sol"
assert_contains "commit QA has exact verdicts" "$QA" "VERDICT: PASS"
assert_contains "integration PM is hidden" "$INTEGRATION" "hidden: true"
assert_contains "integration PM is read-only" "$INTEGRATION" "edit: deny"
assert_contains "integration PM uses sol" "$INTEGRATION" "model: datax_openai/gpt-5.6-sol"
assert_contains "integration PM detects stale SHA" "$INTEGRATION" "VERDICT: STALE"
assert_contains "integration PM cannot publish" "$INTEGRATION" "never"

assert_contains "docs show workflow" "$DOC" "whole-branch integration PM"
assert_contains "docs state no Linear writes" "$DOC" "never comments"
assert_contains "docs identify policy test" "$DOC" "sh tests/ticket-loop-test.sh"

printf '1..%s\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]

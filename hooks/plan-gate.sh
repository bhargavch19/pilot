#!/usr/bin/env bash
# G1 enforcement: block Edit/Write >20 LOC unless a recent plan exists.
# Reads JSON tool invocation from stdin (Claude Code PreToolUse format).
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // .tool // empty' 2>/dev/null || echo "")

if [[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]]; then
  exit 0
fi

NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // .input.new_string // .input.content // ""' 2>/dev/null || echo "")
LINE_COUNT=$(echo -n "$NEW_STRING" | grep -c '^' || true)

if [[ "$LINE_COUNT" -le 20 ]]; then
  exit 0
fi

# Plan-existence check: look in both the superpowers convention and the GSD
# convention (registry's resolution priority gives GSD precedence when
# .planning/ is present).
recent_plan=""
if [[ -d docs/superpowers/plans ]]; then
  recent_plan=$(find docs/superpowers/plans -name '*.md' -mtime -1 2>/dev/null | head -1 || true)
fi
if [[ -z "$recent_plan" && -d .planning ]]; then
  recent_plan=$(find .planning -type f \( -name 'PLAN.md' -o -name 'SPEC.md' \) -mtime -1 2>/dev/null | head -1 || true)
fi
if [[ -n "$recent_plan" ]]; then
  exit 0
fi

cat <<EOF >&2
plan-gate: G1 — write a plan first.

Proposed change: $LINE_COUNT lines (>20 threshold).
No recent (<24h) plan found in:
  - docs/superpowers/plans/*.md
  - .planning/**/PLAN.md (or SPEC.md)

Run the writing-plans skill (superpowers) or gsd-plan-phase, save the plan,
then retry.
Bypass: 'pilot --no-plan' (use sparingly).
EOF
exit 1

#!/usr/bin/env bash
# G1 enforcement: block Edit/Write >1 file or >20 LOC unless plan exists in last 24h.
# Reads JSON tool invocation from stdin (Claude Code PreToolUse format).
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool // empty')

if [[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]]; then
  exit 0
fi

NEW_STRING=$(echo "$INPUT" | jq -r '.input.new_string // .input.content // ""')
LINE_COUNT=$(echo -n "$NEW_STRING" | grep -c '^' || true)

if [[ "$LINE_COUNT" -le 20 ]]; then
  exit 0
fi

# Check for a recent plan (modified in last 24h).
if [[ -d docs/superpowers/plans ]]; then
  RECENT=$(find docs/superpowers/plans -name '*.md' -mtime -1 2>/dev/null | head -1)
  if [[ -n "$RECENT" ]]; then
    exit 0
  fi
fi

cat <<EOF >&2
plan-gate: G1 — write a plan first.

Proposed change: $LINE_COUNT lines (>20 threshold).
No plan in docs/superpowers/plans/ modified within 24h.

Run the writing-plans skill, save to docs/superpowers/plans/<date>-<topic>.md, then retry.
Bypass: 'pilot --no-plan' (use sparingly).
EOF
exit 1

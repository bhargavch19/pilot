#!/usr/bin/env bash
# Idempotently wire pilot hooks into ~/.claude/settings.json.
# Backs up original to settings.json.bak.<timestamp> if present.
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
PILOT_DIR="$HOME/.claude/skills/pilot"

if [[ ! -d "$PILOT_DIR" ]]; then
  echo "ERROR: $PILOT_DIR not found. Run Task 13 (symlink) first." >&2
  exit 1
fi

if [[ -f "$SETTINGS" ]]; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"
else
  echo '{}' > "$SETTINGS"
fi

# Merge hooks. Use jq for safety.
jq --arg pd "$PILOT_DIR" '
  .hooks = (.hooks // {}) |
  .hooks.PreToolUse = (.hooks.PreToolUse // []) +
    [{"matcher":"Edit|Write","hooks":[{"type":"command","command":($pd + "/hooks/plan-gate.sh")}]}] |
  .hooks.Stop = (.hooks.Stop // []) +
    [{"hooks":[{"type":"command","command":($pd + "/hooks/verify-gate.sh")}]}] |
  .hooks.SessionStart = (.hooks.SessionStart // []) +
    [{"hooks":[{"type":"command","command":($pd + "/hooks/sessionstart-banner.sh")}]}]
' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

echo "Wired hooks into $SETTINGS:"
jq '.hooks' "$SETTINGS"

#!/usr/bin/env bash
# Emits the pilot active banner at SessionStart.
# Stdout is appended to the assistant's context as system-reminder text.
set -euo pipefail

# Resolve plugin root: prefer CLAUDE_PLUGIN_ROOT (set by marketplace
# install), else walk up from this script's own dir.
ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

VERSION="?"
if [[ -f "$ROOT/.claude-plugin/plugin.json" ]] && command -v jq >/dev/null 2>&1; then
  VERSION=$(jq -r '.version // "?"' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")
fi

# Detect active bypass markers (one line if any present).
BYPASS_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/pilot"
BYPASS=""
if [[ -f "$BYPASS_DIR/bypass-session" ]]; then
  BYPASS=" (bypass: session-active)"
elif [[ -f "$BYPASS_DIR/bypass-once" || -f "$BYPASS_DIR/bypass-no-plan-once" ]]; then
  BYPASS=" (bypass: one-shot armed)"
fi

cat <<EOF
[pilot active] v${VERSION} phase routing on${BYPASS}.
registry: skills/pilot/registry.md.
bypass: /pilot-off | /pilot-off-rails | /pilot-bypass --no-plan | /pilot-back-on.
diagnostics: /pilot-status | /pilot-doctor.
EOF

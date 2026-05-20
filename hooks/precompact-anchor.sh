#!/usr/bin/env bash
# Re-anchor pilot's routing rules through context compaction.
#
# SKILL.md's routing logic drops out of context as the session grows.
# After /compact, Claude no longer has the registry rules in memory and
# pilot silently stops routing. This hook fires on PreCompact; its stdout
# is injected into the post-compact context as system-reminder text, so
# the routing essentials survive the squeeze.
#
# Keep the output terse — every token costs against the new context window.
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)
TRIGGER=$(printf '%s' "$INPUT" | jq -r '.trigger // "unknown"' 2>/dev/null || echo "unknown")

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

VERSION="?"
if [[ -f "$ROOT/.claude-plugin/plugin.json" ]] && command -v jq >/dev/null 2>&1; then
  VERSION=$(jq -r '.version // "?"' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "?")
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/pilot"
LOG="$CACHE_DIR/routing.log"

# Active bypass detection.
BYPASS_STATE="none"
if [[ -f "$CACHE_DIR/bypass-session" ]]; then
  BYPASS_STATE="session-active (/pilot-back-on to re-engage)"
elif [[ -f "$CACHE_DIR/bypass-once" \
      || -f "$CACHE_DIR/bypass-no-plan-once" \
      || -f "$CACHE_DIR/bypass-precommit-once" ]]; then
  BYPASS_STATE="one-shot armed"
fi

# Last few routing decisions (if any).
RECENT_ROUTES=""
if [[ -f "$LOG" ]]; then
  RECENT_ROUTES=$(tail -5 "$LOG" 2>/dev/null | sed 's/^/  /')
fi

cat <<EOF
[pilot v${VERSION}] re-anchoring through compact (trigger: ${TRIGGER}).

Routing rules (read \`skills/pilot/registry.md\` for the full table):
  Frame "what if/build/add" → grill-me / grill-with-docs / to-prd
  Plan  ">1 file or >20 LOC" → superpowers:writing-plans / gsd-plan-phase
  Build "implement"          → tdd / superpowers:test-driven-development
  Debug "bug/broken/throws"  → diagnose / superpowers:systematic-debugging
  Verify "done/ready"        → superpowers:verification-before-completion
  Review "PR/review"         → superpowers:requesting-code-review
  Ship  "merge/ship"         → gsd-ship / superpowers:finishing-a-development-branch

Guardrails active: G1 (plan-gate), G3/G7/G8/G12 (pre-commit), G14 (verify-gate).
Bypass: /pilot-off | /pilot-off-rails | /pilot-bypass --no-plan|--no-precommit.
Bypass state: ${BYPASS_STATE}.
EOF

if [[ -n "$RECENT_ROUTES" ]]; then
  echo
  echo "Recent routing (last 5):"
  echo "$RECENT_ROUTES"
fi

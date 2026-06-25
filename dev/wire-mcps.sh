#!/usr/bin/env bash
# Idempotently register pilot's bundled MCP servers (context7, playwright,
# github) with Claude Code via `claude mcp add`. Reads declarations from
# .claude-plugin/plugin.json — single source of truth.
#
# Why this script: marketplace-installed plugins propagate their mcpServers
# block automatically, but dev installs (symlink + wire-hooks.sh) don't.
# This is the dev-install companion to wire-hooks.sh.
#
# Re-run anytime — it's idempotent (existing entries are skipped).
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found." >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not on PATH; cannot register MCPs." >&2
  exit 1
fi

# Walk plugin.json's mcpServers block and register each entry.
jq -r '.mcpServers // {} | to_entries[] | [.key, .value.command, ((.value.args // []) | join(" "))] | @tsv' \
  "$MANIFEST" \
  | while IFS=$'\t' read -r name cmd args; do
      [[ -n "$name" ]] || continue
      if claude mcp get "$name" >/dev/null 2>&1; then
        echo "SKIP $name (already registered)"
        continue
      fi
      # Register at user scope so bundled MCPs load in every project, the
      # same way a marketplace install propagates them. Default scope is
      # `local` (cwd-only), which would silently scope the servers to
      # whatever dir this script happened to run in.
      # shellcheck disable=SC2086
      if claude mcp add --scope user "$name" "$cmd" -- $args >/dev/null 2>&1; then
        echo "ADDED $name ($cmd $args)"
      else
        echo "FAIL $name — see: claude mcp add --scope user $name $cmd -- $args" >&2
      fi
    done

echo
echo "To remove: bash $PLUGIN_DIR/dev/unwire-mcps.sh"

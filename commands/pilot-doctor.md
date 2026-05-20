---
description: Diagnose pilot installation — prereqs, hook paths, jq, symlink, settings.json wiring.
allowed-tools: Bash
---

Run a top-to-bottom pilot health check. Steps:

1. **Prereq table** — run `bash ${CLAUDE_PLUGIN_ROOT:-$HOME/Workspace/claude-skill}/dev/check-prereqs.sh`.

2. **Hook scripts executable + present** — run:
   ```bash
   ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/Workspace/claude-skill}"
   for h in plan-gate.sh pre-commit.sh verify-gate.sh sessionstart-banner.sh precompact-anchor.sh; do
     if [[ -x "$ROOT/hooks/$h" ]]; then
       echo "✓ $h"
     elif [[ -f "$ROOT/hooks/$h" ]]; then
       echo "○ $h (present but not executable — chmod +x needed)"
     else
       echo "✗ $h (missing)"
     fi
   done
   ```

3. **settings.json wiring** — list each wired pilot hook AND verify the
   command actually resolves to an executable file (catches stale paths
   left behind by a moved/renamed plugin dir):
   ```bash
   jq -r '
     .hooks // {}
     | to_entries[]
     | .key as $k
     | .value[]?
     | .hooks[]?
     | "\($k)\t\(.command)"
   ' "$HOME/.claude/settings.json" 2>/dev/null \
     | grep -E '/hooks/(plan-gate|pre-commit|verify-gate|sessionstart-banner|precompact-anchor)\.sh' \
     | while IFS=$'\t' read -r event cmd; do
         path="${cmd%% *}"  # strip any args
         path="${path#\"}"; path="${path%\"}"  # strip quotes if present
         if [[ -x "$path" ]]; then
           echo "✓ $event → $path"
         elif [[ -f "$path" ]]; then
           echo "○ $event → $path (present, not executable)"
         else
           echo "✗ $event → $path (BROKEN — file missing; run dev/unwire-hooks then dev/wire-hooks)"
         fi
       done
   # If nothing matched at all:
   jq -e '.hooks // {} | [.. | objects | .command? // empty] | any(test("/hooks/(plan-gate|pre-commit|verify-gate|sessionstart-banner|precompact-anchor)\\.sh"))' \
     "$HOME/.claude/settings.json" >/dev/null 2>&1 \
     || echo '(no pilot hooks wired — run dev/wire-hooks.sh or install via marketplace)'
   ```

4. **MCP servers** — for each entry in plugin.json's mcpServers, verify the
   command is runnable, AND each declared server is actually registered
   with Claude Code (marketplace install does this for you; dev installs
   need `bash dev/wire-mcps.sh`):
   ```bash
   ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/Workspace/claude-skill}"
   unregistered=0
   jq -r '.mcpServers // {} | to_entries[] | "\(.key)\t\(.value.command)\t\((.value.args // []) | join(" "))"' \
     "$ROOT/.claude-plugin/plugin.json" \
     | while IFS=$'\t' read -r name cmd args; do
         runnable="✗"; command -v "$cmd" >/dev/null 2>&1 && runnable="✓"
         registered="✗"
         if command -v claude >/dev/null 2>&1 && claude mcp get "$name" >/dev/null 2>&1; then
           registered="✓"
         fi
         echo "$runnable runnable, $registered registered — $name ($cmd $args)"
       done
   # If any are runnable-but-unregistered, point at the dev wiring script.
   if command -v claude >/dev/null 2>&1; then
     missing=$(jq -r '.mcpServers // {} | keys[]' "$ROOT/.claude-plugin/plugin.json" \
       | while read -r n; do claude mcp get "$n" >/dev/null 2>&1 || echo "$n"; done)
     if [[ -n "$missing" ]]; then
       echo
       echo "⚠ declared MCPs not registered with Claude Code:"
       echo "$missing" | sed 's/^/    /'
       echo "  Fix (dev install): bash $ROOT/dev/wire-mcps.sh"
       echo "  Fix (marketplace install): /plugin reinstall pilot"
     fi
   fi
   ```
   Then check env vars that affect bundled servers:
   ```bash
   [[ -n "${CONTEXT7_API_KEY:-}" ]] && echo "✓ CONTEXT7_API_KEY set" || echo "○ CONTEXT7_API_KEY unset (context7 on free tier)"
   [[ -n "${PILOT_DISABLE_CONTEXT7:-}" ]] && echo "○ PILOT_DISABLE_CONTEXT7 set — docs-lookup disabled"
   ```

5. **Bypass state** — run:
   ```bash
   ls -la "${XDG_CACHE_HOME:-$HOME/.cache}/pilot" 2>/dev/null \
     || echo '(no bypass markers — gates active)'
   ```

6. **Summary** — one-line green/yellow/red verdict:
   - **Green** if all hooks executable, wired in settings.json, required tools present, MCP commands runnable.
   - **Yellow** if tools OK but some hooks unwired, some recommended plugins missing, or an MCP command (e.g. npx) is missing.
   - **Red** if a required tool (jq, git, bash) is missing.

Be terse. Suggest the one fix that'd flip the verdict to green.

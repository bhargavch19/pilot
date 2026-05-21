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

4.5. **Skill availability matrix (per registry.md Primary column)** — walks
   every Primary skill listed in `registry.md` and checks whether it's
   actually installed. Catches "primary skill missing → silent fallback"
   routing surprises:
   ```bash
   ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/Workspace/claude-skill}"
   REG="$ROOT/skills/pilot/registry.md"
   [[ -f "$REG" ]] || { echo "(registry.md not found at $REG)"; }

   # Extract the FIRST backticked identifier per phase-table row (the actual
   # Primary skill). Avoids capturing MCP tool-name fragments described later
   # in the same cell.
   primary_skills=$(awk -F'|' '
     /^\| [0-9]|^\| Meta\.|^\| Docs lookup|^\| UI verify|^\| GitHub ops/ {
       primary = $4
       if (match(primary, /`[a-zA-Z][a-zA-Z0-9_:-]*`/)) {
         print substr(primary, RSTART+1, RLENGTH-2)
       }
     }
   ' "$REG" | sort -u)

   missing_count=0
   echo "Skill availability (Primary column of registry.md):"
   while IFS= read -r skill; do
     [[ -z "$skill" ]] && continue

     # MCPs surface separately in section 4 — skip here.
     case "$skill" in
       context7|playwright|github) continue ;;
     esac

     # Claude Code ships several skills as built-ins (not on disk). Don't
     # flag these as missing — pilot-doctor can't see them via file probes.
     case "$skill" in
       init|verify|run|simplify|review|security-review|claude-api|loop|schedule|fewer-permission-prompts|update-config|keybindings-help|find-skills|write-a-skill|git-guardrails-claude-code|to-prd|to-issues)
         printf "  • %-45s (built-in — file probe N/A)\n" "$skill"
         continue
         ;;
     esac

     found=""
     # 1. User-installed loose skill
     if [[ -f "$HOME/.claude/skills/$skill/SKILL.md" ]]; then
       found="user-installed"
     # 2. Plugin-bundled by exact name
     elif find "$HOME/.claude/plugins/cache" -maxdepth 6 -type f \
            -path "*/skills/$skill/SKILL.md" 2>/dev/null | head -1 | grep -q .; then
       found="plugin-bundled"
     # 3. Namespaced (e.g., superpowers:writing-plans) — try unprefixed
     elif [[ "$skill" == *":"* ]]; then
       bare="${skill#*:}"
       if find "$HOME/.claude/plugins/cache" -maxdepth 6 -type f \
              -path "*/skills/$bare/SKILL.md" 2>/dev/null | head -1 | grep -q .; then
         found="plugin-bundled (namespaced)"
       fi
     fi

     if [[ -n "$found" ]]; then
       printf "  ✓ %-45s (%s)\n" "$skill" "$found"
     else
       printf "  ✗ %-45s (missing — pilot will use fallback if registered)\n" "$skill"
       missing_count=$((missing_count + 1))
     fi
   done <<< "$primary_skills"

   if (( missing_count > 0 )); then
     echo
     echo "⚠ $missing_count primary skill(s) missing on disk. Pilot routes via"
     echo "  fallbacks if registered. Install the missing primaries to enable"
     echo "  preferred routing. Common cause for pilot-bundled scaffolds:"
     echo "  re-run \`bash dev/symlink-pilot.sh\` after a v0.7+ pull (the"
     echo "  symlink script was updated to include scaffold skills)."
   fi
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

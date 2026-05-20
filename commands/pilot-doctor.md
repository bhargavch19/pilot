---
description: Diagnose pilot installation — prereqs, hook paths, jq, symlink, settings.json wiring.
allowed-tools: Bash
---

Run a top-to-bottom pilot health check. Steps:

1. **Prereq table** — run `bash ${CLAUDE_PLUGIN_ROOT:-$HOME/Workspace/claude-skill}/dev/check-prereqs.sh`.

2. **Hook scripts executable + present** — run:
   ```bash
   ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/Workspace/claude-skill}"
   for h in plan-gate.sh pre-commit.sh verify-gate.sh sessionstart-banner.sh; do
     if [[ -x "$ROOT/hooks/$h" ]]; then
       echo "✓ $h"
     elif [[ -f "$ROOT/hooks/$h" ]]; then
       echo "○ $h (present but not executable — chmod +x needed)"
     else
       echo "✗ $h (missing)"
     fi
   done
   ```

3. **settings.json wiring** — run:
   ```bash
   jq -r '
     .hooks // {}
     | to_entries[]
     | .key as $k
     | .value[]?
     | .hooks[]?
     | "\($k): \(.command)"
   ' "$HOME/.claude/settings.json" 2>/dev/null | grep -E '(plan-gate|pre-commit|verify-gate|sessionstart-banner)\.sh' \
     || echo '(no pilot hooks wired — run dev/wire-hooks.sh or install via marketplace)'
   ```

4. **Bypass state** — run:
   ```bash
   ls -la "${XDG_CACHE_HOME:-$HOME/.cache}/pilot" 2>/dev/null \
     || echo '(no bypass markers — gates active)'
   ```

5. **Summary** — one-line green/yellow/red verdict:
   - **Green** if all four hooks executable, wired in settings.json, and required tools present.
   - **Yellow** if tools OK but some hooks unwired or some recommended plugins missing.
   - **Red** if a required tool (jq, git, bash) is missing.

Be terse. Suggest the one fix that'd flip the verdict to green.

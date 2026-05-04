#!/usr/bin/env bash
# Emits the pilot active banner at SessionStart.
# Output goes into the assistant's context as system-reminder additional context.
cat <<'EOF'
[pilot active] phase routing on. registry: ~/.claude/skills/pilot/registry.md.
bypass: "pilot off" (one turn) | "pilot off rails" (session) | "pilot back on" (resume).
EOF

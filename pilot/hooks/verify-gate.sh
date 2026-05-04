#!/usr/bin/env bash
# G14 soft enforcement: warn if assistant claims done without test output evidence.
# Runs on Stop hook. Reads transcript JSON from stdin. Never blocks (warning only).
set -euo pipefail

INPUT=$(cat)

# Concatenate last 5 assistant messages.
LAST=$(echo "$INPUT" | jq -r '[.transcript[]? | select(.role=="assistant") | .content] | .[-5:] | join("\n")' 2>/dev/null || echo "")

if [[ -z "$LAST" ]]; then exit 0; fi

# Detect "done" claim.
if ! echo "$LAST" | grep -iqE '\b(done|complete|completed|ready|fixed|passing)\b'; then
  exit 0
fi

# Look for evidence: test command + result token.
if echo "$LAST" | grep -qE '(pytest|npm test|bun test|cargo test|go test|jest)' && \
   echo "$LAST" | grep -qE '(passed|PASS|ok|OK|✓)'; then
  exit 0
fi

echo "verify-gate: G14 — claim of 'done' without test output evidence. Run the suite or invoke verification-before-completion." >&2
exit 0  # warning, don't block

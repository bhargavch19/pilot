#!/usr/bin/env bash
# Test verify-gate.sh: warns when assistant claims "done" without test output evidence.
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/pilot/hooks/verify-gate.sh"

# Case 1: claim of done WITH test output → no warning (exit 0, no stderr).
INPUT='{"transcript":[{"role":"assistant","content":"I ran pytest and it passed: 12 passed in 0.5s. Done."}]}'
OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
if [[ "$OUT" == *"verify-gate"* ]]; then
  echo "FAIL: false positive on done with evidence"
  exit 1
fi
echo "PASS: done with evidence not flagged"

# Case 2: claim of done WITHOUT test output → warning on stderr.
INPUT='{"transcript":[{"role":"assistant","content":"All done. Ready to ship."}]}'
OUT=$(echo "$INPUT" | "$HOOK" 2>&1 || true)
if [[ "$OUT" != *"verify-gate"* ]]; then
  echo "FAIL: missed claim of done without evidence"
  exit 1
fi
echo "PASS: bare done flagged"

# Case 3: no claim → no warning.
INPUT='{"transcript":[{"role":"assistant","content":"Working on it."}]}'
OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
if [[ "$OUT" == *"verify-gate"* ]]; then
  echo "FAIL: false positive on neutral message"
  exit 1
fi
echo "PASS: neutral not flagged"

echo "ALL verify-gate tests passed."

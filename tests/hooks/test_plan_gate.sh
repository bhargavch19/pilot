#!/usr/bin/env bash
# Test plan-gate.sh: blocks edits >20 LOC unless plan exists in last 24h.
set -euo pipefail

HOOK="$(dirname "$0")/../../pilot/hooks/plan-gate.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Case 1: small change (<=20 LOC, 1 file) → allow.
input='{"tool":"Edit","input":{"file_path":"a.ts","new_string":"x"}}'
echo "$input" | "$HOOK" >/dev/null
echo "PASS: small change allowed"

# Case 2: large change (>20 LOC), no plan → block (exit 1).
# Run in $TMP so the repo's own plans/ doesn't satisfy the gate.
big=$(printf 'line\n%.0s' {1..25})
input=$(jq -n --arg s "$big" '{tool:"Edit",input:{file_path:"a.ts",new_string:$s}}')
if ( cd "$TMP" && echo "$input" | "$HOOK" >/dev/null 2>&1 ); then
  echo "FAIL: large change should have been blocked"
  exit 1
fi
echo "PASS: large change blocked when no plan"

# Case 3: large change with recent plan → allow.
mkdir -p "$TMP/docs/superpowers/plans"
touch "$TMP/docs/superpowers/plans/some-plan.md"
( cd "$TMP" && echo "$input" | "$HOOK" >/dev/null )
echo "PASS: large change allowed with recent plan"

echo "ALL plan-gate tests passed."

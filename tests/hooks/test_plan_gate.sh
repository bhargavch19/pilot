#!/usr/bin/env bash
# Test plan-gate.sh: blocks edits >20 LOC unless plan exists in last 24h.
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/pilot/hooks/plan-gate.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Case 1: small change (<=20 LOC, 1 file) → allow.
input='{"tool":"Edit","input":{"file_path":"a.ts","new_string":"x"}}'
echo "$input" | "$HOOK" >/dev/null
echo "PASS: small change allowed"

# Case 2: large change (>20 LOC), no plan → block (exit 1) with G1 message.
big=$(printf 'line\n%.0s' {1..25})
input=$(jq -n --arg s "$big" '{tool:"Edit",input:{file_path:"a.ts",new_string:$s}}')
set +e
err=$(cd "$TMP" && echo "$input" | "$HOOK" 2>&1 >/dev/null)
rc=$?
set -e
if [[ "$rc" -ne 1 ]]; then
  echo "FAIL: large change should exit 1, got $rc"
  exit 1
fi
if ! echo "$err" | grep -q 'plan-gate: G1'; then
  echo "FAIL: stderr missing G1 message: $err"
  exit 1
fi
echo "PASS: large change blocked with G1 message"

# Case 3: large change with recent plan → allow.
mkdir -p "$TMP/docs/superpowers/plans"
touch "$TMP/docs/superpowers/plans/some-plan.md"
( cd "$TMP" && echo "$input" | "$HOOK" >/dev/null )
echo "PASS: large change allowed with recent plan"

echo "ALL plan-gate tests passed."

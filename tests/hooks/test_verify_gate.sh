#!/usr/bin/env bash
# Test verify-gate.sh: warns when assistant claims "done" without test
# output evidence. Uses both the inline-transcript fallback (old fixtures)
# and the real transcript_path JSONL format.
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/verify-gate.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
cd "$TMP"

# ---- inline-transcript fallback (legacy fixture format) -----------------

# Case 1: claim of done WITH test output → no warning.
INPUT='{"transcript":[{"role":"assistant","content":"I ran pytest and it passed: 12 passed in 0.5s. Done."}]}'
OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
if [[ "$OUT" == *"verify-gate"* ]]; then
  echo "FAIL: false positive on done with evidence"
  exit 1
fi
echo "PASS: done with evidence not flagged (inline)"

# Case 2: claim of done WITHOUT test output → warning.
INPUT='{"transcript":[{"role":"assistant","content":"All done. Ready to ship."}]}'
OUT=$(echo "$INPUT" | "$HOOK" 2>&1 || true)
if [[ "$OUT" != *"verify-gate"* ]]; then
  echo "FAIL: missed claim of done without evidence"
  exit 1
fi
echo "PASS: bare done flagged (inline)"

# Case 3: no claim → no warning.
INPUT='{"transcript":[{"role":"assistant","content":"Working on it."}]}'
OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
if [[ "$OUT" == *"verify-gate"* ]]; then
  echo "FAIL: false positive on neutral message"
  exit 1
fi
echo "PASS: neutral not flagged (inline)"

# ---- transcript_path (real Claude Code format) --------------------------

mk_transcript() {
  # $1 = assistant text content
  local f="$TMP/transcript.jsonl"
  : > "$f"
  jq -n --arg t "$1" '{
    type:"assistant",
    message:{role:"assistant", content:[{type:"text", text:$t}]}
  }' >> "$f"
  printf '%s' "$f"
}

mk_input() {
  jq -n --arg p "$1" '{transcript_path:$p, stop_hook_active:true}'
}

# Case 4: real transcript with done + bun test evidence → allow.
t=$(mk_transcript "Ran bun test — 42 passed. Done.")
OUT=$(mk_input "$t" | "$HOOK" 2>&1)
if [[ "$OUT" == *"verify-gate"* ]]; then
  echo "FAIL: bun test evidence not recognised"
  exit 1
fi
echo "PASS: bun test evidence allowed (transcript_path)"

# Case 5: real transcript with done + vitest evidence → allow.
t=$(mk_transcript "vitest passed all tests, ready to merge.")
OUT=$(mk_input "$t" | "$HOOK" 2>&1)
[[ "$OUT" != *"verify-gate"* ]] || { echo "FAIL: vitest not recognised"; exit 1; }
echo "PASS: vitest evidence allowed"

# Case 6: nx test evidence → allow.
t=$(mk_transcript "nx test ran — All tests passed. Done.")
OUT=$(mk_input "$t" | "$HOOK" 2>&1)
[[ "$OUT" != *"verify-gate"* ]] || { echo "FAIL: nx test not recognised"; exit 1; }
echo "PASS: nx test evidence allowed"

# Case 7: make test evidence → allow.
t=$(mk_transcript "make test — 0 failed, 0 errors. Complete.")
OUT=$(mk_input "$t" | "$HOOK" 2>&1)
[[ "$OUT" != *"verify-gate"* ]] || { echo "FAIL: make test not recognised"; exit 1; }
echo "PASS: make test evidence allowed"

# Case 8: per-repo .pilot.yml extends runners.
cat > .pilot.yml <<'EOF'
test_patterns:
  - 'my-runner'
EOF
t=$(mk_transcript "my-runner finished — all passed. Done.")
OUT=$(mk_input "$t" | "$HOOK" 2>&1)
[[ "$OUT" != *"verify-gate"* ]] || { echo "FAIL: .pilot.yml extra pattern not picked up"; exit 1; }
echo "PASS: .pilot.yml extra runner allowed"
rm -f .pilot.yml

# Case 9: per-repo .pilot.json extends runners.
echo '{"test_patterns":["another-runner"]}' > .pilot.json
t=$(mk_transcript "another-runner — 12 passed. Done.")
OUT=$(mk_input "$t" | "$HOOK" 2>&1)
[[ "$OUT" != *"verify-gate"* ]] || { echo "FAIL: .pilot.json extra pattern not picked up"; exit 1; }
echo "PASS: .pilot.json extra runner allowed"
rm -f .pilot.json

# Case 10: bare done in real transcript → warning.
t=$(mk_transcript "All done. Shipping.")
OUT=$(mk_input "$t" | "$HOOK" 2>&1 || true)
[[ "$OUT" == *"verify-gate"* ]] || { echo "FAIL: bare done not flagged"; exit 1; }
echo "PASS: bare done flagged (transcript_path)"

echo "ALL verify-gate tests passed."

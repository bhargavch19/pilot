#!/usr/bin/env bash
# Run all hook + dev integration tests.
set -euo pipefail
cd "$(dirname "$0")"
fail=0
for d in hooks dev; do
  [[ -d "$d" ]] || continue
  for t in "$d"/test_*.sh; do
    [[ -f "$t" ]] || continue
    echo "=== $t ==="
    if ! bash "$t"; then
      fail=$((fail + 1))
      echo "--- $t FAILED ---"
    fi
  done
done
echo ""
echo "=== Dogfood prompts (manual) ==="
echo "See dogfood/sample_prompts.md and run them in a Claude Code session."
exit "$fail"

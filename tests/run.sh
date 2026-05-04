#!/usr/bin/env bash
# Run all hook tests.
set -euo pipefail
cd "$(dirname "$0")"
for t in hooks/test_*.sh; do
  echo "=== $t ==="
  bash "$t"
done
echo ""
echo "=== Dogfood prompts (manual) ==="
echo "See dogfood/sample_prompts.md and run them in a Claude Code session."

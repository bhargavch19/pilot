#!/usr/bin/env bash
# Test pre-commit.sh: blocks WIP, console.log, sleep() in tests, `: any` without comment.
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/pilot/hooks/pre-commit.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
cd "$TMP"
git init -q
git config user.email t@t.t
git config user.name t

# Case 1: clean code, conventional msg → allow.
echo "export const x = 1" > a.ts
git add a.ts
git commit -q -m "feat: add x"
git mv a.ts b.ts
"$HOOK" "feat: rename" >/dev/null
echo "PASS: clean code allowed"

# Case 2: WIP message → block.
if "$HOOK" "WIP: stuff" >/dev/null 2>&1; then
  echo "FAIL: WIP not blocked"
  exit 1
fi
echo "PASS: WIP blocked"

# Case 3: console.log in staged TS → block.
echo "console.log('x')" > c.ts
git add c.ts
if "$HOOK" "feat: c" >/dev/null 2>&1; then
  echo "FAIL: console.log not blocked"
  exit 1
fi
git reset c.ts >/dev/null
rm c.ts
echo "PASS: console.log blocked"

# Case 4: `: any` without comment → block.
echo "const x: any = 1" > d.ts
git add d.ts
if "$HOOK" "feat: d" >/dev/null 2>&1; then
  echo "FAIL: bare any not blocked"
  exit 1
fi
git reset d.ts >/dev/null
rm d.ts
echo "PASS: bare any blocked"

# Case 5: `: any` WITH comment → allow.
echo "const x: any = 1 // any: legacy lib" > e.ts
git add e.ts
"$HOOK" "feat: e" >/dev/null
echo "PASS: documented any allowed"

# Case 6: sleep() in test file → block.
mkdir -p tests
echo "test('x', () => sleep(100))" > tests/foo.test.ts
git add tests/foo.test.ts
if "$HOOK" "test: foo" >/dev/null 2>&1; then
  echo "FAIL: sleep in test not blocked"
  exit 1
fi
echo "PASS: sleep in test blocked"

echo "ALL pre-commit tests passed."

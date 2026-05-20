#!/usr/bin/env bash
# Pre-commit gate: G3 (conventional msg, no WIP), G7 (`any` w/ comment), G8 (no console.log), G12 (no sleep in tests).
set -euo pipefail

MSG="${1:-}"

# G3: conventional commit prefix + no WIP.
if [[ "$MSG" =~ ^WIP ]] || [[ "$MSG" =~ WIP$ ]]; then
  echo "pre-commit: G3 — WIP commits forbidden. Squash or rewrite." >&2
  exit 1
fi
if ! [[ "$MSG" =~ ^(feat|fix|chore|docs|refactor|test|style|perf|build|ci|revert)(\(.+\))?:\  ]]; then
  if [[ -n "$MSG" ]]; then
    echo "pre-commit: G3 — message must start with conventional prefix (feat:, fix:, chore:, etc.)." >&2
    exit 1
  fi
fi

# Get staged files.
STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

# G8: no console.log in staged TS/JS/TSX/JSX.
for f in $STAGED; do
  case "$f" in
    *.ts|*.tsx|*.js|*.jsx)
      if git show ":$f" 2>/dev/null | grep -nE '(^|[^.])console\.log\(' >/dev/null; then
        echo "pre-commit: G8 — console.log in $f. Remove or use a logger." >&2
        exit 1
      fi
      ;;
  esac
done

# G7: `: any` requires `any:` comment on same line.
for f in $STAGED; do
  case "$f" in
    *.ts|*.tsx)
      while IFS= read -r line; do
        if [[ "$line" =~ :\ *any([^a-zA-Z]|$) ]] && ! [[ "$line" =~ //.*any: ]]; then
          echo "pre-commit: G7 — bare \`: any\` in $f. Add explanatory \`// any: <reason>\` comment." >&2
          echo "  $line" >&2
          exit 1
        fi
      done < <(git show ":$f" 2>/dev/null || true)
      ;;
  esac
done

# G12: no `sleep(` or `setTimeout(` in staged test files.
for f in $STAGED; do
  case "$f" in
    *test*|*spec*)
      if git show ":$f" 2>/dev/null | grep -nE '(^|[^a-zA-Z_])(sleep|setTimeout)\(' >/dev/null; then
        echo "pre-commit: G12 — sleep/setTimeout in test $f. Fix root cause, don't paper over flakes." >&2
        exit 1
      fi
      ;;
  esac
done

exit 0

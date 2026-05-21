#!/usr/bin/env bash
# G14 soft enforcement: warn when the assistant claims work is "done" /
# "ready" / "passing" without visible test-suite evidence in the transcript.
# Runs on Stop and SubagentStop. Never blocks (warning only — exit 0).
#
# Per-repo overrides: add `.pilot.json` at the repo root with extra
# runner regexes:
#   { "test_patterns": ["rake test", "my-custom-runner"] }
set -euo pipefail

INPUT=$(cat)

if [[ -z "$INPUT" ]] || ! printf '%s' "$INPUT" | jq empty 2>/dev/null; then
  echo "verify-gate: stdin missing or not valid JSON — gate declining to enforce." >&2
  exit 0
fi

# Stop hook input includes transcript_path; the JSONL file holds the
# message history. Older inline `.transcript[]` payloads are supported
# as a fallback so existing fixtures keep working.
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)

if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  LAST=$(jq -r '
    select(.type=="assistant")
    | (.message.content // [])
    | if type=="array" then (map(select(.type=="text") | .text) | join("\n"))
      else (. | tostring) end
  ' "$TRANSCRIPT" 2>/dev/null | tail -200 || true)

  # Schema-drift detection: transcript exists and is non-empty, but our jq
  # expression yielded nothing. Either Claude Code's JSONL schema changed or
  # this turn was tool-only (no text). The second case is benign; the first
  # is silent rot. Surface a diagnostic so failures are visible early.
  if [[ -z "$LAST" ]]; then
    TRANSCRIPT_LINES=$(wc -l < "$TRANSCRIPT" 2>/dev/null || echo 0)
    if (( TRANSCRIPT_LINES > 0 )); then
      # Re-try with a permissive fallback: grab any `text` field anywhere in
      # the last 50 lines. Catches schema variants where .message.content
      # was renamed (e.g., to .content or .delta.text).
      LAST=$(tail -50 "$TRANSCRIPT" 2>/dev/null \
        | jq -r '[.. | objects | .text? // empty] | join("\n")' 2>/dev/null \
        | tail -200 || true)

      if [[ -z "$LAST" ]]; then
        echo "verify-gate: transcript has $TRANSCRIPT_LINES lines but yielded no text — schema may have changed; gate inactive this turn." >&2
        exit 0
      fi
    fi
  fi
else
  LAST=$(echo "$INPUT" | jq -r '[.transcript[]? | select(.role=="assistant") | .content] | .[-5:] | join("\n")' 2>/dev/null || true)
fi

[[ -n "$LAST" ]] || exit 0

# Detect a "done" claim.
if ! echo "$LAST" | grep -iqE '\b(done|complete|completed|ready|fixed|passing|all green)\b'; then
  exit 0
fi

# Built-in test runners. Conservative regex: bare command followed by space
# or end-of-line to avoid matching `make test-fixtures` etc.
DEFAULT_RUNNERS='(pytest|npm test|npm run test|bun( run)? test|pnpm( run)? test|yarn( run)? test|cargo test|cargo nextest|go test|jest|vitest|nx test|mocha|tap|make test|gradle test|mvn test|sbt test|cabal test|stack test|dotnet test|phpunit|rspec|elixir test|mix test|node --test(-only)?)\b'

# Per-repo runner extensions via .pilot.json. (YAML support dropped in 0.3.0:
# the awk-based parser couldn't handle quoted values, multi-key files, or
# indented blocks reliably. Use jq + JSON.)
EXTRA_PATTERNS=""
if [[ -f .pilot.json ]]; then
  EXTRA_PATTERNS=$(jq -r '.test_patterns[]? // empty' .pilot.json 2>/dev/null | paste -sd'|' - 2>/dev/null || true)
fi

if [[ -n "$EXTRA_PATTERNS" ]]; then
  # Strip the leading `(` and trailing `)\b` from DEFAULT_RUNNERS, then union.
  CORE=${DEFAULT_RUNNERS#(}
  CORE=${CORE%)\\b}
  RUNNERS="(${CORE}|${EXTRA_PATTERNS})\b"
else
  RUNNERS="$DEFAULT_RUNNERS"
fi

RESULTS='(passed|PASS|✓|✔|All tests pass|tests passed|0 failed|0 failures|0 errors|ok [0-9]+|OK \(|pass [0-9]+|fail 0)'

if echo "$LAST" | grep -qE "$RUNNERS" && echo "$LAST" | grep -qE "$RESULTS"; then
  exit 0
fi

cat <<EOF >&2
verify-gate: G14 — "done" / "ready" claim without test-suite evidence.

Run the project's tests and quote the result, or invoke
superpowers:verification-before-completion before claiming complete.

Configured runners: built-ins + .pilot.yml/.pilot.json test_patterns.
EOF
exit 0

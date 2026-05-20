# Fix 4 pilot gaps + zsh footgun note

Discovered while dogfooding pilot on log-stat CLI build. All 4 hook gates
work; gaps are around test-runner coverage, telemetry, and dev-install MCP.

## Fix 1 — verify-gate misses `node --test`
- `hooks/verify-gate.sh:38` DEFAULT_RUNNERS regex lacks Node's built-in test runner.
- Add `node( --test| --test-only)?\b` to regex.
- Add test case to `tests/hooks/test_verify_gate.sh`.

## Fix 2 — routing telemetry never written
- SKILL.md tells the model to append to `~/.cache/pilot/routing.log` per route. Compliance gap.
- Replace with `hooks/log-skill-invocation.sh` (PostToolUse:Skill).
- Hook reads tool_input.skill, appends `ISO ts skill=<name>` line, caps at 500.
- Wire in `dev/wire-hooks.sh` + `dev/unwire-hooks.sh`.
- Remove model-driven block from SKILL.md.
- Document in `guardrails.md` (new row).
- Add test `tests/hooks/test_log_skill_invocation.sh`.

## Fix 3 — silent exit 0 on malformed JSON
- `plan-gate.sh`, `pre-commit.sh`, `verify-gate.sh` all use `jq ... 2>/dev/null || echo ""` → empty var → no-op.
- Add `jq empty` validation at top of each hook. On failure: stderr log "<hook>: stdin parse error — gate declining to enforce." + exit 0.
- Add test case to each hook's test script.

## Fix 4 — bundled MCPs not registered on dev-install
- `plugin.json` declares context7/playwright/github under mcpServers; dev-install (symlink + wire-hooks.sh) never propagates to Claude Code.
- Add `dev/wire-mcps.sh` using `claude mcp add` per declared server.
- Add `dev/unwire-mcps.sh` using `claude mcp remove`.
- Extend `pilot-doctor.md` step 4 to detect "declared but not registered" and print the fix command.
- Add note to `prereqs.md` for dev installers.

## Fix 5 (misc) — zsh echo footgun
- `tests/README.md` (NEW): one-liner "use `printf '%s'` not `echo` when piping JSON to hooks from zsh".

## Commit order
1. `fix(verify-gate): recognize node --test as a test runner`
2. `feat(hooks): log-skill-invocation routing telemetry`
3. `fix(hooks): exit cleanly on malformed JSON stdin`
4. `feat(dev): wire-mcps.sh + doctor MCP gap detection`
5. `docs: zsh echo footgun note for hook test invocation`

Each commit: code change + matching test update where applicable. Run `tests/run.sh` after each commit; gate everything on the suite staying green.

## Alternative considered
Auto-wiring MCPs via jq-edits to `~/.claude/settings.json` (mirror wire-hooks.sh). Rejected: `claude mcp add` is the documented public API and survives Claude Code config schema changes. Settings.json direct edit is brittle.

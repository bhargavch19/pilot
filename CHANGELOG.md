# Changelog

All notable changes to the `pilot` plugin are documented here. Format roughly
follows [Keep a Changelog](https://keepachangelog.com/); versions follow
[Semantic Versioning](https://semver.org/) once 1.0 ships.

## [0.5.1] — 2026-05-20

Patch follow-up on 0.5.0 — closes the open audit findings on the
context7 bundling and a couple of older deferred items.

### Fixed
- **Dropped ambiguous `${CONTEXT7_API_KEY:-}` env block.** Bash-style
  defaults aren't part of Claude Code's plugin-manifest interpolator
  (other working plugins don't pass user env vars via the manifest at
  all). MCP servers now inherit Claude Code's process env; users
  `export` keys in their shell before launching.
- **Pinned `@upstash/context7-mcp@2.2.5`.** Was resolving to *latest*
  on every npx invocation — any future major release would land
  unannounced. Manual bumps from here on.
- **`dev/dry-run.sh` cleanup fixed.** The MultiEdit-with-plan scenario
  used `git rm + git commit --amend --no-edit -m "..."` (contradictory
  flags, didn't actually undo the `.planning` commit). Replaced with
  `git reset --hard HEAD~1`.

### Added
- **`PILOT_DISABLE_CONTEXT7` opt-out.** Set the env var to any
  non-empty value and pilot's SKILL.md tells Claude to skip the
  docs-lookup phase entirely (for restricted-network setups).
- **`routing.log` cap at 500 lines.** Telemetry instruction in
  SKILL.md now tails the log when it grows past 500 entries.
- **`/pilot-doctor` checks MCP server health.** New section reads
  `mcpServers` from plugin.json, verifies each command is on PATH,
  reports `CONTEXT7_API_KEY` + `PILOT_DISABLE_CONTEXT7` state. Also
  picks up `precompact-anchor.sh` in the hook checks (was missed).
- **CI validates `mcpServers` shape.** plugin-manifest job now jq-
  asserts every server has a string command and well-formed args.
- **`web/index.html` updated for v0.5.1 + context7.** New scene 05
  walks through the resolve-library-id → get-library-docs flow.
  "Five hooks" copy bumped to "six" (PreCompact was missed in 0.4.0).

## [0.5.0] — 2026-05-20

First bundled MCP server. Pilot now ships with `context7` so Claude can
fetch current library docs on demand without extra setup.

### Added
- **`context7` MCP server bundled.** `plugin.json` declares
  `mcpServers.context7` pointing at `@upstash/context7-mcp` via `npx`,
  so installing pilot auto-starts the server. Two tools become available:
  `mcp__context7__resolve-library-id` and
  `mcp__context7__get-library-docs`. Free tier works without an API key;
  set `CONTEXT7_API_KEY` for higher rate limits.
- **Registry entry for docs lookup.** `skills/pilot/registry.md` gains a
  "Docs lookup" row routed to context7, plus an always-on layer bullet.
  Triggers: library + version names, "use latest docs", "context7", or
  any phase where the agent is about to touch an unfamiliar API.
- **SKILL.md routing guidance for context7.** Tells Claude to invoke
  context7 *proactively* in Plan/Build/Debug phases, mention once that
  it's pulling fresh docs, and skip when the disruption cost is high.
- **prereqs.md "Bundled MCP servers" section.** Documents context7
  + API key + the new soft `node`/`npx` requirement.
- **`dev/check-prereqs.sh`** checks `npx` and reports
  `CONTEXT7_API_KEY` presence.

### Changed
- README install paragraph now mentions PreCompact (was missed in 0.4.0)
  and the bundled context7 MCP.

## [0.4.0] — 2026-05-20

Resolves the four items deferred from the 0.3.0 audit pass: bypass
semantics, compaction survival, real-payload verification, and the
publishing placeholder.

### Added
- **PreCompact anchor hook.** `hooks/precompact-anchor.sh` fires on
  context compaction and prints routing rules, active guardrails,
  current bypass state, and the last 5 routing log entries. The
  output is injected as system-reminder text into the post-compact
  context, so pilot's routing logic survives `/compact` and
  auto-compaction. Wired in plugin.json + dev/wire-hooks.sh.
- **Per-gate bypass markers.** `bypass-precommit-once` (mirrors the
  existing `bypass-no-plan-once`) lets `/pilot-bypass --no-precommit`
  skip exactly one pre-commit fire without disturbing a concurrent
  `/pilot-off` aimed at the next plan-gate. Each hook now consumes
  its own marker before the shared `bypass-once`.
- **`/pilot-bypass --no-precommit`** slash command flag.
- **`dev/dry-run.sh`** — end-to-end simulation that stands up a
  throwaway repo + cache dir, feeds each hook the documented Claude
  Code payload shape, and verifies the expected decision. 17
  scenarios. Wired into CI right after `tests/run.sh`.
- **`dev/finalize-readme.sh`** — substitutes the `<github-user>`
  placeholder in the README. Uses `gh api user --jq .login` when
  authed, or accepts the handle as an argument.

### Changed
- guardrails.md bypass table now lists both `--no-plan` and
  `--no-precommit`, and explains the per-gate-before-shared
  consumption order.

## [0.3.0] — 2026-05-20

Second audit pass. Closes the gaps the first cleanup missed: matcher
coverage, distribution polish, and onboarding signals.

### Added
- **MultiEdit + NotebookEdit gating.** plan-gate matcher is now
  `Edit|Write|MultiEdit|NotebookEdit`. plan-gate sums all
  `edits[].new_string` lines for MultiEdit and reads `new_source`
  for NotebookEdit.
- **SubagentStop hook.** verify-gate now runs on both `Stop` and
  `SubagentStop`, so long-running subagents claiming "done" without
  test evidence get the same nudge.
- **First-run welcome.** SessionStart banner appends
  "first run — try /pilot-doctor" on the first install, self-dismisses.
- **Upgrade notification.** Banner detects a version transition
  (stored in `${XDG_CACHE_HOME:-~/.cache}/pilot/last-version`) and
  shows a one-line CHANGELOG pointer.
- **Routing telemetry.** SKILL.md instructs Claude to append one
  terse line per routing decision to
  `${XDG_CACHE_HOME:-~/.cache}/pilot/routing.log`. `/pilot-status`
  tails the last 10 entries.
- **CI.** `.github/workflows/test.yml` runs hook tests on
  ubuntu-latest + macos-latest, shellcheck on `hooks/` and `dev/`,
  and JSON validation on plugin manifests.
- **LICENSE.** MIT.

### Fixed
- **HEREDOC false positive** in pre-commit. `<<<stuff` was tripping
  the heredoc-bypass detector via overlapping substring match.
  Tightened regex to require leading boundary + identifier follow.
- **Escaped-quote handling** in pre-commit. `-m "foo \\"bar\\""` made
  sed truncate the message; G3 was applied to a bogus prefix. Now
  the hook detects `\\"` and skips G3 (file checks still run).
- **Substring-match bypass** in plan-gate / pre-commit phrase
  detection. `"shutdownpilot off"` should never trip bypass —
  added `(^|[[:space:]]|[[:punct:]])` leading anchor on every
  `pilot off / pilot --no-plan / pilot back on` grep.
- **TTY-escape-code leak** in check-prereqs. tput colors were set
  unconditionally; piped/captured output had raw ANSI codes. Guard
  on `[[ -t 1 ]]`.
- **PLUGINS_CACHE maxdepth** in check-prereqs. Hardcoded `-maxdepth 8`
  silently missed plugins that nest skills deeper. Removed limit.

### Changed
- **Dropped YAML config.** `.pilot.yml` support removed from
  verify-gate; the awk-based parser was fragile. `.pilot.json` is
  the only per-repo config surface now. Breaking change with zero
  external users (pre-1.0).
- plugin.json: added `license: "MIT"`, `skills: "./skills/"`, fixed
  author surname.
- Banner now reports active bypass state (one-shot armed vs session-active).

### Distribution
- `.gitignore` hardened for `settings.local.json`, `settings.json.bak.*`,
  and `.cache/pilot/`.
- README: dropped YAML config example; `.pilot.json` only.

## [0.2.0] — 2026-05-19

Audit-driven cleanup. The pre-1.0 release where every advertised behavior
is actually wired.

### Added
- Real Claude Code plugin layout: `.claude-plugin/plugin.json` declares all
  four hooks via `${CLAUDE_PLUGIN_ROOT}`, `.claude-plugin/marketplace.json`
  exposes pilot as a single-plugin marketplace. Install via
  `/plugin marketplace add <repo>` → `/plugin install pilot@pilot`.
- Slash commands: `/pilot-status`, `/pilot-off`, `/pilot-off-rails`,
  `/pilot-back-on`, `/pilot-bypass`, `/pilot-doctor`.
- Marker-file bypass under `${XDG_CACHE_HOME:-~/.cache}/pilot`:
  `bypass-once`, `bypass-no-plan-once`, `bypass-session`. Slash commands
  write them; hooks honor them.
- `dev/unwire-hooks.sh` — clean removal of pilot hook entries from
  `~/.claude/settings.json`. Idempotent. Backs up.
- `dev/check-prereqs.sh` and `prereqs.md` — surface what plugins/skills
  pilot would prefer routing into, with required/recommended/optional
  buckets.
- Pre-repo config for verify-gate runners via `.pilot.yml` /
  `.pilot.json` `test_patterns:` list.
- `tests/dev/test_wire_unwire.sh` — wire/unwire integration test that
  proves foreign hooks are preserved.

### Fixed
- **pre-commit was never wired.** It existed as a git-native script with a
  `MSG="$1"` signature but `wire-hooks.sh` never installed it, so G3 / G7
  / G8 / G12 were advertised but unenforced. Rewritten as a Claude Code
  `PreToolUse` hook on `Bash` matching `git commit`; now part of the
  default wired set.
- **plan-gate missed GSD plans.** Registry's resolution rule prefers GSD
  when `.planning/` exists, but plan-gate only ever looked in
  `docs/superpowers/plans/`. Now checks both, plus `.planning/**/SPEC.md`.
- **Documented bypasses weren't real.** `pilot --no-plan`, `pilot off`,
  `pilot off rails` are now actually parsed from the transcript and from
  marker files.
- **24-hour mtime freshness was arbitrary.** Replaced with a git-aware
  check: plan exists in working tree OR was modified in the current
  branch's commits since merge-base.
- **verify-gate runner regex too narrow.** Added bun/pnpm/yarn/nx/vitest
  /mocha/make/gradle/mvn/dotnet/rspec/mix. Result token list widened.
- **Hook paths were absolute and machine-bound.** Plugin install uses
  `${CLAUDE_PLUGIN_ROOT}`; dev install (via `wire-hooks.sh`) resolves
  paths from the script's own location.
- SessionStart banner now includes the plugin version and any active
  bypass marker.

### Changed
- Repo restructured: `pilot/` → `skills/pilot/`, hooks moved to top-level
  `hooks/`, commands added under `commands/`. Existing dev installs must
  rerun `bash dev/wire-hooks.sh` once.
- `tests/run.sh` now discovers tests in both `tests/hooks/` and
  `tests/dev/` and exits non-zero if any test fails (previously masked
  failures because the loop's `set -e` only catches the last test).

### Documentation
- `skills/pilot/guardrails.md` now reflects the actually-wired enforcement
  layer (no more pre-commit-hook lies).
- `skills/pilot/SKILL.md` adds a "Fallback when a routed skill is missing"
  section so Claude degrades gracefully instead of erroring.
- `README.md` rewritten for marketplace install as the primary path.

---

## Releasing a new version

1. Bump `version` in `.claude-plugin/plugin.json`.
2. Prepend a new `## [X.Y.Z] — YYYY-MM-DD` section to this file.
3. Run `bash tests/run.sh` — must be green.
4. Commit with `chore(release): vX.Y.Z`.
5. `git tag vX.Y.Z && git push --tags`.
6. (Optional, if installed) `/claude-mem:version-bump` automates
   plugin.json + CHANGELOG + tag + GitHub release in one step.

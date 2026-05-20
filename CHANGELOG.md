# Changelog

All notable changes to the `pilot` plugin are documented here. Format roughly
follows [Keep a Changelog](https://keepachangelog.com/); versions follow
[Semantic Versioning](https://semver.org/) once 1.0 ships.

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

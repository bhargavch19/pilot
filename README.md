# pilot

Unified AI coding conductor for Claude Code. Auto-routes the user's intent
to the right underlying skill (grill → plan → TDD → debug → verify → ship),
enforces a configurable set of CLAUDE.md quality gates via shell hooks, and
stays extensible through a one-line registry edit.

- **Repository structure:** Claude Code single-plugin marketplace
  (`.claude-plugin/marketplace.json` + `.claude-plugin/plugin.json` at root).
- **Skill source:** `skills/pilot/`
- **Hooks:** `hooks/{plan-gate,pre-commit,verify-gate,sessionstart-banner}.sh`
- **Slash commands:** `commands/pilot-{status,off,off-rails,back-on,bypass,doctor}.md`

See [`CHANGELOG.md`](./CHANGELOG.md) for what shipped in each version and
[`prereqs.md`](./prereqs.md) for what plugins/skills pilot prefers to route
into.

## Quick install (marketplace path — recommended)

> **Before publishing:** replace `<github-user>` below with your actual
> GitHub handle. Run `bash dev/finalize-readme.sh` to substitute it
> automatically (uses `gh api user` if you're authed, or pass it as an
> argument: `bash dev/finalize-readme.sh <handle>`). The repo must be
> pushed to a public (or accessible) GitHub URL — pilot is a
> single-plugin marketplace, so the repo IS the marketplace.

In Claude Code:

```
/plugin marketplace add <github-user>/pilot
/plugin install pilot@pilot
```

Restart Claude Code. All five hooks (PreToolUse on Edit/Write/MultiEdit/
NotebookEdit + Bash, Stop, SubagentStop, SessionStart) wire automatically
via the plugin manifest. The slash commands become available, and the
SessionStart banner shows the active version + a first-run hint pointing
at `/pilot-doctor`.

Verify with `/pilot-doctor` in any session.

## Dev install (symlink + live edit)

For hacking on pilot without going through marketplace publishing:

```bash
git clone https://github.com/<github-user>/pilot ~/Workspace/claude-skill
bash ~/Workspace/claude-skill/dev/symlink-pilot.sh    # ~/.claude/skills/pilot -> skills/pilot
bash ~/Workspace/claude-skill/dev/wire-hooks.sh        # write hook paths into ~/.claude/settings.json
# restart Claude Code
```

To remove:

```bash
bash ~/Workspace/claude-skill/dev/unwire-hooks.sh      # idempotent
rm ~/.claude/skills/pilot                              # only if you symlinked
```

## What pilot does

1. **Phase routing.** On any session start or new prompt, pilot reads
   `skills/pilot/registry.md`, scans the user message for trigger keywords,
   inspects project state (`.planning/`, `git status`, `git log`), and
   invokes the right underlying skill via the Skill tool.
2. **Quality gates.** Four hooks enforce CLAUDE.md-aligned rules — see
   `skills/pilot/guardrails.md` for the full mapping.
3. **Stay extensible.** Adding a new skill is a one-line append to
   `registry.md`. Adding a new guardrail is a hook script plus a test under
   `tests/hooks/`.

## Bypass

| When you want to… | Use |
|---|---|
| Skip the next gate fire | `/pilot-off` |
| Skip only plan-gate | `/pilot-bypass --no-plan` |
| Turn pilot off for the session | `/pilot-off-rails` |
| Turn pilot back on | `/pilot-back-on` |
| Diagnose what's wired and what isn't | `/pilot-doctor` |
| Quick wired-hooks view | `/pilot-status` |

Bypass also works via free-text phrases in the user message (`pilot off`,
`pilot off rails`, `pilot --no-plan`) — handy when typing in a deep
sub-conversation.

## Configuration

Per-repo runner extensions for `verify-gate.sh` via `.pilot.json` at the
repo root:

```json
{ "test_patterns": ["rake test", "my-custom-runner"] }
```

The patterns are regex strings; they're unioned with pilot's built-in
runner list (pytest, bun test, vitest, nx test, make test, ...).

## Tests

```bash
bash tests/run.sh    # unit-style fixture tests for every hook
bash dev/dry-run.sh  # end-to-end simulation with realistic Claude Code JSON
```

Plain bash + jq; no extra deps. CI runs both on ubuntu-latest and
macos-latest plus shellcheck on `hooks/` and `dev/`.

## Project context

- Design: `docs/superpowers/specs/2026-05-04-pilot-design.md`
- Plan: `docs/superpowers/plans/2026-05-04-pilot.md`

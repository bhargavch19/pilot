# Pilot prerequisites

Pilot itself only needs `jq` and `bash` (both ubiquitous). What it routes *to*
is a set of other Claude Code skills and plugins. None are strictly required —
pilot will fall back through the registry's `fallbacks` column — but a friend
running pilot on a fresh box gets the best experience by installing the
recommended set first.

Run `bash dev/check-prereqs.sh` (or `/pilot-doctor` from a Claude Code session)
to see what's installed and what's missing.

## Tools (must be on PATH)

| Tool | Why |
|---|---|
| `bash` ≥ 4 | All hooks. |
| `jq`        | Hook stdin/stdout parsing, settings.json merging. |
| `git`       | plan-gate uses `git merge-base` for plan-freshness checks. |
| `node` + `npx` | Pulls the bundled `context7` MCP server on first invocation. Soft prereq — pilot still loads without it; only the docs-lookup phase degrades. |

## Bundled MCP servers

Pilot's `plugin.json` declares one MCP server. Claude Code starts it
automatically on plugin install.

| Server | Purpose | API key |
|---|---|---|
| `context7` (`@upstash/context7-mcp`) | Up-to-date library docs (resolve-library-id + get-library-docs tools). Pilot routes here on any "use latest docs / how does X work in version Y" query. | Optional. `CONTEXT7_API_KEY` env var raises rate limits. |

## Skills / plugins

Pilot routes phase → primary skill, with fallbacks. Categories:

### Recommended (covers most phases)
| Plugin / skill | Covers phases |
|---|---|
| `superpowers` (official marketplace) | Plan, Build (TDD), Verify, Review, Brainstorming, Debug |
| `frontend-design` (official marketplace) | UI build |
| `claude-mem` | Recall (session start), Capture (post-ship) |

### Optional (sharper routing when present)
| Plugin / skill | Covers |
|---|---|
| `grill-me`, `grill-with-docs`, `to-prd`, `to-issues` | Frame (code & non-code) |
| `tdd` | Drop-in for Build (Pocock tracer-bullet TDD) |
| `diagnose` | Drop-in for Debug |
| `improve-codebase-architecture` | Refactor |
| `simplify` | Pre-PR cleanup pass |
| `skill-creator` | Meta: authoring/editing skills |
| `context-mode` | Token-budget hygiene on long outputs |

### GSD suite (only if you use it)
Pilot's registry has a `.planning/`-aware path that prefers GSD skills
(`gsd-spec-phase`, `gsd-plan-phase`, `gsd-execute-phase`, `gsd-debug`,
`gsd-ship`, ...) when `.planning/` exists in the cwd. Without GSD installed,
pilot routes through the superpowers / Pocock path instead.

## Editing the registry

When you install a new skill, append a row to `skills/pilot/registry.md`. No
code change needed — the registry is the single source of truth.

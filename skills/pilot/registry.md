# Pilot Registry

> The single source of truth pilot consults to route user intent → underlying skill.
> To add a new skill: append a row. No code change required.

## Literal-name routing wins (highest priority)

If the user's prompt literally contains a skill id from the **Primary** or **Fallbacks** column below — or one of the bundled MCP names (`context7`, `playwright`, `github`) — pilot routes to it **immediately**, without keyword scoring. Multi-mention prompts produce a sequenced chain of phases.

See `SKILL.md` → "Literal-name shortcut" for the exact rule (scanning conventions, namespace handling, edge cases). The phase table below applies only when no literal hit is found.

## Phase table

| Phase | Triggers | Primary skill | Fallbacks | Resolution rule |
|---|---|---|---|---|
| 0. Recall | session start; "where were we"; "did we already" | `claude-mem:mem-search` | `gsd-resume-work`, `claude-mem:learn-codebase` | always run on SessionStart; if mem-search returns nothing AND repo is unfamiliar (no prior `claude-mem` index), use `learn-codebase` to prime |
| 0.5 Triage | "triage"; "what to work on"; "incoming bugs"; "review the inbox"; "issue queue" | `triage` | `gsd-inbox` | fires before Frame when work source is an issue tracker / PR queue |
| 0.75 Bootstrap | "new project"; "init"; "fresh repo"; no CLAUDE.md present | `init` | `gsd-new-project`, `claude-mem:learn-codebase` | auto-fire when `[ ! -f CLAUDE.md ]` AND no `.planning/` directory AND no prior pilot routing in this repo |
| 1. Frame (non-code) | "idea"; "what if"; "explore"; "thinking about" | `grill-me` | `gsd-explore` | non-code keywords |
| 1. Frame (code) | "build"; "add"; "feature"; "change <thing>" | `grill-with-docs` → `to-prd` | `superpowers:brainstorming` → `gsd-spec-phase` | if `.planning/` exists, use GSD path |
| 2. Plan | post-frame; "plan this"; >1 file or >20 LOC | `superpowers:writing-plans` | `gsd-plan-phase`, `to-issues` | multi-session work → GSD; single-session → superpowers; tracer slicing → to-issues |
| 3. Build (logic) | post-plan; code work begins; "implement" | `tdd` | `superpowers:test-driven-development`, `gsd-execute-phase` | always TDD unless `--skip-tdd` |
| 3. Build (UI) | "UI"; "design"; "component"; "screen"; "page" | `frontend-design:frontend-design` | `gsd-sketch`, `gsd-ui-phase` | UI-specific keywords |
| 4. Debug | "bug"; "broken"; "throws"; "fails"; "regression" | `diagnose` | `superpowers:systematic-debugging`, `gsd-debug` | hypothesis-first non-skippable |
| 4.5 Performance | "slow"; "latency"; "perf"; "profile"; "benchmark"; "bottleneck"; "regression"; "p99" | `diagnose` | `superpowers:systematic-debugging` | reproduce-then-measure non-skippable; same primary as Debug but explicit phase keeps perf invariants visible |
| 5. Verify | claim of "done"; before commit/PR | `superpowers:verification-before-completion` | `gsd-verify-work`, `gsd-validate-phase` | mandatory before Review |
| 6. Review | pre-merge; "review this" | `superpowers:requesting-code-review` | `gsd-code-review`, `simplify` | mandatory before Ship |
| 6.5 Security | "security review"; "audit"; "OWASP"; "vulnerability"; "sanitize"; "injection"; diff touches auth/crypto/network paths | `security-review` | `gsd-secure-phase` | always before Ship if any sensitive-path change |
| 7. Refactor | "messy"; "hard to change"; "clean up" | `improve-codebase-architecture` | `claude-mem:pathfinder`, `zoom-out`, `gsd-map-codebase` | single-file deepening → improve-codebase-architecture; cross-system unification → pathfinder; scope to current task only |
| 7.5 Migration | "migration"; "schema change"; "upgrade dep"; "breaking change"; "lockfile bump" | `migration-safety` | `to-issues`, `diagnose` | required before Pre-deploy if `migrations/` or lockfile changed; produces `MIGRATION-SAFETY.md` |
| 7.75 Pre-deploy | "deploy"; "release"; "ship to prod"; "production"; "go live"; immediately before Ship on a release branch | `pre-deploy-checklist` | `superpowers:requesting-code-review` | fires automatically before Ship for production-targeted branches; produces `PRE-DEPLOY.md` |
| 8. Ship | "merge"; "PR"; "ship it" | `gsd-ship` | `superpowers:finishing-a-development-branch` | only after Verify + Review |
| 8.5 Post-deploy | "monitor"; "after deploy"; "did the deploy work"; "rollback"; "post-deploy"; "did anything break" | `post-deploy-monitor` | `diagnose` | fires after Ship completes; checks error rate + latency + logs; produces `POST-DEPLOY.md` |
| 9. Capture | post-ship; end of phase | _claude-mem plugin auto-hook (not skill-invokable)_ | `gsd-extract-learnings` | runs automatically |
| Meta. Skill authoring | "create skill"; "new skill"; "write a skill"; "edit skill" | `skill-creator:skill-creator` | `write-a-skill` (superpowers), `superpowers:writing-skills` | meta-tooling — runs outside phase loop |
| Docs lookup | "use latest docs"; "how does X work in vY.Z"; "context7"; library name + version | `context7` MCP (`mcp__context7__resolve-library-id` + `get-library-docs`) | training-data fallback (acknowledge cutoff) | invoke any time the agent is about to use an unfamiliar API or the user names a library + version |
| UI verify | UI tasks reaching Verify phase; "test in browser"; "does it actually work"; "screenshot the change" | `playwright` MCP (`mcp__playwright__browser_navigate`, `browser_snapshot`, `browser_click`, `browser_evaluate`, ...) | `run`, `superpowers:verification-before-completion` (test-runner only — no browser) | invoke proactively after Build (UI) completes, before claiming the change works |
| GitHub ops | "PR"; "CI status"; "review state"; "merge readiness"; "post comment"; "list issues" | `github` MCP (`mcp__github__list_pull_requests`, `get_pull_request`, `create_pull_request_review`, `create_issue_comment`, ...) | `gh` CLI via Bash | when Review/Ship phase needs real GitHub data instead of inferring from local git |

## Always-on layer

- `context-mode` — output discipline (large tool output → sandbox). No opt-in needed.
- `caveman` — communication style (terse, no filler). Active by default per Bhargav's CLAUDE.md.
- `context7` MCP — bundled with pilot. Use proactively whenever a Plan/Build/Debug phase touches a library the agent might be hazy on. Free tier works without an API key; set `CONTEXT7_API_KEY` for higher rate limits.
- `playwright` MCP — bundled with pilot. Use proactively in the Verify phase after any UI change. Drive the browser, snapshot, click through the new flow, then claim done with the evidence in the transcript.
- `github` MCP — bundled with pilot. Use in Review and Ship phases whenever you need real GitHub state (PR status, review approvals, CI checks, issue threads). Requires `GITHUB_TOKEN` in the shell env for writes; read-only public access works without one.

## Resolution priority (when multiple options apply)

1. If `.planning/` directory exists in cwd → prefer GSD variant.
2. Else if work is multi-session or multi-file → prefer GSD or superpowers.
3. Else → prefer Pocock (tracer-bullet, fastest).
4. Always: `context-mode` runs underneath.

## Extending

To add a new skill:
1. Append a row to the phase table above with: phase, triggers, primary, fallbacks, resolution rule.
2. If the skill needs a dedicated playbook, create `playbooks/<topic>.md` and reference it.
3. Reload: `claude --restart-skills` or new session.

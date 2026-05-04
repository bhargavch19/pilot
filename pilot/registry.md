# Pilot Registry

> The single source of truth pilot consults to route user intent → underlying skill.
> To add a new skill: append a row. No code change required.

## Phase table

| Phase | Triggers | Primary skill | Fallbacks | Resolution rule |
|---|---|---|---|---|
| 0. Recall | session start; "where were we"; "did we already" | `claude-mem:mem-search` | `gsd-resume-work` | always run on SessionStart |
| 1. Frame (non-code) | "idea"; "what if"; "explore"; "thinking about" | `grill-me` | `gsd-explore` | non-code keywords |
| 1. Frame (code) | "build"; "add"; "feature"; "change X"; "implement" | `grill-with-docs` → `to-prd` | `superpowers:brainstorming` → `gsd-spec-phase` | if `.planning/` exists, use GSD path |
| 2. Plan | post-frame; "plan this"; >1 file or >20 LOC | `superpowers:writing-plans` | `gsd-plan-phase`, `to-issues` | multi-session work → GSD; single-session → superpowers; tracer slicing → to-issues |
| 3. Build (logic) | post-plan; code work begins | `tdd` | `superpowers:test-driven-development`, `gsd-execute-phase` | always TDD unless `--skip-tdd` |
| 3. Build (UI) | "UI"; "design"; "component"; "screen"; "page" | `frontend-design` | `gsd-sketch`, `gsd-ui-phase` | UI-specific keywords |
| 4. Debug | "bug"; "broken"; "throws"; "fails"; "regression" | `diagnose` | `superpowers:systematic-debugging`, `gsd-debug` | hypothesis-first non-skippable |
| 5. Verify | claim of "done"; before commit/PR | `superpowers:verification-before-completion` | `gsd-verify-work`, `gsd-validate-phase` | mandatory before Review |
| 6. Review | pre-merge; "review this" | `superpowers:requesting-code-review` | `gsd-code-review`, `simplify` | mandatory before Ship |
| 7. Refactor | "messy"; "hard to change"; "clean up" | `improve-codebase-architecture` | `zoom-out`, `gsd-map-codebase` | scope to current task only |
| 8. Ship | "merge"; "PR"; "ship it" | `gsd-ship` | `superpowers:finishing-a-development-branch` | only after Verify + Review |
| 9. Capture | post-ship; end of phase | `claude-mem` (auto) | `gsd-extract-learnings` | runs automatically |

## Always-on layer

- `context-mode` — output discipline (large tool output → sandbox). No opt-in needed.
- `caveman` — communication style (terse, no filler). Active by default per Bhargav's CLAUDE.md.

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

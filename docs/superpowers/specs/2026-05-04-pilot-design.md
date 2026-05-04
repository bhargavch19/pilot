# Pilot — Unified AI Coding Conductor Skill

**Date:** 2026-05-04
**Author:** Bhargav (with Claude)
**Status:** Approved (sections 1–3) — ready for implementation plan

---

## Problem

Currently using AI to write software but not always sure what's being written. Trust without traceability. Want to avoid costly mistakes (silent scope creep, bad architecture, undisciplined edits) without slowing down. Multiple plugins/skills are installed (superpowers, GSD, context-mode, claude-mem, frontend-design, skill-creator, Pocock's skills) but switching between them requires memorizing slash commands and mental overhead.

## Goal

A single skill — `pilot` — that:

1. **Routes** user intent to the right underlying skill so Bhargav stops memorizing commands.
2. **Enforces** his quality bar (CLAUDE.md rules) as non-skippable gates.
3. **Embeds** Pocock's loop (grill → PRD → tracer-bullets → TDD → AFK → verify → memory).
4. **Stays extensible** — new skills register in a phase table; pilot picks them up without rewriting core logic.

## Non-goals

- Not a replacement for any of the underlying plugins. Pilot is the conductor; existing plugins keep doing their job.
- Not a one-shot installer (option C from brainstorming was rejected for that role).
- Not a UI / GUI — pure markdown + hooks.

---

## Anatomy

**Name:** `pilot`
**Location:** `~/.claude/skills/pilot/` (user-level, available in every project)

```
pilot/
├── SKILL.md              # entry: phase detection + routing logic
├── workflow.md           # Pocock loop, expanded
├── guardrails.md         # CLAUDE.md rules → enforced gates
├── registry.md           # extensible {phase → skill} table
├── playbooks/
│   ├── new-feature.md    # frame → plan → tdd → ship
│   ├── bug-fix.md        # repro → diagnose → fix → regression
│   ├── refactor.md       # scope → plan → atomic slices → verify
│   ├── exploration.md    # spike → discard or promote
│   └── ui-work.md        # frontend-design + sketch + review
├── hooks/
│   ├── pre-commit.sh     # blocks WIP commits, console.log, sleep() in tests
│   ├── plan-gate.sh      # blocks edits if scope >1 file or >20 LOC without plan
│   └── verify-gate.sh    # blocks "done" claims without verification output
└── README.md             # how to extend
```

**Activation modes:**
- **Manual:** `/pilot` (or natural-language trigger via the skill's `description`)
- **Sticky:** once invoked in a session, remains active until user says `pilot off rails`
- **Per-turn override:** `pilot off` (single turn), `pilot --skip-tdd`, `pilot --no-plan`

---

## Phase routing

Pilot classifies every user turn into one of 10 phases, then invokes the canonical skill.

| Phase | Triggers | Primary | Fallbacks |
|---|---|---|---|
| **0. Recall** | session start, "where were we", "did we already…" | `claude-mem:mem-search` | `gsd-resume-work` |
| **1. Frame (non-code)** | "idea", "what if", "explore", "thinking about" | `grill-me` | `gsd-explore` |
| **1. Frame (code)** | "build", "add", "feature", "change X" | `grill-with-docs` → `to-prd` | `superpowers:brainstorming` → `gsd-spec-phase` |
| **2. Plan** | post-frame, or "plan this", >1 file or >20 LOC | `superpowers:writing-plans` (single sess) OR `gsd-plan-phase` (multi-sess) | `to-issues` for tracer slicing |
| **3. Build (logic)** | post-plan, code work begins | `tdd` (Pocock vertical slice) | `superpowers:test-driven-development`, `gsd-execute-phase` |
| **3. Build (UI)** | "UI", "design", "component", "screen" | `frontend-design` | `gsd-sketch`, `gsd-ui-phase` |
| **4. Debug** | "bug", "broken", "throws", "fails", "regression" | `diagnose` (Pocock) | `superpowers:systematic-debugging`, `gsd-debug` |
| **5. Verify** | claim of "done", before commit/PR | `superpowers:verification-before-completion` | `gsd-verify-work`, `gsd-validate-phase` |
| **6. Review** | pre-merge, "review this" | `superpowers:requesting-code-review` | `gsd-code-review`, `simplify` |
| **7. Refactor** | "messy", "hard to change", code smell | `improve-codebase-architecture` | `zoom-out`, `gsd-map-codebase` |
| **8. Ship** | "merge", "PR", "ship it" | `gsd-ship` | `superpowers:finishing-a-development-branch` |
| **9. Capture** | post-ship, end of phase | `claude-mem` (auto) | `gsd-extract-learnings` |

**Resolution rule for "multiple options":**
1. If GSD project state exists (`.planning/` directory) → prefer GSD variant.
2. Else if work is multi-session/multi-file → prefer GSD or superpowers.
3. Else → prefer Pocock (tracer-bullet, fastest).
4. Always: `context-mode` runs underneath (output discipline, no opt-in needed).

---

## Guardrails

Each rule from `~/.claude/CLAUDE.md` (and Bhargav's auto-memory) maps to an enforcement layer.

| # | Rule | Enforcement | Pilot action |
|---|---|---|---|
| G1 | Plan before coding (>1 file OR >20 LOC) | Skill content | Detects scope; refuses edits until Plan phase done |
| G2 | Explain trade-offs (1 alternative + why rejected) | Skill content | Plan template requires "alt considered" field |
| G3 | Small atomic commits, conventional messages | Skill + hook | After each tracer slice, propose commit; hook blocks WIP/multi-feature |
| G4 | One focused clarifying question, not 3 assumptions | Skill content | Frame phase: max 1 Q per turn |
| G5 | No silent scope creep | Skill content | Out-of-scope finds → "follow-ups" section; do not fix |
| G6 | Read every diff | Skill + hook | Pre-commit prints diff + 1-line "what/why" |
| G7 | TS strict, no `any` without comment | Hook (lint-staged) | `setup-pre-commit`; skill rejects `any` in generated code |
| G8 | No dead code, no `console.log` | Hook (lint-staged) | Same |
| G9 | Async boundaries have explicit error handling | Skill content | TDD red phase requires error-path test |
| G10 | Tests for non-trivial logic | Skill content | TDD phase mandatory unless `--skip-tdd` |
| G11 | Hypothesis before editing (debug) | Skill content | `diagnose`'s reproduce→hypothesise non-skippable |
| G12 | No `sleep`/timeout patches for flaky tests | Skill + grep | Pre-commit blocks new `sleep(` / `setTimeout` in test files |
| G13 | Direct communication, no filler | Skill content | `caveman`-style compressed responses |
| G14 | End multi-step work with: changed/didn't/verify | Skill content | Session close template |
| G15 | Dangerous git ops blocked | Hook | Install Pocock's `git-guardrails-claude-code` |

**Two layers:**
- **Skill-level (soft):** rules in `SKILL.md`. Claude obeys. Bypassed via `pilot off`.
- **Hook-level (hard):** shell scripts run by harness on `PreToolUse` / `PreCommit`. Block before execution. Harder to bypass.

---

## Pocock skill audit

**Already installed** in current session (verified via Skill tool listing): `tdd`, `diagnose`, `grill-me`, `grill-with-docs`, `to-prd`, `to-issues`, `triage`, `improve-codebase-architecture`, `caveman`, `write-a-skill`, `find-skills`.

**To install during pilot scaffolding:**
- `zoom-out` — explain code in whole-system context (refactor phase)
- `setup-matt-pocock-skills` — per-repo config (issue tracker, ADR layout)
- `git-guardrails-claude-code` — hook-based block on dangerous git commands (G15)
- `setup-pre-commit` — Husky + lint-staged (G7, G8, G12)

Install command: `npx skills@latest add mattpocock/skills` (interactive picker — select the 4 above).

---

## Extensibility

To add a new skill in the future, append a row to `registry.md`:

```markdown
| Phase | Skill | Triggers | Priority |
|---|---|---|---|
| 4. Debug | new-debug-tool | "memory leak", "OOM" | preferred over diagnose for memory issues |
```

Pilot reads `registry.md` on every turn. No code change required.

---

## Setup / install plan (high level — full plan in next phase)

1. Install missing Pocock skills (`zoom-out`, `setup-matt-pocock-skills`, `git-guardrails-claude-code`, `setup-pre-commit`).
2. Scaffold `~/.claude/skills/pilot/` directory with all files above.
3. Wire hooks into `~/.claude/settings.json` (`PreToolUse:Bash`, `PreCommit`, `Stop`).
4. Add `pilot doctor` slash command that audits any project for missing config.
5. Test on `claude-skill` repo (this directory) — dogfood pilot to build itself.
6. Document in `~/.claude/skills/pilot/README.md` how to extend.

---

## Decisions locked

- **Packaging:** user-level skill (`~/.claude/skills/pilot/`) for v1. Plugin wrapper deferred.
- **Hooks:** native Claude Code hooks for harness-level (PreToolUse, Stop, SessionStart) + Husky for git-level (per-repo, catches manual git ops outside Claude).
- **Activation:** auto-engage at SessionStart with a `[pilot active]` banner. `pilot off` for single-turn override; `pilot off rails` for session-wide.

---

## Success criteria

- Bhargav never has to type a slash command other than `/pilot` (and `/pilot off` overrides).
- 100% of code edits >20 LOC trigger plan phase.
- 100% of "done" claims trigger verify phase.
- Adding a new skill = appending one row to `registry.md`.
- Pre-commit hook catches at least one `console.log` / `any` / `sleep()` in dogfood week.

---

## References

- `~/.claude/CLAUDE.md` — universal quality bar
- `~/.claude/projects/-Users-bhargavchellu-Workspace/memory/MEMORY.md` — Pocock workflow note
- https://github.com/mattpocock/skills — source for grilling/PRD/TDD/diagnose/etc.
- Superpowers brainstorming flow → writing-plans transition (next step)

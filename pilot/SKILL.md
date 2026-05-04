---
name: pilot
description: Unified AI coding conductor. Auto-routes intent to the right skill (grill, plan, TDD, debug, verify, ship), enforces CLAUDE.md quality gates, and stays extensible via registry.md. Use whenever starting work, debugging, refactoring, or shipping. Triggers on: "build", "fix", "ship", "explore", "messy", "broken", "review", session start, or any code change >20 LOC. Bypass per-turn with "pilot off"; per-session with "pilot off rails".
---

# Pilot

You are conducting Bhargav's coding session. Your job is to:
1. **Detect the phase** of work from the user's prompt and project state.
2. **Invoke the right underlying skill** per `registry.md`.
3. **Enforce guardrails** per `guardrails.md`.
4. **Stay out of the way** — don't repeat what the underlying skill already does.

## Activation banner

When invoked at SessionStart (or first turn of a session), emit one line:

```
[pilot active] phase routing on. say "pilot off" (one turn) or "pilot off rails" (session) to bypass.
```

## Phase detection algorithm

1. **Read `registry.md`** (it lives next to this file).
2. **Scan the user prompt** for trigger keywords from the registry.
3. **Read project state** to inform resolution priority:
   - `ls .planning/ 2>/dev/null` — GSD project state present?
   - `git status --short 2>/dev/null` — uncommitted work?
   - `git log --oneline -5 2>/dev/null` — recent commits suggest mid-task?
4. **Pick one phase** with the highest signal. If ambiguous, ask one focused question (per CLAUDE.md G4).
5. **Invoke the primary skill** for that phase via the Skill tool. Do NOT inline the underlying skill's logic.
6. **Apply guardrails** before any code action — see `guardrails.md`.

## Phase recognition cheatsheet

| Signal | Phase |
|---|---|
| Session opens; user typed nothing yet | 0. Recall |
| "what if", "idea", "explore" — no code intent | 1. Frame (non-code) |
| "build X", "add Y", "feature for Z" | 1. Frame (code) → 2. Plan |
| User has a frame + says "go" or "plan" | 2. Plan |
| Plan exists; user says "build" / "implement" | 3. Build |
| User mentions UI / component / screen | 3. Build (UI) |
| "bug", "broken", "throws", "fails" | 4. Debug |
| User says "done" / "ready" before tests run | 5. Verify (gate) |
| Tests green, user wants merge | 6. Review → 8. Ship |
| "messy", "hard to change", code smell | 7. Refactor |
| Phase complete | 9. Capture (auto) |

## Playbooks

For multi-step phase combinations, see:
- `playbooks/new-feature.md` — Frame → Plan → Build → Verify → Review → Ship
- `playbooks/bug-fix.md` — Debug → Verify
- `playbooks/refactor.md` — Refactor → Verify → Review
- `playbooks/exploration.md` — Frame (non-code) → Spike
- `playbooks/ui-work.md` — Frame → Build (UI) → Review

## Bypass syntax

- `pilot off` — disable for the next turn only.
- `pilot off rails` — disable for the rest of the session.
- `pilot --skip-tdd` — proceed without TDD (use sparingly).
- `pilot --no-plan` — proceed without a written plan (only for trivial changes).
- `pilot back on` — re-engage after `off rails`.

## What pilot does NOT do

- Does not write code itself for code phases — it invokes Build skills (tdd / superpowers:test-driven-development / frontend-design:frontend-design).
- Does not duplicate underlying skill logic. Trust them.
- Does not bypass guardrails silently. Always announce when a guardrail blocks.

## When to ask vs route

- **Ask** when: phase is ambiguous between two with similar signal strength; user hasn't stated success criteria; scope is unclear.
- **Route** when: phase is clear from keywords + project state; trigger matches one row in registry decisively.

Default: route. Ask only when a guardrail forces it (e.g., G1 needs scope to be known before plan vs build).

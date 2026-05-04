# Pilot Guardrails

15 rules from `~/.claude/CLAUDE.md` and Bhargav's auto-memory, mapped to enforcement.

## Soft layer (skill content — Claude obeys)

| # | Rule | Trigger | Action |
|---|---|---|---|
| G1 | Plan before coding (>1 file OR >20 LOC) | About to call Edit/Write on >1 file or content >20 lines | Block. Invoke Plan phase first. |
| G2 | Explain trade-offs (1 alternative + why rejected) | In Frame/Plan output | Plan template requires `## Alternative considered` section. |
| G4 | One focused clarifying question, not 3 invented assumptions | In Frame phase | Max 1 question per turn. |
| G5 | No silent scope creep | Edit on file unrelated to current task | Add to `out-of-scope-followups.md` instead of fixing. |
| G6 | Read every diff (user reads, AI explains) | Before commit | Print diff + 1-line "what changed, why this approach" before `git commit`. |
| G9 | Async boundaries have explicit error handling | TDD red phase | Test must include error path before implementation. |
| G10 | Tests for non-trivial logic | Build phase | TDD mandatory unless `pilot --skip-tdd`. |
| G11 | Hypothesis before editing (debug) | Debug phase | `diagnose` skill's reproduce→hypothesise step non-skippable. |
| G13 | Direct communication, no filler | Always | `caveman` style — fragments OK, technical exact, fluff dies. |
| G14 | End multi-step work with: changed/didn't/verify | At end of Build/Refactor/Ship | Emit close template. |

## Hard layer (shell hooks — harness or git blocks)

| # | Rule | Hook script | Trigger | Action |
|---|---|---|---|---|
| G3 | Atomic commits, conventional messages | `hooks/pre-commit.sh` | Pre-commit | Block if msg lacks conventional prefix or contains "WIP". |
| G7 | TS strict, no `any` without comment | `hooks/pre-commit.sh` (grep) | Pre-commit | Block on `: any` without `// any:` comment on same line. |
| G8 | No dead code, no `console.log` | `hooks/pre-commit.sh` (grep) | Pre-commit | Block on `console.log(` in staged TS/JS files. |
| G12 | No `sleep`/timeout patches for flaky tests | `hooks/pre-commit.sh` (grep) | Pre-commit | Block on new `sleep(` or `setTimeout(` in staged test files. |
| G15 | Dangerous git ops blocked | `hooks/git-dangerous.sh` (or Pocock's `git-guardrails-claude-code`) | PreToolUse:Bash | Block `push --force`, `reset --hard`, `clean -f`, `branch -D`. |

## Plan-gate hook (G1)

`hooks/plan-gate.sh` runs on `PreToolUse:Edit` and `PreToolUse:Write`:
- Counts files in proposed change set.
- Counts lines in `new_string` parameter.
- If files >1 OR lines >20, checks for an open plan in `docs/superpowers/plans/` modified in last 24h.
- If no plan: exit 1 with message `"plan-gate: G1 — write a plan first (touching N files / M lines). Run /plan or use writing-plans skill."`.

## Verify-gate hook (G14 + part of G5)

`hooks/verify-gate.sh` runs on `Stop` (end of assistant turn):
- Greps assistant transcript for "done", "complete", "ready", "passing", "fixed".
- If found, checks last 10 messages for evidence: a `pytest`/`npm test`/`bun test` invocation with green output.
- If no evidence: emit warning "verify-gate: G14 — claim of done without verification output."

## Bypass

All soft rules: `pilot off` for one turn.
Hard rules: cannot bypass without removing the hook from `~/.claude/settings.json`.

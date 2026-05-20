# Pilot Production-Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote pilot from "personal coding conductor" to "production-grade workflow engine" by adding 7 new phases (Triage, Bootstrap, Performance, Security, Migration, Pre-deploy, Post-deploy), wiring 3 existing skills as fallbacks (`run`, `claude-mem:learn-codebase`, `claude-mem:pathfinder`), upgrading the Verify-phase primary, scaffolding 3 new skills (`migration-safety`, `pre-deploy-checklist`, `post-deploy-monitor`), adding cross-turn phase awareness, and shipping a `/pilot-trace` slash command.

**Architecture:** Four stages. Stage 1 = registry-only adds (10 atomic commits, no code execution paths change). Stage 2 = meta-gaps (one SKILL.md insertion + one new slash command file). Stage 3 = new-skill scaffolds (interface + redirect, not full content). Stage 4 = README + landing page sync. The full implementation of the three new skills is **deferred** to follow-up sessions; this plan registers their identifiers and stub-routes them through working fallbacks so users get real behavior even before the full content lands.

**Tech Stack:** Bash + `jq` for hook glue (existing convention). Claude Code skill `.md` files with YAML frontmatter for new skills. `registry.md` Markdown table for phase routing. No new dependencies.

**Decisions baked in:**

- New phases slot at decimal numbers (`0.5 Triage`, `0.75 Bootstrap`, `4.5 Performance`, `6.5 Security`, `7.5 Migration`, `7.75 Pre-deploy`, `8.5 Post-deploy`). Total goes from 10 → 17 phases.
- Cross-turn state derives from the existing `routing.log` (read by the LLM as a hint). **No new state file.**
- `/pilot-trace` uses the last `skill=pilot` entry in `routing.log` as the session boundary marker.
- Force-fallback syntax is already supported via the literal-name shortcut added in v0.6.1. **Strike from todo.**
- New skill scaffolds redirect to a working fallback until full content ships. Routing engages them, but they don't produce empty output.

**Alternative considered:** Adding a separate `pilot-state.json` for cross-turn phase awareness. Rejected — `routing.log` already contains the necessary signal, adding another state file would mean two sources of truth and a migration path between them. Reading existing telemetry is strictly cheaper.

---

## File Structure

| File | Type | Stage | What |
|---|---|---|---|
| `skills/pilot/registry.md` | Modify | 1 | Add 7 new phase rows, edit 4 existing rows |
| `skills/pilot/SKILL.md` | Modify | 2 | Insert "Cross-turn phase awareness" section |
| `commands/pilot-trace.md` | Create | 2 | New slash command — show current session's chain |
| `skills/migration-safety/SKILL.md` | Create | 3 | Scaffold: frontmatter + section outline + redirect |
| `skills/pre-deploy-checklist/SKILL.md` | Create | 3 | Scaffold: frontmatter + section outline + redirect |
| `skills/post-deploy-monitor/SKILL.md` | Create | 3 | Scaffold: frontmatter + section outline + redirect |
| `README.md` | Modify | 4 | New "Production phases" section; bump structure bullets |
| `web/index.html` | Modify | 4 | Version chip → v0.7.0; new hero-side row; slash commands +/pilot-trace |

All edits are additive. Zero deletions of existing behavior. Existing 10 phases keep working unchanged.

---

# Stage 1 — Registry adds (10 commits)

Each task in this stage is a single registry-row edit + commit. Order matters only for the "wire fallbacks" tasks (8/9/10), which depend on the new rows existing in some cases. Run 1→7 first, then 8→10.

## Task 1: Add Phase 0.5 Triage

**Files:**
- Modify: `skills/pilot/registry.md` — insert new row after the existing "0. Recall" row.

- [ ] **Step 1.1: Insert row**

Find the row beginning `| 0. Recall |` in `skills/pilot/registry.md`. **Immediately after** that row, insert:

```markdown
| 0.5 Triage | "triage"; "what to work on"; "incoming bugs"; "review the inbox"; "issue queue" | `triage` | `gsd-inbox` | fires before Frame when work source is an issue tracker / PR queue |
```

- [ ] **Step 1.2: Update the "Phase recognition cheatsheet" in SKILL.md**

Find the row `| Session opens; user typed nothing yet | 0. Recall |` in `skills/pilot/SKILL.md`. Insert this row immediately after:

```markdown
| "triage"; "what to work on"; "review the inbox" | 0.5 Triage |
```

- [ ] **Step 1.3: Commit**

```bash
cd /Users/bhargavchellu/Workspace/claude-skill
git add skills/pilot/registry.md skills/pilot/SKILL.md
git commit -m "feat(registry): triage phase — route inbox/issue-queue prompts to triage skill"
```

---

## Task 2: Add Phase 0.75 Bootstrap

**Files:**
- Modify: `skills/pilot/registry.md`
- Modify: `skills/pilot/SKILL.md`

- [ ] **Step 2.1: Insert row**

After the Triage row added in Task 1, insert:

```markdown
| 0.75 Bootstrap | "new project"; "init"; "fresh repo"; no CLAUDE.md present | `init` | `gsd-new-project`, `claude-mem:learn-codebase` | auto-fire when `[ ! -f CLAUDE.md ]` AND no `.planning/` directory AND no prior pilot routing in this repo |
```

- [ ] **Step 2.2: Extend SKILL.md project-state probe**

Find the "Read project state" list in `skills/pilot/SKILL.md` (under "Phase detection algorithm"). It currently reads:

```markdown
3. **Read project state** to inform resolution priority:
   - `ls .planning/ 2>/dev/null` — GSD project state present?
   - `git status --short 2>/dev/null` — uncommitted work?
   - `git log --oneline -5 2>/dev/null` — recent commits suggest mid-task?
```

Add one bullet to that list:

```markdown
   - `test -f CLAUDE.md && echo yes || echo no` — repo has been bootstrapped?
```

- [ ] **Step 2.3: Update cheatsheet**

Insert after the Triage cheatsheet row:

```markdown
| no CLAUDE.md; "new project"; "init" | 0.75 Bootstrap |
```

- [ ] **Step 2.4: Commit**

```bash
git add skills/pilot/registry.md skills/pilot/SKILL.md
git commit -m "feat(registry): bootstrap phase — auto-fire when CLAUDE.md missing"
```

---

## Task 3: Add Phase 4.5 Performance

**Files:**
- Modify: `skills/pilot/registry.md`
- Modify: `skills/pilot/SKILL.md`

- [ ] **Step 3.1: Insert row**

Find the row beginning `| 4. Debug |`. Insert immediately after:

```markdown
| 4.5 Performance | "slow"; "latency"; "perf"; "profile"; "benchmark"; "bottleneck"; "regression"; "p99" | `diagnose` | `superpowers:systematic-debugging` | reproduce-then-measure non-skippable; same primary as Debug but explicit phase keeps perf invariants visible |
```

- [ ] **Step 3.2: Update cheatsheet**

After the Debug cheatsheet row (`| "bug", "broken", "throws", "fails" | 4. Debug |`), insert:

```markdown
| "slow", "latency", "perf", "profile", "benchmark" | 4.5 Performance |
```

- [ ] **Step 3.3: Commit**

```bash
git add skills/pilot/registry.md skills/pilot/SKILL.md
git commit -m "feat(registry): performance phase — explicit row for perf regression work"
```

---

## Task 4: Add Phase 6.5 Security

**Files:**
- Modify: `skills/pilot/registry.md`
- Modify: `skills/pilot/SKILL.md`

- [ ] **Step 4.1: Insert row**

Find the row beginning `| 6. Review |`. Insert immediately after:

```markdown
| 6.5 Security | "security review"; "audit"; "OWASP"; "vulnerability"; "sanitize"; "injection"; diff touches auth/crypto/network paths | `security-review` | `gsd-secure-phase` | always before Ship if any sensitive-path change |
```

- [ ] **Step 4.2: Update cheatsheet**

After the Review cheatsheet row (`| Tests green, user wants merge | 6. Review → 8. Ship |`), insert:

```markdown
| "security review", "audit", "OWASP", diff touches auth/crypto/network | 6.5 Security (mandatory before Ship) |
```

- [ ] **Step 4.3: Commit**

```bash
git add skills/pilot/registry.md skills/pilot/SKILL.md
git commit -m "feat(registry): security phase — security-review mandatory before Ship for sensitive diffs"
```

---

## Task 5: Add Phase 7.5 Migration (uses stub skill from Stage 3)

**Files:**
- Modify: `skills/pilot/registry.md`
- Modify: `skills/pilot/SKILL.md`

The row references `migration-safety` which will be scaffolded in Stage 3. Pilot's fallback-when-missing rule means until that scaffold exists, pilot routes to `to-issues` (the fallback). After Stage 3, pilot routes to the scaffold (which itself redirects to the fallback). Net behavior is identical until the full skill ships.

- [ ] **Step 5.1: Insert row**

Find the row beginning `| 7. Refactor |`. Insert immediately after:

```markdown
| 7.5 Migration | "migration"; "schema change"; "upgrade dep"; "breaking change"; "lockfile bump" | `migration-safety` | `to-issues`, `diagnose` | required before Pre-deploy if `migrations/` or lockfile changed; produces `MIGRATION-SAFETY.md` |
```

- [ ] **Step 5.2: Update cheatsheet**

After the Refactor cheatsheet row, insert:

```markdown
| "migration", "schema change", "upgrade dep", diff touches migrations/ or lockfile | 7.5 Migration |
```

- [ ] **Step 5.3: Commit**

```bash
git add skills/pilot/registry.md skills/pilot/SKILL.md
git commit -m "feat(registry): migration phase — migration-safety primary, to-issues fallback"
```

---

## Task 6: Add Phase 7.75 Pre-deploy

**Files:**
- Modify: `skills/pilot/registry.md`
- Modify: `skills/pilot/SKILL.md`

- [ ] **Step 6.1: Insert row**

After the Migration row added in Task 5, insert:

```markdown
| 7.75 Pre-deploy | "deploy"; "release"; "ship to prod"; "production"; "go live"; immediately before Ship on a release branch | `pre-deploy-checklist` | `superpowers:requesting-code-review` | fires automatically before Ship for production-targeted branches; produces `PRE-DEPLOY.md` |
```

- [ ] **Step 6.2: Update cheatsheet**

Insert after the Migration cheatsheet row:

```markdown
| "deploy", "release", "ship to prod" | 7.75 Pre-deploy (mandatory before Ship) |
```

- [ ] **Step 6.3: Commit**

```bash
git add skills/pilot/registry.md skills/pilot/SKILL.md
git commit -m "feat(registry): pre-deploy phase — checklist before Ship for prod branches"
```

---

## Task 7: Add Phase 8.5 Post-deploy

**Files:**
- Modify: `skills/pilot/registry.md`
- Modify: `skills/pilot/SKILL.md`

- [ ] **Step 7.1: Insert row**

Find the row beginning `| 8. Ship |`. Insert immediately after:

```markdown
| 8.5 Post-deploy | "monitor"; "after deploy"; "did the deploy work"; "rollback"; "post-deploy"; "did anything break" | `post-deploy-monitor` | `diagnose` | fires after Ship completes; checks error rate + latency + logs; produces `POST-DEPLOY.md` |
```

- [ ] **Step 7.2: Update cheatsheet**

After the Ship-related row, insert:

```markdown
| "monitor", "after deploy", "rollback", "did the deploy work" | 8.5 Post-deploy |
```

- [ ] **Step 7.3: Commit**

```bash
git add skills/pilot/registry.md skills/pilot/SKILL.md
git commit -m "feat(registry): post-deploy phase — monitor + verify after Ship"
```

---

## Task 8: Wire `run` as UI Verify fallback

**Files:**
- Modify: `skills/pilot/registry.md`

- [ ] **Step 8.1: Edit UI verify row**

Find the row beginning `| UI verify |`. The Fallbacks column currently reads:

```
| `superpowers:verification-before-completion` (test-runner only — no browser) |
```

Change to:

```
| `run`, `superpowers:verification-before-completion` (test-runner only — no browser) |
```

The full edited row should read:

```markdown
| UI verify | UI tasks reaching Verify phase; "test in browser"; "does it actually work"; "screenshot the change" | `playwright` MCP (`mcp__playwright__browser_navigate`, `browser_snapshot`, `browser_click`, `browser_evaluate`, ...) | `run`, `superpowers:verification-before-completion` (test-runner only — no browser) | invoke proactively after Build (UI) completes, before claiming the change works |
```

- [ ] **Step 8.2: Commit**

```bash
git add skills/pilot/registry.md
git commit -m "feat(registry): UI verify falls back to run when playwright unavailable"
```

---

## Task 9: Wire `claude-mem:learn-codebase` + `pathfinder` as fallbacks

**Files:**
- Modify: `skills/pilot/registry.md`

- [ ] **Step 9.1: Edit Recall row**

Find the row beginning `| 0. Recall |`. Change its Fallbacks column from:

```
| `gsd-resume-work` |
```

to:

```
| `gsd-resume-work`, `claude-mem:learn-codebase` |
```

And the Resolution rule column from:

```
| always run on SessionStart |
```

to:

```
| always run on SessionStart; if mem-search returns nothing AND repo is unfamiliar (no prior `claude-mem` index), use `learn-codebase` to prime |
```

- [ ] **Step 9.2: Edit Refactor row**

Find the row beginning `| 7. Refactor |`. Change its Fallbacks column from:

```
| `zoom-out`, `gsd-map-codebase` |
```

to:

```
| `claude-mem:pathfinder`, `zoom-out`, `gsd-map-codebase` |
```

And the Resolution rule column from:

```
| scope to current task only |
```

to:

```
| single-file deepening → improve-codebase-architecture; cross-system unification → pathfinder; scope to current task only |
```

- [ ] **Step 9.3: Commit**

```bash
git add skills/pilot/registry.md
git commit -m "feat(registry): wire claude-mem fallbacks — learn-codebase for Recall, pathfinder for Refactor"
```

---

## Task 10: Upgrade Verify-phase primary to `verify`

**Files:**
- Modify: `skills/pilot/registry.md`

The current Verify primary is `superpowers:verification-before-completion` — a textual "did you run tests?" gate. The standalone `verify` skill actually launches the app and observes behavior. That's a strictly stronger primary. The textual gate is enforced by the `verify-gate.sh` hook regardless, so demoting it to fallback doesn't lose its enforcement.

- [ ] **Step 10.1: Edit Verify row**

Find the row beginning `| 5. Verify |`. Change:

```
| 5. Verify | claim of "done"; before commit/PR | `superpowers:verification-before-completion` | `gsd-verify-work`, `gsd-validate-phase` | mandatory before Review |
```

to:

```markdown
| 5. Verify | claim of "done"; before commit/PR; "actually test it"; "confirm it works" | `verify` | `playwright` (UI cases), `superpowers:verification-before-completion`, `gsd-verify-work`, `gsd-validate-phase` | run the app + observe behavior; text-only gate enforced via `verify-gate.sh` hook regardless of primary |
```

- [ ] **Step 10.2: Commit**

```bash
git add skills/pilot/registry.md
git commit -m "feat(registry): verify phase primary upgraded to behavior-driven verify skill"
```

---

# Stage 2 — Meta-gaps (2 commits)

## Task 11: Cross-turn phase awareness via `routing.log` read

**Files:**
- Modify: `skills/pilot/SKILL.md` — insert new section before "Phase detection algorithm".

- [ ] **Step 11.1: Insert section**

In `skills/pilot/SKILL.md`, find the line `## Phase detection algorithm`. **Immediately before** that line, insert:

```markdown
## Cross-turn phase awareness

Pilot doesn't carry explicit phase state across turns — but the routing telemetry already is the state. **Before** running phase detection, glance at the last ~5 entries of `${XDG_CACHE_HOME:-~/.cache}/pilot/routing.log`:

```bash
tail -5 "${XDG_CACHE_HOME:-$HOME/.cache}/pilot/routing.log" 2>/dev/null
```

Use those entries as **context** for the current routing decision:

- If the latest entries show a chain in progress (`pilot → writing-plans → tdd → ...`), the user's "go" / "continue" / "next" usually means **advance to the next phase**, not start over. Look at the chain shape and pick the natural successor (Build → Verify, Verify → Review, Review → Ship).
- If the latest entry was `skill=gsd-ship` or another terminal, the work is done. A fresh prompt should route to Recall / Triage / Frame.
- If there are no entries from the last ~10 minutes, treat the session as fresh and re-run phase detection from scratch.
- If the chain shows the same skill repeated multiple times (`pilot → tdd → tdd → tdd`), the user is iterating — don't re-engage routing, just continue.

This is **observation**, not control flow. The LLM uses it as a hint to break ties or pick natural successors. The registry's resolution rules still govern actual phase selection.

```

- [ ] **Step 11.2: Commit**

```bash
git add skills/pilot/SKILL.md
git commit -m "feat(skill): cross-turn phase awareness via routing.log read"
```

---

## Task 12: `/pilot-trace` slash command

**Files:**
- Create: `commands/pilot-trace.md`

- [ ] **Step 12.1: Create the command file**

Create `/Users/bhargavchellu/Workspace/claude-skill/commands/pilot-trace.md` with this exact content:

```markdown
---
description: Show the current session's pilot routing chain — phases visited in order since the last SessionStart.
allowed-tools: Bash
---

Print a compact trace of every Skill invocation since the most recent
`skill=pilot` entry (the session-start marker). Useful for "why did it
route there?" debugging.

Steps:

1. **Locate the log and find the session boundary** — the last
   `skill=pilot` entry:

   ```bash
   LOG="${XDG_CACHE_HOME:-$HOME/.cache}/pilot/routing.log"
   if [[ ! -f "$LOG" ]]; then
     echo "No routing log yet (~/.cache/pilot/routing.log not found)."
     echo "If pilot is wired but hasn't fired, run any work-prompt to seed the log."
     exit 0
   fi

   BOUNDARY=$(grep -n "skill=pilot$" "$LOG" | tail -1 | cut -d: -f1)
   if [[ -z "$BOUNDARY" ]]; then
     echo "No 'skill=pilot' entry in current log — pilot may not be active in any recent session."
     echo "Showing last 10 entries:"
     tail -10 "$LOG"
     exit 0
   fi
   ```

2. **Print entries since the boundary**, numbered, with arrows showing the
   chain:

   ```bash
   echo "Pilot session chain (since line $BOUNDARY of routing.log):"
   echo
   tail -n +"$BOUNDARY" "$LOG" | awk -F'skill=' '
     {
       n++
       arrow = (n == 1) ? "  " : "→ "
       printf "%2d. %s %s\n", n, arrow, $0
     }
   '
   echo
   ```

3. **Annotate the shape** — give the user a one-line summary:

   ```bash
   CHAIN_LEN=$(tail -n +"$BOUNDARY" "$LOG" | wc -l | tr -d ' ')
   LAST_SKILL=$(tail -1 "$LOG" | awk -F'skill=' '{print $2}')

   if [[ "$CHAIN_LEN" -le 1 ]]; then
     echo "Chain length: 1 — pilot engaged but no phase fired yet."
   else
     echo "Chain length: $CHAIN_LEN phases. Most recent: $LAST_SKILL."
   fi
   ```

That's the full command. Compact, no external deps beyond `awk` / `grep`
which every supported platform ships.
```

- [ ] **Step 12.2: Smoke-test the command**

```bash
cd /Users/bhargavchellu/Workspace/claude-skill
# Extract just the bash blocks from the markdown and run them in sequence
bash <(awk '/^   ```bash$/,/^   ```$/' commands/pilot-trace.md | sed 's/^   //' | grep -v '^```')
```

Expected: a numbered list of recent routing events ending with a chain-length summary.

- [ ] **Step 12.3: Commit**

```bash
git add commands/pilot-trace.md
git commit -m "feat(commands): /pilot-trace — show current session's routing chain"
```

---

# Stage 3 — New-skill scaffolds (3 commits)

Each new skill gets a real directory with a real SKILL.md that has:
- Proper YAML frontmatter (so it's discoverable by the Skill tool).
- A "Status: scaffold" block explaining the skill is registered but not yet fully implemented.
- A redirect to a working fallback skill that handles the same use case in the interim.
- A documented section outline for the full skill content (this becomes the spec for follow-up sessions).
- Acceptance criteria the full skill must meet.

This way, pilot's routing engages the scaffold (real file, real frontmatter), and the scaffold itself instructs the LLM to redirect to a working fallback. Net behavior is "produces useful output today, plus a clear handoff for tomorrow."

## Task 13: `migration-safety` skill scaffold

**Files:**
- Create: `skills/migration-safety/SKILL.md`

- [ ] **Step 13.1: Create the scaffold**

Create `/Users/bhargavchellu/Workspace/claude-skill/skills/migration-safety/SKILL.md`:

```markdown
---
name: migration-safety
description: Analyze proposed schema migrations, dependency upgrades, and breaking changes for production safety. Use when adding or changing DB migrations, bumping major versions of dependencies, modifying APIs that have external consumers, or touching lockfiles. Triggers on "migration", "schema change", "upgrade dep", "breaking change", "lockfile bump", and on any diff that touches `migrations/`, `package.json`, `requirements.txt`, `Cargo.lock`, `Gemfile.lock`, `go.sum`, or `**/*.migration.sql`.
---

# Migration Safety

## Status: scaffold (full implementation queued)

This skill is registered in pilot's routing table (Phase 7.5 Migration) but its full content is queued for a follow-up session. Until then, this file performs the role of a **transparent redirect**: when pilot routes here, hand off to a working fallback that covers the same use case, and document what the full skill will do so the redirect feels honest, not broken.

### Redirect for now

- **Schema migration** → use `to-issues` to break the migration into a tracer-bullet sequence: write the forward migration, write the reverse migration, dry-run the forward on a snapshot of prod data, write the rollback playbook, ship the forward with a feature flag.
- **Dep upgrade (major version bump)** → use `diagnose` to assess regression risk: read the dep's CHANGELOG, identify every `BREAKING` entry, grep the codebase for callsites, surface what's likely to break.
- **API contract change** → use `to-prd` to make the contract change explicit, then `superpowers:requesting-code-review` to gate external-consumer impact.

State explicitly to the user: "migration-safety is scaffold-only; using `<fallback>` for this turn."

## When the full skill is implemented, it will cover

### 1. Concurrent-write safety (DB migrations)

For each migration touching live tables:
- Identify locks acquired (`ACCESS EXCLUSIVE`, `SHARE`, etc.)
- Estimate lock duration as a function of table size
- Suggest concurrent alternatives (`CREATE INDEX CONCURRENTLY`, two-step add-column-with-default, etc.)
- Flag operations that block writes for >100ms on tables >1M rows

### 2. Rollback plan

- Every forward migration must have a documented reverse migration OR a feature-flag-toggle to disable the new code path.
- For irreversible migrations (drop column, drop table), require explicit acknowledgment in a `MIGRATION-SAFETY.md` block.

### 3. Downtime estimate

- Read row count from `information_schema` / equivalent
- Apply known per-operation timing (ALTER TABLE adds ~1ms/row for many operations)
- Output an estimated window with a confidence interval

### 4. Dep upgrade breaking-change scan

- Resolve the changelog of the bumped dep (npm package CHANGELOG.md, GitHub releases, Cargo crate metadata)
- Filter to `BREAKING` / `MAJOR` entries between the current and target version
- For each, grep the codebase for callsites of the affected API
- Output a `BREAKING-IMPACT.md` with a table: API → callsite count → suggested migration

### 5. Feature-flag wrapping

- For changes deemed risky by the above checks, propose a feature flag with:
  - Default state (off for new code, on for existing behavior)
  - Documented removal date (default: 30 days after deploy)
  - Rollback procedure that doesn't require redeploy

## Output artifact

Full skill writes `MIGRATION-SAFETY.md` to the phase artifact directory (`.planning/phase-XX/MIGRATION-SAFETY.md` when GSD project state exists, else `docs/migration-safety/<branch>.md`).

The report sections mirror sections 1-5 above. Each section has a verdict: `PASS` / `CAUTION` / `BLOCK`. Any `BLOCK` halts the Pre-deploy phase until resolved.

## Acceptance criteria for the full skill

- Can parse migrations in at least: PostgreSQL (`ALTER TABLE`), MySQL, SQLite, Rails ActiveRecord, Django, Alembic.
- Can read at least: `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `requirements.txt`, `Pipfile.lock`, `Cargo.lock`, `Gemfile.lock`, `go.sum`.
- Produces a `MIGRATION-SAFETY.md` artifact with all 5 sections populated.
- Integrates with `/pilot-doctor` — a "branch ship-readiness" check that surfaces any `BLOCK` verdicts.
- Has fixture tests under `tests/skills/migration-safety/` covering at least: lock-blocking migration, missing reverse migration, major dep bump with breaking-change scan.

## Triggers (final list; may grow)

- Literal: "migration", "schema change", "upgrade dep", "breaking change", "lockfile bump"
- Project-state probe: `git diff` includes paths matching `migrations/`, `package.json`, `requirements.txt`, `Cargo.lock`, `Gemfile.lock`, `go.sum`, `**/*.migration.sql`
- Phase ordering: required before Phase 7.75 Pre-deploy if any of the above are present in the diff

---

*Full content scheduled for a follow-up session. See `docs/superpowers/plans/2026-05-20-production-hardening.md` for the implementation queue. Until then, the redirect above keeps users unblocked.*
```

- [ ] **Step 13.2: Commit**

```bash
git add skills/migration-safety/SKILL.md
git commit -m "feat(skills): migration-safety scaffold — interface + redirect to to-issues fallback"
```

---

## Task 14: `pre-deploy-checklist` skill scaffold

**Files:**
- Create: `skills/pre-deploy-checklist/SKILL.md`

- [ ] **Step 14.1: Create the scaffold**

Create `/Users/bhargavchellu/Workspace/claude-skill/skills/pre-deploy-checklist/SKILL.md`:

```markdown
---
name: pre-deploy-checklist
description: Run a structured pre-deploy gate before shipping to production. Covers secret scan, env-var completeness, feature-flag default state, smoke test plan, and identified rollback path. Use immediately before any production deploy. Triggers on "deploy", "release", "ship to prod", "production", "go live", "tagging a release".
---

# Pre-deploy Checklist

## Status: scaffold (full implementation queued)

This skill is registered in pilot's routing table (Phase 7.75 Pre-deploy) but its full content is queued. Until then, redirect to working fallbacks per the use case.

### Redirect for now

- **Code-review readiness** → use `superpowers:requesting-code-review` to confirm the diff is review-ready, then check the merge protection rules manually.
- **Security pass** → use `security-review` for OWASP-style checks (this also runs in Phase 6.5 Security).
- **Smoke test plan** → use `verify` to drive the app through the new feature manually before deploying.
- **Secret scan** → run `gitleaks detect` or equivalent locally; pilot doesn't yet wrap it.

State to the user: "pre-deploy-checklist is scaffold-only; using `<fallback>` for this turn."

## When the full skill is implemented, it will cover

### 1. Secret scan

- Run `gitleaks detect` (or equivalent) on the diff
- Block on any high-severity finding
- For low-severity findings, request explicit acknowledgment

### 2. Env-var completeness

- Diff `.env.example` against required env vars referenced in code (`process.env.X`, `os.environ['X']`, etc.)
- Block if any required env var is undocumented
- Surface to the user before deploy: "the following env vars must be set in production: …"

### 3. Feature-flag default state

- Find every newly-added feature flag in the diff
- Confirm its production default (off for new behavior, on for existing)
- Surface flags that default-on for new behavior — these are usually wrong

### 4. Smoke test plan

- For the change set, propose a 3-5 step manual smoke test
- Each step has a "what to click" and a "what to observe"
- The user runs the smoke test and confirms before proceeding

### 5. Rollback identification

- Confirm the deploy mechanism has a documented rollback procedure for this change
- For DB migrations, confirm Migration phase (7.5) produced a `MIGRATION-SAFETY.md` with rollback steps
- For new infrastructure, confirm Terraform / IaC has a `destroy` path

## Output artifact

Full skill writes `PRE-DEPLOY.md` to the phase artifact directory. Each of the 5 sections has a `PASS` / `CAUTION` / `BLOCK` verdict. Any `BLOCK` halts the Ship phase.

## Acceptance criteria for the full skill

- Wraps `gitleaks` (or `trufflehog` as alternative) for secret scanning.
- Diffs the project's env-var documentation against code references.
- Reads feature flag declarations from at least: GrowthBook, LaunchDarkly, ConfigCat, custom env-var flags.
- Has fixture tests covering: missing env var, default-on feature flag, missing rollback documentation.

## Triggers (final list)

- Literal: "deploy", "release", "ship to prod", "production", "go live", "tag release"
- Phase ordering: fires automatically before Phase 8 Ship when the target branch is `main` / `production` / `release/*`

---

*Full content scheduled for a follow-up session.*
```

- [ ] **Step 14.2: Commit**

```bash
git add skills/pre-deploy-checklist/SKILL.md
git commit -m "feat(skills): pre-deploy-checklist scaffold — interface + redirect to security-review fallback"
```

---

## Task 15: `post-deploy-monitor` skill scaffold

**Files:**
- Create: `skills/post-deploy-monitor/SKILL.md`

- [ ] **Step 15.1: Create the scaffold**

Create `/Users/bhargavchellu/Workspace/claude-skill/skills/post-deploy-monitor/SKILL.md`:

```markdown
---
name: post-deploy-monitor
description: After a production deploy completes, monitor error rate, latency, and log output for the first 15-60 minutes. Surface regressions before they become incidents. Use immediately after Ship phase. Triggers on "monitor", "after deploy", "did the deploy work", "rollback", "post-deploy", "did anything break".
---

# Post-deploy Monitor

## Status: scaffold (full implementation queued)

This skill is registered in pilot's routing table (Phase 8.5 Post-deploy) but its full content is queued. Until then, redirect per use case.

### Redirect for now

- **Manual log scrape** → use `diagnose` to investigate any reported anomaly post-deploy.
- **Error rate / latency check** → if your team has a Grafana / Datadog / Sentry dashboard, open it manually; pilot doesn't yet wrap those APIs.
- **Rollback decision** → use `diagnose` to assess whether a rollback is warranted, then run your team's documented rollback procedure.

State to the user: "post-deploy-monitor is scaffold-only; using `diagnose` for any anomaly investigation."

## When the full skill is implemented, it will cover

### 1. Pre-deploy baseline capture

- Before Ship completes, record:
  - 7-day p50 / p95 / p99 latency for the affected routes
  - 7-day error rate for the affected routes
  - 7-day log-volume baseline
- Store baseline in `.pilot/post-deploy/<commit-sha>.json`

### 2. Post-deploy delta watch

- For 15 / 30 / 60 minutes post-deploy, poll the metrics source
- Compute deltas against baseline
- Threshold alerts:
  - Error rate > baseline × 1.5 → CAUTION
  - Error rate > baseline × 3 → BLOCK (auto-suggest rollback)
  - p99 latency > baseline + 100ms → CAUTION
  - p99 latency > baseline × 2 → BLOCK

### 3. Log diff

- Sample logs from the affected services pre- and post-deploy
- Surface any new error patterns (ERROR / FATAL log lines not present in baseline)

### 4. Rollback recommendation

- Combine signals from sections 2 and 3
- Output one of: `STABLE` (no action), `WATCH` (continue monitoring), `ROLLBACK` (revert immediately)

## Output artifact

Full skill writes `POST-DEPLOY.md` with the deltas, log diffs, and recommendation. Updated every 5 minutes for the first hour.

## Acceptance criteria for the full skill

- Reads metrics from at least: Prometheus, Datadog, Sentry, CloudWatch, Grafana (configurable per-project via `.pilot.json`).
- Reads logs from at least: stdout via `kubectl logs`, CloudWatch Logs, Datadog Logs, Loki.
- Surfaces a recommendation within 15 minutes of deploy completion.
- Has fixture tests covering: baseline-vs-spike error rate, latency regression, new error pattern in logs.

## Triggers (final list)

- Literal: "monitor", "after deploy", "did the deploy work", "rollback", "post-deploy", "did anything break"
- Phase ordering: fires automatically after Phase 8 Ship completes; runs for 60 minutes by default

---

*Full content scheduled for a follow-up session.*
```

- [ ] **Step 15.2: Commit**

```bash
git add skills/post-deploy-monitor/SKILL.md
git commit -m "feat(skills): post-deploy-monitor scaffold — interface + redirect to diagnose fallback"
```

---

# Stage 4 — Documentation sync (1 commit)

## Task 16: Update README + landing page

**Files:**
- Modify: `README.md`
- Modify: `web/index.html`

- [ ] **Step 16.1: Update README — top-level structure bullets**

Find the bullet list in `README.md` that begins with `- **Repository structure:** ...`. Update the **MCPs (bundled)** line to:

```markdown
- **MCPs (bundled):** `context7` (docs) · `playwright` (UI verify) · `github` (review / ship).
- **Bundled skills (this plugin's own):** `migration-safety`, `pre-deploy-checklist`, `post-deploy-monitor` (all under `skills/`). Currently scaffolds — see `docs/superpowers/plans/2026-05-20-production-hardening.md` for completion queue.
```

(insert the second line as a new bullet immediately after the MCPs line)

- [ ] **Step 16.2: Update README — add "Production phases" section**

After the existing `## How to invoke pilot` section, insert a new section:

```markdown
## Production phases (v0.7+)

Beyond the core Frame → Plan → Build → Verify → Review → Ship → Capture cycle, pilot routes 7 production-oriented phases at decimal slots:

| Slot | Phase | Primary skill | Fires when |
|---|---|---|---|
| 0.5 | Triage | `triage` | "what to work on", incoming bugs, PR queue |
| 0.75 | Bootstrap | `init` | repo has no CLAUDE.md |
| 4.5 | Performance | `diagnose` | "slow", "latency", "profile", "regression" |
| 6.5 | Security | `security-review` | "audit", "OWASP", diff touches auth/crypto/network |
| 7.5 | Migration | `migration-safety`* | diff touches `migrations/` or lockfile |
| 7.75 | Pre-deploy | `pre-deploy-checklist`* | immediately before Ship on a release branch |
| 8.5 | Post-deploy | `post-deploy-monitor`* | after Ship completes |

`*` Scaffold — registers and redirects to a working fallback. Full content in queue (see `docs/superpowers/plans/2026-05-20-production-hardening.md`).

Each phase appears as a row in `skills/pilot/registry.md` with its triggers and fallbacks. Phase ordering is enforced by the **Resolution rule** column — e.g., `7.5 Migration` is required before `7.75 Pre-deploy` if migrations/lockfile changed.
```

- [ ] **Step 16.3: Update README — Bypass table**

In the Bypass section, add a row for `/pilot-trace`:

```markdown
| Inspect current session's routing chain | `/pilot-trace` |
```

(insert immediately after the `/pilot-status` row)

- [ ] **Step 16.4: Update web/index.html — version chip**

Find the line containing `pilot v0.6.1` in `web/index.html`. Change to:

```html
      <span class="chip"><span class="chip-dot"></span> pilot v0.7.0</span>
```

- [ ] **Step 16.5: Update web/index.html — footer version**

Find the line containing `v0.6.1 · 2026-05-20` in `web/index.html`. Change to:

```html
      <span>v0.7.0 · 2026-05-20</span>
```

- [ ] **Step 16.6: Update web/index.html — add "phases" hero-side pair**

Find the existing `<dl class="hero-side">` block. After the `trigger` pair, insert a new `phases` pair:

```html
        <div class="pair">
          <dt>phases</dt>
          <dd>17 routed phases: Recall · Triage · Bootstrap · Frame · Plan · Build · Debug · Performance · Verify · Review · Security · Refactor · Migration · Pre-deploy · Ship · Post-deploy · Capture. Each maps to a primary skill with at least one fallback.</dd>
        </div>
```

- [ ] **Step 16.7: Update web/index.html — slash commands reference card**

Find the `<div class="commands">` block in the slash-commands reference card. After the `<div><code>/pilot-status</code><span class="desc">wired hooks · bypass · last routes</span></div>` row, insert:

```html
          <div><code>/pilot-trace</code><span class="desc">current session's phase chain in order</span></div>
```

- [ ] **Step 16.8: Smoke-check HTML**

```bash
cd /Users/bhargavchellu/Workspace/claude-skill
python3 -c "
import html.parser
class P(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack=[]
    def handle_starttag(self, tag, attrs):
        if tag not in ('br','hr','img','meta','link','input'):
            self.stack.append(tag)
    def handle_endtag(self, tag):
        if self.stack and self.stack[-1]==tag:
            self.stack.pop()
with open('web/index.html') as f:
    p = P(); p.feed(f.read())
print('unclosed:', p.stack if p.stack else 'none')
"
```

Expected: `unclosed: none`.

- [ ] **Step 16.9: Commit**

```bash
git add README.md web/index.html
git commit -m "docs: production phases (v0.7) — README + landing page sync"
```

---

# Summary of commits

After running this plan end-to-end, the repo gains these commits in order:

1. `feat(registry): triage phase — route inbox/issue-queue prompts to triage skill`
2. `feat(registry): bootstrap phase — auto-fire when CLAUDE.md missing`
3. `feat(registry): performance phase — explicit row for perf regression work`
4. `feat(registry): security phase — security-review mandatory before Ship for sensitive diffs`
5. `feat(registry): migration phase — migration-safety primary, to-issues fallback`
6. `feat(registry): pre-deploy phase — checklist before Ship for prod branches`
7. `feat(registry): post-deploy phase — monitor + verify after Ship`
8. `feat(registry): UI verify falls back to run when playwright unavailable`
9. `feat(registry): wire claude-mem fallbacks — learn-codebase for Recall, pathfinder for Refactor`
10. `feat(registry): verify phase primary upgraded to behavior-driven verify skill`
11. `feat(skill): cross-turn phase awareness via routing.log read`
12. `feat(commands): /pilot-trace — show current session's routing chain`
13. `feat(skills): migration-safety scaffold — interface + redirect to to-issues fallback`
14. `feat(skills): pre-deploy-checklist scaffold — interface + redirect to security-review fallback`
15. `feat(skills): post-deploy-monitor scaffold — interface + redirect to diagnose fallback`
16. `docs: production phases (v0.7) — README + landing page sync`

16 atomic commits, all on the current branch (`feat/pilot-v1`).

---

# Self-Review

**Spec coverage:**

- 7 new phases (Triage, Bootstrap, Performance, Security, Migration, Pre-deploy, Post-deploy) → Tasks 1, 2, 3, 4, 5, 6, 7 — one task each.
- 3 existing-skill fallback wires (`run`, `claude-mem:learn-codebase`, `claude-mem:pathfinder`) → Tasks 8 and 9.
- Verify-phase primary upgrade (`verify` over `superpowers:verification-before-completion`) → Task 10.
- 3 new-skill scaffolds (`migration-safety`, `pre-deploy-checklist`, `post-deploy-monitor`) → Tasks 13, 14, 15.
- Cross-turn phase awareness via `routing.log` read → Task 11.
- `/pilot-trace` command → Task 12.
- Force-fallback syntax → struck (already exists via literal-name shortcut from v0.6.1).
- README + landing page sync → Task 16.

**Placeholder scan:** No `TBD`, no `add appropriate handling`, no `similar to task N`. Every registry diff is shown verbatim; every scaffold has full SKILL.md content; the `/pilot-trace` command has its full implementation; SKILL.md insertion has its exact prose.

**Type / name consistency:** Phase numbers (0.5, 0.75, 4.5, 6.5, 7.5, 7.75, 8.5) used identically in registry rows, cheatsheet rows, README's "Production phases" table, and landing-page hero-side. Skill identifiers (`migration-safety`, `pre-deploy-checklist`, `post-deploy-monitor`) used identically across registry rows, scaffold directory names, and scaffold frontmatter `name:` fields.

**Order dependencies verified:** Tasks 1-7 are independent of each other (each inserts one row). Tasks 8-10 edit existing rows — order among them doesn't matter. Tasks 13-15 create scaffold files referenced by Tasks 5-7 registry rows — but pilot's fallback-when-missing rule means tasks 5-7 work even before their scaffolds exist (the registry fallback wins). So the literal execution order can be 1→16 sequentially, or grouped by stage in parallel within a stage.

**Risk surface:** All edits are additive. The only existing-row edits (Tasks 8, 9, 10) preserve the existing primary or demote it to fallback (no skill loses routing entirely). Worst-case rollback: revert any commit individually; pilot's behavior reverts to v0.6.1 for that phase.

---

# Execution staging

**This session (estimated 90-120 min):** Stages 1, 2, 4 — Tasks 1 through 12 plus Task 16. That's 13 commits. Each task is a 5-10 minute edit + commit cycle.

**Follow-up session(s):** Stage 3 — Tasks 13, 14, 15 produce real scaffolds (each scaffold is ~150 lines of structured SKILL.md). Could be done in this session if time permits, but each scaffold is also the spec for the eventual full-skill content, so it's worth a focused pass rather than rushing.

**Future sessions (queued, not in this plan):** Write the **full content** for `migration-safety`, `pre-deploy-checklist`, `post-deploy-monitor`. Each is a 500-1000 line skill with examples, fixtures, and integration with `/pilot-doctor`. One skill per session is realistic.

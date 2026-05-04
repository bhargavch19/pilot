# Dogfood prompts

Manual test fixtures. Paste each into Claude Code with pilot active and verify expected route.

| # | Prompt | Expected phase | Expected skill |
|---|---|---|---|
| 1 | "I want to build a CLI that scrapes job listings." | 1. Frame (code) | grill-with-docs |
| 2 | "There's a bug — the upload throws 500 sometimes." | 4. Debug | diagnose |
| 3 | "This auth.ts file has gotten messy." | 7. Refactor | improve-codebase-architecture |
| 4 | "What if we used Postgres instead of Mongo?" | 1. Frame (non-code) | grill-me |
| 5 | "Done — ready to merge." | 5. Verify (gate) | verification-before-completion |
| 6 | "Build a settings panel UI." | 3. Build (UI) | frontend-design |

## Pass criteria

For each prompt, pilot should announce which phase + skill in one line, then invoke that skill via the Skill tool. If pilot inlines logic instead of routing, that's a fail.

---
description: Bypass a specific pilot gate once. Args: --no-plan
argument-hint: --no-plan | --skip-tdd
allowed-tools: Bash
---

The user invoked `/pilot-bypass $ARGUMENTS`. Parse `$ARGUMENTS` and act:

- `--no-plan` → arm a one-shot plan-gate bypass:
  ```bash
  BYPASS_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/pilot"
  mkdir -p "$BYPASS_DIR"
  touch "$BYPASS_DIR/bypass-no-plan-once"
  echo "pilot --no-plan: plan-gate skipped on next Edit/Write."
  ```

- `--skip-tdd` → no hook enforces TDD (it's a soft rule), so this is purely
  conversational. Acknowledge it ("`--skip-tdd` noted — I'll proceed without
  red-green-refactor for this slice"), and continue. The user is on the hook
  for verifying their own work.

- No arguments or unknown flag → print usage:
  ```
  /pilot-bypass --no-plan   # one-shot plan-gate skip
  /pilot-bypass --skip-tdd  # acknowledge TDD skip (soft)
  ```
  Then stop.

After arming a bypass, continue with whatever the user asked for next.

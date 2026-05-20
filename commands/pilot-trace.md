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

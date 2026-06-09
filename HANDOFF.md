# Sparts Scoresheet — Handoff

## Current State
App builds and runs in Xcode simulator. Scoring mechanism complete. New Game and Archives buttons fixed.
Exported from Codea; all logic in SpartsScoresheet.codea/*.lua.

## Task Queue
1. [ ] Add pass direction to hand number labels
   - Sequence: left → right → Kreskin → hold (repeats every 4 hands)
   - Hand 1: pass left, Hand 2: pass right, Hand 3: the Kreskin, Hand 4: the hold
   - Find HAND label rendering via grep in SpartsScoresheet.codea/
   - Derive direction from hand number: cycle = {"left", "right", "Kreskin", "hold"}
   - direction = cycle[(handNumber - 1) % 4 + 1]
2. [ ] SPARTS logo tap is inert — needs `Sparts Scoresheet Intro.mov` located or the handler updated to not depend on a missing file

## Completed Tasks
- [x] Fix New Game button — tap was swallowed by right-side scroll handler in `touched()` before reaching fixed buttons section
- [x] Fix Archives button — same root cause as New Game (both are right-side buttons)

### Fix details
**File:** `SpartsScoresheet.codea/Scratch.lua`
**Root cause:** The `touched()` function processed right-side BEGAN events (for single-finger scrolling) at line 1015-1020, swallowing them with `return true` BEFORE the fixed buttons section at lines 1109-1112 could check them. Both New Game and Archives are positioned on the right side of the screen.
**Fix:** Reordered `touched()` so fixed buttons (now section 2) are checked before scroll handling (section 3). Taps on buttons return early; taps on empty space proceed to scroll handling as before.

## Known Issues
- File organization may be messy; cleanup pass may be needed
- Scratch.lua for example has a name suggesting temporary use but contains project critical code at present

## Notes
- Do not touch Assets/ dependency or archives folders unless explicitly instructed to
- Archives folder (Assets/Sparts Scoresheet.codea/) contains only index.json

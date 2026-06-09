# Sparts Scoresheet — Handoff

## Current State
App builds and runs in Xcode simulator. Scoring mechanism complete.
Exported from Codea; all logic in SpartsScoresheet.codea/*.lua.

## Task Queue
1. [ ] Add pass direction to hand number labels
   - Sequence: left → right → Kreskin → hold (repeats every 4 hands)
   - Hand 1: pass left, Hand 2: pass right, Hand 3: the Kreskin, Hand 4: the hold
   - Find HAND label rendering via grep in SpartsScoresheet.codea/
   - Derive direction from hand number: cycle = {"left", "right", "Kreskin", "hold"}
   - direction = cycle[(handNumber - 1) % 4 + 1]

## Completed Tasks
(none yet)

## Known Issues
- File organization may be messy; cleanup pass may be needed
- Scratch.lua for example has a name suggesting temporary use but contains project critical code at present

## Notes
- Do not touch Assets/ dependency or archives folders unless explicitly instructed to
- Archives folder (Assets/Sparts Scoresheet.codea/) contains only index.json
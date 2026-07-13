# Sparts Scoresheet — Handoff

## Current State

**Commit:** `b1173c4` on `main` (plus this HANDOFF update). App builds, launches,
and renders correctly on iPhone 17 simulator (`1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044`).

**The app is landscape-only by design** — the scoresheet renders sideways relative
to the simulator's portrait chrome. Not a bug; don't chase "rotation."

## Completed this session — dealer tracking + archive refinements

### Dealer tracking (who deals each hand)
- **Info label** reads `"N: pass <dir> - dealer: <Name>"` (dropped the old `"HAND "`
  prefix, added `"dealer: "`). Applies to every hand.
- **Hand 1's dealer name** is blue and tappable; tapping cycles the first dealer
  `P1 → P2 → P3 → P4`. **Hand 2's dealer name** is blue and tappable; tapping cycles
  the second dealer **only between the two players on the team opposite hand 1's
  dealer**. Hands 3+ derive automatically (`_dealerForHand`: hand3 = partner of
  dealer1, hand4 = partner of dealer2).
- **Second-dealer rule:** always one of the opposite team's two players. When the
  first dealer changes teams, the second dealer resets to that team; when it stays on
  the same team, the choice is preserved. See `ScoreSheets:_setFirstDealer` /
  `_setSecondDealer` / `_cycleFirstDealer` / `_cycleSecondDealer`.
- **Dealer name-box** in the scoresheet grid gets a **no-fill blue outline** (inset
  inside the cell borders) for each hand's dealer. `ScoreSheets` sets
  `table._dealerGlobalIndex` before drawing; `ScoreTable` outlines that cell.
  Theme color: `Theme.nameDealerBox`.
- **Persistence:** `firstDealer` and `secondDealer` are saved/loaded
  (`SaveAndLoad.lua`), applied **after** the `sheets` reconstruction in
  `loadGameState` (init resets them to defaults, so order matters).

### Bug fixed — hand-1 player names reverted on reload
Root cause: `ScoreSheets:init` seeds the hand-1 name `UITextField`s with `"Player N"`
placeholders **and writes them into the model**, clobbering names just loaded from
disk — but only the first table (the only one with editable fields at init). Fix:
`loadGameState` re-applies the saved hand-1 names (model + text field) from disk
**after** the reconstruction. Hands 2+ were never affected. All scoresheet data now
persists (names, bids, tooks, hearts, queens, moon, coast toggle, both dealers,
hand count).

### Archive refinements (`ArchiveExporter.lua`, `ArchiveBrowser.lua`)
- Archive **image** hand labels now match the live heading incl. the dealer name.
  The dealer box outline already carried over (exporter draws `tables[i]:draw()` with
  `_dealerGlobalIndex` still set from the live frame).
- Archive image **date** pinned 5px below the top edge (was crowding the hand label).
- **Summary block** (browser) redesigned: one row per team pairing members → score,
  plus a bottom gold **`Winner: <members>`** line. Higher `gameTotal` wins. Replaces
  the old ambiguous `"Final Scores: X to Y"`.

## Architecture notes worth keeping
- **Archives are stored, not regenerated.** `ArchiveExporter` `saveImage`s the PNG +
  `.json` + index entry at creation (New Game → Confirm); `ArchiveBrowser` `readImage`s
  the stored PNGs. Display cost does not grow with archive count.
- **Global player index within a hand:** 1=team1/p1, 2=team1/p2, 3=team2/p1,
  4=team2/p2. Teammates `{1↔2, 3↔4}` (`_partnerOf`).
- **No touch injection in the workflow** — `simctl` can't tap. Tappable behavior
  (dealer cycling) was verified by the user manually; everything else was verified by
  auto-triggering at launch (temporary `_TEST_*` one-shots in `ScoreSheets:draw`,
  always reverted) and by injecting saved state into the sim's NSUserDefaults plist
  (`:SpartsScoresheet:` keys) then relaunching.

## Orchestrator delegation economics (this session)
Implementation was delegated to Haiku subprocesses per the `xcode-orchestrator` skill;
the orchestrator tested via `xcodebuild`/`xcrun`. Running total in `DELEGATION_LOG.tsv`:
**11 delegations, ~24.3k output tokens, ≈ $0.35** pushed to Haiku. Note: for the
smallest one-line/one-value edits the delegation overhead outweighed the context
savings (the savings mechanism is offloading bulk reads, not tiny edits).

## Task Queue
1. [ ] Fix SPARTS logo tap to play intro video (`_spartsHit` handler exists in
   `ScoreSheets:touched`; radius now scales with `logoSize`).
2. [ ] (open) whatever the user assigns next.

## Simulators
- iPhone 17: `1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044` (USE THIS ONE)
- iPhone 16e: `0EF8AE50-8899-40DD-A77E-359C06732886` (other project, do not use)
- Heavy install/terminate cycling can shuffle the app's CoreSimulator data container,
  surfacing a different saved game. Archives and code are unaffected; it's a sim-only
  artifact. Use `xcrun simctl get_app_container <udid> <bundle> data` for the live one.

## History — resolved launch failure (kept for reference)
Earlier session fixed the app showing only a placeholder and never building the
scoresheet. Two causes: (1) `Package.resolved` (pins `twolivesleft/Runtime`) got
gitignored in `27bfa6a`, so fresh builds drifted to a broken `branch=main` revision
that touched UIKit off the main thread; (2) unresolved merge-conflict markers in
`ScoreSheets.lua`. Fixed by repinning to `924c512` and un-gitignoring `Package.resolved`.
If the scoresheet ever fails to appear with `parentViewController` / off-main-thread
layer errors in the console, check `Package.resolved` before assuming a Lua bug (see
CLAUDE.md "SPM Dependency Pinning").

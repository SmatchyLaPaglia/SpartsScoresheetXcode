# Sparts Scoresheet — Handoff

## Current State
App builds and runs in Xcode simulator. New Game and Archives buttons fixed.
SPARTS logo tap is partially fixed — deferred to draw loop but still not working.
Exported from Codea; all logic in SpartsScoresheet.codea/*.lua.

## Uncommitted Changes
`SpartsScoresheet.codea/Scratch.lua` has two changes (not committed):

1. **`draw()` line ~343**: Added deferred video presentation block:
```lua
if self._pendingVideoAsset then
  local a = self._pendingVideoAsset
  self._pendingVideoAsset = nil
  if videoPlayer and a then
    videoPlayer:showAndAutoplayMOV(a)
  end
end
```

2. **`touched()` line ~943**: Changed direct `showAndAutoplayMOV` call to deferred flag:
```lua
-- BEFORE (original):
videoPlayer:showAndAutoplayMOV(asset.Sparts_Scoresheet_Intro)
-- AFTER (current):
self._pendingVideoAsset = asset["Sparts Scoresheet Intro"]
```
Note: bracket notation `asset["Sparts Scoresheet Intro"]` matches the actual filename with spaces. The original dot notation `asset.Sparts_Scoresheet_Intro` used underscores which don't match.

## Task Queue
1. [ ] **Fix SPARTS logo tap to play intro video** — CURRENT TASK, partially done
2. [ ] Add pass direction to hand number labels
   - Sequence: left → right → Kreskin → hold (repeats every 4 hands)
   - Hand 1: pass left, Hand 2: pass right, Hand 3: the Kreskin, Hand 4: the hold

## SPARTS Logo Tap — Known Facts

### File locations
- **Video file**: `SpartsScoresheet.codea/Sparts Scoresheet Intro.mov` (369 MB, verified in app bundle)
- **Handler**: `Scratch.lua` ~line 938 in `function ScoreSheets:touched(t)`
- **Hit target set**: `Scratch.lua` ~line 488 in `function ScoreSheets:draw()`
- **Video player**: `Assets/CodeaAVPlayer.codea/CodeaAVPlayer.lua` — `CodeaAVPlayer:showAndAutoplayMOV()`
- **Video player init**: `Main.lua` line 172 — `videoPlayer = CodeaAVPlayer()` (global)
- **Asset dependency loaded**: `Main.lua` line 1 — `require(asset.documents.CodeaAVPlayer)`

### Code flow
1. **`draw()`** sets `self._spartsHit = {x=WIDTH/2, y=spY, r=90}` every frame (line ~488). The SPARTS text is rendered at `(WIDTH/2, spY)` in screen space (bottom-left origin), outside the table's pushMatrix/translate block but with `sy` (scroll offset) manually added.
2. **`touched()`** section "1) Track touches FIRST" (~line 938) checks if `t.state == BEGAN` and `self._spartsHit` exists, then does a radius hit test.
3. On hit: sets `self._pendingVideoAsset` and returns true (current code).
4. Next `draw()` frame: picks up `_pendingVideoAsset`, calls `videoPlayer:showAndAutoplayMOV(a)`.

### Architecture note
The user provided this hint: **"Crashes can happen when code in objc callbacks tries to interact with Codea's drawing system."**

The `showAndAutoplayMOV` function calls `objc.viewer:presentViewController_animated_completion_()` which mutates the view hierarchy. The original code called this directly from `touched()` (touch dispatch). The current deferred approach calls it from `draw()` (render loop). This followed the same pattern as the archive flow which uses `_archivingStage` to defer heavy objc work to `draw()`.

### What has been tried (and failed)
1. **Original**: Direct `showAndAutoplayMOV` call from `touched()` — silent failure, nothing visible
2. **Underscore asset name**: `asset.Sparts_Scoresheet_Intro` — likely resolved to nil since filename has spaces
3. **Bracket asset name** (current): `asset["Sparts Scoresheet Intro"]` — still not confirmed working
4. **Debugging with print()/devLog()**: Added extensive logging but couldn't see output via `xcrun simctl log show` — `objc.log()` bridge may not work during draw/touch loop, and `print()` output goes to stdout only visible in Xcode console
5. **Deferred to draw loop** (current): Sets flag in touched(), calls showAndAutoplayMOV in draw() — still not working
6. **Red flash visual indicator**: Added but then removed as part of debug cleanup — caused black screen when combined with other debug clutter

### Possible remaining issues to investigate
- **Asset resolution**: `asset["Sparts Scoresheet Intro"]` may still be nil. Could try enumerating `asset` keys to find the actual name, or try without spaces, or try using a direct file path with `objc.NSURL`
- **`videoPlayer` availability**: The video player is set as a global in `Main.lua`. Verify it's not nil in the draw loop — the current code guards with `if videoPlayer and a then`
- **`_spartsHit` positioning**: The hit target uses `spY = topY + (m.leftRowH * 1.85) + sy`. Verify coordinate system matches touch coordinates (both should be bottom-left origin screen space). The SPARTS text renders with `text("SPARTS", WIDTH/2, spY)` and `textMode(CENTER)`.
- **Touch not reaching handler**: If `print()` output is invisible, the only way to confirm tap detection is a visible side-effect. Try setting a background color change or toggling a visible element on hit.
- **Scroll sensor touch consumption**: The scroll sensor covers the full screen with `doNotInterceptTouches = false` by default. It sets `doNotInterceptTouches = true` on BEGAN inside its `onTouched` callback, but this might not take effect retroactively. If the Codea runtime dispatches to sensors before calling global `touched()`, the SPARTS handler might never receive BEGAN events.
- **Alternative video approach**: Instead of `AVPlayerViewController`, try using `objc.AVPlayerLayer` embedded in the existing view hierarchy, or try a different presentation method.

## Completed Tasks
- [x] Fix New Game button — tap was swallowed by right-side scroll handler in `touched()` before reaching fixed buttons section
- [x] Fix Archives button — same root cause as New Game (both are right-side buttons)

### Fix details (New Game / Archives)
**File:** `SpartsScoresheet.codea/Scratch.lua` (committed: `2feb212`)
**Root cause:** The `touched()` function processed right-side BEGAN events (for single-finger scrolling) swallowing them with `return true` BEFORE the fixed buttons section could check them.
**Fix:** Reordered `touched()` so fixed buttons (section 2) are checked before scroll handling (section 3).

## Known Issues
- File organization may be messy; cleanup pass may be needed
- Scratch.lua name suggests temporary use but contains project-critical code
- `print()` / `devLog()` output from draw/touch loop not visible via `xcrun simctl log show`

## Notes
- Do not touch Assets/ dependency or archives folders unless explicitly instructed to
- Archives folder (Assets/Sparts Scoresheet.codea/) contains only index.json
- Simulator: iPhone 16e (0EF8AE50-8899-40DD-A77E-359C06732886)
- Bundle ID: com.JesseWonderClark.SpartsScoresheet
- Build/test commands in CLAUDE.md

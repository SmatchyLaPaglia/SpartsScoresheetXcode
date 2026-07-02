# Sparts Scoresheet — Handoff

## Current State

**Commit:** `102cb4f` (detached HEAD) — "fix: horizontal drag tolerance, tap vs drag animation, stepPx, hint position, movieActive gate"

App builds and runs from Xcode on iPhone 17 simulator (`1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044`).

## Session Failures — Archive Fix

### Task
Archives (generated when user taps "New Game" → Confirm) must save to persistent storage and appear in the Archives browser. On simulator, archives generated in one session vanish after Xcode rebuild. On device, they never appeared at all.

### What was attempted

| Attempt | Approach | Result |
|---------|----------|--------|
| 1 | Revert to `asset.documents` prefix | User rejected — `asset.documents` is for bundled dependencies, not file I/O |
| 2 | `asset .. "SpartsArchives/"` → `asset.SpartsArchives .. "/"` (dot notation) | Built and ran, but archives empty in browser |
| 3 | Invented new helper functions (`_archReadIndex`, `_archHideBundled`, etc.) creating a parallel merged-index system | Built and ran, archives empty in browser. User said "you invented a new way instead of fixing existing patterns" |
| 4 | Reverted all changes, made minimal edit: `asset .. "SpartsArchives/"` → `"Documents:SpartsArchives/"` on writes, added `_readArchiveText`/`_readArchiveImage` helpers for dual-source reads | Built and ran, archives empty in browser |

### Net result
**Zero progress.** Archives still don't appear in the browser after "New Game" → Confirm. Working tree has uncommitted changes to `AchiveExporter.lua` and `ArchiveBrowser.lua` that don't solve the problem.

### Fundamental unanswered question
**Are the images failing to be generated (saveImage/saveText silently failing), or are they being saved correctly but failing to be loaded/displayed (readImage/readText returning nil)?**

Determining this requires a diagnostic that isolates save from load. For example:
- After archiving, check whether files exist in the sandbox `Documents/` folder using `xcrun simctl` to inspect the app's data container
- Or add a Codea-side debug path that tries to read back the image immediately after saving it and reports success/failure via `print()` or a visible on-screen indicator

### Known working pattern (Quozzy project)
Another Codea Xcode export project uses `"Documents:"` as a string prefix for `saveImage`/`readImage`:
```lua
saveImage("Documents:LoadingImage", img)
readImage("Documents:LastMatchReplayAvatar")
```
This was confirmed working in Quozzy. The same approach was applied in attempt 4 but still failed — suggesting the problem may be in the archiving flow itself (e.g., `_doSnapshotNow` or `ArchiveExporter:update` not actually being called, or the rendered image being nil/empty) rather than in the file path.

## Notes on Claude's behavior
- Repeatedly invented new architectures instead of making minimal fixes to existing patterns
- Failed to run a diagnostic to determine whether the failure is on the save or load side before attempting fixes
- Built and tested each attempt against an empty state (no archive had been saved during that session) so the "archives empty" result was the same regardless of whether the fix was correct or not
- Did not test the full flow: New Game → Confirm → Archives browser

## Git State
- **Working tree**: `AchiveExporter.lua` and `ArchiveBrowser.lua` dirty (attempt 4 changes — `"Documents:SpartsArchives/"` paths)
- **stash@{0}**: Scroll sensor fix in Scratch.lua + handoff edits (from session before last)
- **stash@{1}**: Orchestrator pattern and hand-passing labels (older)

## Task Queue
1. [ ] **CRITICAL: Fix archive generation and display**
2. [ ] Fix SPARTS logo tap to play intro video
3. [ ] Add pass direction to hand number labels

## Simulators
- iPhone 17: `1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044` (USE THIS ONE)
- iPhone 16e: `0EF8AE50-8899-40DD-A77E-359C06732886` (other project, do not use)

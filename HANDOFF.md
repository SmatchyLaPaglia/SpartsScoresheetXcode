# Sparts Scoresheet — Handoff

## Current State

**Commit:** `b5fcfb8` on `main`. Working tree clean.

App builds, launches, and renders the scoresheet correctly on iPhone 17 simulator
(`1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044`), confirmed after a fresh simulator boot.

**The app is landscape-only by design.** The scoresheet renders sideways relative to
the simulator's portrait status bar — this is expected, not a bug. Don't rabbit-hole
on "rotation" as a symptom.

## Resolved: launch failure (scoresheet never appeared)

This session fixed the app failing to launch — it would show only a placeholder
screen (previously "HELLO FROM SPARTS", now a "LAUNCH FAILURE" screen if it recurs)
and never construct the scoresheet.

**Root cause:** two independent bugs, both introduced around the `tmepo` merge:

1. `Package.resolved` (pins the `twolivesleft/Runtime` SPM package, which provides
   Codea's `LuaKit`/`RuntimeKit` runtime) got accidentally gitignored in `27bfa6a`.
   The package requirement is `branch = main` with no fixed tag, so every fresh
   build silently re-resolved to whatever was newest on that branch. The drifted
   commit's threaded driver crashes touching UIKit off the main thread
   (`viewer.mode`, `UITextField` construction both throw
   `attempt to index a nil value (field 'parentViewController')`), which aborted
   `ScoreSheets:init` every time.
2. `ScoreSheets.lua` had two unresolved git merge-conflict markers left over from
   the `tmepo` merge, making the file invalid Lua — Codea couldn't compile it, so
   `ScoreSheets` was never even defined.

**Fix:** repinned `Package.resolved` to the last known-good revision (`924c512`,
confirmed working at commit `91229e4`), stopped gitignoring it, and resolved the
merge conflicts. See commit `b5fcfb8` for full details and the diagnostic trail.

**Gotcha for future sessions:** see the new "SPM Dependency Pinning" section in
CLAUDE.md. If the scoresheet ever fails to appear again and the Xcode console shows
`Modifying properties of a view's layer off the main thread` /
`parentViewController`, check `Package.resolved`'s pinned revision before assuming
it's a Lua bug.

## Archive investigation — needs re-verification

A prior session spent 4 attempts trying to fix archives (generated via "New Game" →
Confirm) not appearing in the Archives browser, with zero resolved progress. That
investigation predates this session's launch fix — depending on exactly when the
`Package.resolved`/merge-conflict breakage started, some or all of that testing may
have been run against a build that wasn't actually launching correctly, which would
invalidate the "archives empty" observations.

**Next step:** re-test the full flow (New Game → Confirm → Archives browser) fresh,
now that the app reliably launches, before resuming any archive-specific debugging.
Don't trust old findings from before this fix.

## Git State

- Working tree: clean.
- **stash@{0}**: "dumb interface nothign" (main)
- **stash@{1}**: "dumb interface nothing" (tmepo branch)
- **stash@{2}**: uncommitted Scratch.lua and HANDOFF.md changes (main)
- **stash@{3}**: orchestrator pattern and hand-passing labels (main)
- None of these were touched this session — unverified, may be stale.

## Task Queue

1. [ ] Re-verify archive generation/display now that the app launches (see above)
2. [ ] Fix SPARTS logo tap to play intro video
3. [ ] Add pass direction to hand number labels

## Simulators

- iPhone 17: `1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044` (USE THIS ONE)
- iPhone 16e: `0EF8AE50-8899-40DD-A77E-359C06732886` (other project, do not use)

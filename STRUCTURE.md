# Sparts Scoresheet — Structure Guide

Purpose of this doc: give a Claude Project (chat, no code access) enough of a
model of this codebase to reason about *where a bug likely lives* from a bug
report alone, without reconstructing the implementation. It describes
responsibilities, data flow, and known sharp edges — not line-by-line logic.

For build/run/simulator instructions and known infra gotchas (simulator
hangs, SPM package pinning), see `CLAUDE.md` in the repo root — this doc is
about the Lua app logic, not the toolchain.

## What the app is

Sparts is a scoring app for a 4-player, 2-team partnership card game that
combines Spades and Hearts rules ("Sparts"). One team plays a "hand"; each
hand contributes a Spades sub-score and a Hearts sub-score; those accumulate
into running totals across a whole game (ends at 600 points). The UI is a
single landscape scoresheet: two stacked mini-tables (Team 1 rows, Team 2
rows), each row holding per-player bid/took inputs, hearts/queen/moon
checkboxes, and computed score columns. Multiple "hands" stack vertically
and the user scrolls between them. There's also an archive system that
snapshots a finished game to disk (PNG + JSON) for later browsing.

## Tech stack & runtime model

This is a **Codea-exported Xcode project**: all app logic is Lua, run by an
embedded Lua VM inside a thin Swift/ObjC host (Codea's runtime). Do not look
for MVC/SwiftUI patterns — there is no view controller hierarchy for the
game itself, just:

- `setup()` — called once at launch (`Main.lua`)
- `draw()` — called every frame (~60fps); the *entire* UI is re-drawn from
  scratch every frame using immediate-mode drawing calls (`fill`, `rect`,
  `text`, etc. — all Codea globals, not defined in this repo)
- `touched(t)` — called for every touch event (began/moving/ended/cancelled)
  with a single touch struct `t = {id, state, x, y, deltaX, deltaY, ...}`

Because draw() re-runs every frame, **all "state" is just Lua tables held in
globals/closures** — there is no separate render-vs-model split beyond what
each class does internally. A visual glitch is almost always a `draw()`
math/order bug; a stuck or misrouted touch is almost always a `touched()`
routing/ownership bug (see "Touch routing" below).

A handful of globals come from the Codea runtime itself and are **not
defined anywhere in this repo**: `color()`, `rect()`, `text()`, `pushStyle`/
`popStyle`, `pushMatrix`/`popMatrix`/`translate`, `tween`, `image()`,
`readImage`/`saveImage`/`readText`/`saveText`, `json.encode`/`json.decode`,
`readLocalData`/`saveLocalData`/`clearLocalData` (a simple key→value local
store), `WIDTH`/`HEIGHT`/`DeltaTime`/`ElapsedTime`, `CurrentOrientation`,
`objc.*` (Codea's Objective-C bridge). If a bug report mentions one of these
behaving oddly, the cause is more likely in *how this codebase calls them*
than in a bug you can fix by editing their (nonexistent, in this repo)
implementation.

`objc.*` calls (native UIKit bridging, used for player-name text fields,
alerts, and safe-area insets) are a common source of "works sometimes,
crashes/blanks sometimes" bugs — see "Name text fields" below.

## Class system (`Class.lua`)

A tiny custom class implementation: `class(base)` returns a callable table;
calling it (`Foo(...)`) allocates an instance, sets its metatable, and runs
`init`. Supports single inheritance (shallow-copies `base`'s fields) and a
custom `__index` override mechanism. Every "class" in this codebase
(`ScoreTable`, `ScoreSheets`, `IncrementingCell`, `CheckboxCell`, `Sensor`,
`ArchiveBrowser`, `ArchiveExporter`, `ScoreLedger`) is built with this. If
something behaves like "a method isn't being found" or "base class state
leaks between instances," this file's `__index` chaining logic is the place
to scrutinize (in particular: base-class table *values* — not just
functions — are shallow-copied at class-definition time, so mutable
base-class tables can be shared across subclasses unless re-initialized in
`init`).

## Core data model

A **team**:
```
{ players = { {name,bid,took}, {name,bid,took} },
  hearts, queensSpades, moonShot,
  spadesScore, heartsScore, handBags,        -- this hand, computed
  spadesTotal, heartsTotal, gameTotal, allBags, -- running, computed
  _oppMoonBonus }                             -- transient, ledger-managed
```
`bid`/`took`/`hearts` are `nil` until the user has explicitly entered them
(nil = "not yet entered", distinct from `0`). A lot of ready/not-ready logic
throughout the scoring code hinges on this nil-vs-zero distinction — a bug
where scores show `--` when they shouldn't (or vice versa) is usually a
broken nil-check somewhere in `ScoreRules.lua` or `ScoreLedger.lua`.

A **hand** = one `ScoreTable` instance, holding two teams (`self.teams[1]`,
`self.teams[2]`) plus the interactive cell widgets for that hand.

A **game** = `ScoreSheets`, which owns an ordered array `self.tables` of
`ScoreTable`s (one per hand played so far) plus all the chrome: scroll
position, buttons, dealer tracking, archive browser/exporter, keyboard
avoidance, name text fields.

## File map

### `Main.lua`
Entry point. Defines the sample/default `teams` table (unused once a real
game starts), global layout knobs (also re-declared/overridden in
`ScoreTable.lua` — see note below), `devLog` (dual console logger — Codea
console + Xcode console via `objc.log`), and the three Codea lifecycle
functions: `setup()` (builds `sheets = ScoreSheets(...)`, wires app-lifecycle
persistence hooks via `LifecycleObserver`, restores saved state), `draw()`
(delegates to `sheets:draw()`, or shows a red "LAUNCH FAILURE" screen if
`sheets` is nil — meaning `ScoreSheets:init` threw), `touched(t)` (delegates
to `sheets:touched(t)`).

**Note:** `layout` and `LeftCols` are defined identically in both
`Main.lua` and `ScoreTable.lua` (globals, last one loaded wins per Lua load
order — `ScoreTable.lua`'s copy is what's actually live once it loads,
since Codea loads files and the same global gets reassigned). If someone
edits layout knobs in `Main.lua` expecting an effect, check `ScoreTable.lua`
first.

### `ScoreTable.lua`
Renders **one hand** (both teams, 4 player rows) and owns that hand's
interactive widgets. Key pieces:
- `ALT_COLS` — the authoritative column layout spec (14 columns: NAME,
  BTLABEL, BID, TOOK, HEARTS, QUEEN, MOON, R1–R6 [hand+total score columns],
  GRAND). `buildEdges()` turns these into absolute x-pixel edges each frame
  in `:layout()`. **All cell positioning bugs trace back to this table and
  `:layout()`** — if a column is misaligned or a tap lands on the wrong
  cell, start here.
- `:init(teams)` creates 10 `IncrementingCell`s (bid/took ×2 players ×2
  teams, plus hearts ×2 teams) and 4 `CheckboxCell`s (queen/moon ×2 teams).
- `:layout()` recomputes every cell's pixel frame from `WIDTH`/`HEIGHT` and
  notch/orientation info every single frame (not cached across frames
  except in `self.metrics`). It also positions the long-press sensors used
  for name-box interactions.
- `:draw()` calls `:layout()`, then draws headers, name cells (with
  placeholder-gray vs. real-name-black text color), the dealer's blue
  outline box, chip labels ("bid/took", "hearts", "queen", "moon"), the
  interactive cells, and the right-hand score table (reads already-computed
  `team.spadesScore` etc. — **this file does not compute scores**, it only
  formats/displays what `ScoreLedger` already wrote onto the team tables).
- `:touched(t)` fans the touch out to every cell + long-press sensor, then
  has **special-cased moon/queen exclusivity logic**: checking one team's
  moon box forces that team's hearts to 13 and queen to true, and force-
  clears the other team's moon/hearts/queen. Same mutual-exclusion pattern
  for the queen checkboxes alone. This is duplicated conceptually in
  `ScoreRules.syncHeartsMoon` (see below) — **two independent
  implementations of the same "only one team can moon" rule exist**: one
  here (immediate UI feedback on tap) and one in `ScoreRules.lua` (the
  authoritative one, re-run every frame from `ScoreLedger`). If they ever
  disagree, the ledger's version wins visually since it runs after touch
  handling and overwrites the team tables, but a one-frame flicker or a
  weird intermediate state is possible here.
- Autosaves (`saveGameState()`) whenever a touch on this table ends.

### `ScoreRules.lua`
Pure functions, no UI, no side effects except within `syncHeartsMoon`
(which intentionally mutates the two teams it's given). This is the
**scoring rulebook** and the first place to look for "the math is wrong"
bugs:
- `spadesHand(team)` — team bid = sum of both players' bids; only bids from
  players with `bid > 0` count toward "took for bid"; nil-bid players'
  tricks count as bags regardless of outcome; makes bid → `+10×bid`, misses
  → `-10×bid`; nil bid handled separately with a flat ±100 bonus per
  nil-bidding player (going 0-for-0 = +100, taking any tricks on a nil bid =
  -100).
- `applySandbagPenalty(allBags, per=10, penalty=100)` — every 10 cumulative
  bags costs 100 points and resets the bag counter's hundreds-place
  (`allBags % 10` remains). Called from `ScoreLedger`, not from here
  directly against a team.
- `heartsHand(team)` — `hearts×4 + (queen ? 52 : 0) + (moon ? -104 : 0) +
  _oppMoonBonus`. Note the moon shooter scores `52 (queen) + 13×4 (hearts) -
  104 (moon) = 0` — shooting the moon nets the shooter 0 and the opponent
  +104 (via `_oppMoonBonus`, set by `syncHeartsMoon`).
- `syncHeartsMoon(teams)` — **the authoritative single-moon-shooter
  invariant**. Given both teams for one hand, if either has `moonShot ==
  true`, forces: shooter → hearts=13, queen=true; other team → hearts=0,
  moon=false, queen=false, `_oppMoonBonus=104`. If *both* teams somehow have
  moonShot true simultaneously, team 1 wins arbitrarily. This function is
  called once per hand, per frame, from `ScoreLedger:computeSnapshotsForTables`
  — so it's always re-derived from current checkbox state, never trusted as
  already-consistent.
- `spadesReady`/`heartsReady`/`queenIsAssigned`/`heartsTotalDisplayReady` —
  gate functions controlling when a hand shows real numbers vs `"--"`. If a
  score cell is stuck on `"--"` that a user expects to be filled in, or
  shows a value prematurely, check these first.

### `ScoreLedger.lua`
The **single source of truth for all computed/derived numbers**, recomputed
from scratch every frame in `ScoreSheets:draw()` (`self.ledger =
ScoreLedger(...)`, then `computeSnapshotsForTables(self.tables)`). It walks
hands in order (hand 1 → N), maintaining running totals per team:
- Spades total accumulates unconditionally once a hand's spades are "ready"
  (bags penalty applied inline via `ScoreRules.applySandbagPenalty`).
- **Hearts total only starts accumulating once a "chain" begins** — the
  first hand (`hi == 1`) with a non-nil hearts score starts the chain
  (`rs.heartsReady = true`), and from then on every subsequent hand's hearts
  score (even nil/unplayed ones — no, only non-nil ones) adds in. If hearts
  never becomes ready on hand 1, hand 2+ hearts values still won't display
  as totals even if entered, **unless hand 1 eventually gets hearts data
  too** (re-run every frame, so this is dynamic, not a one-time miss). This
  chain rule is the most likely place for a "why isn't my hearts total
  showing" bug report to trace to.
- Game total = `spadesTotal - heartsTotal`, shown only once both exist.

There is no caching between frames and no incremental update — every hand's
snapshot is fully recomputed from the raw `teams` data every draw. This
means **the ledger cannot itself introduce stale-state bugs**, but it also
means anything that mutates `teams[*].players[*].bid/took` etc. outside the
normal cell → `syncBack()` → ledger pipeline can produce inconsistent
results until the next frame.

**Known inconsistency:** `Tests.lua` calls `ScoreLedger:recompute()` and
`ScoreLedger:finalizeHandFromTeams()` — neither method exists on the current
`ScoreLedger` class (only `:init` and `:computeSnapshotsForTables` do).
Those tests (and the `runLedgerOrderBugProbe()` helper) are stale relative
to the current ledger API and would error if run. Treat `Tests.lua`'s
hearts/moon-normalization tests (`T.test_moon_*`, `T.test_ledger_moon_*`) as
the currently-valid ones; the ledger-recompute-based probes are dead code
describing an earlier ledger design.

### `ScoreSheets.lua` (largest file — the app "controller")
Owns the whole-screen experience: the stack of hands, scrolling, all fixed
buttons, dealer-of-record tracking, archive integration, and the bridge to
native UIKit text fields for player names.

- **`:init`**: builds the first `ScoreTable`, sets up the whole-screen
  scroll `Sensor`, builds `tzBtn`/`newGameBtn`/`archiveBtn`/`newBtn` (each a
  plain table with its own `Sensor`, not a class), and — notably — creates
  four raw `objc.UITextField` instances directly attached to the host
  UIView for player-name entry (Codea's own text tools aren't used for this
  because Codea has no native multi-field keyboard-avoidance story; this
  app rolls its own via the `iOS Keyboard Avoider` dependency). Text field
  placeholder logic ("Player 1".."Player 4") and propagation to *all*
  hands' team tables lives here in the delegate callbacks.
- **`:draw()`**: computes notch/orientation padding, calls
  `ScoreTable:syncBack()` on every hand to pull cell values into `teams`,
  invokes the ledger, updates `dst.spadesScore` etc. on every team from the
  ledger snapshot, checks for game-over (>=600 total on the *last* hand
  only), then draws every hand stacked vertically with a scroll offset,
  plus dealer labels/info icons, the SPARTS logo (tap → intro video),
  top buttons, the "NEW HAND" button (or game-over banner), a scroll-mode
  overlay tint, an archiving/loading busy overlay, and a one-time
  "swipe to scroll" hint. Also drives the archive export/load state
  machines (`_archivingStage`, `_archiveLoadStage` — deliberately delayed
  by one frame so the busy overlay has a chance to actually render before
  the (potentially slow) synchronous export/load work runs — see
  "one-frame stall pattern" below).
- **`:touched(t)`**: this is the most complex control-flow in the codebase
  and the first place to look for **any misrouted-touch bug** (taps not
  registering, drags fighting each other, ownership getting "stuck"). It
  checks, roughly in this order: archive exporter/browser modal capture →
  scroll-hint dismissal → dealer-name / info-icon / SPARTS-logo hit-testing
  (screen-space rects computed during the previous draw) → active-touch
  bookkeeping (`_activeTouches`, `_touchOrder`, `_futile` for the "you
  should swipe on the right side" hint) → fixed buttons (new hand /
  timezone / new game / archive) → **two-finger scroll mode** (exactly 2
  simultaneous touches always wins and swallows everything, cancelling any
  cell that had grabbed ownership of either finger) → single-finger scroll
  *but only on the right-side score columns and only if no
  `IncrementingCell` already owns that touch id* → **if an
  `IncrementingCell` owns this touch id, always forward to it** (bypassing
  the normal Y-bounds check, so horizontal drags on a value cell aren't
  broken by vertical finger drift) → keyboard avoider → finally, normal
  per-table forwarding (`forwardTouchToTables`, which offsets `y` by each
  table's scroll position and only forwards if the touch's re-mapped `y`
  falls within that table's vertical band).
  **Ownership** for drag/step gestures on numeric cells is tracked in a
  *class-level* table `IncrementingCell._owners[touchId] = cellInstance`
  (see `IncrementingCell.lua`), not per-instance — this is intentional
  (only one cell can ever own a given finger) but means a bug in releasing
  ownership on `ENDED`/`CANCELLED` would cause a cell to "stick" and ignore
  all future touches with that (recycled) id until the app is restarted or
  another touch begins there. `CheckboxCell` has the identical
  `_owners` pattern.
- **Dealer tracking** (`_dealerForHand`, `_setFirstDealer`/
  `_setSecondDealer`, `_cycleFirstDealer`/`_cycleSecondDealer`): the app
  only ever asks the user to name hand 1's dealer and hand 2's dealer
  (tap the blue name); every other hand's dealer is derived by a fixed
  4-hand rotation (`_partnerOf` table: player 1↔2 are partners, 3↔4 are
  partners) assuming standard rotation. If dealer names are wrong on hand
  3+, check `_dealerForHand`'s modulo-4 logic and `_partnerOf`, not the
  per-hand data.
- **Persistence**: there are genuinely **two separate, overlapping
  persistence mechanisms** running side by side:
  1. `SaveAndLoad.lua`'s `saveGameState`/`loadGameState`, which writes one
     flat key per field (`h{hand}t{team}p{player}bid`, etc.) via
     `readLocalData`/`saveLocalData` (Codea's local KV store), triggered by
     app lifecycle events (`LifecycleObserver` background/terminate hooks
     in `Main.lua`) and by every completed touch in `ScoreTable:touched`.
  2. `ScoreSheets:_saveLocalGame`/`_loadLocalGame`, which serializes the
     *entire* game as one JSON blob to `asset.localGame` (a bundled/local
     asset file), called from `:init` only (`_loadLocalGame`) — there is no
     matching automatic call site for `_saveLocalGame` visible in the
     current flow (search for call sites before assuming it fires
     automatically).
  If save/restore behaves inconsistently after a relaunch (e.g. some fields
  restore, others don't), check which of these two paths actually ran, and
  in what order — `loadGameState()` in `Main.lua:setup()` runs, then
  further down `ScoreSheets:init` calls `self:_loadLocalGame()`, meaning
  **the JSON-blob load can run and overwrite what `loadGameState()` just
  restored**, depending on whether `asset.localGame` has content.
- **Archives**: `archiveExporter:request()` just sets a `pending` flag;
  the actual snapshot work happens one frame later via the
  `_archivingStage` 0→1 delay (see `ArchiveExporter` below) so the "busy"
  overlay is guaranteed to have rendered at least once first — a pattern
  used identically for opening the archive browser (`_archiveLoadStage`).
  If you see this "stage 0, then stage 1 next frame" idiom, it's this
  deliberate one-frame-render-then-do-blocking-work pattern, not dead code.

### `ArchiveExporter.lua`
On request, freezes the current `ScoreSheets` scroll/keyboard offsets to 0,
hides the live name text fields, renders every hand into an off-screen
`image()` canvas (`setContext(img)` / draw / `setContext()`), restores
on-screen state, then writes three artifacts to `Documents:`: a PNG
(the rendered image), a JSON dump (`buildInputs` = raw per-hand team/player
data, `buildComputed` = the ledger's computed snapshot for every hand), and
appends an entry to `SpartsArchives_index.json` (newest first). If an
archived game's displayed totals ever look wrong compared to the live game
at time of archiving, the bug is more likely in whether `ss.ledger` was
freshly recomputed before `buildComputed` ran than in the rendering step.

### `ArchiveBrowser.lua`
A horizontally-paged, vertically-scrollable gallery of archived PNGs with a
JSON-backed summary overlay (names, per-team score, computed winner) and a
delete flow (soft-delete: blanks the PNG/JSON in place and removes the
index entry, rather than truly deleting files — Codea's asset API has no
delete). Two independent axes of touch handling exist per-card: horizontal
drag = page-to-page paging (with inertia/deceleration), vertical drag =
scroll within one tall image (also with inertia) — gesture axis is decided
once per touch by whichever delta exceeds the other by a 1.2x margin
(`_gestureAxis`). A "plaque" (the summary box + delete badge) fades out
while vertically dragging so it doesn't obscure the image, and fades back
in on release — if a summary box is stuck invisible/visible, check
`_plaqueA`/`plaqueFadeIn`/`plaqueFadeOut` in `:update()`.
`_getMetaForBase`/`_getImageForBase` both try `Documents:` first (user-
generated archives) and fall back to the bundled `asset` path (any archives
shipped inside `Assets/Sparts Scoresheet.codea/` — see CLAUDE.md: that
folder is archive storage only, never edited by app logic other than
reading here).

### `IncrementingCell.lua`
The bid/took/hearts numeric input widget: tap = +1, drag horizontally =
multi-step (accumulates pixels into `dragAccum`, steps every `stepPx`
pixels — `stepPx` is overridden per-instance by `ScoreTable:init` to make a
full drag across all the right-hand columns equal roughly a 0–13 sweep).
Values wrap between an explicit **"unset" (`--`) state** and the numeric
range `[min,max]` (default 0–13): stepping past either boundary lands on
"unset" rather than clamping or wrapping numerically — this is intentional
(lets a user "back out" an accidental entry) and is a likely source of "the
number won't go past X" confusion reports that are actually working as
designed. Per-touch-id ownership (`_owners`, class-level) is claimed only
on `BEGAN` inside the cell's box and held until `ENDED`/`CANCELLED`; if a
cell "eats" a later, unrelated touch with a recycled id, look here.

### `CheckboxCell.lua`
Simpler tap-to-toggle widget (queen/moon), same per-touch ownership pattern
as `IncrementingCell`. Has a `disabled` flag (set every frame by
`ScoreTable:draw()` while the opposing team's moon is active) that mutes
its colors and blocks `:touched()` entirely — if a checkbox looks "grayed
out but still tappable" or vice versa, the mismatch is between this
mute-color logic and the `self.disabled` gate in `:touched()`.

### `Sensor.lua`
A generic gesture-recognizer utility (tap/drag/swipe/long-press/zoom/drop/
touch) used as a component by nearly every interactive thing in the app
(cells, buttons, name long-press, whole-screen scroll). Each gesture type
is independent and opt-in via `:onX(callback)`; `:touched(t)` runs every
registered gesture's update function and returns whether this sensor
"intercepted" the touch (used by callers to decide whether to keep
routing the touch elsewhere). `doNotInterceptTouches` /
`doNotInterceptOnce` are escape hatches callers use to let a touch pass
through even though the sensor's box contains it (e.g. `ScoreSheets` uses
this on its whole-screen scroll sensor to avoid stealing touches meant for
buttons/cells).

### `Theme.lua`
Pure data: every color constant. No logic. If a visual bug is "wrong color"
rather than "wrong position," this is the only file that should need to
change.

### `Helpers.lua`
Grab-bag of small stateless utilities: `clamp`, `fitFontSize` (shrinks font
to fit a box — used for header labels), `codeaToUIKitRect` (Codea's
bottom-left-origin coords → UIKit's top-left-origin coords, needed
anywhere a Lua-space rect is handed to a real `UIView`/`UITextField`),
`drawRoundedRect` (draws rounded rects via a filled center rect + capped
lines, not a real rounded-rect primitive — used for the pill-shaped
buttons), `listenForKeyboard` (appears unused directly — the actual
keyboard handling goes through the `iOS Keyboard Avoider` dependency's own
`KeyboardHandler`/`KeyboardAvoider`, not this function), `_safeFilePart`
(sanitizes player names for use in archive filenames), and
`newTeamsFromPrevious` (builds the next hand's blank team objects, carrying
forward only names + running totals — used by `ScoreSheets:_addHand`).

### `notchTracker.lua`
Infers which physical side (left/right) the iPhone's notch/Dynamic Island is
currently on, using device rotation rate (gyro) rather than
`CurrentOrientation` alone, because Codea's `CurrentOrientation` can be
stale or the true landscape sub-orientation ambiguous during a rotation.
Feeds `notchOnLeft`/`notchOnRight` into `ScoreSheets`, which passes it to
`ScoreTable:layout()` to add extra inset padding on the notch side. If
layout padding is on the wrong side after a physical rotation, this file's
`Z_START`/`Z_STOP`/`ACCUM_MIN`/`SETTLE_S` thresholds (tuned empirically)
are the tuning knobs, not the layout math itself.

### `SaveAndLoad.lua`
See "Persistence" under `ScoreSheets.lua` above — this is the flat-keys-in-
local-KV-store half of the persistence story. Note `loadGameState()`
**replaces `sheets` entirely** (`sheets = ScoreSheets(...)`) rather than
mutating the existing one, then manually re-seeds `_setFirstDealer`/
`_setSecondDealer` and hand-1 player names on the new instance — if a
freshly-loaded game is missing UI wiring that a freshly-`setup()` game has,
check whether this reconstruction path re-does everything `ScoreSheets:init`
normally does (it doesn't call `:init` again — it calls the constructor
fresh, so `:init` *does* run — but it then immediately overwrites
`sheets.tables` with the loaded tables afterward, so any per-table state
`:init` set up referencing the *original* first table may now be stale).

### `Tests.lua`
Manually-invoked (not part of any automatic test runner or CI — search for
where `T.run()` is actually called; it is not called from `Main.lua`)
pure-Lua tests for `ScoreRules`/`ScoreLedger` moon-normalization behavior.
See the `ScoreLedger.lua` section above for which parts of this file are
stale relative to the current ledger API.

### `UIKit.lua`
**Entirely commented out** (one giant block comment) — an earlier,
abandoned attempt at a Lua-side UIKit wrapper (`UIView`, `UIConstraint`,
Auto Layout helpers). Superseded by the direct `objc.*` calls used in
`ScoreSheets.lua` for name text fields. Dead file; not loaded/executed.

## Dependencies (do not modify; imported via `require()` in `Main.lua`)
- `Assets/CodeaAVPlayer.codea/` — plays the "SPARTS" logo-tap intro video
  (`videoPlayer:showAndAutoplayMOV(...)`).
- `Assets/iOS Keyboard Avoider.codea/` — `KeyboardHandler` (raw keyboard
  show/hide notification listener) + `KeyboardAvoider` (shifts the host
  view up when a registered `UITextField` becomes first responder, used
  for the 4 player-name fields).
- `Assets/LifecycleObserver.codea/` — wraps `UIApplication` background/
  terminate notifications into the `onWillResignActive`/
  `onDidEnterBackground`/`onWillTerminate` callbacks `Main.lua` hooks into
  for autosave.

## Archives storage (do not modify app-side; read-only fallback path)
`Assets/Sparts Scoresheet.codea/` — bundled archive PNG/JSON pairs the app
can read as a fallback when nothing exists yet in `Documents:` (see
`ArchiveBrowser:_getImageForBase`/`_getMetaForBase`/`loadIndex`). Real user
archives live in the device's `Documents:` sandbox, not here.

## Quick "where's the bug" index

| Symptom | Look here first |
|---|---|
| Wrong score number | `ScoreRules.lua` (formula), then `ScoreLedger.lua` (accumulation/chain logic) |
| Score shows `--` when it shouldn't (or vice versa) | `ScoreRules.spadesReady`/`heartsReady`/`queenIsAssigned`, `ScoreLedger`'s `*Ready` locals |
| Cell/column visually misaligned | `ScoreTable.lua` → `ALT_COLS` and `:layout()` |
| Tap lands on wrong cell / touch feels "stuck" to one widget | Per-touch ownership tables: `IncrementingCell._owners` / `CheckboxCell._owners`; then `ScoreSheets:touched()`'s routing order |
| Scrolling fights with cell dragging | `ScoreSheets:touched()` — two-finger vs one-finger vs cell-ownership precedence |
| Moon/queen checkbox behaves inconsistently across teams | `ScoreTable:touched()`'s inline exclusivity logic **and** `ScoreRules.syncHeartsMoon` (two implementations of one rule) |
| Wrong dealer name on hand 3+ | `ScoreSheets._dealerForHand` / `_partnerOf` |
| Data lost or wrong after relaunch | Both persistence paths in "Persistence" above — check which one actually wrote/read |
| Archive image/summary wrong or stuck faded | `ArchiveExporter` (render-time state) vs `ArchiveBrowser._plaqueA`/`metaCache` (browse-time state) |
| Layout wrong after rotating device | `notchTracker.lua` thresholds, then `ScoreTable:layout()`'s notch padding branch |
| Name text field not editable / keyboard doesn't avoid it | `ScoreSheets:init`'s `objc.UITextField` setup + `KeyboardAvoider` (dependency) |
| Blank/crash on launch | `Main.lua:draw()`'s "LAUNCH FAILURE" fallback means `ScoreSheets:init` threw — check Xcode console (`devLog` mirrors there) |

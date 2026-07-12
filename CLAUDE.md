# Sparts Scoresheet — Xcode Project

## Project Type
Codea-exported Xcode project. App logic is entirely in Lua files.
Swift/ObjC files are Codea runtime boilerplate — do not modify them.

## Xcode Config
- Scheme: SpartsScoresheet
- Bundle ID: com.JesseWonderClark.SpartsScoresheet
- Simulator: iPhone 17 (1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044)

## File Structure
- Game logic: SpartsScoresheet.codea/*.lua
- Dependencies (do not modify):
  - Assets/CodeaAVPlayer.codea/
  - Assets/iOS Keyboard Avoider.codea/
  - Assets/LifecycleObserver.codea/
- Archives storage only (do not modify):
  - Assets/Sparts Scoresheet.codea/

## Build & Test Loop
```bash
# Build
xcodebuild -scheme SpartsScoresheet \
           -destination 'platform=iOS Simulator,id=1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044' \
           -derivedDataPath /tmp/sparts-build \
           -quiet build 2>&1 > /tmp/build.log

# Check for failure before proceeding
grep -q "BUILD FAILED" /tmp/build.log && cat /tmp/build.log && exit 1

# Launch
xcrun simctl launch 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044 com.JesseWonderClark.SpartsScoresheet

sleep 4

# Screenshot
xcrun simctl io 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044 screenshot /tmp/test.png

# Logs
xcrun simctl spawn 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044 log stream \
  --predicate 'subsystem == "com.JesseWonderClark.SpartsScoresheet"' \
  > /tmp/test.log
```

## Simulator Hang — Diagnosis & Fix

**Symptom:** App shows perpetual spinner, `xcrun simctl launch` and `simctl terminate` hang indefinitely. Looks like "app won't start." Often misdiagnosed as a code bug.

**Root cause:** Simulator process gets into a bad state (can happen after any crash, forced quit, or hung `simctl` command). NOT usually a code bug — verify code first by checking the build succeeds, then try the simulator fix.

**Fix — in this order:**
```bash
# 1. Kill all hung simctl processes
pkill -9 -f "simctl" 2>/dev/null

# 2. Kill the Simulator process itself
pkill -9 -f "Simulator" 2>/dev/null

# 3. Wait for cleanup
sleep 3

# 4. Reboot the simulator
xcrun simctl boot 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044

# 5. Verify it boots
xcrun simctl list | grep 0EF8AE50  # should show "(Booted)"

# 6. Launch app with timeout (avoid another hang)
xcrun simctl launch 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044 com.JesseWonderClark.SpartsScoresheet &
LPID=$!; sleep 10; kill $LPID 2>/dev/null; wait $LPID 2>/dev/null
```

**How to avoid causing it:**
- Never call functions from dependencies before they're defined (e.g., `devLog()` called from `CodeaAVPlayer.lua` which is `require()`'d before `devLog` exists in `Main.lua`). A nil-reference crash during app startup causes Codea to retry-launch in a tight loop, which can wedge the simulator.
- Always terminate the app before launching a new instance: `xcrun simctl terminate ...` first.
- If `simctl terminate` hangs for more than 5 seconds, the simulator is already wedged — use the full kill procedure above.

## App Orientation
The app is **landscape-only by design**. The scoresheet renders sideways relative
to the simulator's portrait status bar/chrome — this is expected, not a bug. Don't
spend time "fixing" rotation.

## SPM Dependency Pinning — Diagnosis & Fix

**Symptom:** App builds and launches, but the scoresheet (or any UIKit-touching
Lua code called from `setup()`) never appears — screen stays on a placeholder.
Xcode console shows:
```
Modifying properties of a view's layer off the main thread is not allowed: ...
attempt to index a nil value (field 'parentViewController')
```
Easy to misdiagnose as a Lua bug (nil check, wrong API) because the stack trace
points into your Lua file.

**Root cause:** the `twolivesleft/Runtime` SPM package (provides Codea's
`LuaKit`/`RuntimeKit`) is pinned to `branch = main` with no fixed tag/version. If
`SpartsScoresheet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
is missing or its `Runtime` pin has drifted, a fresh build silently resolves to
whatever is newest on that branch — which can introduce a regression in the
threaded runtime driver's UIKit handling. This happened once already (see git
history around commit `27bfa6a`, which accidentally gitignored `Package.resolved`
alongside genuine IDE-state cleanup).

**Fix — check this before debugging Lua:**
```bash
# Check the currently pinned Runtime revision
cat SpartsScoresheet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# Force a clean resolve against whatever is currently pinned there
xcodebuild -resolvePackageDependencies -scheme SpartsScoresheet -derivedDataPath /tmp/sparts-build
```
Last known-good pinned revision: `924c512405ebc7c5c4694c66367d709d73aa287d`
(confirmed working at commit `91229e4`).

**How to avoid causing it:**
- Never let `Package.resolved` be gitignored — it must stay tracked. `.gitignore`
  should not have a bare `Package.resolved` or blanket `*.xcworkspace` rule.
- Don't run Xcode's "Update to Latest Package Versions" on this project unless
  you intend to re-pin and re-verify the launch.

## Rules
- Edit only Lua files in SpartsScoresheet.codea/
- Never modify Swift/ObjC runtime files unless explicitly told to
- Never modify dependency or archives folders unless explicitly told to
- After BUILD FAILED: extract compiler error, write correction spec, spawn subagent
- Do not self-evaluate screenshots — report observation and wait for user confirmation
- Maximum 3 correction attempts per task before escalating to user

## Before committing
- **Run, don't just build.** `xcodebuild build` succeeds for syntax errors that crash at
  runtime (nil function calls, missing APIs). Always install + launch after building:
  ```bash
  xcrun simctl install <sim> <built-app> && xcrun simctl launch <sim> <bundle>
  ```
- **Grep for any function before using it.** Codea 3.x has a limited Lua API surface.
  Before calling any function you haven't seen used in this codebase, grep for it:
  ```bash
  grep -rn 'functionName' SpartsScoresheet.codea/
  ```
  If it doesn't appear, it probably doesn't exist. Use `pcall` or find an alternative.

## Committing
- **Never commit unless the user explicitly instructs you to.** Build, test, report — but wait for the user to say "commit" before touching git.
- When committing, do not use "Co-Authored by" — use "Executed-by: Claude"
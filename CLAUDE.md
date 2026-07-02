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

## Rules
- Edit only Lua files in SpartsScoresheet.codea/
- Never modify Swift/ObjC runtime files unless explicitly told to
- Never modify dependency or archives folders unless explicitly told to
- After BUILD FAILED: extract compiler error, write correction spec, spawn subagent
- Do not self-evaluate screenshots — report observation and wait for user confirmation
- Maximum 3 correction attempts per task before escalating to user

## Committing
- in git commits do not use "Co-Authored by" instead use "Executed by"
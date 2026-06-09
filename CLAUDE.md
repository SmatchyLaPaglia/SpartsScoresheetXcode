# Sparts Scoresheet — Xcode Project

## Project Type
Codea-exported Xcode project. App logic is entirely in Lua files.
Swift/ObjC files are Codea runtime boilerplate — do not modify them.

## Xcode Config
- Scheme: SpartsScoresheet
- Bundle ID: com.JesseWonderClark.SpartsScoresheet
- Simulator: iPhone 16e (0EF8AE50-8899-40DD-A77E-359C06732886)

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
           -destination 'platform=iOS Simulator,id=0EF8AE50-8899-40DD-A77E-359C06732886' \
           -derivedDataPath /tmp/sparts-build \
           -quiet build 2>&1 > /tmp/build.log

# Check for failure before proceeding
grep -q "BUILD FAILED" /tmp/build.log && cat /tmp/build.log && exit 1

# Launch
xcrun simctl launch 0EF8AE50-8899-40DD-A77E-359C06732886 com.JesseWonderClark.SpartsScoresheet

sleep 4

# Screenshot
xcrun simctl io 0EF8AE50-8899-40DD-A77E-359C06732886 screenshot /tmp/test.png

# Logs
xcrun simctl spawn 0EF8AE50-8899-40DD-A77E-359C06732886 log stream \
  --predicate 'subsystem == "com.JesseWonderClark.SpartsScoresheet"' \
  > /tmp/test.log
```

## Rules
- Edit only Lua files in SpartsScoresheet.codea/
- Never modify Swift/ObjC runtime files unless explicitly told to
- Never modify dependency or archives folders unless explicitly told to
- After BUILD FAILED: extract compiler error, write correction spec, spawn subagent
- Do not self-evaluate screenshots — report observation and wait for user confirmation
- Maximum 3 correction attempts per task before escalating to user
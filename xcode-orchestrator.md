---
name: xcode-orchestrator
description: >
  Orchestrates Xcode/Codea-exported project fixes using a delegated Haiku
  process for code generation and xcrun/xcodebuild for testing. Use when
  fixing bugs or adding features to a Codea-exported Xcode project running
  in the iOS simulator.
---

# Xcode Orchestrator Skill

You are the orchestrator. You review, plan, delegate, test, and integrate.
You do not write implementation code yourself.
A delegated Haiku process writes code. You test it via xcodebuild and xcrun.

This skill is project-agnostic — it derives project-specific values at the
start of a session rather than hardcoding them.

## Prerequisites
- Simulator is booted (verify with `xcrun simctl list | grep Booted`)

## Workflow

### 0. CONFIGURE (once per project, cached across sessions)

If `.orchestrator-env` exists in the project root, load it instead of
re-detecting:

```bash
[ -f .orchestrator-env ] && source .orchestrator-env && \
  echo "loaded: SCHEME=$SCHEME BUNDLE_ID=$BUNDLE_ID SIM_UDID=$SIM_UDID DERIVED_DATA=$DERIVED_DATA"
```

Otherwise, detect and cache it (shell variables don't survive past this
session, so persist them to a file rather than re-deriving from scratch
every time):

```bash
SCHEME=$(xcodebuild -list -json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['project']['schemes'][0])")
BUNDLE_ID=$(xcodebuild -showBuildSettings -scheme "$SCHEME" 2>/dev/null | awk -F' = ' '/PRODUCT_BUNDLE_IDENTIFIER/{print $2; exit}')
SIM_UDID=$(xcrun simctl list devices | grep Booted | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)
DERIVED_DATA="/tmp/${SCHEME}-build"

cat > .orchestrator-env <<CFG
SCHEME="$SCHEME"
BUNDLE_ID="$BUNDLE_ID"
SIM_UDID="$SIM_UDID"
DERIVED_DATA="$DERIVED_DATA"
CFG

echo "SCHEME=$SCHEME"
echo "BUNDLE_ID=$BUNDLE_ID"
echo "SIM_UDID=$SIM_UDID"
echo "DERIVED_DATA=$DERIVED_DATA"
```

Notes, since this hasn't been tested against a real Xcode project —
`xcodebuild`/`xcrun` only exist on macOS, so this couldn't be verified the
way the `claude -p` flags elsewhere in this file were:
  - `-showBuildSettings -scheme` is the authoritative way to get
    `PRODUCT_BUNDLE_IDENTIFIER` — grepping the raw `.pbxproj` directly is
    fragile (multiple configs/targets, unresolved variable references).
  - The `-list -json` parse assumes a `project` key, which holds for a
    plain `.xcodeproj` (the normal Codea export shape). An `.xcworkspace`
    uses a different key and would need a different parse.
  - If multiple schemes exist and the first one isn't right, ask the user
    rather than guessing.
  - If launch or install ever fails mysteriously later in a session,
    re-check whether the simulator instance changed — `SIM_UDID` in the
    cached file could be stale if the simulator was reset or a different
    one booted.

Run this block once and check the four echoed values before trusting them
in a real task.

Use `$SCHEME`, `$BUNDLE_ID`, `$SIM_UDID`, `$DERIVED_DATA` in place of any
literal project name, bundle ID, or device UDID in the steps below.

### 1. REVIEW

- If HANDOFF.md, CLAUDE.md, and/or STRUCTURE.md exist in the project root,
  read them. Do not read all Lua files.
- Before doing anything else, ask any clarifying questions needed about
  the goal.

### 2. COMPOSE

- Write a step-by-step plan for achieving the goal.
- **Root cause check:** for each bug-fix step, ask — is the root cause
  already confirmed, or is this a guess? If it's a guess, insert a
  diagnostic step before the fix step.

  Diagnostic strategies available:

  | Strategy | How | Use when |
  |----------|-----|----------|
  | Codea-side read-back | After `saveImage`/`saveText`, immediately call `readImage`/`readText` on the same path and `print()` success/failure, resolved path, dimensions, errors. | Need to know if save itself succeeds |
  | File-existence probe | Write a small text file to the suspected sandbox path (`Documents:probe.txt`), read it back. | Need to confirm the path prefix works |
  | On-screen indicator | Draw a colored rectangle or status text on-screen, visible in screenshot. | Log stream capture is unreliable, or unverified (see below) |
  | Host-side file check | `xcrun simctl get_app_container`, then `find`/`ls` the Documents directory. | Need to confirm files actually landed on disk |
  | NSLog print() capture | See below. **Unverified — confirm once before relying on it.** | After the one-time probe has confirmed it works for this project |

  **NSLog print() capture — unverified, confirm once per project:**
  ```bash
  xcrun simctl spawn $SIM_UDID log stream \
    --predicate "subsystem == \"$BUNDLE_ID\"" \
    > /tmp/diag.log &
  LOGPID=$!
  ```
  This assumes Codea's `print()` surfaces via NSLog tagged with the app's
  bundle ID as subsystem — an assumption inherited from an earlier version
  of this file, not independently confirmed. Plain `NSLog()` calls (as
  opposed to the modern `os_log`/`Logger` API) commonly log with an empty
  or process-based subsystem rather than the bundle ID, so this predicate
  may simply match nothing.

  One-time probe: add `print("PROBE_12345")` somewhere reachable, start
  the log stream **before** launching (see below for why), launch, and
  check whether `PROBE_12345` shows up. If the bundle-ID predicate finds
  nothing, try `process == "<AppName>"` or `processImagePath CONTAINS
  "<AppName>"` next — that's the most likely actual shape of Codea's log
  output — before concluding log capture doesn't work at all and falling
  back to the on-screen-indicator or file-existence-probe strategies.
  Always `kill $LOGPID` when done capturing.

  **`log stream` only shows messages emitted after it starts** — it does
  not retroactively show anything, the same way `tail -f` doesn't. Start
  it *before* launching the app, not after. Anything printed during
  `setup()` or at launch will be missed if the stream starts afterward.

  **Execute a diagnostic:**
  1. Write instrumentation instructions (NOT a fix) and delegate it (see
     EXECUTE — same subprocess mechanism).
  2. Integrate the returned instrumentation, build, install, start log
     capture, launch, let it run a few seconds, screenshot, kill the log
     capture.
  3. Read the result to determine root cause.
  4. Report findings to the user before proceeding to the fix step.

- **Testability check:** is every step observably verifiable (build
  success, a screenshot, specific log content)? Revise until it is.

  **No touch injection is available.** `simctl` can launch, terminate, and
  screenshot — it cannot simulate a tap, drag, or any other touch input.
  Any step whose acceptance criteria depends on the user interacting with
  the running app is not actually testable this way. Revise such steps so
  the feature under test triggers automatically — from `setup()`/`draw()`,
  or via a temporary auto-run flag added specifically for this test cycle
  — instead of assuming a tap can be simulated. Say this explicitly in the
  delegate instructions for any step involving an interactive feature.

- **Approval check:** which steps would need the user's approval
  mid-execution? Revise to minimize or eliminate mid-plan approval needs
  where possible, without removing the plan review below.
- Present the plan to the user. Incorporate their changes before executing
  anything.

### 3. EXECUTE

For each step in the confirmed plan that changes code, delegate it.

**Delegate via subprocess — Haiku, on the existing subscription, no
separate billing.** Do not use the built-in Task tool. Spawn an
independent `claude` process via the Bash tool. No `ANTHROPIC_BASE_URL` is
set on this command, so it authenticates exactly like this session does.

```bash
claude -p "<step instructions>" \
  --model claude-haiku-4-5-20251001 \
  --output-format json \
  --tools "Read,Grep" \
  --max-budget-usd 0.50 \
  > /tmp/delegate_result.json
```

Verified directly against the installed `claude` CLI (`claude -p --help`
plus a live test call) — `--tools`, `--output-format json`, and
`--max-budget-usd` are all real, accepted flags. If a future CLI version
ever rejects one of these, that surfaces as a spawn failure — see HARD
STOP — not a silent misconfiguration.

The `<step instructions>` should cover, in prose:
  - which file to modify
  - what it currently does and what it should do instead
  - constraints (Lua, Codea Legacy 3.x runtime, no external libs)
  - what "done" looks like for this step, and how it will actually be
    triggered/observed given no touch injection exists
  - relevant code (paste only the function/block that matters)
  - an explicit instruction not to edit or write files directly, and to
    return the complete modified file content as the final answer —
    warn explicitly against shortcuts like "-- rest of file unchanged"
    even for large files
  - an explicit instruction to only use Codea API calls it's confident
    exist, and to flag uncertainty about any function name in its summary

`--tools "Read,Grep"` restricts the delegate to read-only investigation —
it cannot touch the filesystem, only answer in text.

Parse `/tmp/delegate_result.json`. Confirmed fields: `result`, `is_error`,
`total_cost_usd`, `session_id`, `usage.input_tokens` /
`usage.output_tokens`. If `is_error` is true, treat the step as failed.

**If the `claude -p` command itself exits non-zero or produces no
parseable JSON**, that's a spawn failure — see HARD STOP.

**Integrate, with a truncation guard:**

```bash
cp <target_file> /tmp/<target_file>.bak   # before overwriting
```

Write the returned content to disk. Then diff it against the backup:

```bash
diff /tmp/<target_file>.bak <target_file>
```

Confirm the diff only touches what this step actually asked for. Watch
specifically for signs the delegate truncated its answer instead of
returning the complete file — placeholder comments like "-- rest
unchanged", a diff that's suspiciously small relative to the file's real
size, or the file ending mid-function. If anything looks off, send it
back with a correction note rather than trusting it.

**Check API calls before building — free, no model cost:**

```bash
python3 check_codea_api_calls.py <modified_file.lua> codea-api-globals.txt
```

Plain text matching against `codea-api-globals.txt` (generated once from
a real Codea runtime — see project setup notes). Flags function-call-
shaped identifiers that are neither in the reference list nor defined
locally in the file. Won't catch method calls (`obj:touched()`), so it's
a cheap first pass, not a guarantee — but it costs nothing to run and
catches the common case of an invented function name before wasting a
build cycle on it.

**Build, install, and test every step as it's completed:**

```bash
xcodebuild -scheme $SCHEME \
           -destination "platform=iOS Simulator,id=$SIM_UDID" \
           -derivedDataPath $DERIVED_DATA \
           -quiet build > /tmp/build.log 2>&1 || { tail -50 /tmp/build.log; exit 1; }

# xcodebuild build compiles the app but does not install it — simctl
# launch would otherwise run whatever was installed previously, silently
# testing stale code. Find and install the freshly built binary.
APP_PATH=$(find "$DERIVED_DATA/Build/Products" -name "*.app" | head -1)
xcrun simctl install $SIM_UDID "$APP_PATH"

xcrun simctl terminate $SIM_UDID $BUNDLE_ID 2>/dev/null

# Start log capture BEFORE launch — log stream only shows messages
# emitted after it starts, so starting it after launch misses setup()-time
# output, which is exactly when most diagnostics fire.
xcrun simctl spawn $SIM_UDID log stream \
  --predicate "subsystem == \"$BUNDLE_ID\"" \
  > /tmp/test.log &
LOGPID=$!

xcrun simctl launch $SIM_UDID $BUNDLE_ID

sleep 5

xcrun simctl io $SIM_UDID screenshot /tmp/test.png

sleep 3
kill $LOGPID 2>/dev/null
```

Use the screenshot for anything visual; use the log for runtime behavior
once the one-time NSLog probe has confirmed it's reliable for this
project. Do not self-declare success from the screenshot alone — report
what's observed and wait for the user's confirmation before marking the
whole plan done (see HANDOFF.md rule below).

**If a test fails:** identify the specific error from the log or
screenshot, write a correction note, and re-delegate the same step.
Several rounds of small adjustment within one step (e.g. nudging
on-screen text placement) are normal and don't need individual reporting.
Maximum 3 correction attempts per step before escalating.

---

**Standby path — DeepSeek via local proxy. Not active. Do not use unless
the user has explicitly started the proxy and asked for it this
session.**

```bash
ANTHROPIC_BASE_URL="http://127.0.0.1:8787" ANTHROPIC_AUTH_TOKEN="unused-but-required" \
  claude -p "<step instructions>" \
  --output-format json \
  --tools "Read,Grep" \
  --max-budget-usd 0.50 \
  > /tmp/delegate_result.json
```

Bills a separate DeepSeek account behind the proxy, with automatic Haiku
fallback if DeepSeek's balance is out — see deepseek-fallback-setup.md.
Leave unused until turned back on deliberately.

## HANDOFF.md — update once per goal, not per step

Update HANDOFF.md exactly once: after reporting the finished result and
the user confirms the whole goal is done. Not after each delegated file
change, not after each correction attempt.

When updating it, include: task completed, file(s) modified, current
state, next task.

## HARD STOP

If the `claude -p` command itself fails to run at all (crash, non-zero
exit, no parseable output) — as opposed to a delegated step failing its
test, which is handled by the normal correction path:
  Do NOT write the implementation yourself as a workaround.
  Report exactly what broke to the user and stop.
  Wait for human guidance before continuing.

## Escalation

If a step fails 3 correction attempts:
  Report to the user: what was attempted, what failed each time, and the
  current state of the file.
  Wait for human guidance before continuing.

## Project setup notes (one-time, not part of the per-task workflow)

- `codea-api-globals.txt` should exist alongside this file. To regenerate:
  run a `dump(_G)`-style traversal in a **blank** Codea project, save the
  printed output, one `name : type` pair per line.
- `.orchestrator-env` gets created automatically by CONFIGURE the first
  time this skill runs in a project; delete it if the simulator or scheme
  changes and values need re-detecting.
- The NSLog print() capture method needs its one-time probe (see COMPOSE)
  before EXECUTE relies on it for a real diagnosis.
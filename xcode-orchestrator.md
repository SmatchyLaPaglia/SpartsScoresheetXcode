---
name: xcode-orchestrator
description: >
  Orchestrates Xcode/Codea-exported project fixes using subagents for code
  generation and xcrun/xcodebuild for testing. Use when fixing bugs or adding
  features to a Codea-exported Xcode project running in the iOS simulator.
---

# Xcode Orchestrator Skill

You are the orchestrator. You plan, delegate, test, and integrate.
You do not write implementation code yourself.
Subagents write code. You test it via xcodebuild and xcrun.

## Prerequisites
- CLAUDE.md exists and has been read
- HANDOFF.md exists in the project root
- Simulator is booted (verify with `xcrun simctl list | grep Booted`)

## Workflow

### 1. PLAN
Read HANDOFF.md only. Do not read all Lua files.
Identify the single next task from HANDOFF.md.
If the task touches more than one file, split into atomic subtasks
— one file per subtask.

### 2. SPECIFY
For each subtask, grep the relevant file(s) to find the exact code site.
Do not guess. Do not read entire files — use grep to locate the relevant
function or block, then read only that section.

Write a task spec containing:
  - Exact filename to modify
  - Current behavior (one sentence)
  - Required behavior (one sentence)
  - Constraints (Lua, Codea Legacy 3.x runtime, no external libs)
  - Acceptance criteria (observable, testable)
  - Relevant code context (paste only the relevant function/block)

### 3. DECIDE: Fix or Diagnose?

If you already know the root cause with high confidence:
  → Proceed to DELEGATE (step 4) with a fix spec.

If the failure cause is unknown or unconfirmed (e.g., "save silently failing
vs load returning nil", "file path wrong vs image generation broken"):
  → Proceed to DIAGNOSE (step 3A) before writing any fix code.

Ask: **Could I explain to the user exactly why this breaks, or am I guessing?**
If guessing, diagnose first.

#### 3A. DIAGNOSE

The purpose of this phase is to isolate the failure to a specific operation
before attempting any fix. Do NOT write fix code here — only instrumentation
that reveals what the runtime is actually doing.

**Diagnostic strategy (pick one or both):**

| Strategy | How | Use when |
|----------|-----|----------|
| Codea-side read-back | After `saveImage`/`saveText`, immediately call `readImage`/`readText` on the same path and `print()` success/failure. Also `print()` the resolved path, image dimensions, and any error messages. | Need to know if save itself succeeds |
| File-existence probe | Write a small text file to the suspected sandbox path (`Documents:probe.txt`), then read it back. If readable, the path prefix works and the problem is elsewhere. | Need to confirm the path prefix works |
| On-screen indicator | Draw a colored rectangle or status text on-screen (green=save OK, red=save failed) visible in screenshot. | Log stream capture is unreliable |
| Host-side file check | Use `xcrun simctl get_app_container` to find the sandbox, then `find`/`ls` the Documents directory to check if files exist on disk. | Need to confirm files actually landed on disk |

**Preferred diagnostic for this Codea runtime:**
`print()` output goes to NSLog with subsystem matching the bundle ID
(`com.JesseWonderClark.SpartsScoresheet`). It IS capturable via:
```bash
xcrun simctl spawn 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044 log stream \
  --predicate 'subsystem == "com.JesseWonderClark.SpartsScoresheet"' \
  > /tmp/diag.log &
```

**Execute:**
1. Write a task spec for diagnostic instrumentation (NOT a fix)
2. Delegate to subagent: "Add diagnostic print() statements to [file] to determine whether [operation] succeeds or fails"
3. Integrate, Build, Launch, Trigger the feature, Capture logs
4. Read /tmp/diag.log to determine root cause
5. Report findings to user before proceeding to fix

**Exit criteria:** You now know definitively whether the failure is on the
save side, load side, or both, and what the actual error is. You can explain
it to the user in one sentence.

### 4. DELEGATE
Spawn a subagent via Task tool for each subtask:

  Task({
    prompt: <task spec>,
    description: "Fix [specific thing] in [filename]"
  })

When spawning subagents, pass only `prompt` and `description`.
Do not pass thinking, reasoning_effort, or any model parameters.
If the Task call returns an API error, trigger HARD STOP immediately.

Subagent contract — subagent MUST return:
  - The complete modified file content
  - A one-line summary of what changed
  - Any assumptions made

Do not spawn more than 2 subagents in parallel.

### 5. INTEGRATE
Receive subagent result.
Write the returned file content to disk.
Do not modify it. If it needs changes, send back to a new subagent
with specific correction notes.

### 6. TEST
Build, terminate any running instance, relaunch fresh, then screenshot:

```bash
# Build
xcodebuild -scheme SpartsScoresheet \
           -destination 'platform=iOS Simulator,id=1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044' \
           -derivedDataPath /tmp/sparts-build \
           -quiet build 2>&1 > /tmp/build.log

# Short-circuit on build failure
grep -q "BUILD FAILED" /tmp/build.log && cat /tmp/build.log && exit 1

# Terminate stale instance
xcrun simctl terminate 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044 \
  com.JesseWonderClark.SpartsScoresheet 2>/dev/null

# Launch fresh
xcrun simctl launch 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044 \
  com.JesseWonderClark.SpartsScoresheet

sleep 5

# Screenshot
xcrun simctl io 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044 \
  screenshot /tmp/test.png

# Logs (capture for 3 seconds then kill)
xcrun simctl spawn 1B48ACAA-0AE2-40C3-B28B-BFDB1A4A3044 log stream \
  --predicate 'subsystem == "com.JesseWonderClark.SpartsScoresheet"' \
  > /tmp/test.log &
LOGPID=$!
sleep 3
kill $LOGPID 2>/dev/null
```

### 7. EVALUATE
Examine screenshot and logs.
Pass criteria: BUILD SUCCEEDED + no runtime crashes in log + visual
result matches acceptance criteria.

Do not self-declare success based on screenshot alone.
Report your screenshot observation to the user and wait for confirmation.

If PASS (pending user confirmation):
  Report screenshot observation.
  Update HANDOFF.md marking task complete.
  Wait for user to confirm before proceeding to next task.

If FAIL:
  Do not fix code yourself.
  Identify the specific error from logs or screenshot.
  Write a correction spec: what failed, what the error says, what to fix.
  Spawn a new subagent with the correction spec.
  Maximum 3 correction attempts before escalating to user.

## Escalation
If a task fails 3 correction attempts:
  Report to user: what was attempted, what failed each time,
  what the current state of the file is.
  Wait for human guidance before continuing.

## HARD STOP
If subagent spawning fails for any reason:
  DO NOT write implementation code yourself.
  DO NOT rationalize exceptions to this rule.
  Report the error to the user and stop.
  Wait for human guidance.

## HANDOFF.md Updates
After each confirmed-complete task, update HANDOFF.md with:
  - Task completed
  - File(s) modified
  - Current state
  - Next task

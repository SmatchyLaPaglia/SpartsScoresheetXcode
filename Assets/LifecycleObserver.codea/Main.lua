-- Main.lua
-- Standalone lifecycle + persistence test

local STATE_KEY = "demo_button_state"
local MAX_STATE = 5

function setup()
  -- Load persisted state (number only — fast & safe)
  buttonState = readLocalData(STATE_KEY, 1)
  
  EVENT_KEY = "demo_last_lifecycle_event"
  
  lifecycle = LifecycleObserver()
  
  -- set these callbacks to save state
  
  lifecycle.onEnterBackground = function()
    print("[LIFECYCLE] enter background → saving state:", buttonState)
    saveLocalData(STATE_KEY, buttonState)
    saveLocalData(EVENT_KEY, "enterBackground")
  end
  
  lifecycle.onWillResignActive = function()
    print("[LIFECYCLE] resign active → saving state:", buttonState)
    saveLocalData(STATE_KEY, buttonState)
    saveLocalData(EVENT_KEY, "willResignActive")
  end
  
  lifecycle.onWillTerminate = function()
    print("[LIFECYCLE] terminate → saving state:", buttonState)
    saveLocalData(STATE_KEY, buttonState)
    saveLocalData(EVENT_KEY, "willTerminate")
  end
  
  -- set these callbacks for other lifecycle events
  lifecycle.onDidBecomeActive = function()
    print("[LIFECYCLE] did become active → state:", buttonState)
  end
  
  lifecycle.onDidEnterForeground = function()
    print("[LIFECYCLE] did enter foreground → state:", buttonState)
  end

  local lastEvent = readLocalData(EVENT_KEY, "none")
  print("[STARTUP] last saved lifecycle event:", lastEvent,
  "→ restored state:", buttonState)
end

function draw()
  background(32)
  
  -- Button geometry
  local bw, bh = 260, 64
  local bx = WIDTH/2 - bw/2
  local by = HEIGHT/2 - bh/2
  
  -- Visual state feedback
  local colors = {
    color(200, 80, 80),
    color(200, 160, 80),
    color(80, 180, 80),
    color(80, 140, 200),
    color(160, 80, 200),
  }
  
  fill(colors[buttonState])
  rect(bx, by, bw, bh, 12)
  
  fill(255)
  fontSize(22)
  textAlign(CENTER)
  textMode(CENTER)
  text("STATE "..buttonState, WIDTH/2, HEIGHT/2)
  
  -- Instructions
  fontSize(16)
  fill(200)
  text("Tap button to set its state→ \nHome / Lock / Kill app / Relaunch\nto verify its state persists",
  WIDTH/2, HEIGHT/2 - 90)
end

function touched(t)
  if t.state ~= BEGAN then return end
  
  local bw, bh = 260, 64
  local bx = WIDTH/2 - bw/2
  local by = HEIGHT/2 - bh/2
  
  if t.x >= bx and t.x <= bx + bw and
  t.y >= by and t.y <= by + bh then
    
    buttonState = (buttonState % MAX_STATE) + 1
    print("[UI] button tapped → state:", buttonState)
    
    -- Optional immediate save (cheap)
    saveLocalData(STATE_KEY, buttonState)
  end
end

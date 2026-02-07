require(asset.documents.CodeaAVPlayer)
require(asset.documents.LifecycleObserver)
require(asset.documents.iOS_Keyboard_Avoider)


-------------------------------------------------
-- Sample Data (2 teams)
-------------------------------------------------
teams = {
  {
    id   = 1,
    name = "Team 1",
    players = {
      { id=1, name="Lecia",  bid=4, took=4, spades=0 },
      { id=2, name="Arthur", bid=2, took=2, spades=5 },
    },
    hearts       = 0,
    queensSpades = false,
    moonShot     = false,
    spadesScore  = 60,
    heartsScore  = 72,
    handScore    = -12,
    handBags     = 0,
    allBags      = 0,
    spadesTotal  = 60,
    heartsTotal  = 72,
    gameTotal    = -12
  },
  {
    id   = 2,
    name = "Team 2",
    players = {
      { id=3, name="Elena", bid=4, took=7, spades=0 },
      { id=4, name="Jesse", bid=0, took=0, spades=8 },
    },
    hearts       = 0,
    queensSpades = false,
    moonShot     = false,
    spadesScore  = 0,
    heartsScore  = 0,
    handScore    = 0,
    handBags     = 0,
    allBags      = 0,
    spadesTotal  = 0,
    heartsTotal  = 0,
    gameTotal    = 0
  }
}

-------------------------------------------------
-- Layout “knobs”
-------------------------------------------------
layout = {
  overallWidthPercent   = 92.5, -- of safe area
  overallHeightPercent  = 50,   -- of safe area
  overallInnerPadding   = 4,    -- inside big rounded box
  
  leftTableWidthPercent = 51,   -- of inner width
  gapTablesPercent      = 0,    -- of inner width
  tablesHeightPercent   = 99.5, -- of inner height
  
  headerGap = 5,                -- px between header row and data rows
  teamGap   = 5,                -- px between team 1 and team 2 blocks
}

-- Left table column fractions (sum of base = 600)
LeftCols = {
  nameFrac   = 120/600,
  narrowFrac =  80/600,
  heartsFrac =  80/600,
}

-------------------------------------------------
-- Small helpers (globals used by ScoreTable)
------------------------------

-- basic cell drawer (used by ScoreTable)
function drawCell(x,y,w,h, label, fontSz, weight)
  pushStyle()
  fill(255) ; rectMode(CORNER) ; rect(x,y,w,h)
  stroke(0) ; strokeWidth(1)   ; noFill() ; rect(x,y,w,h)
  if label then
    fill(0) ; font("HelveticaNeue") ; fontSize(fontSz or 14) ; textAlign(CENTER)
    local cx,cy = x + w/2, y + h/2
    if weight == "bold" then text(label, cx+0.5, cy+0.5) end
    text(label, cx, cy)
  end
  popStyle()
end

-- Dev logger: writes to both Codea console (`print`) and Xcode console (`objc.log`).
function devLog(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring(select(i, ...))
  end
  local msg = table.concat(parts, " ")
  print(msg)
  if objc and objc.log then
    msg = "🧑‍💻 " .. msg
    objc.log(msg)
  end
end

-------------------------------------------------
-- Globals
-------------------------------------------------
sheets = nil

function setup()
  devLog("SETUP REACHED")
  viewer.mode = FULLSCREEN
  parameter.action("Save Game", function()
    saveGameState()
  end)
  parameter.action("Load Game", function()
    loadGameState()
  end)
  parameter.number("Archive Scale", 0.28, 0.62, 0.42, function(v)
    if sheets and sheets.archiveBrowser then sheets.archiveBrowser.scale = v end
  end)
  parameter.watch("ElapsedTime")
  parameter.number("overallWidthPercent",  50, 100, layout.overallWidthPercent,  function(v) layout.overallWidthPercent=v  end)
  parameter.number("overallHeightPercent", 1, 100, layout.overallHeightPercent, function(v) layout.overallHeightPercent=v end)
  parameter.number("leftTableWidthPercent",30,  60, layout.leftTableWidthPercent,function(v) layout.leftTableWidthPercent=v end)
  parameter.number("gapTablesPercent",      0,  10, layout.gapTablesPercent,     function(v) layout.gapTablesPercent=v     end)
  parameter.number("headerGap",             0,  20, layout.headerGap,            function(v) layout.headerGap=v            end)
  parameter.number("teamGap",               0,  20, layout.teamGap,              function(v) layout.teamGap=v              end)
  
  -- Start with your existing 'teams' object for the first table
  sheets = ScoreSheets(function() return teams end)

  devLog("ScoreSheets exists: ", ScoreSheets ~= nil)
  devLog("ScoreSheets instance exists: ", sheets ~= nil)

  --game persistence:
  
  loadGameState()
  
  lifecycle = LifecycleObserver()
  
  function persist(reason)
    devLog("[LIFECYCLE]", reason, "-> saving game state")
    local t = os.time()
    saveLocalData("lastSaveEpoch", t)
    saveLocalData("lastSaveReason", reason or "")
    saveGameState()
  end
  
  lifecycle.onWillResignActive = function()
    persist("will resign active")
  end
  
  lifecycle.onDidEnterBackground = function()
    persist("did enter background")
  end
  
  lifecycle.onWillTerminate = function()
    persist("will terminate")
  end
  
  local lastEpoch  = readLocalData("lastSaveEpoch")
  local lastReason = readLocalData("lastSaveReason")
  
  if lastEpoch then
    local pretty = os.date("%b %d, %Y, %I:%M %p", lastEpoch)
    devLog("[SAVE CHECK] last save:", pretty, "reason:", lastReason)
  else
    devLog("[SAVE CHECK] no prior save recorded")
  end
  
  videoPlayer = CodeaAVPlayer()
  
end

function draw()
  background(250, 150, 50)
  fill(255)
  text("HELLO FROM SPARTS", WIDTH/2, HEIGHT/2)
    if sheets then sheets:draw() end
end

function touched(t)
  if sheets and sheets:touched(t) then return end
end

function willClose()
  persist("willClose() called")
end

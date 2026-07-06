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

-------------------------------------------------
-- File I/O test helpers (Documents: vs asset.documents)
-------------------------------------------------

function launchNumber()
  local n = (readLocalData("PIN_lc") or 0) + 1
  saveLocalData("PIN_lc", n)
  return n
end

function textsFoundByDocuments()
  local a = readText("Documents:_pin_str.txt")
  return a and ("'" .. a .. "'") or "nil"
end

function textsFoundByAssetDocuments()
  local a = readText(asset.documents .. "_pin_key.txt")
  return a and ("'" .. a .. "'") or "nil"
end

function saveTextsBothWays()
  saveText("Documents:_pin_str.txt", "hello")
  saveText(asset.documents .. "_pin_key.txt", "hello")
  return "saved"
end

function testTextSaves()
  devLog("launch " .. launchNumber())
  devLog("texts found by 'Documents:': " .. textsFoundByDocuments())
  devLog("texts found by asset.documents: " .. textsFoundByAssetDocuments())
  devLog(saveTextsBothWays())
end

function resetTestState()
  saveLocalData("PIN_lc", 0)
  saveText("Documents:_pin_str.txt", nil)
  saveText(asset.documents .. "_pin_key.txt", nil)
  saveImage("Documents:_pin_str_img", nil)
  saveImage(asset.documents .. "_pin_key_img", nil)
  devLog("reset done — next launch will be launch 1 with all nil")
end

function imagesFoundByDocuments()
  local a = nil; pcall(function() a = readImage("Documents:_pin_str_img") end)
  return a and ("image " .. a.width .. "x" .. a.height) or "nil"
end

function imagesFoundByAssetDocuments()
  local a = nil; pcall(function() a = readImage(asset.documents .. "_pin_key_img") end)
  return a and ("image " .. a.width .. "x" .. a.height) or "nil"
end

function saveImagesBothWays()
  local r = image(32,32); setContext(r); background(255,0,0,255); setContext()
  saveImage("Documents:_pin_str_img", r)
  saveImage(asset.documents .. "_pin_key_img", r)
  return "saved"
end

function testImageSaves()
  devLog("images found by 'Documents:': " .. imagesFoundByDocuments())
  devLog("images found by asset.documents: " .. imagesFoundByAssetDocuments())
  devLog(saveImagesBothWays())
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
function reconcileTest()
  local p = "Documents:RECONCILE_test"
  devLog("RECON", "===")
  devLog("RECON", "app: " .. tostring(readLocalData and "Codea" or "unknown"))
  devLog("RECON", "saveText ok=" .. tostring(pcall(function() saveText(p .. ".txt", "hello " .. os.time()) end)))
  devLog("RECON", "readText back=" .. tostring(pcall(function() return readText(p .. ".txt") end) and readText(p .. ".txt") or "NIL"))
  local img = image(32,32); setContext(img); background(255,0,0,255); setContext()
  devLog("RECON", "saveImage ok=" .. tostring(pcall(function() saveImage(p .. ".png", img) end)))
  local ri = nil; pcall(function() ri = readImage(p .. ".png") end)
  devLog("RECON", "readImage back=" .. tostring(ri and ("found "..ri.width.."x"..ri.height) or "NIL"))
  if _flushLogBuffer then _flushLogBuffer() end
end

sheets = nil

function setup()
  devLog("SETUP REACHED")

  testTextSaves()
  testImageSaves()

  viewer.mode = FULLSCREEN

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
  movieActive = false

end

function draw()
  background(250, 150, 50)
  fill(255)
  text("HELLO FROM SPARTS", WIDTH/2, HEIGHT/2)
  if sheets then sheets:draw() end

  -- Show test results on screen
  if _testLines then
    pushStyle()
    fill(0, 255, 0)
    fontSize(13)
    textAlign(LEFT)
    textMode(CORNER)
    local y = HEIGHT - 20
    for i = #_testLines, 1, -1 do
      text(_testLines[i], 10, y)
      y = y - 16
    end
    popStyle()
  end
end

function touched(t)
  if sheets and sheets:touched(t) then return end
end

function willClose()
  persist("willClose() called")
end

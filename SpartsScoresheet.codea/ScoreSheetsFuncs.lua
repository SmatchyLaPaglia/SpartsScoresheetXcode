function ScoreSheets:_setNameFieldsEnabled(enabled)
  local fields = self._rawNameFields
  if not fields then return end
  
  for i = 1, #fields do
    local tf = fields[i]
    if tf then
      tf.enabled = enabled and true or false
    end
  end
end

function ScoreSheets:_ledgerHasData(snaps)
  for hi = 1, #snaps do
    for ti = 1, 2 do
      local s = snaps[hi][ti]
      if
      (s.spadesScore and s.spadesScore ~= 0) or
      (s.heartsScore and s.heartsScore ~= 0) or
      (s.handBags    and s.handBags    ~= 0)
      then
        return true
      end
    end
  end
  return false
end
function ScoreSheets:_saveLocalGame()
  print("saving")
  local dump = {
    date = os.date("%Y-%m-%d %H:%M:%S"),
    isWest  = self.tzBtn and self.tzBtn.isWest or false,
    inputs = self.archiveExporter:buildInputs(self)
  }
  saveText(asset.localGame, json.encode(dump))
end

function ScoreSheets:_loadLocalGame()
  print("loading")
  local s = readText(asset.localGame)
  if not s or s == "" then return end
  
  local ok, dump = pcall(json.decode, s)
  if not ok or type(dump) ~= "table" then return end
  if self.tzBtn and dump.isWest ~= nil then
    self.tzBtn.isWest = dump.isWest
  end
  
  if dump.inputs then
    self.tables = self:_tablesFromInputs(dump.inputs)
    self.ledger = nil 
  end
end

function ScoreSheets:_tablesFromInputs(inputs)
  local out = {}
  for hi = 1, #inputs do
    local hand = inputs[hi]
    local teams = {}
    for ti = 1, 2 do
      local src = hand.teams[ti]
      teams[ti] = {
        players = {
          {
            name = src.players[1].name,
            bid  = src.players[1].bid,
            took = src.players[1].took
          },
          {
            name = src.players[2].name,
            bid  = src.players[2].bid,
            took = src.players[2].took
          }
        },
        hearts       = src.hearts,
        queensSpades = src.queensSpades,
        moonShot     = src.moonShot,
        
        -- running totals will be recomputed by ledger
        spadesTotal = 0,
        heartsTotal = 0,
        gameTotal   = 0,
        allBags     = 0
      }
    end
    table.insert(out, ScoreTable(teams))
  end
  return out
end

function ScoreSheets:_syncTeamsFromAllTables()
  for i = 1, #self.tables do
    local t = self.tables[i]
    if t and t.syncBack then
      t:syncBack()
    end
  end
end

function ScoreSheets:_addHand()
  if self._gameOver then return end
  local last = self.tables[#self.tables]
  local teams = newTeamsFromPrevious(last.teams)
  table.insert(self.tables, ScoreTable(teams))
  
  local stepH, gapH = self:_stackMetrics()
  local d = stepH + gapH
  local targetY = (#self.tables - 1) * d  -- center the NEW hand
  self:_scrollTo(targetY, 0.4)            -- smooth scroll ~0.4s
  -- First time scrolling becomes possible: show hint overlay
  if not self._scrollHintEverShown then
    self._scrollHintEverShown = true
    self._scrollHintActive = true
    self._scrollHintDismissOnTouch = true
    self._scrollHintStartedAt = ElapsedTime
    self._scrollHintAlpha = 220  -- start visible
  end
  
end

function ScoreSheets:_onNameFieldChanged(oTF)
  local i = tonumber(oTF.tag or 0) or 0
  if i < 1 then return end
  
  local newName = tostring(oTF.text or "")
  
  local entry = self._nameData and self._nameData[i]
  if not entry then return end
  
  local slotTeam = entry.team
  local slotPlayer = entry.player
  
  for ti = 1, #self.tables do
    local t = self.tables[ti]
    local p = t and t.teams and t.teams[slotTeam] and t.teams[slotTeam].players and t.teams[slotTeam].players[slotPlayer]
    if p then p.name = newName end
  end
  
end

function ScoreSheets:_syncNameFieldFrames()
  if not self._rawNameFields or #self._rawNameFields == 0 then return end
  
  local t = self.tables[1]
  if not t then return end
  t:layout()
  local m = t.metrics
  if not m then return end
  
  -- These are Codea-space Y anchors for the first table’s name rows
  local ys = { m.t1_row1, m.t1_row2, m.t2_row1, m.t2_row2 }
  
  for i, tf in ipairs(self._rawNameFields) do
    local y = ys[i]
    if y and tf then
      -- IMPORTANT: fields must scroll with the same scrollY as the drawn content
      local sy = self:_effectiveScrollY()
      tf.frame = codeaToUIKitRect(m.innerX, y + sy, m.wName, m.leftRowH)
    end
  end
end

-- Default teams for the very first table/hand
function ScoreSheets:_defaultTeams()
  local function team()
    return {
      players = { {name="A", bid=nil, took=nil}, {name="B", bid=nil, took=nil} },
      hearts=nil, queensSpades=false, moonShot=false,
      -- cumulative/running
      spadesTotal=0, heartsTotal=0, gameTotal=0, allBags=0,
      -- per-hand derived (optional — convenient to keep here)
      spadesScore=nil, heartsScore=nil, handBags=nil, _oppMoonBonus=0
    }
  end
  return { team(), team() }
end

function ScoreSheets:_resetAll()
  local first = self.tables[1] and self.tables[1].teams
  local function freshFrom(team)
    return {
      players = {
        { name = team and team.players[1].name or "A", bid=nil, took=nil },
        { name = team and team.players[2].name or "B", bid=nil, took=nil },
      },
      hearts=nil, queensSpades=false, moonShot=false,
      -- running totals cleared
      spadesTotal=0, heartsTotal=0, gameTotal=0, allBags=0,
      -- per-hand derived cleared
      spadesScore=nil, heartsScore=nil, handBags=nil, _oppMoonBonus=0
    }
  end
  
  local teams = {
    freshFrom(first and first[1]),
    freshFrom(first and first[2]),
  }
  
  self.tables = { ScoreTable(teams) }
  self.scrollY = 0
  -- Reset player names back to placeholders (UIKit is source-of-truth here)
  if self._rawNameFields then
    for i, tf in ipairs(self._rawNameFields) do
      local ph = "Player "..tostring(i)
      tf.text = ph
      self:_onNameFieldChanged(tf)
    end
  end  
  
  self._gameOver = false
  self._winningTeam = nil
  self._winningMode = nil
  
  clearLocalData()
end

function ScoreSheets:_contentSpan()
  local stepH, gapH = self:_stackMetrics()
  local d = stepH + gapH
  return math.max(0, (#self.tables - 1) * d)
end

function ScoreSheets:_clampScroll()
  local span = self:_contentSpan()
  if self.scrollY < 0     then self.scrollY = 0 end
  if self.scrollY > span  then self.scrollY = span end
end

function ScoreSheets:_scrollTo(targetY, duration)
  local span = self:_contentSpan()
  local clamped = math.max(0, math.min(span, targetY))
  if self._scrollTween then tween.stop(self._scrollTween) end
  -- duration default ~0.35s; linear tween is fine (omit easing arg for safety)
  self._scrollTween = tween(duration or 0.35, self, { scrollY = clamped }, nil, function()
    self._scrollTween = nil
  end)
end

-- returns (stepH, gapH)
function ScoreSheets:_stackMetrics()
  -- Ensure we have fresh layout metrics from the first table
  local t = self.tables and self.tables[1]
  if t and t.layout then t:layout() end
  
  -- vertical extent of a table block (matches your layout knob)
  local stepH = HEIGHT * ((layout and layout.overallHeightPercent or 50) / 100)
  
  -- gap between hands: ~ one row height (fallback if metrics not ready yet)
  local rowH = (t and t.metrics and t.metrics.leftRowH) or 16
  local gapH = rowH * 1.2
  
  return stepH, gapH
end

function ScoreSheets:_presentNewGameConfirm()
  local UIAlertController = objc.UIAlertController
  local UIAlertAction = objc.UIAlertAction
  
  local alert = UIAlertController:alertControllerWithTitle_message_preferredStyle_(
  "New Game",
  "Reset all fields and archive current game?",
  objc.enum.UIAlertControllerStyle.alert
  )
  
  local cancel = UIAlertAction:actionWithTitle_style_handler_(
  "Cancel",
  objc.enum.UIAlertActionStyle.destructive,
  nil
  )
  
  local confirm = UIAlertAction:actionWithTitle_style_handler_(
  "Confirm",
  objc.enum.UIAlertActionStyle.default,
  function()
    self._resetAfterArchive = true
    self._archivingStage = 0
    self.archiveExporter:request()
  end
  )
  
  alert:addAction_(confirm)
  alert:addAction_(cancel)
  
  local vc = objc.viewer
  vc:presentViewController_animated_completion_(alert, true, nil)
end

function ScoreSheets:_saveArchiveSnapshot()
  if not self._inDraw then self._pendingArchiveSnapshot = true; return end
  print("saving")
  local stepH, gapH = self:_stackMetrics()
  local d = stepH + gapH
  local n = #self.tables
  
  -- total height for all hands + a little header space
  local topPad = 120
  local botPad = 80
  local totalH = math.floor(topPad + (stepH * n) + (gapH * math.max(0, n - 1)) + botPad + 0.5)
  local rt = image(WIDTH, totalH)
  setContext(rt)
  background(35)
  fill(255)
  fontSize(40)
  print("SNAP "..tostring(WIDTH).."x"..tostring(totalH), WIDTH/2, totalH/2)
  setContext()
  --            saveImage(asset.SpartsArchives .. "test.png", rt)
  if true then return end
  
  local stepH, gapH = self:_stackMetrics()
  local d = stepH + gapH
  local n = #self.tables
  
  -- total height for all hands + a little header space
  local topPad = 120
  local botPad = 80
  local totalH = math.floor(topPad + (stepH * n) + (gapH * math.max(0, n - 1)) + botPad + 0.5)
  
  
  local rt = image(WIDTH, totalH)
  local baseName = self:_archiveBaseName()
  
  -- freeze scrolling while snapshotting
  local oldScrollY = self.scrollY
  local oldKbShift = self._kbShiftY
  self.scrollY = 0
  self._kbShiftY = 0
  
  setContext(rt)
  pushStyle()
  background(35)
  
  -- shift so the first hand sits near the top of the tall image
  local desiredCenterY = totalH - topPad - (stepH * 0.5)
  local baseShift = desiredCenterY - (HEIGHT * 0.5)  -- NOTE: HEIGHT is rt height inside setContext
  
  for i = 1, n do
    pushMatrix()
    translate(0, baseShift - (i - 1) * d)
    self.tables[i]:draw()
    popMatrix()
  end
  
  popStyle()
  setContext()
  
  -- restore
  self.scrollY = oldScrollY
  self._kbShiftY = oldKbShift
  if false then 
    -- save image
    saveImage(asset.SpartsArchives  .. baseName .. ".png", rt)
  end
  
  -- save metadata (JSON)
  local meta = {
    created = os.date("%Y-%m-%d %H:%M:%S"),
    nameStamp = self:_currentNameStamp(),
    hands = n
  }
  
  saveText(
  asset.SpartsArchives .. baseName .. ".json",
  json.encode(meta)
  )
end


function ScoreSheets:_currentNameStamp()
  local t = self.tables and self.tables[1]
  local teams = t and t.teams
  if not teams then return "Game" end
  
  local p11 = _safeFilePart(teams[1].players[1].name)
  local p12 = _safeFilePart(teams[1].players[2].name)
  local p21 = _safeFilePart(teams[2].players[1].name)
  local p22 = _safeFilePart(teams[2].players[2].name)
  
  return p11 .. "-" .. p12 .. "__" .. p21 .. "-" .. p22
end

function ScoreSheets:_archiveBaseName()
  local date = os.date("%Y-%m-%d_%H%M")
  return date .. "__" .. self:_currentNameStamp()
end
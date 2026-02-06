-- ArchiveExporter.lua
ArchiveExporter = class()

function ArchiveExporter:init()
  self.pending = false
end

function ArchiveExporter:request()
  print("ArchiveExporter:request has fired")
  
  self.pending = true
end

-- Call once per frame from ScoreSheets:draw() as: self.archiveExporter:update(self)
function ArchiveExporter:update(ss)
  if not self.pending then return 
  end
  print("ArchiveExporter:update is pending")
  self.pending = false
  self:_doSnapshotNow(ss)
end

function ArchiveExporter:_doSnapshotNow(ss)
  if not ss then return end
  if not ss.tables or #ss.tables == 0 then return end
  
  local fields = ss._rawNameFields or {}
  for i = 1, #fields do
    local tf = fields[i]
    if tf then tf.hidden = true end
  end
  
  local oldScrollY = ss.scrollY
  local oldKbShift = ss._kbShiftY
  ss.scrollY = 0
  ss._kbShiftY = 0
  
  local stepH, gapH = ss:_stackMetrics()
  local d = stepH + gapH
  local n = #ss.tables
  
  local topPad = 105
  local botPad = 80
  local totalH = math.floor(topPad + (stepH * n) + (gapH * math.max(0, n - 1)) + botPad + 0.5)
  
  local img = image(WIDTH, totalH)
  
  setContext(img)
  pushStyle()
  background(35)
  
  local uiInset = 10
  
  -- Header row (toggle left, date centered)
  do
    local coastStr = ((ss.tzBtn and ss.tzBtn.isWest) and "West Coast") or "East Coast"
    
    -- Prefer the same date string the sheet uses (if available), otherwise fallback.
    local dateStr
    if ss._dateString then
      dateStr = ss:_dateString()
    elseif ss._archiveDateString then
      dateStr = ss:_archiveDateString()
    else
      dateStr = os.date("%b %d, %Y")
    end
  end
  
  local desiredCenterY = totalH - topPad - (stepH * 0.5)
  local baseShift = desiredCenterY - (HEIGHT * 0.5)
  
  for i = 1, n do
    pushMatrix()
    translate(0, baseShift - (i - 1) * d)
    -- "Hand X:" label before each hand (omit first to avoid colliding with coast label)
    
    local t = ss.tables[i]
    local m = t and t.metrics
    if m then
      pushStyle()
      font("Chalkduster")
      fontSize(22)            -- smaller so it fits between tables
      fill(130)
      textAlign(LEFT)
      textMode(CORNER)
      
      local centerY = HEIGHT * 0.5
      local topY    = centerY + (stepH * 0.5)
      local lx      = m.innerX + uiInset   -- EXACT left edge of table
      local ly      = topY + 2             -- small breathing room
      
      text("HAND " .. i .. ":", lx, ly)
      popStyle()
    end
    ss.tables[i]:draw()
    popMatrix()
  end
  
  -- Header + top-left coast toggle (match ScoreSheets placement & style)
  do
    local t = ss.tables[1]
    local m = t and t.metrics
    if m then
      -- draw in the same translated space as table 1
      pushMatrix()
      translate(0, baseShift)
      
      local topY = m.innerY + m.tablesH
      local gap  = 9
      
      -- ======= Date (same anchor math) =======
      do
        pushStyle()
        font("Chalkduster")
        local spY = topY + (m.leftRowH * 1.85) - 20 -- sy is 0 in exporter
        fontSize(38)
        fill(231, 235)   -- near white, not pure
        textAlign(CENTER)
        textMode(CENTER)
        text(os.date("%B %d, %Y"), WIDTH * 0.5, spY)
        popStyle()
      end
      
      -- ======= Coast toggle (boxed) =======
      do
        local tw = (ss.tzBtn and ss.tzBtn.w) or 120
        local th = (ss.tzBtn and ss.tzBtn.h) or 44
        
        -- in ScoreSheets this is the "upper row" (tyNewGame)
        local ty = topY + gap
        local tyNewGame = ty + th + (gap * 2)
        local tx = m.innerX
        
        pushStyle()
        fill(50)
        stroke(70)
        strokeWidth(3)
        rect(tx, tyNewGame - th/2, tw, th, 10)
        
        fill(160)
        font("Chalkduster")
        fontSize(18)
        textAlign(CENTER)
        textMode(CENTER)
        local label = (ss.tzBtn and ss.tzBtn.isWest) and "WEST COAST" or "EAST COAST"
        text(label, tx + tw * 0.5, tyNewGame)
        popStyle()
      end
      
      popMatrix()
    end
  end
  
  popStyle()
  setContext()
  
  ss.scrollY = oldScrollY
  ss._kbShiftY = oldKbShift
  
  for i = 1, #fields do
    local tf = fields[i]
    if tf then tf.hidden = false end
  end
  
  local baseName = ss:_archiveBaseName() or ("Archive_" .. os.date("%Y%m%d_%H%M%S"))
  local folder = "SpartsArchives/"
  saveImage(asset .. folder .. baseName .. ".png", img)
  
  -- Build raw inputs
  local inputs   = self:buildInputs(ss)
  
  -- Build computed snapshots (fresh + consistent)
  ss.ledger = ss.ledger or ScoreLedger(ScoreRules, nil)
  local snaps = ss.ledger:computeSnapshotsForTables(ss.tables)
  
  local computed = self:buildComputed(ss)
  
  local ledgerDump = {
    meta = {
      created    = os.date("%Y-%m-%d %H:%M:%S"),
      coast = (ss.tzBtn and ss.tzBtn.isWest) and "WEST" or "EAST",
      nameStamp  = (ss._currentNameStamp and ss:_currentNameStamp()) or "",
      rules      = "ScoreRules_v1",
      hands      = #ss.tables
    },
    inputs   = inputs,
    computed = computed
  }
  
  saveText(asset .. "SpartsArchives/" .. baseName .. ".json", json.encode(ledgerDump))
  local indexAsset = asset .. "SpartsArchives/index.json"
  
  local idx = _readJsonOrEmpty(indexAsset)
  
  idx.items = idx.items or {}
  table.insert(idx.items, 1, { base = baseName, created = os.time() })
  
  _writeJson(indexAsset, idx)
end

function _readJsonOrEmpty(a)
  local s = readText(a)
  if not s or s == "" then return {} end
  local ok, t = pcall(json.decode, s)
  if ok and type(t) == "table" then return t end
  return {}
end

function _writeJson(a, t)
  saveText(a, json.encode(t))
end

function ArchiveExporter:buildInputs(ss)
  local inputs = {}
  
  for hi = 1, #ss.tables do
    local t = ss.tables[hi]
    local hand = { teams = {} }
    
    for ti = 1, 2 do
      local team = t.teams[ti]
      hand.teams[ti] = {
        players = {
          {
            name = tostring(team.players[1].name or ""),
            bid  = team.players[1].bid,
            took = team.players[1].took
          },
          {
            name = tostring(team.players[2].name or ""),
            bid  = team.players[2].bid,
            took = team.players[2].took
          }
        },
        hearts       = team.hearts,
        queensSpades = team.queensSpades and true or false,
        moonShot     = team.moonShot and true or false
      }
    end
    
    inputs[hi] = hand
  end
  
  return inputs
end


function ArchiveExporter:buildComputed(ss)
  ss.ledger = ss.ledger or ScoreLedger(ScoreRules, nil)
  local snaps = ss.ledger:computeSnapshotsForTables(ss.tables)
  
  local out = {}
  
  for hi = 1, #snaps do
    out[hi] = { teams = {} }
    for ti = 1, 2 do
      local s = snaps[hi][ti]
      out[hi].teams[ti] = {
        spadesScore = s.spadesScore,
        heartsScore = s.heartsScore,
        handBags    = s.handBags,
        spadesTotal = s.spadesTotal,
        heartsTotal = s.heartsTotal,
        allBags     = s.allBags,
        gameTotal   = s.gameTotal
      }
    end
  end
  
  return out
end

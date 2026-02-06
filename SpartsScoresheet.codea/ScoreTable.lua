-- ScoreTable.lua
-- Renders the two-table sheet and uses IncrementingCell + CheckboxCell.

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
  
  grandWeight     = 1.5,   -- grand totals 1.5x wider than other right columns
  grandFundFrac   = 0.55  -- how much of that extra comes from left (non-name) columns
}

-- Left table column fractions (sum of base = 600)
LeftCols = {
  nameFrac   = 120/600,
  narrowFrac =  80/600,
  heartsFrac =  80/600,
}

-- ALT layout: absolute column widths (from your dump)
local ALT_COLS = {
  { key="NAME",  w=137 },
  { key="BTLABEL", w=52 },
  { key="BID",     w=52 },
  { key="TOOK",    w=52 },
  { key="HEART", w=52  },
  { key="QUEEN", w=52  },
  { key="MOON",  w=52  },
  { key="R1",    w=46  },
  { key="R2",    w=46  },
  { key="R3",    w=46  },
  { key="R4",    w=46  },
  { key="R5",    w=46  },
  { key="R6",    w=46  },
  { key="GRAND", w=69  },
}

local function buildEdges(x0, cols)
  local edges = { x0 }
  local x = x0
  for i = 1, #cols do
    x = x + cols[i].w
    edges[i+1] = x
  end
  return edges
end

ScoreTable = class()

function ScoreTable:init(teams)
  self.teams = teams
  self.cells = {}
  self._scrollY = 0
  -- Incrementing cells (10)
  self.cells.t1_p1_bid   = IncrementingCell(0,0,0,0, teams[1].players[1].bid)
  self.cells.t1_p1_took  = IncrementingCell(0,0,0,0, teams[1].players[1].took)
  self.cells.t1_p2_bid   = IncrementingCell(0,0,0,0, teams[1].players[2].bid)
  self.cells.t1_p2_took  = IncrementingCell(0,0,0,0, teams[1].players[2].took)
  self.cells.t1_hearts   = IncrementingCell(0,0,0,0, teams[1].hearts)
  
  self.cells.t2_p1_bid   = IncrementingCell(0,0,0,0, teams[2].players[1].bid)
  self.cells.t2_p1_took  = IncrementingCell(0,0,0,0, teams[2].players[1].took)
  self.cells.t2_p2_bid   = IncrementingCell(0,0,0,0, teams[2].players[2].bid)
  self.cells.t2_p2_took  = IncrementingCell(0,0,0,0, teams[2].players[2].took)
  self.cells.t2_hearts   = IncrementingCell(0,0,0,0, teams[2].hearts)
  
  -- Checkbox cells (4)
  self.cells.t1_qs       = CheckboxCell(0,0,0,0, teams[1].queensSpades)
  self.cells.t1_moon     = CheckboxCell(0,0,0,0, teams[1].moonShot)
  self.cells.t2_qs       = CheckboxCell(0,0,0,0, teams[2].queensSpades)
  self.cells.t2_moon     = CheckboxCell(0,0,0,0, teams[2].moonShot)
  
  -- Optional bounds for incrementing cells
  for k,c in pairs(self.cells) do
    if c.set then
      c.min, c.max, c.wrap = 0, 13, true
    end
  end
  
  for k, c in pairs(self.cells) do
    if c.set then
      local v = c.value
      if v ~= nil then
        c:set(v)
      else
        c:unset()
      end
    end
  end
  
  -- Long-press sensors (names + header)
  self.lp = {
    t1_p1_name = Sensor{ parent = {x=0,y=0,w=0,h=0} },
    t1_p2_name = Sensor{ parent = {x=0,y=0,w=0,h=0} },
    t2_p1_name = Sensor{ parent = {x=0,y=0,w=0,h=0} },
    t2_p2_name = Sensor{ parent = {x=0,y=0,w=0,h=0} },
    headerTeam = Sensor{ parent = {x=0,y=0,w=0,h=0} },
  }
  self._lpTH = 0.45
  for _, s in pairs(self.lp) do
    s._pressed, s._start, s._fired = false, nil, false
    s:onTouch(function(ev)
      if ev.state then
        s._pressed = true; s._start = ElapsedTime; s._fired = false
      else
        s._pressed = false; s._start = nil;        s._fired = false
      end
    end)
  end
  self:_skinInputs()
end

-- Toggle LP (used by ScoreSheets while dragging)
function ScoreTable:setLongPressEnabled(on)
  self.longPressEnabled = (on ~= false)
  if not self.longPressEnabled then
    for _, s in pairs(self.lp) do
      s._pressed, s._start, s._fired = false, nil, false
    end
  end
end

function ScoreTable:_clearPlayer(teamIndex, playerIndex)
  if teamIndex == 1 and playerIndex == 1 then
    self:_resetCellToUnset(self.cells.t1_p1_bid)
    self:_resetCellToUnset(self.cells.t1_p1_took)
    self:_resetCellToUnset(self.cells.t1_hearts)
    self.cells.t1_qs.value   = false
    self.cells.t1_moon.value = false
    
  elseif teamIndex == 1 and playerIndex == 2 then
    self:_resetCellToUnset(self.cells.t1_p2_bid)
    self:_resetCellToUnset(self.cells.t1_p2_took)
    self:_resetCellToUnset(self.cells.t1_hearts)
    self.cells.t1_qs.value   = false
    self.cells.t1_moon.value = false
    
  elseif teamIndex == 2 and playerIndex == 1 then
    self:_resetCellToUnset(self.cells.t2_p1_bid)
    self:_resetCellToUnset(self.cells.t2_p1_took)
    self:_resetCellToUnset(self.cells.t2_hearts)
    self.cells.t2_qs.value   = false
    self.cells.t2_moon.value = false
    
  else -- team 2, player 2
    self:_resetCellToUnset(self.cells.t2_p2_bid)
    self:_resetCellToUnset(self.cells.t2_p2_took)
    self:_resetCellToUnset(self.cells.t2_hearts)
    self.cells.t2_qs.value   = false
    self.cells.t2_moon.value = false
  end
end

function ScoreTable:_resetHeaderLP()
  local s = self.lp and self.lp.headerTeam
  if s then
    s._pressed = false
    s._start   = nil
    s._fired   = false
  end
end

function ScoreTable:_clearEntireHand()
  self:_resetCellToUnset(self.cells.t1_p1_bid)
  self:_resetCellToUnset(self.cells.t1_p1_took)
  self:_resetCellToUnset(self.cells.t1_p2_bid)
  self:_resetCellToUnset(self.cells.t1_p2_took)
  self:_resetCellToUnset(self.cells.t2_p1_bid)
  self:_resetCellToUnset(self.cells.t2_p1_took)
  self:_resetCellToUnset(self.cells.t2_p2_bid)
  self:_resetCellToUnset(self.cells.t2_p2_took)
  
  self:_resetCellToUnset(self.cells.t1_hearts)
  self:_resetCellToUnset(self.cells.t2_hearts)
  
  self.cells.t1_qs.value=false; self.cells.t1_moon.value=false
  self.cells.t2_qs.value=false; self.cells.t2_moon.value=false
end

function ScoreTable:setCellFrame(cell, x, y, w, h)
  cell.x, cell.y, cell.w, cell.h = x, y, w, h
  if cell.sensor then
    cell.sensor:setParent{ parent = cell, xywhMode = CORNER }
  end
end

function ScoreTable:_resetCellToUnset(cell)
  if cell.unset then
    cell:unset()
  else
    cell.value  = 0
    cell.hasSet = false
  end
end

function ScoreTable:_applyNumberFontSize()
  for _, c in pairs(self.cells) do
    if c.set then        -- only incrementing cells have :set()
      c.fontSize = self.numberFontSize
    end
  end
end

function ScoreTable:syncBack()
  local t = self.teams
  
  local function fromCell(numCell)  -- returns number or nil
    return (numCell and numCell.hasSet) and numCell.value or nil
  end
  local function fromCheck(checkCell) -- booleans default to false unless explicitly true
    return (checkCell and checkCell.value == true) or false
  end
  
  -- Team 1
  t[1].players[1].bid  = fromCell(self.cells.t1_p1_bid)
  t[1].players[1].took = fromCell(self.cells.t1_p1_took)
  t[1].players[2].bid  = fromCell(self.cells.t1_p2_bid)
  t[1].players[2].took = fromCell(self.cells.t1_p2_took)
  t[1].hearts          = fromCell(self.cells.t1_hearts)
  t[1].queensSpades    = fromCheck(self.cells.t1_qs)
  t[1].moonShot        = fromCheck(self.cells.t1_moon)
  
  -- Team 2
  t[2].players[1].bid  = fromCell(self.cells.t2_p1_bid)
  t[2].players[1].took = fromCell(self.cells.t2_p1_took)
  t[2].players[2].bid  = fromCell(self.cells.t2_p2_bid)
  t[2].players[2].took = fromCell(self.cells.t2_p2_took)
  t[2].hearts          = fromCell(self.cells.t2_hearts)
  t[2].queensSpades    = fromCheck(self.cells.t2_qs)
  t[2].moonShot        = fromCheck(self.cells.t2_moon)
end

-- draw a filled cell with border + centered label
function ScoreTable:_cell(x,y,w,h, bg, txt, txtCol, fsz)
  pushStyle()
  fill(bg) ; stroke(Theme.gridLine) ; strokeWidth(1)
  rectMode(CORNER) ; rect(x,y,w,h)
  if txt then
    fill(txtCol or Theme.textOnLight)
    font("HelveticaNeue-Bold")
    fontSize(fsz or (h*0.45))
    textAlign(CENTER)
    text(txt, x + w/2, y + h/2)
  end
  popStyle()
end

-- pre-skin all interactive cells (left side) with theme colors
function ScoreTable:_skinInputs()
  for _, c in pairs(self.cells) do
    if c and c.set then
      c.colBg        = Theme.cellBg
      c.colBgPressed = Theme.cellBgPressed
      c.colStroke    = Theme.gridLine
      c.colText      = Theme.textAccentBlue
      c.colTextUnset = Theme.textDisabled
    elseif c and c.value ~= nil then -- checkbox
      c.colBg        = Theme.cellBg
      c.colBgPressed = Theme.cellBgPressed
      c.colStroke    = Theme.gridLine
      c.colTick      = Theme.checkboxTick
    end
  end
end

function ScoreTable:layout()
  local safeW, safeH = WIDTH, HEIGHT
  
  -- Prefer flags provided by ScoreSheets (gyro workaround), else fall back.
  local notchOnLeft  = (self.notchOnLeft  == true)
  local notchOnRight = (self.notchOnRight == true)
  
  if not notchOnLeft and not notchOnRight then
    notchOnLeft  = (CurrentOrientation == LANDSCAPE_RIGHT) -- notch is LEFT
    notchOnRight = (CurrentOrientation == LANDSCAPE_LEFT)  -- notch is RIGHT
  end
  
  local overallW0 = safeW * layout.overallWidthPercent / 100
  local overallH  = safeH * layout.overallHeightPercent / 100
  
  local extra = 0
  if notchOnLeft or notchOnRight then
    extra = 44 -- tune (unchanged)
  end
  
  local inset = 5
  
  local baseX = (safeW - overallW0) / 2
  local leftEdge, rightEdge
  
  if notchOnLeft then
    leftEdge  = baseX
    rightEdge = baseX + (overallW0 + extra)
    leftEdge  = leftEdge + inset
    rightEdge = rightEdge - inset
    
  elseif notchOnRight then
    rightEdge = baseX + overallW0
    leftEdge  = rightEdge - (overallW0 + extra)
    leftEdge  = leftEdge + inset
    rightEdge = rightEdge - inset
    
  else
    leftEdge  = baseX + inset
    rightEdge = (baseX + overallW0) - inset
  end
  
  leftEdge  = math.max(inset, leftEdge)
  rightEdge = math.min(safeW - inset, rightEdge)
  
  local overallX = leftEdge
  local overallW = math.max(0, rightEdge - leftEdge)
  local overallY = (safeH - overallH) / 2
  
  local pad = layout.overallInnerPadding
  local innerX, innerY = overallX + pad, overallY + pad
  local innerW, innerH = overallW - pad*2, overallH - pad*2
  local tablesH = innerH * layout.tablesHeightPercent / 100
  
  self.metrics = self.metrics or {}
  local m = self.metrics
  
  -- Basic vertical sizing (keep identical to legacy)
  m.leftHeaderH  = math.max(28, math.min(64, tablesH / 5))
  m.leftRowH     = m.leftHeaderH
  m.rightHeaderH = m.leftHeaderH
  m.rightRowH    = m.leftRowH
  
  -- Store inner rect + table height
  m.innerX, m.innerY = innerX, innerY
  m.tablesH = tablesH
  m.cols = ALT_COLS
  
  -- Build absolute X edges from the column spec
  m.x = buildEdges(innerX, ALT_COLS)  -- m.x[1]=x0 ... m.x[15]=x14
  m.tablesW = m.x[#m.x] - m.x[1]
  
  -- Convenience: column width by 1-based column index
  local function colW(ci)
    return m.x[ci + 1] - m.x[ci]
  end
  
  -- Recreate legacy-ish aggregates so existing draw code can keep working
  m.wName   = colW(1)   -- NAME
  m.wNarrow = colW(2)   -- BID (and also TOOK/SPADE widths)
  m.wHearts = colW(5)   -- HEARTS (and also QUEEN/MOON widths)
  
  -- Right-side: R columns are 46, Grand is 69 (keep both)
  m.wScore  = colW(8)   -- R1 width (46)
  m.wGrand  = colW(14)  -- GRAND width (69)
  
  -- Boundaries between left/right sections
  m.leftW  = (m.x[8]  - m.x[1])   -- NAME..MOON
  m.gapW   = 0
  m.rightW = (m.x[15] - m.x[8])   -- R1..GRAND
  
  -- Y positions (identical to legacy)
  m.headY   = innerY + tablesH - m.leftHeaderH
  m.yAfterHeadGap = m.headY - layout.headerGap
  m.t1_row1 = m.yAfterHeadGap - m.leftRowH
  m.t1_row2 = m.t1_row1 - m.leftRowH
  m.t2_row1 = m.t1_row2 - layout.teamGap - m.leftRowH
  m.t2_row2 = m.t2_row1 - m.leftRowH
  
  self.numberFontSize = m.leftRowH * 0.5
  
  -- Long-press sensor rects (names + TEAMS header)
  local function nameRect(y)
    return { x = m.x[1], y = y, w = colW(1), h = m.leftRowH }
  end
  self.lp.t1_p1_name:setParent{ parent = nameRect(m.t1_row1), xywhMode = CORNER }
  self.lp.t1_p2_name:setParent{ parent = nameRect(m.t1_row2), xywhMode = CORNER }
  self.lp.t2_p1_name:setParent{ parent = nameRect(m.t2_row1), xywhMode = CORNER }
  self.lp.t2_p2_name:setParent{ parent = nameRect(m.t2_row2), xywhMode = CORNER }
  
  self.lp.headerTeam:setParent{
    parent   = { x = m.x[1], y = m.headY, w = colW(1), h = m.leftHeaderH },
    xywhMode = CORNER
  }
  
  --------------------------------------------------------------------
  -- Cell frames: ALL explicit, NO ellipses
  -- Columns (ALT_COLS):
  --  1 NAME
  --  2 BTLABEL (chip-only)
  --  3 BID
  --  4 TOOK
  --  5 HEARTS
  --  6 QUEEN
  --  7 MOON
  --------------------------------------------------------------------
  -- Team 1, player 1 (top row)
  self:setCellFrame(self.cells.t1_p1_bid,  m.x[3], m.t1_row1, colW(3), m.leftRowH)
  self:setCellFrame(self.cells.t1_p1_took, m.x[4], m.t1_row1, colW(4), m.leftRowH)
  
  -- Team 1, player 2 (second row)
  self:setCellFrame(self.cells.t1_p2_bid,  m.x[3], m.t1_row2, colW(3), m.leftRowH)
  self:setCellFrame(self.cells.t1_p2_took, m.x[4], m.t1_row2, colW(4), m.leftRowH)
  
  self:setCellFrame(self.cells.t1_hearts, m.x[5], m.t1_row2, colW(5), m.leftRowH)
  self:setCellFrame(self.cells.t1_qs,     m.x[6], m.t1_row2, colW(6), m.leftRowH)
  self:setCellFrame(self.cells.t1_moon,   m.x[7], m.t1_row2, colW(7), m.leftRowH)
  
  -- Team 2, player 1 (third row)
  self:setCellFrame(self.cells.t2_p1_bid,  m.x[3], m.t2_row1, colW(3), m.leftRowH)
  self:setCellFrame(self.cells.t2_p1_took, m.x[4], m.t2_row1, colW(4), m.leftRowH)
  
  -- Team 2, player 2 (bottom row)
  self:setCellFrame(self.cells.t2_p2_bid,  m.x[3], m.t2_row2, colW(3), m.leftRowH)
  self:setCellFrame(self.cells.t2_p2_took, m.x[4], m.t2_row2, colW(4), m.leftRowH)
  
  self:setCellFrame(self.cells.t2_hearts, m.x[5], m.t2_row2, colW(5), m.leftRowH)
  self:setCellFrame(self.cells.t2_qs,     m.x[6], m.t2_row2, colW(6), m.leftRowH)
  self:setCellFrame(self.cells.t2_moon,   m.x[7], m.t2_row2, colW(7), m.leftRowH)
  self:_applyNumberFontSize()
end

function ScoreTable:draw()
  -- layout + skin + sync
  self:layout()
  
  local m = self.metrics
  local x = m.x
  
  -- Helpers to read widths from edge indices
  local function w(i0, i1) return (x[i1] - x[i0]) end
  
  --------------------------------------------------------------------------
  -- TOP HEADER (same semantics, computed by spans)
  --------------------------------------------------------------------------
  local handGroupW  = w(8, 11)   -- R1..R3
  local totalGroupW = w(11, 14)  -- R4..R6
  local grandGroupW = w(14, 15)  -- GRAND
  
  local headerFont = math.min(
  fitFontSize("TEAMS",        w(1,2)-10, m.leftHeaderH-8, 1),
  fitFontSize("SPADES",       w(2,5)-10, m.leftHeaderH-8, 1),
  fitFontSize("HEARTS",       w(5,8)-10, m.leftHeaderH-8, 1),
  fitFontSize("Hand\nScores",  handGroupW-10,  m.leftHeaderH-8, 2),
  fitFontSize("Total\nScores", totalGroupW-10, m.leftHeaderH-8, 2),
  fitFontSize("Grand\nTotal",  grandGroupW-10, m.leftHeaderH-8, 2)
  )
  
  -- Left titles
  self:_cell(x[1], m.headY, w(1,2), m.leftHeaderH, Theme.leftHeaderBg, "TEAMS",  Theme.leftHeaderText, headerFont)
  self:_cell(x[2], m.headY, w(2,5), m.leftHeaderH, Theme.leftHeaderBg, "SPADES", Theme.leftHeaderText, headerFont)
  self:_cell(x[5], m.headY, w(5,8), m.leftHeaderH, Theme.leftHeaderBg, "HEARTS", Theme.leftHeaderText, headerFont)
  
  -- Right titles
  self:_cell(x[8],  m.headY, handGroupW,  m.leftHeaderH, Theme.leftHeaderBg, "HAND\nSCORES",  Theme.leftHeaderText, headerFont)
  self:_cell(x[11], m.headY, totalGroupW, m.leftHeaderH, Theme.leftHeaderBg, "TOTAL\nSCORES", Theme.leftHeaderText, headerFont)
  self:_cell(x[14], m.headY, grandGroupW, m.leftHeaderH, Theme.leftHeaderBg, "GRAND\nTOTAL",  Theme.leftHeaderText, headerFont)
  
  --------------------------------------------------------------------------
  -- LEFT TABLE (names + chips)
  --------------------------------------------------------------------------
  local function nameStripe(i) return (i%2==1) and Theme.nameStripeLight or Theme.nameStripeDark end
  local nameFS  = m.leftRowH * 0.42
  local chipFS  = m.leftRowH * 0.32
  
  local PLACEHOLDER_COL  = color(175)
  local BLACK = color(0, 0, 0, 255)
  
  self:_cell(x[1], m.t1_row1, w(1,2), m.leftRowH, nameStripe(1), self.teams[1].players[1].name,
  (self.teams[1].players[1].name == "Player 1") and PLACEHOLDER_COL or BLACK, nameFS)
  
  self:_cell(x[1], m.t1_row2, w(1,2), m.leftRowH, nameStripe(2), self.teams[1].players[2].name,
  (self.teams[1].players[2].name == "Player 2") and PLACEHOLDER_COL or BLACK, nameFS)
  
  self:_cell(x[1], m.t2_row1, w(1,2), m.leftRowH, nameStripe(1), self.teams[2].players[1].name,
  (self.teams[2].players[1].name == "Player 3") and PLACEHOLDER_COL or BLACK, nameFS)
  
  self:_cell(x[1], m.t2_row2, w(1,2), m.leftRowH, nameStripe(2), self.teams[2].players[2].name,
  (self.teams[2].players[2].name == "Player 4") and PLACEHOLDER_COL or BLACK, nameFS)
  
  -- chips row (same content, now positioned by spans)
  local function chipsRow(y)
    self:_cell(x[2], y, w(2,3), m.leftRowH, Theme.leftHeaderBg, "bid/took", Theme.textSecondary, chipFS)
    self:_cell(x[5], y, w(5,6), m.leftRowH, Theme.leftHeaderBg, "hearts",   Theme.textSecondary, chipFS)
    self:_cell(x[6], y, w(6,7), m.leftRowH, Theme.leftHeaderBg, "queen",    Theme.textSecondary, chipFS)
    self:_cell(x[7], y, w(7,8), m.leftRowH, Theme.leftHeaderBg, "moon",     Theme.textSecondary, chipFS)
  end
  chipsRow(m.t1_row1); chipsRow(m.t1_row2); chipsRow(m.t2_row1); chipsRow(m.t2_row2)
  
  -- interactive cells
  self.cells.t1_p1_bid:draw()   ; self.cells.t1_p1_took:draw()
  self.cells.t1_p2_bid:draw()   ; self.cells.t1_p2_took:draw()
  self.cells.t1_hearts:draw()   ; self.cells.t1_qs:draw() ; self.cells.t1_moon:draw()
  
  self.cells.t2_p1_bid:draw()   ; self.cells.t2_p1_took:draw()
  self.cells.t2_p2_bid:draw()   ; self.cells.t2_p2_took:draw()
  self.cells.t2_hearts:draw()   ; self.cells.t2_qs:draw() ; self.cells.t2_moon:draw()
  
  --------------------------------------------------------------------------
  -- RIGHT TABLE (mini headers + values), now using x edges directly
  --------------------------------------------------------------------------
  local labelsRight = {
    "SPADES","HEARTS","BAGS",
    "SPADES","HEARTS","BAGS",
    "GAME\nTOTAL"
  }
  local miniHeaderFont = m.rightRowH * 0.28
  local colBg = {
    Theme.rightSpadesScoreBg,
    Theme.rightHeartsScoreBg,
    Theme.rightHandScoreBg,
    Theme.rightAllBagsBg,
    Theme.rightSpadesTotalBg,
    Theme.rightHeartsTotalBg,
    Theme.rightGameTotalBg
  }
  
  local function drawMiniHeaderRow(y)
    for i=1,7 do
      local i0 = 8 + (i-1)
      local i1 = 8 + i
      self:_cell(x[i0], y, w(i0,i1), m.rightRowH, Theme.rightMiniHeaderBg, labelsRight[i], Theme.rightMiniHeaderTxt, miniHeaderFont)
    end
  end
  
  local function rightValsForTeam(ti)
    local team = self.teams[ti]
    
    local function fmtv(v) return (v == nil) and "--" or tostring(math.floor(v)) end
    
    -- “Hand” readiness is simply whether the ledger produced a hand value.
    local sReady = (team.spadesScore ~= nil)
    local hReady = (team.heartsScore ~= nil)
    
    -- “Totals” readiness is whatever the ledger decided (nil means “don’t show”)
    local spTotReady = (team.spadesTotal ~= nil) and sReady
    local hTotReady  = (team.heartsTotal ~= nil)
    local bagsReady  = (team.allBags     ~= nil) and sReady
    local grandReady = (team.gameTotal   ~= nil)
    
    return {
      -- HAND SCORES
      fmtv(team.spadesScore),
      fmtv(team.heartsScore),
      fmtv(team.handBags),
      
      -- TOTAL SCORES
      spTotReady and fmtv(team.spadesTotal) or "--",
      hTotReady  and fmtv(team.heartsTotal) or "--",
      bagsReady  and fmtv(team.allBags)     or "--",
      
      -- GRAND TOTAL
      grandReady and fmtv(team.gameTotal)   or "--",
    }
  end
  
  local numberFS = self.numberFontSize
  local function drawValuesRow(y, teamIndex)
    local vals = rightValsForTeam(teamIndex)
    for i=1,7 do
      local i0 = 8 + (i-1)
      local i1 = 8 + i
      self:_cell(x[i0], y, w(i0,i1), m.rightRowH, colBg[i], vals[i], Theme.rightNumberTxt, numberFS)
    end
  end
  
  drawMiniHeaderRow(m.t1_row1); drawValuesRow(m.t1_row2, 1)
  drawMiniHeaderRow(m.t2_row1); drawValuesRow(m.t2_row2, 2)
end

function ScoreTable:touched(t)
  local prev_t1_moon = self.cells.t1_moon.value
  local prev_t2_moon = self.cells.t2_moon.value
  
  local prev_t1_qs   = self.cells.t1_qs.value
  local prev_t2_qs   = self.cells.t2_qs.value
  
  local handled = false
  
  for _, c in pairs(self.cells) do
    if c and c.touched then
      if c:touched(t) then handled = true end
    end
  end
  for _, s in pairs(self.lp) do
    if s and s.touched then
      if s:touched(t) then handled = true end
    end
  end
  
  local t1_changed = (self.cells.t1_moon.value ~= prev_t1_moon)
  local t2_changed = (self.cells.t2_moon.value ~= prev_t2_moon)
  
  if t1_changed and self.cells.t1_moon.value == true then
    self.cells.t2_moon.value = false
  elseif t2_changed and self.cells.t2_moon.value == true then
    self.cells.t1_moon.value = false
  end
  
  local t1_qs_changed = (self.cells.t1_qs.value ~= prev_t1_qs)
  local t2_qs_changed = (self.cells.t2_qs.value ~= prev_t2_qs)
  
  if t1_qs_changed and self.cells.t1_qs.value == true then
    self.cells.t2_qs.value = false
  elseif t2_qs_changed and self.cells.t2_qs.value == true then
    self.cells.t1_qs.value = false
  end
  
  return handled
end


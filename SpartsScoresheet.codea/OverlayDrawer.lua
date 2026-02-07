-- ScoreSheets = class()

-- function ScoreSheets:init()
--   objc.log("inside OverlayDrawer: now!!!")
--   self._scrollTween = nil
--   self.makeTeams = makeTeams or self._defaultTeams
--   self.tables    = {}
--   self.scrollY   = 0
--   self._kbShiftY = 0
--   self._kbTween = nil
--   devLog("notchTracker")
--   self.notchTracker = newNotchTracker()
--   devLog("archiveExporter")
--   self.archiveExporter = ArchiveExporter()
--   devLog("archiveBrowser")
--   self.archiveBrowser = ArchiveBrowser()
--   self._archiveWasActive = false
--   self._archiveLoading = false
--   self._archiveLoadStage = nil  -- nil / 0 / 1
-- end

function ScoreSheets:_drawNonInteractiveOverlay(isOn, msg)
  if not isOn then return end
  
  pushStyle()
  rectMode(CORNER)
  fill(0, 0, 0, 65)
  fill(0, 137)
  rect(0, 0, WIDTH, HEIGHT)
  
  fill(255, 255, 255, 230)
  font("Chalkduster")
  fontSize(26)
  textAlign(CENTER)
  textMode(CENTER)
  
  local cx, cy = WIDTH/2, HEIGHT/2
  if msg and msg ~= "" then
    text(msg, cx, cy + 36)
  end
  
  -- tiny spinner
  local r = 18
  local t = ElapsedTime * 3.2
  stroke(255, 255, 255, 220)
  strokeWidth(4)
  noFill()
  lineCapMode(ROUND)
  local r = 18
  local t = ElapsedTime * 6
  stroke(255, 255, 255, 220)
  strokeWidth(4)
  lineCapMode(ROUND)
  for i = 0, 11 do
    local a = t + i * (math.pi * 2 / 12)
    local ax = cx + math.cos(a) * r
    local ay = cy - 8 + math.sin(a) * r
    local bx = cx + math.cos(a) * (r * 0.55)
    local by = cy - 8 + math.sin(a) * (r * 0.55)
    local alpha = 40 + (i / 11) * 180
    stroke(255, 255, 255, alpha)
    line(ax, ay, bx, by)
  end
  
  popStyle()
end

ArchiveBrowser = class()

function ArchiveBrowser:init()
  self._plaqueA = {}          -- base -> 0..1
  self.plaqueFadeIn  = 9      -- tweak speed
  self.plaqueFadeOut = 16     -- tweak speed
  self._labelsArmed = false   -- becomes true after the FIRST touch on the archives screen
  self._touchActive = false
  self._labelAlpha  = 1
  self._labelTarget = 1
  self._gestureAxis = "none"  -- "none" | "h" | "v"
  self._fadeOutFast = 18      -- higher = faster fade (vertical inspect)
  self._fadeOutSlow = 6       -- normal fade (touch ends)
  self._fadeInSpeed = 10
  self.summaryMode = "fixed"  -- "fixed" or "attached"
  self.summaryH = 96          -- vertical space reserved for the 4 lines
  self.metaCache = {}         -- base -> decoded json table (or false)
  self.active = false
  self.scale = 0.7      -- knob (2–2.5 visible)
  self.gap = 18
  self.page = 1          -- 1-based index into items
  self.x = 0             -- horizontal scroll position (pixels)
  self.vx = 0            -- horizontal velocity
  self.pageSY = {}   -- base -> scroll offset (0..maxSy)
  self.pageVY = {}   -- base -> velocity
  self.items = {}
  self.cache = {}        -- baseName -> image
  self.cacheOrder = {}
  self.maxCache = 5
  self._pendingDelete = nil
  
  self.closeBadge = {
    radius   = 10,   -- visual + hit radius
    insetX  = -5,   -- distance from image right edge
    insetY  = -5    -- distance from image top edge
  }
  
  self._drag = { mode="idle", sx=0, sy=0, x0=0, y0=0, t0=0, lastX=0, lastY=0, lastDT=0 }
end

function ArchiveBrowser:_getMetaForBase(base)
  if not base or base == "" then return nil end
  local cached = self.metaCache[base]
  if cached ~= nil then return (cached == false) and nil or cached end
  
  local s = readText(asset .. "SpartsArchives/" .. base .. ".json")
  if not s or s == "" then self.metaCache[base] = false; return nil end
  
  local ok, t = pcall(json.decode, s)
  if ok and type(t) == "table" then
    self.metaCache[base] = t
    return t
  end
  
  self.metaCache[base] = false
  return nil
end

local function _nm(x) return tostring(x or "") end

local function _parseCreatedToPretty(s)
  s = tostring(s or "")
  local Y,M,D,h,m,sec = s:match("^(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+):(%d+)")
  if not Y then return "—" end
  
  local t = os.time{
    year = tonumber(Y), month = tonumber(M), day = tonumber(D),
    hour = tonumber(h), min = tonumber(m), sec = tonumber(sec)
  }
  
  local out = os.date("%d %B %Y, %I:%M %p", t)  -- "06:30 PM"
  out = out:gsub("^0", "")                         -- "6:30 PM"
  out = out:gsub(" AM$", " am"):gsub(" PM$", " pm")
  return out
end

function ArchiveBrowser:_summaryForBase(base)
  local dump = self:_getMetaForBase(base)
  if not dump then
    return {
      date  = "—",
      t1    = "—/—",
      t2    = "—/—",
      scores= "Final Scores: — to —"
    }
  end
  
  local createdRaw = _nm(dump.meta and dump.meta.created)
  local created = _parseCreatedToPretty(createdRaw)
  
  local hands = tonumber((dump.meta and dump.meta.hands) or (dump.inputs and #dump.inputs)) or 0
  
  local t1p1,t1p2,t2p1,t2p2 = "—","—","—","—"
  local h1 = dump.inputs and dump.inputs[1]
  if h1 and h1.teams and h1.teams[1] and h1.teams[2] then
    local a = h1.teams[1].players or {}
    local b = h1.teams[2].players or {}
    t1p1, t1p2 = _nm(a[1] and a[1].name), _nm(a[2] and a[2].name)
    t2p1, t2p2 = _nm(b[1] and b[1].name), _nm(b[2] and b[2].name)
  end
  
  local s1, s2 = "—", "—"
  local last = dump.computed and dump.computed[hands]
  if last and last.teams and last.teams[1] and last.teams[2] then
    s1 = tostring(last.teams[1].gameTotal or "—")
    s2 = tostring(last.teams[2].gameTotal or "—")
  end
  
  return {
    date  = created,
    t1    = t1p1 .. "/" .. t1p2,
    t2    = t2p1 .. "/" .. t2p2,
    scores= "Final Scores: " .. s1 .. " to " .. s2
  }
end

function ArchiveBrowser:_curBase()
  local it = self.items[self.page]
  return it and it.base or nil
end

function ArchiveBrowser:_getSummaryBG(w, h, r, a)
  self._bgCache = self._bgCache or {}
  local key = tostring(w).."x"..tostring(h).."r"..tostring(r).."a"..tostring(a)
  local img = self._bgCache[key]
  if img then return img end
  
  -- pass 1: build the rounded-rect SHAPE using your drawRoundedRect (opaque)
  local mask = image(w, h)
  setContext(mask)
  pushStyle()
  background(0,0,0,0)
  
  -- drawRoundedRect uses CENTER coords
  drawRoundedRect(
  w * 0.5, h * 0.5,
  w, h,
  r or 14,
  color(75),  -- opaque fill
  color(75)   -- opaque fill
  )
  
  popStyle()
  setContext()
  
  -- pass 2: bake the transparency by drawing the mask with tint alpha
  img = image(w, h)
  setContext(img)
  pushStyle()
  background(0,0,0,0)
  spriteMode(CORNER)
  tint(0, 235)
  sprite(mask, 0, 0, w, h)
  noTint()
  popStyle()
  setContext()
  
  self._bgCache[key] = img
  return img
end

function ArchiveBrowser:_getSY(i)
  return (i and self.pageSY[i]) or 0
end

function ArchiveBrowser:_setSY(i, v)
  if not i then return end
  self.pageSY[i] = v
end

function ArchiveBrowser:_getVY(i)
  return (i and self.pageVY[i]) or 0
end

function ArchiveBrowser:_setVY(i, v)
  if not i then return end
  self.pageVY[i] = v
end

function ArchiveBrowser:loadIndex()
  local indexPath = asset .. "SpartsArchives/index.json"
  local s = readText(indexPath)
  if not s or s == "" then
    self.items = {}
    return
  end
  
  local ok, t = pcall(json.decode, s)
  if not (ok and type(t) == "table" and type(t.items) == "table") then
    self.items = {}
    return
  end
  
  local cleaned = {}
  local changed = false
  
  for _, it in ipairs(t.items) do
    local base = it and it.base
    if base and base ~= "" then
      local pngOk  = pcall(readImage, asset .. "SpartsArchives/" .. base .. ".png")
      local jsonOk = readText(asset .. "SpartsArchives/" .. base .. ".json")
      
      if pngOk and jsonOk and jsonOk ~= "" then
        table.insert(cleaned, it)
      else
        changed = true
      end
    else
      changed = true
    end
  end
  
  self.items = cleaned
  
  -- If we dropped anything, rewrite index.json so it stays clean
  if changed then
    pcall(function()
      saveText(indexPath, json.encode({ items = cleaned }))
    end)
  end
end

function ArchiveBrowser:_cachePut(key, img)
  if self.cache[key] then return end
  self.cache[key] = img
  table.insert(self.cacheOrder, key)
  
  while #self.cacheOrder > self.maxCache do
    local k = table.remove(self.cacheOrder, 1)
    self.cache[k] = nil
  end
end

function ArchiveBrowser:_getImageForBase(base)
  if not base or base == "" then return nil end
  local img = self.cache[base]
  if img then return img end
  
  local a = asset .. "SpartsArchives/" .. base .. ".png"
  local ok, res = pcall(readImage, a)
  if ok and res then
    self:_cachePut(base, res)
    return res
  end
  return nil
end

function ArchiveBrowser:open()
  self._labelsArmed = false
  self._touchActive = false
  self._labelAlpha  = 1
  self._labelTarget = 1
  self._gestureAxis = "none"
  self:loadIndex()
  self.active = true
  self.page = 1
  self.x = 0
  self.vx = 0
end

function ArchiveBrowser:_maxSY(i)
  local it = i and self.items[i]
  local base = it and it.base
  local img = base and self:_getImageForBase(base)
  if not img then return 0 end
  
  local drawW = WIDTH * self.scale
  local drawH = (img.height / img.width) * drawW
  local viewH = HEIGHT * 0.84
  return math.max(0, drawH - viewH)
end

function ArchiveBrowser:close()
  self.active = false
end

function ArchiveBrowser:_pageStride()
  return (WIDTH * self.scale) + self.gap
end

function ArchiveBrowser:_visibleRange()
  local first = math.max(1, self.page - 2)
  local last  = math.min(#self.items, self.page + 2)
  return first, last
end

function ArchiveBrowser:_hitTestIndexAt(x, y)
  local stride = self:_pageStride()
  local cx = WIDTH/2
  local topY = HEIGHT - 90 -- NOTE: if your draw uses a different topY, make them match
  
  local first, last = self:_visibleRange()
  for i = first, last do
    local it = self.items[i]
    local base = it and it.base
    local img = base and self:_getImageForBase(base)
    if img then
      local drawW = WIDTH * self.scale
      local drawH = (img.height / img.width) * drawW
      
      local px = cx + (i-1)*stride - self.x
      local left = px - drawW/2
      local right = left + drawW
      local top = topY
      local bottom = topY - drawH
      
      if x >= left and x <= right and y >= bottom and y <= top then
        return i
      end
    end
  end
  return nil
end

function ArchiveBrowser:update(dt)
  if not self.active then return end
  dt = dt or DeltaTime or 0
  if self._pendingDelete then
    local pd = self._pendingDelete
    self._pendingDelete = nil
    
    local i    = pd.index
    local base = pd.base
    
    -- update in-memory state
    table.remove(self.items, i)
    self.page = math.max(1, math.min(self.page, #self.items))
    
    self.cache[base] = nil
    self.metaCache[base] = nil
    self.pageSY[i] = nil
    self.pageVY[i] = nil
    
    -- SAFE place to mutate assets
    pcall(function()
      saveText(asset .. "SpartsArchives/" .. base .. ".json", "")
      saveImage(asset .. "SpartsArchives/" .. base .. ".png", image(1,1))
    end)
    pcall(function()
      local indexPath = asset .. "SpartsArchives/index.json"
      local out = {
        items = self.items
      }
      saveText(indexPath, json.encode(out))
    end)
    
    return
  end
  
  if self._drag.mode == "idle" then
    -- simple inertial decay
    self.x = self.x + self.vx * dt
    
    local decay = 0.04 ^ dt
    self.vx = self.vx * decay
    
    -- apply vertical inertia to any base that has vy (visible window only)
    local first, last = self:_visibleRange()
    for i = first, last do
      local it = self.items[i]
      local base = it and it.base
      if base then
        local vy = self:_getVY(i)
        if math.abs(vy) > 0.001 then
          local sy = self:_getSY(i) + vy * dt
          vy = vy * decay
          
          local maxSy = self:_maxSY(i)
          sy = clamp(sy, 0, maxSy)
          
          self:_setSY(i, sy)
          self:_setVY(i, vy)
        else
          self:_setVY(i, 0)
        end
      end
    end
  end
  
  do
    local first, last = self:_visibleRange()
    for i = first, last do
      local it = self.items[i]
      local base = it and it.base
      if base then
        local maxSy = self:_maxSY(i)
        local sy = clamp(self:_getSY(i), 0, maxSy)
        self:_setSY(i, sy)
      end
    end
  end
  
  -- clamp horizontal bounds
  local stride = self:_pageStride()
  local maxX = math.max(0, (#self.items - 1) * stride)
  self.x = clamp(self.x, 0, maxX)
  
  -- preload neighbors
  local function preload(i)
    local it = self.items[i]
    if it and it.base then self:_getImageForBase(it.base) end
  end
  preload(self.page)
  preload(self.page - 1)
  preload(self.page + 1)
  -- plaque fade per-base:
  do
    self._plaqueA = self._plaqueA or {}
    
    local draggingIndex = nil
    if self._drag and self._drag.mode == "drag" and self._gestureAxis == "v" then
      draggingIndex = self._drag.i
    end
    
    local first, last = self:_visibleRange()
    for i = first, last do
      local it = self.items[i]
      local base = it and it.base
      if base then
        local sy = self:_getSY(i) or 0
        
        -- target: hide if dragging vertically on this item OR it is left scrolled
        local target = ((i == draggingIndex) or (sy > 0.5)) and 0 or 1
        
        local a = self._plaqueA[i]
        if a == nil then a = 1 end
        
        local speed = (target > a) and (self.plaqueFadeIn or 9) or (self.plaqueFadeOut or 16)
        local k = math.min(1, (dt or 0) * speed)
        a = a + (target - a) * k
        
        self._plaqueA[i] = a
      end
    end
  end
end

function ArchiveBrowser:draw()
  if not self.active then return end
  
  self:update(DeltaTime)
  self.summaryH = 0
  
  background(0,0,0,210)
  
  local stride = self:_pageStride()
  local cx = WIDTH/2
  
  -- tops align a bit lower to make room for summaries
  local topY = HEIGHT - 18 - (self.summaryH or 0)
  self._lastTopY = topY
  
  local first = math.max(1, self.page - 2)
  local last  = math.min(#self.items, self.page + 2)
  
  for i = first, last do
    local it = self.items[i]
    local base = it.base
    local img = self:_getImageForBase(base)
    if img then
      local drawW = WIDTH * self.scale
      local drawH = (img.height / img.width) * drawW
      
      local px = cx + (i-1)*stride - self.x
      
      -- draw archive image (top-aligned)
      pushMatrix()
      translate(px - drawW/2, topY - drawH)
      spriteMode(CORNER)
      
      pushStyle()
      fill(178)
      
      
      local yOff = self:_getSY(i)
      
      sprite(img, 0, yOff, drawW, drawH)
      popMatrix()
      popStyle()

      -- the delete badge (top-right of image, fades like plaque)
      do
        local aa = (self._plaqueA and self._plaqueA[i]) or 1
        if aa > 0 then
          local cxB, cyB, rB = self:_closeBadgeCenter(px, drawW, topY)
          self:drawXAt(cxB, cyB, rB, aa)
        end
      end
      
      -- summary box + text (fadeable)
      do
        local sum = self:_summaryForBase(base)
        
        -- preserve your choices
        local size   = 18
        local lineDY = math.floor(size * 1.62 + 0.5)
        local padX   = 18
        local padY   = 14
        
        local linesN = 4
        
        pushStyle()
        font("Helvetica")
        fontSize(size)
        textMode(CORNER)
        textAlign(LEFT)
        
        local label = "Teams: "
        local labelW = textSize(label)
        
        -- measure widths (box can be narrower than image)
        local w1 = textSize(sum.date or "")
        local w3 = labelW + textSize(sum.t1 or "")
        local w4 = labelW + textSize(sum.t2 or "")
        local w6 = textSize(sum.scores or "")
        
        local maxW = math.max(w1, w3, w4, w6)
        
        local boxW = math.min(drawW, math.floor(maxW + padX * 2 + 0.5))
        local boxH = math.floor(padY * 2 + (lineDY * (linesN - 1)) + size + 0.5)
        
        -- anchor the box near the top, aligned with this card
        local topMargin = 14
        local boxGapToImage = 10
        
        local x0 = math.floor((px - drawW/2) + 20 + 0.5)     -- your inset
        local yTop = HEIGHT - topMargin
        -- near bottom of screen (tweak these)
        local bottomPad = 18   -- distance above bottom edge
        local y0 = bottomPad   -- because spriteMode(CORNER): y0 is the box's bottom-left
        
        -- tell the image layout how much header space it needs
        self.summaryH = math.max(self.summaryH or 0, (boxH + boxGapToImage + topMargin))
        
        local aa = (self._plaqueA and self._plaqueA[i]) or 1
        local a = math.floor(255 * aa + 0.5)
        if a > 0 then
          local bg = self:_getSummaryBG(boxW, boxH, 14, 120)
          
          spriteMode(CORNER)
          tint(255,255,255,a)
          sprite(bg, x0, y0, boxW, boxH)
          noTint()
          
          fill(255, a) -- fade text too
          
          local tx = x0 + padX
          local ty = y0 + boxH - padY - size
          
          text(sum.date or "", tx, ty); ty = ty - lineDY
          text("Teams:", tx, ty)
          text(sum.t1 or "", tx + labelW, ty); ty = ty - lineDY
          text(" ", tx, ty) -- keeps row height consistent
          text(sum.t2 or "", tx + labelW, ty); ty = ty - lineDY
          text(sum.scores or "", tx, ty)
        end
        
        popStyle()
      end
    end
  end
  
  -- close button (top-left) — no top bar now
  pushStyle()
  fill(255,255,255,240)
  fontSize(34)
  textAlign(LEFT)
  textMode(CENTER)
  text("✕", 18, HEIGHT-28)
  popStyle()
end

function ArchiveBrowser:touched(t)
  if not self.active then return false end
  
  if t.state == BEGAN then
    local i = self:_hitDeleteAt(t.x, t.y)
    if i then
      print("archive delete button hit")
      local base = self.items[i].base
      
      local UIAlertController = objc.UIAlertController
      local UIAlertAction = objc.UIAlertAction
      
      local alert = UIAlertController:alertControllerWithTitle_message_preferredStyle_(
      "Delete Archive?",
      "This cannot be undone.",
      objc.enum.UIAlertControllerStyle.alert
      )
      
      local cancel = UIAlertAction:actionWithTitle_style_handler_(
      "Cancel",
      objc.enum.UIAlertActionStyle.cancel,
      nil
      )
      
      local confirm = UIAlertAction:actionWithTitle_style_handler_(
      "Delete",
      objc.enum.UIAlertActionStyle.destructive,
      function()
        self._pendingDelete = {
          index = i,
          base  = base
        }
      end
      )
      
      alert:addAction_(confirm)
      alert:addAction_(cancel)
      
      objc.viewer:presentViewController_animated_completion_(alert, true, nil)
      return true
    end
  end
  
  -- close tap area (top-left)
  if t.state == BEGAN then
    if t.x < 72 and t.y > HEIGHT-64 then
      self:close()
      return true
    end
  end
  
  local d = self._drag
  
  if t.state == BEGAN then
    self._touchActive = true
    
    -- on open: labels stay visible until the first touch happens
    if not self._labelsArmed then
      self._labelsArmed = true
    end
    
    self._gestureAxis = "none"
    self._labelTarget = 1  -- show labels while touch begins / holding
    
    d.mode = "drag"
    d.sx, d.sy = t.x, t.y
    d.x0 = self.x
    
    -- NOTE: still using current-page base for scroll state here (you already have per-base storage)
    d.i = self:_hitTestIndexAt(t.x, t.y) or self.page
    d.y0 = self:_getSY(d.i)
    
    
    d.lastX, d.lastY = t.x, t.y
    self.vx = 0
    self:_setVY(d.i, 0)
    return true
    
  elseif t.state == MOVING and d.mode == "drag" then
    local dx = t.x - d.sx
    local dy = t.y - d.sy
    
    -- decide gesture axis once (with a small threshold so it doesn't flicker)
    if self._gestureAxis == "none" then
      local ax, ay = math.abs(dx), math.abs(dy)
      if ax > 10 or ay > 10 then
        if ax > ay * 1.2 then
          self._gestureAxis = "h"
        elseif ay > ax * 1.2 then
          self._gestureAxis = "v"
        end
      end
    end
    
    -- label visibility rule after first touch:
    -- - horizontal swipe / hold => visible
    -- - vertical swipe => fade fast
    if self._gestureAxis == "v" then
      self._labelTarget = 0
    else
      self._labelTarget = 1
    end
    
    if math.abs(dx) > math.abs(dy) * 1.2 then
      self.x = d.x0 - dx
    else
      local i = d.i or self.page
      local maxSy = self:_maxSY(i)
      self:_setSY(i, clamp(d.y0 + dy, 0, maxSy))
    end
    
    local dt = math.max(0.001, (DeltaTime or 1/60))
    self.vx = (d.lastX - t.x) / dt
    
    local i = d.i or self.page
    self:_setVY(i, (t.y - d.lastY) / dt)
    
    d.lastX, d.lastY = t.x, t.y
    return true
    
  elseif (t.state == ENDED or t.state == CANCELLED) and d.mode == "drag" then
    d.mode = "idle"
    self._touchActive = false
    
    -- after touch ends, labels fade out (unless you want them to persist; this matches your rule)
    self._labelTarget = 0
    self._gestureAxis = "none"
    
    -- keep "page" only for preload/windowing; DO NOT snap x
    local stride = self:_pageStride()
    local targetPage = math.floor((self.x / stride) + 0.5) + 1
    self.page = clamp(targetPage, 1, #self.items)
    
    d.i = nil
    
    return true
  end
  
  return true
end

function ArchiveBrowser:_closeBadgeCenter(px, drawW, topY)
  local cfg = self.closeBadge
  local cx = (px + drawW/2) - cfg.insetX - cfg.radius
  local cy = topY - cfg.insetY - cfg.radius
  return cx, cy, cfg.radius
end

function ArchiveBrowser:drawXAt(cx, cy, r, alpha)
  if not alpha or alpha <= 0 then return end
  
  local a = math.floor(255 * alpha + 0.5)
  
  pushStyle()
  noStroke()
  fill(200, 40, 40, a)
  ellipse(cx, cy, r * 2)
  
  fill(255, a)
  fontSize(r * 1.4)
  textAlign(CENTER)
  textMode(CENTER)
  text("✕", cx, cy)
  popStyle()
end

function ArchiveBrowser:_hitDeleteAt(x, y)
  local stride = self:_pageStride()
  local cx = WIDTH/2
  local topY = self._lastTopY or (HEIGHT - 18)
  
  local first, last = self:_visibleRange()
  for i = first, last do
    local it = self.items[i]
    local base = it and it.base
    local img = base and self:_getImageForBase(base)
    if img then
      local drawW = WIDTH * self.scale
      local px = cx + (i-1)*stride - self.x
      
      local cxB, cyB, rB = self:_closeBadgeCenter(px, drawW, topY)
      
      local dx = x - cxB
      local dy = y - cyB
      if (dx*dx + dy*dy) <= (rB * rB) then
        return i
      end
    end
  end
  return nil
end
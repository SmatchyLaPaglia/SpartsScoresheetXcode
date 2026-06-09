-- CheckboxCell.lua
-- Simple tappable checkbox with press highlight + touch ownership

CheckboxCell = class()

-- one-owner-per-touch (avoid cross-highlighting while swiping)
CheckboxCell._owners = {}

function CheckboxCell:init(x, y, w, h, initialValue)
  self.x, self.y, self.w, self.h = x, y, w, h
  self.value = (initialValue == true)  -- boolean
  self.isPressed = false
  
  self.colStroke    = self.colStroke    or Theme.gridLine
  self.colBg        = self.colBg        or Theme.cellBg
  self.colBgPressed = self.colBgPressed or Theme.cellBgPressed
  self.colTick      = self.colTick      or Theme.checkboxTick
  
  self.sensorPress = Sensor{ parent = self }
  self.sensorTap   = Sensor{ parent = self }
  
  -- live press highlight while a finger is inside
  self.sensorPress:onTouch(function(event)
    self.isPressed = event.state and true or false
  end)
  
  -- tap toggles
  self.sensorTap:onTap(function()
    self.value = not self.value
    
    return
  end)
end

-- cell-local point-in-rect
function CheckboxCell:inbox(t)
  return (t.x >= self.x and t.x <= self.x + self.w
  and t.y >= self.y and t.y <= self.y + self.h)
end

-- ownership: claim on BEGAN inside; keep until ENDED/CANCELLED
function CheckboxCell:_ownsTouch(t)
  local owners = CheckboxCell._owners
  local current = owners[t.id]
  if current then return current == self end
  if t.state == BEGAN and self:inbox(t) then
    owners[t.id] = self
    return true
  end
  return false
end

function CheckboxCell:draw()
  pushStyle()
  rectMode(CORNER)
  
  -- background + border (themed; thicker while pressed)
  local bg = self.isPressed and self.colBgPressed or self.colBg
  fill(bg)
  stroke(self.colStroke)
  strokeWidth(self.isPressed and 2 or 1)
  rect(self.x, self.y, self.w, self.h)
  
  -- inner square
  local box = math.min(self.w, self.h) * 0.55
  local bx  = self.x + (self.w - box)/2
  local by  = self.y + (self.h - box)/2
  noFill()
  stroke(self.colStroke)
  strokeWidth(1)
  rect(bx, by, box, box)
  
  -- tick (draw last so it isn't covered)
  if self.value then
    stroke(self.colTick)
    strokeWidth(math.max(2, box*0.12))
    local x1,y1 = bx + box*0.20, by + box*0.55
    local x2,y2 = bx + box*0.42, by + box*0.30
    local x3,y3 = bx + box*0.80, by + box*0.75
    line(x1,y1,x2,y2)
    line(x2,y2,x3,y3)
  end
  
  popStyle()
end

function CheckboxCell:touched(t)
  if not self:_ownsTouch(t) then return false end
  self.sensorPress:touched(t)
  self.sensorTap:touched(t)
  if t.state == ENDED or t.state == CANCELLED then
    if CheckboxCell._owners[t.id] == self then
      CheckboxCell._owners[t.id] = nil
    end
  end
  return true
end
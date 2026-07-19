-- IncrementingCell.lua
IncrementingCell = class()
IncrementingCell._owners = {}

function IncrementingCell:init(x, y, w, h, initialValue)
  self.x, self.y, self.w, self.h = x, y, w, h
  self.value  = initialValue
  self.hasSet = (initialValue ~= nil)

  self.pulse = 0
  self.pulseTween = nil

  -- themeable colors (fallbacks keep existing look)
  self.colBg         = self.colBg         or Theme.cellBg
  self.colBgPressed  = self.colBgPressed  or Theme.cellBgPressed
  self.colStroke     = self.colStroke     or Theme.gridLine
  self.colText       = self.colText       or Theme.textAccentBlue
  self.colTextUnset  = self.colTextUnset  or Theme.textDisabled

  self.min, self.max = 0, 13
  self.wrap = true

  -- pixels per increment while dragging (tune to taste)
  self.stepPx      = 22
  self.dragLastX   = nil   -- last x we sampled
  self.dragAccum   = 0     -- accumulated pixels since last step

  self.isPressed = false
  self.disabled = false

  self.sensor = Sensor{ parent = self }

  -- visual press state (like the old sensorPress:onTouch)
  self.sensor:onTouch(function(ev)
    local down = ev.state and true or false
    self.isPressed = down

    if down then
      -- hold the pop label fully on while finger is down
      self.pulse = 1
      if self.pulseTween then tween.stop(self.pulseTween); self.pulseTween = nil end
    else
      -- ease out a bit slower on release
      if self.pulseTween then tween.stop(self.pulseTween) end
      self.pulseTween = tween(0.32, self, { pulse = 0 }, tween.easing.cubicOut, function()
        self.pulseTween = nil
      end)
    end
  end)

  self.sensor:onDrag(function(event)
    if self._pulseTween then tween.stop(self._pulseTween); self._pulseTween = nil end
    self.pulse = 1
    local t = event.touch
    if t.state == BEGAN then
      self.dragLastX = t.x
      self.dragAccum = 0
      return
    end

    if (t.state == MOVING or t.state == ENDED) and self.dragLastX then
      -- accumulate horizontal motion
      local dx = t.x - self.dragLastX
      self.dragLastX = t.x
      self.dragAccum = self.dragAccum + dx

      -- how many full steps worth of motion have we accumulated?
      local steps = 0
      if self.dragAccum >=  self.stepPx then
        steps = math.floor(self.dragAccum / self.stepPx)
      elseif self.dragAccum <= -self.stepPx then
        steps = math.ceil(self.dragAccum / self.stepPx) -- negative
      end

      if steps ~= 0 then
        -- step once per unit so boundary logic ("--" between min/max) still applies
        local dir = (steps > 0) and 1 or -1
        for _ = 1, math.abs(steps) do
          self:_step(dir, "drag")
        end
        -- keep only the remainder so small back-and-forth feels smooth
        self.dragAccum = self.dragAccum - steps * self.stepPx
      end

      if t.state == ENDED or t.state == CANCELLED then
        self.dragLastX = nil
        self.dragAccum = 0
        if self._pulseTween then tween.stop(self._pulseTween); self._pulseTween = nil end
        self._pulseTween = tween(0.35, self, { pulse = 0 }, nil, function()
          self._pulseTween = nil
        end)
      end
    end
  end)

  self.sensor:onTap(function()
    self:_step(1, "tap")
  end)

end

-- Mutes toward gray at FULL alpha (never toward transparent) so a disabled
-- cell's background stays fully opaque and can't let whatever is drawn
-- underneath (e.g. the static chip labels) show through.
local function mutedOpaque(c)
  local gray, mix = 130, 0.55
  return color(
    c.r + (gray - c.r) * mix,
    c.g + (gray - c.g) * mix,
    c.b + (gray - c.b) * mix,
    c.a
  )
end

function IncrementingCell:draw()
  pushStyle()
  rectMode(CORNER)

  local strokeCol = self.colStroke
  if self.disabled then
    strokeCol = mutedOpaque(strokeCol)
  end

  if self.isPressed then
    local bgCol = self.colBgPressed
    if self.disabled then bgCol = mutedOpaque(bgCol) end
    fill(bgCol) ; stroke(strokeCol) ; strokeWidth(2)
  else
    local bgCol = self.colBg
    if self.disabled then bgCol = mutedOpaque(bgCol) end
    fill(bgCol) ; stroke(strokeCol) ; strokeWidth(1)
  end
  rect(self.x, self.y, self.w, self.h)

  local f = self.fontSize or (self.h * 0.5)
  font("HelveticaNeue-Bold")
  fontSize(f)
  textAlign(CENTER)

  local label, col
  if self.hasSet then
    label = tostring(math.floor(self.value))
    col   = self.colText
  else
    label = "--"
    col   = self.colTextUnset
  end

  -- pop-up feedback: float upward + enlarge briefly so it's visible above the finger
  -- (popY only floats upward for tap — drag stays inside the cell)
  if (self.pulse or 0) > 0 then
    local p = self.pulse
    local popFS = f + (self.h * 0.7) * p
    local popY  = 0
    if self._stepSource == "tap" then
      popY = (self.h * 0.5 + (f + self.h * 0.7) * 0.3) * p
    end

    fontSize(popFS)
    -- pop color: lerp from base (blue) -> red as p goes to 1
    local base = self.colText
    local red  = color(240, 71, 51)

    local r = base.r + (red.r - base.r) * p
    local g = base.g + (red.g - base.g) * p
    local b = base.b + (red.b - base.b) * p
    local a = base.a + (red.a - base.a) * p

    if self.disabled then a = a * 0.45 end

    fill(color(r, g, b, a))
    text(label, self.x + self.w/2, self.y + self.h/2 + popY)
  else
    -- normal label (already there)
    local textCol = col
    if self.disabled then textCol = color(col.r, col.g, col.b, col.a * 0.45) end
    fill(textCol)
    text(label, self.x + self.w/2, self.y + self.h/2)
  end

  popStyle()
end

function IncrementingCell:set(v)
  if self.wrap then
    local span = self.max - self.min + 1
    v = ((v - self.min) % span + span) % span + self.min
  else
    v = math.max(self.min, math.min(self.max, v))
  end
  self.value  = v
  self.hasSet = true   -- <-- mark as entered whenever we programmatically set

end

function IncrementingCell:unset()
  self.value  = 0
  self.hasSet = false

end

function IncrementingCell:inbox(t)
  return t.x >= self.x and t.x <= self.x + self.w
  and t.y >= self.y and t.y <= self.y + self.h
end

-- check/assign ownership for this touch id
function IncrementingCell:_ownsTouch(t)
  local owners = IncrementingCell._owners
  local current = owners[t.id]
  if current then return current == self end
  if t.state == BEGAN and self:inbox(t) then
    owners[t.id] = self
    return true
  end
  return false
end

-- step by +1 or -1, with "--" between max and min
-- source: "tap" or "drag" — controls pop-up animation behavior
function IncrementingCell:_step(delta, source)
  self._stepSource = source or "tap"  -- store for draw() pop-up behavior
  -- if we're unset, first step chooses an endpoint in the step direction
  if not self.hasSet then
    if delta > 0 then self:set(self.min) else self:set(self.max) end
    return
  end
  local v = self.value + delta
  if v > self.max or v < self.min then
    -- crossing a boundary goes to unset
    self:unset()

    return
  else
    self:set(v)

    return
  end
end

function IncrementingCell:touched(t)
  if self.disabled then return false end
  if not self:_ownsTouch(t) then
    return false
  end

  local handled = self.sensor:touched(t)

  if t.state == ENDED or t.state == CANCELLED then
    local owners = IncrementingCell._owners
    if owners[t.id] == self then owners[t.id] = nil end
  end

  return handled
end
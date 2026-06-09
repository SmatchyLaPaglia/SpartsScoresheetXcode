function newNotchTracker(opts)
opts = opts or {}

local t = {
  Z_START   = opts.Z_START   or 2.2,
  Z_STOP    = opts.Z_STOP    or 0.7,
  ACCUM_MIN = opts.ACCUM_MIN or 0.85,
  SETTLE_S  = opts.SETTLE_S  or 0.18,
  
  lastOrient = nil,
  inferredLandscape = nil, -- "LEFT" or "RIGHT" (matches LANDSCAPE_* constants)
  rotating = false,
  rotAccum = 0,
  lowSince = nil,
  
  notchOnLeft = false,
  notchOnRight = false,
  
  lastZ = 0,
}

local function isLandscape(o)
return o == LANDSCAPE_LEFT or o == LANDSCAPE_RIGHT
end

function t:resetFromCurrentOrientation()
self.lastOrient = CurrentOrientation
self.rotating = false
self.rotAccum = 0
self.lowSince = nil

if CurrentOrientation == LANDSCAPE_LEFT then
self.inferredLandscape = "LEFT"
elseif CurrentOrientation == LANDSCAPE_RIGHT then
self.inferredLandscape = "RIGHT"
else
self.inferredLandscape = nil
end
end

function t:update(dt)
local o  = CurrentOrientation
local rr = RotationRate

if o ~= self.lastOrient then
self.lastOrient = o
self.rotating = false
self.rotAccum = 0
self.lowSince = nil

if o == LANDSCAPE_LEFT then
self.inferredLandscape = "LEFT"
elseif o == LANDSCAPE_RIGHT then
self.inferredLandscape = "RIGHT"
else
self.inferredLandscape = nil
end
end

local z = (rr and rr.z) or 0
self.lastZ = z
local absZ = math.abs(z)

if (not self.rotating) and absZ >= self.Z_START then
self.rotating = true
self.rotAccum = 0
self.lowSince = nil
end

if self.rotating then
self.rotAccum = self.rotAccum + z * (dt or 0)

if absZ <= self.Z_STOP then
if not self.lowSince then self.lowSince = ElapsedTime end

if (ElapsedTime - self.lowSince) >= self.SETTLE_S then
if isLandscape(o) and (o == self.lastOrient) and (math.abs(self.rotAccum) >= self.ACCUM_MIN) then
if self.inferredLandscape == "LEFT" then
self.inferredLandscape = "RIGHT"
elseif self.inferredLandscape == "RIGHT" then
self.inferredLandscape = "LEFT"
else
self.inferredLandscape = (o == LANDSCAPE_LEFT) and "LEFT" or "RIGHT"
end
end

self.rotating = false
self.rotAccum = 0
self.lowSince = nil
end
else
self.lowSince = nil
end
end

-- YOUR rule:
-- LANDSCAPE_RIGHT => notch on LEFT, and vice versa.
self.notchOnLeft  = (self.inferredLandscape == "RIGHT")
self.notchOnRight = (self.inferredLandscape == "LEFT")

return self.notchOnLeft, self.notchOnRight
end

function t:computePads(basePad, notchPad, insetPad)
basePad  = basePad  or 0
notchPad = notchPad or 0
insetPad = insetPad or 0

local leftPad  = basePad
local rightPad = basePad

if self.notchOnLeft then
leftPad  = leftPad  + notchPad + insetPad
rightPad = rightPad + insetPad
elseif self.notchOnRight then
rightPad = rightPad + notchPad + insetPad
leftPad  = leftPad  + insetPad
else
leftPad  = leftPad  + insetPad
rightPad = rightPad + insetPad
end

return leftPad, rightPad
end

t:resetFromCurrentOrientation()
return t
end
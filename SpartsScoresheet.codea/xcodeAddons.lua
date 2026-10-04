--[[
  xcodeAddons.lua

  Lua-side half of a demo/reference implementation of Codea's "addon"
  mechanism -- the CodeaAddon protocol that lets your project's exported
  Xcode target register native Swift/Objective-C functions into Lua, and
  call back into Lua from native code.

  The native half lives in SpartsScoresheet/Addon/Module/PingPongModule.*
  and TouchBridgeModule.*. This file only talks to functions those two
  modules register; it does not import or require anything native itself
  -- from Lua's point of view, xcodePing(), xcodeSetDemoZone(),
  xcodeTapNativeButton() and xcodeDragNativeButton() are just ordinary
  global functions that happen to be implemented in Objective-C++.

  Two demos:

  1. Ping-pong: xcodePing(n) / luaPong(n) bounce an integer back and forth
     between Lua and native a few times, to show a call crossing the
     boundary in both directions.

  2. Touch bridge: a small on-screen zone that can trigger a synthetic tap
     in native UIKit (Lua -> native), and can itself be driven by a
     synthetic tap/drag injected by native code (native -> Lua).
]]

------------------------------------------------------------
-- 1. Ping-pong
------------------------------------------------------------

-- Called by native (PingPongModule) once, shortly after setup() finishes,
-- to demonstrate a round trip that *starts* on the native side.
function xcodeStartPingPong()
  devLog("[addons] native started the ping-pong")
  xcodePing(1)
end

-- Called by native (PingPongModule.mm's lua_xcodePing) each time the value
-- bounces back to Lua. Bounces it straight back so you can see the call
-- cross the boundary several times in the console (native caps the count).
function luaPong(n)
  devLog("[addons] luaPong received", n, "from Xcode")
  xcodePing(n + 1)
end

------------------------------------------------------------
-- 2. Touch bridge demo zone
------------------------------------------------------------

AddonDemo = {
  zone = { x = 20, y = 20, w = 220, h = 110 },
  label = "Addon demo zone",
  flashUntil = 0,
  dragTouchId = nil,
  dragLast = nil,
}

function AddonDemo.init()
  -- Tell native code where this zone lives in Codea's coordinate space, so
  -- the "Tap -> Lua" / "Drag -> Lua" native buttons know where to aim their
  -- synthetic touches.
  if xcodeSetDemoZone then
    local z = AddonDemo.zone
    xcodeSetDemoZone(z.x, z.y, z.w, z.h)
  end
end

function AddonDemo.draw()
  local z = AddonDemo.zone
  pushStyle()
  rectMode(CORNER)

  if ElapsedTime < AddonDemo.flashUntil then
    fill(90, 200, 255, 220)
  else
    fill(60, 60, 70, 200)
  end
  stroke(255)
  strokeWidth(2)
  rect(z.x, z.y, z.w, z.h)

  fill(255)
  font("HelveticaNeue")
  fontSize(14)
  textAlign(CENTER)
  text(AddonDemo.label, z.x + z.w / 2, z.y + z.h / 2)
  popStyle()
end

function AddonDemo:containsPoint(x, y)
  local z = self.zone
  return x >= z.x and x <= z.x + z.w and y >= z.y and y <= z.y + z.h
end

-- Returns true if it consumed the touch (so Main.lua's touched() shouldn't
-- also forward it to the real scoresheet).
function AddonDemo:touched(t)
  local inside = self:containsPoint(t.x, t.y)

  if t.state == BEGAN then
    if not inside then return false end
    self.dragTouchId = t.id
    self.dragLast = { x = t.x, y = t.y }
    self.flashUntil = ElapsedTime + 0.15
    devLog("[addons] demo zone touched BEGAN at", t.x, t.y, "- calling xcodeTapNativeButton()")
    if xcodeTapNativeButton then xcodeTapNativeButton() end
    return true
  end

  if t.id ~= self.dragTouchId then
    return false
  end

  if t.state == CHANGED then
    local last = self.dragLast
    local dx, dy = t.x - last.x, t.y - last.y
    self.dragLast = { x = t.x, y = t.y }
    if (dx ~= 0 or dy ~= 0) and xcodeDragNativeButton then
      xcodeDragNativeButton(dx, dy)
    end
    return true
  end

  if t.state == ENDED then
    devLog("[addons] demo zone touch ENDED")
    self.dragTouchId = nil
    self.dragLast = nil
    return true
  end

  return false
end

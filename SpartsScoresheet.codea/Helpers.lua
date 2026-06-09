-------------------
function clamp(x,a,b) 
  return math.max(a, math.min(b,x)) 
end

function fitFontSize(text, maxW, maxH, lines)
  lines = lines or 1
  local try   = maxH / lines * 0.9
  local minSz = 8
  local steps = 20
  pushStyle()
  textWrapWidth(0)
  for i=1,steps do
    fontSize(try)
    local w,h = textSize(text)
    if w <= maxW*0.98 and h <= maxH*0.98 then
      popStyle()
      return try
    end
    try = try - math.max((try - minSz)/(steps - i + 1), 0.5)
    if try <= minSz then break end
  end
  popStyle()
  return minSz
end

function codeaToUIKitRect(x, y, w, h)
  return objc.rect(x, HEIGHT - y - h, w, h)
end

function drawRoundedRect(x, y, w, h, r, fillCol, strokeCol)
  pushStyle()
  
  -- CENTER → CORNER
  local cx, cy = x - w/2, y - h/2
  
  -- choose colors
  local fc = fillCol or color(255)
  local sc = strokeCol or fillCol or color(255)
  
  fill(fc)
  stroke(sc)
  
  rectMode(CORNER)
  noSmooth()
  
  local insetPos  = vec2(cx + r, cy + r)
  local insetSize = vec2(w - 2*r, h - 2*r)
  rect(insetPos.x, insetPos.y, insetSize.x, insetSize.y)
  
  if r > 0 then
    smooth()
    lineCapMode(ROUND)
    strokeWidth(r * 2)
    
    -- top
    line(insetPos.x, insetPos.y,
    insetPos.x + insetSize.x, insetPos.y)
    -- bottom
    line(insetPos.x, insetPos.y + insetSize.y,
    insetPos.x + insetSize.x, insetPos.y + insetSize.y)
    -- left
    line(insetPos.x, insetPos.y,
    insetPos.x, insetPos.y + insetSize.y)
    -- right
    line(insetPos.x + insetSize.x, insetPos.y,
    insetPos.x + insetSize.x, insetPos.y + insetSize.y)
  end
  
  popStyle()
end

function listenForKeyboard()
  local NotificationCenter = objc.NSNotificationCenter.defaultCenter
  local KeyboardHandler = function(notification)
    print("handler firing")
    local userInfo = notification.userInfo
    local rectValue = userInfo["UIKeyboardFrameEndUserInfoKey"]
    local kbFrame = rectValue:CGRectValue()
    rawKeyboardHeight = kbFrame.size.height
    keyboardIsVisible = kbFrame.origin.y < HEIGHT
  end
  
  NotificationCenter:addObserver_selector_name_object_(
  KeyboardHandler,
  objc.selector("call:"),
  "UIKeyboardWillChangeFrameNotification",
  nil
  )
end

function _safeFilePart(s)
  s = tostring(s or ""):gsub("[^%w%s%-_]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then s = "Player" end
  return s
end

function newTeamsFromPrevious(prevTeams)
  local function cloneTotals(dst, src)
    dst.spadesTotal = src.spadesTotal or 0
    dst.heartsTotal = src.heartsTotal or 0
    dst.gameTotal   = src.gameTotal   or 0
    dst.allBags     = src.allBags     or 0
  end
  local function newTeamFrom(prev)
    local t = {
      players = {
        { name = prev.players[1].name, bid=nil, took=nil },
        { name = prev.players[2].name, bid=nil, took=nil },
      },
      hearts=nil, queensSpades=false, moonShot=false,
      spadesScore=nil, heartsScore=nil, handBags=nil,
      _oppMoonBonus=0
    }
    cloneTotals(t, prev)
    return t
  end
  return { newTeamFrom(prevTeams[1]), newTeamFrom(prevTeams[2]) }
end
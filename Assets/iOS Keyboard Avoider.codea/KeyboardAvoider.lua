KeyboardAvoider = class()

local function finiteNumber(v, fallback)
    local n = tonumber(v)
    if not n then return fallback end
    if n ~= n then return fallback end
    if n == math.huge or n == -math.huge then return fallback end
    return n
end

function KeyboardAvoider:init(kbHandler)
    self.kb = kbHandler
    self.fields = {}
    self.baseFrames = {}
    self.shiftY = 0
    
    self.padding = 12
    self.animDuration = 0.25
    
    self._nc = objc.NSNotificationCenter.defaultCenter
    self._editHandler = nil
end

function KeyboardAvoider:setAvoidanceDelegate(fn)
    self.avoidanceDelegate = fn
end

-- Register any number of fields:
-- avoider:registerFields(tf1, tf2, tf3, ...)
function KeyboardAvoider:registerFields(...)
    local list = {...}
    for i = 1, #list do
        local tf = list[i]
        if tf then self:registerField(tf) end
    end
end

function KeyboardAvoider:registerField(tf)
    table.insert(self.fields, tf)
    self.baseFrames[tf] = tf.frame
end

function KeyboardAvoider:start()
    self:_installEditingObserver()
    self:_installKeyboardCallbacks()
end

function KeyboardAvoider:stop()
    if self._editHandler then
        self._nc:removeObserver_(self._editHandler)
        self._editHandler = nil
    end
end

-- Call from touched(t). Returns true if it handled the tap.
function KeyboardAvoider:handleTouch(t)
    if t.state ~= BEGAN then return false end
    
    -- Only dismiss; never show
    if self:tapIsOutsideRegisteredTextFields(t) then
        if (self.kb:currentKeyboardHeight() or 0) > 0 then
            self:dismissKeyboard()
            return true
        end
    end
    
    return false
end

function KeyboardAvoider:dismissKeyboard()
    objc.viewer.view:endEditing_(true)
end

function KeyboardAvoider:tapIsOutsideRegisteredTextFields(t)
    -- Codea -> UIKit coords
    local ux = t.x
    local uy = HEIGHT - t.y
    
    for i = 1, #self.fields do
        local f = self.fields[i].frame
        if ux >= f.origin.x and ux <= (f.origin.x + f.size.width)
        and uy >= f.origin.y and uy <= (f.origin.y + f.size.height) then
            return false
        end
    end
    return true
end

function KeyboardAvoider:_installKeyboardCallbacks()
    self.kb:onShown(function(note)
        -- match iOS keyboard animation timing
        local ui = note and note.userInfo
        local dur = ui and ui.UIKeyboardAnimationDurationUserInfoKey
        dur = tonumber(dur)
        if dur and dur > 0 then self.animDuration = dur end
        
        self:_shiftToAvoidKeyboard(self.kb:currentKeyboardHeight() or 0, true)
    end)
    
    self.kb:onHidden(function(note)
        local ui = note and note.userInfo
        local dur = ui and ui.UIKeyboardAnimationDurationUserInfoKey
        dur = tonumber(dur)
        if dur and dur > 0 then self.animDuration = dur end
        
        self:_shiftToAvoidKeyboard(0, true)
    end)
end

function KeyboardAvoider:_installEditingObserver()
    if self._editHandler then return end
    
    local Handler = objc.class("KeyboardAvoiderEditHandler")
    
    function Handler:textDidBegin_(oNotification)
        -- If keyboard already up (or coming up), re-evaluate shift for the new active field
        local owner = self._luaOwner
        if owner then
            owner:_shiftToAvoidKeyboard(owner.kb:currentKeyboardHeight() or 0, true)
        end
    end
    
    self._editHandler = Handler()
    self._editHandler._luaOwner = self
    
    self._nc:addObserver_selector_name_object_(
    self._editHandler,
    objc.selector("textDidBegin:"),
    "UITextFieldTextDidBeginEditingNotification",
    nil
    )
end

function KeyboardAvoider:_activeField()
    for i = 1, #self.fields do
        local tf = self.fields[i]
        if tf.isFirstResponder then return tf end
    end
    return nil
end

function KeyboardAvoider:_applyShift(shiftY, animated)
    self.shiftY = finiteNumber(shiftY, 0) or 0
    
    if self.avoidanceDelegate then
        self.avoidanceDelegate(self.shiftY, animated)
        return
    end
    
    local function setFrames()
        for i = 1, #self.fields do
            local tf = self.fields[i]
            local base = self.baseFrames[tf]
            if base then
                local bx = finiteNumber(base.origin.x, 0) or 0
                local by = finiteNumber(base.origin.y, 0) or 0
                local bw = finiteNumber(base.size.width, 0) or 0
                local bh = finiteNumber(base.size.height, 0) or 0
                tf.frame = objc.rect(
                bx, by - self.shiftY,
                bw, bh
                )
            end
        end
    end
    
    if animated then
        objc.UIView:animateWithDuration_animations_(self.animDuration, setFrames)
    else
        setFrames()
    end
end

function KeyboardAvoider:_shiftToAvoidKeyboard(kh, animated)
    kh = finiteNumber(kh, 0) or 0
    if kh <= 0 then
        self:_applyShift(0, animated)
        return
    end
    
    local active = self:_activeField()
    if not active then
        self:_applyShift(0, animated)
        return
    end
    
    -- Keyboard top in UIKit coords
    local keyboardTopY = finiteNumber(HEIGHT, 0) - kh
    
    local f = self.baseFrames[active] or active.frame
    if not f then
        self:_applyShift(0, animated)
        return
    end
    
    local fy = finiteNumber(f.origin and f.origin.y, 0) or 0
    local fh = finiteNumber(f.size and f.size.height, 0) or 0
    local activeMaxY = fy + fh
    
    local overlap = finiteNumber(activeMaxY - keyboardTopY, 0) or 0
    if overlap > 0 then
        self:_applyShift(overlap + (finiteNumber(self.padding, 0) or 0), animated)
    else
        self:_applyShift(0, animated)
    end
end

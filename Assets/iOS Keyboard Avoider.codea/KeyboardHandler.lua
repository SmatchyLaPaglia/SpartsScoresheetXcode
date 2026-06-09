--# KeyboardHandler
-- creates a hidden UITextField to enable manual control of showing/hiding the iOS keyboard

KeyboardHandler = class()

function KeyboardHandler:init()
    self._nc = objc.NSNotificationCenter.defaultCenter
    self._handler = nil
    self._delegate = nil
    self._tf = nil
    
    self._kbHeight = 0
    self._isShowing = false
    
    self._cbShown = nil
    self._cbHidden = nil
    self._cbText = nil
end

local function hostView()
    local v = objc.viewer.view
    return (v and v.subviews and v.subviews[1]) or v
end

local function safeToNumber(x)
    if x == nil then return nil end
    local n = tonumber(x)
    return n
end

local function nsvalueToLua(v)
    if not v then return nil end
    -- In Codea, some ObjC types (NSNumber / BOOL) often arrive as plain Lua numbers/booleans.
    local tv = type(v)
    if tv == "number" or tv == "string" or tv == "boolean" or tv == "nil" then
        return v
    end
    if tv ~= "userdata" and tv ~= "table" then
        return tostring(v)
    end
    -- Try CGRect / CGPoint / CGSize in the most Codea-friendly way
    if v.CGRectValue then
        local r = v:CGRectValue_()
        return {
            __type = "CGRect",
            origin = { x = safeToNumber(r.origin.x), y = safeToNumber(r.origin.y) },
            size   = { w = safeToNumber(r.size.width), h = safeToNumber(r.size.height) },
            raw = tostring(v)
        }
    end
    
    if v.CGPointValue then
        local p = v:CGPointValue_()
        return {
            __type = "CGPoint",
            x = safeToNumber(p.x),
            y = safeToNumber(p.y),
            raw = tostring(v)
        }
    end
    
    if v.CGSizeValue then
        local s = v:CGSizeValue_()
        return {
            __type = "CGSize",
            w = safeToNumber(s.width),
            h = safeToNumber(s.height),
            raw = tostring(v)
        }
    end
    
    -- Numbers / bools often convert via tonumber
    local n = safeToNumber(v)
    if n ~= nil then
        return n
    end
    
    -- Strings sometimes show up already as Lua strings; otherwise tostring fallback
    return tostring(v)
end

local function userInfoToLua(userInfo)
    local out = {}
    if type(userInfo) ~= "table" then
        out.__raw = tostring(userInfo)
        return out
    end
    
    for k,v in pairs(userInfo) do
        local ks = tostring(k)
        out[ks] = nsvalueToLua(v)
    end
    return out
end

local function notificationToLua(oNotification)
    local t = {
        __type = "NSNotification",
        raw = tostring(oNotification)
    }
    
    if not oNotification then
        t.nilNotification = true
        return t
    end
    
    -- These usually exist on NSNotification
    if oNotification.name then
        t.name = tostring(oNotification.name)
    end
    if oNotification.object then
        t.object = tostring(oNotification.object)
        if oNotification.object.class then
            t.objectClass = tostring(oNotification.object.class)
        end
    end
    if oNotification.userInfo then
        t.userInfo = userInfoToLua(oNotification.userInfo)
    end
    
    return t
end

function KeyboardHandler:_ensureHiddenTextField()
    if self._tf then return end
    
    local tf = objc.UITextField:alloc():initWithFrame_(objc.rect(-2000, -2000, 10, 10))
    tf.alpha = 0.00
    tf.tintColor = objc.UIColor.clearColor
    hostView():addSubview_(tf)
    self._tf = tf
    
    -- Delegate so Return hides keyboard
    local Del = objc.class("KBHiddenTFDelegate")
    function Del:textFieldShouldReturn_(oTF)
        oTF:resignFirstResponder_()
        return true
    end
    self._delegate = Del()
    self._tf.delegate = self._delegate
end

function KeyboardHandler:_installObjCHandler()
    if self._handler then return end
    
    local Handler = objc.class("KBNotificationHandlerFull")
    
    function Handler:keyboardWillShow_(oNotification)
        local owner = self._luaOwner
        if not owner then return end
        
        owner._isShowing = true
        
        local h = 0
        if oNotification and oNotification.userInfo then
            local v = oNotification.userInfo["UIKeyboardFrameEndUserInfoKey"]
            if v and v.CGRectValue then
                local r = v:CGRectValue_()
                h = safeToNumber(r.size.height) or 0
            end
        end
        owner._kbHeight = h
        
        if owner._cbShown then
            owner._cbShown(notificationToLua(oNotification))
        end
    end
    
    function Handler:keyboardWillHide_(oNotification)
        local owner = self._luaOwner
        if not owner then return end
        
        owner._isShowing = false
        owner._kbHeight = 0
        
        if owner._cbHidden then
            owner._cbHidden(notificationToLua(oNotification))
        end
    end
    
    function Handler:textChanged_(oSender)
        local owner = self._luaOwner
        if not owner then return end
        if owner._cbText then
            owner._cbText(tostring(oSender.text or ""))
        end
    end
    
    self._handler = Handler()
    self._handler._luaOwner = self
    
    -- Wire “editing changed” for text updates
    self._tf:addTarget_action_forControlEvents_(
    self._handler,
    objc.selector("textChanged:"),
    objc.enum.UIControlEvents.editingChanged
    )
end

-- Public API: callbacks
function KeyboardHandler:onShown(cb)   self._cbShown = cb end
function KeyboardHandler:onHidden(cb)  self._cbHidden = cb end
function KeyboardHandler:onTextChanged(cb) self._cbText = cb end

-- Public API: control
function KeyboardHandler:start()
    self:_ensureHiddenTextField()
    self:_installObjCHandler()
    
    self._nc:addObserver_selector_name_object_(
    self._handler,
    objc.selector("keyboardWillShow:"),
    "UIKeyboardWillShowNotification",
    nil
    )
    
    self._nc:addObserver_selector_name_object_(
    self._handler,
    objc.selector("keyboardWillHide:"),
    "UIKeyboardWillHideNotification",
    nil
    )
end

function KeyboardHandler:isShowing()
    return self._isShowing
end

function KeyboardHandler:stop()
    if self._handler then
        self._nc:removeObserver_(self._handler)
    end
    if self._tf then self._tf:removeFromSuperview() end
    self._handler = nil
    self._delegate = nil
    self._tf = nil
end

function KeyboardHandler:toggle()
    self:_ensureHiddenTextField()
    if self._tf.isFirstResponder then
        self._tf:resignFirstResponder_()
    else
        self._tf:becomeFirstResponder_()
    end
end

function KeyboardHandler:show()
    self:_ensureHiddenTextField()
    self._tf:becomeFirstResponder_()
end

function KeyboardHandler:hide()
    if self._tf then
        self._tf:resignFirstResponder_()
    end
end

function KeyboardHandler:currentKeyboardHeight()
    return self._kbHeight or 0
end
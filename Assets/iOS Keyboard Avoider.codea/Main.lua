function setup()
    viewer.mode = FULLSCREEN
    
    kb = KeyboardHandler()
    kb:start()
    avoider = KeyboardAvoider(kb)
    avoider:start()
    
    topField, topMiddleField, bottomMiddleField, btmField = makeTextFields()
    avoider:registerFields(topField, topMiddleField, bottomMiddleField, btmField) -- or any number
end

function draw()
    background(31, 97, 117)
end

function touched(t)
    if avoider:handleTouch(t) then return true end
    return false
end

function makeTextFields()
    local w = WIDTH * 0.6
    
    local tfTop = objc.UITextField:alloc():initWithFrame_(
    objc.rect(WIDTH/2 - 160,HEIGHT*0.4,320,30))
    tfTop.backgroundColor = color(72, 72, 39)
    tfTop.placeholder = "text field 1"
    
    local tfTopMiddle = objc.UITextField:alloc():initWithFrame_(
    objc.rect(WIDTH/2 - 160,HEIGHT*0.5,320,30))
    tfTopMiddle.backgroundColor = color(72, 59, 39)
    tfTopMiddle.placeholder = "text field 2"
    
    local tfBottomMiddle = objc.UITextField:alloc():initWithFrame_(
    objc.rect(WIDTH/2 - 160,HEIGHT*0.65,320,30))
    tfBottomMiddle.backgroundColor = color(72, 41, 39)
    tfBottomMiddle.placeholder = "text field 3"
    
    local tfBottom = objc.UITextField:alloc():initWithFrame_(
    objc.rect(WIDTH/2 - 160,HEIGHT*0.75,320,30))
    tfBottom.backgroundColor = color(49, 36, 58)
    tfBottom.placeholder = "text field 4"
    
    objc.viewer.view:addSubview_(tfTop)
    objc.viewer.view:addSubview_(tfTopMiddle)
    objc.viewer.view:addSubview_(tfBottomMiddle)
    objc.viewer.view:addSubview_(tfBottom)
    return tfTop, tfTopMiddle, tfBottomMiddle, tfBottom
end
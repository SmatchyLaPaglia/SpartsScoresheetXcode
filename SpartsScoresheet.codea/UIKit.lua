--[[UIKit = {}

UIView = class()

local ConstraintProto = class()

local function _init()
  if UIView.root == nil then
    UIView.root = true -- Avoid recursion
    UIView.root = UIView(objc.viewer.view.subviews[1])
    
    -- Reset root view
    for i,sv in ipairs(UIView.root._v.subviews) do
      if i ~= 1 then -- First is <KeyboardInputView>
        sv:removeFromSuperview()
      end
    end
  end
end

function UIView:init(view)
  _init()
  self._v = view
  
  if self._v == nil then
    self._v = objc.UIView:alloc()
    self._v:initWithFrame_(objc.rect(0, 0, 0, 0))
  end
  
  self._v.translatesAutoresizingMaskIntoConstraints = false
end

function UIView:addChild(child)
  self._v:addSubview_(child._v)
end

function UIView:addConstraint(constraint)
  self._v:addConstraint_(constraint._constraint)
end

function UIView:swapConstraint(old, new)
  if old then
    self._v:removeConstraint_(old._constraint)
  end
  self._v:addConstraint_(new._constraint)
  return new
end

function UIView:layoutSubviews()
  self._v:layoutSubviews()
end

function UIView:__index(k)
  -- Constraint attr?
  local attr = objc.enum.NSLayoutAttribute[k]
  if attr ~= nil then
    -- Create a constraint prototype
    return ConstraintProto(self, attr)
  end
end

UITextField = class(UIView)
function UITextField:init(text)
  UIView.init(self, objc.UITextField:alloc())
  self._v:initWithFrame_(objc.rect(0, 0, 0, 0))
  self._v.text = text
  
  local _self = self
  local Delegate = objc.delegate("UITextFieldDelegate")
  function Delegate:textFieldDidEndEditing_(objTextField)
    if _self.onEdit then
      _self.onEdit(objTextField.text)
    end
  end
  -- UITextField will be single line only.
  -- If you need multi-line, then use UITextView.
  function Delegate:textFieldShouldReturn_(objTextField)
    objTextField:endEditing_(false)
    return false
  end
  self._v.delegate = Delegate()
end

UITextView = class(UIView)
function UITextView:init(text)
  UIView.init(self, objc.UITextView:alloc())
  self._v:initWithFrame_(objc.rect(0, 0, 0, 0))
  self._v.text = text
  
  local _self = self
  local Delegate = objc.delegate("UITextViewDelegate")
  function Delegate:textViewDidChange_(objTextView)
    if _self.onEdit then
      _self.onEdit(objTextView.text)
    end
  end
  self._v.delegate = Delegate()
end

UIConstraint = class()
function UIConstraint:init(lhs, relation, rhs)
  
  local relationMap = {
    ["="] = objc.enum.NSLayoutRelation.equal,
    [">="] = objc.enum.NSLayoutRelation.greaterThanOrEqual,
    ["<="] = objc.enum.NSLayoutRelation.lessThanOrEqual
  }
  
  relation = relationMap[relation]
  
  self._constraint = objc.NSLayoutConstraint:constraintWithItem_attribute_relatedBy_toItem_attribute_multiplier_constant_(
  lhs.view._v,
  lhs.attr,
  relation,
  rhs.view._v,
  rhs.attr,
  rhs.multiplier,
  rhs.constant
  )
end

function ConstraintProto:init(view, attr)
  self.view = view
  self.attr = attr
  self.multiplier = 1
  self.constant = 0
  self.operator = nil
end

function ConstraintProto:eq(other)
  if type(other) == "number" then
    other = {
      view = self.view,
      attr = self.attr,
      multiplier = 0.0,
      constant = other
    }
  end
  return UIConstraint(self, "=", other)
end

function ConstraintProto:lte(other)
  return UIConstraint(self, "<=", other)
end

function ConstraintProto:gte(other)
  return UIConstraint(self, ">=", other)
end

function ConstraintProto:__mul(val)
  self.multiplier = val
  return self
end

function ConstraintProto:__add(val)
  self.constant = self.constant + val
  return self
end

function ConstraintProto:__sub(val)
  self.constant = self.constant - val
  return self
end

UILayoutConstraintAxis = {
  horizontal = objc.enum.UILayoutConstraintAxis.horizontal,
  vertical = objc.enum.UILayoutConstraintAxis.vertical
}


]]
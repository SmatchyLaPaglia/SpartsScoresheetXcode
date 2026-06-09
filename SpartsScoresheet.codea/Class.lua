
function class(base)
  local c = {}
  
  local __baseindex = nil
  local __customindex = nil
  local __index = c
  
  -- Configures base class access and custom __index functions/tables
  -- assigned to the class.
  local function configureIndex()
    
    local funcSrc =
    [[local c, __customindex, __baseindex = ...
    return function(instance, k)
      return rawget(c, k)%s
    end]]

local extras = {}

if __customindex then
  if type(__customindex) == "function" then
    table.insert(extras, " or __customindex(instance, k)")
  else
    table.insert(extras, " or __customindex[k]")
  end
end

if __baseindex then
  if type(__baseindex) == "function" then
    table.insert(extras, " or __baseindex(instance, k)")
  else
    table.insert(extras, " or __baseindex[k]")
  end
end

if #extras > 0 then
  funcSrc = funcSrc:format(table.concat(extras))
  local fn, err = load(funcSrc)
  if fn then
    __index = fn(c, __customindex, __baseindex)
  else
    error(err)
  end
end
end

local mt = {}
mt.__call = function(cls, ...)
local ins = {}

rawset(c, "__index", __index)
setmetatable(ins, cls)

if cls.init then
  cls.init(ins, ...)
elseif base.init then
  base.init(ins, ...)
end

return ins
end
mt.__newindex = function(cls, key, v)
if key == "__index" then
  __customindex = v
  configureIndex()
else
  rawset(cls, key, v)
end
end
mt.__index = function(cls, k)
if k == "__index" then
  return __index
end
end

setmetatable(c, mt)

-- Shallow base class copy
if base then
for k, v in pairs(base) do
  if k ~= "__index" then
    c[k] = v
  end
end

if base.__index then
  __baseindex = base.__index
  configureIndex()
end
end

return c
end
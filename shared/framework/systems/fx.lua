-- framework/systems/fx.lua
-- Optional system: shader post-processing chain powered by moonshine
--
-- Declare on a scene:  MyScene.systems = { "fx" }
--
-- Usage in create():
--   self.fx:add("glow")
--   self.fx:add("vignette")
--   self.fx:add("crt")
--   self.fx:set("glow", "min_luma", 0.3)      -- set effect parameter
--   self.fx:set("vignette", "radius", 0.8)
--   self.fx:remove("crt")
--
-- Available effects (moonshine built-ins):
--   "boxblur", "gaussianblur", "chromasep", "colorgradc",
--   "crt", "desaturate", "filmgrain", "glow", "godsray",
--   "pixelate", "posterize", "scanlines", "sketch", "vignette"
--
-- Usage in draw() – wrap your scene drawing inside self.fx:draw():
--   function MyScene:draw()
--       self.fx:draw(function()
--           -- all drawing here goes through the effect chain
--           Renderer.drawBackground()
--           Renderer.drawEntities()
--       end)
--       -- UI drawn OUTSIDE fx to stay crisp
--   end
--
-- You can also enable/disable the whole chain:
--   self.fx:enable()
--   self.fx:disable()
--   self.fx:toggle()

local moonshine = require "moonshine"

---@class FxSystem
local FxSystem = {}
FxSystem.__index = FxSystem

---Create a new FxSystem for a scene.
---@return FxSystem
function FxSystem.new()
    local self = setmetatable({
        _effects  = {},    -- ordered list of effect names
        _chain    = nil,   -- moonshine effect chain (built lazily)
        _enabled  = true,
        _dirty    = false, -- chain needs rebuild
    }, FxSystem)
    return self
end

-- Rebuild the moonshine chain from self._effects
local function rebuildChain(self)
    if #self._effects == 0 then
        self._chain = nil
        self._dirty = false
        return
    end

    local chain = moonshine(moonshine.effects[self._effects[1]])
    for i = 2, #self._effects do
        chain = chain.chain(moonshine.effects[self._effects[i]])
    end
    self._chain = chain
    self._dirty = false

    -- Re-apply stored parameters
    if self._params then
        for ename, params in pairs(self._params) do
            for k, v in pairs(params) do
                pcall(function()
                    self._chain[ename][k] = v
                end)
            end
        end
    end
end

---Add a post-processing effect to the end of the chain.
---@param effectName string  moonshine effect name (e.g. "glow", "vignette")
function FxSystem:add(effectName)
    table.insert(self._effects, effectName)
    self._dirty = true
end

---Remove a named effect from the chain.
---@param effectName string
function FxSystem:remove(effectName)
    for i = #self._effects, 1, -1 do
        if self._effects[i] == effectName then
            table.remove(self._effects, i)
            break
        end
    end
    self._dirty = true
end

---Set a parameter on a named effect.
---@param effectName string
---@param param      string  Parameter name
---@param value      any     New value
function FxSystem:set(effectName, param, value)
    -- Store for chain rebuilds
    self._params = self._params or {}
    self._params[effectName] = self._params[effectName] or {}
    self._params[effectName][param] = value

    -- Apply immediately if chain is live
    if self._chain and not self._dirty then
        pcall(function()
            self._chain[effectName][param] = value
        end)
    end
end

---Wrap a drawing function with the effect chain.
---If no effects are added or the chain is disabled, the function is called directly.
---@param drawFn function  Drawing function to wrap
function FxSystem:draw(drawFn)
    if self._dirty then rebuildChain(self) end

    if self._enabled and self._chain then
        self._chain(drawFn)
    else
        drawFn()
    end
end

---Enable the effect chain.
function FxSystem:enable()
    self._enabled = true
end

---Disable the effect chain (drawing is passed through unmodified).
function FxSystem:disable()
    self._enabled = false
end

---Toggle the effect chain on/off.
function FxSystem:toggle()
    self._enabled = not self._enabled
end

---Return the raw moonshine chain for advanced usage.
---@return table|nil
function FxSystem:getChain()
    if self._dirty then rebuildChain(self) end
    return self._chain
end

return FxSystem

-- framework/systems/anims.lua
-- Optional system: sprite animation factory powered by anim8
--
-- Declare on a scene:  MyScene.systems = { "anims" }
--
-- Usage in create():
--   local g = self.anims:grid(frameW, frameH, image:getWidth(), image:getHeight())
--   local walkAnim = self.anims:new(g("1-4", 1), 0.1)          -- frames (1..4, row 1), 0.1s each
--   local jumpAnim = self.anims:new(g("1-2", 2), 0.15, "once") -- play once
--
-- Usage in update():
--   walkAnim:update(dt)
--
-- Usage in draw():
--   walkAnim:draw(spritesheet, x, y)             -- no rotation/scale
--   walkAnim:draw(spritesheet, x, y, 0, 2, 2)    -- scaled 2x
--
-- Other animation methods (anim8 API):
--   anim:gotoFrame(n)
--   anim:pauseAtEnd()
--   anim:clone()                                 -- duplicate with same state
--   anim.onLoop = function(anim, loops) ... end  -- callback on each loop

local anim8 = require "anim8.anim8"

---@class AnimsSystem
local AnimsSystem = {}
AnimsSystem.__index = AnimsSystem

---Create a new AnimsSystem for a scene.
---@return AnimsSystem
function AnimsSystem.new()
    return setmetatable({}, AnimsSystem)
end

---Create a grid to describe the sprite sheet layout.
---@param frameWidth  integer  Width of each frame in pixels
---@param frameHeight integer  Height of each frame in pixels
---@param imageWidth  integer  Total width of the sprite sheet
---@param imageHeight integer  Total height of the sprite sheet
---@param left        integer|nil  X offset of the first frame (default 0)
---@param top         integer|nil  Y offset of the first frame (default 0)
---@param border      integer|nil  Border between frames in pixels (default 0)
---@return table  anim8 Grid object
function AnimsSystem:grid(frameWidth, frameHeight, imageWidth, imageHeight, left, top, border)
    return anim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight, left, top, border)
end

---Create a new animation from a list of frames.
---@param frames    table   Frame list from grid:getFrames() or grid(...)
---@param durations number|table  Duration per frame (number = all same, table = per frame)
---@param onLoop    string|function|nil  "cycle" (default) | "pauseAtEnd" | callback
---@return table  anim8 Animation object
function AnimsSystem:new(frames, durations, onLoop)
    return anim8.newAnimation(frames, durations, onLoop)
end

---Return the raw anim8 module for advanced usage.
---@return table
function AnimsSystem:lib()
    return anim8
end

return AnimsSystem

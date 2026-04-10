-- framework/systems/physics.lua
-- Optional system: AABB collision world powered by bump.lua
--
-- Declare on a scene:  MyScene.systems = { "physics" }
--
-- Then in create():
--   self.physics:setTileSize(32)          -- optional, default 64
--   self.physics:add(obj, x, y, w, h)
--   local newX, newY, cols = self.physics:move(obj, targetX, targetY)
--   local cols = self.physics:check(obj, targetX, targetY)
--   self.physics:remove(obj)
--   self.physics:updateItem(obj, x, y, w, h)  -- reposition rectangle
--   self.physics:getRect(obj)             -- returns x,y,w,h
--   self.physics:queryRect(x,y,w,h)       -- returns items overlapping rect
--
-- Collision response filters (pass as 4th arg to move/check):
--   bump.slide   – slides along obstacles (default)
--   bump.touch   – stops at the obstacle surface
--   bump.cross   – passes through (triggers callbacks only)
--   bump.bounce  – bounces off obstacles

local bump = require "bump.bump"

---@class PhysicsSystem
local PhysicsSystem = {}
PhysicsSystem.__index = PhysicsSystem

-- Expose bump's response filter constants directly on the module
PhysicsSystem.slide  = bump.slide
PhysicsSystem.touch  = bump.touch
PhysicsSystem.cross  = bump.cross
PhysicsSystem.bounce = bump.bounce

---Create a new PhysicsSystem for a scene.
---@param _scene table  Scene instance (unused currently, reserved for future)
---@return PhysicsSystem
function PhysicsSystem.new(_scene)
    return setmetatable({
        _world = bump.newWorld(64),
    }, PhysicsSystem)
end

---Change the cell size of the spatial hash (call before adding objects).
---@param size integer  Cell size in pixels (default 64)
function PhysicsSystem:setTileSize(size)
    self._world = bump.newWorld(size)
end

---Add an object to the physics world.
---@param obj  any     Any Lua value used as the collision item
---@param x    number  Left edge
---@param y    number  Top edge
---@param w    number  Width
---@param h    number  Height
function PhysicsSystem:add(obj, x, y, w, h)
    self._world:add(obj, x, y, w, h)
end

---Remove an object from the physics world.
---@param obj any
function PhysicsSystem:remove(obj)
    if self._world:hasItem(obj) then
        self._world:remove(obj)
    end
end

---Update the bounding rectangle of an existing object inside the world.
---Named updateItem to avoid conflict with the per-frame tick convention.
---@param obj any
---@param x   number
---@param y   number
---@param w   number
---@param h   number
function PhysicsSystem:updateItem(obj, x, y, w, h)
    self._world:update(obj, x, y, w, h)
end

---Move an object, resolving collisions.
---@param obj     any
---@param goalX   number  Desired X position
---@param goalY   number  Desired Y position
---@param filter  function|nil  Collision response filter (default: bump.slide)
---@return number actualX, number actualY, table collisions
function PhysicsSystem:move(obj, goalX, goalY, filter)
    return self._world:move(obj, goalX, goalY, filter)
end

---Check what collisions would occur if obj moved to goalX/goalY (no movement).
---@param obj    any
---@param goalX  number
---@param goalY  number
---@param filter function|nil
---@return table collisions
function PhysicsSystem:check(obj, goalX, goalY, filter)
    local _, _, cols = self._world:check(obj, goalX, goalY, filter)
    return cols
end

---Get the current bounding rectangle of an object.
---@param obj any
---@return number x, number y, number w, number h
function PhysicsSystem:getRect(obj)
    return self._world:getRect(obj)
end

---Return all objects whose bounding rectangles overlap the given area.
---@param x number
---@param y number
---@param w number
---@param h number
---@return table items, integer count
function PhysicsSystem:queryRect(x, y, w, h)
    return self._world:queryRect(x, y, w, h)
end

---Return whether an object is registered in this world.
---@param obj any
---@return boolean
function PhysicsSystem:has(obj)
    return self._world:hasItem(obj)
end

---Return the raw bump.World for advanced usage.
---@return table
function PhysicsSystem:getWorld()
    return self._world
end

-- Note: bump does not require a per-frame update call.
-- PhysicsSystem.update = nil  (intentionally absent)

return PhysicsSystem

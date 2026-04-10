-- framework/systems/ecs.lua
-- Optional system: Entity-Component-System world powered by tiny-ecs
--
-- Declare on a scene:  MyScene.systems = { "ecs" }
--
-- Core concepts:
--   Entity  – plain Lua table with component fields
--   System  – table with a filter and process/update logic
--   World   – manages entities and systems
--
-- Usage in create():
--   -- Define a system
--   local moveSystem = self.ecs:system()
--   moveSystem.filter = self.ecs:filter("position", "velocity")
--   function moveSystem:update(entities, dt)
--       for _, e in ipairs(entities) do
--           e.position.x = e.position.x + e.velocity.x * dt
--           e.position.y = e.position.y + e.velocity.y * dt
--       end
--   end
--   self.ecs:addSystem(moveSystem)
--
--   -- Create and add entities
--   local player = { position = {x=0, y=0}, velocity = {x=100, y=0} }
--   self.ecs:add(player)
--
-- Usage in update() – framework calls self.ecs:update(dt) automatically:
--   (no manual update call needed)
--
-- Other operations:
--   self.ecs:remove(entity)
--   self.ecs:removeSystem(system)
--   self.ecs:clearEntities()

local tiny = require "tiny-ecs"

---@class EcsSystem
local EcsSystem = {}
EcsSystem.__index = EcsSystem

---Create a new EcsSystem for a scene.
---@return EcsSystem
function EcsSystem.new()
    return setmetatable({
        _world   = tiny.world(),
        _systems = {},
    }, EcsSystem)
end

-- ─── Filter helpers ──────────────────────────────────────────────────────────

---Create a filter that passes entities having ALL of the listed components.
---@param  ... string  Component names
---@return function    tiny filter
function EcsSystem:filter(...)
    return tiny.requireAll(...)
end

---Create a filter that passes entities having ANY of the listed components.
---@param  ... string
---@return function
function EcsSystem:filterAny(...)
    return tiny.requireAny(...)
end

---Create a filter that rejects entities having ANY of the listed components.
---@param  ... string
---@return function
function EcsSystem:filterExclude(...)
    return tiny.rejectAny(...)
end

-- ─── System factory ──────────────────────────────────────────────────────────

---Create a new (empty) processing system table.
---Attach a .filter and define :update(entities, dt) on the returned table,
---then pass it to self.ecs:addSystem().
---@return table  tiny system stub
function EcsSystem:system()
    return {}
end

---Create and register a processing system in one step.
---@param sys table  System table with .filter and :update(entities, dt)
---@return table  The registered system
function EcsSystem:addSystem(sys)
    table.insert(self._systems, sys)
    self._world:addSystem(sys)
    return sys
end

---Remove a previously added system.
---@param sys table
function EcsSystem:removeSystem(sys)
    for i = #self._systems, 1, -1 do
        if self._systems[i] == sys then
            table.remove(self._systems, i)
            break
        end
    end
    self._world:removeSystem(sys)
end

-- ─── Entity management ────────────────────────────────────────────────────────

---Add one or more entities to the world.
---@param  ... table  Entity tables
function EcsSystem:add(...)
    self._world:add(...)
end

---Remove one or more entities from the world.
---@param  ... table
function EcsSystem:remove(...)
    self._world:remove(...)
end

---Remove all entities (systems are preserved).
function EcsSystem:clearEntities()
    self._world:clearEntities()
end

---Remove all systems (entities are preserved).
function EcsSystem:clearSystems()
    self._world:clearSystems()
    self._systems = {}
end

-- ─── Frame update (called automatically by SceneManager) ─────────────────────

---@param dt number
function EcsSystem:update(dt)
    self._world:update(dt)
end

---Return the raw tiny-ecs world for advanced usage.
---@return table
function EcsSystem:getWorld()
    return self._world
end

return EcsSystem

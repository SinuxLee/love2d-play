-- framework/systems/map.lua
-- Optional system: Tiled map loader powered by STI (Simple Tiled Implementation)
--
-- Declare on a scene:  MyScene.systems = { "map" }
--
-- Usage in create():
--   self.map:load("assets/maps/level1.lua")
--   self.map:setLayerVisible("Background", true)
--
-- Usage in update():
--   self.map:update(dt)          -- advances tile animations
--
-- Usage in draw():
--   -- Draw map layers in camera space:
--   self.cameras:attach()
--   self.map:draw()              -- draws all visible layers
--   self.map:drawLayer("Tiles")  -- draw one specific layer
--   self.cameras:detach()
--
-- Accessing objects from the Tiled object layer:
--   for _, obj in pairs(self.map.map.layers["Objects"].objects) do
--       print(obj.x, obj.y, obj.name, obj.type)
--   end
--
-- STI also supports bump.lua integration:
--   self.map:setBumpWorld(self.physics:getWorld())
--   self.map:loadCollisions("Collisions")  -- layer name with collision tiles

local sti = require "sti"

---@class MapSystem
local MapSystem = {}
MapSystem.__index = MapSystem

---Create a new MapSystem for a scene.
---@return MapSystem
function MapSystem.new()
    return setmetatable({ map = nil }, MapSystem)
end

---Load a Tiled map exported as Lua format.
---@param path    string  Path to the .lua map file (relative to game source)
---@param plugins table|nil  Optional list of STI plugin names (e.g. {"bump"})
---@return table  The loaded STI map object (also stored as self.map.map)
function MapSystem:load(path, plugins)
    self.map = sti(path, plugins)
    return self.map
end

---Draw all visible map layers (call from inside scene:draw()).
---@param tx number|nil  Translation X (default 0)
---@param ty number|nil  Translation Y (default 0)
---@param sx number|nil  Scale X (default 1)
---@param sy number|nil  Scale Y (default 1)
function MapSystem:draw(tx, ty, sx, sy)
    if self.map then
        self.map:draw(tx, ty, sx, sy)
    end
end

---Draw a specific named layer.
---@param layerName string
function MapSystem:drawLayer(layerName)
    if not self.map then return end
    local layer = self.map.layers[layerName]
    if layer then
        self.map:drawLayer(layer)
    end
end

---Update tile animations.
---@param dt number
function MapSystem:update(dt)
    if self.map then
        self.map:update(dt)
    end
end

---Set a layer's visibility.
---@param layerName string
---@param visible   boolean
function MapSystem:setLayerVisible(layerName, visible)
    if not self.map then return end
    local layer = self.map.layers[layerName]
    if layer then layer.visible = visible end
end

---Resize the canvas (call after love.resize).
---@param w integer
---@param h integer
function MapSystem:resize(w, h)
    if self.map then self.map:resize(w, h) end
end

---Return the raw STI map object for advanced usage.
---@return table|nil
function MapSystem:get()
    return self.map
end

return MapSystem

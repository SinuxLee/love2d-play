-- framework/systems/save.lua
-- Optional system: save/load helpers powered by bitser
--
-- Declare on a scene:  MyScene.systems = { "save" }
--
-- Usage:
--   -- Serialize any Lua value to a binary string
--   local bytes = self.save:serialize(myData)
--   local data  = self.save:deserialize(bytes)
--
--   -- Write/read data directly to Love2D's save directory
--   self.save:write("save1.dat", { level = 3, score = 9000 })
--   local saved = self.save:read("save1.dat")
--
--   -- Check / delete save files
--   self.save:exists("save1.dat")  -- boolean
--   self.save:delete("save1.dat")
--
--   -- Register a class so bitser can serialize custom objects
--   self.save:register("Player", Player)

local bitser = require "bitser.bitser"

---@class SaveSystem
local SaveSystem = {}
SaveSystem.__index = SaveSystem

---Create a new SaveSystem for a scene.
---@return SaveSystem
function SaveSystem.new()
    return setmetatable({}, SaveSystem)
end

---Serialize any Lua value to a binary string.
---@param value any
---@return string  Binary data
function SaveSystem:serialize(value)
    return bitser.dumps(value)
end

---Deserialize a binary string back to a Lua value.
---@param data string  Binary data produced by serialize()
---@return any
function SaveSystem:deserialize(data)
    return bitser.loads(data)
end

---Write data to a file in Love2D's save directory.
---@param filename string  e.g. "save1.dat"
---@param value    any     Any serializable Lua value
---@return boolean ok, string|nil err
function SaveSystem:write(filename, value)
    local bytes = bitser.dumps(value)
    local ok, err = love.filesystem.write(filename, bytes)
    return ok, err
end

---Read data from a file in Love2D's save directory.
---@param filename string
---@return any|nil value, string|nil err
function SaveSystem:read(filename)
    local bytes, err = love.filesystem.read(filename)
    if not bytes then return nil, err end
    local ok, value = pcall(bitser.loads, bytes)
    if not ok then return nil, tostring(value) end
    return value
end

---Check whether a save file exists.
---@param filename string
---@return boolean
function SaveSystem:exists(filename)
    return love.filesystem.getInfo(filename, "file") ~= nil
end

---Delete a save file.
---@param filename string
---@return boolean ok
function SaveSystem:delete(filename)
    return love.filesystem.remove(filename)
end

---Register a class/table so bitser can serialize its instances.
---@param name  string  Unique name for the class
---@param class table   The class table (must have __serialize or be a plain table)
function SaveSystem:register(name, class)
    bitser.register(name, class)
end

---Return the raw bitser module for advanced usage.
---@return table
function SaveSystem:lib()
    return bitser
end

return SaveSystem

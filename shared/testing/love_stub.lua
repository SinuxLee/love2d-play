-- shared/testing/love_stub.lua
-- Minimal love.* stubs so that unit tests can require game modules
-- that reference love.* at load time without crashing.
-- This does NOT simulate any real behavior -- use integration tests for love.physics etc.

local function noop() end
local function noop_module()
    return setmetatable({}, {__index = function() return noop end})
end

love = love or {}
love.graphics = love.graphics or noop_module()
love.keyboard = love.keyboard or noop_module()
love.mouse = love.mouse or noop_module()
love.window = love.window or noop_module()
love.audio = love.audio or noop_module()
love.filesystem = love.filesystem or noop_module()
love.timer = love.timer or noop_module()
love.event = love.event or noop_module()
love.math = love.math or setmetatable({}, {
    __index = function(_, k)
        if k == "random" then return math.random end
        return noop
    end
})

-- love.graphics.getDimensions stub returning a sensible default
local lg = love.graphics
local mt = getmetatable(lg)
if mt then
    local old_index = mt.__index
    mt.__index = function(self, k)
        if k == "getDimensions" then return function() return 800, 600 end end
        if k == "getWidth" then return function() return 800 end end
        if k == "getHeight" then return function() return 600 end end
        if type(old_index) == "function" then return old_index(self, k) end
        return old_index[k]
    end
end

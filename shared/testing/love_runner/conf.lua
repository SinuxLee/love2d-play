-- shared/testing/love_runner/conf.lua
-- Headless Love2D configuration for integration tests

do
    local source = love.filesystem.getSource()
    -- love_runner is in shared/testing/love_runner/, root is 3 levels up
    local root = source .. "/../../../"
    package.path = root .. "shared/?.lua;"
        .. root .. "shared/?/init.lua;"
        .. root .. "vendor/?.lua;"
        .. root .. "vendor/?/init.lua;"
        .. package.path
end

function love.conf(t)
    t.version = "11.4"
    t.window = nil  -- no window
    t.modules.audio = false
    t.modules.sound = false
    t.modules.joystick = false
    t.modules.video = false
    t.modules.image = false
    t.modules.font = false
    t.modules.graphics = false
    t.modules.window = false
    t.modules.physics = true
    t.modules.math = true
    t.modules.data = true
    t.modules.timer = true
    t.modules.event = true
    t.modules.system = true
end

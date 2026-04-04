do
    local source = love.filesystem.getSource()
    local root = source .. "/../../"
    package.path = source .. "/src/?.lua;"
        .. source .. "/src/?/init.lua;"
        .. root .. "vendor/?.lua;"
        .. root .. "vendor/?/init.lua;"
        .. root .. "shared/?.lua;"
        .. root .. "shared/?/init.lua;"
        .. package.path
end

function love.conf(t)
    t.version = "11.4"
    t.window.title = "Physics Testbed"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.vsync = 1
    t.window.highdpi = false

    t.modules.audio = false
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = true
    t.modules.sound = false
    t.modules.system = true
    t.modules.thread = false
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
end

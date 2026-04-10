do
    local source = love.filesystem.getSource()
    local root = source .. "/../../"
    package.path = source .. "/src/?.lua;"
        .. source .. "/src/?/init.lua;"
        .. root .. "vendor/?.lua;"
        .. root .. "vendor/?/init.lua;"
        .. root .. "vendor/lua-msgpack/?.lua;"
        .. root .. "shared/?.lua;"
        .. root .. "shared/?/init.lua;"
        .. package.path
end

function love.conf(t)
    t.version = "11.4"
    t.console = false

    t.window.title = "Game Server"
    t.window.width = 900
    t.window.height = 600
    t.window.resizable = true

    t.modules.audio    = false
    t.modules.joystick = false
    t.modules.physics  = false
    t.modules.sound    = false
    t.modules.touch    = false
    t.modules.video    = false
end

-- Monorepo path setup: make vendor/, shared/, and src/ accessible via require()
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
    t.version       = "11.4"
    t.console       = true   -- show console on Windows (handy for dev)

    t.window.title  = "Framework Demo"
    t.window.width  = 1024
    t.window.height = 640
    t.window.resizable = false

    t.modules.audio   = true
    t.modules.physics = true
end

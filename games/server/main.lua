-- main.lua: temporary scaffold to verify deps load
local mp = require "msgpack"
assert(mp.pack and mp.unpack, "msgpack load failed")

function love.load()
    print("[server] starting...")
end

function love.update(dt)
end

function love.draw()
    love.graphics.print("Game Server - initializing", 10, 10)
end

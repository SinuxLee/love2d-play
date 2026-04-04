local suit = require "suit"
local testbed = require "testbed"

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    testbed:init()
end

function love.update(dt)
    testbed:update(dt)
end

function love.draw()
    testbed:draw()
end

function love.mousepressed(x, y, button)
    testbed:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    testbed:mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    testbed:mousemoved(x, y, dx, dy)
end

function love.wheelmoved(x, y)
    testbed:wheelmoved(x, y)
end

function love.keypressed(key)
    testbed:keypressed(key)
end

function love.textinput(t)
    suit.textinput(t)
end

function love.resize(w, h)
    testbed:resize(w, h)
end

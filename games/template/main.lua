local game_state = require "hump.gamestate"
local timer     = require "core.timer"
local menu      = require "scene.menu"

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    game_state.registerEvents()
    game_state.switch(menu)
end

function love.update(dt)
    timer:update(dt)
end

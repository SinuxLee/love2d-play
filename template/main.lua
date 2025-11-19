local game_state = require "libs.hump.gamestate"
local timer     = require "src.core.timer"
local menu      = require "src.scene.menu"

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    game_state.registerEvents()
    game_state.switch(menu)
end

function love.update(dt)
    timer:update(dt)
end

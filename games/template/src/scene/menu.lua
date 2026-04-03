local Gamestate = require "hump.gamestate"
local game      = require "scene.game"

local menu      = {}

function menu:draw()
    love.graphics.printf("Press ENTER to Start", 0, 300, 1280, "center")
end

function menu:keypressed(key)
    if key == "return" then
        Gamestate.switch(game)
    end
end

return menu

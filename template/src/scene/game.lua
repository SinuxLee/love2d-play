local camera = require "src.core.camera"
local Player = require("src.entity.player")
local Enemy = require("src.entity.enemy")

---@class scene.Game
---@field player entity.Player
---@field enemy entity.Player
local game = {}

function game:enter(to, pre, ...)
    self.player = Player(100, 100)
    self.enemy = Enemy(50, 50)
end

function game:update(dt)
    self.player:update(dt)
    self.enemy:update(dt)

    camera:lookAt(self.player.x, self.player.y)
end

function game:draw()
    camera:attach()
    do
        -- world drawing here
        -- self.map:draw()
        self.player:draw()
        self.enemy:draw()
    end
    camera:detach()

    -- UI drawing here
    love.graphics.print("WASD to move", 10, 10)
end

return game

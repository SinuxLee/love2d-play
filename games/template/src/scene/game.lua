local camera = require "src.core.camera"
local input = require "src.core.input"
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

function game:keypressed(key)
    input.keypressed(key)
end

function game:keyreleased(key)
    input.keyreleased(key)
end

function game:update(dt)
    self.player:update(dt)
    self.enemy:update(dt)
    camera:lookAt(self.player.x, self.player.y) -- 使用 camera:attach() 时，坐标系会变换到相机坐标系
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
    love.graphics.setColor(1, 1, 1)  -- 重置为白色，确保文本可见
    love.graphics.print("WASD to move", 10, 10)
    love.graphics.print(string.format("Player: (%.1f, %.1f)", self.player.x, self.player.y), 10, 30)
    love.graphics.print(string.format("Enemy: (%.1f, %.1f)", self.enemy.x, self.enemy.y), 10, 50)
    love.graphics.print(string.format("Input: up=%s down=%s left=%s right=%s", 
        tostring(input.up), tostring(input.down), tostring(input.left), tostring(input.right)), 10, 70)
end

return game

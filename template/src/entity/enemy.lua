local Class = require "libs.hump.class"
local input = require "src.core.input"

---@class entity.Enemy
---@field x integer
---@field y integer
---@field speed number
local Enemy = Class {}

---@param x integer
---@param y integer
function Enemy:init(x, y)
    self.x = x
    self.y = y
    self.speed = 100
end

---@param dt number
function Enemy:update(dt)
    if input.up then self.y = self.y - self.speed * dt end
    if input.down then self.y = self.y + self.speed * dt end
    if input.left then self.x = self.x - self.speed * dt end
    if input.right then self.x = self.x + self.speed * dt end
end

function Enemy:draw()
    love.graphics.setColor(100, 1, 1)
    love.graphics.rectangle("fill", self.x - 10, self.y - 10, 10, 10)
end

return Enemy

local Class = require "libs.hump.class"
local input = require "src.core.input"

---@class entity.Player
---@field x integer
---@field y integer
---@field speed number
---@field size integer
local Player = Class {}

---@param x integer
---@param y integer
function Player:init(x, y)
    self.x = x
    self.y = y
    self.speed = 200
    self.size = 20
end

---@param dt number
function Player:update(dt)
    if input.up then self.y = self.y - self.speed * dt end
    if input.down then self.y = self.y + self.speed * dt end
    if input.left then self.x = self.x - self.speed * dt end
    if input.right then self.x = self.x + self.speed * dt end
end

function Player:draw()
    love.graphics.setColor(1, 100, 1)
    love.graphics.rectangle("fill", self.x-10, self.y-10, self.size, self.size)
end

return Player

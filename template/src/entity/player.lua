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
    local dx, dy = 0, 0
    if input.left then dx = dx - 1 end
    if input.right then dx = dx + 1 end
    if input.up then dy = dy - 1 end
    if input.down then dy = dy + 1 end

    -- 归一化方向向量，确保斜向移动时速度保持一致
    if dx ~= 0 or dy ~= 0 then
        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length

        self.x = self.x + dx * self.speed * dt
        self.y = self.y + dy * self.speed * dt
    end
end

function Player:draw()
    love.graphics.setColor(0.1, 0.39, 0.1)
    love.graphics.rectangle("fill",
        self.x - self.size, self.y - self.size,
        self.size, self.size)
end

return Player

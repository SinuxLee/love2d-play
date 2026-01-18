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

function Enemy:draw()
    love.graphics.setColor(1, 0, 0)  -- 红色
    love.graphics.circle("fill", self.x, self.y , 50)
end

return Enemy

local Camera = {}
Camera.__index = Camera

function Camera.new()
    local self = setmetatable({}, Camera)
    self.x = 0
    self.y = 0
    self.scale = 1
    self.min_scale = 0.1
    self.max_scale = 10
    self.dragging = false
    self.drag_start_x = 0
    self.drag_start_y = 0
    self.cam_start_x = 0
    self.cam_start_y = 0
    return self
end

function Camera:attach()
    love.graphics.push()
    local w, h = love.graphics.getDimensions()
    love.graphics.translate(w / 2, h / 2)
    love.graphics.scale(self.scale)
    love.graphics.translate(-self.x, -self.y)
end

function Camera:detach()
    love.graphics.pop()
end

function Camera:toWorld(sx, sy)
    local w, h = love.graphics.getDimensions()
    local wx = (sx - w / 2) / self.scale + self.x
    local wy = (sy - h / 2) / self.scale + self.y
    return wx, wy
end

function Camera:toScreen(wx, wy)
    local w, h = love.graphics.getDimensions()
    local sx = (wx - self.x) * self.scale + w / 2
    local sy = (wy - self.y) * self.scale + h / 2
    return sx, sy
end

function Camera:mousepressed(x, y, button)
    if button == 2 then
        self.dragging = true
        self.drag_start_x = x
        self.drag_start_y = y
        self.cam_start_x = self.x
        self.cam_start_y = self.y
    end
end

function Camera:mousereleased(x, y, button)
    if button == 2 then
        self.dragging = false
    end
end

function Camera:mousemoved(x, y, dx, dy)
    if self.dragging then
        self.x = self.cam_start_x - (x - self.drag_start_x) / self.scale
        self.y = self.cam_start_y - (y - self.drag_start_y) / self.scale
    end
end

function Camera:wheelmoved(x, y)
    local factor = y > 0 and 1.1 or (1 / 1.1)
    self.scale = math.max(self.min_scale, math.min(self.max_scale, self.scale * factor))
end

function Camera:reset()
    self.x = 0
    self.y = 0
    self.scale = 1
end

return Camera

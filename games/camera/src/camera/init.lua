-- camera.lua — 统一相机：通过 config.mode 选择跟随/变换后端
-- https://wrothmir.is-a.dev/records/records-on-love2d/record-on-creating-a-camera/
local Camera = {}
Camera.__index = Camera

---@class CameraConfig
---@field mode string|nil "follow"|"lookat"|"lerp"|"exp"|"spring"|"deadzone"|"lookahead"|"gamera"
---@field scale number|nil 跟随模式下的统一缩放（默认 1）
---@field smoothSpeed number|nil follow/exp/deadzone/lookahead 平滑（默认 8）
---@field bounds { x: number, y: number, w: number, h: number }|nil 世界边界（follow）
---@field deadzone { w: number, h: number }|nil 世界空间死区半宽/半高（follow）
---@field lookAhead number|nil 沿 dir 的前瞻距离（follow / lookahead）
---@field lerpSpeed number|nil lerp 模式速度系数（默认 20）
---@field expDecay number|nil exp 模式衰减（默认 20）
---@field stiffness number|nil spring 刚度
---@field mass number|nil spring 质量
---@field damping number|nil spring 阻尼（默认临界阻尼）
---@field dzW number|nil deadzone 模式屏幕死区半宽（默认 100）
---@field dzH number|nil deadzone 模式屏幕死区半高（默认 80）
---@field deadzoneSmooth number|nil deadzone 子模式平滑（默认 8）
---@field world { [1]: number, [2]: number, [3]: number, [4]: number }|nil gamera: l,t,w,h

local function expDecay(a, b, decay, dt)
    return a + (b - a) * (1 - math.exp(-decay * dt))
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

function Camera:new(config)
    config = config or {}
    local o = setmetatable({}, Camera)

    o.mode = config.mode or "follow"
    o.x = 0
    o.y = 0
    o.targetX = 0
    o.targetY = 0
    o.width = love.graphics.getWidth()
    o.height = love.graphics.getHeight()
    o.scaleX = config.scale or 1
    o.scaleY = o.scaleX
    o.rotation = 0

    -- follow（Untitled 风格）
    o.smoothSpeed = config.smoothSpeed or 8
    o.bounds = config.bounds
    o.deadzone = config.deadzone
    o.lookAhead = config.lookAhead or 0

    o.velX = 0
    o.velY = 0
    o.stiffness = config.stiffness or 10
    o.mass = config.mass or 1
    o.damping = config.damping or (2 * math.sqrt(o.stiffness * o.mass))

    o.lerpSpeed = config.lerpSpeed or 20
    o.expDecay = config.expDecay or 20

    o.dzW = config.dzW or 100
    o.dzH = config.dzH or 80
    o.deadzoneSmooth = config.deadzoneSmooth or 8

    o.lookAheadDist = config.lookAheadDist or (config.lookAhead or 100)

    o.shakeIntensity = 0
    o.shakeDuration = 0
    o.shakeTimer = 0
    return o
end

function Camera:shake(intensity, duration)
    self.shakeIntensity = intensity
    self.shakeDuration = duration
    self.shakeTimer = duration
end

local function shakeOffset(self)
    local ox, oy = 0, 0
    if self.shakeTimer > 0 and self.shakeDuration > 0 then
        local t = self.shakeTimer / self.shakeDuration
        ox = (math.random() * 2 - 1) * self.shakeIntensity * t
        oy = (math.random() * 2 - 1) * self.shakeIntensity * t
    end
    return ox, oy
end

function Camera:_tickShake(dt)
    self.shakeTimer = math.max(0, self.shakeTimer - dt)
end

--- 让摄像机聚焦到某个位置（屏幕中心对准 x,y）
function Camera:lookAt(x, y)
    self.x = x - self.width / 2
    self.y = y - self.height / 2
end

--- 主更新：根据 mode 跟随目标；target 需有 .x .y
---@param target { x: number, y: number }
---@param dirX number|nil
---@param dirY number|nil
---@param dt number
function Camera:follow(target, dirX, dirY, dt)
    dirX = dirX or 0
    dirY = dirY or 0

    if self.mode == "lookat" then
        self:lookAt(target.x, target.y)
        self:_tickShake(dt)
        return
    end

    if self.mode == "lerp" then
        self:updateWithLerp(dt, target.x, target.y)
        self:_tickShake(dt)
        return
    end

    if self.mode == "exp" then
        self:updateWithExpDecay(dt, target.x, target.y)
        self:_tickShake(dt)
        return
    end

    if self.mode == "spring" then
        self:springUpdate(dt, target.x, target.y)
        self:_tickShake(dt)
        return
    end

    if self.mode == "deadzone" then
        self:updateWithDeadzone(dt, target.x, target.y)
        self:_tickShake(dt)
        return
    end

    if self.mode == "lookahead" then
        self:updateWithLookAhead(dt, target.x, target.y, dirX, dirY)
        self:_tickShake(dt)
        return
    end

    -- follow：Untitled 完整逻辑（指数平滑 + 可选死区/前瞻/边界）
    local scale = self.scaleX
    local goalX = target.x + dirX * self.lookAhead - self.width / (2 * scale)
    local goalY = target.y + dirY * self.lookAhead - self.height / (2 * scale)

    if self.deadzone then
        local sx = target.x - self.x - self.width / (2 * scale)
        local sy = target.y - self.y - self.height / (2 * scale)
        local dzW = self.deadzone.w
        local dzH = self.deadzone.h
        if math.abs(sx) < dzW then goalX = self.x end
        if math.abs(sy) < dzH then goalY = self.y end
    end

    self.x = self.x + (goalX - self.x) * (1 - math.exp(-self.smoothSpeed * dt))
    self.y = self.y + (goalY - self.y) * (1 - math.exp(-self.smoothSpeed * dt))

    if self.bounds then
        local b = self.bounds
        local vw = self.width / scale
        local vh = self.height / scale
        self.x = math.max(b.x, math.min(self.x, b.x + b.w - vw))
        self.y = math.max(b.y, math.min(self.y, b.y + b.h - vh))
    end

    self:_tickShake(dt)
end

function Camera:updateWithLerp(dt, x, y)
    local targetX = x - self.width / 2
    local targetY = y - self.height / 2
    self.x = lerp(self.x, targetX, self.lerpSpeed * dt)
    self.y = lerp(self.y, targetY, self.lerpSpeed * dt)
end

function Camera:updateWithExpDecay(dt, x, y)
    local targetX = x - self.width / 2
    local targetY = y - self.height / 2
    self.x = expDecay(self.x, targetX, self.expDecay, dt)
    self.y = expDecay(self.y, targetY, self.expDecay, dt)
end

function Camera:springUpdate(dt, x, y)
    local targetX = x - self.width / 2
    local targetY = y - self.height / 2
    local forceX = self.stiffness * (targetX - self.x)
    local forceY = self.stiffness * (targetY - self.y)
    local dampX = self.damping * self.velX
    local dampY = self.damping * self.velY
    self.velX = self.velX + (forceX - dampX) / self.mass * dt
    self.velY = self.velY + (forceY - dampY) / self.mass * dt
    self.x = self.x + self.velX * dt
    self.y = self.y + self.velY * dt
end

function Camera:updateWithDeadzone(dt, x, y)
    local screenX, screenY = self:worldToScreen(x, y)
    local centerX = self.width / 2
    local centerY = self.height / 2
    local targetX = self.x
    local targetY = self.y

    if screenX < centerX - self.dzW then
        targetX = x - (centerX - self.dzW)
    elseif screenX > centerX + self.dzW then
        targetX = x - (centerX + self.dzW)
    end

    if screenY < centerY - self.dzH then
        targetY = y - (centerY - self.dzH)
    elseif screenY > centerY + self.dzH then
        targetY = y - (centerY + self.dzH)
    end

    self.x = expDecay(self.x, targetX, self.deadzoneSmooth, dt)
    self.y = expDecay(self.y, targetY, self.deadzoneSmooth, dt)
end

function Camera:updateWithLookAhead(dt, x, y, dirX, dirY)
    dirX = dirX or 0
    dirY = dirY or 0
    if dirX == 0 and dirY == 0 then
        if love.keyboard.isDown("right") then dirX = 1 end
        if love.keyboard.isDown("left") then dirX = -1 end
        if love.keyboard.isDown("down") then dirY = 1 end
        if love.keyboard.isDown("up") then dirY = -1 end
    end
    local targetX = x + dirX * self.lookAheadDist - self.width / 2
    local targetY = y + dirY * self.lookAheadDist - self.height / 2
    self.x = expDecay(self.x, targetX, self.smoothSpeed, dt)
    self.y = expDecay(self.y, targetY, self.smoothSpeed, dt)
end

function Camera:attach()
    local ox, oy = shakeOffset(self)

    if self.mode == "follow" then
        love.graphics.push()
        love.graphics.scale(self.scaleX, self.scaleY)
        love.graphics.translate(-self.x + ox, -self.y + oy)
    else
        love.graphics.push()
        love.graphics.translate(-self.x + ox, -self.y + oy)
        love.graphics.translate(self.width / 2, self.height / 2)
        love.graphics.rotate(-self.rotation)
        love.graphics.scale(self.scaleX, self.scaleY)
        love.graphics.translate(-self.width / 2, -self.height / 2)
    end
end

function Camera:detach()
    love.graphics.pop()
end

function Camera:screenToWorld(sx, sy)
    if self.mode == "follow" then
        local s = self.scaleX
        return sx / s + self.x, sy / s + self.y
    end
    return sx + self.x, sy + self.y
end

function Camera:worldToScreen(wx, wy)
    if self.mode == "follow" then
        local s = self.scaleX
        return (wx - self.x) * s, (wy - self.y) * s
    end
    return wx - self.x, wy - self.y
end


return Camera

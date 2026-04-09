local Utils = require("core.utils")

---@class FloatingText
---@field x number
---@field y number
---@field text string
---@field color Color
---@field alpha number
---@field timer number
---@field duration number
---@field fontSize "small"|"large"

---@class Effects
---@field shakeTimer number
---@field shakeIntensity number
---@field shakeOffsetX number
---@field shakeOffsetY number
local Effects = {}

---@type love.ParticleSystem
local burstPS
---@type love.ParticleSystem
local linePS
---@type love.ParticleSystem
local wavePS
---@type love.ParticleSystem
local rainbowPS
---@type FloatingText[]
local floatingTexts = {}
---@type love.Font
local floatFontSmall
---@type love.Font
local floatFontLarge
local initialized = false

Effects.shakeTimer = 0
Effects.shakeIntensity = 0
Effects.shakeOffsetX = 0
Effects.shakeOffsetY = 0

function Effects.init()
    -- Create a small white pixel texture for all particle systems
    local canvas = love.graphics.newCanvas(4, 4)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.setCanvas()

    -- Burst particles (normal gem clear)
    burstPS = love.graphics.newParticleSystem(canvas, 500)
    burstPS:setParticleLifetime(0.3, 0.6)
    burstPS:setSpeed(80, 200)
    burstPS:setSpread(math.pi * 2)
    burstPS:setSizes(1.2, 0)
    burstPS:setLinearAcceleration(0, 100, 0, 200) -- light gravity
    burstPS:setEmissionRate(0)

    -- Line particles (striped gem activation)
    linePS = love.graphics.newParticleSystem(canvas, 300)
    linePS:setParticleLifetime(0.2, 0.4)
    linePS:setSpeed(300, 500)
    linePS:setSizes(1.5, 0.5)
    linePS:setEmissionRate(0)

    -- Shockwave particles (wrapped gem)
    wavePS = love.graphics.newParticleSystem(canvas, 200)
    wavePS:setParticleLifetime(0.2, 0.5)
    wavePS:setSpeed(150, 300)
    wavePS:setSpread(math.pi * 2)
    wavePS:setSizes(2.0, 0)
    wavePS:setEmissionRate(0)

    -- Rainbow particles (color bomb)
    rainbowPS = love.graphics.newParticleSystem(canvas, 400)
    rainbowPS:setParticleLifetime(0.4, 0.8)
    rainbowPS:setSpeed(100, 350)
    rainbowPS:setSpread(math.pi * 2)
    rainbowPS:setSizes(1.5, 0)
    rainbowPS:setLinearAcceleration(0, 50, 0, 100)
    rainbowPS:setEmissionRate(0)

    floatFontSmall = love.graphics.newFont(16)
    floatFontLarge = love.graphics.newFont(22)
    floatingTexts = {}
    initialized = true
end

---Burst colored particles at a position (normal gem clear)
---@param x number
---@param y number
---@param color Color
function Effects.burstAt(x, y, color)
    if not initialized then return end
    burstPS:setPosition(x, y)
    burstPS:setColors(color[1], color[2], color[3], 1, color[1], color[2], color[3], 0)
    burstPS:emit(10)
end

---Line sweep effect for striped gem activation
---@param x number
---@param y number
---@param direction "horizontal"|"vertical"
---@param color Color
function Effects.lineSwipe(x, y, direction, color)
    if not initialized then return end
    linePS:setPosition(x, y)
    linePS:setColors(color[1], color[2], color[3], 1, 1, 1, 1, 0)
    if direction == "horizontal" then
        linePS:setSpread(0.15)
        -- Emit left and right
        linePS:setDirection(0)
        linePS:emit(15)
        linePS:setDirection(math.pi)
        linePS:emit(15)
    else
        linePS:setSpread(0.15)
        linePS:setDirection(-math.pi / 2)
        linePS:emit(15)
        linePS:setDirection(math.pi / 2)
        linePS:emit(15)
    end
end

---Shockwave for wrapped gem activation
---@param x number
---@param y number
---@param color Color
function Effects.shockwave(x, y, color)
    if not initialized then return end
    wavePS:setPosition(x, y)
    wavePS:setColors(color[1], color[2], color[3], 1, 1, 1, 1, 0)
    wavePS:emit(30)
end

---Rainbow explosion for color bomb activation
---@param x number
---@param y number
function Effects.rainbow(x, y)
    if not initialized then return end
    rainbowPS:setPosition(x, y)
    -- Cycle through all gem colors by setting varied particle colors
    local colors = Utils.GEM_COLORS
    local c1 = colors[1]
    local c2 = colors[2]
    local c3 = colors[4]
    rainbowPS:setColors(c1[1], c1[2], c1[3], 1, c2[1], c2[2], c2[3], 0.8, c3[1], c3[2], c3[3], 0)
    rainbowPS:emit(40)
end

---Show floating score text
---@param x number
---@param y number
---@param text string
---@param color? Color
---@param large? boolean
function Effects.floatText(x, y, text, color, large)
    table.insert(floatingTexts, {
        x = x,
        y = y,
        text = text,
        color = color or {1, 1, 1},
        alpha = 1.0,
        timer = 0,
        duration = 0.8,
        fontSize = large and "large" or "small",
    })
end

---Trigger screen shake
---@param intensity? number
function Effects.shake(intensity)
    Effects.shakeIntensity = intensity or 3
    Effects.shakeTimer = 0.2
end

---@param dt number
function Effects.update(dt)
    if not initialized then return end
    burstPS:update(dt)
    linePS:update(dt)
    wavePS:update(dt)
    rainbowPS:update(dt)

    -- Update floating texts
    local i = 1
    while i <= #floatingTexts do
        local ft = floatingTexts[i]
        ft.timer = ft.timer + dt
        local t = ft.timer / ft.duration
        ft.y = ft.y - 50 * dt
        ft.alpha = 1.0 - t
        if t >= 1 then
            table.remove(floatingTexts, i)
        else
            i = i + 1
        end
    end

    -- Update screen shake
    if Effects.shakeTimer > 0 then
        Effects.shakeTimer = Effects.shakeTimer - dt
        local factor = Effects.shakeTimer / 0.2
        Effects.shakeOffsetX = (math.random() * 2 - 1) * Effects.shakeIntensity * factor
        Effects.shakeOffsetY = (math.random() * 2 - 1) * Effects.shakeIntensity * factor
    else
        Effects.shakeOffsetX = 0
        Effects.shakeOffsetY = 0
    end
end

function Effects.draw()
    if not initialized then return end
    -- Draw all particle systems
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(burstPS)
    love.graphics.draw(linePS)
    love.graphics.draw(wavePS)
    love.graphics.draw(rainbowPS)

    -- Draw floating texts
    for _, ft in ipairs(floatingTexts) do
        local font = ft.fontSize == "large" and floatFontLarge or floatFontSmall
        love.graphics.setFont(font)
        love.graphics.setColor(ft.color[1], ft.color[2], ft.color[3], ft.alpha)
        love.graphics.printf(ft.text, ft.x - 50, ft.y, 100, "center")
    end
end

return Effects

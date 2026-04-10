local fire

function love.load()
    -- 用一个 4x4 的白色小圆作为粒子图（也可以用图片）
    local canvas = love.graphics.newCanvas(8, 8)
    love.graphics.setCanvas(canvas)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 4, 4, 4)
    love.graphics.setCanvas()
    
    fire = love.graphics.newParticleSystem(canvas, 500)
    fire:setParticleLifetime(0.3, 0.8)
    fire:setEmissionRate(200)
    fire:setSpeed(50, 120)
    fire:setDirection(math.rad(-90))          -- 向上
    fire:setSpread(math.rad(30))              -- 小角度扩散
    fire:setLinearAcceleration(-20, -100, 20, -200) -- 向上加速 + 轻微左右飘
    fire:setSizes(1.5, 1.0, 0.3)             -- 先大后小
    fire:setSizeVariation(0.5)
    fire:setColors(
        1,   0.4, 0,   1,      -- 橙色核心
        1,   0.2, 0,   0.8,    -- 红橙
        0.6, 0.1, 0.1, 0.4,    -- 暗红
        0.2, 0.2, 0.2, 0       -- 烟灰消散
    )
    fire:setPosition(400, 500)
    fire:setLinearDamping(1, 2)
end

function love.update(dt)
    fire:update(dt)
end

function love.draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.1)
    love.graphics.setBlendMode("add")    -- 叠加模式让火焰发光！
    love.graphics.draw(fire)
    love.graphics.setBlendMode("alpha")  -- 恢复默认混合模式
end

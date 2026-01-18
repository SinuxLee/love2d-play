-- 简单粒子水模拟（可交互：按住鼠标左键倒水）

local particles = {}
local pool = {}
local maxParticles = 2000
local GRAVITY = 900                                      -- 像素/s^2
local R = 1                                              -- 粒子半径
local RESTITUTION = 0.0                                  -- 碰撞弹性
local VISCOSITY = 0.02                                   -- 邻近速度混合，模拟粘性
local SPAWN_RATE = 600                                   -- 每秒粒子数（按住鼠标）
local container = { x = 200, y = 200, w = 400, h = 260 } -- 容器（可改）
local lastSpawn = 0

local function spawnParticle(x, y, vx, vy)
    local p = nil
    for i = 1, #pool do
        if not pool[i].active then
            p = pool[i]
            break
        end
    end

    if not p then return end

    p.active = true
    p.x = x
    p.y = y
    p.vx = vx or 0
    p.vy = vy or 0
    p.r = R
    p.mass = 1
    p.color = { 0.2 + math.random() * 0.1, 0.4 + math.random() * 0.2, 0.9, 1 }
    particles[#particles + 1] = p
end

function love.load()
    for i = 1, maxParticles do
        pool[i] = { active = false }
    end
    love.graphics.setBackgroundColor(0.12, 0.12, 0.12)
    love.window.setMode(800, 600)
end

-- 简单邻居查找：O(n^2)（低粒子数可用）
local function applyNeighbourViscosity(dt)
    local n = #particles
    for i = 1, n do
        local a = particles[i]
        if not a.active then goto continueA end
        -- mix velocities with near particles
        for j = i + 1, n do
            local b = particles[j]
            if not b.active then goto continueB end
            local dx = b.x - a.x
            local dy = b.y - a.y
            local dist2 = dx * dx + dy * dy
            local influence = (R * 6) * (R * 6)
            if dist2 < influence and dist2 > 0 then
                local dist = math.sqrt(dist2)
                local nx, ny = dx / dist, dy / dist
                -- small separation force to avoid堆叠
                local overlap = (R * 2 - dist)
                if overlap > 0 then
                    local sep = overlap * 0.5
                    a.x = a.x - nx * sep
                    a.y = a.y - ny * sep
                    b.x = b.x + nx * sep
                    b.y = b.y + ny * sep
                end
                -- velocity blending (模拟粘性)
                local mix = VISCOSITY * dt * (1 - (dist / math.sqrt(influence)))
                local avx, avy = a.vx, a.vy
                local bvx, bvy = b.vx, b.vy
                a.vx = a.vx + (bvx - avx) * mix
                a.vy = a.vy + (bvy - avy) * mix
                b.vx = b.vx + (avx - bvx) * mix
                b.vy = b.vy + (avy - bvy) * mix
            end
            ::continueB::
        end
        ::continueA::
    end
end

local function integrate(p, dt)
    p.vy = p.vy + GRAVITY * dt
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
end

local function handleCollisions(p)
    -- 与容器边界碰撞（矩形内）
    local left = container.x + p.r
    local right = container.x + container.w - p.r
    local top = container.y + p.r
    local bottom = container.y + container.h - p.r

    -- 地板/下边界
    if p.y > bottom then
        p.y = bottom
        if p.vy > 0 then p.vy = -p.vy * RESTITUTION end
        -- 摩擦
        p.vx = p.vx * 0.6
    end
    -- 顶
    if p.y < top then
        p.y = top
        if p.vy < 0 then p.vy = -p.vy * RESTITUTION end
    end
    -- 左右
    if p.x < left then
        p.x = left
        if p.vx < 0 then p.vx = -p.vx * RESTITUTION end
    elseif p.x > right then
        p.x = right
        if p.vx > 0 then p.vx = -p.vx * RESTITUTION end
    end
end

function love.update(dt)
    -- spawn when mouse held
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        lastSpawn = lastSpawn + SPAWN_RATE * dt
        while lastSpawn >= 1 do
            local jitter = (math.random() - 0.5) * 6
            spawnParticle(mx + jitter, my + jitter, (math.random() - 0.5) * 60, -50 + math.random() * 40)
            lastSpawn = lastSpawn - 1
        end
    else
        lastSpawn = 0
    end

    -- physics
    applyNeighbourViscosity(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        if not p.active then
            table.remove(particles, i)
        else
            integrate(p, dt)
            handleCollisions(p)
            -- remove if out of world
            if p.y > love.graphics.getHeight() + 200 then
                p.active = false
                table.remove(particles, i)
            end
        end
    end
end

function love.draw()
    -- container
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", container.x, container.y, container.w, container.h)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", container.x, container.y, container.w, container.h)

    -- draw particles
    for i = 1, #particles do
        local p = particles[i]
        love.graphics.setColor(p.color)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    -- UI tip
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Hold left mouse to pour water. Particles: " .. tostring(#particles), 10, 10)
end

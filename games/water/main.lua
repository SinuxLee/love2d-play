-- 简单粒子水模拟（可交互：按住鼠标左键倒水）

local particle = require "particle"

local particles = {}
local pool = {}
local maxParticles = 2000
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
    p.r = particle.R
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
        for j = i + 1, n do
            local b = particles[j]
            if not b.active then goto continueB end
            particle.applyViscosity(a, b, dt)
            ::continueB::
        end
        ::continueA::
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
            particle.integrate(p, dt)
            particle.handleCollisions(p, container)
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

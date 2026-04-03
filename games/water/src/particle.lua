-- games/water/src/particle.lua
local particle = {}

particle.GRAVITY = 900
particle.R = 1
particle.RESTITUTION = 0.0
particle.VISCOSITY = 0.02
particle.FLOOR_FRICTION = 0.6

function particle.integrate(p, dt, gravity)
    gravity = gravity or particle.GRAVITY
    p.vy = p.vy + gravity * dt
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
end

function particle.handleCollisions(p, container, restitution, floor_friction)
    restitution = restitution or particle.RESTITUTION
    floor_friction = floor_friction or particle.FLOOR_FRICTION
    local r = p.r or particle.R

    local left = container.x + r
    local right = container.x + container.w - r
    local top = container.y + r
    local bottom = container.y + container.h - r

    if p.y > bottom then
        p.y = bottom
        if p.vy > 0 then p.vy = -p.vy * restitution end
        p.vx = p.vx * floor_friction
    end
    if p.y < top then
        p.y = top
        if p.vy < 0 then p.vy = -p.vy * restitution end
    end
    if p.x < left then
        p.x = left
        if p.vx < 0 then p.vx = -p.vx * restitution end
    elseif p.x > right then
        p.x = right
        if p.vx > 0 then p.vx = -p.vx * restitution end
    end
end

function particle.applyViscosity(a, b, dt, viscosity, r)
    viscosity = viscosity or particle.VISCOSITY
    r = r or particle.R
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dist2 = dx * dx + dy * dy
    local influence = (r * 6) * (r * 6)
    if dist2 >= influence or dist2 <= 0 then return false end

    local dist = math.sqrt(dist2)
    local nx, ny = dx / dist, dy / dist

    local overlap = (r * 2 - dist)
    if overlap > 0 then
        local sep = overlap * 0.5
        a.x = a.x - nx * sep
        a.y = a.y - ny * sep
        b.x = b.x + nx * sep
        b.y = b.y + ny * sep
    end

    local mix = viscosity * dt * (1 - (dist / math.sqrt(influence)))
    local avx, avy = a.vx, a.vy
    local bvx, bvy = b.vx, b.vy
    a.vx = a.vx + (bvx - avx) * mix
    a.vy = a.vy + (bvy - avy) * mix
    b.vx = b.vx + (avx - bvx) * mix
    b.vy = b.vy + (avy - bvy) * mix

    return true
end

return particle

local scene = {}

-- state
local stickman = nil
local anchors = {}
local active_joint = nil
local active_anchor = nil
local hook_range = 250
local start_x, start_y = 100, 400

local anchor_positions = {
    {x = 200,  y = 200},
    {x = 400,  y = 120},
    {x = 580,  y = 220},
    {x = 780,  y = 140},
    {x = 980,  y = 200},
    {x = 1150, y = 120},
    {x = 1350, y = 180},
    {x = 1520, y = 100},
    {x = 1700, y = 180},
    {x = 1880, y = 120},
    {x = 2050, y = 200},
    {x = 2200, y = 140},
}

local function findNearestAnchor(wx, wy)
    local best, best_dist = nil, math.huge
    for _, a in ipairs(anchors) do
        local dx, dy = a.x - wx, a.y - wy
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < best_dist and dist < hook_range then
            best, best_dist = a, dist
        end
    end
    return best, best_dist
end

function scene.setup(world)
    -- reset state
    anchors = {}
    active_joint = nil
    active_anchor = nil
    stickman = nil

    -- long ground
    local ground = love.physics.newBody(world, 1200, 550, "static")
    love.physics.newFixture(ground, love.physics.newRectangleShape(4000, 20))

    -- ceiling (very high)
    local ceiling = love.physics.newBody(world, 1200, -50, "static")
    love.physics.newFixture(ceiling, love.physics.newRectangleShape(4000, 20))

    -- stickman (circle body)
    stickman = love.physics.newBody(world, start_x, start_y, "dynamic")
    local stickman_shape = love.physics.newCircleShape(15)
    local sf = love.physics.newFixture(stickman, stickman_shape, 2)
    sf:setRestitution(0.2)
    sf:setFriction(0.5)
    stickman:setUserData("stickman")
    stickman:setLinearDamping(0.1)

    -- anchor points
    for _, pos in ipairs(anchor_positions) do
        local body = love.physics.newBody(world, pos.x, pos.y, "static")
        local shape = love.physics.newCircleShape(8)
        local f = love.physics.newFixture(body, shape)
        f:setFriction(0)
        body:setUserData("anchor")
        table.insert(anchors, {body = body, x = pos.x, y = pos.y})
    end

    -- finish platform
    local finish = love.physics.newBody(world, 2300, 450, "static")
    love.physics.newFixture(finish, love.physics.newRectangleShape(100, 20))
    finish:setUserData("finish")
end

function scene.mousepressed(world, wx, wy, button)
    if button == 1 and stickman and not stickman:isDestroyed() then
        if active_joint then return true end

        local anchor = findNearestAnchor(wx, wy)
        if anchor then
            local sx, sy = stickman:getPosition()
            local dx, dy = anchor.x - sx, anchor.y - sy
            local dist = math.sqrt(dx * dx + dy * dy)

            active_joint = love.physics.newRopeJoint(stickman, anchor.body, sx, sy, anchor.x, anchor.y, dist, false)
            active_anchor = anchor
        end
        return true
    end
end

function scene.mousereleased(world, wx, wy, button)
    if button == 1 and active_joint then
        if not active_joint:isDestroyed() then
            active_joint:destroy()
        end
        active_joint = nil
        active_anchor = nil
        return true
    end
end

function scene.update(world, dt)
    if not stickman or stickman:isDestroyed() then return end

    -- reset if fell too far
    local sx, sy = stickman:getPosition()
    if sy > 600 then
        stickman:setPosition(start_x, start_y)
        stickman:setLinearVelocity(0, 0)
        stickman:setAngularVelocity(0)
        if active_joint and not active_joint:isDestroyed() then
            active_joint:destroy()
        end
        active_joint = nil
        active_anchor = nil
    end
end

function scene.draw(world)
    -- draw anchor range indicators
    for _, a in ipairs(anchors) do
        -- outer range ring (faint)
        love.graphics.setColor(0.3, 0.6, 1.0, 0.08)
        love.graphics.circle("line", a.x, a.y, hook_range)

        -- anchor highlight
        love.graphics.setColor(0.3, 0.6, 1.0, 0.6)
        love.graphics.circle("fill", a.x, a.y, 10)
        love.graphics.setColor(0.4, 0.7, 1.0, 0.9)
        love.graphics.circle("line", a.x, a.y, 12)
    end

    -- active rope line
    if active_joint and not active_joint:isDestroyed() and active_anchor then
        local sx, sy = stickman:getPosition()
        love.graphics.setColor(0.9, 0.8, 0.3, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.line(sx, sy, active_anchor.x, active_anchor.y)
        love.graphics.setLineWidth(1)
    end

    -- stickman highlight
    if stickman and not stickman:isDestroyed() then
        local sx, sy = stickman:getPosition()
        love.graphics.setColor(1, 0.4, 0.3, 0.9)
        love.graphics.circle("fill", sx, sy, 15)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("line", sx, sy, 16)

        -- direction indicator (velocity)
        local vx, vy = stickman:getLinearVelocity()
        local speed = math.sqrt(vx * vx + vy * vy)
        if speed > 20 then
            local scale = 0.15
            love.graphics.setColor(1, 1, 0.5, 0.5)
            love.graphics.line(sx, sy, sx + vx * scale, sy + vy * scale)
        end
    end

    -- finish platform marker
    love.graphics.setColor(0.2, 1.0, 0.3, 0.5)
    love.graphics.rectangle("fill", 2250, 440, 100, 20)
    love.graphics.setColor(0.2, 1.0, 0.3, 0.9)
    love.graphics.print("FINISH", 2270, 425)
end

function scene.drawHUD()
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("LMB: Hook to nearest anchor | Release: Fly | RMB: Pan camera", 10, 50)

    if stickman and not stickman:isDestroyed() then
        local vx, vy = stickman:getLinearVelocity()
        local speed = math.sqrt(vx * vx + vy * vy)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.print(string.format("Speed: %.0f", speed), 10, 70)
    end
end

return scene

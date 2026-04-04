local scene = {}

function scene.setup(world)
    -- ground
    local ground = love.physics.newBody(world, 400, 500, "static")
    love.physics.newFixture(ground, love.physics.newRectangleShape(900, 20))

    local y_base = 200
    local spacing = 150

    -- 1. Revolute Joint (rotating wheel)
    local x = 100
    local pivot = love.physics.newBody(world, x, y_base, "static")
    love.physics.newFixture(pivot, love.physics.newCircleShape(5))

    local wheel = love.physics.newBody(world, x, y_base, "dynamic")
    love.physics.newFixture(wheel, love.physics.newRectangleShape(60, 10), 2)
    local rj = love.physics.newRevoluteJoint(pivot, wheel, x, y_base)
    rj:setMotorEnabled(true)
    rj:setMotorSpeed(math.pi)
    rj:setMaxMotorTorque(500)

    -- 2. Prismatic Joint (sliding platform)
    x = x + spacing
    local rail = love.physics.newBody(world, x, y_base, "static")
    love.physics.newFixture(rail, love.physics.newCircleShape(5))

    local slider = love.physics.newBody(world, x, y_base, "dynamic")
    love.physics.newFixture(slider, love.physics.newRectangleShape(40, 20), 2)
    local pj = love.physics.newPrismaticJoint(rail, slider, x, y_base, 1, 0)
    pj:setLimitsEnabled(true)
    pj:setLimits(-60, 60)
    pj:setMotorEnabled(true)
    pj:setMotorSpeed(50)
    pj:setMaxMotorForce(200)

    -- 3. Distance Joint (spring)
    x = x + spacing
    local top_anchor = love.physics.newBody(world, x, y_base - 80, "static")
    love.physics.newFixture(top_anchor, love.physics.newCircleShape(5))

    local bob = love.physics.newBody(world, x + 30, y_base + 40, "dynamic")
    love.physics.newFixture(bob, love.physics.newCircleShape(15), 3)
    local dj = love.physics.newDistanceJoint(top_anchor, bob, x, y_base - 80, x + 30, y_base + 40)
    dj:setFrequency(2)
    dj:setDampingRatio(0.1)

    -- 4. Weld Joint (rigid connection)
    x = x + spacing
    local base_body = love.physics.newBody(world, x, y_base, "dynamic")
    love.physics.newFixture(base_body, love.physics.newRectangleShape(40, 40), 2)

    local welded = love.physics.newBody(world, x + 30, y_base - 30, "dynamic")
    love.physics.newFixture(welded, love.physics.newRectangleShape(20, 20), 1)
    love.physics.newWeldJoint(base_body, welded, x + 15, y_base - 15)

    -- 5. Wheel Joint (car-like)
    x = x + spacing
    local chassis = love.physics.newBody(world, x, y_base - 30, "dynamic")
    love.physics.newFixture(chassis, love.physics.newRectangleShape(60, 15), 2)

    local wheel_l = love.physics.newBody(world, x - 20, y_base, "dynamic")
    love.physics.newFixture(wheel_l, love.physics.newCircleShape(12), 1)

    local wheel_r = love.physics.newBody(world, x + 20, y_base, "dynamic")
    love.physics.newFixture(wheel_r, love.physics.newCircleShape(12), 1)

    local wj1 = love.physics.newWheelJoint(chassis, wheel_l, x - 20, y_base, 0, 1)
    wj1:setSpringFrequency(4)
    wj1:setSpringDampingRatio(0.7)

    local wj2 = love.physics.newWheelJoint(chassis, wheel_r, x + 20, y_base, 0, 1)
    wj2:setSpringFrequency(4)
    wj2:setSpringDampingRatio(0.7)
end

return scene

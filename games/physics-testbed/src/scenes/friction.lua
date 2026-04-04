local scene = {}

function scene.setup(world)
    -- ground
    local ground = love.physics.newBody(world, 400, 550, "static")
    love.physics.newFixture(ground, love.physics.newRectangleShape(900, 20))

    -- series of ramps with different friction values
    local ramp_len = 250
    local ramp_angle = math.rad(25)

    local friction_values = {0.0, 0.1, 0.3, 0.5, 1.0}

    for i, fric in ipairs(friction_values) do
        local cx = 200 + (i - 1) * 160
        local cy = 250

        -- ramp (angled platform)
        local ramp = love.physics.newBody(world, cx, cy, "static")
        local ramp_shape = love.physics.newRectangleShape(0, 0, ramp_len, 10, ramp_angle)
        local rf = love.physics.newFixture(ramp, ramp_shape)
        rf:setFriction(fric)

        -- block on top of ramp
        local bx = cx - math.cos(ramp_angle) * 80
        local by = cy - math.sin(ramp_angle) * 80 - 20
        local block = love.physics.newBody(world, bx, by, "dynamic")
        local block_shape = love.physics.newRectangleShape(25, 25)
        local bf = love.physics.newFixture(block, block_shape, 2)
        bf:setFriction(fric)
    end

    -- label indicators on the ground (just static markers for reference)
    -- Users can see friction values by selecting the bodies
end

return scene

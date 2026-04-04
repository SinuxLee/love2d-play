local scene = {}

function scene.setup(world)
    -- ground
    local ground = love.physics.newBody(world, 400, 550, "static")
    love.physics.newFixture(ground, love.physics.newRectangleShape(900, 20))

    -- bridge parameters
    local num_planks = 20
    local plank_w = 35
    local plank_h = 8
    local start_x = 100
    local bridge_y = 300

    -- left pillar
    local left_pillar = love.physics.newBody(world, start_x - plank_w / 2, bridge_y, "static")
    love.physics.newFixture(left_pillar, love.physics.newRectangleShape(20, 80))

    -- right pillar
    local total_w = num_planks * plank_w
    local right_pillar = love.physics.newBody(world, start_x + total_w + plank_w / 2, bridge_y, "static")
    love.physics.newFixture(right_pillar, love.physics.newRectangleShape(20, 80))

    -- create planks
    local prev_body = left_pillar
    for i = 1, num_planks do
        local x = start_x + (i - 0.5) * plank_w
        local plank = love.physics.newBody(world, x, bridge_y, "dynamic")
        local shape = love.physics.newRectangleShape(plank_w - 2, plank_h)
        local fixture = love.physics.newFixture(plank, shape, 2)
        fixture:setFriction(0.6)

        -- joint at left edge of plank
        local jx = start_x + (i - 1) * plank_w
        love.physics.newRevoluteJoint(prev_body, plank, jx, bridge_y)

        prev_body = plank
    end

    -- connect last plank to right pillar
    love.physics.newRevoluteJoint(prev_body, right_pillar, start_x + num_planks * plank_w, bridge_y)

    -- drop some heavy objects onto the bridge
    for i = 1, 3 do
        local bx = 200 + (i - 1) * 150
        local heavy = love.physics.newBody(world, bx, 100, "dynamic")
        local shape = love.physics.newRectangleShape(30, 30)
        local fixture = love.physics.newFixture(heavy, shape, 5)
        fixture:setFriction(0.5)
        fixture:setRestitution(0.1)
    end
end

return scene

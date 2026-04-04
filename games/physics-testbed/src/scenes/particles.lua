local scene = {}

function scene.setup(world)
    -- container walls
    local bottom = love.physics.newBody(world, 400, 500, "static")
    love.physics.newFixture(bottom, love.physics.newRectangleShape(400, 10))

    local left = love.physics.newBody(world, 200, 350, "static")
    love.physics.newFixture(left, love.physics.newRectangleShape(10, 300))

    local right = love.physics.newBody(world, 600, 350, "static")
    love.physics.newFixture(right, love.physics.newRectangleShape(10, 300))

    -- funnel at top
    local funnel_l = love.physics.newBody(world, 320, 180, "static")
    local fl_shape = love.physics.newRectangleShape(0, 0, 100, 8, math.rad(30))
    love.physics.newFixture(funnel_l, fl_shape)

    local funnel_r = love.physics.newBody(world, 480, 180, "static")
    local fr_shape = love.physics.newRectangleShape(0, 0, 100, 8, math.rad(-30))
    love.physics.newFixture(funnel_r, fr_shape)

    -- obstacle in the middle
    local obstacle = love.physics.newBody(world, 400, 350, "static")
    love.physics.newFixture(obstacle, love.physics.newCircleShape(30))

    -- spawn particles
    local num = 80
    for i = 1, num do
        local x = 350 + math.random(-40, 40)
        local y = 50 + math.random(0, 80)
        local r = math.random(4, 7)

        local body = love.physics.newBody(world, x, y, "dynamic")
        local shape = love.physics.newCircleShape(r)
        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setRestitution(0.3)
        fixture:setFriction(0.1)
        body:setLinearDamping(0.5)
    end
end

return scene

local scene = {}

function scene.setup(world)
    -- ground
    local ground = love.physics.newBody(world, 400, 500, "static")
    love.physics.newFixture(ground, love.physics.newRectangleShape(800, 20))

    -- walls
    local left_wall = love.physics.newBody(world, 0, 300, "static")
    love.physics.newFixture(left_wall, love.physics.newRectangleShape(20, 600))

    local right_wall = love.physics.newBody(world, 800, 300, "static")
    love.physics.newFixture(right_wall, love.physics.newRectangleShape(20, 600))

    -- ceiling
    local ceiling = love.physics.newBody(world, 400, 0, "static")
    love.physics.newFixture(ceiling, love.physics.newRectangleShape(800, 20))

    -- balls with different restitution
    local colors = {
        {1, 0.3, 0.3},
        {1, 0.6, 0.2},
        {1, 1, 0.3},
        {0.3, 1, 0.3},
        {0.3, 0.6, 1},
    }

    for i = 1, 5 do
        local x = 150 + (i - 1) * 130
        local ball = love.physics.newBody(world, x, 100, "dynamic")
        local shape = love.physics.newCircleShape(20)
        local fixture = love.physics.newFixture(ball, shape, 1)
        fixture:setRestitution(0.2 * i) -- 0.2 to 1.0
        fixture:setFriction(0.1)
        ball:setLinearVelocity(0, 0)
    end

    -- some random smaller balls
    for i = 1, 15 do
        local x = math.random(100, 700)
        local y = math.random(50, 200)
        local r = math.random(8, 15)
        local ball = love.physics.newBody(world, x, y, "dynamic")
        local shape = love.physics.newCircleShape(r)
        local fixture = love.physics.newFixture(ball, shape, 1)
        fixture:setRestitution(math.random() * 0.8 + 0.2)
        fixture:setFriction(0.05)
    end
end

return scene

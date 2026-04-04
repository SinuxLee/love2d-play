local scene = {}

function scene.setup(world)
    -- ground
    local ground = love.physics.newBody(world, 400, 480, "static")
    local gf = love.physics.newFixture(ground, love.physics.newRectangleShape(900, 20))
    gf:setRestitution(1.0) -- perfectly bouncy ground

    -- drop balls with varying restitution from the same height
    local values = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0}

    for i, rest in ipairs(values) do
        local x = 80 + (i - 1) * 70
        local y = 80
        local ball = love.physics.newBody(world, x, y, "dynamic")
        local shape = love.physics.newCircleShape(15)
        local fixture = love.physics.newFixture(ball, shape, 1)
        fixture:setRestitution(rest)
        fixture:setFriction(0.0)
    end
end

return scene

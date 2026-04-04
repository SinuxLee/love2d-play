local scene = {}

function scene.setup(world)
    -- ceiling anchor
    local anchor = love.physics.newBody(world, 400, 50, "static")
    love.physics.newFixture(anchor, love.physics.newCircleShape(5))

    -- chain links
    local num_links = 15
    local link_w = 30
    local link_h = 10
    local prev_body = anchor

    for i = 1, num_links do
        local x = 400
        local y = 50 + i * (link_h + 4)
        local body = love.physics.newBody(world, x, y, "dynamic")
        local shape = love.physics.newRectangleShape(link_w, link_h)
        local fixture = love.physics.newFixture(body, shape, 2)
        fixture:setFriction(0.4)

        -- connect to previous link
        local jx = 400
        local jy = 50 + (i - 0.5) * (link_h + 4)
        love.physics.newRevoluteJoint(prev_body, body, jx, jy)

        prev_body = body
    end

    -- heavy ball at the end
    local ball = love.physics.newBody(world, 400, 50 + (num_links + 1) * (link_h + 4), "dynamic")
    local circle = love.physics.newCircleShape(20)
    local bf = love.physics.newFixture(ball, circle, 5)
    bf:setRestitution(0.3)
    love.physics.newRevoluteJoint(prev_body, ball, 400, 50 + (num_links + 0.5) * (link_h + 4))

    -- ground
    local ground = love.physics.newBody(world, 400, 550, "static")
    love.physics.newFixture(ground, love.physics.newRectangleShape(800, 20))
end

return scene

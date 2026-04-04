local scene = {}

function scene.setup(world)
    -- ground
    local ground = love.physics.newBody(world, 400, 500, "static")
    local gs = love.physics.newRectangleShape(800, 20)
    love.physics.newFixture(ground, gs)

    -- pyramid of boxes
    local box_size = 30
    local rows = 10
    local start_x = 400 - (rows * box_size) / 2
    local start_y = 500 - 30

    for row = 0, rows - 1 do
        local cols = rows - row
        local offset_x = start_x + row * (box_size / 2)
        for col = 0, cols - 1 do
            local x = offset_x + col * (box_size + 2) + box_size / 2
            local y = start_y - row * (box_size + 2) - box_size / 2
            local body = love.physics.newBody(world, x, y, "dynamic")
            local shape = love.physics.newRectangleShape(box_size, box_size)
            local fixture = love.physics.newFixture(body, shape, 1)
            fixture:setFriction(0.5)
            fixture:setRestitution(0.1)
        end
    end
end

return scene

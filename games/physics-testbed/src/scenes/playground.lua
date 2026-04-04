local scene = {}

local spawn_mode = "box" -- "box", "circle", "triangle"
local spawn_size = 20

function scene.setup(world)
    -- ground
    local ground = love.physics.newBody(world, 400, 520, "static")
    love.physics.newFixture(ground, love.physics.newRectangleShape(800, 20))

    -- walls
    local left = love.physics.newBody(world, 10, 300, "static")
    love.physics.newFixture(left, love.physics.newRectangleShape(20, 600))

    local right = love.physics.newBody(world, 790, 300, "static")
    love.physics.newFixture(right, love.physics.newRectangleShape(20, 600))

    -- a few starting platforms
    local plat1 = love.physics.newBody(world, 250, 400, "static")
    local pf1 = love.physics.newFixture(plat1, love.physics.newRectangleShape(150, 10))
    pf1:setFriction(0.5)

    local plat2 = love.physics.newBody(world, 550, 350, "static")
    local pf2 = love.physics.newFixture(plat2, love.physics.newRectangleShape(150, 10))
    pf2:setFriction(0.5)

    -- ramp
    local ramp = love.physics.newBody(world, 400, 450, "static")
    local ramp_shape = love.physics.newRectangleShape(0, 0, 200, 8, math.rad(15))
    love.physics.newFixture(ramp, ramp_shape)

    -- store world reference for spawning
    scene._world = world
end

function scene.update(world, dt)
    -- spawn objects with middle mouse or keyboard
    if love.keyboard.isDown("1") then
        spawn_mode = "box"
    elseif love.keyboard.isDown("2") then
        spawn_mode = "circle"
    elseif love.keyboard.isDown("3") then
        spawn_mode = "triangle"
    end
end

return scene

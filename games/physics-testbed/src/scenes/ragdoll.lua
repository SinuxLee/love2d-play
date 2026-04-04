local scene = {}

local function createLimb(world, x, y, w, h, density)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, density or 1)
    fixture:setFriction(0.4)
    fixture:setRestitution(0.1)
    return body
end

local function createRagdoll(world, cx, cy)
    -- torso
    local torso = createLimb(world, cx, cy, 30, 50, 2)

    -- head
    local head = love.physics.newBody(world, cx, cy - 40, "dynamic")
    love.physics.newFixture(head, love.physics.newCircleShape(12), 1)
    local neck = love.physics.newRevoluteJoint(torso, head, cx, cy - 25)
    neck:setLimitsEnabled(true)
    neck:setLimits(math.rad(-30), math.rad(30))

    -- upper arms
    local l_upper_arm = createLimb(world, cx - 30, cy - 15, 25, 8, 1)
    local r_upper_arm = createLimb(world, cx + 30, cy - 15, 25, 8, 1)

    local lsj = love.physics.newRevoluteJoint(torso, l_upper_arm, cx - 15, cy - 15)
    lsj:setLimitsEnabled(true)
    lsj:setLimits(math.rad(-135), math.rad(45))

    local rsj = love.physics.newRevoluteJoint(torso, r_upper_arm, cx + 15, cy - 15)
    rsj:setLimitsEnabled(true)
    rsj:setLimits(math.rad(-45), math.rad(135))

    -- lower arms
    local l_lower_arm = createLimb(world, cx - 55, cy - 15, 22, 7, 0.8)
    local r_lower_arm = createLimb(world, cx + 55, cy - 15, 22, 7, 0.8)

    local lej = love.physics.newRevoluteJoint(l_upper_arm, l_lower_arm, cx - 42, cy - 15)
    lej:setLimitsEnabled(true)
    lej:setLimits(math.rad(-10), math.rad(140))

    local rej = love.physics.newRevoluteJoint(r_upper_arm, r_lower_arm, cx + 42, cy - 15)
    rej:setLimitsEnabled(true)
    rej:setLimits(math.rad(-140), math.rad(10))

    -- upper legs
    local l_upper_leg = createLimb(world, cx - 8, cy + 40, 10, 30, 1.5)
    local r_upper_leg = createLimb(world, cx + 8, cy + 40, 10, 30, 1.5)

    local lhj = love.physics.newRevoluteJoint(torso, l_upper_leg, cx - 8, cy + 25)
    lhj:setLimitsEnabled(true)
    lhj:setLimits(math.rad(-90), math.rad(30))

    local rhj = love.physics.newRevoluteJoint(torso, r_upper_leg, cx + 8, cy + 25)
    rhj:setLimitsEnabled(true)
    rhj:setLimits(math.rad(-30), math.rad(90))

    -- lower legs
    local l_lower_leg = createLimb(world, cx - 8, cy + 72, 9, 28, 1)
    local r_lower_leg = createLimb(world, cx + 8, cy + 72, 9, 28, 1)

    local lkj = love.physics.newRevoluteJoint(l_upper_leg, l_lower_leg, cx - 8, cy + 55)
    lkj:setLimitsEnabled(true)
    lkj:setLimits(math.rad(-5), math.rad(130))

    local rkj = love.physics.newRevoluteJoint(r_upper_leg, r_lower_leg, cx + 8, cy + 55)
    rkj:setLimitsEnabled(true)
    rkj:setLimits(math.rad(-130), math.rad(5))
end

function scene.setup(world)
    -- ground
    local ground = love.physics.newBody(world, 400, 550, "static")
    love.physics.newFixture(ground, love.physics.newRectangleShape(900, 20))

    -- platforms
    local plat1 = love.physics.newBody(world, 250, 350, "static")
    love.physics.newFixture(plat1, love.physics.newRectangleShape(200, 10))

    local plat2 = love.physics.newBody(world, 550, 400, "static")
    love.physics.newFixture(plat2, love.physics.newRectangleShape(200, 10))

    -- create ragdolls
    createRagdoll(world, 250, 150)
    createRagdoll(world, 400, 100)
    createRagdoll(world, 550, 200)
end

return scene

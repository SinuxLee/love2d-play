-- Physics module - creates the Box2D world, borders, holes, and ball bodies
local Config = require("config")
local Physics = {}

-- Convert from original cocos2d-x coordinates (Y-up) to Love2D screen coordinates (Y-down)
-- In the original: (0,0) is bottom-left of the desk sprite
-- In Love2D: (0,0) is top-left of the screen
function Physics.deskToScreen(dx, dy)
    local sx = dx + Config.DESK_OFFSET_X
    local sy = (Config.DESK_HEIGHT - dy) + Config.DESK_OFFSET_Y
    return sx, sy
end

function Physics.screenToDesk(sx, sy)
    local dx = sx - Config.DESK_OFFSET_X
    local dy = Config.DESK_HEIGHT - (sy - Config.DESK_OFFSET_Y)
    return dx, dy
end

function Physics.init()
    local self = {}

    -- Create zero-gravity world
    -- Set meter so Box2D's internal b2_maxTranslation (2 meters) = 200 pixels.
    -- This prevents velocity clamping at high speeds.
    -- With setMeter(1), max was only 2px/step = 600 px/s, causing severe speed loss.
    love.physics.setMeter(10)
    self.world = love.physics.newWorld(0, 0, true)

    -- Collision categories:
    -- 1 = active balls & borders
    -- 2 = hole sensors
    -- 3 = disabled objects (pocketed balls, dragged white ball)

    self.balls = {}       -- indexed 0-15
    self.borders = {}
    self.holes = {}
    self.holeBodies = {}

    -- Damping speed check counter (original checks every 10th frame)
    self.dampingCheckCount = 0

    -- Create borders and holes
    Physics.createInnerBorders(self)
    Physics.createOuterBorders(self)
    Physics.createHoles(self)

    -- Set up collision callbacks
    Physics.setupCollisionCallbacks(self)

    return self
end

function Physics.createInnerBorders(self)
    for _, seg in ipairs(Config.INNER_BORDERS) do
        local x1, y1 = Physics.deskToScreen(seg[1][1], seg[1][2])
        local x2, y2 = Physics.deskToScreen(seg[2][1], seg[2][2])
        local body = love.physics.newBody(self.world, 0, 0, "static")
        local shape = love.physics.newEdgeShape(x1, y1, x2, y2)
        local fixture = love.physics.newFixture(body, shape)
        fixture:setRestitution(Config.BORDER_RESTITUTION)
        fixture:setFriction(Config.BORDER_FRICTION)
        fixture:setUserData({type = "border"})
        fixture:setCategory(1)
        fixture:setMask(3)
        table.insert(self.borders, {body = body, fixture = fixture,
                                     x1 = x1, y1 = y1, x2 = x2, y2 = y2})
    end
end

function Physics.createOuterBorders(self)
    for _, seg in ipairs(Config.OUTER_BORDERS) do
        local x1, y1 = Physics.deskToScreen(seg[1][1], seg[1][2])
        local x2, y2 = Physics.deskToScreen(seg[2][1], seg[2][2])
        local body = love.physics.newBody(self.world, 0, 0, "static")
        local shape = love.physics.newEdgeShape(x1, y1, x2, y2)
        local fixture = love.physics.newFixture(body, shape)
        fixture:setRestitution(Config.BORDER_RESTITUTION)
        fixture:setFriction(Config.BORDER_FRICTION)
        fixture:setUserData({type = "border"})
        fixture:setCategory(1)
        fixture:setMask(3)
        table.insert(self.borders, {body = body, fixture = fixture,
                                     x1 = x1, y1 = y1, x2 = x2, y2 = y2})
    end
end

function Physics.createHoles(self)
    for i, hole in ipairs(Config.HOLE_POSITIONS) do
        local sx, sy = Physics.deskToScreen(hole.x, hole.y)
        local body = love.physics.newBody(self.world, sx, sy, "static")
        local shape = love.physics.newCircleShape(Config.HOLE_RADIUS)
        local fixture = love.physics.newFixture(body, shape, 0)
        fixture:setSensor(true)
        fixture:setUserData({type = "hole", index = i})
        fixture:setCategory(2)
        fixture:setMask(3) -- collide with cat 1 (active balls), not cat 3 (disabled)
        table.insert(self.holes, {body = body, fixture = fixture, x = sx, y = sy})
        table.insert(self.holeBodies, body)
    end
end

function Physics.createBall(self, index, dx, dy)
    local sx, sy = Physics.deskToScreen(dx, dy)
    local body = love.physics.newBody(self.world, sx, sy, "dynamic")
    local shape = love.physics.newCircleShape(Config.BALL_RADIUS)

    local fixture = love.physics.newFixture(body, shape, Config.BALL_DENSITY)

    if index == 0 then
        fixture:setFriction(Config.WHITE_BALL_FRICTION)
    else
        fixture:setFriction(Config.BALL_FRICTION)
    end
    fixture:setRestitution(Config.BALL_RESTITUTION)
    fixture:setUserData({type = "ball", index = index})
    fixture:setCategory(1)
    fixture:setMask(3)

    body:setLinearDamping(Config.BALL_LINEAR_DAMPING)
    body:setAngularDamping(Config.BALL_ANGULAR_DAMPING)
    body:setBullet(true)

    -- With setMeter(100), Box2D computes mass from density in meter-space:
    --   area_m2 = pi * (15/100)^2 = 0.0707 m^2, mass = 2.7 * 0.0707 = 0.191 kg
    -- We need mass = density * pi * r_px^2 = 2.7 * pi * 225 = 1908.5
    -- Override mass to match the original pixel-space physics.
    local targetMass = Config.BALL_DENSITY * math.pi * Config.BALL_RADIUS * Config.BALL_RADIUS
    body:setMassData(0, 0, targetMass, body:getInertia())

    self.balls[index] = {
        body = body,
        shape = shape,
        fixture = fixture,
        index = index,
        state = Config.BALL_STATE_STOP,
        visible = true,
        -- Pocketing animation state
        pocketAnim = nil,
        -- 3D rolling angles (matches original vec3 angular velocity)
        rollX = math.random() * math.pi * 2,
        rollY = math.random() * math.pi * 2,
        rollZ = math.random() * math.pi * 2,
        -- Extra spin angular velocities (from cue spin or collision transfer)
        -- These are ADDED on top of pure rolling and decay over time
        extraSpinX = 0,  -- forward/back spin (高低杆)
        extraSpinY = 0,  -- left/right extra (切球偏转)
        extraSpinZ = 0,  -- top spin / side spin (左右塞)
    }
    return self.balls[index]
end

function Physics.createAllBalls(self)
    -- White ball (index 0)
    local deskHalfH = Config.DESK_HEIGHT / 2
    Physics.createBall(self, 0, Config.WHITE_BALL_ORIGINAL_X, deskHalfH)

    -- Colored balls in triangle formation (exact algorithm from PhysicalControl.lua)
    local dir_x = Config.RACK_START_X
    local dir_y = deskHalfH
    local diameter = Config.BALL_RADIUS * 2 + 2
    local ballPos_x = dir_x
    local ballPos_y = dir_y
    local curNumber = 1
    local curColY = 0

    for i = 1, 5 do
        ballPos_x = ballPos_x + diameter - 3
        ballPos_y = ballPos_y - diameter
        curColY = ballPos_y
        for j = 1, i do
            ballPos_y = ballPos_y + diameter
            local ballIndex = Config.BALL_RACK_ORDER[curNumber]
            Physics.createBall(self, ballIndex, ballPos_x, ballPos_y)
            curNumber = curNumber + 1
            if j == i then
                ballPos_y = curColY + diameter / 2
            end
        end
    end
end

function Physics.resetAllBalls(self)
    for _, ball in pairs(self.balls) do
        if ball.body and not ball.body:isDestroyed() then
            ball.body:destroy()
        end
    end
    self.balls = {}
    self.dampingCheckCount = 0
    Physics.createAllBalls(self)
end

function Physics.setupCollisionCallbacks(self)
    self.collisionCallbacks = {
        onBallBall = nil,
        onBallBorder = nil,
        onBallHole = nil,
    }
    -- Queue events during physics step; Box2D forbids body mods inside callbacks
    self._pendingEvents = {}

    self.world:setCallbacks(
        function(a, b, contact)
            local udA = a:getUserData()
            local udB = b:getUserData()
            if not udA or not udB then return end

            if udA.type == "ball" and udB.type == "ball" then
                table.insert(self._pendingEvents, {type = "ball_ball", a = udA.index, b = udB.index})
            end

            if (udA.type == "ball" and udB.type == "border") or
               (udA.type == "border" and udB.type == "ball") then
                local ballIdx = udA.type == "ball" and udA.index or udB.index
                table.insert(self._pendingEvents, {type = "ball_border", ball = ballIdx})
            end

            if (udA.type == "ball" and udB.type == "hole") or
               (udA.type == "hole" and udB.type == "ball") then
                local ballIdx = udA.type == "ball" and udA.index or udB.index
                local holeIdx = udA.type == "hole" and udA.index or udB.index
                table.insert(self._pendingEvents, {type = "ball_hole", ball = ballIdx, hole = holeIdx})
            end
        end,
        function(a, b, contact) end,
        function(a, b, contact) end,
        function(a, b, contact, ni, ti) end
    )
end

function Physics.processPendingEvents(self)
    for _, ev in ipairs(self._pendingEvents) do
        if ev.type == "ball_ball" and self.collisionCallbacks.onBallBall then
            self.collisionCallbacks.onBallBall(ev.a, ev.b)
        elseif ev.type == "ball_border" and self.collisionCallbacks.onBallBorder then
            self.collisionCallbacks.onBallBorder(ev.ball)
        elseif ev.type == "ball_hole" and self.collisionCallbacks.onBallHole then
            self.collisionCallbacks.onBallHole(ev.ball, ev.hole)
        end
    end
    self._pendingEvents = {}
end

function Physics.update(self, dt)
    -- Fixed timestep: 5 substeps at 1/300s (matches original)
    for i = 1, Config.FRESH_COUNT do
        self.world:update(1 / Config.SCREEN_REFRESH_RATE)
    end
    -- Process deferred collision events after world is unlocked
    Physics.processPendingEvents(self)
    -- Update visual rolling angles
    Physics.updateBallRolling(self, dt)
end

-- Update 3D rolling for all balls.
-- Each ball has two sources of visual rotation:
--   1. Pure rolling: angular_vel = linear_vel / radius (driven by movement)
--   2. Extra spin: from cue spin (高低杆/左右塞) or collision transfer
-- Extra spin decays over time as table friction converts it to pure rolling.
function Physics.updateBallRolling(self, dt)
    local r = Config.BALL_RADIUS
    local factor = Config.BALL_ROLLING_FACTOR
    -- Decay rate: extra spin decays to zero over ~1-2 seconds
    local spinDecay = 2.5 * dt  -- per-frame decay factor

    for _, ball in pairs(self.balls) do
        if ball.state ~= Config.BALL_STATE_IN_HOLE and ball.visible then
            local vx, vy = ball.body:getLinearVelocity()
            local speed2 = vx * vx + vy * vy

            -- 1. Pure rolling from linear velocity
            if speed2 > 1 then
                local angVelFromVx = vx / r * factor
                local angVelFromVy = -vy / r * factor

                ball.rollX = ball.rollX + angVelFromVy * dt
                ball.rollY = ball.rollY + angVelFromVx * dt
            end

            -- 2. Extra spin (on top of pure rolling)
            if math.abs(ball.extraSpinX) > 0.01 or
               math.abs(ball.extraSpinY) > 0.01 or
               math.abs(ball.extraSpinZ) > 0.01 then

                ball.rollX = ball.rollX + ball.extraSpinX * dt
                ball.rollY = ball.rollY + ball.extraSpinY * dt
                ball.rollZ = ball.rollZ + ball.extraSpinZ * dt

                -- Decay extra spin (friction gradually absorbs it)
                ball.extraSpinX = ball.extraSpinX * (1.0 - spinDecay)
                ball.extraSpinY = ball.extraSpinY * (1.0 - spinDecay)
                ball.extraSpinZ = ball.extraSpinZ * (1.0 - spinDecay)

                -- Snap to zero when small enough
                if math.abs(ball.extraSpinX) < 0.01 then ball.extraSpinX = 0 end
                if math.abs(ball.extraSpinY) < 0.01 then ball.extraSpinY = 0 end
                if math.abs(ball.extraSpinZ) < 0.01 then ball.extraSpinZ = 0 end
            end

            -- 3. Box2D angular velocity also drives Z spin (from side english)
            local angVel2D = ball.body:getAngularVelocity()
            if math.abs(angVel2D) > 0.01 then
                ball.rollZ = ball.rollZ + angVel2D * factor * dt
            end
        end
    end
end

-- Apply velocity-dependent damping (matches EightBall:adjustBallSpeed)
-- Original only checks every 10th animation frame, and also on collision events.
function Physics.applyCustomDamping(self, timeSinceShot)
    self.dampingCheckCount = self.dampingCheckCount + 1
    if self.dampingCheckCount < Config.DAMPING_CHECK_INTERVAL then
        return
    end
    self.dampingCheckCount = 0

    for _, ball in pairs(self.balls) do
        if ball.state == Config.BALL_STATE_RUN and ball.body:isActive() then
            local vx, vy = ball.body:getLinearVelocity()
            local v2 = vx * vx + vy * vy

            if timeSinceShot and timeSinceShot > Config.INCREASE_VELOCITY_TIME then
                if v2 <= Config.BALL_DAMPING_VALUE then
                    ball.body:setLinearDamping(Config.BALL_LINEAR_INCREASE_MULTIPLE)
                    if v2 <= Config.BALL_DOUBLE_DAMPING_VALUE then
                        ball.body:setLinearDamping(Config.BALL_LINEAR_INCREASE_DOUBLE_MULTIPLE)
                    end
                end
            end

            -- Per-ball individual stop: if this ball is slow enough, stop it immediately
            -- (matches original EightBallLayer.lua:947-949)
            if math.abs(vx) < Config.BALL_VELOCITY_LIMIT and
               math.abs(vy) < Config.BALL_VELOCITY_LIMIT then
                ball.body:setLinearVelocity(0, 0)
                ball.body:setAngularVelocity(0)
                ball.state = Config.BALL_STATE_STOP
                ball.body:setLinearDamping(Config.BALL_LINEAR_DAMPING)
                -- Clear extra spin when ball stops
                ball.extraSpinX = 0
                ball.extraSpinY = 0
                ball.extraSpinZ = 0
            end
        end
    end
end

-- Check if ALL balls have stopped
function Physics.areAllBallsStopped(self)
    for _, ball in pairs(self.balls) do
        if ball.state ~= Config.BALL_STATE_IN_HOLE then
            local vx, vy = ball.body:getLinearVelocity()
            if math.abs(vx) >= Config.BALL_VELOCITY_LIMIT or
               math.abs(vy) >= Config.BALL_VELOCITY_LIMIT then
                return false
            end
        end
    end
    return true
end

-- Force stop all balls
function Physics.stopAllBalls(self)
    for _, ball in pairs(self.balls) do
        if ball.state ~= Config.BALL_STATE_IN_HOLE then
            ball.body:setLinearVelocity(0, 0)
            ball.body:setAngularVelocity(0)
            ball.state = Config.BALL_STATE_STOP
            ball.body:setLinearDamping(Config.BALL_LINEAR_DAMPING)
            ball.extraSpinX = 0
            ball.extraSpinY = 0
            ball.extraSpinZ = 0
        end
    end
end

-- Disable a ball (pocketed) - move off screen, disable collision
function Physics.disableBall(self, index)
    local ball = self.balls[index]
    if not ball then return end
    ball.state = Config.BALL_STATE_IN_HOLE
    ball.body:setLinearVelocity(0, 0)
    ball.body:setAngularVelocity(0)
    ball.fixture:setCategory(3)
    ball.fixture:setMask(1, 2, 3)
end

-- Fully hide a ball after pocket animation completes
function Physics.hideBall(self, index)
    local ball = self.balls[index]
    if not ball then return end
    ball.body:setPosition(2000, 2000)
    ball.visible = false
end

-- Check if white ball placement position is legal
function Physics.isWhiteBallPositionLegal(self, sx, sy)
    local dx, dy = Physics.screenToDesk(sx, sy)
    local radius = Config.BALL_RADIUS
    local distance = Config.BALL_RADIUS * 2

    -- Within table bounds (matches MathMgr:checkBallLocationIsLegal)
    if dx <= (60 + radius) or dx >= (913 - radius) or
       dy <= (60 + radius) or dy >= (489 - radius) then
        return false
    end

    -- No overlap with other balls
    for i = 1, 15 do
        local ball = self.balls[i]
        if ball and ball.state ~= Config.BALL_STATE_IN_HOLE then
            local bx, by = ball.body:getPosition()
            local ddx = bx - sx
            local ddy = by - sy
            if ddx * ddx + ddy * ddy <= distance * distance then
                return false
            end
        end
    end
    return true
end

-- Check if position is outside table bounds
function Physics.isPositionOutOfBounds(self, sx, sy)
    local dx, dy = Physics.screenToDesk(sx, sy)
    local radius = Config.BALL_RADIUS
    if dx > (60 + radius) and dx < (913 - radius) and
       dy > (60 + radius) and dy < (489 - radius) then
        return false
    end
    return true
end

return Physics

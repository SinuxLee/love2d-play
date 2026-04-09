-- Automated test suite for billiards game
-- Runs inside Love2D, executes all tests, writes results to file, then quits.
-- Usage: love love2d -- --test
--
-- Tests cover: config integrity, coordinate conversion, physics creation,
-- ball rack layout, impulse/velocity math, damping, collision categories,
-- pocket detection, white ball legality, and game state flow.

local Config = require("config")
local Physics = require("physics")
local Cue = require("cue")

local Tests = {}
local results = {}
local passCount = 0
local failCount = 0

local function assert_eq(name, got, expected, tolerance)
    tolerance = tolerance or 0
    local pass
    if type(got) == "number" and type(expected) == "number" then
        pass = math.abs(got - expected) <= tolerance
    else
        pass = (got == expected)
    end
    if pass then
        passCount = passCount + 1
        table.insert(results, "[PASS] " .. name)
    else
        failCount = failCount + 1
        table.insert(results, "[FAIL] " .. name .. "  got=" .. tostring(got) .. "  expected=" .. tostring(expected))
    end
end

local function assert_true(name, value)
    if value then
        passCount = passCount + 1
        table.insert(results, "[PASS] " .. name)
    else
        failCount = failCount + 1
        table.insert(results, "[FAIL] " .. name .. "  expected true, got " .. tostring(value))
    end
end

local function assert_false(name, value)
    if not value then
        passCount = passCount + 1
        table.insert(results, "[PASS] " .. name)
    else
        failCount = failCount + 1
        table.insert(results, "[FAIL] " .. name .. "  expected false, got " .. tostring(value))
    end
end

-- ==================== Test Cases ====================

function Tests.config_constants()
    table.insert(results, "\n--- Config Constants ---")
    assert_eq("BALL_RADIUS", Config.BALL_RADIUS, 15)
    assert_eq("BALL_DENSITY", Config.BALL_DENSITY, 2.7)
    assert_eq("BALL_RESTITUTION", Config.BALL_RESTITUTION, 0.95)
    assert_eq("BALL_FRICTION", Config.BALL_FRICTION, 0)
    assert_eq("WHITE_BALL_FRICTION", Config.WHITE_BALL_FRICTION, 0.2)
    assert_eq("BALL_LINEAR_DAMPING", Config.BALL_LINEAR_DAMPING, 0.7)
    assert_eq("BALL_ANGULAR_DAMPING", Config.BALL_ANGULAR_DAMPING, 1)
    assert_eq("BALL_VELOCITY_LIMIT", Config.BALL_VELOCITY_LIMIT, 4)
    assert_eq("BALL_DAMPING_VALUE", Config.BALL_DAMPING_VALUE, 90000)
    assert_eq("BALL_DOUBLE_DAMPING_VALUE", Config.BALL_DOUBLE_DAMPING_VALUE, 22500)
    assert_eq("BALL_LINEAR_INCREASE_MULTIPLE", Config.BALL_LINEAR_INCREASE_MULTIPLE, 0.7)
    assert_eq("BALL_LINEAR_INCREASE_DOUBLE_MULTIPLE", Config.BALL_LINEAR_INCREASE_DOUBLE_MULTIPLE, 1.0)
    assert_eq("INCREASE_VELOCITY_TIME", Config.INCREASE_VELOCITY_TIME, 1)
    assert_eq("BORDER_RESTITUTION", Config.BORDER_RESTITUTION, 0.8)
    assert_eq("BORDER_FRICTION", Config.BORDER_FRICTION, 0.5)
    assert_eq("LINE_SPEED_RATIO", Config.LINE_SPEED_RATIO, 16000)
    assert_eq("ROTATE_FORCE_RATIO", Config.ROTATE_FORCE_RATIO, 10000)
    assert_eq("LEFT_RIGHT_FORCE_RATIO", Config.LEFT_RIGHT_FORCE_RATIO, 300)
    assert_eq("CUE_DISTANCE", Config.CUE_DISTANCE, 336)
    assert_eq("FRESH_COUNT", Config.FRESH_COUNT, 5)
    assert_eq("SCREEN_REFRESH_RATE", Config.SCREEN_REFRESH_RATE, 300)
    assert_eq("DESK_HEIGHT", Config.DESK_HEIGHT, 547)
    assert_eq("WHITE_BALL_ORIGINAL_X", Config.WHITE_BALL_ORIGINAL_X, 270)
    assert_eq("WHITE_BALL_ORIGINAL_Y", Config.WHITE_BALL_ORIGINAL_Y, 273.5)
    assert_eq("RACK_START_X", Config.RACK_START_X, 650)
    assert_eq("HOLE_COUNT", #Config.HOLE_POSITIONS, 6)
    assert_eq("INNER_BORDER_COUNT", #Config.INNER_BORDERS, 6)
    assert_eq("OUTER_BORDER_COUNT", #Config.OUTER_BORDERS, 4)
    assert_eq("BALL_RACK_ORDER_COUNT", #Config.BALL_RACK_ORDER, 15)
    assert_eq("TABLE_INNER_TOP", Config.TABLE_INNER_TOP, 488)
    assert_eq("TABLE_INNER_BOTTOM", Config.TABLE_INNER_BOTTOM, 59)
end

function Tests.coordinate_conversion()
    table.insert(results, "\n--- Coordinate Conversion ---")
    -- deskToScreen: sx = dx + OFFSET_X, sy = (DESK_HEIGHT - dy) + OFFSET_Y
    local ox = Config.DESK_OFFSET_X
    local oy = Config.DESK_OFFSET_Y

    -- Bottom-left corner of desk (0,0 in Y-up) -> screen
    local sx, sy = Physics.deskToScreen(0, 0)
    assert_eq("desk(0,0)->screen.x", sx, 0 + ox, 0.01)
    assert_eq("desk(0,0)->screen.y", sy, Config.DESK_HEIGHT + oy, 0.01)

    -- Top-right corner (DESK_WIDTH, DESK_HEIGHT) -> screen
    sx, sy = Physics.deskToScreen(Config.DESK_WIDTH, Config.DESK_HEIGHT)
    assert_eq("desk(W,H)->screen.x", sx, Config.DESK_WIDTH + ox, 0.01)
    assert_eq("desk(W,H)->screen.y", sy, 0 + oy, 0.01)

    -- Round-trip
    local dx, dy = Physics.screenToDesk(Physics.deskToScreen(270, 273.5))
    assert_eq("roundtrip.x", dx, 270, 0.01)
    assert_eq("roundtrip.y", dy, 273.5, 0.01)

    -- White ball position
    sx, sy = Physics.deskToScreen(Config.WHITE_BALL_ORIGINAL_X, Config.DESK_HEIGHT / 2)
    dx, dy = Physics.screenToDesk(sx, sy)
    assert_eq("white_ball_roundtrip.x", dx, Config.WHITE_BALL_ORIGINAL_X, 0.01)
    assert_eq("white_ball_roundtrip.y", dy, Config.DESK_HEIGHT / 2, 0.01)
end

function Tests.physics_creation()
    table.insert(results, "\n--- Physics Creation ---")
    local phys = Physics.init()

    -- World created
    assert_true("world exists", phys.world ~= nil)

    -- Borders: 6 inner + 4 outer = 10
    assert_eq("border_count", #phys.borders, 10)

    -- Holes: 6
    assert_eq("hole_count", #phys.holes, 6)

    -- Verify hole sensors
    for i, hole in ipairs(phys.holes) do
        assert_true("hole_" .. i .. "_is_sensor", hole.fixture:isSensor())
    end

    -- Create balls
    Physics.createAllBalls(phys)

    -- 16 balls (0-15)
    local ballCount = 0
    for _ in pairs(phys.balls) do ballCount = ballCount + 1 end
    assert_eq("ball_count", ballCount, 16)

    -- Ball mass = density * pi * r^2
    local expectedMass = Config.BALL_DENSITY * math.pi * Config.BALL_RADIUS * Config.BALL_RADIUS
    local wb = phys.balls[0]
    assert_eq("ball_mass", wb.body:getMass(), expectedMass, 0.1)

    -- Ball restitution
    assert_eq("ball_restitution", wb.fixture:getRestitution(), Config.BALL_RESTITUTION, 0.001)

    -- White ball friction
    assert_eq("white_ball_friction", wb.fixture:getFriction(), Config.WHITE_BALL_FRICTION, 0.001)

    -- Colored ball friction
    local b1 = phys.balls[1]
    assert_eq("color_ball_friction", b1.fixture:getFriction(), Config.BALL_FRICTION, 0.001)

    -- Linear damping
    assert_eq("ball_linear_damping", wb.body:getLinearDamping(), Config.BALL_LINEAR_DAMPING, 0.001)

    -- Bullet mode
    assert_true("ball_is_bullet", wb.body:isBullet())

    -- Clean up
    for _, ball in pairs(phys.balls) do
        ball.body:destroy()
    end
    for _, b in ipairs(phys.borders) do
        b.body:destroy()
    end
    for _, h in ipairs(phys.holes) do
        h.body:destroy()
    end
    phys.world:destroy()
end

function Tests.ball_rack_layout()
    table.insert(results, "\n--- Ball Rack Layout ---")
    local phys = Physics.init()
    Physics.createAllBalls(phys)

    -- White ball at (270, deskH/2)
    local wb = phys.balls[0]
    local wsx, wsy = wb.body:getPosition()
    local wdx, wdy = Physics.screenToDesk(wsx, wsy)
    assert_eq("white_ball_desk_x", wdx, 270, 1)
    assert_eq("white_ball_desk_y", wdy, Config.DESK_HEIGHT / 2, 1)

    -- Front ball (#1) should be at approximately (650 + 29, deskH/2 + 32)
    -- Actually: first iteration i=1: ballPos_x = 650 + 29 = 679, ballPos_y = deskH/2 - 32 + 32 = deskH/2
    local b1 = phys.balls[1]
    local b1sx, b1sy = b1.body:getPosition()
    local b1dx, b1dy = Physics.screenToDesk(b1sx, b1sy)
    assert_eq("ball_1_desk_x", b1dx, 679, 1)
    assert_eq("ball_1_desk_y", b1dy, Config.DESK_HEIGHT / 2, 1)

    -- 8-ball should be in the middle of the third row
    -- i=3: ballPos_x = 650 + 29*3 = 737, middle ball (j=2 of 3)
    local b8 = phys.balls[8]
    local b8sx, b8sy = b8.body:getPosition()
    local b8dx, b8dy = Physics.screenToDesk(b8sx, b8sy)
    -- 8 is the 5th in BALL_RACK_ORDER -> row 3 (i=3), ball 2 of 3 (j=2) -> y = center
    assert_eq("ball_8_desk_x", b8dx, 737, 2)

    -- All 15 colored balls should be in front of white ball (x > 270)
    local allInFront = true
    for i = 1, 15 do
        local b = phys.balls[i]
        local bsx, bsy = b.body:getPosition()
        local bdx, bdy = Physics.screenToDesk(bsx, bsy)
        if bdx < 270 then allInFront = false end
    end
    assert_true("all_colored_balls_in_front_of_white", allInFront)

    -- Clean up
    for _, ball in pairs(phys.balls) do ball.body:destroy() end
    for _, b in ipairs(phys.borders) do b.body:destroy() end
    for _, h in ipairs(phys.holes) do h.body:destroy() end
    phys.world:destroy()
end

function Tests.impulse_velocity()
    table.insert(results, "\n--- Impulse & Velocity ---")
    love.physics.setMeter(100)
    local world = love.physics.newWorld(0, 0, true)
    local body = love.physics.newBody(world, 500, 300, "dynamic")
    local shape = love.physics.newCircleShape(Config.BALL_RADIUS)
    local fixture = love.physics.newFixture(body, shape, Config.BALL_DENSITY)
    body:setLinearDamping(Config.BALL_LINEAR_DAMPING)
    body:setBullet(true)

    -- Override mass to match pixel-space physics (same as physics.lua does)
    local targetMass = Config.BALL_DENSITY * math.pi * Config.BALL_RADIUS * Config.BALL_RADIUS
    body:setMassData(0, 0, targetMass, body:getInertia())

    local mass = body:getMass()
    local expectedMass = Config.BALL_DENSITY * math.pi * Config.BALL_RADIUS^2
    assert_eq("impulse_test_mass", mass, expectedMass, 0.1)

    -- Full power impulse
    local fullImpulse = Config.CUE_DISTANCE * Config.LINE_SPEED_RATIO * 1.0
    assert_eq("full_impulse_value", fullImpulse, 336 * 16000, 0.1)

    body:applyLinearImpulse(fullImpulse, 0)
    local vx, _ = body:getLinearVelocity()
    local expectedV = fullImpulse / mass
    assert_eq("full_power_velocity", vx, expectedV, 1)
    assert_true("full_power_velocity_reasonable", vx > 2500 and vx < 3200)

    -- Step 1 second (300 substeps)
    for i = 1, 300 do
        world:update(1/300)
    end
    vx, _ = body:getLinearVelocity()
    -- After 1s with damping 0.7: v should decay to roughly half
    assert_true("velocity_after_1s_decayed", vx < 1500 and vx > 100)

    -- v^2 should have decayed
    local v2 = vx * vx
    assert_true("v2_decayed", v2 < 2000000)

    body:destroy()
    world:destroy()
end

function Tests.damping_system()
    table.insert(results, "\n--- Damping System ---")
    local phys = Physics.init()
    Physics.createAllBalls(phys)

    local wb = phys.balls[0]
    wb.state = Config.BALL_STATE_RUN

    -- Set velocity below BALL_DAMPING_VALUE threshold (v^2 < 90000, v < 300)
    wb.body:setLinearVelocity(200, 0)

    for i = 1, 15 do
        Physics.applyCustomDamping(phys, 2.0)
    end

    local damping = wb.body:getLinearDamping()
    -- v=200, v^2=40000 < 90000 -> increased damping
    -- v^2=40000 > 22500 -> not double damping yet
    assert_eq("damping_increased", damping, Config.BALL_LINEAR_INCREASE_MULTIPLE, 0.01)

    -- Set velocity below double threshold (v^2 < 22500, v < 150)
    wb.body:setLinearVelocity(100, 0)
    wb.state = Config.BALL_STATE_RUN
    wb.body:setLinearDamping(Config.BALL_LINEAR_DAMPING)

    for i = 1, 15 do
        Physics.applyCustomDamping(phys, 2.0)
    end

    damping = wb.body:getLinearDamping()
    assert_eq("damping_doubled", damping, Config.BALL_LINEAR_INCREASE_DOUBLE_MULTIPLE, 0.01)

    -- Per-ball individual stop: set velocity below BALL_VELOCITY_LIMIT (4)
    wb.body:setLinearVelocity(3, 2)
    wb.state = Config.BALL_STATE_RUN
    for i = 1, 15 do
        Physics.applyCustomDamping(phys, 2.0)
    end
    assert_eq("per_ball_stop_state", wb.state, Config.BALL_STATE_STOP)
    local vx, vy = wb.body:getLinearVelocity()
    assert_eq("per_ball_stop_vx", vx, 0, 0.01)
    assert_eq("per_ball_stop_vy", vy, 0, 0.01)

    -- Clean up
    for _, ball in pairs(phys.balls) do ball.body:destroy() end
    for _, b in ipairs(phys.borders) do b.body:destroy() end
    for _, h in ipairs(phys.holes) do h.body:destroy() end
    phys.world:destroy()
end

function Tests.collision_categories()
    table.insert(results, "\n--- Collision Categories ---")
    local phys = Physics.init()
    Physics.createAllBalls(phys)

    -- Active ball: category 1, mask 3
    local wb = phys.balls[0]
    local cat = wb.fixture:getCategory()
    assert_eq("active_ball_category", cat, 1)

    -- Hole sensor: category 2
    local holeCat = phys.holes[1].fixture:getCategory()
    assert_eq("hole_category", holeCat, 2)
    assert_true("hole_is_sensor", phys.holes[1].fixture:isSensor())

    -- Disable a ball
    Physics.disableBall(phys, 1)
    local b1 = phys.balls[1]
    assert_eq("disabled_ball_category", b1.fixture:getCategory(), 3)
    assert_eq("disabled_ball_state", b1.state, Config.BALL_STATE_IN_HOLE)

    -- Clean up
    for _, ball in pairs(phys.balls) do ball.body:destroy() end
    for _, b in ipairs(phys.borders) do b.body:destroy() end
    for _, h in ipairs(phys.holes) do h.body:destroy() end
    phys.world:destroy()
end

function Tests.white_ball_legality()
    table.insert(results, "\n--- White Ball Legality ---")
    local phys = Physics.init()
    Physics.createAllBalls(phys)

    -- Center of table should be legal (away from all balls)
    local cx, cy = Physics.deskToScreen(484, 273.5)
    -- This is near the rack, may not be legal. Use a safe spot instead.
    local sx, sy = Physics.deskToScreen(200, 273.5)
    assert_true("center_left_legal", Physics.isWhiteBallPositionLegal(phys, sx, sy))

    -- Outside table bounds should be illegal
    sx, sy = Physics.deskToScreen(10, 10)
    assert_false("outside_bounds_illegal", Physics.isWhiteBallPositionLegal(phys, sx, sy))

    -- Right on top of a ball should be illegal
    local b1 = phys.balls[1]
    local b1x, b1y = b1.body:getPosition()
    assert_false("on_top_of_ball_illegal", Physics.isWhiteBallPositionLegal(phys, b1x, b1y))

    -- Clean up
    for _, ball in pairs(phys.balls) do ball.body:destroy() end
    for _, b in ipairs(phys.borders) do b.body:destroy() end
    for _, h in ipairs(phys.holes) do h.body:destroy() end
    phys.world:destroy()
end

function Tests.ball_stop_detection()
    table.insert(results, "\n--- Ball Stop Detection ---")
    local phys = Physics.init()
    Physics.createAllBalls(phys)

    -- All balls should be stopped initially (velocity = 0)
    assert_true("all_stopped_initially", Physics.areAllBallsStopped(phys))

    -- Set one ball moving
    phys.balls[0].body:setLinearVelocity(100, 0)
    assert_false("not_stopped_when_moving", Physics.areAllBallsStopped(phys))

    -- Set below threshold (BALL_VELOCITY_LIMIT = 4)
    phys.balls[0].body:setLinearVelocity(3, 3)
    assert_true("stopped_below_threshold", Physics.areAllBallsStopped(phys))

    -- Pocketed balls should not affect stop check
    Physics.disableBall(phys, 1)
    phys.balls[1].body:setLinearVelocity(1000, 1000) -- shouldn't matter
    assert_true("pocketed_ball_ignored", Physics.areAllBallsStopped(phys))

    -- Clean up
    for _, ball in pairs(phys.balls) do ball.body:destroy() end
    for _, b in ipairs(phys.borders) do b.body:destroy() end
    for _, h in ipairs(phys.holes) do h.body:destroy() end
    phys.world:destroy()
end

function Tests.cue_launch()
    table.insert(results, "\n--- Cue Launch ---")
    local phys = Physics.init()
    Physics.createAllBalls(phys)

    local cue = Cue.init(phys)
    cue.angle = 0  -- aiming right
    cue.power = 50  -- 50%
    cue.spinX = 0
    cue.spinY = 0
    cue.visible = true
    cue.shooting = false

    local wb = phys.balls[0]
    local oldX, oldY = wb.body:getPosition()

    local didShoot = Cue.launchBall(cue, phys)
    assert_true("cue_did_shoot", didShoot)
    assert_false("cue_hidden_after_shot", cue.visible)
    assert_eq("ball_state_run", wb.state, Config.BALL_STATE_RUN)

    -- Ball should have velocity
    local vx, vy = wb.body:getLinearVelocity()
    assert_true("ball_has_velocity_x", math.abs(vx) > 100)
    assert_eq("ball_velocity_y_near_zero", vy, 0, 1)

    -- Expected: 336 * 16000 * 0.5 / mass
    local expectedV = Config.CUE_DISTANCE * Config.LINE_SPEED_RATIO * 0.5 / wb.body:getMass()
    assert_eq("ball_velocity_matches_formula", vx, expectedV, 1)

    -- Continuous force should be stored
    assert_true("continuous_force_nil_when_no_spin", wb._continuousForce.x == 0)

    -- Test with spin
    Physics.resetAllBalls(phys)
    local cue2 = Cue.init(phys)
    cue2.angle = math.pi / 4  -- 45 degrees
    cue2.power = 100
    cue2.spinX = 0.5
    cue2.spinY = -0.5
    cue2.visible = true
    cue2.shooting = false

    wb = phys.balls[0]
    Cue.launchBall(cue2, phys)
    vx, vy = wb.body:getLinearVelocity()
    assert_true("diagonal_shot_vx", math.abs(vx) > 100)
    assert_true("diagonal_shot_vy", math.abs(vy) > 100)
    assert_true("angular_velocity_set", math.abs(wb.body:getAngularVelocity()) > 0)
    assert_true("continuous_force_set", wb._continuousForce ~= nil)

    -- Clean up
    for _, ball in pairs(phys.balls) do ball.body:destroy() end
    for _, b in ipairs(phys.borders) do b.body:destroy() end
    for _, h in ipairs(phys.holes) do h.body:destroy() end
    phys.world:destroy()
end

function Tests.physics_simulation()
    table.insert(results, "\n--- Physics Simulation (Ball Movement) ---")
    local phys = Physics.init()
    Physics.createAllBalls(phys)

    local wb = phys.balls[0]
    local startX, startY = wb.body:getPosition()

    -- Apply impulse to white ball (shoot right)
    local impulse = Config.CUE_DISTANCE * Config.LINE_SPEED_RATIO * 1.0
    wb.body:applyLinearImpulse(impulse, 0)
    wb.state = Config.BALL_STATE_RUN

    -- Step 1 frame
    Physics.update(phys, 1/60)

    local newX, newY = wb.body:getPosition()
    assert_true("ball_moved_after_step", newX > startX)

    -- Step many frames to let ball hit the rack
    for i = 1, 30 do
        Physics.update(phys, 1/60)
    end

    -- Some colored balls should have moved (check position changed from initial)
    local anyMoved = false
    for i = 1, 15 do
        local ball = phys.balls[i]
        local bx, by = ball.body:getPosition()
        local vx, vy = ball.body:getLinearVelocity()
        -- Check either velocity or position displacement
        local initBx, initBy = Physics.deskToScreen(Config.RACK_START_X + 29, Config.DESK_HEIGHT / 2)
        local dx = bx - initBx
        local dy = by - initBy
        if math.abs(vx) > 0.01 or math.abs(vy) > 0.01 or
           (dx*dx + dy*dy) > 4 then
            anyMoved = true
            break
        end
    end
    assert_true("colored_balls_moved_after_collision", anyMoved)

    -- Clean up
    for _, ball in pairs(phys.balls) do ball.body:destroy() end
    for _, b in ipairs(phys.borders) do b.body:destroy() end
    for _, h in ipairs(phys.holes) do h.body:destroy() end
    phys.world:destroy()
end

function Tests.hole_positions_symmetry()
    table.insert(results, "\n--- Hole Position Symmetry ---")
    local holes = Config.HOLE_POSITIONS
    -- Should have 6 holes
    assert_eq("hole_count", #holes, 6)

    -- Left holes x should be equal
    assert_eq("left_holes_x", holes[1].x, holes[2].x, 0.1)
    -- Center holes x should be equal
    assert_eq("center_holes_x", holes[3].x, holes[4].x, 0.1)
    -- Right holes x should be equal
    assert_eq("right_holes_x", holes[5].x, holes[6].x, 0.1)
end

function Tests.rack_order_completeness()
    table.insert(results, "\n--- Rack Order Completeness ---")
    local order = Config.BALL_RACK_ORDER
    assert_eq("rack_order_length", #order, 15)

    -- Should contain exactly balls 1-15
    local seen = {}
    for _, v in ipairs(order) do
        seen[v] = true
    end
    for i = 1, 15 do
        assert_true("rack_contains_ball_" .. i, seen[i] == true)
    end

    -- Ball 8 should be at position 5 (center of rack)
    assert_eq("ball_8_at_position_5", order[5], 8)
end

-- ==================== Runner ====================

function Tests.run()
    table.insert(results, "=== Billiards Love2D Test Suite ===")
    table.insert(results, "")

    local testFuncs = {
        "config_constants",
        "coordinate_conversion",
        "physics_creation",
        "ball_rack_layout",
        "impulse_velocity",
        "damping_system",
        "collision_categories",
        "white_ball_legality",
        "ball_stop_detection",
        "cue_launch",
        "physics_simulation",
        "hole_positions_symmetry",
        "rack_order_completeness",
    }

    for _, name in ipairs(testFuncs) do
        local ok, err = pcall(Tests[name])
        if not ok then
            failCount = failCount + 1
            table.insert(results, "[ERROR] " .. name .. ": " .. tostring(err))
        end
    end

    table.insert(results, "")
    table.insert(results, string.format("=== Results: %d passed, %d failed ===", passCount, failCount))

    return table.concat(results, "\n"), failCount
end

return Tests

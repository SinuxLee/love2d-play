-- Break shot diagnostic test
-- Simulates a full-power break shot and logs detailed physics data.
-- Usage: love love2d -- --test-break

local Config = require("config")
local Physics = require("physics")
local Cue = require("cue")

local function run()
    local lines = {}
    local function log(s) table.insert(lines, s) end

    log("=== Break Shot Diagnostic ===")
    log("")

    -- Config dump
    log("-- Config --")
    log(string.format("  LINE_SPEED_RATIO    = %s", Config.LINE_SPEED_RATIO))
    log(string.format("  CUE_DISTANCE        = %s", Config.CUE_DISTANCE))
    log(string.format("  BALL_DENSITY         = %s", Config.BALL_DENSITY))
    log(string.format("  BALL_RADIUS          = %s", Config.BALL_RADIUS))
    log(string.format("  BALL_LINEAR_DAMPING  = %s", Config.BALL_LINEAR_DAMPING))
    log(string.format("  BALL_RESTITUTION     = %s", Config.BALL_RESTITUTION))
    log(string.format("  BALL_VELOCITY_LIMIT  = %s", Config.BALL_VELOCITY_LIMIT))
    log(string.format("  INCREASE_VELOCITY_TIME = %s", Config.INCREASE_VELOCITY_TIME))
    log(string.format("  BALL_DAMPING_VALUE   = %s", Config.BALL_DAMPING_VALUE))
    log(string.format("  BALL_DOUBLE_DAMPING_VALUE = %s", Config.BALL_DOUBLE_DAMPING_VALUE))
    log(string.format("  BALL_LINEAR_INCREASE_MULTIPLE = %s", Config.BALL_LINEAR_INCREASE_MULTIPLE))
    log(string.format("  BALL_LINEAR_INCREASE_DOUBLE_MULTIPLE = %s", Config.BALL_LINEAR_INCREASE_DOUBLE_MULTIPLE))
    log(string.format("  BORDER_RESTITUTION   = %s", Config.BORDER_RESTITUTION))
    log("")

    -- Create physics world and balls
    local phys = Physics.init()
    Physics.createAllBalls(phys)

    local wb = phys.balls[0]
    local mass = wb.body:getMass()
    log(string.format("  Ball mass            = %.2f", mass))

    -- Record initial positions
    local initPos = {}
    for i = 0, 15 do
        local b = phys.balls[i]
        local bx, by = b.body:getPosition()
        local dx, dy = Physics.screenToDesk(bx, by)
        initPos[i] = {sx = bx, sy = by, dx = dx, dy = dy}
    end

    log("")
    log("-- Initial Positions (desk coords) --")
    log(string.format("  White ball: desk(%.1f, %.1f) screen(%.1f, %.1f)",
        initPos[0].dx, initPos[0].dy, initPos[0].sx, initPos[0].sy))
    log(string.format("  Ball 1 (front): desk(%.1f, %.1f) screen(%.1f, %.1f)",
        initPos[1].dx, initPos[1].dy, initPos[1].sx, initPos[1].sy))

    local distWbToB1 = math.sqrt((initPos[0].sx - initPos[1].sx)^2 + (initPos[0].sy - initPos[1].sy)^2)
    log(string.format("  Distance white->ball1: %.1f px", distWbToB1))

    -- Simulate break shot: full power, aimed directly at ball 1
    local cue = Cue.init(phys)
    cue.angle = math.atan2(initPos[1].sy - initPos[0].sy, initPos[1].sx - initPos[0].sx)
    cue.power = 100
    cue.spinX = 0
    cue.spinY = 0
    cue.visible = true
    cue.shooting = false

    log("")
    log("-- Shot Parameters --")
    log(string.format("  Cue angle: %.3f rad (%.1f deg)", cue.angle, math.deg(cue.angle)))
    log(string.format("  Power: %d%%", cue.power))

    local impulse = Config.CUE_DISTANCE * Config.LINE_SPEED_RATIO * 1.0
    local expectedV0 = impulse / mass
    log(string.format("  Impulse: %.0f", impulse))
    log(string.format("  Expected v0: %.1f px/s", expectedV0))

    -- Launch
    Cue.launchBall(cue, phys)
    local vx0, vy0 = wb.body:getLinearVelocity()
    log(string.format("  Actual v0: (%.1f, %.1f) = %.1f px/s", vx0, vy0, math.sqrt(vx0^2+vy0^2)))
    log(string.format("  WB damping after launch: %.2f", wb.body:getLinearDamping()))

    -- Detailed first-frame substep analysis
    log("")
    log("-- First frame substep detail --")
    for substep = 1, Config.FRESH_COUNT do
        phys.world:update(1 / Config.SCREEN_REFRESH_RATE)
        local svx, svy = wb.body:getLinearVelocity()
        local sbx, sby = wb.body:getPosition()
        log(string.format("  substep %d: v=(%.1f,%.1f) pos=(%.1f,%.1f) damping=%.2f",
            substep, svx, svy, sbx, sby, wb.body:getLinearDamping()))
    end
    Physics.processPendingEvents(phys)
    Physics.updateBallRolling(phys, 1/60)
    Cue.updateForces(phys, 1/60)
    Physics.applyCustomDamping(phys, 1/60)

    log("")
    log("-- Simulation (from frame 2) --")

    -- Simulate frame by frame, tracking white ball and checking for collisions
    local firstCollisionFrame = nil
    local totalFrames = 300  -- 5 seconds at 60fps
    local timeSinceShot = 0

    for frame = 1, totalFrames do
        local dt = 1/60
        timeSinceShot = timeSinceShot + dt

        -- Physics step
        Physics.update(phys, dt)
        Cue.updateForces(phys, dt)

        -- Apply damping (like game.lua does)
        Physics.applyCustomDamping(phys, timeSinceShot)

        -- Check white ball status
        local wvx, wvy = wb.body:getLinearVelocity()
        local wspeed = math.sqrt(wvx^2 + wvy^2)
        local wbx, wby = wb.body:getPosition()

        -- Log key frames
        if frame == 1 or frame == 5 or frame == 10 or frame == 15 or
           frame == 30 or frame == 60 or frame == 120 or frame == 180 or frame == 300 then
            log(string.format("  Frame %3d (t=%.2fs): wb pos=(%.0f,%.0f) v=%.1f damping=%.2f",
                frame, timeSinceShot, wbx, wby, wspeed, wb.body:getLinearDamping()))
        end

        -- Check if any colored ball has velocity (first collision detection)
        if not firstCollisionFrame then
            for i = 1, 15 do
                local b = phys.balls[i]
                local bvx, bvy = b.body:getLinearVelocity()
                if math.abs(bvx) > 1 or math.abs(bvy) > 1 then
                    firstCollisionFrame = frame
                    log(string.format("  >>> First collision at frame %d (t=%.3fs), ball %d got v=(%.1f,%.1f)",
                        frame, timeSinceShot, i, bvx, bvy))
                    break
                end
            end
        end
    end

    log("")
    log("-- Final State (after 5 seconds) --")

    local movedCount = 0
    local stoppedCount = 0
    local maxDisplacement = 0

    for i = 0, 15 do
        local b = phys.balls[i]
        local bx, by = b.body:getPosition()
        local vx, vy = b.body:getLinearVelocity()
        local speed = math.sqrt(vx^2 + vy^2)
        local disp = math.sqrt((bx - initPos[i].sx)^2 + (by - initPos[i].sy)^2)

        if disp > maxDisplacement then maxDisplacement = disp end

        if disp > 2 then
            movedCount = movedCount + 1
        else
            stoppedCount = stoppedCount + 1
        end

        if i == 0 or disp > 5 or speed > 1 then
            log(string.format("  Ball %2d: pos=(%.0f,%.0f) v=%.1f displaced=%.1f px %s",
                i, bx, by, speed, disp,
                b.state == Config.BALL_STATE_IN_HOLE and "[IN HOLE]" or
                b.state == Config.BALL_STATE_STOP and "[STOP]" or "[RUN]"))
        end
    end

    log("")
    log(string.format("  Balls moved: %d / 16", movedCount))
    log(string.format("  Max displacement: %.1f px", maxDisplacement))
    log(string.format("  First collision: frame %s", tostring(firstCollisionFrame or "NONE")))

    if not firstCollisionFrame then
        log("")
        log("  !!! WHITE BALL NEVER REACHED THE RACK !!!")
        log("  Possible causes:")
        log("    - Impulse too weak (LINE_SPEED_RATIO too low)")
        log("    - Damping too high (BALL_LINEAR_DAMPING too high)")
        log("    - Ball mass too high")
        log("    - Distance too far")
    elseif movedCount < 10 then
        log("")
        log("  !!! BREAK DID NOT SCATTER WELL !!!")
        log("  Possible causes:")
        log("    - Restitution too low")
        log("    - Damping too high for scattered balls")
    else
        log("")
        log("  Break shot looks OK!")
    end

    -- Clean up
    for _, ball in pairs(phys.balls) do
        if not ball.body:isDestroyed() then ball.body:destroy() end
    end
    for _, b in ipairs(phys.borders) do b.body:destroy() end
    for _, h in ipairs(phys.holes) do h.body:destroy() end
    phys.world:destroy()

    return table.concat(lines, "\n")
end

return { run = run }

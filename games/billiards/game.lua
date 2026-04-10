-- Game state management and input handling
local Config = require("config")
local Physics = require("physics")
local Cue = require("cue")
local Audio = require("audio")
local Renderer = require("renderer")

local Game = {}

function Game.setupCallbacks(self)
    self.physics.collisionCallbacks.onBallBall = function(idxA, idxB)
        local ballA = self.physics.balls[idxA]
        local ballB = self.physics.balls[idxB]
        if ballA and ballB then
            local vxA, vyA = ballA.body:getLinearVelocity()
            local vxB, vyB = ballB.body:getLinearVelocity()
            local relVel = math.abs(vxA - vxB) + math.abs(vyA - vyB)
            Audio.playBallHit(relVel)

            -- Spin transfer on collision:
            -- The struck ball inherits a fraction of the striking ball's extra spin,
            -- and also gains some roll from the collision impulse direction.
            local transferRate = 0.3  -- 30% spin transfer

            -- Contact direction (from A to B)
            local bxA, byA = ballA.body:getPosition()
            local bxB, byB = ballB.body:getPosition()
            local cdx = bxB - bxA
            local cdy = byB - byA
            local cdist = math.sqrt(cdx * cdx + cdy * cdy)
            if cdist > 0 then
                cdx = cdx / cdist
                cdy = cdy / cdist
            end

            -- Transfer extra spin from A to B
            ballB.extraSpinX = ballB.extraSpinX + ballA.extraSpinX * transferRate
            ballB.extraSpinY = ballB.extraSpinY + ballA.extraSpinY * transferRate
            ballB.extraSpinZ = ballB.extraSpinZ + ballA.extraSpinZ * transferRate

            -- Collision impact also induces some rolling on the struck ball
            -- (the friction at contact point kicks the ball into a spin)
            local impactSpeed = math.sqrt(relVel) * 0.5
            ballB.extraSpinX = ballB.extraSpinX + (-cdy) * impactSpeed
            ballB.extraSpinY = ballB.extraSpinY + cdx * impactSpeed

            -- Reduce striking ball's extra spin (it lost energy)
            ballA.extraSpinX = ballA.extraSpinX * (1 - transferRate)
            ballA.extraSpinY = ballA.extraSpinY * (1 - transferRate)
            ballA.extraSpinZ = ballA.extraSpinZ * (1 - transferRate)
        end
    end

    self.physics.collisionCallbacks.onBallBorder = function(ballIdx)
        local ball = self.physics.balls[ballIdx]
        if ball then
            local vx, vy = ball.body:getLinearVelocity()
            Audio.playBallCollider((math.abs(vx) + math.abs(vy)) * 0.5)
        end
    end

    self.physics.collisionCallbacks.onBallHole = function(ballIdx, holeIdx)
        Game.onBallInHole(self, ballIdx, holeIdx)
    end
end

function Game.init()
    local self = {}

    self.state = Config.STATE_PRACTICE
    self.physics = Physics.init()
    self.cue = Cue.init(self.physics)

    -- Timing
    self.timeSinceShot = 0
    self.isShooting = false
    self.checkStopTimer = 0

    -- White ball dragging
    self.isDraggingWhiteBall = false

    -- Cue rotation state (matches original's began/moved/ended logic)
    self.isDraggingCue = false
    self.cueBeganAngle = 0    -- angle at touch start

    -- Fine tuning panel (left side)
    self.isDraggingFineTune = false
    self.fineTuneLastY = 0
    self.fineTunePanelX = 20
    self.fineTunePanelW = 66
    self.fineTunePanelH = 420
    self.fineTunePanelY = (Config.DESIGN_HEIGHT - 420) / 2

    -- Power bar
    self.isDraggingPower = false
    self.powerPercent = 0

    -- Spin indicator
    self.spinIndicatorX = Config.DESK_OFFSET_X + 50
    self.spinIndicatorY = Config.DESIGN_HEIGHT - 60
    self.isDraggingSpin = false

    -- Pocketed balls (for HUD display)
    self.pocketedBalls = {}

    -- Pocket animations in progress
    self.pocketAnims = {}

    -- Initialize balls
    Physics.createAllBalls(self.physics)
    Game.setupCallbacks(self)

    return self
end

-- Ball pocketing: start animation (matches original 0.5s slide+scale)
function Game.onBallInHole(self, ballIdx, holeIdx)
    local ball = self.physics.balls[ballIdx]
    if not ball or ball.state == Config.BALL_STATE_IN_HOLE then return end

    Audio.playPocket()

    -- Get ball position and hole position
    local bx, by = ball.body:getPosition()
    local hole = self.physics.holes[holeIdx]
    local hx, hy = hole.x, hole.y

    -- Disable physics collision immediately (matches original bitmask 0x04)
    Physics.disableBall(self.physics, ballIdx)
    -- Keep ball at current visual position for animation (don't hide yet)
    ball.body:setPosition(bx, by)
    ball.visible = true

    -- Start pocket animation
    table.insert(self.pocketAnims, {
        ballIdx = ballIdx,
        startX = bx, startY = by,
        targetX = hx, targetY = hy,
        timer = 0,
        duration = 0.5,  -- matches original cc.MoveTo:create(0.5, ...)
        startScale = 1.0,
        endScale = 0.8,   -- matches original cc.ScaleTo:create(0.5, 0.8)
    })

    -- Track pocketed balls
    if ballIdx > 0 then
        table.insert(self.pocketedBalls, ballIdx)
    end
end

function Game.updatePocketAnims(self, dt)
    local i = 1
    while i <= #self.pocketAnims do
        local anim = self.pocketAnims[i]
        anim.timer = anim.timer + dt
        local t = math.min(anim.timer / anim.duration, 1.0)

        local ball = self.physics.balls[anim.ballIdx]
        if ball then
            -- Lerp position toward hole
            local px = anim.startX + (anim.targetX - anim.startX) * t
            local py = anim.startY + (anim.targetY - anim.startY) * t
            ball.body:setPosition(px, py)
            -- Store scale for rendering
            ball._pocketScale = anim.startScale + (anim.endScale - anim.startScale) * t

            if t >= 1.0 then
                -- Animation complete: fully hide ball
                Physics.hideBall(self.physics, anim.ballIdx)
                ball._pocketScale = nil
                table.remove(self.pocketAnims, i)
            else
                i = i + 1
            end
        else
            table.remove(self.pocketAnims, i)
        end
    end
end

function Game.update(self, dt)
    -- Update physics
    Physics.update(self.physics, dt)

    -- Update continuous forces (spin)
    Cue.updateForces(self.physics, dt)

    -- Update pocket animations
    Game.updatePocketAnims(self, dt)

    -- If balls are in motion
    if self.isShooting then
        self.timeSinceShot = self.timeSinceShot + dt

        -- Apply custom damping (throttled to every 10th call, matching original)
        Physics.applyCustomDamping(self.physics, self.timeSinceShot)

        -- Check if all balls have stopped (every 0.1s, matching original)
        self.checkStopTimer = self.checkStopTimer + dt
        if self.checkStopTimer >= Config.CHECK_STOP_INTERVAL then
            self.checkStopTimer = 0

            -- Only consider stopped if no pocket animations in progress
            if #self.pocketAnims == 0 and Physics.areAllBallsStopped(self.physics) then
                Game.onAllBallsStopped(self)
            end
        end
    end

    -- Update power bar visual pull-back
    self.cue.pullBack = self.powerPercent * 1.5
end

function Game.onAllBallsStopped(self)
    self.isShooting = false
    self.timeSinceShot = 0

    Physics.stopAllBalls(self.physics)

    -- Handle white ball in hole
    local whiteBall = self.physics.balls[0]
    if not whiteBall or whiteBall.state == Config.BALL_STATE_IN_HOLE then
        Game.resetWhiteBall(self)
    end

    -- Check if all colored balls are pocketed (practice mode restart)
    local allPocketed = true
    for i = 1, 15 do
        local ball = self.physics.balls[i]
        if ball and ball.state ~= Config.BALL_STATE_IN_HOLE then
            allPocketed = false
            break
        end
    end

    if allPocketed then
        Game.restart(self)
        return
    end

    -- Show cue again
    self.cue.visible = true
    self.cue.shooting = false
    self.cue.power = 0
    self.powerPercent = 0

    Game.autoAimAtNearest(self)
end

function Game.resetWhiteBall(self)
    local wb = self.physics.balls[0]
    if wb then
        wb.state = Config.BALL_STATE_STOP
        wb.visible = true
        wb._pocketScale = nil
        wb.fixture:setCategory(1)
        wb.fixture:setMask(3)

        -- Find a legal position (matches original EBGameControl:dealWhiteBallInHole)
        local deskHalfH = Config.DESK_HEIGHT / 2
        local dx = Config.WHITE_BALL_ORIGINAL_X
        local sx, sy = Physics.deskToScreen(dx, deskHalfH)

        while not Physics.isWhiteBallPositionLegal(self.physics, sx, sy) do
            dx = dx + Config.BALL_RADIUS * 2 + 5
            sx, sy = Physics.deskToScreen(dx, deskHalfH)
        end

        wb.body:setPosition(sx, sy)
        wb.body:setLinearVelocity(0, 0)
        wb.body:setAngularVelocity(0)
    end
end

function Game.autoAimAtNearest(self)
    local wb = self.physics.balls[0]
    if not wb then return end

    local wx, wy = wb.body:getPosition()
    local nearestDist = math.huge
    local nearestBall = nil

    for i = 1, 15 do
        local ball = self.physics.balls[i]
        if ball and ball.state ~= Config.BALL_STATE_IN_HOLE and ball.visible then
            local bx, by = ball.body:getPosition()
            local ddx = bx - wx
            local ddy = by - wy
            local dist = ddx * ddx + ddy * ddy
            if dist < nearestDist then
                nearestDist = dist
                nearestBall = ball
            end
        end
    end

    if nearestBall then
        local bx, by = nearestBall.body:getPosition()
        self.cue.angle = math.atan2(by - wy, bx - wx)
    end
end

function Game.restart(self)
    Physics.resetAllBalls(self.physics)
    self.pocketedBalls = {}
    self.pocketAnims = {}
    self.cue.visible = true
    self.cue.shooting = false
    self.cue.power = 0
    self.cue.spinX = 0
    self.cue.spinY = 0
    self.powerPercent = 0
    self.isShooting = false
    self.timeSinceShot = 0

    Game.setupCallbacks(self)
    Game.autoAimAtNearest(self)
end

-- ==================== Input Handling ====================

function Game.mousepressed(self, x, y, button)
    if button ~= 1 then return end

    -- Determine if click is inside the table playing area
    local dkx, dky = Physics.screenToDesk(x, y)
    local r = Config.BALL_RADIUS
    local isOnTable = dkx > (50) and dkx < (920) and dky > (50) and dky < (500)

    -- UI controls only respond when clicking OUTSIDE the table
    if not isOnTable then
        -- Power bar (vertical: bottom=0%, top=100%)
        local pbx = Config.POWER_BAR_X
        local pby = Config.POWER_BAR_Y
        local pbvw = Config.POWER_BAR_VISUAL_W
        local pbvh = Config.POWER_BAR_VISUAL_H

        if x >= pbx - 10 and x <= pbx + pbvw + 10 and y >= pby - 10 and y <= pby + pbvh + 10 then
            if not self.isShooting then
                self.isDraggingPower = true
                self.powerPercent = math.max(0, math.min(100, (1 - (y - pby) / pbvh) * 100))
                self.cue.power = self.powerPercent
            end
            return
        end

        -- Fine tuning panel (left side)
        if not self.isShooting and
           x >= self.fineTunePanelX and x <= self.fineTunePanelX + self.fineTunePanelW and
           y >= self.fineTunePanelY and y <= self.fineTunePanelY + self.fineTunePanelH then
            self.isDraggingFineTune = true
            self.fineTuneLastY = y
            return
        end

        -- Spin indicator
        local six = self.spinIndicatorX
        local siy = self.spinIndicatorY
        local siRadius = 30
        local sdx = x - six
        local sdy = y - siy
        if sdx * sdx + sdy * sdy <= siRadius * siRadius then
            self.isDraggingSpin = true
            self.cue.spinX = math.max(-1, math.min(1, sdx / (siRadius - 4)))
            self.cue.spinY = math.max(-1, math.min(1, sdy / (siRadius - 4)))
            return
        end
    end

    if self.isShooting then return end

    -- White ball dragging
    local wb = self.physics.balls[0]
    if wb and wb.state ~= Config.BALL_STATE_IN_HOLE then
        local wx, wy = wb.body:getPosition()
        local ddx = x - wx
        local ddy = y - wy
        local hitRadius = Config.BALL_RADIUS * 3
        if ddx * ddx + ddy * ddy <= hitRadius * hitRadius then
            self.isDraggingWhiteBall = true
            self.cue.visible = false
            wb.fixture:setCategory(3)
            wb.fixture:setMask(1, 2, 3)
            return
        end
    end

    -- Cue aiming: quick-click directly aims at cursor position
    -- (matches original's isTouchLayerBegan quick click logic)
    if self.cue.visible and not self.isShooting then
        local wbx, wby = Cue.getWhiteBallPos(self.physics)
        self.cue.angle = math.atan2(y - wby, x - wbx)
        self.isDraggingCue = true
        self.cueBeganAngle = math.atan2(y - wby, x - wbx)
    end
end

function Game.mousereleased(self, x, y, button)
    if button ~= 1 then return end

    if self.isDraggingPower then
        self.isDraggingPower = false
        if self.powerPercent > 1 then
            self.cue.power = self.powerPercent
            local didShoot = Cue.launchBall(self.cue, self.physics)
            if didShoot then
                Audio.playCueHit()
                self.isShooting = true
                self.timeSinceShot = 0
                self.checkStopTimer = 0
                self.physics.dampingCheckCount = 0
                for _, ball in pairs(self.physics.balls) do
                    if ball.state ~= Config.BALL_STATE_IN_HOLE then
                        ball.state = Config.BALL_STATE_RUN
                        ball.body:setLinearDamping(Config.BALL_LINEAR_DAMPING)
                    end
                end
            end
        end
        self.powerPercent = 0
        self.cue.power = 0
        return
    end

    if self.isDraggingSpin then
        self.isDraggingSpin = false
        return
    end

    if self.isDraggingFineTune then
        self.isDraggingFineTune = false
        return
    end

    if self.isDraggingWhiteBall then
        self.isDraggingWhiteBall = false
        local wb = self.physics.balls[0]
        if wb then
            wb.fixture:setCategory(1)
            wb.fixture:setMask(3)
            local wx, wy = wb.body:getPosition()
            if not Physics.isWhiteBallPositionLegal(self.physics, wx, wy) then
                Game.resetWhiteBall(self)
            end
        end
        self.cue.visible = true
        Game.autoAimAtNearest(self)
        return
    end

    self.isDraggingCue = false
end

function Game.mousemoved(self, x, y, dx, dy)
    if self.isDraggingPower then
        local pby = Config.POWER_BAR_Y
        local pbvh = Config.POWER_BAR_VISUAL_H
        -- Vertical: bottom=0%, top=100%
        self.powerPercent = math.max(0, math.min(100, (1 - (y - pby) / pbvh) * 100))
        self.cue.power = self.powerPercent
        return
    end

    if self.isDraggingSpin then
        local six = self.spinIndicatorX
        local siy = self.spinIndicatorY
        local siRadius = 30
        local sdx = x - six
        local sdy = y - siy
        local dist = math.sqrt(sdx * sdx + sdy * sdy)
        if dist > siRadius - 4 then
            sdx = sdx / dist * (siRadius - 4)
            sdy = sdy / dist * (siRadius - 4)
        end
        self.cue.spinX = sdx / (siRadius - 4)
        self.cue.spinY = sdy / (siRadius - 4)
        return
    end

    if self.isDraggingFineTune then
        -- Drag up/down to micro-adjust cue angle (matches original /200 factor)
        local deltaY = y - self.fineTuneLastY
        local angular = deltaY / 200  -- same divisor as original
        if math.abs(angular) <= 0.3 then  -- clamp like original
            self.cue.angle = self.cue.angle + angular
        end
        self.fineTuneLastY = y
        return
    end

    if self.isDraggingWhiteBall then
        local wb = self.physics.balls[0]
        if wb then
            -- Constrain white ball within table bounds while dragging
            local dkx, dky = Physics.screenToDesk(x, y)
            local radius = Config.BALL_RADIUS
            dkx = math.max(60 + radius, math.min(913 - radius, dkx))
            dky = math.max(60 + radius, math.min(489 - radius, dky))
            local cx, cy = Physics.deskToScreen(dkx, dky)
            wb.body:setPosition(cx, cy)
        end
        return
    end

    -- Cue rotation via mouse drag
    if self.isDraggingCue and self.cue.visible and not self.isShooting then
        local wbx, wby = Cue.getWhiteBallPos(self.physics)
        local newAngle = math.atan2(y - wby, x - wbx)
        -- Apply relative delta rotation (matches original's move logic)
        local delta = newAngle - self.cueBeganAngle
        self.cue.angle = self.cue.angle + delta
        self.cueBeganAngle = newAngle
    end
end

function Game.wheelmoved(self, x, y)
    if not self.isShooting then
        self.powerPercent = math.max(0, math.min(100, self.powerPercent + y * 5))
        self.cue.power = self.powerPercent
    end
end

-- ==================== Drawing ====================

function Game.draw(self)
    Renderer.drawTable()

    -- Draw all visible balls (with rolling rotation and pocket animation)
    for idx = 0, 15 do
        local ball = self.physics.balls[idx]
        if ball and ball.visible then
            local bx, by = ball.body:getPosition()
            local scale = ball._pocketScale or 1.0
            Renderer.drawBall(idx, bx, by, ball.rollX, ball.rollY, ball.rollZ, scale)
        end
    end

    -- Aiming line and cue (only when not shooting)
    if not self.isShooting then
        Cue.drawAimingLine(self.cue, self.physics)
        Cue.draw(self.cue, self.physics)
    end

    -- UI elements
    Renderer.drawPowerBar(self.powerPercent, self.isDraggingPower)
    if not self.isShooting then
        Renderer.drawFineTuningPanel(math.deg(self.cue.angle))
    end
    Renderer.drawSpinIndicator(self.cue.spinX, self.cue.spinY,
                                self.spinIndicatorX, self.spinIndicatorY)
    Game.drawPocketedBalls(self)

    -- White ball placement indicator
    if self.isDraggingWhiteBall then
        local wb = self.physics.balls[0]
        if wb then
            local wx, wy = wb.body:getPosition()
            local isLegal = Physics.isWhiteBallPositionLegal(self.physics, wx, wy)
            Renderer.drawPlacementCircle(wx, wy, isLegal)
        end
    end

    Game.drawUI(self)
end

function Game.drawPocketedBalls(self)
    if #self.pocketedBalls == 0 then return end

    local startX = 20
    local startY = 20
    local spacing = Config.BALL_RADIUS * 2 + 4

    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("Pocketed:", startX, startY - 15)

    for i, ballIdx in ipairs(self.pocketedBalls) do
        Renderer.drawBall(ballIdx, startX + (i - 1) * spacing, startY + 10, 0, 0, 0, 0.8)
    end
end

function Game.drawUI(self)
    love.graphics.setColor(1, 1, 1, 0.5)
    local helpY = Config.DESIGN_HEIGHT - 25

    if self.isShooting then
        love.graphics.print("Balls in motion...", Config.DESIGN_WIDTH / 2 - 60, helpY)
    elseif self.isDraggingWhiteBall then
        love.graphics.print("Place the cue ball - release to confirm",
                          Config.DESIGN_WIDTH / 2 - 140, helpY)
    else
        love.graphics.print(
            "Click to aim | Drag power bar to shoot | Drag white ball to reposition | R to restart",
            Config.DESIGN_WIDTH / 2 - 280, helpY)
    end

    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.print("FPS: " .. love.timer.getFPS(), Config.DESIGN_WIDTH - 80, 10)
end

function Game.keypressed(self, key)
    if key == "r" then
        Game.restart(self)
    elseif key == "escape" then
        love.event.quit()
    end
end

return Game

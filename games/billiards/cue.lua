-- Cue stick module - aiming, rotation, power, shot mechanics
local Config = require("config")

local Cue = {}

function Cue.init(physics)
    local self = {}
    self.angle = 0          -- radians, 0 = pointing right (shot direction)
    self.power = 0          -- 0-100 percent
    self.visible = true
    self.shooting = false
    self.spinX = 0          -- left/right english (-1 to 1)
    self.spinY = 0          -- follow/draw (-1 to 1)
    self.pullBack = 0       -- visual pull-back for power
    return self
end

function Cue.getWhiteBallPos(physics)
    local wb = physics.balls[0]
    if not wb then return 0, 0 end
    return wb.body:getPosition()
end

-- Draw the cue stick
function Cue.draw(self, physics)
    if not self.visible then return end

    local Atlas = require("atlas")
    local wx, wy = Cue.getWhiteBallPos(physics)
    local angle = self.angle
    local gapFromBall = Config.BALL_RADIUS + 4 + self.pullBack

    if Atlas.isLoaded() and Atlas.getFrame("eightBall_Cue") then
        -- Original cue: anchor (1, 0.5) = right edge = tip (near ball).
        -- Sprite body extends in local -X from anchor (tip toward butt).
        -- 
        -- angle = shot direction (toward the ball).
        -- We want the tip near the ball, butt extending AWAY from ball (opposite of angle).
        -- 
        -- After love.graphics.draw rotation r, local -X maps to world direction (r + pi).
        -- We want local -X (tip-to-butt) to point in direction (angle + pi) (away from ball).
        -- So: r + pi = angle + pi  =>  r = angle
        --
        -- Tip position: offset from ball center in the OPPOSITE direction of shot.
        local tipX = wx - math.cos(angle) * gapFromBall
        local tipY = wy - math.sin(angle) * gapFromBall

        love.graphics.setColor(1, 1, 1, 1)
        Atlas.draw("eightBall_Cue", tipX, tipY, angle, 1, 1, 1, 0.5)
    else
        -- Fallback: procedural cue
        local dirX = math.cos(angle)
        local dirY = math.sin(angle)
        local cueLength = 300
        local startX = wx - dirX * gapFromBall
        local startY = wy - dirY * gapFromBall
        local endX = startX - dirX * cueLength
        local endY = startY - dirY * cueLength

        love.graphics.setLineWidth(5)
        love.graphics.setColor(0.55, 0.35, 0.15, 1)
        love.graphics.line(startX, startY, endX, endY)

        local tipLen = 8
        love.graphics.setColor(0.85, 0.80, 0.65, 1)
        love.graphics.line(startX, startY, startX - dirX * tipLen, startY - dirY * tipLen)

        local buttLen = 60
        love.graphics.setColor(0.30, 0.18, 0.08, 1)
        love.graphics.line(endX + dirX * buttLen, endY + dirY * buttLen, endX, endY)
        love.graphics.setLineWidth(1)
    end
end

-- Draw the aiming line with route detection
function Cue.drawAimingLine(self, physics)
    if not self.visible then return end

    local wx, wy = Cue.getWhiteBallPos(physics)
    local angle = self.angle
    local r = Config.BALL_RADIUS
    local dirX = math.cos(angle)
    local dirY = math.sin(angle)

    local startX = wx + dirX * (r + 2)
    local startY = wy + dirY * (r + 2)

    -- Find nearest ball in aiming path
    local nearestBall = nil
    local nearestDist = math.huge
    local nearestPerpDist = 0

    for i = 1, 15 do
        local ball = physics.balls[i]
        if ball and ball.state ~= Config.BALL_STATE_IN_HOLE and ball.visible then
            local bx, by = ball.body:getPosition()
            local dx = bx - wx
            local dy = by - wy
            local proj = dx * dirX + dy * dirY
            if proj > 0 then
                local perpDist = math.abs(dx * (-dirY) + dy * dirX)
                if perpDist < 2 * r then
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < nearestDist then
                        nearestDist = dist
                        nearestBall = ball
                        nearestPerpDist = perpDist
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setLineWidth(1)

    if nearestBall then
        local bx, by = nearestBall.body:getPosition()
        local dx = bx - wx
        local dy = by - wy
        local proj = dx * dirX + dy * dirY
        local offset = math.sqrt(math.max(0, 4 * r * r - nearestPerpDist * nearestPerpDist))
        local hitDist = proj - offset

        local endAimX = wx + dirX * hitDist
        local endAimY = wy + dirY * hitDist
        Cue.drawDottedLine(startX, startY, endAimX, endAimY, 8, 6)

        -- Ghost ball at collision point
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle("line", endAimX, endAimY, r)

        -- Deflection lines
        local toBallX = bx - endAimX
        local toBallY = by - endAimY
        local toBallLen = math.sqrt(toBallX * toBallX + toBallY * toBallY)
        if toBallLen > 0 then
            toBallX = toBallX / toBallLen
            toBallY = toBallY / toBallLen
        end

        -- Target ball direction
        local lineLen = 50
        love.graphics.setColor(1, 1, 0, 0.4)
        Cue.drawDottedLine(bx, by, bx + toBallX * lineLen, by + toBallY * lineLen, 6, 4)

        -- White ball deflection
        local deflX = dirX - (dirX * toBallX + dirY * toBallY) * toBallX
        local deflY = dirY - (dirX * toBallX + dirY * toBallY) * toBallY
        local deflLen = math.sqrt(deflX * deflX + deflY * deflY)
        if deflLen > 0.01 then
            deflX = deflX / deflLen
            deflY = deflY / deflLen
            love.graphics.setColor(1, 1, 1, 0.3)
            Cue.drawDottedLine(endAimX, endAimY,
                endAimX + deflX * lineLen, endAimY + deflY * lineLen, 6, 4)
        end
    else
        -- No ball hit: extend to border
        local maxDist = Cue.getDistanceToBorder(wx, wy, dirX, dirY)
        local endAimX = wx + dirX * maxDist
        local endAimY = wy + dirY * maxDist
        Cue.drawDottedLine(startX, startY, endAimX, endAimY, 8, 6)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle("line", endAimX, endAimY, r)
    end
end

function Cue.drawDottedLine(x1, y1, x2, y2, dashLen, gapLen)
    local dx = x2 - x1
    local dy = y2 - y1
    local totalLen = math.sqrt(dx * dx + dy * dy)
    if totalLen < 1 then return end
    local ndx = dx / totalLen
    local ndy = dy / totalLen
    local pos = 0
    local drawing = true
    while pos < totalLen do
        local segLen = drawing and dashLen or gapLen
        local endPos = math.min(pos + segLen, totalLen)
        if drawing then
            love.graphics.line(x1 + ndx * pos, y1 + ndy * pos,
                               x1 + ndx * endPos, y1 + ndy * endPos)
        end
        pos = endPos
        drawing = not drawing
    end
end

function Cue.getDistanceToBorder(px, py, dirX, dirY)
    local Physics = require("physics")
    local borders = {}
    for _, seg in ipairs(Config.INNER_BORDERS) do
        local x1, y1 = Physics.deskToScreen(seg[1][1], seg[1][2])
        local x2, y2 = Physics.deskToScreen(seg[2][1], seg[2][2])
        table.insert(borders, {x1, y1, x2, y2})
    end

    local minDist = 2000
    local r = Config.BALL_RADIUS

    for _, b in ipairs(borders) do
        local x1, y1, x2, y2 = b[1], b[2], b[3], b[4]
        local ex = x2 - x1
        local ey = y2 - y1
        local denom = dirX * ey - dirY * ex
        if math.abs(denom) > 0.001 then
            local t = ((x1 - px) * ey - (y1 - py) * ex) / denom
            local u = ((x1 - px) * dirY - (y1 - py) * dirX) / denom
            if t > r and u >= 0 and u <= 1 then
                if t < minDist then
                    minDist = t - r
                end
            end
        end
    end
    return math.max(0, minDist)
end

-- Launch the white ball
-- Original impulse = diffXY * lineSpeedRatio * forcePercent
--   where |diffXY| = CUE_DISTANCE (~336px, from cue marker to ball center)
--   with mass = density * pi * r^2 = 2.7 * pi * 225 = ~1908.5
-- So: velocity = (336 * 16000 * fp) / 1908.5 = ~2817 * fp px/s at full power
function Cue.launchBall(self, physics)
    local wb = physics.balls[0]
    if not wb then return end

    local forcePercent = self.power / 100
    if forcePercent <= 0 then return end

    local dirX = math.cos(self.angle)
    local dirY = math.sin(self.angle)

    -- Impulse scaled by CUE_DISTANCE to match original's non-unit direction vector
    local impulseScale = Config.CUE_DISTANCE * Config.LINE_SPEED_RATIO * forcePercent
    local impulseX = dirX * impulseScale
    local impulseY = dirY * impulseScale
    wb.body:applyLinearImpulse(impulseX, impulseY)

    -- Side spin (angular velocity)
    wb.body:setAngularVelocity(Config.LEFT_RIGHT_FORCE_RATIO * self.spinX)

    -- Top/back spin (continuous force, cleared after 0.5s)
    local forceScale = Config.CUE_DISTANCE * Config.ROTATE_FORCE_RATIO * forcePercent
    local forceX = dirX * forceScale * self.spinY
    local forceY = dirY * forceScale * self.spinY
    wb._continuousForce = {x = forceX, y = forceY, timer = 0.5}

    -- === Visual extra spin from cue spin parameters ===
    -- spinY > 0: high (follow/top spin) -> extra forward roll
    -- spinY < 0: low (draw/back spin) -> extra backward roll (opposite to movement)
    -- spinX: side english -> extra Z-axis spin
    local spinStrength = forcePercent * 25  -- base spin angular velocity (rad/s)

    -- High/low spin: adds/subtracts rotation along the movement direction.
    -- The forward roll axis depends on shot direction:
    --   Shot along X -> forward roll is around rollX (perpendicular)
    --   Shot along Y -> forward roll is around rollY
    -- We decompose by shot direction:
    wb.extraSpinX = -dirY * self.spinY * spinStrength  -- vy component of forward roll
    wb.extraSpinY =  dirX * self.spinY * spinStrength  -- vx component of forward roll

    -- Side english: Z-axis spin
    wb.extraSpinZ = self.spinX * spinStrength * 1.5

    -- Set state
    wb.state = Config.BALL_STATE_RUN
    self.visible = false
    self.power = 0
    self.pullBack = 0
    self.shooting = true

    return true
end

-- Update continuous forces on white ball
function Cue.updateForces(physics, dt)
    local wb = physics.balls[0]
    if wb and wb._continuousForce then
        wb._continuousForce.timer = wb._continuousForce.timer - dt
        if wb._continuousForce.timer <= 0 then
            wb._continuousForce = nil
        else
            wb.body:applyForce(wb._continuousForce.x, wb._continuousForce.y)
        end
    end
end

return Cue

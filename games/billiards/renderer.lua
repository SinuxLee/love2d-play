-- Renderer module - draws table, balls, power bar, spin indicator using original assets
local Config = require("config")
local Atlas = require("atlas")
local BallShader = require("ballshader")
local Renderer = {}

-- Loaded images
local deskImage = nil
local bgImage = nil
local ballImages = {}    -- index 0-15: loaded from images/balls/*.png or atlas
local shadowFrame = nil  -- from atlas: eightBall_Ball_Shadow
local highlightFrame = nil -- from atlas: eightBall_Ball_HighLight
local spinBgFrame = nil
local spinDotFrame = nil
local placementCircleFrame = nil
local atlasLoaded = false
local font = nil

-- Standalone slider images (loaded directly, not from atlas)
local sliderBgImg = nil      -- 415x82, horizontal track background
local sliderPowerImg = nil   -- 415x82, horizontal fill (same size, clipped left->right)
local sliderCueBarImg = nil  -- 1350x30, knob (cue stick image)

-- Ball UV textures for 3D sphere shader (120x60 equirectangular maps)
local ballUVTextures = {}
local shaderAvailable = false

function Renderer.init()
    font = love.graphics.newFont(11)

    -- Load atlas
    atlasLoaded = Atlas.init()

    -- Load desk image
    local ok
    ok, deskImage = pcall(love.graphics.newImage, "images/eightBall_DeskImage.png")
    if not ok then deskImage = nil end

    -- Load background image
    ok, bgImage = pcall(love.graphics.newImage, "images/eightBall_Background_Main.png")
    if not ok then bgImage = nil end

    -- Load ball images from 3d_ball UV textures (120x60 equirectangular maps)
    for i = 0, 15 do
        local imgOk, img = pcall(love.graphics.newImage, "images/balls/" .. i .. ".png")
        if imgOk then
            img:setFilter("linear", "linear")
            img:setWrap("repeat", "clamp")
            ballUVTextures[i] = img
        end
    end

    -- Initialize sphere projection shader
    local shaderOk, _ = pcall(BallShader.init)
    shaderAvailable = shaderOk and BallShader.isAvailable() and next(ballUVTextures) ~= nil

    -- Load standalone slider images
    ok, sliderBgImg = pcall(love.graphics.newImage, "images/eightBall_Sliderbar_Bg.png")
    if not ok then sliderBgImg = nil end
    ok, sliderPowerImg = pcall(love.graphics.newImage, "images/eightBall_SliderBar_Power.png")
    if not ok then sliderPowerImg = nil end
    ok, sliderCueBarImg = pcall(love.graphics.newImage, "images/eightBall_Cue_bar.png")
    if not ok then sliderCueBarImg = nil end

    -- Cache atlas frame references
    if atlasLoaded then
        shadowFrame = Atlas.getFrame("eightBall_Ball_Shadow")
        highlightFrame = Atlas.getFrame("eightBall_Ball_HighLight")
        spinBgFrame = Atlas.getFrame("eightBall_HighLowPole_Bg")
        spinDotFrame = Atlas.getFrame("eightBall_HighLowPole_RedPint")
        placementCircleFrame = Atlas.getFrame("eightBall_WhiteBall_BigCircle")
    end
end

-- ==================== Ball Drawing ====================

function Renderer.drawBall(index, x, y, rollX, rollY, rollZ, scale)
    scale = scale or 1.0
    rollX = rollX or 0
    rollY = rollY or 0
    rollZ = rollZ or 0
    local r = Config.BALL_RADIUS

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.circle("fill", x + 2, y + 3, r * scale)

    -- Prefer sphere shader with UV textures for realistic rolling
    if shaderAvailable and ballUVTextures[index] then
        BallShader.drawBall(ballUVTextures[index], x, y, rollX, rollY, rollZ, scale, r)
    elseif atlasLoaded and Atlas.getFrame("ball_" .. index) then
        -- Fallback: static atlas sprite (no rolling)
        local frameName = "ball_" .. index
        local ballScale = (r * 2 * scale) / 50
        love.graphics.setColor(1, 1, 1, 1)
        Atlas.draw(frameName, x, y, 0, ballScale, ballScale)
    else
        Renderer.drawBallProcedural(index, x, y, 0, scale)
    end
end

-- Procedural ball drawing fallback (used when no assets available)
function Renderer.drawBallProcedural(index, x, y, angle, scale)
    local r = Config.BALL_RADIUS
    scale = scale or 1.0
    local color = Config.BALL_COLORS[index]
    if not color then return end

    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.circle("fill", x, y, r * scale)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.circle("fill", x - r * 0.25 * scale, y - r * 0.25 * scale, r * 0.35 * scale)
end

-- ==================== Table Drawing ====================

function Renderer.drawBackground()
    if bgImage then
        local ww = Config.DESIGN_WIDTH
        local wh = Config.DESIGN_HEIGHT
        local imgW, imgH = bgImage:getDimensions()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgImage, 0, 0, 0, ww / imgW, wh / imgH)
    else
        love.graphics.setColor(0.12, 0.12, 0.15, 1)
        love.graphics.rectangle("fill", 0, 0, Config.DESIGN_WIDTH, Config.DESIGN_HEIGHT)
    end
end

function Renderer.drawTable()
    local ox = Config.DESK_OFFSET_X
    local oy = Config.DESK_OFFSET_Y
    local dw = Config.DESK_WIDTH
    local dh = Config.DESK_HEIGHT

    -- Draw background first
    Renderer.drawBackground()

    if deskImage then
        -- Use actual desk texture
        local imgW, imgH = deskImage:getDimensions()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(deskImage, ox, oy, 0, dw / imgW, dh / imgH)
    else
        -- Fallback: procedural table
        -- Outer frame (wood)
        love.graphics.setColor(0.35, 0.20, 0.08, 1)
        love.graphics.rectangle("fill", ox - 30, oy - 30, dw + 60, dh + 60, 8, 8)

        -- Inner rail
        love.graphics.setColor(0.45, 0.28, 0.12, 1)
        love.graphics.rectangle("fill", ox - 10, oy - 10, dw + 20, dh + 20, 4, 4)

        -- Playing surface
        love.graphics.setColor(0.0, 0.5, 0.25, 1)
        love.graphics.rectangle("fill", ox, oy, dw, dh)

        local function dts(dx, dy)
            return dx + ox, (Config.DESK_HEIGHT - dy) + oy
        end

        -- Inner border lines
        love.graphics.setColor(0.0, 0.40, 0.20, 1)
        love.graphics.setLineWidth(3)
        for _, seg in ipairs(Config.INNER_BORDERS) do
            local x1, y1 = dts(seg[1][1], seg[1][2])
            local x2, y2 = dts(seg[2][1], seg[2][2])
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setLineWidth(1)

        -- Pockets
        for _, hole in ipairs(Config.HOLE_POSITIONS) do
            local hx, hy = dts(hole.x, hole.y)
            love.graphics.setColor(0.05, 0.05, 0.05, 1)
            love.graphics.circle("fill", hx, hy, Config.BALL_RADIUS * 1.4)
            love.graphics.setColor(0.02, 0.02, 0.02, 1)
            love.graphics.circle("fill", hx, hy, Config.BALL_RADIUS * 1.1)
        end

        -- Head string line
        local headX, _ = dts(Config.WHITE_BALL_ORIGINAL_X + 3.5, 0)
        local _, topY = dts(0, Config.TABLE_INNER_BOTTOM)
        local _, botY = dts(0, Config.TABLE_INNER_TOP)
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.line(headX, topY, headX, botY)

        -- Foot spot
        local spotX, spotY = dts(Config.RACK_START_X, Config.DESK_HEIGHT / 2)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.circle("fill", spotX, spotY, 3)
    end
end

-- ==================== White Ball Placement Circle ====================

function Renderer.drawPlacementCircle(x, y, isLegal)
    if placementCircleFrame and atlasLoaded then
        local s = (Config.BALL_RADIUS * 2 * 2.5) / placementCircleFrame.sourceW
        if isLegal then
            love.graphics.setColor(1, 1, 1, 0.5)
        else
            love.graphics.setColor(1, 0.3, 0.3, 0.5)
        end
        Atlas.draw("eightBall_WhiteBall_BigCircle", x, y, 0, s, s)
    else
        love.graphics.setColor(isLegal and {0, 1, 0, 0.3} or {1, 0, 0, 0.3})
        love.graphics.circle("line", x, y, Config.BALL_RADIUS * 2)
    end
end

-- ==================== Power Bar (Right Side) ====================

function Renderer.drawPowerBar(powerPercent, isActive)
    local pbx = Config.POWER_BAR_X
    local pby = Config.POWER_BAR_Y
    local vw = Config.POWER_BAR_VISUAL_W   -- 82 (visual width after rotation)
    local vh = Config.POWER_BAR_VISUAL_H   -- 415 (visual height after rotation)

    -- Rotation pivot: we rotate the horizontal assets 90deg CW around the
    -- center of the visual rectangle, so bottom=0%, top=100%.
    -- The center of the visual area:
    local cx = pbx + vw / 2
    local cy = pby + vh / 2

    if sliderBgImg and sliderPowerImg then
        local imgW = sliderBgImg:getWidth()   -- 415
        local imgH = sliderBgImg:getHeight()  -- 82

        -- Background: draw the 415x82 image rotated -90deg (CCW) at center.
        -- CCW rotation: left edge -> bottom, right edge -> top.
        -- So the slider's 0% (left) is at bottom, 100% (right) is at top.
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sliderBgImg, cx, cy, -math.pi / 2, 1, 1, imgW / 2, imgH / 2)

        -- Power fill: clip left portion of fill image, draw with same -90deg rotation.
        -- Left of horizontal -> bottom of vertical. Fill grows upward.
        if powerPercent > 0 then
            local frac = math.min(powerPercent / 100, 1)
            local pImgW = sliderPowerImg:getWidth()
            local pImgH = sliderPowerImg:getHeight()
            local clipW = math.max(1, math.floor(pImgW * frac))

            local fillQuad = love.graphics.newQuad(0, 0, clipW, pImgH, pImgW, pImgH)

            -- After -90deg rotation, the clipped rect (clipW x pImgH) becomes
            -- pImgH wide x clipW tall, with the original left edge at bottom.
            -- Position: bottom of bar, anchor at (0, pImgH/2) for X centering.
            local fillBottom = cy + vh / 2
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sliderPowerImg, fillQuad, cx, fillBottom,
                -math.pi / 2, 1, 1, 0, pImgH / 2)
        end

        -- Knob (cue bar): 1350x30 image, rotated -90deg as a horizontal indicator.
        -- Original uses ClipAble panel (84px wide) to clip the 1350px cue image,
        -- so only a small cross-section is visible within the bar.
        -- We clip by drawing only the rightmost portion of the image that fits
        -- within the bar's visual height (vh) after rotation.
        if sliderCueBarImg then
            local cueW = sliderCueBarImg:getWidth()   -- 1350
            local cueH = sliderCueBarImg:getHeight()  -- 30
            local knobY = pby + vh * (1 - powerPercent / 100)

            -- After -90deg rotation, the cue's width (1350) becomes vertical span.
            -- We only want vh (415) pixels of it to show, anchored at the right end.
            -- Clip: take the rightmost vh-worth-of-pixels from the image.
            local s = vw / cueH  -- scale so 30px height -> vw (82px) visual width
            local visibleW = vh / s  -- how many source pixels fit in vh visual height
            local clipX = math.max(0, cueW - visibleW)
            local clipW = cueW - clipX

            local knobQuad = love.graphics.newQuad(clipX, 0, clipW, cueH, cueW, cueH)

            love.graphics.setColor(1, 1, 1, 1)
            -- Draw clipped cue at knob position, rotated -90deg.
            -- Anchor at (clipW, cueH/2) = right-center of the clipped region.
            love.graphics.draw(sliderCueBarImg, knobQuad, cx, knobY, -math.pi / 2,
                s, s, clipW, cueH / 2)
        end
    else
        -- Fallback: procedural vertical power bar
        love.graphics.setColor(0.15, 0.15, 0.15, 0.8)
        love.graphics.rectangle("fill", pbx, pby, vw, vh, 4, 4)
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.rectangle("line", pbx, pby, vw, vh, 4, 4)
        if powerPercent > 0 then
            local fillH = vh * powerPercent / 100
            local r = math.min(1, powerPercent / 50)
            local g = math.min(1, (100 - powerPercent) / 50)
            love.graphics.setColor(r, g, 0, 0.9)
            love.graphics.rectangle("fill", pbx + 2, pby + vh - fillH, vw - 4, fillH - 2, 2, 2)
        end
        local knobY = pby + vh * (1 - powerPercent / 100)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", pbx - 4, knobY - 6, vw + 8, 12, 3, 3)
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("line", pbx - 4, knobY - 6, vw + 8, 12, 3, 3)
    end

    -- Power percentage label
    love.graphics.setColor(1, 1, 1, 0.8)
    local label = string.format("%d%%", math.floor(powerPercent))
    local fw = love.graphics.getFont():getWidth(label)
    love.graphics.print(label, pbx + vw / 2 - fw / 2, pby + vh + 8)
end

-- ==================== Fine Tuning Panel (Left Side) ====================

function Renderer.drawFineTuningPanel(cueAngleDeg)
    -- Position: left side of screen, vertically centered
    local panelX = 20
    local panelH = 420
    local panelY = (Config.DESIGN_HEIGHT - panelH) / 2

    if atlasLoaded and Atlas.getFrame("eightBall_FineTurning_Back2") then
        local bgFrame = Atlas.getFrame("eightBall_FineTurning_Back2")
        local bgW = bgFrame.sourceW  -- 66
        local cx = panelX + bgW / 2
        local cy = Config.DESIGN_HEIGHT / 2
        local scaleY = panelH / bgFrame.sourceH

        -- Background frame
        love.graphics.setColor(1, 1, 1, 0.9)
        Atlas.draw("eightBall_FineTurning_Back2", cx, cy, 0, 1, scaleY)

        -- Scale strip: clip to within the background frame using stencil
        local scaleFrame = Atlas.getFrame("eightBall_FineTurning_Scale")
        if scaleFrame then
            local clipX = panelX + 8
            local clipY = panelY + 8
            local clipW = bgW - 16
            local clipH = panelH - 16

            -- Set stencil to the clipping rectangle
            love.graphics.stencil(function()
                love.graphics.rectangle("fill", clipX, clipY, clipW, clipH)
            end, "replace", 1)
            love.graphics.setStencilTest("greater", 0)

            -- Draw scrolling scale strip
            local angleOffset = (cueAngleDeg or 0) * 2
            local stripScaleY = panelH / scaleFrame.sourceH * 2
            love.graphics.setColor(1, 1, 1, 0.6)
            Atlas.draw("eightBall_FineTurning_Scale", cx, cy + angleOffset, 0, 1, stripScaleY)

            love.graphics.setStencilTest()
        end

        -- Center pointer/tag (fixed at vertical center, right edge of panel)
        local tagFrame = Atlas.getFrame("eightBall_FineTurning_Tag")
        if tagFrame then
            love.graphics.setColor(1, 1, 1, 1)
            Atlas.draw("eightBall_FineTurning_Tag", panelX + bgW - 2, cy, 0, 1, 1)
        end
    else
        -- Fallback: procedural fine tuning panel
        local panelW = 40
        love.graphics.setColor(0.15, 0.15, 0.15, 0.7)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 4, 4)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 4, 4)

        -- Scale markings
        love.graphics.setColor(1, 1, 1, 0.3)
        for i = 0, 20 do
            local my = panelY + (panelH / 20) * i
            local mw = (i % 5 == 0) and panelW * 0.6 or panelW * 0.3
            love.graphics.line(panelX + (panelW - mw) / 2, my, panelX + (panelW + mw) / 2, my)
        end

        -- Center marker
        love.graphics.setColor(1, 0.3, 0.3, 0.8)
        local cy = panelY + panelH / 2
        love.graphics.polygon("fill", panelX + panelW, cy, panelX + panelW + 8, cy - 5, panelX + panelW + 8, cy + 5)
    end

    -- Label
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("Fine\nTune", panelX, panelY - 30, 50, "center")
end

-- ==================== Spin Indicator ====================

function Renderer.drawSpinIndicator(spinX, spinY, ix, iy)
    local radius = 30

    if atlasLoaded and Atlas.getFrame("eightBall_Small_Whiteball") then
        -- Use original small white ball + red point sprites
        local wbFrame = Atlas.getFrame("eightBall_Small_Whiteball")
        local s = (radius * 2) / wbFrame.sourceW
        -- Background
        if spinBgFrame then
            local bgS = (radius * 2 + 10) / spinBgFrame.sourceW
            love.graphics.setColor(1, 1, 1, 0.9)
            Atlas.draw("eightBall_HighLowPole_Bg", ix, iy, 0, bgS, bgS)
        end
        -- White ball
        love.graphics.setColor(1, 1, 1, 1)
        Atlas.draw("eightBall_Small_Whiteball", ix, iy, 0, s, s)

        -- Red point
        local dotX = ix + spinX * (radius - 4)
        local dotY = iy + spinY * (radius - 4)
        love.graphics.setColor(1, 1, 1, 1)
        Atlas.draw("eightBall_Small_RedPoint", dotX, dotY, 0, 1, 1)
    elseif spinBgFrame and atlasLoaded then
        -- Fallback to old spin bg + procedural dot
        local s = (radius * 2) / spinBgFrame.sourceW
        love.graphics.setColor(1, 1, 1, 0.9)
        Atlas.draw("eightBall_HighLowPole_Bg", ix, iy, 0, s, s)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.line(ix - radius, iy, ix + radius, iy)
        love.graphics.line(ix, iy - radius, ix, iy + radius)
        local dotX = ix + spinX * (radius - 4)
        local dotY = iy + spinY * (radius - 4)
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.circle("fill", dotX, dotY, 5)
    else
        -- Full procedural fallback
        love.graphics.setColor(0.15, 0.15, 0.15, 0.8)
        love.graphics.circle("fill", ix, iy, radius)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("line", ix, iy, radius)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.line(ix - radius, iy, ix + radius, iy)
        love.graphics.line(ix, iy - radius, ix, iy + radius)
        local dotX = ix + spinX * (radius - 4)
        local dotY = iy + spinY * (radius - 4)
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.circle("fill", dotX, dotY, 5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("line", dotX, dotY, 5)
    end
end

return Renderer

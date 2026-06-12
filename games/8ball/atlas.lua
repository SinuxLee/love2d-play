-- Atlas sprite frame loader for EightBall.plist
-- Pre-defines quad coordinates for extracting sprites from the atlas PNG.
local Atlas = {}

local atlasImage = nil
local frames = {}  -- name -> {quad, sourceW, sourceH, offsetX, offsetY}

-- Sprite frame definitions extracted from EightBall.plist
-- Format: {name, x, y, w, h, offsetX, offsetY, rotated, sourceW, sourceH}
local frameDefs = {
    -- Cue & aiming
    {"eightBall_Cue",               1,   885, 642,  30, -15, 0, false, 672,  30},
    {"eightBall_DrawLine",          1,   917, 864,   7,   0, 0, false, 864,   7},
    {"eightBall_DrawCircle",       986,  933,  30,  30,   0, 0, false,  30,  30},
    {"eightBall_DrawCircle_Red",   792,  388,  41,  41,   0, 0, false,  41,  41},
    {"eightBall_DrawCircle_Shadow",792,  431,  41,  41,   0, 0, false,  41,  41},

    -- Ball effects
    {"eightBall_Ball_HighLight",     1,  649,  50,  50,   0, 0, false,  50,  50},
    {"eightBall_Ball_Shadow",      608,  516,  76,  76,   0, 0, false,  80,  80},

    -- Spin indicator
    {"eightBall_HighLowPole_Bg",   608,  388,  73,  74,   0, 0, false,  73,  74},
    {"eightBall_HighLowPole_RedPint",608, 756,  45,  45,   0, 0, false,  45,  45},
    {"eightBall_Small_Whiteball",  686,  578,  60,  60,   0, 0, false,  60,  60},
    {"eightBall_Small_RedPoint",   978,  418,  10,  10,   0, 0, false,  10,  10},

    -- White ball placement
    {"eightBall_WhiteBall_BigCircle",431, 987, 124, 124,   0, 0, false, 124, 124},

    -- Power bar / slider
    {"eightBall_Sliderbar_Bg",     910,    1,  82, 415,   0, 0, false,  82, 415},
    {"eightBall_SliderBar_Cue",      1, 1173,  25, 349,   0, 0, true,   25, 349},
    {"eightBall_SliderBar_Power",  390,  441, 360,  39,   0, 0, true,  360,  39},
    {"eightBall_PowerView",        834,  500, 317,  44,   0, 2, true,  331,  59},
    {"eightBall_PowerView_Back",   431,  926, 331,  59,   0, 0, false, 331,  59},
    {"eightBall_Needle_Deal",      645,  885, 310,  27,   0, 0, false, 310,  27},

    -- Fine tuning
    {"eightBall_FineTurning_Back2",910,  418,  66, 465,   0, 0, false,  66, 465},
    {"eightBall_FineTurningBg",    352, 1149,  43, 423,   0, 0, true,   43, 423},
    {"eightBall_FineTurning_Scale",994,    1,  27, 930,   0, 0, false,  27, 930},
    {"eightBall_FineTurning_Tag",  936,  914,  24,  16,   0, 0, true,   24,  16},

    -- 2D ball sprites
    {"ball_0",  608, 464, 50, 50, 0, 0, false, 50, 50},
    {"ball_1",  660, 464, 50, 50, 0, 0, false, 50, 50},
    {"ball_2",  770, 648, 50, 50, 0, 0, false, 50, 50},
    {"ball_3",  660, 744, 50, 50, 0, 0, false, 50, 50},
    {"ball_4",  712, 700, 50, 50, 0, 0, false, 50, 50},
    {"ball_5",  764, 700, 50, 50, 0, 0, false, 50, 50},
    {"ball_6",    1, 441, 50, 50, 0, 0, false, 50, 50},
    {"ball_7",    1, 493, 50, 50, 0, 0, false, 50, 50},
    {"ball_8",    1, 545, 50, 50, 0, 0, false, 50, 50},
    {"ball_9",    1, 597, 50, 50, 0, 0, false, 50, 50},
    {"ball_10", 748, 596, 50, 50, 0, 0, false, 50, 50},
    {"ball_11", 666, 640, 50, 50, 0, 0, false, 50, 50},
    {"ball_12", 608, 652, 50, 50, 0, 0, false, 50, 50},
    {"ball_13", 718, 648, 50, 50, 0, 0, false, 50, 50},
    {"ball_14", 660, 692, 50, 50, 0, 0, false, 50, 50},
    {"ball_15", 608, 704, 50, 50, 0, 0, false, 50, 50},
}

function Atlas.init()
    local ok, img = pcall(love.graphics.newImage, "images/atlas/EightBall.png")
    if not ok then
        print("Warning: Could not load atlas EightBall.png")
        return false
    end
    atlasImage = img
    atlasImage:setFilter("linear", "linear")

    local imgW, imgH = atlasImage:getDimensions()

    for _, def in ipairs(frameDefs) do
        local name = def[1]
        local fx, fy, fw, fh = def[2], def[3], def[4], def[5]
        local ox, oy = def[6], def[7]
        local rotated = def[8]
        local sw, sh = def[9], def[10]

        local quad
        if rotated then
            -- Rotated sprites: stored 90deg CW in atlas, so atlas region is (fw x fh) but
            -- the actual sprite dimensions are (fh x fw) when de-rotated.
            -- In the atlas the width/height of the region are swapped.
            quad = love.graphics.newQuad(fx, fy, fh, fw, imgW, imgH)
        else
            quad = love.graphics.newQuad(fx, fy, fw, fh, imgW, imgH)
        end

        frames[name] = {
            quad = quad,
            sourceW = sw,
            sourceH = sh,
            frameW = fw,
            frameH = fh,
            offsetX = ox,
            offsetY = oy,
            rotated = rotated,
        }
    end

    return true
end

function Atlas.getImage()
    return atlasImage
end

function Atlas.getFrame(name)
    return frames[name]
end

-- Draw a sprite frame at (x, y) with optional rotation, scaleX, scaleY
-- anchorX/anchorY are 0-1 relative to the ORIGINAL sourceSize (0=left/top, 0.5=center, 1=right/bottom)
-- This accounts for trim offset so anchors are consistent with cocos2d behavior.
function Atlas.draw(name, x, y, rotation, scaleX, scaleY, anchorX, anchorY)
    local f = frames[name]
    if not f or not atlasImage then return false end

    rotation = rotation or 0
    scaleX = scaleX or 1
    scaleY = scaleY or 1
    anchorX = anchorX or 0.5
    anchorY = anchorY or 0.5

    -- Compute anchor in source space, then convert to frame (trimmed) space.
    -- In cocos2d plist format 2, offset = (trimmedCenter - sourceCenter).
    -- So the trimmed frame's top-left in source space is:
    --   frameOriginInSource.x = (sourceW - frameW) / 2 + offsetX
    --   frameOriginInSource.y = (sourceH - frameH) / 2 - offsetY  (Y flipped in cocos)
    -- The anchor point in source space:
    --   anchorInSource.x = anchorX * sourceW
    -- The anchor relative to the trimmed frame:
    --   ox = anchorInSource.x - frameOriginInSource.x

    local srcAnchorX = anchorX * f.sourceW
    local srcAnchorY = anchorY * f.sourceH
    local frameOriginX = (f.sourceW - f.frameW) / 2 + f.offsetX
    local frameOriginY = (f.sourceH - f.frameH) / 2 - f.offsetY

    if f.rotated then
        -- Rotated sprites are stored 90deg CW in atlas.
        -- The quad is (fh x fw) in atlas texture, representing (fw x fh) visual.
        -- After de-rotation (-90deg), the visual frame is fw wide, fh tall.
        local ox = srcAnchorY - frameOriginY   -- maps to atlas horizontal (pre-rotation vertical)
        local oy = f.frameW - (srcAnchorX - frameOriginX)  -- maps to atlas vertical (pre-rotation horizontal), inverted
        love.graphics.draw(atlasImage, f.quad, x, y,
            rotation - math.pi / 2, scaleX, scaleY, ox, oy)
    else
        local ox = srcAnchorX - frameOriginX
        local oy = srcAnchorY - frameOriginY
        love.graphics.draw(atlasImage, f.quad, x, y,
            rotation, scaleX, scaleY, ox, oy)
    end
    return true
end

function Atlas.isLoaded()
    return atlasImage ~= nil
end

return Atlas

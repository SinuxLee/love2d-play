-- Constants matching the original cocos2dx game (EightBallDefine.lua)
local Config = {}

-- Design resolution
Config.DESIGN_WIDTH = 1136
Config.DESIGN_HEIGHT = 640

-- Ball physics
Config.BALL_RADIUS = 15
Config.BALL_DENSITY = 2.7
Config.BALL_RESTITUTION = 0.95
Config.BALL_FRICTION = 0
Config.WHITE_BALL_FRICTION = 0.2
Config.BALL_LINEAR_DAMPING = 0.7          -- base damping (matches original)
Config.BALL_ANGULAR_DAMPING = 1
Config.BALL_VELOCITY_LIMIT = 4            -- matches original
Config.BALL_DAMPING_VALUE = 300 * 300     -- v^2 threshold for medium damping (matches original)
Config.BALL_DOUBLE_DAMPING_VALUE = 150 * 150 -- v^2 threshold for high damping (matches original)
Config.BALL_LINEAR_INCREASE_MULTIPLE = 0.7   -- matches original (same as base, only starts timer)
Config.BALL_LINEAR_INCREASE_DOUBLE_MULTIPLE = 1.0  -- matches original
Config.INCREASE_VELOCITY_TIME = 1         -- matches original

-- Border physics
Config.BORDER_DENSITY = 10000000
Config.BORDER_RESTITUTION = 0.8
Config.BORDER_FRICTION = 0.5

-- Ball rolling visual speed factor
-- Pure rolling: angular_vel = linear_vel / radius (factor = 1.0)
-- Slightly above 1.0 exaggerates the roll for more visual punch in top-down view.
Config.BALL_ROLLING_FACTOR = 1.2

-- Force/Power (original values, now Box2D velocity clamping is fixed by setMeter(100))
Config.LINE_SPEED_RATIO = 16000    -- impulse force multiplier
Config.ROTATE_FORCE_RATIO = 10000  -- top/back spin force multiplier
Config.LEFT_RIGHT_FORCE_RATIO = 300 -- side spin angular velocity multiplier

-- Physics stepping
Config.FRESH_COUNT = 5
Config.SCREEN_REFRESH_RATE = Config.FRESH_COUNT * 60  -- = 300

-- Cue geometry (from original sprite: eightBall_Cue.png sourceSize 672x30, anchor 1,0.5)
-- The marker tag(51) is at (cueWidth/2, cueHeight/2) = (336, 15) in cue-local.
-- Distance from marker to anchor (ball center) = cueWidth/2 = 336.
Config.CUE_DISTANCE = 336

-- Desk dimensions
-- The original desk height is ~547 (inferred from whiteBallOriginalPos.y = 273.5 = deskH/2)
Config.DESK_WIDTH = 968
Config.DESK_HEIGHT = 547

-- Offset to center the desk on screen
Config.DESK_OFFSET_X = (Config.DESIGN_WIDTH - Config.DESK_WIDTH) / 2
Config.DESK_OFFSET_Y = (Config.DESIGN_HEIGHT - Config.DESK_HEIGHT) / 2

-- Table inner playing surface boundaries (Y-up cocos2d coordinates)
Config.TABLE_INNER_LEFT = 58
Config.TABLE_INNER_RIGHT = 910
Config.TABLE_INNER_TOP = 488     -- top edge in Y-up
Config.TABLE_INNER_BOTTOM = 59   -- bottom edge in Y-up

-- Pocket (hole) positions relative to desk (from PhysicalControl.lua, Y-up coordinate)
Config.HOLE_POSITIONS = {
    {x = 48,  y = 48},     -- bottom-left
    {x = 48,  y = 498.6},  -- top-left
    {x = 485, y = 30},     -- bottom-center
    {x = 485, y = 516},    -- top-center
    {x = 921, y = 48},     -- bottom-right
    {x = 921, y = 498.6},  -- top-right
}

Config.HOLE_RADIUS = Config.BALL_RADIUS * 1.2

-- White ball original position (in desk coordinate, Y-up in original)
Config.WHITE_BALL_ORIGINAL_X = 270
Config.WHITE_BALL_ORIGINAL_Y = 273.5  -- desk height / 2

-- Ball rack position
Config.RACK_START_X = 650

-- Ball arrangement in triangle (front to back)
Config.BALL_RACK_ORDER = {1, 2, 9, 10, 8, 3, 4, 11, 5, 12, 13, 6, 14, 15, 7}

-- In-hole detection boundaries (desk coordinates, Y-up)
Config.IN_HOLE_LEFT = 70
Config.IN_HOLE_RIGHT = 910
Config.IN_HOLE_TOP = 475
Config.IN_HOLE_BOTTOM = 70

-- Power bar (original 415x82 horizontal slider, rotated 90deg CW to display vertically)
-- After rotation: visual width=82, visual height=415, right side of screen
Config.POWER_BAR_VISUAL_W = 82   -- visual width after rotation
Config.POWER_BAR_VISUAL_H = 415  -- visual height after rotation
Config.POWER_BAR_X = Config.DESIGN_WIDTH - Config.POWER_BAR_VISUAL_W - 15
Config.POWER_BAR_Y = (Config.DESIGN_HEIGHT - Config.POWER_BAR_VISUAL_H) / 2

-- Check stop interval
Config.CHECK_STOP_INTERVAL = 0.1

-- Damping speed check frequency: original checks every 10th animation callback
Config.DAMPING_CHECK_INTERVAL = 10

-- Ball colors for rendering
Config.BALL_COLORS = {
    [0]  = {1.00, 1.00, 1.00},  -- white (cue ball)
    [1]  = {1.00, 0.85, 0.00},  -- yellow (solid 1)
    [2]  = {0.00, 0.00, 0.80},  -- blue (solid 2)
    [3]  = {1.00, 0.00, 0.00},  -- red (solid 3)
    [4]  = {0.30, 0.00, 0.50},  -- purple (solid 4)
    [5]  = {1.00, 0.50, 0.00},  -- orange (solid 5)
    [6]  = {0.00, 0.50, 0.00},  -- green (solid 6)
    [7]  = {0.55, 0.00, 0.00},  -- maroon (solid 7)
    [8]  = {0.10, 0.10, 0.10},  -- black (8 ball)
    [9]  = {1.00, 0.85, 0.00},  -- yellow (stripe 9)
    [10] = {0.00, 0.00, 0.80},  -- blue (stripe 10)
    [11] = {1.00, 0.00, 0.00},  -- red (stripe 11)
    [12] = {0.30, 0.00, 0.50},  -- purple (stripe 12)
    [13] = {1.00, 0.50, 0.00},  -- orange (stripe 13)
    [14] = {0.00, 0.50, 0.00},  -- green (stripe 14)
    [15] = {0.55, 0.00, 0.00},  -- maroon (stripe 15)
}

-- Game states
Config.STATE_PRACTICE = -1
Config.STATE_NONE = 0
Config.STATE_WAITING = 1
Config.STATE_HIT_BALL = 2
Config.STATE_SET_WHITE = 3
Config.STATE_GAME_OVER = 4

-- Ball states
Config.BALL_STATE_STOP = 0
Config.BALL_STATE_RUN = 1
Config.BALL_STATE_IN_HOLE = 2

-- Inner border segments (from PhysicalControl.lua, Y-up coordinate)
Config.INNER_BORDERS = {
    {{91, 59}, {457, 59}},      -- bottom-left segment
    {{512, 59}, {878, 59}},     -- bottom-right segment
    {{910, 92}, {910, 455}},    -- right wall
    {{878, 488}, {512, 488}},   -- top-right segment
    {{456, 488}, {91, 488}},    -- top-left segment
    {{58, 456}, {58, 91}},      -- left wall
}

-- Outer border segments (from PhysicalControl.lua:56-63)
Config.OUTER_BORDERS = {
    {{0, 0}, {Config.DESK_WIDTH, 0}},
    {{0, 0}, {0, Config.DESK_HEIGHT}},
    {{Config.DESK_WIDTH, 0}, {Config.DESK_WIDTH, Config.DESK_HEIGHT}},
    {{0, Config.DESK_HEIGHT}, {Config.DESK_WIDTH, Config.DESK_HEIGHT}},
}

-- Apply tuning overrides from tuning.lua (if it exists)
function Config.applyTuning()
    local ok, tuning = pcall(require, "tuning")
    if ok and type(tuning) == "table" then
        for k, v in pairs(tuning) do
            if Config[k] ~= nil then
                Config[k] = v
            end
        end
    end
end

Config.applyTuning()

return Config

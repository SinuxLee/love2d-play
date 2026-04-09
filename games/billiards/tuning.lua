-- Tuning overrides for all physics/gameplay parameters.
-- Edit this file and press F5 in-game to hot-reload.
-- Only uncomment the values you want to override.
-- Commented values use defaults from config.lua.

return {
    -- Ball physics
    -- BALL_RADIUS = 15,
    -- BALL_DENSITY = 2.7,
    -- BALL_RESTITUTION = 0.95,
    -- BALL_FRICTION = 0,
    -- WHITE_BALL_FRICTION = 0.2,
    -- BALL_LINEAR_DAMPING = 1.8,
    -- BALL_ANGULAR_DAMPING = 1,
    -- BALL_VELOCITY_LIMIT = 1.5,
    -- BALL_DAMPING_VALUE = 250000,        -- v^2 threshold for medium damping
    -- BALL_DOUBLE_DAMPING_VALUE = 10000,  -- v^2 threshold for high damping
    -- BALL_LINEAR_INCREASE_MULTIPLE = 2.8,
    -- BALL_LINEAR_INCREASE_DOUBLE_MULTIPLE = 4.0,
    -- INCREASE_VELOCITY_TIME = 0.5,

    -- Border physics
    -- BORDER_RESTITUTION = 0.8,
    -- BORDER_FRICTION = 0.5,

    -- Force/Power
    -- LINE_SPEED_RATIO = 41000,
    -- ROTATE_FORCE_RATIO = 25600,
    -- LEFT_RIGHT_FORCE_RATIO = 770,

    -- Rolling visual
    -- BALL_ROLLING_FACTOR = 1.2,

    -- Cue distance (affects impulse: impulse = CUE_DISTANCE * LINE_SPEED_RATIO * percent)
    -- CUE_DISTANCE = 336,
}

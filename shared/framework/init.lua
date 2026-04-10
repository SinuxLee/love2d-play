-- framework/init.lua
-- Main entry point for the Love2D Phaser 3-style framework.
--
-- Usage (in main.lua inside love.load):
--
--   local Framework = require "framework"
--
--   function love.load()
--       Framework.game({
--           title      = "My Game",
--           background = {0.1, 0.1, 0.2},
--           debug      = false,
--
--           -- Default input bindings shared across all scenes (optional)
--           input = {
--               left  = {"key:left",  "key:a"},
--               right = {"key:right", "key:d"},
--               up    = {"key:up",    "key:w"},
--               down  = {"key:down",  "key:s"},
--               jump  = {"key:space"},
--           },
--
--           -- Global middleware: tables with update/draw methods (optional)
--           middleware = {},
--
--           -- Scene registry: key → Scene subclass
--           scenes = {
--               boot = require "scene.boot",
--               menu = require "scene.menu",
--               play = require "scene.play",
--               hud  = require "scene.hud",
--           },
--
--           -- Scene to start on launch
--           start = "boot",
--       })
--   end
--
-- After Framework.game() returns the SceneManager is live and all
-- love.* callbacks are wired up; you should not define any love.*
-- functions yourself after this call.

local SceneManager = require "framework.scene_manager"

-- ─── All love2d callbacks we intercept and forward ──────────────────────────
-- "load" is handled separately; "draw" and "update" are also special-cased.
local DISPATCH_CALLBACKS = {
    -- keyboard
    "keypressed", "keyreleased", "textinput", "textedited",
    -- mouse
    "mousepressed", "mousereleased", "mousemoved", "wheelmoved",
    -- touch
    "touchpressed", "touchreleased", "touchmoved",
    -- joystick / gamepad
    "joystickpressed", "joystickreleased", "joystickaxis", "joystickhat",
    "joystickadded",   "joystickremoved",
    "gamepadadded",    "gamepadremoved",
    "gamepadpressed",  "gamepadreleased",  "gamepadaxis",
    -- window
    "focus", "visible", "resize",
    -- file
    "filedropped", "directorydropped",
}

local Framework = {}

-- Holds the live SceneManager so helper accessors can reach it.
local _sm

---Bootstrap the game: wire up all love.* callbacks and start the first scene.
---Must be called from inside love.load() or at module level after conf.lua runs.
---@param config table  Game configuration (see module header for keys)
---@return SceneManager  The live scene manager
function Framework.game(config)
    assert(type(config)         == "table",  "Framework.game: config must be a table")
    assert(type(config.scenes)  == "table",  "Framework.game: config.scenes is required")
    assert(type(config.start)   == "string", "Framework.game: config.start is required")

    -- ── Optional window title ────────────────────────────────────────────────
    if config.title and love.window then
        love.window.setTitle(config.title)
    end

    -- ── Background colour ────────────────────────────────────────────────────
    if config.background and love.graphics then
        love.graphics.setBackgroundColor(
            config.background[1] or 0,
            config.background[2] or 0,
            config.background[3] or 0,
            config.background[4] or 1
        )
    end

    -- ── Create scene manager ─────────────────────────────────────────────────
    local sm = SceneManager.new(config.scenes, config)
    _sm = sm

    -- ── Optional dev tools (hot-reload, FPS overlay) ─────────────────────────
    local debugMod
    if config.debug then
        local ok, d = pcall(require, "framework.dev.debug")
        if ok then
            debugMod = d
            debugMod.init(sm)
        end
    end

    -- ── Snapshot any existing love callbacks set before Framework.game() ─────
    -- (Allows library authors to still set love.keypressed etc. before us.)
    -- NOTE: We skip Love2D's own boot.lua wrappers (source starts with "[love")
    -- because they internally hold a nil prevFn and crash when called.
    local _orig = {}
    local function orig(name)
        return _orig[name] or function() end
    end

    local function snapshot(name)
        local fn = love[name]
        if type(fn) == "function" then
            local info = debug.getinfo(fn, "S")
            -- Only chain user-defined functions; ignore Love2D's internal wrappers
            if info and not info.source:match("^%[love") then
                _orig[name] = fn
            end
        end
    end

    snapshot("update"); snapshot("draw"); snapshot("quit")
    for _, cb in ipairs(DISPATCH_CALLBACKS) do snapshot(cb) end

    -- ── love.update ──────────────────────────────────────────────────────────
    love.update = function(dt)
        orig("update")(dt)
        -- Global middleware (runs before scenes)
        local mw = config.middleware
        if mw then
            for _, m in ipairs(mw) do
                if m.update then m.update(dt) end
            end
        end
        -- Dev tools
        if debugMod then debugMod.update(dt) end
        sm:update(dt)
    end

    -- ── love.draw ────────────────────────────────────────────────────────────
    love.draw = function()
        orig("draw")()
        -- Global middleware draw
        local mw = config.middleware
        if mw then
            for _, m in ipairs(mw) do
                if m.draw then m.draw() end
            end
        end
        sm:draw()
        -- Dev overlay (drawn on top of everything)
        if debugMod then debugMod.draw() end
    end

    -- ── love.quit ────────────────────────────────────────────────────────────
    love.quit = function()
        orig("quit")()
        sm:dispatch("quit")
        sm:destroyAll()
        return false   -- allow quit
    end

    -- ── Generic dispatch callbacks ────────────────────────────────────────────
    for _, cbName in ipairs(DISPATCH_CALLBACKS) do
        local name = cbName          -- capture for closure
        local prevFn = orig(name)    -- orig() returns a no-op if no prior handler
        love[name] = function(...)
            prevFn(...)
            sm:dispatch(name, ...)
        end
    end

    -- ── Start initial scene ──────────────────────────────────────────────────
    sm:start(config.start)

    return sm
end

---Return the live SceneManager (available after Framework.game() is called).
---@return SceneManager|nil
function Framework.getSceneManager()
    return _sm
end

return Framework

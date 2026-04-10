-- demo-framework/main.lua
-- Entire game bootstrap – the framework handles all love.* callbacks.

local Framework = require "framework"

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    Framework.game({
        title      = "Framework Demo",
        background = { 0.08, 0.08, 0.15 },
        debug      = true,   -- F9 toggles the dev overlay; lurker hot-reload

        -- ── Default input bindings (available in every scene as self.input) ──
        input = {
            left  = { "key:left",  "key:a" },
            right = { "key:right", "key:d" },
            up    = { "key:up",    "key:w" },
            down  = { "key:down",  "key:s" },
            jump  = { "key:space", "key:up", "key:w" },
            fire  = { "key:z",     "mouse:1" },
        },

        -- ── Scene registry ───────────────────────────────────────────────────
        scenes = {
            menu = require "scene.menu",
            play = require "scene.play",
            hud  = require "scene.hud",
        },

        -- ── First scene to launch ────────────────────────────────────────────
        start = "menu",
    })
end

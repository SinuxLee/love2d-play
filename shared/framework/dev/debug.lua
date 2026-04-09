-- framework/dev/debug.lua
-- Developer tools: hot-reload (lurker) + FPS/scene overlay
--
-- Enabled by setting  debug = true  in Framework.game() config.
-- Should NEVER be required in production builds.
--
-- Features:
--   • Hot file reload via lurker (saves you restarting the game while editing)
--   • FPS / delta-time display (top-right corner)
--   • Active scenes list with their current status
--   • Press F9 to toggle the overlay

-- Make lume available globally so lurker can find it from its require path
if not rawget(_G, "lume") then
    local ok, lume = pcall(require, "lume.lume")
    if ok then _G.lume = lume end
end

local lurker
do
    local ok, l = pcall(require, "lurker.lurker")
    if ok then lurker = l end
end

local Debug = {}

local _sm          -- SceneManager reference
local _show = true -- overlay visibility toggle
local _dt   = 0

function Debug.init(sm)
    _sm = sm

    if lurker then
        lurker.init()
        lurker.quiet = false   -- print reload messages to console
        print("[Framework/Debug] lurker hot-reload active")
    else
        print("[Framework/Debug] lurker not available – hot-reload disabled")
    end
end

function Debug.update(dt)
    _dt = dt
    if lurker then
        lurker.update()
    end
end

function Debug.draw()
    if not _show then return end

    local W = love.graphics.getWidth()
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", W - 220, 4, 216, 14 + (_sm and #_sm._scenes * 14 or 0) + 6)

    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(
        string.format("FPS: %d  dt: %.4f", love.timer.getFPS(), _dt),
        W - 216, 8
    )

    if _sm then
        local y = 22
        for _, entry in ipairs(_sm._scenes) do
            local col = { 0.5, 0.5, 0.5, 1 }
            if entry.status == "running"  then col = { 0.3, 1.0, 0.3, 1 }
            elseif entry.status == "paused"  then col = { 1.0, 0.8, 0.2, 1 }
            elseif entry.status == "sleeping" then col = { 0.5, 0.7, 1.0, 1 }
            end
            love.graphics.setColor(col)
            love.graphics.print(
                string.format("  [%s] %s", entry.status:sub(1,3):upper(), entry.key),
                W - 216, y
            )
            y = y + 14
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Toggle overlay with F9
-- (Wire into the keypressed dispatch via a middleware or scene callback.
--  The demo game registers this; you can also do it manually.)
function Debug.keypressed(key)
    if key == "f9" then
        _show = not _show
    end
end

return Debug

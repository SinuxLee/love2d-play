-- scene/hud.lua
-- HUD overlay scene, running IN PARALLEL with play.lua.
-- Demonstrates:
--   Parallel scenes (launched alongside play)
--   self.data    (reads score from shared data written by play)
--   self.tweens  (score pop animation)

local Scene = require "framework.scene"
local HudScene = Scene:extend("HudScene")

function HudScene:create()
    self._displayScore = 0  -- animated score counter
    self._popScale     = 1.0
end

function HudScene:update(dt)
    -- Smoothly animate the displayed score toward the real score
    local target = self.data.score or 0
    if self._displayScore < target then
        self._displayScore = math.min(target,
            self._displayScore + math.max(1, (target - self._displayScore) * 12 * dt))
        -- Trigger pop when score changes
        if not self._popping then
            self._popping = true
            self._popScale = 1.0
            self.tweens:tween(0.12, self, { _popScale = 1.35 }, "out-cubic",
                function()
                    self.tweens:tween(0.18, self, { _popScale = 1.0 }, "in-elastic",
                        function() self._popping = false end)
                end)
        end
    end
end

function HudScene:draw()
    local W  = love.graphics.getWidth()
    local score = math.floor(self._displayScore)
    local total = self.data.totalCoins or 0
    local collected = total - (function()
        local n = 0
        -- We can't access PlayScene internals directly; use data instead
        -- play.lua stores alive coin count via self.data if needed.
        -- For now approximate from score
        return math.max(0, total - math.floor(score / 100))
    end)()

    -- ── Score panel (top-left) ────────────────────────────────────────────────
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, 200, 48)

    love.graphics.setColor(1, 0.85, 0.1, 1)
    local s = self._popScale
    love.graphics.push()
    love.graphics.translate(100, 24)
    love.graphics.scale(s, s)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf(string.format("Score: %d", score), -100, -14, 200, "center")
    love.graphics.pop()

    -- ── Coins indicator (top-right) ───────────────────────────────────────────
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", W - 180, 0, 180, 36)

    love.graphics.setColor(1, 1, 0.3)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf(
        string.format("Coins: %d / %d", collected, total),
        W - 176, 8, 172, "right")

    love.graphics.setColor(1, 1, 1, 1)
end

return HudScene

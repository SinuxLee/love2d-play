-- scene/hud.lua
-- HUD overlay scene, running IN PARALLEL with play.lua.
--
-- Demonstrates:
--   Parallel scenes (launched alongside play)
--   self:watch(key, fn)   – react to shared data changes (auto-cleaned on stop)
--   self.tweens           – score pop animation triggered by watcher

local Scene = require "framework.scene"
local HudScene = Scene:extend("HudScene")

function HudScene:create()
    self._displayScore = self.data.score or 0
    self._popScale     = 1.0
    self._popping      = false

    -- Watch score changes: trigger pop animation whenever score increases.
    -- The watcher is automatically removed when this scene is stopped.
    self:watch("score", function(new, _old)
        -- Snap display toward new value immediately (smooth lerp in update)
        if new > self._displayScore and not self._popping then
            self._popping  = true
            self._popScale = 1.0
            self.tweens:tween(0.12, self, { _popScale = 1.35 }, "out-cubic",
                function()
                    self.tweens:tween(0.18, self, { _popScale = 1.0 }, "in-elastic",
                        function() self._popping = false end)
                end)
        end
    end)
end

function HudScene:update(dt)
    -- Smoothly animate the displayed score toward the real score
    local target = self.data.score or 0
    if self._displayScore ~= target then
        self._displayScore = math.min(target,
            self._displayScore + math.max(1, (target - self._displayScore) * 12 * dt))
    end
end

function HudScene:draw()
    local W     = love.graphics.getWidth()
    local score = math.floor(self._displayScore)
    local total = self.data.totalCoins or 0

    -- Approximate coins collected from score (100 pts per coin)
    local collected = math.min(total, math.floor(score / 100))

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

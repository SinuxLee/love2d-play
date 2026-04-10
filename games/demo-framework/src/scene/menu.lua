-- scene/menu.lua
-- Main menu scene.
-- Demonstrates: self.ui (suit), self.time (timer/tween), self.scene (switch)

local Scene = require "framework.scene"
local MenuScene = Scene:extend("MenuScene")

local W, H

function MenuScene:create()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    -- Animated title Y-position starts off-screen and tweens in
    self._titleY    = -80
    self._titleAlpha = 0

    self.tweens:tween(0.6, self, { _titleY = H * 0.28, _titleAlpha = 1 },
        "out-cubic")

    -- Pulsing scale for the "Press ENTER" hint
    self._pulse = 1.0
    self.time:every(0.9, function()
        self.tweens:tween(0.45, self, { _pulse = 1.15 }, "in-out-sine",
            function()
                self.tweens:tween(0.45, self, { _pulse = 1.0 }, "in-out-sine")
            end)
    end)

    -- Shared data initialisation
    self.data.score      = 0
    self.data.highScore  = self.data.highScore or 0
end

function MenuScene:update(dt)   -- luacheck: ignore
    -- Input handled via keypressed below
end

function MenuScene:draw()
    -- ── Background gradient (manual via rectangles) ──────────────────────────
    for i = 0, H, 4 do
        local t = i / H
        love.graphics.setColor(0.05 + t * 0.08, 0.05 + t * 0.05, 0.2 + t * 0.1, 1)
        love.graphics.rectangle("fill", 0, i, W, 4)
    end

    -- ── Title ────────────────────────────────────────────────────────────────
    love.graphics.setColor(0.9, 0.7, 0.2, self._titleAlpha)
    local font = love.graphics.newFont(48)
    love.graphics.setFont(font)
    love.graphics.printf("FRAMEWORK DEMO", 0, self._titleY, W, "center")

    love.graphics.setColor(0.7, 0.7, 0.9, self._titleAlpha * 0.8)
    local small = love.graphics.newFont(16)
    love.graphics.setFont(small)
    love.graphics.printf("A Love2D Phaser-style Framework", 0, self._titleY + 58, W, "center")

    -- ── Pulsing "Press ENTER" hint ───────────────────────────────────────────
    love.graphics.setColor(1, 1, 1, self._titleAlpha)
    local s = self._pulse
    love.graphics.push()
    love.graphics.translate(W / 2, H * 0.55)
    love.graphics.scale(s, s)
    love.graphics.setFont(love.graphics.newFont(22))
    love.graphics.printf("Press  ENTER  to Play", -W / 2, -15, W, "center")
    love.graphics.pop()

    -- ── High score ───────────────────────────────────────────────────────────
    if self.data.highScore and self.data.highScore > 0 then
        love.graphics.setColor(0.6, 1.0, 0.6, self._titleAlpha)
        love.graphics.setFont(love.graphics.newFont(18))
        love.graphics.printf("High Score: " .. self.data.highScore,
            0, H * 0.68, W, "center")
    end

    -- ── suit UI: Quit button ─────────────────────────────────────────────────
    love.graphics.setColor(1, 1, 1, self._titleAlpha)
    self.ui.layout:reset(W / 2 - 80, H - 80, 4)
    if self.ui:Button("Quit", self.ui.layout:row(160, 36)).hit then
        love.event.quit()
    end

    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(0.4, 0.4, 0.6, 0.8)
    love.graphics.printf("F9 = debug overlay", 0, H - 22, W, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

function MenuScene:keypressed(key)
    if key == "return" or key == "kpenter" then
        -- switch stops menu, launches play + hud in parallel
        self.scene:switch("play")
        self.scene:launch("hud")
    elseif key == "escape" then
        love.event.quit()
    end
end

return MenuScene

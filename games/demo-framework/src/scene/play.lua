-- scene/play.lua
-- Gameplay scene.
-- Demonstrates:
--   self.physics  (bump.lua AABB collision)
--   self.input    (action bindings)
--   self.cameras  (hump.camera with smooth follow)
--   self.time     (after/every timers)
--   self.tweens   (smooth value interpolation)
--   self.events   (scene-local events → HUD listens via self.data)
--   self.data     (shared state: score)
--   self.scene    (launch/stop/switch)

local Scene = require "framework.scene"

local PlayScene = Scene:extend("PlayScene")

-- Declare optional systems for this scene
PlayScene.systems = { "physics" }

-- ── World constants ──────────────────────────────────────────────────────────
local GRAVITY    = 900
local MOVE_SPEED = 240
local JUMP_FORCE = -440
local TILE       = 32

-- Level layout (W = wall, F = floor tile, P = player spawn, C = coin)
local MAP = {
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
    "W                              W",
    "W        CCC                   W",
    "W     FFFFFF                   W",
    "W                    CCC       W",
    "W              FFFFFF          W",
    "W  CCC                         W",
    "W  FFFFFF   W       FFFFFF     W",
    "W                         P    W",
    "W  FFFFFFFFFFFFFFFFFFFFFFFFFFFF W",
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
}

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function px(col) return (col - 1) * TILE end
local function py(row) return (row - 1) * TILE end

-- ── Scene lifecycle ───────────────────────────────────────────────────────────

function PlayScene:create()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    self.data.score = 0

    -- ── Parse the map ────────────────────────────────────────────────────────
    self._walls  = {}
    self._floors = {}
    self._coins  = {}
    self._playerSpawn = { x = W / 2, y = H / 2 }

    for row, line in ipairs(MAP) do
        for col = 1, #line do
            local ch = line:sub(col, col)
            local x, y = px(col), py(row)
            if ch == "W" then
                local tile = { x = x, y = y, w = TILE, h = TILE, kind = "wall" }
                table.insert(self._walls, tile)
                self.physics:add(tile, x, y, TILE, TILE)
            elseif ch == "F" then
                local tile = { x = x, y = y, w = TILE, h = TILE, kind = "floor" }
                table.insert(self._floors, tile)
                self.physics:add(tile, x, y, TILE, TILE)
            elseif ch == "C" then
                local coin = { x = x + 8, y = y + 8, w = 16, h = 16,
                               alive = true, bobOffset = math.random() * math.pi * 2 }
                table.insert(self._coins, coin)
                self.physics:add(coin, coin.x, coin.y, coin.w, coin.h)
            elseif ch == "P" then
                self._playerSpawn = { x = x, y = y }
            end
        end
    end

    -- ── Player ───────────────────────────────────────────────────────────────
    self._player = {
        x = self._playerSpawn.x,
        y = self._playerSpawn.y,
        w = 24, h = 32,
        vx = 0, vy = 0,
        onGround = false,
        facing = 1,         -- 1 = right, -1 = left
        jumpCooldown = 0,
    }
    self.physics:add(self._player,
        self._player.x, self._player.y,
        self._player.w, self._player.h)

    -- Camera starts at player position
    self.cameras:lookAt(self._player.x, self._player.y)

    -- Flash effect on coin collect
    self._flash = 0

    -- Announce scene start to HUD via shared data
    self.data.totalCoins = #self._coins

    -- Return-to-menu hint timer
    self._elapsed = 0
end

function PlayScene:update(dt)
    local p = self._player
    self._elapsed = self._elapsed + dt

    -- ── Horizontal movement ──────────────────────────────────────────────────
    local moveX = 0
    if self.input:actionDown("left")  then moveX = moveX - 1 end
    if self.input:actionDown("right") then moveX = moveX + 1 end

    if moveX ~= 0 then
        p.facing = moveX
        p.vx = moveX * MOVE_SPEED
    else
        p.vx = p.vx * 0.75  -- friction
        if math.abs(p.vx) < 2 then p.vx = 0 end
    end

    -- ── Jump ─────────────────────────────────────────────────────────────────
    p.jumpCooldown = math.max(0, p.jumpCooldown - dt)
    if self.input:actionPressed("jump") and p.onGround and p.jumpCooldown <= 0 then
        p.vy = JUMP_FORCE
        p.onGround = false
        p.jumpCooldown = 0.15
    end

    -- ── Gravity ──────────────────────────────────────────────────────────────
    p.vy = p.vy + GRAVITY * dt

    -- ── Move with collision ──────────────────────────────────────────────────
    local goalX = p.x + p.vx * dt
    local goalY = p.y + p.vy * dt

    local function collFilter(_, other)
        if other.kind == "coin" then return "cross" end
        return "slide"
    end

    local newX, newY, cols = self.physics:move(p, goalX, goalY, collFilter)
    p.x = newX
    p.y = newY
    self.physics:updateItem(p, p.x, p.y, p.w, p.h)

    -- Detect ground / ceiling / walls from collisions
    p.onGround = false
    for _, col in ipairs(cols) do
        if col.normal.y < 0 then
            p.onGround = true
            p.vy = 0
        elseif col.normal.y > 0 then
            p.vy = 0
        end
        -- Coin collection
        if col.other.alive then
            col.other.alive = false
            self.physics:remove(col.other)
            self.data.score = (self.data.score or 0) + 100
            self._flash = 0.12

            -- Brief camera shake via tweens
            local ox, oy = self.cameras:position()
            self.tweens:tween(0.08, { t = 0 }, { t = 1 }, "linear", function()
                self.cameras:lookAt(ox + math.random(-4, 4), oy + math.random(-4, 4))
                self.time:after(0.08, function()
                    self.cameras:lookAt(ox, oy)
                end)
            end)
        end
    end

    -- ── Camera smooth follow ─────────────────────────────────────────────────
    local cx, cy = self.cameras:position()
    local tx = p.x + p.w / 2
    local ty = p.y + p.h / 2
    self.cameras:lookAt(cx + (tx - cx) * 8 * dt, cy + (ty - cy) * 8 * dt)

    -- ── Coin bobbing ─────────────────────────────────────────────────────────
    for _, coin in ipairs(self._coins) do
        if coin.alive then
            coin.bobOffset = coin.bobOffset + dt * 2
        end
    end

    -- ── Respawn if fallen off ────────────────────────────────────────────────
    if p.y > py(#MAP + 2) then
        self.physics:updateItem(p, self._playerSpawn.x, self._playerSpawn.y, p.w, p.h)
        p.x, p.y = self._playerSpawn.x, self._playerSpawn.y
        p.vx, p.vy = 0, 0
    end

    -- ── Flash decay ──────────────────────────────────────────────────────────
    self._flash = math.max(0, self._flash - dt * 4)

    -- All coins collected?
    local allGone = true
    for _, c in ipairs(self._coins) do
        if c.alive then allGone = false; break end
    end
    if allGone and not self._won then
        self._won = true
        self.data.highScore = math.max(self.data.highScore or 0, self.data.score)
        self.time:after(2.0, function()
            self.scene:stop("hud")
            self.scene:switch("menu")
        end)
    end
end

function PlayScene:draw()
    self.cameras:attach()

    -- ── Walls ────────────────────────────────────────────────────────────────
    for _, w in ipairs(self._walls) do
        love.graphics.setColor(0.25, 0.25, 0.35)
        love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
        love.graphics.setColor(0.35, 0.35, 0.5)
        love.graphics.rectangle("line", w.x, w.y, w.w, w.h)
    end

    -- ── Floor tiles ──────────────────────────────────────────────────────────
    for _, f in ipairs(self._floors) do
        love.graphics.setColor(0.3, 0.55, 0.3)
        love.graphics.rectangle("fill", f.x, f.y, f.w, f.h)
        love.graphics.setColor(0.4, 0.7, 0.4)
        love.graphics.rectangle("line", f.x, f.y, f.w, f.h)
    end

    -- ── Coins ─────────────────────────────────────────────────────────────────
    for _, coin in ipairs(self._coins) do
        if coin.alive then
            local bob = math.sin(coin.bobOffset) * 3
            love.graphics.setColor(1.0, 0.85, 0.1)
            love.graphics.circle("fill", coin.x + coin.w / 2, coin.y + coin.h / 2 + bob, 8)
            love.graphics.setColor(1, 1, 0.5)
            love.graphics.circle("line", coin.x + coin.w / 2, coin.y + coin.h / 2 + bob, 8)
        end
    end

    -- ── Player ────────────────────────────────────────────────────────────────
    local p = self._player
    local glow = self._flash
    love.graphics.setColor(0.2 + glow, 0.5 + glow * 0.3, 0.9 + glow * 0.1)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 4, 4)
    -- Eyes
    love.graphics.setColor(1, 1, 1)
    local ex = (p.facing > 0) and (p.x + p.w - 8) or (p.x + 4)
    love.graphics.rectangle("fill", ex, p.y + 8, 5, 5)

    self.cameras:detach()

    -- ── On-screen hint (no camera transform) ─────────────────────────────────
    if self._won then
        local W = love.graphics.getWidth()
        local H = love.graphics.getHeight()
        love.graphics.setColor(0.2, 0.9, 0.3, 0.95)
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.printf("All coins collected! Returning...", 0, H / 2 - 24, W, "center")
    else
        love.graphics.setColor(0.6, 0.6, 0.8, 0.7)
        love.graphics.setFont(love.graphics.newFont(12))
        love.graphics.print("ESC = menu  |  WASD/Arrows = move  |  Space/W/Up = jump", 8, 8)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayScene:keypressed(key)
    if key == "escape" then
        self.scene:stop("hud")
        self.scene:switch("menu")
    end
end

function PlayScene:destroy()
    -- Nothing to clean up manually; physics world is GC'd with the instance
end

return PlayScene

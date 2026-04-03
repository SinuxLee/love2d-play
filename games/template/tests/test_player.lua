-- games/template/tests/test_player.lua
local t = require "testing"
local input = require "core.input"
local Player = require "entity.player"

t.describe("Player", function()
    local function reset_input()
        input.up = false
        input.down = false
        input.left = false
        input.right = false
    end

    t.it("initializes at given position", function()
        local p = Player(100, 200)
        t.assert.eq(p.x, 100)
        t.assert.eq(p.y, 200)
    end)

    t.it("has default speed 200", function()
        local p = Player(0, 0)
        t.assert.eq(p.speed, 200)
    end)

    t.it("does not move when no input", function()
        reset_input()
        local p = Player(100, 100)
        p:update(1.0)
        t.assert.eq(p.x, 100)
        t.assert.eq(p.y, 100)
    end)

    t.it("moves right at speed*dt", function()
        reset_input()
        input.right = true
        local p = Player(0, 0)
        p:update(0.5)
        t.assert.near(p.x, 100, 0.01)
        t.assert.near(p.y, 0, 0.01)
    end)

    t.it("normalizes diagonal movement", function()
        reset_input()
        input.right = true
        input.down = true
        local p = Player(0, 0)
        p:update(1.0)
        local expected = 200 / math.sqrt(2)
        t.assert.near(p.x, expected, 0.01)
        t.assert.near(p.y, expected, 0.01)
    end)

    t.it("diagonal speed equals cardinal speed", function()
        reset_input()
        input.right = true
        local p1 = Player(0, 0)
        p1:update(1.0)
        local cardinal_dist = math.sqrt(p1.x * p1.x + p1.y * p1.y)

        reset_input()
        input.right = true
        input.down = true
        local p2 = Player(0, 0)
        p2:update(1.0)
        local diagonal_dist = math.sqrt(p2.x * p2.x + p2.y * p2.y)

        t.assert.near(cardinal_dist, diagonal_dist, 0.01)
    end)
end)

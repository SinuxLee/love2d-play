-- games/template/tests/test_input.lua
local t = require "testing"
local input = require "core.input"

t.describe("Input", function()
    local function reset()
        input.up = false
        input.down = false
        input.left = false
        input.right = false
    end

    t.it("starts with all directions false", function()
        reset()
        t.assert.falsy(input.up)
        t.assert.falsy(input.down)
        t.assert.falsy(input.left)
        t.assert.falsy(input.right)
    end)

    t.it("sets up=true on 'w' press", function()
        reset()
        input.keypressed("w")
        t.assert.truthy(input.up)
    end)

    t.it("sets up=true on 'up' press", function()
        reset()
        input.keypressed("up")
        t.assert.truthy(input.up)
    end)

    t.it("sets up=false on 'w' release", function()
        reset()
        input.keypressed("w")
        input.keyreleased("w")
        t.assert.falsy(input.up)
    end)

    t.it("handles all WASD keys", function()
        reset()
        input.keypressed("a")
        input.keypressed("s")
        input.keypressed("d")
        t.assert.truthy(input.left)
        t.assert.truthy(input.down)
        t.assert.truthy(input.right)
        t.assert.falsy(input.up)
    end)

    t.it("handles all arrow keys", function()
        reset()
        input.keypressed("left")
        input.keypressed("down")
        input.keypressed("right")
        t.assert.truthy(input.left)
        t.assert.truthy(input.down)
        t.assert.truthy(input.right)
    end)
end)

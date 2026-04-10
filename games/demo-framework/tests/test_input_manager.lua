-- tests/test_input_manager.lua
-- Unit tests for shared/framework/input_manager.lua

local t = require "testing"
local InputManager = require "framework.input_manager"

t.describe("InputManager", function()

    t.describe("raw key queries", function()
        t.it("keyDown returns false before any event", function()
            local im = InputManager.new()
            t.assert.falsy(im:keyDown("space"))
        end)

        t.it("keyDown returns true after _keypressed", function()
            local im = InputManager.new()
            im:_keypressed("space")
            t.assert.truthy(im:keyDown("space"))
        end)

        t.it("keyPressed returns true only on the frame of press", function()
            local im = InputManager.new()
            im:_keypressed("a")
            t.assert.truthy(im:keyPressed("a"))
            im:flush()
            t.assert.falsy(im:keyPressed("a"))  -- cleared after flush
            t.assert.truthy(im:keyDown("a"))     -- still held
        end)

        t.it("keyReleased returns true on the frame of release", function()
            local im = InputManager.new()
            im:_keypressed("z")
            im:flush()
            im:_keyreleased("z")
            t.assert.truthy(im:keyReleased("z"))
            t.assert.falsy(im:keyDown("z"))
            im:flush()
            t.assert.falsy(im:keyReleased("z"))  -- cleared after flush
        end)

        t.it("holding key does NOT re-trigger keyPressed", function()
            local im = InputManager.new()
            im:_keypressed("d")
            t.assert.truthy(im:keyPressed("d"))
            -- Simulate key held (no new keypressed event)
            im:flush()
            im:_keypressed("d")   -- love would not call this while key is held... 
            -- Actually in Love2D keypressed IS called each time (with isrepeat=true)
            -- but we guard against double-setting _pressed
            -- Since we simulate it here: flush was called, so _down["key:d"] is still true
            -- _keypressed checks if already down before setting pressed
            -- After flush, _down["key:d"] = true (not cleared by flush), _pressed = {}
            -- _keypressed would NOT set _pressed because _down already has it
            t.assert.falsy(im:keyPressed("d"))
        end)
    end)

    t.describe("raw mouse queries", function()
        t.it("mouseDown returns false initially", function()
            local im = InputManager.new()
            t.assert.falsy(im:mouseDown(1))
        end)

        t.it("mouseDown returns true after _mousepressed", function()
            local im = InputManager.new()
            im:_mousepressed(100, 200, 1)
            t.assert.truthy(im:mouseDown(1))
        end)

        t.it("mousePressed clears on flush", function()
            local im = InputManager.new()
            im:_mousepressed(0, 0, 2)
            t.assert.truthy(im:mousePressed(2))
            im:flush()
            t.assert.falsy(im:mousePressed(2))
            t.assert.truthy(im:mouseDown(2))
        end)

        t.it("mouseReleased clears on flush", function()
            local im = InputManager.new()
            im:_mousepressed(0, 0, 1)
            im:flush()
            im:_mousereleased(0, 0, 1)
            t.assert.truthy(im:mouseReleased(1))
            im:flush()
            t.assert.falsy(im:mouseReleased(1))
        end)

        t.it("records mouse position from _mousemoved", function()
            local im = InputManager.new()
            im:_mousemoved(320, 240, 5, -3)
            local x, y = im:getMousePos()
            t.assert.eq(x, 320)
            t.assert.eq(y, 240)
            t.assert.eq(im.mouse.dx, 5)
            t.assert.eq(im.mouse.dy, -3)
        end)

        t.it("accumulates mouse delta across multiple events per frame", function()
            local im = InputManager.new()
            im:_mousemoved(100, 100, 3, 0)
            im:_mousemoved(103, 100, 2, 1)
            t.assert.eq(im.mouse.dx, 5)
            t.assert.eq(im.mouse.dy, 1)
        end)

        t.it("flushes mouse delta on flush()", function()
            local im = InputManager.new()
            im:_mousemoved(50, 50, 10, 10)
            im:flush()
            t.assert.eq(im.mouse.dx, 0)
            t.assert.eq(im.mouse.dy, 0)
        end)

        t.it("accumulates wheel delta", function()
            local im = InputManager.new()
            im:_wheelmoved(0, 3)
            im:_wheelmoved(0, 2)
            t.assert.eq(im.mouse.wheel.y, 5)
            im:flush()
            t.assert.eq(im.mouse.wheel.y, 0)
        end)
    end)

    t.describe("action binding", function()
        t.it("bind() with a single string source", function()
            local im = InputManager.new()
            im:bind("jump", "key:space")
            im:_keypressed("space")
            t.assert.truthy(im:actionDown("jump"))
            t.assert.truthy(im:actionPressed("jump"))
        end)

        t.it("bind() with multiple sources (table)", function()
            local im = InputManager.new()
            im:bind("jump", { "key:space", "key:up", "key:w" })
            im:_keypressed("w")
            t.assert.truthy(im:actionDown("jump"))
            t.assert.truthy(im:actionPressed("jump"))
        end)

        t.it("actionDown returns false when no sources are held", function()
            local im = InputManager.new()
            im:bind("fire", { "key:z", "mouse:1" })
            t.assert.falsy(im:actionDown("fire"))
        end)

        t.it("actionDown activates from mouse source", function()
            local im = InputManager.new()
            im:bind("fire", { "key:z", "mouse:1" })
            im:_mousepressed(0, 0, 1)
            t.assert.truthy(im:actionDown("fire"))
            t.assert.truthy(im:actionPressed("fire"))
        end)

        t.it("actionReleased triggers when source is released", function()
            local im = InputManager.new()
            im:bind("dodge", "key:lshift")
            im:_keypressed("lshift")
            im:flush()
            im:_keyreleased("lshift")
            t.assert.truthy(im:actionReleased("dodge"))
            t.assert.falsy(im:actionDown("dodge"))
        end)

        t.it("unbind() removes the action", function()
            local im = InputManager.new()
            im:bind("run", "key:lshift")
            im:unbind("run")
            im:_keypressed("lshift")
            t.assert.falsy(im:actionDown("run"))
        end)

        t.it("querying unbound action returns false safely", function()
            local im = InputManager.new()
            t.assert.falsy(im:actionDown("nonexistent"))
            t.assert.falsy(im:actionPressed("nonexistent"))
            t.assert.falsy(im:actionReleased("nonexistent"))
        end)

        t.it("default bindings from constructor", function()
            local im = InputManager.new({
                left  = { "key:left", "key:a" },
                right = { "key:right", "key:d" },
            })
            im:_keypressed("a")
            t.assert.truthy(im:actionDown("left"))
            t.assert.falsy(im:actionDown("right"))
        end)
    end)

    t.describe("flush semantics", function()
        t.it("flush does NOT clear _down (held state persists)", function()
            local im = InputManager.new()
            im:_keypressed("space")
            im:flush()
            t.assert.truthy(im:keyDown("space"))
        end)

        t.it("flush DOES clear _pressed and _released", function()
            local im = InputManager.new()
            im:_keypressed("x")
            im:_keyreleased("y")
            im:flush()
            t.assert.falsy(im:keyPressed("x"))
            t.assert.falsy(im:keyReleased("y"))
        end)
    end)

end)

-- games/physics-testbed/tests/test_camera.lua
local t = require "testing"
local Camera = require "camera"

t.describe("Camera", function()
    t.describe("new", function()
        t.it("initializes at origin with scale 1", function()
            local cam = Camera.new()
            t.assert.eq(cam.x, 0)
            t.assert.eq(cam.y, 0)
            t.assert.eq(cam.scale, 1)
        end)
    end)

    t.describe("toWorld / toScreen roundtrip", function()
        t.it("screen center maps to camera position", function()
            local cam = Camera.new()
            cam.x = 100
            cam.y = 200
            local wx, wy = cam:toWorld(400, 300)
            t.assert.near(wx, 100, 0.01)
            t.assert.near(wy, 200, 0.01)
        end)

        t.it("roundtrips correctly", function()
            local cam = Camera.new()
            cam.x = 50
            cam.y = 75
            cam.scale = 2.0
            local wx, wy = cam:toWorld(300, 200)
            local sx, sy = cam:toScreen(wx, wy)
            t.assert.near(sx, 300, 0.01)
            t.assert.near(sy, 200, 0.01)
        end)

        t.it("respects scale for toWorld", function()
            local cam = Camera.new()
            cam.x = 0
            cam.y = 0
            cam.scale = 2.0
            local wx, wy = cam:toWorld(600, 300)
            t.assert.near(wx, 100, 0.01)
            t.assert.near(wy, 0, 0.01)
        end)
    end)

    t.describe("wheelmoved", function()
        t.it("zooms in on scroll up", function()
            local cam = Camera.new()
            local old_scale = cam.scale
            cam:wheelmoved(0, 1)
            t.assert.truthy(cam.scale > old_scale)
        end)

        t.it("zooms out on scroll down", function()
            local cam = Camera.new()
            local old_scale = cam.scale
            cam:wheelmoved(0, -1)
            t.assert.truthy(cam.scale < old_scale)
        end)

        t.it("clamps to min_scale", function()
            local cam = Camera.new()
            for _ = 1, 100 do cam:wheelmoved(0, -1) end
            t.assert.near(cam.scale, cam.min_scale, 0.01)
        end)

        t.it("clamps to max_scale", function()
            local cam = Camera.new()
            for _ = 1, 100 do cam:wheelmoved(0, 1) end
            t.assert.near(cam.scale, cam.max_scale, 0.01)
        end)
    end)

    t.describe("reset", function()
        t.it("restores defaults", function()
            local cam = Camera.new()
            cam.x = 999
            cam.y = 888
            cam.scale = 5
            cam:reset()
            t.assert.eq(cam.x, 0)
            t.assert.eq(cam.y, 0)
            t.assert.eq(cam.scale, 1)
        end)
    end)

    t.describe("drag pan", function()
        t.it("pans camera on right-mouse drag", function()
            local cam = Camera.new()
            cam.x = 100
            cam.y = 100
            cam:mousepressed(400, 300, 2)
            t.assert.truthy(cam.dragging)
            cam:mousemoved(500, 400, 100, 100)
            t.assert.near(cam.x, 0, 0.01)
            t.assert.near(cam.y, 0, 0.01)
        end)

        t.it("ignores left-mouse for drag", function()
            local cam = Camera.new()
            cam:mousepressed(400, 300, 1)
            t.assert.falsy(cam.dragging)
        end)
    end)
end)

-- games/physics-testbed/tests/test_cut_the_rope.lua
local t = require "testing"
local geom = require "geom"

t.describe("segmentsIntersect", function()
    local si = geom.segmentsIntersect

    t.it("detects crossing segments", function()
        t.assert.truthy(si(0, 0, 10, 10, 10, 0, 0, 10))
    end)

    t.it("rejects parallel segments", function()
        t.assert.falsy(si(0, 0, 10, 0, 0, 5, 10, 5))
    end)

    t.it("rejects non-touching segments", function()
        t.assert.falsy(si(0, 0, 5, 0, 10, 0, 10, 5))
    end)

    t.it("detects T intersection", function()
        t.assert.truthy(si(5, 0, 5, 10, 0, 5, 10, 5))
    end)

    t.it("detects endpoint touching", function()
        -- non-collinear segments sharing an endpoint
        t.assert.truthy(si(0, 0, 5, 5, 5, 5, 10, 0))
    end)

    t.it("rejects collinear non-overlapping", function()
        t.assert.falsy(si(0, 0, 1, 0, 2, 0, 3, 0))
    end)
end)

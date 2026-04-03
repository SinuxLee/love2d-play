local t = require "testing"
local particle = require "particle"

t.describe("particle.integrate", function()
    t.it("applies gravity to vy", function()
        local p = {x = 0, y = 0, vx = 0, vy = 0}
        particle.integrate(p, 1.0, 100)
        t.assert.near(p.vy, 100, 0.01)
    end)

    t.it("moves position by velocity", function()
        local p = {x = 10, y = 20, vx = 5, vy = 0}
        particle.integrate(p, 1.0, 0)
        t.assert.near(p.x, 15, 0.01)
    end)

    t.it("gravity accumulates over multiple steps", function()
        local p = {x = 0, y = 0, vx = 0, vy = 0}
        particle.integrate(p, 0.5, 100)
        particle.integrate(p, 0.5, 100)
        t.assert.near(p.vy, 100, 0.01)
    end)
end)

t.describe("particle.handleCollisions", function()
    local box = {x = 0, y = 0, w = 100, h = 100}

    t.it("clamps particle to bottom boundary", function()
        local p = {x = 50, y = 150, vx = 0, vy = 10, r = 1}
        particle.handleCollisions(p, box, 0, 1.0)
        t.assert.near(p.y, 99, 0.01)
        t.assert.near(p.vy, 0, 0.01)
    end)

    t.it("clamps particle to top boundary", function()
        local p = {x = 50, y = -10, vx = 0, vy = -5, r = 1}
        particle.handleCollisions(p, box, 0, 1.0)
        t.assert.near(p.y, 1, 0.01)
    end)

    t.it("clamps particle to left boundary", function()
        local p = {x = -5, y = 50, vx = -10, vy = 0, r = 1}
        particle.handleCollisions(p, box, 0, 1.0)
        t.assert.near(p.x, 1, 0.01)
    end)

    t.it("clamps particle to right boundary", function()
        local p = {x = 200, y = 50, vx = 10, vy = 0, r = 1}
        particle.handleCollisions(p, box, 0, 1.0)
        t.assert.near(p.x, 99, 0.01)
    end)

    t.it("applies floor friction on bottom hit", function()
        local p = {x = 50, y = 150, vx = 100, vy = 10, r = 1}
        particle.handleCollisions(p, box, 0, 0.5)
        t.assert.near(p.vx, 50, 0.01)
    end)

    t.it("bounces with restitution", function()
        local p = {x = 50, y = 150, vx = 0, vy = 10, r = 1}
        particle.handleCollisions(p, box, 0.8, 1.0)
        t.assert.near(p.vy, -8, 0.01)
    end)
end)

t.describe("particle.applyViscosity", function()
    t.it("blends velocities of nearby particles", function()
        local a = {x = 0, y = 0, vx = 10, vy = 0}
        local b = {x = 2, y = 0, vx = 0, vy = 0}
        local applied = particle.applyViscosity(a, b, 1.0, 0.5, 1)
        t.assert.truthy(applied)
        t.assert.truthy(a.vx < 10)
        t.assert.truthy(b.vx > 0)
    end)

    t.it("does not affect distant particles", function()
        local a = {x = 0, y = 0, vx = 10, vy = 0}
        local b = {x = 100, y = 0, vx = 0, vy = 0}
        local applied = particle.applyViscosity(a, b, 1.0, 0.5, 1)
        t.assert.falsy(applied)
        t.assert.eq(a.vx, 10)
        t.assert.eq(b.vx, 0)
    end)

    t.it("separates overlapping particles", function()
        local a = {x = 0, y = 0, vx = 0, vy = 0}
        local b = {x = 0.5, y = 0, vx = 0, vy = 0}
        particle.applyViscosity(a, b, 1.0, 0.02, 1)
        t.assert.truthy(b.x - a.x > 0.5)
    end)
end)

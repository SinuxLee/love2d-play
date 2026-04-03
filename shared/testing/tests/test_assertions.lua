-- shared/testing/tests/test_assertions.lua
local t = require "testing"

t.describe("assertions.eq", function()
    t.it("passes for equal numbers", function()
        t.assert.eq(1, 1)
    end)

    t.it("passes for equal strings", function()
        t.assert.eq("hello", "hello")
    end)

    t.it("passes for deep-equal tables", function()
        t.assert.eq({1, {2, 3}}, {1, {2, 3}})
    end)

    t.it("fails for different values", function()
        t.assert.errors(function()
            t.assert.eq(1, 2)
        end)
    end)
end)

t.describe("assertions.neq", function()
    t.it("passes for different values", function()
        t.assert.neq(1, 2)
    end)

    t.it("fails for equal values", function()
        t.assert.errors(function()
            t.assert.neq(1, 1)
        end)
    end)
end)

t.describe("assertions.near", function()
    t.it("passes within tolerance", function()
        t.assert.near(1.0, 1.0001, 0.001)
    end)

    t.it("fails outside tolerance", function()
        t.assert.errors(function()
            t.assert.near(1.0, 2.0, 0.001)
        end)
    end)
end)

t.describe("assertions.truthy/falsy", function()
    t.it("truthy passes for true", function()
        t.assert.truthy(true)
    end)

    t.it("truthy passes for non-nil", function()
        t.assert.truthy(42)
    end)

    t.it("falsy passes for nil", function()
        t.assert.falsy(nil)
    end)

    t.it("falsy passes for false", function()
        t.assert.falsy(false)
    end)
end)

t.describe("assertions.contains", function()
    t.it("finds substring", function()
        t.assert.contains("hello world", "world")
    end)

    t.it("fails for missing substring", function()
        t.assert.errors(function()
            t.assert.contains("hello", "xyz")
        end)
    end)
end)

t.describe("assertions.type", function()
    t.it("checks number", function()
        t.assert.type(42, "number")
    end)

    t.it("checks string", function()
        t.assert.type("hi", "string")
    end)

    t.it("fails for wrong type", function()
        t.assert.errors(function()
            t.assert.type(42, "string")
        end)
    end)
end)

t.describe("assertions.vec_near", function()
    t.it("passes for close vectors (table keys)", function()
        t.assert.vec_near({x = 1.0, y = 2.0}, {x = 1.0001, y = 2.0001}, 0.001)
    end)

    t.it("passes for close vectors (array indices)", function()
        t.assert.vec_near({1.0, 2.0}, {1.0001, 2.0001}, 0.001)
    end)
end)

t.describe("assertions.match", function()
    t.it("matches partial table", function()
        t.assert.match({name = "player", hp = 100, mp = 50}, {name = "player", hp = 100})
    end)

    t.it("fails for mismatched key", function()
        t.assert.errors(function()
            t.assert.match({name = "player"}, {name = "enemy"})
        end)
    end)
end)

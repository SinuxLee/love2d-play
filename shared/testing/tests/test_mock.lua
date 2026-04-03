-- shared/testing/tests/test_mock.lua
local t = require "testing"
local mock = require "testing.mock"

t.describe("mock.spy", function()
    t.it("records calls", function()
        local fn = mock.spy()
        fn(1, 2)
        fn("a", "b")
        t.assert.eq(fn.call_count, 2)
        t.assert.eq(fn.calls[1], {1, 2})
        t.assert.eq(fn.calls[2], {"a", "b"})
    end)

    t.it("starts with zero calls", function()
        local fn = mock.spy()
        t.assert.eq(fn.call_count, 0)
        t.assert.eq(#fn.calls, 0)
    end)

    t.it("delegates to base function", function()
        local fn = mock.spy(function(x) return x * 2 end)
        local result = fn(5)
        t.assert.eq(result, 10)
        t.assert.eq(fn.call_count, 1)
    end)
end)

t.describe("mock.stub", function()
    t.it("replaces and restores method", function()
        local obj = {value = function() return "original" end}
        local restore = mock.stub(obj, "value", function() return "stubbed" end)
        t.assert.eq(obj.value(), "stubbed")
        restore()
        t.assert.eq(obj.value(), "original")
    end)
end)

-- tests/test_event_emitter.lua
-- Unit tests for shared/framework/event_emitter.lua

local t = require "testing"
local EventEmitter = require "framework.event_emitter"

t.describe("EventEmitter", function()

    t.describe("on / emit", function()
        t.it("calls handler when event is emitted", function()
            local ee = EventEmitter.new()
            local called = false
            ee:on("ping", function() called = true end)
            ee:emit("ping")
            t.assert.truthy(called)
        end)

        t.it("passes arguments to the handler", function()
            local ee = EventEmitter.new()
            local received
            ee:on("data", function(v) received = v end)
            ee:emit("data", 42)
            t.assert.eq(received, 42)
        end)

        t.it("calls multiple handlers for the same event", function()
            local ee = EventEmitter.new()
            local count = 0
            ee:on("tick", function() count = count + 1 end)
            ee:on("tick", function() count = count + 1 end)
            ee:on("tick", function() count = count + 1 end)
            ee:emit("tick")
            t.assert.eq(count, 3)
        end)

        t.it("does not fire handler for different event", function()
            local ee = EventEmitter.new()
            local called = false
            ee:on("a", function() called = true end)
            ee:emit("b")
            t.assert.falsy(called)
        end)

        t.it("emitting without subscribers is a no-op", function()
            local ee = EventEmitter.new()
            t.assert.truthy(pcall(function() ee:emit("ghost") end))
        end)
    end)

    t.describe("off", function()
        t.it("removes a specific handler", function()
            local ee = EventEmitter.new()
            local count = 0
            local fn = ee:on("x", function() count = count + 1 end)
            ee:emit("x")   -- count = 1
            ee:off("x", fn)
            ee:emit("x")   -- should not fire
            t.assert.eq(count, 1)
        end)

        t.it("removes all handlers when fn is nil", function()
            local ee = EventEmitter.new()
            local count = 0
            ee:on("y", function() count = count + 1 end)
            ee:on("y", function() count = count + 1 end)
            ee:off("y")      -- remove all
            ee:emit("y")
            t.assert.eq(count, 0)
        end)

        t.it("removing a non-existent handler is safe", function()
            local ee = EventEmitter.new()
            t.assert.truthy(pcall(function()
                ee:off("nope", function() end)
            end))
        end)
    end)

    t.describe("once", function()
        t.it("fires exactly once", function()
            local ee = EventEmitter.new()
            local count = 0
            ee:once("bang", function() count = count + 1 end)
            ee:emit("bang")
            ee:emit("bang")
            ee:emit("bang")
            t.assert.eq(count, 1)
        end)

        t.it("passes arguments on the one call", function()
            local ee = EventEmitter.new()
            local got
            ee:once("val", function(v) got = v end)
            ee:emit("val", 99)
            t.assert.eq(got, 99)
        end)
    end)

    t.describe("clear", function()
        t.it("removes all handlers for all events", function()
            local ee = EventEmitter.new()
            local count = 0
            ee:on("a", function() count = count + 1 end)
            ee:on("b", function() count = count + 1 end)
            ee:clear()
            ee:emit("a")
            ee:emit("b")
            t.assert.eq(count, 0)
        end)
    end)

    t.describe("re-entrant safety", function()
        t.it("allows on() inside emit() without infinite loop", function()
            local ee = EventEmitter.new()
            local count = 0
            ee:on("msg", function()
                count = count + 1
                if count == 1 then
                    -- Adding a new handler mid-emit; it should NOT fire this frame
                    ee:on("msg", function() count = count + 100 end)
                end
            end)
            ee:emit("msg")   -- count should become 1, NOT 101
            t.assert.eq(count, 1)
        end)

        t.it("allows off() inside emit()", function()
            local ee = EventEmitter.new()
            local count = 0
            local fn
            fn = ee:on("evt", function()
                count = count + 1
                ee:off("evt", fn)   -- unsubscribe self mid-emit
            end)
            ee:emit("evt")
            ee:emit("evt")   -- second emit should not fire fn
            t.assert.eq(count, 1)
        end)
    end)

end)

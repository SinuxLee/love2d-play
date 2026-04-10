-- tests/test_observable.lua
-- Unit tests for shared/framework/observable.lua

local t          = require "testing"
local Observable = require "framework.observable"

t.describe("Observable", function()

    -- ── Basic read / write ────────────────────────────────────────────────────
    t.describe("read / write", function()
        t.it("stores and retrieves a value", function()
            local d = Observable.new()
            d.score = 42
            t.assert.eq(d.score, 42)
        end)

        t.it("initialises from a table", function()
            local d = Observable.new({ hp = 100, mp = 50 })
            t.assert.eq(d.hp,  100)
            t.assert.eq(d.mp,   50)
        end)

        t.it("can store nil (delete a key)", function()
            local d = Observable.new({ x = 1 })
            d.x = nil
            t.assert.eq(d.x, nil)
        end)

        t.it("supports boolean values", function()
            local d = Observable.new()
            d.flag = true
            t.assert.truthy(d.flag)
            d.flag = false
            t.assert.falsy(d.flag)
        end)
    end)

    -- ── watch ─────────────────────────────────────────────────────────────────
    t.describe("watch", function()
        t.it("fires watcher when value changes", function()
            local d = Observable.new()
            local called = false
            d:watch("score", function() called = true end)
            d.score = 10
            t.assert.truthy(called)
        end)

        t.it("passes (newValue, oldValue) to watcher", function()
            local d = Observable.new({ score = 5 })
            local got_new, got_old
            d:watch("score", function(new, old)
                got_new = new
                got_old = old
            end)
            d.score = 99
            t.assert.eq(got_new, 99)
            t.assert.eq(got_old,  5)
        end)

        t.it("does NOT fire watcher when value is unchanged", function()
            local d = Observable.new({ score = 10 })
            local count = 0
            d:watch("score", function() count = count + 1 end)
            d.score = 10   -- same value
            t.assert.eq(count, 0)
        end)

        t.it("does NOT fire watcher for a different key", function()
            local d = Observable.new()
            local called = false
            d:watch("hp", function() called = true end)
            d.mp = 99
            t.assert.falsy(called)
        end)

        t.it("supports multiple watchers on the same key", function()
            local d = Observable.new()
            local count = 0
            d:watch("x", function() count = count + 1 end)
            d:watch("x", function() count = count + 1 end)
            d:watch("x", function() count = count + 1 end)
            d.x = 1
            t.assert.eq(count, 3)
        end)

        t.it("returns the watcher function for later unwatch", function()
            local d  = Observable.new()
            local fn = function() end
            local ret = d:watch("k", fn)
            t.assert.eq(ret, fn)
        end)
    end)

    -- ── unwatch ───────────────────────────────────────────────────────────────
    t.describe("unwatch", function()
        t.it("stops firing after unwatch", function()
            local d     = Observable.new()
            local count = 0
            local fn    = d:watch("v", function() count = count + 1 end)
            d.v = 1    -- fires → count = 1
            d:unwatch("v", fn)
            d.v = 2    -- should NOT fire
            t.assert.eq(count, 1)
        end)

        t.it("only removes the specified function", function()
            local d      = Observable.new()
            local countA = 0
            local countB = 0
            local fnA    = d:watch("k", function() countA = countA + 1 end)
            local _fnB   = d:watch("k", function() countB = countB + 1 end)
            d.k = 1      -- both fire
            d:unwatch("k", fnA)
            d.k = 2      -- only fnB fires
            t.assert.eq(countA, 1)
            t.assert.eq(countB, 2)
        end)

        t.it("unwatch on non-existent key is safe", function()
            local d = Observable.new()
            t.assert.truthy(pcall(function()
                d:unwatch("ghost", function() end)
            end))
        end)
    end)

    -- ── clearWatchers ─────────────────────────────────────────────────────────
    t.describe("clearWatchers", function()
        t.it("removes all watchers for all keys", function()
            local d     = Observable.new()
            local count = 0
            d:watch("a", function() count = count + 1 end)
            d:watch("b", function() count = count + 1 end)
            d:clearWatchers()
            d.a = 1
            d.b = 1
            t.assert.eq(count, 0)
        end)
    end)

    -- ── raw ───────────────────────────────────────────────────────────────────
    t.describe("raw", function()
        t.it("returns the underlying plain table", function()
            local d = Observable.new({ x = 7 })
            d.y = 8
            local store = d:raw()
            t.assert.eq(store.x, 7)
            t.assert.eq(store.y, 8)
        end)

        t.it("raw table is not the proxy itself", function()
            local d = Observable.new()
            t.assert.falsy(d:raw() == d)
        end)
    end)

    -- ── reserved name protection ──────────────────────────────────────────────
    t.describe("reserved names", function()
        t.it("writing to 'watch' raises an error", function()
            local d = Observable.new()
            t.assert.falsy(pcall(function() d.watch = 1 end))
        end)

        t.it("writing to 'unwatch' raises an error", function()
            local d = Observable.new()
            t.assert.falsy(pcall(function() d.unwatch = 1 end))
        end)

        t.it("writing to 'clearWatchers' raises an error", function()
            local d = Observable.new()
            t.assert.falsy(pcall(function() d.clearWatchers = 1 end))
        end)

        t.it("writing to 'raw' raises an error", function()
            local d = Observable.new()
            t.assert.falsy(pcall(function() d.raw = 1 end))
        end)
    end)

    -- ── re-entrant / snapshot safety ──────────────────────────────────────────
    t.describe("re-entrant safety (snapshot semantics)", function()
        t.it("watcher added inside notify does NOT fire in current cycle", function()
            local d     = Observable.new()
            local count = 0
            d:watch("n", function()
                count = count + 1
                -- Add another watcher mid-notify; it should NOT fire this cycle
                d:watch("n", function() count = count + 100 end)
            end)
            d.n = 1     -- count should be 1, not 101
            t.assert.eq(count, 1)
        end)

        t.it("watcher removed inside notify still fires current cycle for already-scheduled ones", function()
            local d     = Observable.new()
            local count = 0
            local fnB
            d:watch("n", function()
                count = count + 1
                -- Remove fnB while it is still in the original list
                if fnB then d:unwatch("n", fnB) end
            end)
            fnB = d:watch("n", function() count = count + 10 end)
            -- Both are captured in snapshot before iteration,
            -- so fnB was already in the snapshot and WILL fire this cycle.
            d.n = 1
            t.assert.eq(count, 11)
            -- Next cycle fnB is gone
            d.n = 2
            t.assert.eq(count, 12)   -- only first watcher fires (adds 1)
        end)
    end)

    -- ── init table does not trigger watchers ──────────────────────────────────
    t.describe("init semantics", function()
        t.it("initial values do not trigger watchers registered before first write", function()
            local d     = Observable.new({ score = 0 })
            local count = 0
            d:watch("score", function() count = count + 1 end)
            -- Re-writing same initial value must not fire (old == new)
            d.score = 0
            t.assert.eq(count, 0)
        end)

        t.it("writing a different value after init does trigger watcher", function()
            local d     = Observable.new({ score = 0 })
            local count = 0
            d:watch("score", function() count = count + 1 end)
            d.score = 1
            t.assert.eq(count, 1)
        end)
    end)

end)

local T = require("tools.test_runner")
local Tweens = require("core.animation")

T.describe("Tween easing functions", function()
    -- Test via tween behavior since easings are local

    T.it("linear tween reaches exact end value", function()
        Tweens.clear()
        local obj = {x = 0}
        Tweens.add(obj, "x", 100, 1.0, "linear")
        Tweens.update(1.0)
        T.assert_equal(obj.x, 100)
    end)

    T.it("easeOutQuad tween reaches exact end value", function()
        Tweens.clear()
        local obj = {x = 0}
        Tweens.add(obj, "x", 50, 0.5, "easeOutQuad")
        Tweens.update(0.5)
        T.assert_equal(obj.x, 50)
    end)

    T.it("easeOutBounce tween reaches exact end value", function()
        Tweens.clear()
        local obj = {y = 100}
        Tweens.add(obj, "y", 200, 0.3, "easeOutBounce")
        Tweens.update(0.3)
        T.assert_equal(obj.y, 200)
    end)
end)

T.describe("Tween lifecycle", function()
    T.it("tween is active while animating", function()
        Tweens.clear()
        local obj = {x = 0}
        Tweens.add(obj, "x", 100, 1.0, "linear")
        T.assert_true(Tweens.isActive())
    end)

    T.it("tween is inactive after completion", function()
        Tweens.clear()
        local obj = {x = 0}
        Tweens.add(obj, "x", 100, 1.0, "linear")
        Tweens.update(1.0)
        T.assert_false(Tweens.isActive())
    end)

    T.it("onComplete callback is fired", function()
        Tweens.clear()
        local obj = {x = 0}
        local called = false
        Tweens.add(obj, "x", 100, 0.5, "linear", function() called = true end)
        Tweens.update(0.5)
        T.assert_true(called, "callback should have been called")
    end)

    T.it("partial update interpolates correctly", function()
        Tweens.clear()
        local obj = {x = 0}
        Tweens.add(obj, "x", 100, 1.0, "linear")
        Tweens.update(0.5)
        T.assert_near(obj.x, 50, 0.01)
    end)

    T.it("clear removes all tweens", function()
        Tweens.clear()
        local obj = {x = 0}
        Tweens.add(obj, "x", 100, 1.0, "linear")
        Tweens.clear()
        T.assert_false(Tweens.isActive())
    end)
end)

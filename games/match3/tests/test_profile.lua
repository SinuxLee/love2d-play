local T = require("tools.test_runner")
local Profile = require("systems.profile")

-- ============================================================
-- Constructor
-- ============================================================

T.describe("Profile.new", function()
    T.it("creates profile with default values", function()
        local p = Profile.new()
        T.assert_near(p.scoreEfficiency, 0.5)
        T.assert_near(p.moveEfficiency, 0.5)
        T.assert_near(p.comboSkill, 0.0)
        T.assert_near(p.specialSkill, 0.0)
        T.assert_near(p.passRate, 0.5)
        T.assert_near(p.frustration, 0.0)
        T.assert_equal(p.archetype, "normal")
        T.assert_equal(p.totalAttempts, 0)
        T.assert_false(p.calibrated)
    end)
end)

-- ============================================================
-- EMA helper
-- ============================================================

T.describe("Profile.ema", function()
    T.it("returns weighted average", function()
        T.assert_near(Profile.ema(0.5, 1.0, 0.15), 0.575)
    end)

    T.it("alpha=1 returns observation", function()
        T.assert_near(Profile.ema(0.5, 1.0, 1.0), 1.0)
    end)

    T.it("alpha=0 returns old value", function()
        T.assert_near(Profile.ema(0.5, 1.0, 0.0), 0.5)
    end)
end)

T.describe("Profile.clamp", function()
    T.it("clamps below", function()
        T.assert_near(Profile.clamp(0, 1, -0.5), 0)
    end)

    T.it("clamps above", function()
        T.assert_near(Profile.clamp(0, 1, 1.5), 1)
    end)

    T.it("passes through in range", function()
        T.assert_near(Profile.clamp(0, 1, 0.5), 0.5)
    end)
end)

-- ============================================================
-- Core update
-- ============================================================

T.describe("Profile:update", function()
    T.it("increments totalAttempts", function()
        local p = Profile.new()
        p:update({
            score = 1000, targetScore = 1000, movesUsed = 10,
            maxMoves = 15, maxCombo = 3, specialsCreated = 2, passed = true,
        })
        T.assert_equal(p.totalAttempts, 1)
    end)

    T.it("updates EMA features toward observations", function()
        local p = Profile.new()
        -- Perfect pass: scoreRatio=1.5, moveRatio=0.5, combo=1.0, special=1.0
        p:update({
            score = 1500, targetScore = 1000, movesUsed = 10,
            maxMoves = 20, maxCombo = 5, specialsCreated = 4, passed = true,
        })
        -- scoreRatio clamped to 1.5, ema(0.5, 1.5, 0.15) = 0.65
        T.assert_near(p.scoreEfficiency, 0.65, 0.01)
        -- moveRatio = 0.5, ema(0.5, 0.5, 0.15) = 0.5
        T.assert_near(p.moveEfficiency, 0.5, 0.01)
        -- comboNorm = 5/5 = 1.0, ema(0.0, 1.0, 0.15) = 0.15
        T.assert_near(p.comboSkill, 0.15, 0.01)
        -- specialNorm = 4/4 = 1.0, ema(0.0, 1.0, 0.15) = 0.15
        T.assert_near(p.specialSkill, 0.15, 0.01)
        -- passVal = 1.0, ema(0.5, 1.0, 0.15) = 0.575
        T.assert_near(p.passRate, 0.575, 0.01)
    end)

    T.it("increases frustration on genuine fail", function()
        local p = Profile.new()
        -- Genuine fail: scoreRatio > 0.3 and moveRatio > 0.5
        p:update({
            score = 500, targetScore = 1000, movesUsed = 12,
            maxMoves = 15, maxCombo = 1, specialsCreated = 0, passed = false,
        })
        T.assert_near(p.frustration, 0.15, 0.01)
    end)

    T.it("does not increase frustration on sandbagging", function()
        local p = Profile.new()
        -- Sandbagging: scoreRatio < 0.3 (intentionally low score)
        p:update({
            score = 100, targetScore = 1000, movesUsed = 2,
            maxMoves = 15, maxCombo = 0, specialsCreated = 0, passed = false,
        })
        T.assert_near(p.frustration, 0.0, 0.01)
    end)

    T.it("decays frustration on pass", function()
        local p = Profile.new()
        p.frustration = 0.5
        p:update({
            score = 1000, targetScore = 1000, movesUsed = 10,
            maxMoves = 15, maxCombo = 2, specialsCreated = 1, passed = true,
        })
        T.assert_near(p.frustration, 0.3, 0.01)
    end)

    T.it("tracks consecutiveLowScores for sandbagging", function()
        local p = Profile.new()
        for _ = 1, 3 do
            p:update({
                score = 50, targetScore = 1000, movesUsed = 1,
                maxMoves = 15, maxCombo = 0, specialsCreated = 0, passed = false,
            })
        end
        T.assert_equal(p.consecutiveLowScores, 3)
    end)

    T.it("resets consecutiveLowScores on decent attempt", function()
        local p = Profile.new()
        p.consecutiveLowScores = 5
        p:update({
            score = 800, targetScore = 1000, movesUsed = 10,
            maxMoves = 15, maxCombo = 2, specialsCreated = 1, passed = true,
        })
        T.assert_equal(p.consecutiveLowScores, 0)
    end)
end)

-- ============================================================
-- Genuine fail detection
-- ============================================================

T.describe("Profile:isGenuineFail", function()
    T.it("returns true for borderline fail", function()
        local p = Profile.new()
        T.assert_true(p:isGenuineFail({
            score = 500, targetScore = 1000, movesUsed = 10, maxMoves = 15,
            maxCombo = 0, specialsCreated = 0, passed = false,
        }))
    end)

    T.it("returns false for sandbagging (low score)", function()
        local p = Profile.new()
        T.assert_false(p:isGenuineFail({
            score = 100, targetScore = 1000, movesUsed = 10, maxMoves = 15,
            maxCombo = 0, specialsCreated = 0, passed = false,
        }))
    end)

    T.it("returns false for sandbagging (few moves)", function()
        local p = Profile.new()
        T.assert_false(p:isGenuineFail({
            score = 500, targetScore = 1000, movesUsed = 2, maxMoves = 15,
            maxCombo = 0, specialsCreated = 0, passed = false,
        }))
    end)
end)

-- ============================================================
-- Skill score & archetype classification
-- ============================================================

T.describe("Profile:recomputeSkillScore", function()
    T.it("classifies casual for low skill", function()
        local p = Profile.new()
        p.scoreEfficiency = 0.2
        p.moveEfficiency = 0.9
        p.comboSkill = 0.1
        p.specialSkill = 0.0
        p.passRate = 0.1
        p:recomputeSkillScore()
        T.assert_equal(p.archetype, "casual")
        T.assert_true(p.skillScore < 0.30)
    end)

    T.it("classifies normal for medium skill", function()
        local p = Profile.new()
        p.scoreEfficiency = 0.5
        p.moveEfficiency = 0.5
        p.comboSkill = 0.3
        p.specialSkill = 0.2
        p.passRate = 0.5
        p:recomputeSkillScore()
        T.assert_equal(p.archetype, "normal")
    end)

    T.it("classifies expert for high skill", function()
        local p = Profile.new()
        p.scoreEfficiency = 1.0
        p.moveEfficiency = 0.1
        p.comboSkill = 1.0
        p.specialSkill = 1.0
        p.passRate = 1.0
        p:recomputeSkillScore()
        T.assert_equal(p.archetype, "expert")
        T.assert_true(p.skillScore >= 0.80)
    end)
end)

-- ============================================================
-- Quick calibration
-- ============================================================

T.describe("Profile:tryCalibrate", function()
    T.it("returns false before 3 attempts", function()
        local p = Profile.new()
        p:update({
            score = 1000, targetScore = 1000, movesUsed = 10,
            maxMoves = 15, maxCombo = 2, specialsCreated = 1, passed = true,
        })
        local calibrated = p:tryCalibrate()
        T.assert_false(calibrated)
    end)

    T.it("detects experienced player (challenge)", function()
        local p = Profile.new()
        for _ = 1, 3 do
            p:update({
                score = 1500, targetScore = 1000, movesUsed = 8,
                maxMoves = 15, maxCombo = 4, specialsCreated = 2, passed = true,
            })
        end
        local calibrated, direction = p:tryCalibrate()
        T.assert_true(calibrated)
        T.assert_equal(direction, "challenge")
    end)

    T.it("detects novice player (assist)", function()
        local p = Profile.new()
        for _ = 1, 3 do
            p:update({
                score = 400, targetScore = 1000, movesUsed = 15,
                maxMoves = 15, maxCombo = 1, specialsCreated = 0, passed = false,
            })
        end
        local calibrated, direction = p:tryCalibrate()
        T.assert_true(calibrated)
        T.assert_equal(direction, "assist")
    end)

    T.it("returns neutral for average player", function()
        local p = Profile.new()
        for _ = 1, 3 do
            p:update({
                score = 900, targetScore = 1000, movesUsed = 12,
                maxMoves = 15, maxCombo = 2, specialsCreated = 1, passed = true,
            })
        end
        local calibrated, direction = p:tryCalibrate()
        T.assert_true(calibrated)
        T.assert_equal(direction, "neutral")
    end)

    T.it("only calibrates once", function()
        local p = Profile.new()
        for _ = 1, 3 do
            p:update({
                score = 1500, targetScore = 1000, movesUsed = 8,
                maxMoves = 15, maxCombo = 4, specialsCreated = 2, passed = true,
            })
        end
        p:tryCalibrate()
        T.assert_true(p.calibrated)
        local again = p:tryCalibrate()
        T.assert_false(again)
    end)
end)

-- ============================================================
-- Move time tracking
-- ============================================================

T.describe("Profile:updateMoveTime", function()
    T.it("updates avgMoveTime via EMA", function()
        local p = Profile.new()
        T.assert_near(p.avgMoveTime, 3.0)
        p:updateMoveTime(5.0)
        -- ema(3.0, 5.0, 0.1) = 3.2
        T.assert_near(p.avgMoveTime, 3.2, 0.01)
    end)

    T.it("clamps very long pauses", function()
        local p = Profile.new()
        p:updateMoveTime(120.0) -- afk, should clamp to 30
        -- ema(3.0, 30.0, 0.1) = 5.7
        T.assert_near(p.avgMoveTime, 5.7, 0.01)
    end)
end)

-- ============================================================
-- Serialization
-- ============================================================

T.describe("Profile serialization", function()
    T.it("round-trips profile data", function()
        local p = Profile.new()
        p.scoreEfficiency = 0.7
        p.frustration = 0.3
        p.archetype = "hardcore"
        p.totalAttempts = 25
        p.calibrated = true

        local data = p:serialize()
        local p2 = Profile.deserialize(data)

        T.assert_near(p2.scoreEfficiency, 0.7)
        T.assert_near(p2.frustration, 0.3)
        T.assert_equal(p2.archetype, "hardcore")
        T.assert_equal(p2.totalAttempts, 25)
        T.assert_true(p2.calibrated)
    end)

    T.it("deserialize handles nil gracefully", function()
        local p = Profile.deserialize(nil)
        T.assert_not_nil(p)
        T.assert_equal(p.archetype, "normal")
    end)
end)

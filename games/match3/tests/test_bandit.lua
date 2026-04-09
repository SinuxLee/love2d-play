local T = require("tools.test_runner")
local Bandit = require("systems.bandit")
local Profile = require("systems.profile")

-- ============================================================
-- Constructor
-- ============================================================

T.describe("Bandit.new", function()
    T.it("creates bandit with 4 tiers x 7 arms", function()
        local b = Bandit.new()
        T.assert_equal(#b.tiers, Bandit.NUM_TIERS)
        for tier = 1, Bandit.NUM_TIERS do
            T.assert_equal(#b.tiers[tier], Bandit.NUM_ARMS)
        end
    end)

    T.it("initializes arms with alpha=2, beta=2", function()
        local b = Bandit.new()
        T.assert_equal(b.tiers[1][1].alpha, 2)
        T.assert_equal(b.tiers[1][1].beta, 2)
    end)

    T.it("initializes skill estimator", function()
        local b = Bandit.new()
        T.assert_near(b.skill.mu, 10)
        T.assert_near(b.skill.sigma, 5)
    end)
end)

-- ============================================================
-- Beta sampling
-- ============================================================

T.describe("Bandit.betaSample", function()
    T.it("returns values in (0, 1)", function()
        for _ = 1, 50 do
            local s = Bandit.betaSample(2, 2)
            T.assert_true(s > 0 and s <= 1, "sample out of range: " .. tostring(s))
        end
    end)

    T.it("works with large alpha/beta", function()
        for _ = 1, 20 do
            local s = Bandit.betaSample(10, 10)
            T.assert_true(s > 0 and s <= 1, "sample out of range: " .. tostring(s))
        end
    end)

    T.it("mean of Beta(5,2) is approximately 0.71", function()
        local sum = 0
        local N = 500
        for _ = 1, N do
            sum = sum + Bandit.betaSample(5, 2)
        end
        local mean = sum / N
        -- Beta(5,2) theoretical mean = 5/7 ~ 0.714
        T.assert_near(mean, 0.714, 0.1)
    end)
end)

-- ============================================================
-- Tier classification
-- ============================================================

T.describe("Bandit.getTier", function()
    T.it("tutorial for 5 gem types", function()
        T.assert_equal(Bandit.getTier({ numGemTypes = 5 }), 1)
    end)

    T.it("normal for 6 gem types no modifiers", function()
        T.assert_equal(Bandit.getTier({ numGemTypes = 6 }), 2)
    end)

    T.it("hard for 7+ gem types", function()
        T.assert_equal(Bandit.getTier({ numGemTypes = 7 }), 3)
    end)

    T.it("hard for single hard modifier", function()
        T.assert_equal(Bandit.getTier({ numGemTypes = 6, modifiers = { "no_specials" } }), 3)
    end)

    T.it("extreme for 2+ hard modifiers", function()
        T.assert_equal(Bandit.getTier({
            numGemTypes = 6,
            modifiers = { "no_specials", "fragile" },
        }), 4)
    end)

    T.it("handles missing modifiers", function()
        T.assert_equal(Bandit.getTier({ numGemTypes = 6 }), 2)
    end)
end)

-- ============================================================
-- Arm selection
-- ============================================================

T.describe("Bandit:selectArm", function()
    T.it("returns a valid bias value", function()
        local b = Bandit.new()
        local p = Profile.new()
        local config = { numGemTypes = 6 }
        local bias, details = b:selectArm(p, config)
        T.assert_not_nil(bias)
        T.assert_true(bias >= -0.30 and bias <= 0.45,
            "bias out of range: " .. tostring(bias))
        T.assert_equal(details.tier, 2)
    end)

    T.it("safety valve forces easy arm on high frustration", function()
        local b = Bandit.new()
        local p = Profile.new()
        p.frustration = 0.9
        local config = { numGemTypes = 6 }

        -- Bias hard arms heavily so Thompson would pick them
        for i = 1, 3 do
            b.tiers[2][i].alpha = 100
        end
        for i = 5, Bandit.NUM_ARMS do
            b.tiers[2][i].alpha = 1
            b.tiers[2][i].beta = 100
        end

        local bias, details = b:selectArm(p, config)
        T.assert_true(details.safetyValve, "safety valve should activate")
        T.assert_true(bias >= 0.10, "bias should be >= 0.10 after safety valve")
    end)

    T.it("returns details table with expected fields", function()
        local b = Bandit.new()
        local p = Profile.new()
        local _, details = b:selectArm(p, { numGemTypes = 6 })
        T.assert_not_nil(details.tier)
        T.assert_not_nil(details.arm)
        T.assert_not_nil(details.bias)
        T.assert_not_nil(details.samples)
        T.assert_not_nil(details.priorAdj)
    end)
end)

-- ============================================================
-- Multi-lever fallback
-- ============================================================

T.describe("Bandit:applyFallback", function()
    T.it("does not activate below threshold", function()
        local b = Bandit.new()
        b.lastArm = Bandit.NUM_ARMS -- at max arm
        local config = { targetScore = 1000, maxMoves = 15 }
        T.assert_false(b:applyFallback(config, 2))
        T.assert_equal(config.targetScore, 1000)
    end)

    T.it("does not activate if not at max arm", function()
        local b = Bandit.new()
        b.lastArm = 4
        local config = { targetScore = 1000, maxMoves = 15 }
        T.assert_false(b:applyFallback(config, 5))
    end)

    T.it("activates at max arm with 3 fails", function()
        local b = Bandit.new()
        b.lastArm = Bandit.NUM_ARMS
        local config = { targetScore = 1000, maxMoves = 15 }
        T.assert_true(b:applyFallback(config, 3))
        T.assert_true(config.targetScore < 1000, "target should be reduced")
        T.assert_true(config.maxMoves > 15, "moves should be increased")
    end)

    T.it("increases help with more fails", function()
        local b = Bandit.new()
        b.lastArm = Bandit.NUM_ARMS

        local config3 = { targetScore = 1000, maxMoves = 15 }
        b:applyFallback(config3, 3)

        local config5 = { targetScore = 1000, maxMoves = 15 }
        b:applyFallback(config5, 5)

        T.assert_true(config5.targetScore <= config3.targetScore,
            "more fails should give more target reduction")
    end)

    T.it("stores fallback info", function()
        local b = Bandit.new()
        b.lastArm = Bandit.NUM_ARMS
        local config = { targetScore = 1000, maxMoves = 15 }
        b:applyFallback(config, 3)
        T.assert_true(b.useFallback)
        T.assert_not_nil(b.fallbackInfo.targetReduction)
        T.assert_not_nil(b.fallbackInfo.bonusMoves)
    end)
end)

-- ============================================================
-- Reward computation
-- ============================================================

T.describe("Bandit.computeReward", function()
    T.it("peaks near archetype center", function()
        local p = Profile.new()
        p.archetype = "normal" -- center = 1.05
        local attempt = { score = 1050, targetScore = 1000, maxCombo = 0, passed = true }
        local reward = Bandit.computeReward(attempt, p)
        T.assert_true(reward > 0.9, "reward at center should be high: " .. tostring(reward))
    end)

    T.it("penalizes very low scores", function()
        local p = Profile.new()
        p.archetype = "normal"
        local attempt = { score = 300, targetScore = 1000, maxCombo = 0, passed = false }
        local reward = Bandit.computeReward(attempt, p)
        T.assert_true(reward < 0.3, "reward for bad score should be low: " .. tostring(reward))
    end)

    T.it("gives combo bonus", function()
        local p = Profile.new()
        p.archetype = "normal"
        -- Use off-center score so flowReward < 1.0, leaving room for combo bonus
        local base = { score = 700, targetScore = 1000, maxCombo = 0, passed = false }
        local combo = { score = 700, targetScore = 1000, maxCombo = 5, passed = false }
        local r1 = Bandit.computeReward(base, p)
        local r2 = Bandit.computeReward(combo, p)
        T.assert_true(r2 > r1, "combo should increase reward")
    end)

    T.it("returns breakdown table", function()
        local p = Profile.new()
        local attempt = { score = 800, targetScore = 1000, maxCombo = 2, passed = false }
        local _, breakdown = Bandit.computeReward(attempt, p)
        T.assert_not_nil(breakdown.flowReward)
        T.assert_not_nil(breakdown.frustPenalty)
        T.assert_not_nil(breakdown.comboBonus)
        T.assert_not_nil(breakdown.scoreRatio)
    end)

    T.it("reward is always in [0, 1]", function()
        local p = Profile.new()
        -- Extreme high
        local r1 = Bandit.computeReward(
            { score = 5000, targetScore = 100, maxCombo = 10, passed = true }, p)
        T.assert_true(r1 >= 0 and r1 <= 1)
        -- Extreme low
        local r2 = Bandit.computeReward(
            { score = 0, targetScore = 1000, maxCombo = 0, passed = false }, p)
        T.assert_true(r2 >= 0 and r2 <= 1)
    end)
end)

-- ============================================================
-- Arm update with decay
-- ============================================================

T.describe("Bandit:updateArm", function()
    T.it("increases alpha on high reward", function()
        local b = Bandit.new()
        b.lastTier = 2
        b.lastArm = 4
        local oldAlpha = b.tiers[2][4].alpha
        b:updateArm(1.0)
        -- After decay: alpha * 0.95 + 1.0
        T.assert_true(b.tiers[2][4].alpha > oldAlpha * 0.9,
            "alpha should increase with reward=1")
    end)

    T.it("increases beta on low reward", function()
        local b = Bandit.new()
        b.lastTier = 2
        b.lastArm = 4
        local oldBeta = b.tiers[2][4].beta
        b:updateArm(0.0)
        -- After decay: beta * 0.95 + 1.0
        T.assert_true(b.tiers[2][4].beta > oldBeta * 0.9,
            "beta should increase with reward=0")
    end)

    T.it("decays all arms in tier", function()
        local b = Bandit.new()
        b.lastTier = 1
        b.lastArm = 1
        -- Set arm 3 to known values
        b.tiers[1][3].alpha = 10
        b.tiers[1][3].beta = 10
        b:updateArm(0.5)
        -- Arm 3 was not selected, so it only got decayed
        T.assert_near(b.tiers[1][3].alpha, 10 * 0.95, 0.01)
        T.assert_near(b.tiers[1][3].beta, 10 * 0.95, 0.01)
    end)
end)

-- ============================================================
-- Skill estimator
-- ============================================================

T.describe("Bandit:updateSkill", function()
    T.it("increases mu on unexpected pass", function()
        local b = Bandit.new()
        b.skill.mu = 5
        b.skill.sigma = 3
        -- Pass level 20 (way above mu=5 → big surprise)
        b:updateSkill(20, true)
        T.assert_true(b.skill.mu > 5, "mu should increase on unexpected pass")
    end)

    T.it("decreases mu on unexpected fail", function()
        local b = Bandit.new()
        b.skill.mu = 20
        b.skill.sigma = 3
        -- Fail level 5 (way below mu=20 → unexpected)
        b:updateSkill(5, false)
        T.assert_true(b.skill.mu < 20, "mu should decrease on unexpected fail")
    end)

    T.it("sigma shrinks on expected outcomes", function()
        local b = Bandit.new()
        b.skill.mu = 10
        b.skill.sigma = 5
        local oldSigma = b.skill.sigma
        -- Pass level 5 (below mu → expected pass)
        b:updateSkill(5, true)
        T.assert_true(b.skill.sigma < oldSigma, "sigma should shrink on expected outcome")
    end)
end)

-- ============================================================
-- Calibration prior shift
-- ============================================================

T.describe("Bandit:shiftPriors", function()
    T.it("neutral does nothing", function()
        local b = Bandit.new()
        local before = b.tiers[1][1].alpha
        b:shiftPriors("neutral")
        T.assert_equal(b.tiers[1][1].alpha, before)
    end)

    T.it("challenge boosts hard arms", function()
        local b = Bandit.new()
        local before = b.tiers[1][1].alpha
        b:shiftPriors("challenge")
        T.assert_equal(b.tiers[1][1].alpha, before + 3)
        -- Easy arms get beta boost
        T.assert_equal(b.tiers[1][5].beta, 2 + 2)
    end)

    T.it("assist boosts easy arms", function()
        local b = Bandit.new()
        local before = b.tiers[1][6].alpha
        b:shiftPriors("assist")
        T.assert_equal(b.tiers[1][6].alpha, before + 3)
        -- Hard arms get beta boost
        T.assert_equal(b.tiers[1][1].beta, 2 + 2)
    end)

    T.it("applies to all tiers", function()
        local b = Bandit.new()
        b:shiftPriors("challenge")
        for tier = 1, Bandit.NUM_TIERS do
            T.assert_equal(b.tiers[tier][1].alpha, 2 + 3)
        end
    end)
end)

-- ============================================================
-- Serialization
-- ============================================================

T.describe("Bandit serialization", function()
    T.it("round-trips state", function()
        local b = Bandit.new()
        b.tiers[2][3].alpha = 8.5
        b.tiers[2][3].beta = 4.2
        b.lastTier = 3
        b.lastArm = 5
        b.skill.mu = 15
        b.skill.sigma = 2.5

        local data = b:serialize()
        local b2 = Bandit.deserialize(data)

        T.assert_near(b2.tiers[2][3].alpha, 8.5)
        T.assert_near(b2.tiers[2][3].beta, 4.2)
        T.assert_equal(b2.lastTier, 3)
        T.assert_equal(b2.lastArm, 5)
        T.assert_near(b2.skill.mu, 15)
        T.assert_near(b2.skill.sigma, 2.5)
    end)

    T.it("deserialize handles nil gracefully", function()
        local b = Bandit.deserialize(nil)
        T.assert_not_nil(b)
        T.assert_equal(#b.tiers, Bandit.NUM_TIERS)
    end)

    T.it("deserialize handles partial data", function()
        local b = Bandit.deserialize({ lastTier = 3, skillMu = 12 })
        T.assert_equal(b.lastTier, 3)
        T.assert_near(b.skill.mu, 12)
        T.assert_near(b.skill.sigma, 5) -- default
    end)
end)

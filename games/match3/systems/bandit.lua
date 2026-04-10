---@diagnostic disable: undefined-global

--- Thompson Sampling multi-armed bandit for adaptive difficulty.
--- Bucketed by difficulty tier (4 tiers × 7 arms).
--- Includes Bayesian skill estimator and multi-lever fallback.

local Profile = require("systems.profile")

---@class BanditArm
---@field alpha number  Beta distribution alpha (successes)
---@field beta number   Beta distribution beta (failures)

---@class SkillEstimator
---@field mu number     mean estimate of skill level
---@field sigma number  uncertainty (std dev)

---@class DifficultyBandit
---@field tiers table<integer, BanditArm[]>  per-tier arm states
---@field biasValues number[]
---@field lastTier integer
---@field lastArm integer
---@field lastSamples number[]
---@field decay number
---@field skill SkillEstimator
---@field useFallback boolean   true if fallback was triggered this level
---@field fallbackInfo table    details of fallback adjustments
local Bandit = {}
Bandit.__index = Bandit

-- ============================================================
-- Constants
-- ============================================================

local BIAS_VALUES = { -0.30, -0.15, -0.05, 0.00, 0.10, 0.25, 0.45 }
local NUM_ARMS = #BIAS_VALUES
local NUM_TIERS = 4
local DECAY = 0.95
local INITIAL_ALPHA = 2
local INITIAL_BETA = 2

-- Difficulty tier definitions
-- 1=tutorial, 2=normal, 3=hard, 4=extreme
local HARD_MODIFIERS = { no_specials = true, fragile = true, small_board = true }

-- ============================================================
-- Constructor
-- ============================================================

---@return DifficultyBandit
function Bandit.new()
    local self = setmetatable({}, Bandit)
    self.tiers = {}
    for tier = 1, NUM_TIERS do
        self.tiers[tier] = {}
        for i = 1, NUM_ARMS do
            self.tiers[tier][i] = { alpha = INITIAL_ALPHA, beta = INITIAL_BETA }
        end
    end
    self.biasValues = BIAS_VALUES
    self.lastTier = 2
    self.lastArm = 4 -- neutral
    self.lastSamples = {}
    self.decay = DECAY
    self.skill = { mu = 10, sigma = 5 }
    self.useFallback = false
    self.fallbackInfo = {}
    return self
end

-- ============================================================
-- Difficulty tier classification
-- ============================================================

---Determine difficulty tier for a level config
---@param config table LevelConfig
---@return integer tier 1-4
function Bandit.getTier(config)
    local hardCount = 0
    if config.modifiers then
        for _, m in ipairs(config.modifiers) do
            if HARD_MODIFIERS[m] then hardCount = hardCount + 1 end
        end
    end
    local gems = config.numGemTypes or 5
    if gems <= 5 then return 1 end          -- tutorial
    if hardCount >= 2 then return 4 end      -- extreme
    if hardCount >= 1 or gems >= 7 then return 3 end -- hard
    return 2                                  -- normal
end

-- ============================================================
-- Beta distribution sampling (Joehnk's algorithm)
-- ============================================================

---Sample from Beta(alpha, beta) distribution
---@param a number alpha >= 1
---@param b number beta >= 1
---@return number sample in (0, 1)
function Bandit.betaSample(a, b)
    -- Joehnk's method: for a,b >= 1 converges in ~2-3 iterations
    for _ = 1, 100 do -- safety limit
        local u1 = math.random() ^ (1 / a)
        local u2 = math.random() ^ (1 / b)
        local sum = u1 + u2
        if sum <= 1.0 and sum > 0 then
            return u1 / sum
        end
    end
    -- Fallback: shouldn't reach here with a,b >= 1
    return 0.5
end

-- ============================================================
-- Arm selection (Thompson Sampling)
-- ============================================================

---Select an arm using Thompson Sampling with profile priors
---@param profile PlayerProfile
---@param config table LevelConfig
---@return number bias the selected bias value
---@return table details {tier, arm, samples, priorAdj, safetyValve}
function Bandit:selectArm(profile, config)
    local tier = Bandit.getTier(config)
    self.lastTier = tier
    self.useFallback = false
    self.fallbackInfo = {}

    local arms = self.tiers[tier]
    local samples = {}
    local priorAdj = "none"

    for i = 1, NUM_ARMS do
        local a = arms[i].alpha
        local b = arms[i].beta

        -- Profile-based prior adjustment
        if profile.frustration > 0.5 and i >= 5 then
            a = a + profile.frustration * 2
            priorAdj = "frustration_boost_easy"
        end
        if profile.skillScore > 0.7 and i <= 3 then
            a = a + (profile.skillScore - 0.5) * 2
            priorAdj = "skill_boost_hard"
        end

        samples[i] = Bandit.betaSample(math.max(1, a), math.max(1, b))
    end

    -- Pick arm with highest sample
    local bestArm, bestVal = 1, -1
    for i = 1, NUM_ARMS do
        if samples[i] > bestVal then
            bestVal = samples[i]
            bestArm = i
        end
    end

    -- Safety valve: force minimum assist when very frustrated
    local safetyValve = false
    if profile.frustration > 0.8 and bestArm < 5 then
        bestArm = 5 -- force at least +0.10
        safetyValve = true
    end

    self.lastArm = bestArm
    self.lastSamples = samples

    local details = {
        tier = tier,
        arm = bestArm,
        bias = BIAS_VALUES[bestArm],
        samples = samples,
        priorAdj = priorAdj,
        safetyValve = safetyValve,
    }

    return BIAS_VALUES[bestArm], details
end

-- ============================================================
-- Multi-lever fallback
-- ============================================================

---Check and apply fallback when bias alone can't help.
---Mutates config in-place. Call after selectArm.
---@param config table LevelConfig (mutable)
---@param failCount integer consecutive fails on this level
---@return boolean activated
function Bandit:applyFallback(config, failCount)
    -- Only activate if at highest bias arm AND consecutive fails >= 3
    if self.lastArm < NUM_ARMS or failCount < 3 then
        self.useFallback = false
        self.fallbackInfo = {}
        return false
    end

    local extraFails = failCount - 2 -- 1 at failCount=3, 2 at failCount=4, etc.
    local targetMult = math.max(0.75, 1.0 - 0.10 - 0.05 * (extraFails - 1))
    local bonusMoves = math.min(4, 2 * math.floor(extraFails / 2 + 0.5))

    local origTarget = config.targetScore
    local origMoves = config.maxMoves

    config.targetScore = math.floor(config.targetScore * targetMult)
    config.maxMoves = config.maxMoves + bonusMoves

    self.useFallback = true
    self.fallbackInfo = {
        targetReduction = origTarget - config.targetScore,
        bonusMoves = bonusMoves,
        targetMult = targetMult,
        failCount = failCount,
    }

    return true
end

-- ============================================================
-- Reward computation (adaptive per archetype)
-- ============================================================

---Compute engagement reward for a level attempt
---@param attempt table {score, targetScore, maxCombo, passed}
---@param profile PlayerProfile
---@return number reward 0-1
---@return table breakdown {flowReward, frustPenalty, comboBonus}
function Bandit.computeReward(attempt, profile)
    local scoreRatio = attempt.score / math.max(1, attempt.targetScore)
    local params = Profile.rewardParams[profile.archetype] or Profile.rewardParams.normal

    -- Bell curve centered at archetype-specific optimum
    local diff = scoreRatio - params.center
    local flowReward = math.exp(-(diff * diff) / (2 * params.sigma * params.sigma))

    -- Anti-frustration penalty
    local frustPenalty = 0
    if scoreRatio < 0.6 then
        frustPenalty = (0.6 - scoreRatio) * 0.5
    end

    -- Combo excitement bonus
    local comboBonus = math.min(0.15, (attempt.maxCombo or 0) * 0.03)

    local reward = math.max(0, math.min(1, flowReward - frustPenalty + comboBonus))

    return reward, {
        flowReward = flowReward,
        frustPenalty = frustPenalty,
        comboBonus = comboBonus,
        scoreRatio = scoreRatio,
        center = params.center,
        sigma = params.sigma,
    }
end

-- ============================================================
-- Arm update
-- ============================================================

---Update the selected arm with observed reward
---@param reward number 0-1
function Bandit:updateArm(reward)
    local arms = self.tiers[self.lastTier]

    -- Decay all arms in this tier (non-stationarity)
    for i = 1, NUM_ARMS do
        arms[i].alpha = math.max(1, arms[i].alpha * self.decay)
        arms[i].beta = math.max(1, arms[i].beta * self.decay)
    end

    -- Update selected arm
    local arm = arms[self.lastArm]
    arm.alpha = arm.alpha + reward
    arm.beta = arm.beta + (1 - reward)
end

-- ============================================================
-- Skill estimator (Elo-like Bayesian)
-- ============================================================

---Update skill estimate after a level attempt
---@param levelNum integer
---@param passed boolean
function Bandit:updateSkill(levelNum, passed)
    local s = self.skill
    local expected = 1.0 / (1.0 + math.exp(-(s.mu - levelNum) / math.max(0.5, s.sigma)))
    local outcome = passed and 1.0 or 0.0
    local surprise = outcome - expected

    local K = s.sigma * 0.3
    s.mu = s.mu + K * surprise

    if math.abs(surprise) < 0.3 then
        s.sigma = math.max(1.0, s.sigma * 0.98)
    else
        s.sigma = math.min(15.0, s.sigma * 1.02)
    end
end

-- ============================================================
-- Calibration prior shift
-- ============================================================

---Shift bandit priors based on quick calibration result
---@param direction string "challenge"|"assist"|"neutral"
function Bandit:shiftPriors(direction)
    if direction == "neutral" then return end

    for tier = 1, NUM_TIERS do
        local arms = self.tiers[tier]
        if direction == "challenge" then
            -- Boost challenging arms (0-2)
            for i = 1, 3 do
                arms[i].alpha = arms[i].alpha + 3
            end
            -- Suppress easy arms (5-7)
            for i = 5, NUM_ARMS do
                arms[i].beta = arms[i].beta + 2
            end
        elseif direction == "assist" then
            -- Boost easy arms (5-7)
            for i = 5, NUM_ARMS do
                arms[i].alpha = arms[i].alpha + 3
            end
            -- Suppress hard arms (1-3)
            for i = 1, 3 do
                arms[i].beta = arms[i].beta + 2
            end
        end
    end
end

-- ============================================================
-- Serialization
-- ============================================================

---Serialize bandit state to a plain table
---@return table
function Bandit:serialize()
    local tiersData = {}
    for tier = 1, NUM_TIERS do
        tiersData[tier] = {}
        for i = 1, NUM_ARMS do
            tiersData[tier][i] = {
                alpha = self.tiers[tier][i].alpha,
                beta = self.tiers[tier][i].beta,
            }
        end
    end
    return {
        tiers = tiersData,
        lastTier = self.lastTier,
        lastArm = self.lastArm,
        skillMu = self.skill.mu,
        skillSigma = self.skill.sigma,
    }
end

---Load bandit state from a plain table
---@param data table
---@return DifficultyBandit
function Bandit.deserialize(data)
    local self = Bandit.new()
    if not data then return self end

    if data.tiers then
        for tier = 1, NUM_TIERS do
            if data.tiers[tier] then
                for i = 1, NUM_ARMS do
                    if data.tiers[tier][i] then
                        self.tiers[tier][i].alpha = data.tiers[tier][i].alpha or INITIAL_ALPHA
                        self.tiers[tier][i].beta = data.tiers[tier][i].beta or INITIAL_BETA
                    end
                end
            end
        end
    end

    self.lastTier = data.lastTier or 2
    self.lastArm = data.lastArm or 4
    self.skill.mu = data.skillMu or 10
    self.skill.sigma = data.skillSigma or 5

    return self
end

-- ============================================================
-- Human-readable decision explanation (NL templates)
-- ============================================================

---Generate a natural language explanation of the last decision
---@param details table from selectArm
---@param profile PlayerProfile
---@return string
function Bandit.explainDecision(details, profile)
    local parts = {}

    -- Player description
    local archNames = { casual = "休闲", normal = "普通", hardcore = "核心", expert = "专家" }
    local archName = archNames[profile.archetype] or profile.archetype
    parts[#parts + 1] = string.format("%s玩家 (skill=%.2f)", archName, profile.skillScore)

    -- Safety valve
    if details.safetyValve then
        parts[#parts + 1] = "安全阀生效, 强制最低辅助"
        return table.concat(parts, ", ")
    end

    -- Frustration state
    if profile.frustration > 0.5 then
        parts[#parts + 1] = string.format("受挫(%.2f), 偏向辅助", profile.frustration)
    end

    -- Bias description
    local biasVal = details.bias
    local biasDesc
    if biasVal <= -0.15 then biasDesc = "挑战"
    elseif biasVal <= 0.05 then biasDesc = "中性"
    elseif biasVal <= 0.20 then biasDesc = "轻度辅助"
    else biasDesc = "强力辅助"
    end
    local biasStr = biasVal >= 0 and string.format("+%.2f", biasVal) or string.format("%.2f", biasVal)
    parts[#parts + 1] = string.format("bias=%s (%s)", biasStr, biasDesc)

    -- Arm selection reason
    parts[#parts + 1] = string.format("Arm#%d T%d", details.arm, details.tier)

    -- Prior adjustment
    if details.priorAdj ~= "none" then
        if details.priorAdj == "frustration_boost_easy" then
            parts[#parts + 1] = "先验偏向辅助"
        elseif details.priorAdj == "skill_boost_hard" then
            parts[#parts + 1] = "先验偏向挑战"
        end
    end

    -- Fallback
    if details.fallback then
        parts[#parts + 1] = string.format("回退: -%dpts +%d步",
            details.fallback.targetReduction or 0,
            details.fallback.bonusMoves or 0)
    end

    return table.concat(parts, ", ")
end

-- Expose constants for testing
Bandit.BIAS_VALUES = BIAS_VALUES
Bandit.NUM_ARMS = NUM_ARMS
Bandit.NUM_TIERS = NUM_TIERS

return Bandit

---@diagnostic disable: undefined-global

--- Player profile system: EMA-based skill tracking, archetype classification,
--- quick calibration, and anti-sandbagging.

---@class PlayerProfile
---@field scoreEfficiency number  EMA of score/target ratio
---@field moveEfficiency number   EMA of movesUsed/maxMoves (lower=better)
---@field comboSkill number       EMA of maxCombo / 5
---@field specialSkill number     EMA of specialsCreated / 4
---@field passRate number         EMA of pass/fail binary
---@field frustration number      0-1, rises fast on fail, decays on pass
---@field avgMoveTime number      EMA of seconds per move
---@field skillScore number       0-1 composite skill estimate
---@field archetype string        "casual"|"normal"|"hardcore"|"expert"
---@field totalAttempts integer
---@field calibrated boolean      true after quick calibration (level 3)
---@field calibrationHistory table[] ring buffer of first 3 attempts
---@field consecutiveLowScores integer  for sandbagging detection
local Profile = {}
Profile.__index = Profile

-- ============================================================
-- Constants
-- ============================================================

local EMA_ALPHA = 0.15

-- Skill score weights (tunable via GM panel)
Profile.weights = {
    scoreEff = 0.30,
    moveEff = 0.25,
    combo = 0.20,
    special = 0.15,
    passRate = 0.10,
}

-- Archetype thresholds
local ARCHETYPE_THRESHOLDS = {
    { 0.30, "casual" },
    { 0.55, "normal" },
    { 0.80, "hardcore" },
    { 1.01, "expert" },
}

-- Adaptive reward centers per archetype (center, sigma)
Profile.rewardParams = {
    casual   = { center = 1.20, sigma = 0.35 },
    normal   = { center = 1.05, sigma = 0.30 },
    hardcore = { center = 1.00, sigma = 0.25 },
    expert   = { center = 0.95, sigma = 0.20 },
}

-- ============================================================
-- Constructor
-- ============================================================

---@return PlayerProfile
function Profile.new()
    local self = setmetatable({}, Profile)
    self.scoreEfficiency = 0.5
    self.moveEfficiency = 0.5
    self.comboSkill = 0.0
    self.specialSkill = 0.0
    self.passRate = 0.5
    self.frustration = 0.0
    self.avgMoveTime = 3.0
    self.skillScore = 0.5
    self.archetype = "normal"
    self.totalAttempts = 0
    self.calibrated = false
    self.calibrationHistory = {}
    self.consecutiveLowScores = 0
    return self
end

-- ============================================================
-- EMA helper
-- ============================================================

local function ema(old, observation, alpha)
    return alpha * observation + (1 - alpha) * old
end

local function clamp(lo, hi, val)
    if val < lo then return lo end
    if val > hi then return hi end
    return val
end

-- ============================================================
-- Core update
-- ============================================================

---@class AttemptData
---@field score integer
---@field targetScore integer
---@field movesUsed integer
---@field maxMoves integer
---@field maxCombo integer
---@field specialsCreated integer
---@field passed boolean

---Update profile from a level attempt
---@param attempt AttemptData
function Profile:update(attempt)
    self.totalAttempts = self.totalAttempts + 1

    local scoreRatio = clamp(0, 2, attempt.score / math.max(1, attempt.targetScore))
    local moveRatio = clamp(0, 1, attempt.movesUsed / math.max(1, attempt.maxMoves))
    local comboNorm = clamp(0, 1, attempt.maxCombo / 5)
    local specialNorm = clamp(0, 1, attempt.specialsCreated / 4)
    local passVal = attempt.passed and 1.0 or 0.0

    self.scoreEfficiency = ema(self.scoreEfficiency, scoreRatio, EMA_ALPHA)
    self.moveEfficiency = ema(self.moveEfficiency, moveRatio, EMA_ALPHA)
    self.comboSkill = ema(self.comboSkill, comboNorm, EMA_ALPHA)
    self.specialSkill = ema(self.specialSkill, specialNorm, EMA_ALPHA)
    self.passRate = ema(self.passRate, passVal, EMA_ALPHA)

    -- Frustration: rises fast on genuine fail, decays on pass
    if not attempt.passed then
        if self:isGenuineFail(attempt) then
            self.frustration = math.min(1.0, self.frustration + 0.15)
        end
        -- else: sandbagging, don't increase frustration
    else
        self.frustration = self.frustration * 0.6
    end

    -- Sandbagging detection
    if scoreRatio < 0.2 then
        self.consecutiveLowScores = self.consecutiveLowScores + 1
    else
        self.consecutiveLowScores = 0
    end

    -- Recompute composite
    self:recomputeSkillScore()

    -- Calibration: collect first 3 attempts
    if not self.calibrated then
        table.insert(self.calibrationHistory, {
            scoreRatio = scoreRatio,
            maxCombo = attempt.maxCombo,
            passed = attempt.passed,
        })
    end
end

---Check if a failure was genuine (not sandbagging)
---@param attempt AttemptData
---@return boolean
function Profile:isGenuineFail(attempt)
    local scoreRatio = attempt.score / math.max(1, attempt.targetScore)
    local moveRatio = attempt.movesUsed / math.max(1, attempt.maxMoves)
    return scoreRatio > 0.3 and moveRatio > 0.5
end

---Update average move time
---@param thinkTime number seconds since last swap
function Profile:updateMoveTime(thinkTime)
    -- Clamp to reasonable range (ignore very long pauses = afk)
    thinkTime = clamp(0.1, 30.0, thinkTime)
    self.avgMoveTime = ema(self.avgMoveTime, thinkTime, 0.1)
end

-- ============================================================
-- Skill score & archetype
-- ============================================================

function Profile:recomputeSkillScore()
    local w = Profile.weights
    self.skillScore = clamp(0, 1,
        w.scoreEff * self.scoreEfficiency +
        w.moveEff * (1.0 - self.moveEfficiency) +
        w.combo * self.comboSkill +
        w.special * self.specialSkill +
        w.passRate * self.passRate
    )

    -- Classify archetype
    for _, entry in ipairs(ARCHETYPE_THRESHOLDS) do
        if self.skillScore < entry[1] then
            self.archetype = entry[2]
            break
        end
    end
end

-- ============================================================
-- Quick calibration (after 3 levels)
-- ============================================================

---Attempt quick calibration. Returns true if calibration was applied, and mode ("challenge"|"assist"|"neutral").
---@return boolean calibrated
---@return "challenge"|"assist"|"neutral"|nil mode
function Profile:tryCalibrate()
    if self.calibrated then return false, nil end
    if #self.calibrationHistory < 3 then return false, nil end

    self.calibrated = true

    -- Compute averages from first 3 attempts
    local avgScore, avgCombo, passes = 0, 0, 0
    for _, h in ipairs(self.calibrationHistory) do
        avgScore = avgScore + h.scoreRatio
        avgCombo = avgCombo + h.maxCombo
        if h.passed then passes = passes + 1 end
    end
    avgScore = avgScore / 3
    avgCombo = avgCombo / 3

    -- Determine initial calibration result
    if avgScore > 1.3 and avgCombo >= 3 then
        -- Experienced player signal
        self.skillScore = 0.6
        self:recomputeSkillScore()
        return true, "challenge"
    elseif avgScore < 0.7 or passes == 0 then
        -- Novice signal
        self.skillScore = 0.2
        self:recomputeSkillScore()
        return true, "assist"
    end

    -- Middle ground: keep defaults
    return true, "neutral"
end

-- ============================================================
-- Serialization
-- ============================================================

---Serialize profile to a plain table (for Save system)
---@return table
function Profile:serialize()
    return {
        scoreEfficiency = self.scoreEfficiency,
        moveEfficiency = self.moveEfficiency,
        comboSkill = self.comboSkill,
        specialSkill = self.specialSkill,
        passRate = self.passRate,
        frustration = self.frustration,
        avgMoveTime = self.avgMoveTime,
        skillScore = self.skillScore,
        archetype = self.archetype,
        totalAttempts = self.totalAttempts,
        calibrated = self.calibrated,
    }
end

---Load profile from a plain table (nil returns default profile)
---@param data table|nil
---@return PlayerProfile
function Profile.deserialize(data)
    local self = Profile.new()
    if not data then return self end
    self.scoreEfficiency = data.scoreEfficiency or 0.5
    self.moveEfficiency = data.moveEfficiency or 0.5
    self.comboSkill = data.comboSkill or 0.0
    self.specialSkill = data.specialSkill or 0.0
    self.passRate = data.passRate or 0.5
    self.frustration = data.frustration or 0.0
    self.avgMoveTime = data.avgMoveTime or 3.0
    self.skillScore = data.skillScore or 0.5
    self.archetype = data.archetype or "normal"
    self.totalAttempts = data.totalAttempts or 0
    self.calibrated = data.calibrated or false
    self.calibrationHistory = {}
    self.consecutiveLowScores = 0
    return self
end

-- Expose helpers for testing
Profile.ema = ema
Profile.clamp = clamp

return Profile

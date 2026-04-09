local Grid = require("core.grid")
local Tweens = require("core.animation")
local Level = require("systems.level")
local Utils = require("core.utils")
local Save = require("systems.save")
local Modifiers = require("systems.modifiers")
local Logger = require("tools.logger")
local Profile = require("systems.profile")
local Bandit = require("systems.bandit")
local Hints = require("systems.hints")

---@type Effects?
local Effects = nil

---Lazy-load effects module (not available in test mode)
---@return Effects?
local function getEffects()
    if Effects == nil then
        if love and love.graphics and love.graphics.newCanvas then
            local ok, mod = pcall(require, "core.effects")
            Effects = ok and mod or false
        else
            Effects = false
        end
    end
    return Effects or nil
end

---DDA curve functions: maps failCount → bias offset, clamped to [-0.5, 0.5]
---@alias DdaCurveName "linear"|"quadratic"|"logarithmic"

---@type table<DdaCurveName, fun(n: integer): number>
local ddaCurves = {
    linear = function(n) return math.max(-0.5, math.min(0.6, 0.05 * n)) end,
    quadratic = function(n) return math.max(-0.5, math.min(0.6, 0.015 * n * n)) end,
    logarithmic = function(n) return math.max(-0.5, math.min(0.6, 0.12 * math.log(n + 1))) end,
}

---@class States
---@field current StateType
---@field score integer
---@field combo integer
---@field maxCombo integer          -- highest combo reached this level
---@field movesLeft integer
---@field swapR1? integer
---@field swapC1? integer
---@field swapR2? integer
---@field swapC2? integer
---@field pendingSpecials? SpecialSpawn[]
---@field isFirstCheck boolean  true for the first check after a swap (has swap context)
---@field failCount integer    consecutive fail count on current level (for DDA)
---@field ddaCurve DdaCurveName  current DDA curve algorithm
---@field nickInput string     current nick being typed
---@field nickMessage string   message shown on nick input screen
---@field collected table<integer, integer>  per-type gem collection count
---@field specialsCreated integer            specials created this level
---@field stars integer                      star rating for completed level (1-3)
local States = {}
States.current = "nick_input"
States.score = 0
States.combo = 0
States.maxCombo = 0
States.movesLeft = 0
States.swapR1 = nil
States.swapC1 = nil
States.swapR2 = nil
States.swapC2 = nil
States.pendingSpecials = nil
States.failCount = 0
States.isFirstCheck = false
States.ddaCurve = "linear"
States.nickInput = ""
States.nickMessage = ""
States.collected = {}
States.specialsCreated = 0
States.stars = 0

-- ML-DDA state
---@type PlayerProfile
States.mlProfile = Profile.new()
---@type DifficultyBandit
States.mlBandit = Bandit.new()
---@type boolean  true = use ML bandit, false = legacy DDA curves
States.mlEnabled = true
---@type table?  details from last Bandit:selectArm call
States.mlLastDecision = nil
---@type string?  NL explanation of last ML decision
States.mlDecisionText = nil
---@type number?  previous skillScore for trend indicator
States.mlPrevSkillScore = nil

---@type number  timestamp of last swap (for avgMoveTime)
local lastSwapTime = 0

---@type StateType?
local pendingTransition = nil

---Track gems collected by type from a matched set
---@param matched table<Gem, boolean>
local function trackCollected(matched)
    for gem in pairs(matched) do
        if gem.type and gem.type > 0 then
            States.collected[gem.type] = (States.collected[gem.type] or 0) + 1
        end
    end
end

---Track specials created
---@param specials SpecialSpawn[]
local function trackSpecials(specials)
    if specials then
        States.specialsCreated = States.specialsCreated + #specials
    end
end

---Check all objectives and return completion status
---@return boolean allComplete, boolean primaryComplete
function States.checkObjectives()
    local config = Level.current
    if not config.objectives or #config.objectives == 0 then
        -- Legacy: just check score
        return States.score >= config.targetScore, States.score >= config.targetScore
    end

    local primaryComplete = false
    local allComplete = true

    for i, obj in ipairs(config.objectives) do
        local met = false
        if obj.type == "score" then
            met = States.score >= obj.target
        elseif obj.type == "collect" then
            met = (States.collected[obj.gemType] or 0) >= obj.target
        elseif obj.type == "combo" then
            met = States.maxCombo >= obj.target
        elseif obj.type == "moves_left" then
            met = States.movesLeft >= obj.target
        elseif obj.type == "specials" then
            met = States.specialsCreated >= obj.target
        end

        if i == 1 then
            primaryComplete = met
        end
        if not met then
            allComplete = false
        end
    end

    return allComplete, primaryComplete
end

---Compute star rating
---@return integer stars 1-3
function States.computeStars()
    local allComplete, primaryComplete = States.checkObjectives()
    if not primaryComplete then return 0 end

    if allComplete then
        return 3
    end

    -- 2 stars if used <= 75% of moves
    local config = Level.current
    local movesUsed = config.maxMoves - States.movesLeft
    if movesUsed <= math.floor(config.maxMoves * 0.75) then
        return 2
    end

    return 1
end

---Snapshot current objective progress for logging
---@return table[]
local function snapshotObjectives()
    local config = Level.current
    if not config.objectives then return {} end
    local result = {}
    for _, obj in ipairs(config.objectives) do
        local cur = 0
        if obj.type == "score" then cur = States.score
        elseif obj.type == "collect" then cur = States.collected[obj.gemType] or 0
        elseif obj.type == "combo" then cur = States.maxCombo
        elseif obj.type == "moves_left" then cur = States.movesLeft
        elseif obj.type == "specials" then cur = States.specialsCreated
        end
        result[#result + 1] = {type = obj.type, current = cur, target = obj.target, done = cur >= obj.target}
    end
    return result
end

---@param newState StateType
function States.transition(newState)
    States.current = newState
    local config = Level.current
    local scoreMultiplier = config.scoreMultiplier or 1.0
    local hasCascadeKing = Modifiers.has(config.modifiers, "cascade_king")

    if newState == "swapping" then
        States.movesLeft = States.movesLeft - 1
        Grid.animateSwap(States.swapR1, States.swapC1, States.swapR2, States.swapC2, function()
            pendingTransition = "checking"
        end)

    elseif newState == "reverting" then
        States.movesLeft = States.movesLeft + 1
        Grid.swap(States.swapR1, States.swapC1, States.swapR2, States.swapC2)
        Grid.animateSwap(States.swapR1, States.swapC1, States.swapR2, States.swapC2, function()
            States.swapR1 = nil
            States.swapC1 = nil
            States.swapR2 = nil
            States.swapC2 = nil
            pendingTransition = "idle"
        end)

    elseif newState == "checking" then
        local matched, specials

        -- On first check after swap, handle special gem interactions
        if States.isFirstCheck and States.swapR1 then
            local gem1 = Grid.cells[States.swapR1][States.swapC1]
            local gem2 = Grid.cells[States.swapR2][States.swapC2]

            if gem1 and gem2 then
                -- Color bomb check
                if gem1.special == "color_bomb" or gem2.special == "color_bomb" then
                    local bomb = gem1.special == "color_bomb" and gem1 or gem2
                    local target = bomb == gem1 and gem2 or gem1
                    matched = Grid.clearColor(target.type, bomb)
                    specials = {}
                -- Special + special combo
                elseif gem1.special and gem2.special then
                    matched = Grid.comboSpecials(gem1, gem2)
                    specials = {}
                end
            end
            States.isFirstCheck = false
        end

        -- Normal match detection if no special interaction
        if not matched then
            matched, specials = Grid.findMatches(States.swapR1, States.swapC1)
        end

        -- Activate any specials in the matched set
        Grid.activateSpecials(matched)

        local count = 0
        for _ in pairs(matched) do count = count + 1 end

        if count > 0 then
            -- Track objective progress
            trackCollected(matched)
            trackSpecials(specials)

            -- Clear swap context after successful match
            States.swapR1 = nil
            States.swapC1 = nil
            States.swapR2 = nil
            States.swapC2 = nil
            States.combo = States.combo + 1
            if States.combo > States.maxCombo then
                States.maxCombo = States.combo
            end

            -- Score calculation with multiplier and cascade_king
            local comboMult = States.combo
            if hasCascadeKing and States.combo > 1 then
                comboMult = comboMult * 1.5
            end
            local points = math.floor(count * 10 * comboMult * scoreMultiplier)
            States.score = States.score + points
            States.pendingSpecials = specials or {}

            Logger.debug("game", "match", {
                cleared = count, combo = States.combo, points = points,
                score = States.score, specials = specials and #specials or 0,
            })

            -- Visual effects: floating score text + screen shake for big clears
            local fx = getEffects()
            if fx then
                -- Find center of matched gems for text position
                local cx, cy, n = 0, 0, 0
                for gem in pairs(matched) do
                    cx = cx + gem.x; cy = cy + gem.y; n = n + 1
                end
                if n > 0 then
                    cx = cx / n; cy = cy / n
                end
                local isCombo = States.combo > 1
                local color = isCombo and {1, 0.9, 0.2} or {1, 1, 1}
                local text = "+" .. points
                if isCombo then text = text .. " x" .. States.combo end
                fx.floatText(cx, cy - 20, text, color, isCombo)
                -- Screen shake on large clears
                if count >= 10 then
                    fx.shake(4)
                elseif count >= 6 then
                    fx.shake(2)
                end
            end

            Grid.removeMatches(matched, function()
                pendingTransition = "falling"
            end)
            States.current = "clearing"
        else
            States.combo = 0
            -- First check after a player swap with no matches → revert the swap
            if States.swapR1 then
                States.transition("reverting")
                return
            end
            -- Cascade check (no swap context) with no matches → resolve
            local _, primaryComplete = States.checkObjectives()
            if primaryComplete then
                States.stars = States.computeStars()
                States.current = "level_complete"
                Logger.info("game", "level_complete", {
                    level = Level.current.number, score = States.score,
                    target = Level.current.targetScore, stars = States.stars,
                    moves_used = Level.current.maxMoves - States.movesLeft,
                    moves_max = Level.current.maxMoves, max_combo = States.maxCombo,
                    objectives = snapshotObjectives(),
                })
            elseif States.movesLeft <= 0 then
                States.current = "level_fail"
                Logger.info("game", "level_fail", {
                    level = Level.current.number, score = States.score,
                    target = Level.current.targetScore, reason = "no_moves",
                    moves_max = Level.current.maxMoves, max_combo = States.maxCombo,
                    objectives = snapshotObjectives(),
                })
            elseif not Grid.hasValidMoves() then
                States.current = "level_fail"
                Logger.info("game", "level_fail", {
                    level = Level.current.number, score = States.score,
                    target = Level.current.targetScore, reason = "no_valid_moves",
                    moves_left = States.movesLeft, objectives = snapshotObjectives(),
                })
            else
                States.current = "idle"
            end
        end

    elseif newState == "falling" then
        Grid.clearRemoved()
        Grid.spawnSpecials(States.pendingSpecials or {})
        States.pendingSpecials = nil

        -- Compute dynamic drop bias: base from level + ML bandit or legacy curve
        local bias = config.dropBias or 0
        if States.mlEnabled and States.mlLastDecision then
            bias = bias + States.mlLastDecision.bias
        else
            local curveFn = ddaCurves[States.ddaCurve] or ddaCurves.linear
            bias = bias + curveFn(States.failCount)
        end
        Grid.dropBias = math.max(-0.5, math.min(0.6, bias))

        Grid.applyGravity(function()
            pendingTransition = "checking"
        end)
    end
end

---@param dt number
function States.update(dt)
    if pendingTransition then
        local next = pendingTransition
        pendingTransition = nil
        States.transition(next)
    end
    -- Update hint system
    Hints.update(dt, States.mlProfile.archetype, States.current == "idle")
end

---@param r1 integer
---@param c1 integer
---@param r2 integer
---@param c2 integer
function States.startSwap(r1, c1, r2, c2)
    States.swapR1, States.swapC1 = r1, c1
    States.swapR2, States.swapC2 = r2, c2
    States.isFirstCheck = true
    Hints.onSwap()

    -- Track avgMoveTime
    if love and love.timer then
        local now = love.timer.getTime()
        if lastSwapTime > 0 then
            local thinkTime = now - lastSwapTime
            States.mlProfile:updateMoveTime(thinkTime)
        end
        lastSwapTime = now
    end

    Logger.debug("game", "swap", {from = {r1, c1}, to = {r2, c2}, moves_left = States.movesLeft})
    Grid.swap(r1, c1, r2, c2)
    States.transition("swapping")
end

function States.startLevel()
    local config = Level.current
    Tweens.clear()

    -- ML-DDA: select arm and optionally apply fallback
    States.mlLastDecision = nil
    if States.mlEnabled then
        local bias, details = States.mlBandit:selectArm(States.mlProfile, config)
        States.mlLastDecision = details

        -- Apply fallback (mutates config) if at max arm + repeated fails
        local fallbackActivated = States.mlBandit:applyFallback(config, States.failCount)
        if fallbackActivated then
            details.fallback = States.mlBandit.fallbackInfo
        end

        -- Generate NL decision explanation
        States.mlDecisionText = Bandit.explainDecision(details, States.mlProfile)

        -- Build arm snapshot for logging
        local armsLog = {}
        local tierArms = States.mlBandit.tiers[details.tier]
        if tierArms then
            for i = 1, #States.mlBandit.biasValues do
                armsLog[i] = {
                    bias = States.mlBandit.biasValues[i],
                    alpha = tierArms[i].alpha,
                    beta = tierArms[i].beta,
                }
            end
        end

        Logger.info("ml", "select_arm", {
            level = config.number, tier = details.tier, arm = details.arm,
            bias = details.bias, prior_adj = details.priorAdj,
            safety_valve = details.safetyValve, fallback = fallbackActivated,
            profile = {
                skillScore = States.mlProfile.skillScore,
                archetype = States.mlProfile.archetype,
                scoreEff = States.mlProfile.scoreEfficiency,
                moveEff = States.mlProfile.moveEfficiency,
                comboSkill = States.mlProfile.comboSkill,
                specialSkill = States.mlProfile.specialSkill,
                passRate = States.mlProfile.passRate,
                frustration = States.mlProfile.frustration,
            },
            skill_estimate = { mu = States.mlBandit.skill.mu, sigma = States.mlBandit.skill.sigma },
            samples = details.samples,
            arms = armsLog,
            explanation = States.mlDecisionText,
        })
    end

    -- Apply modifier effects to grid setup
    Grid.noSpecials = Modifiers.has(config.modifiers, "no_specials")
    Grid.init(config.numGemTypes, config.gridSize)
    Grid.dropBias = config.dropBias or 0

    -- special_start: place initial specials after init
    if Modifiers.has(config.modifiers, "special_start") then
        Grid.placeInitialSpecials(3)
    end

    States.score = 0
    States.combo = 0
    States.maxCombo = 0
    States.movesLeft = config.maxMoves
    States.pendingSpecials = nil
    States.isFirstCheck = false
    States.collected = {}
    States.specialsCreated = 0
    States.stars = 0
    lastSwapTime = 0
    pendingTransition = nil
    States.current = "idle"

    -- Log level start with full config
    local objSummary = {}
    if config.objectives then
        for _, o in ipairs(config.objectives) do
            objSummary[#objSummary + 1] = o.description or o.type
        end
    end
    Logger.info("game", "level_start", {
        level = config.number, target = config.targetScore, moves = config.maxMoves,
        gems = config.numGemTypes, grid = config.gridSize or 8,
        bias = config.dropBias, effective_bias = States.getEffectiveBias(),
        curve = States.ddaCurve, ml_enabled = States.mlEnabled,
        score_mult = config.scoreMultiplier or 1.0,
        mods = config.modifiers or {}, objectives = objSummary,
    })
end

---Build attempt data from current state for ML pipeline
---@return AttemptData
local function buildAttemptData()
    local config = Level.current
    return {
        score = States.score,
        targetScore = config.targetScore,
        movesUsed = config.maxMoves - States.movesLeft,
        maxMoves = config.maxMoves,
        maxCombo = States.maxCombo,
        specialsCreated = States.specialsCreated,
        passed = States.score >= config.targetScore,
    }
end

---Update ML pipeline after a level attempt (pass or fail)
---@param passed boolean
local function updateML(passed)
    if not States.mlEnabled then return end

    local attempt = buildAttemptData()
    local config = Level.current

    -- Snapshot before state for logging
    local profileBefore = {
        skillScore = States.mlProfile.skillScore,
        archetype = States.mlProfile.archetype,
        frustration = States.mlProfile.frustration,
        scoreEff = States.mlProfile.scoreEfficiency,
        moveEff = States.mlProfile.moveEfficiency,
    }
    local armBefore = nil
    local tier = States.mlBandit.lastTier
    local armIdx = States.mlBandit.lastArm
    if States.mlBandit.tiers[tier] and States.mlBandit.tiers[tier][armIdx] then
        local a = States.mlBandit.tiers[tier][armIdx]
        armBefore = { alpha = a.alpha, beta = a.beta }
    end
    local skillBefore = { mu = States.mlBandit.skill.mu, sigma = States.mlBandit.skill.sigma }

    -- Track previous skillScore for trend indicator
    States.mlPrevSkillScore = States.mlProfile.skillScore

    -- Update player profile
    States.mlProfile:update(attempt)

    -- Quick calibration check
    local calibrated, direction = States.mlProfile:tryCalibrate()
    if calibrated and direction then
        States.mlBandit:shiftPriors(direction)
        Logger.info("ml", "calibration", {
            direction = direction,
            skill_score = States.mlProfile.skillScore,
            archetype = States.mlProfile.archetype,
        })
    end

    -- Compute engagement reward and update bandit
    local reward, breakdown = Bandit.computeReward(attempt, States.mlProfile)
    States.mlBandit:updateArm(reward)

    -- Update skill estimator
    States.mlBandit:updateSkill(config.number, passed)

    -- Snapshot after state
    local armAfter = nil
    if States.mlBandit.tiers[tier] and States.mlBandit.tiers[tier][armIdx] then
        local a = States.mlBandit.tiers[tier][armIdx]
        armAfter = { alpha = a.alpha, beta = a.beta }
    end

    Logger.info("ml", "update", {
        level = config.number, passed = passed, reward = reward,
        score_ratio = breakdown.scoreRatio,
        reward_breakdown = {
            flow_reward = breakdown.flowReward,
            frust_penalty = breakdown.frustPenalty,
            combo_bonus = breakdown.comboBonus,
            final_reward = reward,
        },
        arm_before = armBefore, arm_after = armAfter,
        profile_before = profileBefore,
        profile_after = {
            skillScore = States.mlProfile.skillScore,
            archetype = States.mlProfile.archetype,
            frustration = States.mlProfile.frustration,
            scoreEff = States.mlProfile.scoreEfficiency,
            moveEff = States.mlProfile.moveEfficiency,
        },
        skill_before = skillBefore,
        skill_after = { mu = States.mlBandit.skill.mu, sigma = States.mlBandit.skill.sigma },
    })

    -- Persist ML state
    Save.data.mlProfile = States.mlProfile:serialize()
    Save.data.mlBandit = States.mlBandit:serialize()
    Save.data.mlEnabled = States.mlEnabled
end

function States.nextLevel()
    -- ML update before save
    updateML(true)
    -- Save progress on level complete
    Save.onLevelComplete(Level.current.number, States.score, States.ddaCurve, States.stars)
    States.failCount = 0
    Level.next()
    States.startLevel()
end

function States.retryLevel()
    States.failCount = States.failCount + 1
    -- ML update before save
    updateML(false)
    local bias = States.getEffectiveBias()
    Logger.info("game", "retry", {
        level = Level.current.number, fail_count = States.failCount,
        effective_bias = bias, curve = States.ddaCurve, ml_enabled = States.mlEnabled,
    })
    Save.onLevelFail(States.failCount, Grid.dropBias, States.ddaCurve)
    Level.retry()
    States.startLevel()
end

---Handle text input during nick_input state
---@param text string
function States.textinput(text)
    if States.current ~= "nick_input" then return end
    -- Only allow alphanumeric characters
    local filtered = text:gsub("[^%w]", "")
    if #filtered > 0 and #States.nickInput < 12 then
        States.nickInput = States.nickInput .. filtered
        -- Check if this nick has a save
        if Save.exists(States.nickInput) then
            Save.load(States.nickInput)
            local msg = "Welcome back! Level " .. Save.data.maxLevel
            if Save.data.failCount > 0 then
                msg = msg .. string.format("  (retries: %d, bias: %.2f)", Save.data.failCount, Save.data.lastDropBias)
            end
            States.nickMessage = msg
        else
            States.nickMessage = ""
        end
    end
end

---Handle special key presses during nick_input state
---@param key string
function States.keypressed(key)
    if States.current ~= "nick_input" then return end

    if key == "backspace" then
        States.nickInput = States.nickInput:sub(1, -2)
        if #States.nickInput >= 3 and Save.exists(States.nickInput) then
            Save.load(States.nickInput)
            local msg = "Welcome back! Level " .. Save.data.maxLevel
            if Save.data.failCount > 0 then
                msg = msg .. string.format("  (retries: %d, bias: %.2f)", Save.data.failCount, Save.data.lastDropBias)
            end
            States.nickMessage = msg
        else
            States.nickMessage = ""
        end
    elseif key == "return" or key == "kpenter" then
        if #States.nickInput >= 3 then
            States.confirmNick()
        end
    end
end

---Confirm nick and start playing
function States.confirmNick()
    Save.setNick(States.nickInput)
    Level.maxReached = Save.data.maxLevel
    States.failCount = Save.data.failCount or 0
    States.ddaCurve = Save.data.ddaCurve or "linear"

    -- Restore ML state from save
    States.mlProfile = Profile.deserialize(Save.data.mlProfile)
    States.mlBandit = Bandit.deserialize(Save.data.mlBandit)
    if Save.data.mlEnabled ~= nil then
        States.mlEnabled = Save.data.mlEnabled
    end

    Logger.info("game", "player_login", {
        nick = States.nickInput, max_level = Save.data.maxLevel,
        curve = States.ddaCurve, ml_enabled = States.mlEnabled,
        archetype = States.mlProfile.archetype,
        skill_score = States.mlProfile.skillScore,
    })
    Level.start(Save.data.maxLevel)
    States.startLevel()
end

---Compute current effective DDA bias (for display)
---@return number
function States.getEffectiveBias()
    local bias = Level.current.dropBias or 0
    if States.mlEnabled and States.mlLastDecision then
        bias = bias + States.mlLastDecision.bias
    else
        local curveFn = ddaCurves[States.ddaCurve] or ddaCurves.linear
        bias = bias + curveFn(States.failCount)
    end
    return math.max(-0.5, math.min(0.6, bias))
end

return States

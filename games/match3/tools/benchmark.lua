--- Headless auto-play benchmark
--- Simulates complete game runs across strategy × curve combinations
--- Includes ML-DDA benchmark with 100 synthetic players
--- Run: "D:/Program Files/LOVE/lovec.exe" F:/love2d --benchmark

local Grid = require("core.grid")
local Gem = require("core.gem")
local Utils = require("core.utils")
local Level = require("systems.level")
local Autoplay = require("tools.autoplay")
local Profile = require("systems.profile")
local Bandit = require("systems.bandit")

-- ============================================================
-- Headless gravity: same logic as Grid.applyGravity but instant
-- ============================================================
local function instantGravity(bias)
    local SIZE = Grid.size
    for col = 1, SIZE do
        local writeRow = SIZE
        for readRow = SIZE, 1, -1 do
            local gem = Grid.cells[readRow][col]
            if gem then
                if readRow ~= writeRow then
                    Grid.cells[writeRow][col] = gem
                    Grid.cells[readRow][col] = nil
                    gem.row = writeRow
                    gem.col = col
                    local x, y = Utils.gridToPixel(writeRow, col)
                    gem.x, gem.y = x, y
                    gem.targetX, gem.targetY = x, y
                end
                writeRow = writeRow - 1
            end
        end
        for row = writeRow, 1, -1 do
            local gemType = Grid.smartDrop(row, col, bias)
            Grid.cells[row][col] = Gem.new(gemType, row, col)
        end
    end
end

-- ============================================================
-- Headless cascade: match → activate → remove → gravity, repeat
-- Returns total gems cleared and combo count
-- ============================================================
local function headlessCascade(swapR, swapC, bias)
    local totalCleared = 0
    local combo = 0
    for _ = 1, 30 do
        local matched, specials = Grid.findMatches(swapR, swapC)
        Grid.activateSpecials(matched)

        local count = 0
        for _ in pairs(matched) do count = count + 1 end
        if count == 0 then break end

        combo = combo + 1
        totalCleared = totalCleared + count

        -- Remove matched gems
        for gem in pairs(matched) do
            Grid.cells[gem.row][gem.col] = nil
        end

        -- Spawn specials
        if specials then
            for _, spec in ipairs(specials) do
                if not Grid.cells[spec.row][spec.col] then
                    Grid.cells[spec.row][spec.col] = Gem.new(spec.gemType, spec.row, spec.col, spec.special)
                end
            end
        end

        instantGravity(bias)
        -- After first cascade step, clear swap context so further findMatches has no swap position
        swapR, swapC = nil, nil
    end
    return totalCleared, combo
end

-- ============================================================
-- DDA curves (same as states.lua)
-- ============================================================
local ddaCurves = {
    linear = function(n) return math.max(-0.5, math.min(0.6, 0.05 * n)) end,
    quadratic = function(n) return math.max(-0.5, math.min(0.6, 0.015 * n * n)) end,
    logarithmic = function(n) return math.max(-0.5, math.min(0.6, 0.12 * math.log(n + 1))) end,
}

-- ============================================================
-- Simulate one level attempt. Returns result table.
-- ============================================================
---@param levelNum integer
---@param strategyName string
---@param curveName string
---@param failCount integer
---@return table result
local function simulateLevel(levelNum, strategyName, curveName, failCount)
    local config = Level.generate(levelNum)

    -- Apply modifier effects to grid setup
    local Modifiers = require("systems.modifiers")
    Grid.noSpecials = Modifiers.has(config.modifiers, "no_specials")
    Grid.init(config.numGemTypes, config.gridSize)

    -- special_start: place initial specials
    if Modifiers.has(config.modifiers, "special_start") then
        Grid.placeInitialSpecials(3)
    end

    local baseBias = config.dropBias or 0
    local ddaBias = ddaCurves[curveName](failCount)
    local effectiveBias = math.max(-0.5, math.min(0.6, baseBias + ddaBias))
    Grid.dropBias = effectiveBias

    local score = 0
    local movesLeft = config.maxMoves
    local movesUsed = 0
    local maxCombo = 0
    local strategy = Autoplay.strategies[strategyName]
    local scoreMultiplier = config.scoreMultiplier or 1.0
    local hasCascadeKing = Modifiers.has(config.modifiers, "cascade_king")

    while movesLeft > 0 and score < config.targetScore do
        local move = strategy(Grid.cells, config.numGemTypes)
        if not move then break end -- no valid moves

        -- Handle special interactions
        local gem1 = Grid.cells[move.r1][move.c1]
        local gem2 = Grid.cells[move.r2][move.c2]

        Grid.swap(move.r1, move.c1, move.r2, move.c2)
        movesLeft = movesLeft - 1
        movesUsed = movesUsed + 1

        -- Check for special gem interactions (color bomb, special+special)
        local specialHandled = false
        if gem1 and gem2 then
            if gem1.special == "color_bomb" or gem2.special == "color_bomb" then
                local bomb = gem1.special == "color_bomb" and gem1 or gem2
                local target = bomb == gem1 and gem2 or gem1
                local matched = Grid.clearColor(target.type, bomb)
                local count = 0
                for _ in pairs(matched) do count = count + 1 end
                score = score + math.floor(count * 10 * scoreMultiplier)
                for gem in pairs(matched) do
                    Grid.cells[gem.row][gem.col] = nil
                end
                instantGravity(effectiveBias)
                specialHandled = true
            elseif gem1.special and gem2.special then
                local matched = Grid.comboSpecials(gem1, gem2)
                local count = 0
                for _ in pairs(matched) do count = count + 1 end
                score = score + math.floor(count * 10 * scoreMultiplier)
                for gem in pairs(matched) do
                    Grid.cells[gem.row][gem.col] = nil
                end
                instantGravity(effectiveBias)
                specialHandled = true
            end
        end

        if not specialHandled then
            -- Normal cascade
            local cleared, combo = headlessCascade(move.r1, move.c1, effectiveBias)
            if cleared == 0 then
                -- Invalid move, revert
                Grid.swap(move.r1, move.c1, move.r2, move.c2)
                movesLeft = movesLeft + 1
                movesUsed = movesUsed - 1
            else
                -- Score with combo multiplier
                score = score + math.floor(cleared * 10 * scoreMultiplier)
                if combo > maxCombo then maxCombo = combo end
            end
        end

        -- Post-cascade: check for further cascades from gravity fills
        if not specialHandled or true then
            local extraCleared = 0
            for _ = 1, 10 do
                local matched2 = Grid.findMatches()
                Grid.activateSpecials(matched2)
                local c2 = 0
                for _ in pairs(matched2) do c2 = c2 + 1 end
                if c2 == 0 then break end
                extraCleared = extraCleared + c2
                for gem in pairs(matched2) do
                    Grid.cells[gem.row][gem.col] = nil
                end
                instantGravity(effectiveBias)
            end
            score = score + math.floor(extraCleared * 10 * scoreMultiplier)
        end
    end

    local passed = score >= config.targetScore
    return {
        level = levelNum,
        result = passed and "pass" or "fail",
        score = score,
        targetScore = config.targetScore,
        movesUsed = movesUsed,
        maxMoves = config.maxMoves,
        failCount = failCount,
        bias = effectiveBias,
        curve = curveName,
        strategy = strategyName,
        gemTypes = config.numGemTypes,
        maxCombo = maxCombo,
        gridSize = config.gridSize,
        modifiers = table.concat(config.modifiers, "+"),
    }
end

-- ============================================================
-- Run benchmark across all combinations (legacy: strategy x curve grid)
-- ============================================================
local function runLegacyBenchmark()
    local strategies = Autoplay.getStrategyNames()
    local curves = { "linear", "quadratic", "logarithmic" }
    local maxLevel = 100
    local maxRetries = 15 -- max retries per level before giving up

    -- CSV header
    print("strategy,curve,level,attempt,result,score,target,moves_used,max_moves,fail_count,bias,gem_types,max_combo,grid_size,modifiers")

    for _, strat in ipairs(strategies) do
        for _, curve in ipairs(curves) do
            local failCount = 0
            local currentLevel = 1

            while currentLevel <= maxLevel do
                local rec = simulateLevel(currentLevel, strat, curve, failCount)

                -- CSV row
                print(string.format("%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%.3f,%d,%d,%d,%s",
                    strat, curve, currentLevel, failCount + 1,
                    rec.result, rec.score, rec.targetScore,
                    rec.movesUsed, rec.maxMoves,
                    failCount, rec.bias, rec.gemTypes, rec.maxCombo,
                    rec.gridSize, rec.modifiers))

                if rec.result == "pass" then
                    failCount = 0
                    currentLevel = currentLevel + 1
                else
                    failCount = failCount + 1
                    if failCount >= maxRetries then
                        -- Give up on this level, record as stuck
                        print(string.format("# %s/%s stuck at level %d after %d retries", strat, curve, currentLevel, maxRetries))
                        break
                    end
                end
            end
        end
    end
end

-- ============================================================
-- Synthetic player: parameterized skill model
-- 4D: base_skill (0-1), noise (0-1), growth (0-1), volatility (0-1)
-- ============================================================

---@class SyntheticPlayer
---@field baseSkill number    base ability (0=terrible, 1=perfect)
---@field noise number        randomness in performance (0=consistent, 1=erratic)
---@field growth number       improvement rate over time (0=static, 1=fast learner)
---@field volatility number   session variance (0=stable, 1=streaky)
---@field attempts integer    total attempts made
---@field currentStreak integer positive=wins, negative=losses
---@field consecutiveFails integer  consecutive level failures (tilt)
---@field effectiveNoise number     noise + tilt spike
---@field quitProbability number    chance to quit after many fails
---@field name? string              optional label

---Create a synthetic player
---@param baseSkill number 0-1
---@param noise number 0-1
---@param growth number 0-1
---@param volatility number 0-1
---@param name? string  optional label
---@return SyntheticPlayer
local function newSyntheticPlayer(baseSkill, noise, growth, volatility, name)
    return {
        baseSkill = baseSkill,
        noise = noise,
        growth = growth,
        volatility = volatility,
        name = name,
        attempts = 0,
        currentStreak = 0,
        consecutiveFails = 0,
        effectiveNoise = noise,
        quitProbability = 0,
    }
end

---Compute effective skill for this attempt (0-1)
---Includes S-curve learning, tilt effect, and streak momentum
---@param player SyntheticPlayer
---@return number
local function effectiveSkill(player)
    -- S-curve growth: slow start, fast middle, slow finish
    local sigmoidGrowth = player.growth * 0.2 * math.log(player.attempts + 1)
    -- S-curve factor: 4*s*(1-s) peaks at s=0.5
    local sFactor = 4 * player.baseSkill * (1 - player.baseSkill)
    local growthBonus = sigmoidGrowth * math.max(0.3, sFactor)
    local base = math.min(1.0, player.baseSkill + growthBonus)

    -- Noise: uses effectiveNoise which includes "tilt" spikes
    local noiseVal = (math.random() - 0.5) * player.effectiveNoise * 0.4

    -- Volatility: streak-based momentum
    local streakBonus = 0
    if player.volatility > 0 then
        streakBonus = player.currentStreak * player.volatility * 0.02
    end

    return math.max(0, math.min(1, base + noiseVal + streakBonus))
end

---Update synthetic player emotional dynamics after level end
---@param player SyntheticPlayer
---@param passed boolean
local function updatePlayerDynamics(player, passed)
    if not passed then
        player.consecutiveFails = player.consecutiveFails + 1
        -- "Tilt" effect: noise spikes on consecutive fails
        player.effectiveNoise = math.min(0.8, player.noise + 0.05 * player.consecutiveFails)
        -- Quit probability: rises after 5+ consecutive fails
        if player.consecutiveFails >= 5 then
            player.quitProbability = math.min(0.8, 0.2 * (player.consecutiveFails - 4))
        end
        player.currentStreak = math.min(0, player.currentStreak) - 1
    else
        player.consecutiveFails = 0
        player.effectiveNoise = player.noise
        player.quitProbability = 0
        player.currentStreak = math.max(0, player.currentStreak) + 1
    end
end

---Check if synthetic player would quit this session
---@param player SyntheticPlayer
---@return boolean
local function playerWouldQuit(player)
    return player.quitProbability > 0 and math.random() < player.quitProbability
end

---Select autoplay strategy based on synthetic skill level
---Uses only greedy/heuristic in benchmark (montecarlo is too slow for 100-player runs)
---@param skill number 0-1 effective skill
---@return string strategyName
local function selectStrategy(skill)
    if skill > 0.5 then return "heuristic"
    else return "greedy"
    end
end

-- ============================================================
-- Simulate one level with ML-DDA
-- ============================================================
---@param levelNum integer
---@param player SyntheticPlayer
---@param profile PlayerProfile
---@param bandit DifficultyBandit
---@param failCount integer
---@return table result
local function simulateLevelML(levelNum, player, profile, bandit, failCount)
    local config = Level.generate(levelNum)

    -- ML: select arm and apply fallback
    local mlBias, details = bandit:selectArm(profile, config)
    bandit:applyFallback(config, failCount)

    -- Apply modifier effects
    local Modifiers = require("systems.modifiers")
    Grid.noSpecials = Modifiers.has(config.modifiers, "no_specials")
    Grid.init(config.numGemTypes, config.gridSize)
    if Modifiers.has(config.modifiers, "special_start") then
        Grid.placeInitialSpecials(3)
    end

    local baseBias = config.dropBias or 0
    local effectiveBias = math.max(-0.5, math.min(0.6, baseBias + mlBias))
    Grid.dropBias = effectiveBias

    -- Choose strategy based on synthetic player skill
    player.attempts = player.attempts + 1
    local skill = effectiveSkill(player)
    local stratName = selectStrategy(skill)
    local strategy = Autoplay.strategies[stratName]

    local score = 0
    local movesLeft = config.maxMoves
    local movesUsed = 0
    local maxCombo = 0
    local specialsCreated = 0
    local scoreMultiplier = config.scoreMultiplier or 1.0
    local hasCascadeKing = Modifiers.has(config.modifiers, "cascade_king")

    while movesLeft > 0 and score < config.targetScore do
        local move = strategy(Grid.cells, config.numGemTypes)
        if not move then break end

        local gem1 = Grid.cells[move.r1][move.c1]
        local gem2 = Grid.cells[move.r2][move.c2]
        Grid.swap(move.r1, move.c1, move.r2, move.c2)
        movesLeft = movesLeft - 1
        movesUsed = movesUsed + 1

        local specialHandled = false
        if gem1 and gem2 then
            if gem1.special == "color_bomb" or gem2.special == "color_bomb" then
                local bomb = gem1.special == "color_bomb" and gem1 or gem2
                local target = bomb == gem1 and gem2 or gem1
                local matched = Grid.clearColor(target.type, bomb)
                local count = 0
                for _ in pairs(matched) do count = count + 1 end
                score = score + math.floor(count * 10 * scoreMultiplier)
                for gem in pairs(matched) do Grid.cells[gem.row][gem.col] = nil end
                instantGravity(effectiveBias)
                specialHandled = true
            elseif gem1.special and gem2.special then
                local matched = Grid.comboSpecials(gem1, gem2)
                local count = 0
                for _ in pairs(matched) do count = count + 1 end
                score = score + math.floor(count * 10 * scoreMultiplier)
                for gem in pairs(matched) do Grid.cells[gem.row][gem.col] = nil end
                instantGravity(effectiveBias)
                specialHandled = true
            end
        end

        if not specialHandled then
            local cleared, combo = headlessCascade(move.r1, move.c1, effectiveBias)
            if cleared == 0 then
                Grid.swap(move.r1, move.c1, move.r2, move.c2)
                movesLeft = movesLeft + 1
                movesUsed = movesUsed - 1
            else
                score = score + math.floor(cleared * 10 * scoreMultiplier)
                if combo > maxCombo then maxCombo = combo end
            end
        end

        -- Post-cascade
        for _ = 1, 10 do
            local matched2 = Grid.findMatches()
            Grid.activateSpecials(matched2)
            local c2 = 0
            for _ in pairs(matched2) do c2 = c2 + 1 end
            if c2 == 0 then break end
            score = score + math.floor(c2 * 10 * scoreMultiplier)
            for gem in pairs(matched2) do Grid.cells[gem.row][gem.col] = nil end
            instantGravity(effectiveBias)
        end
    end

    local passed = score >= config.targetScore

    -- Update ML pipeline
    local attempt = {
        score = score, targetScore = config.targetScore,
        movesUsed = movesUsed, maxMoves = config.maxMoves,
        maxCombo = maxCombo, specialsCreated = specialsCreated,
        passed = passed,
    }
    profile:update(attempt)
    local calibrated, direction = profile:tryCalibrate()
    if calibrated and direction then
        bandit:shiftPriors(direction)
    end
    local reward = Bandit.computeReward(attempt, profile)
    bandit:updateArm(reward)
    bandit:updateSkill(levelNum, passed)

    -- Update synthetic player dynamics (tilt, quit probability, S-curve)
    updatePlayerDynamics(player, passed)

    return {
        level = levelNum,
        result = passed and "pass" or "fail",
        score = score,
        targetScore = config.targetScore,
        movesUsed = movesUsed,
        maxMoves = config.maxMoves,
        failCount = failCount,
        bias = effectiveBias,
        mlArm = details.arm,
        mlBias = mlBias,
        archetype = profile.archetype,
        skillScore = profile.skillScore,
        frustration = profile.frustration,
        reward = reward,
        gemTypes = config.numGemTypes,
        maxCombo = maxCombo,
        gridSize = config.gridSize,
    }
end

-- ============================================================
-- Generate 100 synthetic players: 20 preset + 80 grid-sampled
-- ============================================================
local function generate100Players()
    local players = {}

    -- ── 20 hand-crafted preset templates ──
    local presets = {
        { 0.05, 0.40, 0.00, 0.05, "Pure Novice" },
        { 0.25, 0.20, 0.00, 0.10, "Casual Veteran" },
        { 0.15, 0.25, 0.40, 0.10, "Keen Learner" },
        { 0.45, 0.10, 0.05, 0.05, "Stable Average" },
        { 0.40, 0.15, 0.10, 0.25, "Commuter Player" },
        { 0.80, 0.05, 0.05, 0.03, "Focused Expert" },
        { 0.75, 0.05, 0.00, 0.20, "Streaky Expert" },
        { 0.10, 0.30, 0.50, 0.10, "Talented Newcomer" },
        { 0.30, 0.45, 0.00, 0.05, "Lazy Tapper" },
        { 0.90, 0.02, 0.05, 0.02, "Perfectionist" },
        { 0.60, 0.10, 0.00, 0.15, "Solid Mid-tier" },
        { 0.20, 0.35, 0.20, 0.20, "Erratic Learner" },
        { 0.50, 0.08, 0.15, 0.05, "Steady Climber" },
        { 0.35, 0.30, 0.00, 0.30, "Inconsistent Mid" },
        { 0.70, 0.15, 0.05, 0.10, "Noisy Expert" },
        { 0.05, 0.10, 0.30, 0.05, "Quiet Learner" },
        { 0.55, 0.20, 0.10, 0.15, "Above Average" },
        { 0.85, 0.03, 0.00, 0.05, "Zen Master" },
        { 0.15, 0.40, 0.05, 0.30, "Frustrated Newbie" },
        { 0.65, 0.05, 0.20, 0.10, "Rising Star" },
    }
    for _, p in ipairs(presets) do
        table.insert(players, newSyntheticPlayer(p[1], p[2], p[3], p[4], p[5]))
    end

    -- ── 80 grid-sampled from parameter space ──
    local skills = { 0.10, 0.25, 0.40, 0.55, 0.70, 0.85 }
    local noises = { 0.05, 0.15, 0.25, 0.35 }
    local growths = { 0.00, 0.15, 0.35 }
    local volatils = { 0.05, 0.15, 0.25 }

    -- Generate all combinations, then pick 80 with deterministic seed
    local allCombos = {}
    for _, s in ipairs(skills) do
        for _, n in ipairs(noises) do
            for _, g in ipairs(growths) do
                for _, v in ipairs(volatils) do
                    table.insert(allCombos, {s, n, g, v})
                end
            end
        end
    end

    -- Deterministic shuffle (Fisher-Yates with fixed seed)
    local savedRng = math.random
    math.randomseed(42)
    for i = #allCombos, 2, -1 do
        local j = math.random(i)
        allCombos[i], allCombos[j] = allCombos[j], allCombos[i]
    end

    -- Take first 80
    local count = math.min(80, #allCombos)
    for i = 1, count do
        local c = allCombos[i]
        table.insert(players, newSyntheticPlayer(c[1], c[2], c[3], c[4]))
    end

    -- Restore random state
    math.randomseed(os.time())

    return players
end

-- ============================================================
-- Metric computation helpers
-- ============================================================
local function mean(t)
    if #t == 0 then return 0 end
    local s = 0; for _, v in ipairs(t) do s = s + v end; return s / #t
end

local function stdev(t, m)
    if #t < 2 then return 0 end
    local s = 0; for _, v in ipairs(t) do s = s + (v - m)^2 end
    return math.sqrt(s / (#t - 1))
end

---Compute Flow Index: % of scoreRatios in [0.8, 1.2]
---@param ratios number[]
---@return number 0-1
local function flowIndex(ratios)
    if #ratios == 0 then return 0 end
    local count = 0
    for _, r in ipairs(ratios) do
        if r >= 0.8 and r <= 1.2 then count = count + 1 end
    end
    return count / #ratios
end

---Compute Bias Stability: stdev of arm selections in sliding windows of 10
---@param armHistory integer[]
---@return number
local function biasStability(armHistory)
    if #armHistory < 10 then return 0 end
    local windowStdevs = {}
    for i = 1, #armHistory - 9 do
        local window = {}
        for j = i, i + 9 do window[#window + 1] = armHistory[j] end
        local m = mean(window)
        windowStdevs[#windowStdevs + 1] = stdev(window, m)
    end
    return mean(windowStdevs)
end

local function pairedTTest(a, b)
    local n = math.min(#a, #b)
    if n < 2 then return 0, 0, 0 end
    local sumD, sumD2 = 0, 0
    for i = 1, n do
        local d = a[i] - b[i]
        sumD = sumD + d
        sumD2 = sumD2 + d * d
    end
    local meanD = sumD / n
    local varD = (sumD2 - n * meanD * meanD) / (n - 1)
    local seD = math.sqrt(math.max(0, varD) / n)
    local t = seD > 0 and (meanD / seD) or 0
    return meanD, t, seD
end

-- ============================================================
-- ML-DDA benchmark: 100 players, paired comparison with legacy
-- ============================================================
function Autoplay.benchmarkML()
    local maxLevel = 30
    local maxRetries = 10
    local players = generate100Players()
    local N = #players

    -- Per-player metrics
    local mlPassRates, legacyPassRates = {}, {}
    local mlFlowScores, legacyFlowScores = {}, {}
    local mlFlowIndices, legacyFlowIndices = {}, {}
    local mlFrustRates, legacyFrustRates = {}, {}
    local mlScoreVars, legacyScoreVars = {}, {}
    local mlBiasStabilities = {}
    local playerSkills = {} -- for per-group breakdown

    io.write(string.format("=== ML-DDA Benchmark: %d synthetic players, %d levels ===\n\n", N, maxLevel))
    io.flush()

    for pid = 1, N do
        local player = players[pid]
        local profile = Profile.new()
        local bandit = Bandit.new()
        playerSkills[pid] = player.baseSkill

        -- ML run
        local mlPasses, mlTotal, mlFlowSum = 0, 0, 0
        local mlScoreRatios = {}
        local mlFrustEvents = 0
        local mlArmHistory = {}
        local failCount = 0
        local currentLevel = 1

        while currentLevel <= maxLevel do
            if playerWouldQuit(player) then break end

            local rec = simulateLevelML(currentLevel, player, profile, bandit, failCount)
            mlTotal = mlTotal + 1
            mlFlowSum = mlFlowSum + rec.reward
            mlScoreRatios[#mlScoreRatios + 1] = rec.score / math.max(1, rec.targetScore)
            mlArmHistory[#mlArmHistory + 1] = rec.mlArm
            if rec.result == "pass" then
                mlPasses = mlPasses + 1
                failCount = 0
                currentLevel = currentLevel + 1
            else
                failCount = failCount + 1
                if failCount >= 3 then mlFrustEvents = mlFrustEvents + 1 end
                if failCount >= maxRetries then break end
            end
        end

        mlPassRates[pid] = mlPasses / math.max(1, mlTotal)
        mlFlowScores[pid] = mlFlowSum / math.max(1, mlTotal)
        mlFlowIndices[pid] = flowIndex(mlScoreRatios)
        mlFrustRates[pid] = mlFrustEvents / math.max(1, mlTotal)
        local mlSRM = mean(mlScoreRatios)
        mlScoreVars[pid] = stdev(mlScoreRatios, mlSRM)
        mlBiasStabilities[pid] = biasStability(mlArmHistory)

        -- Legacy run: same player, reset, use same strategy + linear curve
        local legacyPlayer = newSyntheticPlayer(player.baseSkill, player.noise, player.growth, player.volatility)
        local legacyPasses, legacyTotal, legacyFlowSum = 0, 0, 0
        local legacyScoreRatios = {}
        local legacyFrustEvents = 0
        failCount = 0
        currentLevel = 1

        while currentLevel <= maxLevel do
            if playerWouldQuit(legacyPlayer) then break end

            legacyPlayer.attempts = legacyPlayer.attempts + 1
            local skill = effectiveSkill(legacyPlayer)
            local stratName = selectStrategy(skill)
            local rec = simulateLevel(currentLevel, stratName, "linear", failCount)
            legacyTotal = legacyTotal + 1

            local legacyProfile = Profile.new()
            legacyProfile.archetype = "normal"
            local legacyReward = Bandit.computeReward({
                score = rec.score, targetScore = rec.targetScore,
                maxCombo = rec.maxCombo, passed = rec.result == "pass",
            }, legacyProfile)
            legacyFlowSum = legacyFlowSum + legacyReward
            legacyScoreRatios[#legacyScoreRatios + 1] = rec.score / math.max(1, rec.targetScore)

            local passed = rec.result == "pass"
            updatePlayerDynamics(legacyPlayer, passed)

            if passed then
                legacyPasses = legacyPasses + 1
                failCount = 0
                currentLevel = currentLevel + 1
            else
                failCount = failCount + 1
                if failCount >= 3 then legacyFrustEvents = legacyFrustEvents + 1 end
                if failCount >= maxRetries then break end
            end
        end

        legacyPassRates[pid] = legacyPasses / math.max(1, legacyTotal)
        legacyFlowScores[pid] = legacyFlowSum / math.max(1, legacyTotal)
        legacyFlowIndices[pid] = flowIndex(legacyScoreRatios)
        legacyFrustRates[pid] = legacyFrustEvents / math.max(1, legacyTotal)
        local legSRM = mean(legacyScoreRatios)
        legacyScoreVars[pid] = stdev(legacyScoreRatios, legSRM)

        -- Progress: print every 10th player and first 5
        if pid <= 5 or pid % 10 == 0 then
            local label = player.name and string.format("P%03d %-16s", pid, player.name)
                or string.format("P%03d (s=%.2f n=%.1f g=%.1f v=%.1f)", pid,
                    player.baseSkill, player.noise, player.growth, player.volatility)
            io.write(string.format("%s: ML %.0f%%/%.3f | Leg %.0f%%/%.3f\n",
                label, mlPassRates[pid] * 100, mlFlowScores[pid],
                legacyPassRates[pid] * 100, legacyFlowScores[pid]))
            io.flush()
        end
    end

    -- ── Per-skill-group breakdown ──
    io.write("\n=== Per-Skill-Group Breakdown ===\n")
    io.write(string.format("%-20s %4s  %-8s  %-8s  %-8s  %-8s  %-8s  %-8s\n",
        "Group", "N", "Mode", "Pass%", "Flow%", "Frust%", "Score-s", "BiasStb"))
    io.write(string.rep("-", 92) .. "\n")

    local groups = {
        { "Low (0-0.3)", function(s) return s < 0.3 end },
        { "Mid (0.3-0.6)", function(s) return s >= 0.3 and s < 0.6 end },
        { "High (0.6-1.0)", function(s) return s >= 0.6 end },
    }

    for _, grp in ipairs(groups) do
        local gName, gFilter = grp[1], grp[2]
        local gMlPR, gMlFI, gMlFR, gMlSV, gMlBS = {}, {}, {}, {}, {}
        local gLgPR, gLgFI, gLgFR, gLgSV = {}, {}, {}, {}
        for i = 1, N do
            if gFilter(playerSkills[i]) then
                gMlPR[#gMlPR + 1] = mlPassRates[i]
                gMlFI[#gMlFI + 1] = mlFlowIndices[i]
                gMlFR[#gMlFR + 1] = mlFrustRates[i]
                gMlSV[#gMlSV + 1] = mlScoreVars[i]
                gMlBS[#gMlBS + 1] = mlBiasStabilities[i]
                gLgPR[#gLgPR + 1] = legacyPassRates[i]
                gLgFI[#gLgFI + 1] = legacyFlowIndices[i]
                gLgFR[#gLgFR + 1] = legacyFrustRates[i]
                gLgSV[#gLgSV + 1] = legacyScoreVars[i]
            end
        end
        local gN = #gMlPR
        if gN > 0 then
            io.write(string.format("%-20s %4d  %-8s  %5.1f%%  %5.1f%%  %5.1f%%  %6.3f  %6.3f\n",
                gName, gN, "ML",
                mean(gMlPR) * 100, mean(gMlFI) * 100, mean(gMlFR) * 100,
                mean(gMlSV), mean(gMlBS)))
            io.write(string.format("%-20s %4s  %-8s  %5.1f%%  %5.1f%%  %5.1f%%  %6.3f\n",
                "", "", "Legacy",
                mean(gLgPR) * 100, mean(gLgFI) * 100, mean(gLgFR) * 100,
                mean(gLgSV)))
        end
    end

    -- ── Growing players: adaptation speed ──
    local growingPlayers = {}
    for i = 1, N do
        if players[i].growth > 0.2 then
            growingPlayers[#growingPlayers + 1] = i
        end
    end
    if #growingPlayers > 0 then
        io.write(string.format("\nGrowing players (growth > 0.2): N=%d\n", #growingPlayers))
    end

    -- ── Paired t-test ──
    io.write(string.format("\n=== Paired Comparison (N=%d) ===\n", N))

    local prMean, prT, prSE = pairedTTest(mlPassRates, legacyPassRates)
    local flMean, flT, flSE = pairedTTest(mlFlowScores, legacyFlowScores)
    local fiMean, fiT, fiSE = pairedTTest(mlFlowIndices, legacyFlowIndices)
    local frMean, frT, frSE = pairedTTest(mlFrustRates, legacyFrustRates)
    local svMean, svT, svSE = pairedTTest(mlScoreVars, legacyScoreVars)

    local function sigStr(t) return math.abs(t) > 1.984 and "p<0.05 *" or "n.s." end
    io.write(string.format("Pass Rate:    ML-Leg = %+.4f (SE=%.4f, t=%.2f) %s\n", prMean, prSE, prT, sigStr(prT)))
    io.write(string.format("Flow Score:   ML-Leg = %+.4f (SE=%.4f, t=%.2f) %s\n", flMean, flSE, flT, sigStr(flT)))
    io.write(string.format("Flow Index:   ML-Leg = %+.4f (SE=%.4f, t=%.2f) %s\n", fiMean, fiSE, fiT, sigStr(fiT)))
    io.write(string.format("Frustration:  ML-Leg = %+.4f (SE=%.4f, t=%.2f) %s\n", frMean, frSE, frT, sigStr(frT)))
    io.write(string.format("Score Var:    ML-Leg = %+.4f (SE=%.4f, t=%.2f) %s\n", svMean, svSE, svT, sigStr(svT)))

    -- ── Aggregate stats ──
    local mlPR = mean(mlPassRates)
    local legPR = mean(legacyPassRates)
    local mlFL = mean(mlFlowScores)
    local legFL = mean(legacyFlowScores)
    local mlFI = mean(mlFlowIndices)
    local legFI = mean(legacyFlowIndices)
    local mlFR = mean(mlFrustRates)
    local legFR = mean(legacyFrustRates)
    local mlSV = mean(mlScoreVars)
    local legSV = mean(legacyScoreVars)
    local mlBS = mean(mlBiasStabilities)

    io.write(string.format("\nML:     PR=%.1f%% (sd=%.1f%%)  Flow=%.3f  FlowIdx=%.1f%%  Frust=%.1f%%  ScoreVar=%.3f  BiasStab=%.3f\n",
        mlPR * 100, stdev(mlPassRates, mlPR) * 100, mlFL, mlFI * 100, mlFR * 100, mlSV, mlBS))
    io.write(string.format("Legacy: PR=%.1f%% (sd=%.1f%%)  Flow=%.3f  FlowIdx=%.1f%%  Frust=%.1f%%  ScoreVar=%.3f\n",
        legPR * 100, stdev(legacyPassRates, legPR) * 100, legFL, legFI * 100, legFR * 100, legSV))
end

-- ============================================================
-- Main entry: run ML benchmark by default (legacy is slow)
-- ============================================================
Autoplay.benchmarkLegacy = runLegacyBenchmark
Autoplay.benchmark = function()
    Autoplay.benchmarkML()
end

return Autoplay

local Modifiers = require("systems.modifiers")

---@class Objective
---@field type string          -- "score"|"collect"|"combo"|"moves_left"|"specials"
---@field target integer       -- target value
---@field gemType? integer     -- collect type only
---@field description string   -- display text

---@class LevelConfig
---@field number integer
---@field numGemTypes integer
---@field targetScore integer
---@field maxMoves integer
---@field dropBias number       -- -1.0(hard) to 1.0(easy), 0=uniform random
---@field modifiers string[]    -- active modifier names
---@field gridSize integer      -- board edge length (default 8)
---@field scoreMultiplier number -- base score multiplier (default 1.0)
---@field objectives Objective[] -- level objectives (first is always score)

---@class Level
---@field current LevelConfig
---@field maxReached integer
local Level = {}

Level.current = nil
Level.maxReached = 1

---Simple deterministic PRNG for objective generation
---@param seed integer
---@return fun(): number
local function seededRng(seed)
    local s = seed * 2654435761
    return function()
        s = (s * 1103515245 + 12345) % 2147483648
        return s / 2147483648
    end
end

---Generate objectives for a level
---@param levelNum integer
---@param config LevelConfig
---@return Objective[]
local function generateObjectives(levelNum, config)
    local objectives = {}

    -- Primary objective: always score
    table.insert(objectives, {
        type = "score",
        target = config.targetScore,
        description = "Score " .. config.targetScore,
    })

    -- Secondary objectives start at Lv15
    if levelNum < 15 then return objectives end

    -- Use level-seeded RNG (offset from modifier seed)
    local rng = seededRng(levelNum * 7 + 31)

    -- ~60% chance of a secondary objective
    if rng() > 0.6 then return objectives end

    -- Pick secondary objective type
    local types = { "collect", "combo", "specials" }
    -- moves_left only available if enough moves
    if config.maxMoves >= 12 then
        table.insert(types, "moves_left")
    end

    local pick = types[math.floor(rng() * #types) + 1]

    if pick == "collect" then
        -- Collect N gems of a specific color
        local gemType = math.floor(rng() * config.numGemTypes) + 1
        local colorNames = { "Red", "Blue", "Green", "Yellow", "Purple", "Orange", "Cyan" }
        local count = math.floor(10 + rng() * 15) -- 10-24
        table.insert(objectives, {
            type = "collect",
            target = count,
            gemType = gemType,
            description = string.format("Collect %d %s", count, colorNames[gemType] or "?"),
        })
    elseif pick == "combo" then
        -- Reach N combo
        local target = math.floor(3 + rng() * 3) -- 3-5
        table.insert(objectives, {
            type = "combo",
            target = target,
            description = string.format("Reach %dx combo", target),
        })
    elseif pick == "specials" then
        -- Create N special gems
        local target = math.floor(3 + rng() * 4) -- 3-6
        table.insert(objectives, {
            type = "specials",
            target = target,
            description = string.format("Create %d specials", target),
        })
    elseif pick == "moves_left" then
        -- Finish with N+ moves remaining
        local target = math.floor(config.maxMoves * (0.15 + rng() * 0.1)) -- 15-25% of moves
        target = math.max(2, target)
        table.insert(objectives, {
            type = "moves_left",
            target = target,
            description = string.format("Finish with %d+ moves", target),
        })
    end

    return objectives
end

---Generate base config without modifiers/objectives (for testing base difficulty)
---@param levelNum integer
---@return LevelConfig
function Level.generateBase(levelNum)
    return Level._buildBase(levelNum)
end

---@param levelNum integer
---@return LevelConfig
function Level._buildBase(levelNum)
    --   Lv1-8:   5 gems (tutorial + learning)
    --   Lv9-24:  6 gems (core game, 16 levels to master)
    --   Lv25-50: 7 gems (expert, long runway)
    --   Lv51+:   7 gems (endgame plateau)
    -- ================================================================
    local numGemTypes
    if levelNum <= 8 then
        numGemTypes = 5
    elseif levelNum <= 24 then
        numGemTypes = 6
    else
        numGemTypes = 7
    end

    -- ================================================================
    -- Target score: phase-based with asymptotic growth
    -- Each phase has a ceiling — target approaches but never exceeds it.
    -- Formula: base + range * (1 - e^(-rate * phase_progress))
    -- This gives fast early growth that slows toward the cap.
    --
    --   5 gems: 300 → ~1000 (cap ~1050)
    --   6 gems: 950 → ~2100 (cap ~2200)
    --   7 gems: 1900 → ~3200 (cap ~3500)
    -- Target DROPS at transitions → breathing room
    -- ================================================================
    local targetScore
    if numGemTypes == 5 then
        -- Lv1-8: 300→1000, gentle linear (8 levels, plenty of room)
        targetScore = 200 + levelNum * 100
    elseif numGemTypes == 6 then
        -- Lv9-24: asymptotic ~950→2050, starts below Lv8 target (breathing room)
        local phase = levelNum - 8   -- 1..16
        local range = 1200           -- 850 + 1200 = 2050 cap
        targetScore = math.floor(850 + range * (1 - math.exp(-0.1 * phase)))
    else
        -- Lv25+: asymptotic ~1700→2800, starts below Lv24 target (breathing room)
        local phase = levelNum - 24  -- 1..76
        local range = 1200           -- 1600 + 1200 = 2800 cap
        targetScore = math.floor(1600 + range * (1 - math.exp(-0.03 * phase)))
    end

    -- ================================================================
    -- Moves: asymptotic decrease toward phase-specific floors
    -- Uses exponential decay so late levels barely lose moves.
    --   5 gems: 32 → ~26   (tutorial comfort)
    --   6 gems: ~25 → ~20  (gradually tightens)
    --   7 gems: ~22 → ~18  (DDA compensates)
    -- Bonus at transition levels
    -- ================================================================
    local movesFloor
    if numGemTypes == 5 then movesFloor = 26
    elseif numGemTypes == 6 then movesFloor = 20
    else movesFloor = 18
    end
    -- Exponential decay from 32 toward floor
    local movesRange = 32 - movesFloor
    local maxMoves = math.floor(movesFloor + movesRange * math.exp(-0.06 * (levelNum - 1)))
    -- Bonus at gem-type transition levels
    if levelNum == 9 or levelNum == 25 then
        maxMoves = maxMoves + 3
    elseif levelNum == 10 or levelNum == 26 then
        maxMoves = maxMoves + 2
    elseif levelNum == 11 or levelNum == 27 then
        maxMoves = maxMoves + 1
    end

    -- ================================================================
    -- Drop bias: phased assist
    --   Lv1-3:   +0.25 (tutorial)
    --   Lv4-8:   +0.10 (learning)
    --   Lv9-16:   0.00 (neutral, new 6 gems)
    --   Lv17-24: -0.05 (light challenge)
    --   Lv25-30: +0.05 (7-gem compensation)
    --   Lv31+:    0.00 (expert neutral)
    -- ================================================================
    local dropBias
    if levelNum <= 3 then
        dropBias = 0.25
    elseif levelNum <= 8 then
        dropBias = 0.10
    elseif levelNum <= 16 then
        dropBias = 0
    elseif levelNum <= 24 then
        dropBias = -0.05
    elseif levelNum <= 30 then
        dropBias = 0.05
    else
        dropBias = 0
    end

    return {
        number = levelNum,
        numGemTypes = numGemTypes,
        targetScore = targetScore,
        maxMoves = maxMoves,
        dropBias = dropBias,
        modifiers = {},
        gridSize = 8,
        scoreMultiplier = 1.0,
        objectives = {},
    }
end

---@param levelNum integer
---@return LevelConfig
function Level.generate(levelNum)
    local config = Level._buildBase(levelNum)

    -- ================================================================
    -- Modifiers: deterministic assignment based on level number
    -- ================================================================
    local modNames = Modifiers.assign(levelNum)
    config.modifiers = modNames
    Modifiers.apply(config, modNames)

    -- ================================================================
    -- Objectives: primary (score) + optional secondary from Lv15
    -- ================================================================
    config.objectives = generateObjectives(levelNum, config)

    return config
end

---@param levelNum integer
function Level.start(levelNum)
    Level.current = Level.generate(levelNum)
    if levelNum > Level.maxReached then
        Level.maxReached = levelNum
    end
end

function Level.next()
    Level.start(Level.current.number + 1)
end

function Level.retry()
    Level.start(Level.current.number)
end

return Level

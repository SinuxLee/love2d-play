---@class ModifierDef
---@field name string
---@field description string
---@field pool "mild"|"full"     -- mild = available from Lv10, full = from Lv25
---@field exclusive? string[]    -- modifier names this is incompatible with
---@field apply fun(config: LevelConfig) -- mutate config in-place

---@class Modifiers
local Modifiers = {}

---@type table<string, ModifierDef>
Modifiers.defs = {
    cascade_king = {
        name = "cascade_king",
        description = "Cascade +50% score",
        pool = "mild",
        apply = function(config)
            -- Effect handled in states.lua scoring logic
        end,
    },
    color_limit = {
        name = "color_limit",
        description = "-1 gem type, +20% target",
        pool = "mild",
        exclusive = { "big_board" },
        apply = function(config)
            config.numGemTypes = math.max(3, config.numGemTypes - 1)
            config.targetScore = math.floor(config.targetScore * 1.2)
        end,
    },
    big_board = {
        name = "big_board",
        description = "9x9 board",
        pool = "full",
        exclusive = { "small_board", "color_limit" },
        apply = function(config)
            config.gridSize = 9
        end,
    },
    small_board = {
        name = "small_board",
        description = "6x6 board, -25% target",
        pool = "full",
        exclusive = { "big_board", "fragile" },
        apply = function(config)
            config.gridSize = 6
            config.numGemTypes = math.min(config.numGemTypes, 6)
            config.targetScore = math.floor(config.targetScore * 0.75)
        end,
    },
    no_specials = {
        name = "no_specials",
        description = "No special gems",
        pool = "full",
        exclusive = { "special_start" },
        apply = function(config)
            -- Effect handled in grid.lua findMatches
        end,
    },
    special_start = {
        name = "special_start",
        description = "3 initial specials",
        pool = "mild",
        exclusive = { "no_specials" },
        apply = function(config)
            -- Effect handled in grid.lua after init
        end,
    },
    fragile = {
        name = "fragile",
        description = "-25% moves, x1.5 base score",
        pool = "full",
        exclusive = { "small_board" },
        apply = function(config)
            config.maxMoves = math.max(8, math.floor(config.maxMoves * 0.75))
            config.scoreMultiplier = (config.scoreMultiplier or 1.0) * 1.5
        end,
    },
    generous = {
        name = "generous",
        description = "+0.2 dropBias, +15% target",
        pool = "mild",
        apply = function(config)
            config.dropBias = config.dropBias + 0.2
            config.targetScore = math.floor(config.targetScore * 1.15)
        end,
    },
}

---Mild pool: modifiers available from Lv10
---@type string[]
Modifiers.mildPool = { "cascade_king", "color_limit", "special_start", "generous" }

---Full pool: all modifiers, available from Lv25
---@type string[]
Modifiers.fullPool = { "cascade_king", "color_limit", "special_start", "generous",
    "big_board", "small_board", "no_specials", "fragile" }

---Simple deterministic PRNG seeded per level number
---@param seed integer
---@return fun(): number  returns 0.0-1.0
local function seededRng(seed)
    local s = seed * 2654435761 -- Knuth multiplicative hash
    return function()
        s = (s * 1103515245 + 12345) % 2147483648
        return s / 2147483648
    end
end

---Check if two modifiers are mutually exclusive
---@param a string
---@param b string
---@return boolean
local function areExclusive(a, b)
    local defA = Modifiers.defs[a]
    if defA and defA.exclusive then
        for _, ex in ipairs(defA.exclusive) do
            if ex == b then return true end
        end
    end
    local defB = Modifiers.defs[b]
    if defB and defB.exclusive then
        for _, ex in ipairs(defB.exclusive) do
            if ex == a then return true end
        end
    end
    return false
end

---Deterministically assign modifiers for a given level number
---@param levelNum integer
---@return string[]
function Modifiers.assign(levelNum)
    if levelNum < 10 then return {} end

    local rng = seededRng(levelNum)

    -- Determine pool and count
    local pool, maxCount
    if levelNum < 25 then
        pool = Modifiers.mildPool
        maxCount = 1
    elseif levelNum < 50 then
        pool = Modifiers.fullPool
        maxCount = rng() < 0.5 and 1 or 2
    else
        pool = Modifiers.fullPool
        maxCount = 2
    end

    -- Shuffle pool using Fisher-Yates with our seeded RNG
    local shuffled = {}
    for i, v in ipairs(pool) do shuffled[i] = v end
    for i = #shuffled, 2, -1 do
        local j = math.floor(rng() * i) + 1
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Pick modifiers, skipping exclusives
    local chosen = {}
    for _, name in ipairs(shuffled) do
        if #chosen >= maxCount then break end
        local ok = true
        for _, existing in ipairs(chosen) do
            if areExclusive(name, existing) then
                ok = false
                break
            end
        end
        if ok then
            table.insert(chosen, name)
        end
    end

    return chosen
end

---Apply a list of modifiers to a LevelConfig (mutates in-place)
---@param config LevelConfig
---@param modifierNames string[]
function Modifiers.apply(config, modifierNames)
    for _, name in ipairs(modifierNames) do
        local def = Modifiers.defs[name]
        if def then
            def.apply(config)
        end
    end
end

---Check if a modifier list contains a given modifier
---@param modifierNames string[]
---@param name string
---@return boolean
function Modifiers.has(modifierNames, name)
    for _, n in ipairs(modifierNames) do
        if n == name then return true end
    end
    return false
end

return Modifiers

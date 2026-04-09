---@diagnostic disable: undefined-global

--- Skill-adaptive hint system.
--- Selects hint strategy and idle timeout based on player archetype.
--- Computes hints using autoplay strategies without executing moves.

local Grid = require("core.grid")
local Autoplay = require("tools.autoplay")
local Logger = require("tools.logger")

---@class Hints
---@field enabled boolean       hint system enabled
---@field idleTime number       seconds since last player swap
---@field hintMove AutoplayMove|nil  current hint suggestion
---@field hintVisible boolean   true when hint should be shown
---@field flashTimer number     animation timer for hint flash
local Hints = {}
Hints.enabled = false
Hints.idleTime = 0
Hints.hintMove = nil
Hints.hintVisible = false
Hints.flashTimer = 0

-- Archetype → strategy name mapping
local STRATEGY_MAP = {
    casual   = "montecarlo",
    normal   = "heuristic",
    hardcore = "greedy",
    expert   = "greedy",
}

-- Archetype → idle timeout in seconds
local TIMEOUT_MAP = {
    casual   = 5,
    normal   = 10,
    hardcore = 20,
    expert   = 30,
}

---Get strategy name for a given archetype
---@param archetype string
---@return string
function Hints.getStrategy(archetype)
    return STRATEGY_MAP[archetype] or "heuristic"
end

---Get idle timeout for a given archetype
---@param archetype string
---@return number
function Hints.getTimeout(archetype)
    return TIMEOUT_MAP[archetype] or 10
end

---Reset hint state (call on new level or after a swap)
function Hints.reset()
    Hints.idleTime = 0
    Hints.hintMove = nil
    Hints.hintVisible = false
    Hints.flashTimer = 0
end

---Compute objective bonus for a swap (boost moves that progress objectives)
---@param r1 integer
---@param c1 integer
---@param r2 integer
---@param c2 integer
---@return number bonus  0 or positive
local function objectiveBonus(r1, c1, r2, c2)
    local Level = require("systems.level")
    local config = Level.current
    if not config or not config.objectives then return 0 end

    -- Do a trial swap to find what would match
    local gem1 = Grid.cells[r1][c1]
    local gem2 = Grid.cells[r2][c2]
    if not gem1 or not gem2 then return 0 end

    Grid.swap(r1, c1, r2, c2)
    local matched = Grid.findMatches(r1, c1)
    Grid.swap(r1, c1, r2, c2) -- undo

    local bonus = 0
    for _, obj in ipairs(config.objectives) do
        if obj.type == "collect" and obj.gemType then
            -- Count how many of the target gem type are in matched set
            for gem in pairs(matched) do
                if gem.type == obj.gemType then
                    bonus = bonus + 5
                end
            end
        elseif obj.type == "specials" then
            -- Bonus for moves that activate specials
            for gem in pairs(matched) do
                if gem.special then
                    bonus = bonus + 3
                end
            end
        elseif obj.type == "combo" then
            -- Can't easily predict combo from single swap, give small bonus for large matches
            local count = 0
            for _ in pairs(matched) do count = count + 1 end
            if count >= 5 then bonus = bonus + 2 end
        end
    end
    return bonus
end

---Compute a hint move for the current board state
---Applies objective-aware scoring on top of strategy move
---@param archetype string
---@return AutoplayMove|nil
function Hints.compute(archetype)
    local stratName = Hints.getStrategy(archetype)
    local strat = Autoplay.strategies[stratName]
    if not strat then
        strat = Autoplay.strategies.greedy
    end
    local move = strat(Grid.cells, Grid.numGemTypes)

    -- If objectives are active, check if there's a better objective-aligned move
    local Level = require("systems.level")
    local config = Level.current
    if move and config and config.objectives and #config.objectives > 0 then
        -- Score the strategy's best move with objective bonus
        local bestBonus = objectiveBonus(move.r1, move.c1, move.r2, move.c2)
        local bestScore = (move.score or 0) + bestBonus

        -- Also check all valid swaps for objective-boosted alternatives
        local SIZE = Grid.size
        for row = 1, SIZE do
            for col = 1, SIZE do
                if not Grid.cells[row][col] then goto continue end
                -- Try rightward and downward swaps
                local neighbors = {}
                if col < SIZE and Grid.cells[row][col + 1] then
                    neighbors[#neighbors + 1] = {row, col, row, col + 1}
                end
                if row < SIZE and Grid.cells[row + 1] and Grid.cells[row + 1][col] then
                    neighbors[#neighbors + 1] = {row, col, row + 1, col}
                end
                for _, n in ipairs(neighbors) do
                    local baseScore = Autoplay.evaluateSwap(n[1], n[2], n[3], n[4])
                    if baseScore > 0 then
                        local ob = objectiveBonus(n[1], n[2], n[3], n[4])
                        local totalScore = baseScore + ob
                        if totalScore > bestScore then
                            bestScore = totalScore
                            move = { r1 = n[1], c1 = n[2], r2 = n[3], c2 = n[4], score = totalScore }
                        end
                    end
                end
                ::continue::
            end
        end
    end

    return move
end

---Update hint system each frame
---@param dt number
---@param archetype string
---@param isIdle boolean  true when game state is "idle"
function Hints.update(dt, archetype, isIdle)
    if not Hints.enabled then
        Hints.hintVisible = false
        return
    end

    if not isIdle then
        Hints.reset()
        return
    end

    Hints.idleTime = Hints.idleTime + dt

    local timeout = Hints.getTimeout(archetype)
    if not Hints.hintVisible and Hints.idleTime >= timeout then
        -- Compute hint
        local move = Hints.compute(archetype)
        if move then
            Hints.hintMove = move
            Hints.hintVisible = true
            Logger.debug("hints", "show", {
                archetype = archetype, strategy = Hints.getStrategy(archetype),
                idle_time = Hints.idleTime, r1 = move.r1, c1 = move.c1,
                r2 = move.r2, c2 = move.c2,
            })
        end
    end

    -- Flash animation timer
    if Hints.hintVisible then
        Hints.flashTimer = Hints.flashTimer + dt
    end
end

---Notify that the player made a swap
function Hints.onSwap()
    Hints.reset()
end

-- Expose maps for testing/GM
Hints.STRATEGY_MAP = STRATEGY_MAP
Hints.TIMEOUT_MAP = TIMEOUT_MAP

return Hints

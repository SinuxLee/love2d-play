local Grid = require("core.grid")
local Utils = require("core.utils")
local Logger = require("tools.logger")

---@alias AutoplayStrategy fun(cells: (Gem|nil)[][], numGemTypes: integer): AutoplayMove|nil

---@class AutoplayMove
---@field r1 integer
---@field c1 integer
---@field r2 integer
---@field c2 integer
---@field score number

---@class LevelRecord
---@field level integer          level number
---@field result "pass"|"fail"
---@field score integer          final score
---@field targetScore integer
---@field moves integer          moves used
---@field maxMoves integer       moves allowed
---@field failCount integer      consecutive fails before this attempt
---@field bias number            effective drop bias at end
---@field curve string           DDA curve name
---@field strategy string        autoplay strategy name
---@field gemTypes integer       number of gem types

---@class Autoplay
---@field enabled boolean
---@field timer number
---@field interval number        seconds between moves
---@field strategies table<string, AutoplayStrategy>
---@field currentStrategy string
---@field levelMoves integer     moves made in current level attempt
---@field log LevelRecord[]      full history of level attempts
---@field summary AutoplaySummary cached summary stats
---@field benchmark? fun()        set by tools.benchmark
---@field benchmarkML? fun()      set by tools.benchmark
---@field benchmarkLegacy? fun()  set by tools.benchmark
local Autoplay = {}
Autoplay.enabled = false
Autoplay.timer = 0
Autoplay.interval = 1.0
Autoplay.strategies = {}
Autoplay.currentStrategy = "greedy"
Autoplay.levelMoves = 0
Autoplay.log = {}

---@class AutoplaySummary
---@field totalAttempts integer
---@field totalPasses integer
---@field totalFails integer
---@field passRate number          0.0-1.0
---@field avgMovesPerPass number
---@field avgScorePerPass number
---@field levelsReached integer    highest level passed + 1
---@field currentStreak integer    current consecutive pass/fail streak (positive=pass, negative=fail)
Autoplay.summary = {
    totalAttempts = 0, totalPasses = 0, totalFails = 0,
    passRate = 0, avgMovesPerPass = 0, avgScorePerPass = 0,
    levelsReached = 0, currentStreak = 0,
}

---Get list of registered strategy names (for GM panel radio group)
---@return string[]
function Autoplay.getStrategyNames()
    local names = {}
    for name in pairs(Autoplay.strategies) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

---Get index of current strategy in sorted names list
---@return integer
function Autoplay.getStrategyIndex()
    local names = Autoplay.getStrategyNames()
    for i, name in ipairs(names) do
        if name == Autoplay.currentStrategy then return i end
    end
    return 1
end

---Set strategy by index in sorted names list
---@param index integer
function Autoplay.setStrategyByIndex(index)
    local names = Autoplay.getStrategyNames()
    if names[index] then
        Autoplay.currentStrategy = names[index]
    end
end

---Reset per-level counters (call on new level attempt)
function Autoplay.reset()
    Autoplay.timer = 0
    Autoplay.levelMoves = 0
end

---Reset all data (call when toggling auto-play on)
function Autoplay.resetAll()
    Autoplay.timer = 0
    Autoplay.levelMoves = 0
    Autoplay.log = {}
    Autoplay.summary = {
        totalAttempts = 0, totalPasses = 0, totalFails = 0,
        passRate = 0, avgMovesPerPass = 0, avgScorePerPass = 0,
        levelsReached = 0, currentStreak = 0,
    }
end

---Recompute summary from log
local function refreshSummary()
    local s = Autoplay.summary
    s.totalAttempts = #Autoplay.log
    s.totalPasses = 0
    s.totalFails = 0
    local moveSum, scoreSum = 0, 0
    s.levelsReached = 0
    s.currentStreak = 0

    for i, rec in ipairs(Autoplay.log) do
        if rec.result == "pass" then
            s.totalPasses = s.totalPasses + 1
            moveSum = moveSum + rec.moves
            scoreSum = scoreSum + rec.score
            if rec.level >= s.levelsReached then
                s.levelsReached = rec.level + 1
            end
        else
            s.totalFails = s.totalFails + 1
        end

        -- Track streak from last entry
        if i == #Autoplay.log then
            -- Walk backwards for streak
            local streak = 0
            local streakType = rec.result
            for j = #Autoplay.log, 1, -1 do
                if Autoplay.log[j].result == streakType then
                    streak = streak + 1
                else
                    break
                end
            end
            s.currentStreak = streakType == "pass" and streak or -streak
        end
    end

    s.passRate = s.totalAttempts > 0 and (s.totalPasses / s.totalAttempts) or 0
    s.avgMovesPerPass = s.totalPasses > 0 and (moveSum / s.totalPasses) or 0
    s.avgScorePerPass = s.totalPasses > 0 and (scoreSum / s.totalPasses) or 0
end

---Record a level attempt result
---@param states States
---@param level LevelConfig
---@param result "pass"|"fail"
function Autoplay.recordLevel(states, level, result)
    local rec = {
        level = level.number,
        result = result,
        score = states.score,
        targetScore = level.targetScore,
        moves = level.maxMoves - states.movesLeft,
        maxMoves = level.maxMoves,
        failCount = states.failCount,
        bias = states.getEffectiveBias(),
        curve = states.ddaCurve,
        strategy = Autoplay.currentStrategy,
        gemTypes = level.numGemTypes,
    }
    table.insert(Autoplay.log, rec)
    refreshSummary()

    Logger.info("autoplay", "level_result", {
        level = rec.level, result = rec.result,
        score = rec.score, target = rec.targetScore,
        moves_used = rec.moves, moves_max = rec.maxMoves,
        fail_count = rec.failCount, bias = rec.bias,
        strategy = rec.strategy, gems = rec.gemTypes,
    })
end

---Get per-level breakdown: for each level number, return {attempts, passes, fails, avgBias}
---@return table<integer, {attempts:integer, passes:integer, fails:integer, avgBias:number}>
function Autoplay.getLevelBreakdown()
    local breakdown = {}
    for _, rec in ipairs(Autoplay.log) do
        local b = breakdown[rec.level]
        if not b then
            b = { attempts = 0, passes = 0, fails = 0, biasSum = 0 }
            breakdown[rec.level] = b
        end
        b.attempts = b.attempts + 1
        if rec.result == "pass" then
            b.passes = b.passes + 1
        else
            b.fails = b.fails + 1
        end
        b.biasSum = b.biasSum + rec.bias
    end
    -- Compute avgBias
    for _, b in pairs(breakdown) do
        b.avgBias = b.biasSum / b.attempts
        b.biasSum = nil
    end
    return breakdown
end

---Find the best move using the current strategy
---@return AutoplayMove|nil
function Autoplay.findBestMove()
    local strategy = Autoplay.strategies[Autoplay.currentStrategy]
    if not strategy then return nil end
    return strategy(Grid.cells, Grid.numGemTypes)
end

---@type boolean  guard to record level result only once per outcome
local pendingRecord = false

---@param dt number
---@param states States
function Autoplay.update(dt, states)
    if not Autoplay.enabled then return end

    local Level = require("systems.level")

    -- Auto-advance on level complete/fail
    if states.current == "level_complete" then
        if not pendingRecord then
            pendingRecord = true
            Autoplay.recordLevel(states, Level.current, "pass")
        end
        Autoplay.timer = Autoplay.timer + dt
        if Autoplay.timer >= 1.0 then
            Autoplay.timer = 0
            Autoplay.levelMoves = 0
            pendingRecord = false
            states.nextLevel()
        end
        return
    elseif states.current == "level_fail" then
        if not pendingRecord then
            pendingRecord = true
            Autoplay.recordLevel(states, Level.current, "fail")
        end
        Autoplay.timer = Autoplay.timer + dt
        if Autoplay.timer >= 1.0 then
            Autoplay.timer = 0
            Autoplay.levelMoves = 0
            pendingRecord = false
            states.retryLevel()
        end
        return
    end

    pendingRecord = false

    if states.current ~= "idle" then return end

    Autoplay.timer = Autoplay.timer + dt
    if Autoplay.timer < Autoplay.interval then return end
    Autoplay.timer = 0

    local move = Autoplay.findBestMove()
    if move then
        Autoplay.levelMoves = Autoplay.levelMoves + 1
        states.startSwap(move.r1, move.c1, move.r2, move.c2)
    end
end

-- ============================================================
-- Built-in strategy: greedy
-- Evaluates all possible swaps, picks the one with highest
-- immediate score (match count + special bonuses).
-- ============================================================

---Evaluate a single swap candidate
---@param r1 integer
---@param c1 integer
---@param r2 integer
---@param c2 integer
---@return number score  (-1 if invalid)
local function evaluateSwap(r1, c1, r2, c2)
    local gem1 = Grid.cells[r1][c1]
    local gem2 = Grid.cells[r2][c2]
    if not gem1 or not gem2 then return -1 end

    -- Color bomb swaps are always highest value
    if gem1.special == "color_bomb" or gem2.special == "color_bomb" then
        return 100
    end

    -- Special + special combos
    if gem1.special and gem2.special then
        return 80
    end

    -- Normal swap: do it, check matches, undo it
    Grid.swap(r1, c1, r2, c2)
    local matched, specials = Grid.findMatches(r1, c1)
    Grid.swap(r1, c1, r2, c2) -- undo

    local matchCount = 0
    for _ in pairs(matched) do matchCount = matchCount + 1 end

    if matchCount == 0 then return -1 end

    local score = matchCount

    -- Bonus for creating new specials
    if specials then
        for _, sp in ipairs(specials) do
            if sp.special == "color_bomb" then
                score = score + 20
            elseif sp.special == "wrapped" then
                score = score + 10
            elseif sp.special == "striped_h" or sp.special == "striped_v" then
                score = score + 7
            end
        end
    end

    -- Bonus for activating existing specials in the matched set
    for gem in pairs(matched) do
        if gem.special == "striped_h" or gem.special == "striped_v" then
            score = score + 8
        elseif gem.special == "wrapped" then
            score = score + 5
        end
    end

    return score
end

-- Expose for testing
Autoplay.evaluateSwap = evaluateSwap

---@param cells (Gem|nil)[][]
---@param _numGemTypes integer
---@return AutoplayMove|nil
Autoplay.strategies.greedy = function(cells, _numGemTypes)
    local bestMove = nil
    local bestScore = -1
    local SIZE = Grid.size

    for row = 1, SIZE do
        for col = 1, SIZE do
            if not cells[row][col] then goto continue end

            -- Try rightward swap
            if col < SIZE and cells[row][col + 1] then
                local score = evaluateSwap(row, col, row, col + 1)
                if score > bestScore then
                    bestScore = score
                    bestMove = { r1 = row, c1 = col, r2 = row, c2 = col + 1, score = score }
                end
            end

            -- Try downward swap
            if row < SIZE and cells[row + 1] and cells[row + 1][col] then
                local score = evaluateSwap(row, col, row + 1, col)
                if score > bestScore then
                    bestScore = score
                    bestMove = { r1 = row, c1 = col, r2 = row + 1, c2 = col, score = score }
                end
            end

            ::continue::
        end
    end

    return bestMove
end

-- ============================================================
-- Lightweight board simulation engine
-- Operates on a simple board[r][c] = {type=int, special=str|nil}
-- without touching Grid.cells or triggering animations.
-- ============================================================

---Clone current Grid.cells into a lightweight board
---@return table[][]
local function cloneBoard()
    local SIZE = Grid.size
    local board = {}
    for row = 1, SIZE do
        board[row] = {}
        for col = 1, SIZE do
            local gem = Grid.cells[row][col]
            if gem then
                board[row][col] = { type = gem.type, special = gem.special }
            end
        end
    end
    return board
end

---Find all matches on a simulated board
---@param board table[][]
---@return table<integer, {row:integer, col:integer}> matched  key = r*16+c
---@return integer count
local function simFindMatches(board)
    local matched = {}
    local count = 0
    local SIZE = Grid.size

    local function add(r, c)
        local key = r * 16 + c
        if not matched[key] then
            matched[key] = { row = r, col = c }
            count = count + 1
        end
    end

    -- Horizontal runs
    for row = 1, SIZE do
        local start = 1
        for col = 2, SIZE + 1 do
            local same = col <= SIZE and board[row][col] and board[row][start]
                and board[row][col].type == board[row][start].type
            if not same then
                if col - start >= 3 then
                    for c = start, col - 1 do add(row, c) end
                end
                start = col
            end
        end
    end

    -- Vertical runs
    for col = 1, SIZE do
        local start = 1
        for row = 2, SIZE + 1 do
            local same = row <= SIZE and board[row][col] and board[start][col]
                and board[row][col].type == board[start][col].type
            if not same then
                if row - start >= 3 then
                    for r = start, row - 1 do add(r, col) end
                end
                start = row
            end
        end
    end

    return matched, count
end

---Activate specials in matched set (chain reactions on simulated board)
---@param board table[][]
---@param matched table<integer, {row:integer, col:integer}>
local function simActivateSpecials(board, matched)
    local processed = {}
    local changed = true
    local SIZE = Grid.size

    while changed do
        changed = false
        for key, pos in pairs(matched) do
            if not processed[key] then
                local cell = board[pos.row][pos.col]
                if cell and cell.special then
                    processed[key] = true
                    changed = true

                    local function tryAdd(r, c)
                        local k = r * 16 + c
                        if not matched[k] then
                            matched[k] = { row = r, col = c }
                        end
                    end

                    if cell.special == "striped_h" then
                        for c = 1, SIZE do tryAdd(pos.row, c) end
                    elseif cell.special == "striped_v" then
                        for r = 1, SIZE do tryAdd(r, pos.col) end
                    elseif cell.special == "wrapped" then
                        for dr = -1, 1 do
                            for dc = -1, 1 do
                                local r, c = pos.row + dr, pos.col + dc
                                if r >= 1 and r <= SIZE and c >= 1 and c <= SIZE then
                                    tryAdd(r, c)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

---Apply gravity on simulated board: gems fall down, empty cells filled randomly
---@param board table[][]
---@param numGemTypes integer
local function simGravity(board, numGemTypes)
    local SIZE = Grid.size
    for col = 1, SIZE do
        local write = SIZE
        for row = SIZE, 1, -1 do
            if board[row][col] then
                if write ~= row then
                    board[write][col] = board[row][col]
                    board[row][col] = nil
                end
                write = write - 1
            end
        end
        for row = write, 1, -1 do
            board[row][col] = { type = math.random(numGemTypes), special = nil }
        end
    end
end

---Run a full cascade simulation. Returns total gems cleared.
---@param board table[][]
---@param numGemTypes integer
---@return integer totalCleared
local function simCascade(board, numGemTypes)
    local total = 0
    for _ = 1, 30 do
        local matched, count = simFindMatches(board)
        if count == 0 then break end
        simActivateSpecials(board, matched)
        -- Recount after specials
        count = 0
        for _ in pairs(matched) do count = count + 1 end
        total = total + count
        for _, pos in pairs(matched) do
            board[pos.row][pos.col] = nil
        end
        simGravity(board, numGemTypes)
    end
    return total
end

---Check if a swap is valid (produces at least one match)
---@return boolean valid
local function isSwapValid(r1, c1, r2, c2)
    local gem1 = Grid.cells[r1][c1]
    local gem2 = Grid.cells[r2][c2]
    if not gem1 or not gem2 then return false end
    if gem1.special == "color_bomb" or gem2.special == "color_bomb" then return true end
    if gem1.special and gem2.special then return true end

    Grid.swap(r1, c1, r2, c2)
    local matched = Grid.findMatches(r1, c1)
    Grid.swap(r1, c1, r2, c2)

    for _ in pairs(matched) do return true end
    return false
end

---Collect all valid swap candidates
---@return {r1:integer, c1:integer, r2:integer, c2:integer}[]
local function collectValidSwaps()
    local swaps = {}
    local SIZE = Grid.size
    for row = 1, SIZE do
        for col = 1, SIZE do
            if not Grid.cells[row][col] then goto continue end
            if col < SIZE and Grid.cells[row][col + 1] then
                if isSwapValid(row, col, row, col + 1) then
                    table.insert(swaps, { r1 = row, c1 = col, r2 = row, c2 = col + 1 })
                end
            end
            if row < SIZE and Grid.cells[row + 1] and Grid.cells[row + 1][col] then
                if isSwapValid(row, col, row + 1, col) then
                    table.insert(swaps, { r1 = row, c1 = col, r2 = row + 1, c2 = col })
                end
            end
            ::continue::
        end
    end
    return swaps
end

-- Expose simulation helpers for testing
Autoplay.cloneBoard = cloneBoard
Autoplay.simFindMatches = simFindMatches
Autoplay.simCascade = simCascade

-- ============================================================
-- Strategy: montecarlo
-- For each valid move, simulate K complete cascades with random
-- gem fills. Pick the move with highest average gems cleared.
-- Handles randomness properly — the gold standard for stochastic games.
-- ============================================================

Autoplay.strategies.montecarlo = function(_cells, numGemTypes)
    local K = 15
    local swaps = collectValidSwaps()
    if #swaps == 0 then return nil end

    local bestMove = nil
    local bestAvg = -1

    for _, sw in ipairs(swaps) do
        local totalCleared = 0
        for _ = 1, K do
            local board = cloneBoard()
            board[sw.r1][sw.c1], board[sw.r2][sw.c2] = board[sw.r2][sw.c2], board[sw.r1][sw.c1]
            totalCleared = totalCleared + simCascade(board, numGemTypes)
        end
        local avg = totalCleared / K
        if avg > bestAvg then
            bestAvg = avg
            bestMove = { r1 = sw.r1, c1 = sw.c1, r2 = sw.r2, c2 = sw.c2, score = avg }
        end
    end

    return bestMove
end

-- ============================================================
-- Strategy: heuristic
-- Greedy base score + single cascade simulation + board potential.
-- Evaluates resulting board quality by counting adjacent same-color
-- pairs (predicting future match opportunities).
-- ============================================================

---Count pairs of adjacent same-type cells (horizontal + vertical)
---@param board table[][]
---@return integer
local function boardPotential(board)
    local p = 0
    local SIZE = Grid.size
    for row = 1, SIZE do
        for col = 1, SIZE do
            local cell = board[row][col]
            if cell then
                if col < SIZE and board[row][col + 1]
                    and board[row][col + 1].type == cell.type then
                    p = p + 1
                end
                if row < SIZE and board[row + 1][col]
                    and board[row + 1][col].type == cell.type then
                    p = p + 1
                end
            end
        end
    end
    return p
end

Autoplay.strategies.heuristic = function(_cells, numGemTypes)
    local swaps = collectValidSwaps()
    if #swaps == 0 then return nil end

    local bestMove = nil
    local bestScore = -1

    for _, sw in ipairs(swaps) do
        local greedyScore = evaluateSwap(sw.r1, sw.c1, sw.r2, sw.c2)
        if greedyScore < 0 then goto nextSwap end

        -- Simulate one cascade to get resulting board state
        local board = cloneBoard()
        board[sw.r1][sw.c1], board[sw.r2][sw.c2] = board[sw.r2][sw.c2], board[sw.r1][sw.c1]
        local cleared = simCascade(board, numGemTypes)

        local potential = boardPotential(board)

        -- Combined: immediate value + cascade depth + future potential
        local score = greedyScore + cleared * 0.5 + potential * 0.3

        if score > bestScore then
            bestScore = score
            bestMove = { r1 = sw.r1, c1 = sw.c1, r2 = sw.r2, c2 = sw.c2, score = score }
        end

        ::nextSwap::
    end

    return bestMove
end

return Autoplay

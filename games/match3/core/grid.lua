local Utils = require("core.utils")
local Gem = require("core.gem")
local Tweens = require("core.animation")

---@type Effects?
local Effects = nil

---Lazy-load effects module (not available in test mode)
---@return Effects?
local function getEffects()
    if Effects == nil then
        -- Only load effects when love.graphics is available (not in test mode)
        if love and love.graphics and love.graphics.newCanvas then
            local ok, mod = pcall(require, "core.effects")
            Effects = ok and mod or false
        else
            Effects = false
        end
    end
    return Effects or nil
end

---@class Grid
---@field cells (Gem|nil)[][]
---@field numGemTypes integer
---@field size integer          -- current board edge length
---@field noSpecials boolean    -- true when no_specials modifier is active
local Grid = {}
Grid.cells = {}
Grid.numGemTypes = 7
Grid.size = 8
Grid.noSpecials = false

---@param excluded? table<integer, boolean>
---@return integer
local function randomType(excluded)
    local choices = {}
    for i = 1, Grid.numGemTypes do
        if not excluded or not excluded[i] then
            table.insert(choices, i)
        end
    end
    return choices[math.random(#choices)]
end

---@param numGemTypes? integer
---@param gridSize? integer
function Grid.init(numGemTypes, gridSize)
    Grid.numGemTypes = numGemTypes or Utils.NUM_GEM_TYPES
    Grid.size = gridSize or 8
    Grid.noSpecials = false
    Utils.setGridSize(Grid.size)
    -- Loop instead of recursion to avoid stack overflow in benchmark
    for attempt = 1, 50 do
        if attempt == 1 then math.randomseed(os.time()) end
        Grid.cells = {}
        for row = 1, Grid.size do
            Grid.cells[row] = {}
            for col = 1, Grid.size do
                local excluded = {}
                if col >= 3 then
                    local t1 = Grid.cells[row][col - 1] and Grid.cells[row][col - 1].type
                    local t2 = Grid.cells[row][col - 2] and Grid.cells[row][col - 2].type
                    if t1 and t2 and t1 == t2 then
                        excluded[t1] = true
                    end
                end
                if row >= 3 then
                    local t1 = Grid.cells[row - 1] and Grid.cells[row - 1][col] and Grid.cells[row - 1][col].type
                    local t2 = Grid.cells[row - 2] and Grid.cells[row - 2][col] and Grid.cells[row - 2][col].type
                    if t1 and t2 and t1 == t2 then
                        excluded[t1] = true
                    end
                end
                Grid.cells[row][col] = Gem.new(randomType(excluded), row, col)
            end
        end
        if Grid.hasValidMoves() then return end
    end
end

---Place random special gems on the initial board (for special_start modifier)
---@param count integer
function Grid.placeInitialSpecials(count)
    local specials = { "striped_h", "striped_v", "wrapped" }
    local placed = 0
    -- Deterministic placement using simple iteration
    for row = 1, Grid.size do
        for col = 1, Grid.size do
            if placed >= count then return end
            -- Spread evenly: pick cells based on hash
            local hash = (row * 7 + col * 13) % (Grid.size * Grid.size)
            if hash < count * 3 then
                local gem = Grid.cells[row][col]
                if gem and not gem.special and gem.type > 0 then
                    gem.special = specials[(placed % #specials) + 1]
                    placed = placed + 1
                end
            end
        end
    end
end

---@param r1 integer
---@param c1 integer
---@param r2 integer
---@param c2 integer
function Grid.swap(r1, c1, r2, c2)
    local gem1 = Grid.cells[r1][c1]
    local gem2 = Grid.cells[r2][c2]
    Grid.cells[r1][c1] = gem2
    Grid.cells[r2][c2] = gem1
    gem1.row, gem1.col = r2, c2
    gem2.row, gem2.col = r1, c1
    gem1.targetX, gem1.targetY = Utils.gridToPixel(r2, c2)
    gem2.targetX, gem2.targetY = Utils.gridToPixel(r1, c1)
end

---@param r1 integer
---@param c1 integer
---@param r2 integer
---@param c2 integer
---@param onComplete? fun()
function Grid.animateSwap(r1, c1, r2, c2, onComplete)
    local gem1 = Grid.cells[r1][c1]
    local gem2 = Grid.cells[r2][c2]
    local done = 0
    local function checkDone()
        done = done + 1
        if done >= 4 and onComplete then
            onComplete()
        end
    end
    Tweens.add(gem1, "x", gem1.targetX, Utils.SWAP_DURATION, "easeOutQuad", checkDone)
    Tweens.add(gem1, "y", gem1.targetY, Utils.SWAP_DURATION, "easeOutQuad", checkDone)
    Tweens.add(gem2, "x", gem2.targetX, Utils.SWAP_DURATION, "easeOutQuad", checkDone)
    Tweens.add(gem2, "y", gem2.targetY, Utils.SWAP_DURATION, "easeOutQuad", checkDone)
end

---@class MatchRun
---@field gems Gem[]
---@field type integer
---@field rowStart? integer
---@field rowEnd? integer
---@field colStart? integer
---@field colEnd? integer
---@field row? integer    for horizontal runs
---@field col? integer    for vertical runs
---@field direction "horizontal"|"vertical"

---Collect horizontal and vertical runs, detect patterns, return matched set + specials
---@param swapRow? integer  row of the swapped gem (for special placement)
---@param swapCol? integer  col of the swapped gem (for special placement)
---@return table<Gem, boolean> matched, SpecialSpawn[] specials
function Grid.findMatches(swapRow, swapCol)
    local matched = {}
    local specials = {}
    local SIZE = Grid.size

    -- Collect horizontal runs
    ---@type MatchRun[]
    local hRuns = {}
    for row = 1, SIZE do
        local start = 1
        for col = 2, SIZE + 1 do
            local sameType = col <= SIZE
                and Grid.cells[row][col]
                and Grid.cells[row][start]
                and Grid.cells[row][col].type == Grid.cells[row][start].type
            if not sameType then
                local len = col - start
                if len >= 3 then
                    local startCell = Grid.cells[row][start]
                    if startCell then
                        local run = { gems = {}, type = startCell.type,
                            row = row, colStart = start, colEnd = col - 1, direction = "horizontal" }
                        for c = start, col - 1 do
                            local cell = Grid.cells[row][c]
                            if cell then table.insert(run.gems, cell) end
                        end
                        table.insert(hRuns, run)
                    end
                end
                start = col
            end
        end
    end

    -- Collect vertical runs
    ---@type MatchRun[]
    local vRuns = {}
    for col = 1, SIZE do
        local start = 1
        for row = 2, SIZE + 1 do
            local sameType = row <= SIZE
                and Grid.cells[row][col]
                and Grid.cells[start][col]
                and Grid.cells[row][col].type == Grid.cells[start][col].type
            if not sameType then
                local len = row - start
                if len >= 3 then
                    local startCell = Grid.cells[start][col]
                    if startCell then
                        local run = { gems = {}, type = startCell.type,
                            col = col, rowStart = start, rowEnd = row - 1, direction = "vertical" }
                        for r = start, row - 1 do
                            local cell = Grid.cells[r][col]
                            if cell then table.insert(run.gems, cell) end
                        end
                        table.insert(vRuns, run)
                    end
                end
                start = row
            end
        end
    end

    -- Skip special generation if no_specials modifier is active
    local skipSpecials = Grid.noSpecials

    -- Detect L/T intersections → wrapped gems
    ---@type table<Gem, boolean>
    local usedForLT = {}
    ---@type table<string, boolean>
    local ltPairs = {}

    for hi, hRun in ipairs(hRuns) do
        for vi, vRun in ipairs(vRuns) do
            if hRun.type == vRun.type then
                if vRun.col >= hRun.colStart and vRun.col <= hRun.colEnd
                    and hRun.row >= vRun.rowStart and hRun.row <= vRun.rowEnd then
                    local key = hi .. "," .. vi
                    if not ltPairs[key] then
                        ltPairs[key] = true
                        if not skipSpecials then
                            table.insert(specials, {
                                row = hRun.row, col = vRun.col,
                                special = "wrapped", gemType = hRun.type
                            })
                        end
                        for _, g in ipairs(hRun.gems) do usedForLT[g] = true; matched[g] = true end
                        for _, g in ipairs(vRun.gems) do usedForLT[g] = true; matched[g] = true end
                    end
                end
            end
        end
    end

    -- Process remaining runs for line-4 (striped) and line-5 (color bomb)
    ---@param run MatchRun
    local function processRun(run)
        -- Check if this run is fully consumed by an L/T
        local dominated = false
        for _, g in ipairs(run.gems) do
            if not usedForLT[g] then dominated = false; break end
            dominated = true
        end
        if dominated then
            for _, g in ipairs(run.gems) do matched[g] = true end
            return
        end

        for _, g in ipairs(run.gems) do matched[g] = true end

        if skipSpecials then return end

        local len = #run.gems
        if len >= 5 then
            -- Color bomb at swap position or center
            local pivot = run.gems[math.ceil(len / 2)]
            if swapRow and swapCol then
                for _, g in ipairs(run.gems) do
                    if g.row == swapRow and g.col == swapCol then
                        pivot = g; break
                    end
                end
            end
            table.insert(specials, {
                row = pivot.row, col = pivot.col,
                special = "color_bomb", gemType = 0
            })
        elseif len == 4 then
            -- Striped gem: perpendicular to match direction
            local pivot = run.gems[2]
            if swapRow and swapCol then
                for _, g in ipairs(run.gems) do
                    if g.row == swapRow and g.col == swapCol then
                        pivot = g; break
                    end
                end
            end
            local stripe = run.direction == "horizontal" and "striped_v" or "striped_h"
            table.insert(specials, {
                row = pivot.row, col = pivot.col,
                special = stripe, gemType = run.type
            })
        end
    end

    for _, run in ipairs(hRuns) do processRun(run) end
    for _, run in ipairs(vRuns) do processRun(run) end

    return matched, specials
end

---Activate special gems in the matched set (chain reactions)
---@param matched table<Gem, boolean>
function Grid.activateSpecials(matched)
    local activated = {}
    local changed = true
    local SIZE = Grid.size

    while changed do
        changed = false
        for gem in pairs(matched) do
            if gem.special and not activated[gem] then
                activated[gem] = true
                changed = true

                -- Trigger special activation effects
                local fx = getEffects()
                if fx then
                    local color = Utils.GEM_COLORS[gem.type] or {1, 1, 1}
                    if gem.special == "striped_h" then
                        fx.lineSwipe(gem.x, gem.y, "horizontal", color)
                    elseif gem.special == "striped_v" then
                        fx.lineSwipe(gem.x, gem.y, "vertical", color)
                    elseif gem.special == "wrapped" then
                        fx.shockwave(gem.x, gem.y, color)
                    elseif gem.special == "color_bomb" then
                        fx.rainbow(gem.x, gem.y)
                    end
                end

                if gem.special == "striped_h" then
                    for c = 1, SIZE do
                        local g = Grid.cells[gem.row][c]
                        if g and not matched[g] then matched[g] = true end
                    end
                elseif gem.special == "striped_v" then
                    for r = 1, SIZE do
                        local g = Grid.cells[r][gem.col]
                        if g and not matched[g] then matched[g] = true end
                    end
                elseif gem.special == "wrapped" then
                    for dr = -1, 1 do
                        for dc = -1, 1 do
                            local r, c = gem.row + dr, gem.col + dc
                            if r >= 1 and r <= SIZE and c >= 1 and c <= SIZE then
                                local g = Grid.cells[r][c]
                                if g and not matched[g] then matched[g] = true end
                            end
                        end
                    end
                end
            end
        end
    end
end

---@param matched table<Gem, boolean>
---@param onComplete? fun()
---@return integer count
function Grid.removeMatches(matched, onComplete)
    local count = 0
    local totalAnims = 0
    local doneAnims = 0

    for gem, _ in pairs(matched) do
        count = count + 1
        totalAnims = totalAnims + 1
        gem.removing = true
        -- Trigger particle burst effect
        local fx = getEffects()
        if fx then
            local color = Utils.GEM_COLORS[gem.type] or {1, 1, 1}
            fx.burstAt(gem.x, gem.y, color)
        end
        Tweens.add(gem, "scale", 0, Utils.CLEAR_DURATION, "easeOutQuad")
        Tweens.add(gem, "alpha", 0, Utils.CLEAR_DURATION, "easeOutQuad", function()
            doneAnims = doneAnims + 1
            if doneAnims >= totalAnims and onComplete then
                onComplete()
            end
        end)
    end

    return count
end

function Grid.clearRemoved()
    for row = 1, Grid.size do
        for col = 1, Grid.size do
            if Grid.cells[row][col] and Grid.cells[row][col].removing then
                Grid.cells[row][col] = nil
            end
        end
    end
end

---Spawn special gems at specified positions (after clearing, before gravity)
---@param specials SpecialSpawn[]
function Grid.spawnSpecials(specials)
    for _, spec in ipairs(specials) do
        -- Only spawn if the cell is empty (was cleared)
        if not Grid.cells[spec.row][spec.col] then
            local newGem = Gem.new(spec.gemType, spec.row, spec.col, spec.special)
            Grid.cells[spec.row][spec.col] = newGem
            newGem.scale = 0
            Tweens.add(newGem, "scale", 1.0, 0.3, "easeOutQuad")
        end
    end
end

---Clear all gems of a specific color (for color bomb activation)
---@param targetType integer
---@param bombGem Gem
---@return table<Gem, boolean> matched
function Grid.clearColor(targetType, bombGem)
    local matched = {}
    matched[bombGem] = true
    for row = 1, Grid.size do
        for col = 1, Grid.size do
            local g = Grid.cells[row][col]
            if g and g.type == targetType then
                matched[g] = true
            end
        end
    end
    return matched
end

---Handle special+special combo swaps
---@param gem1 Gem
---@param gem2 Gem
---@return table<Gem, boolean> matched
function Grid.comboSpecials(gem1, gem2)
    local matched = {}
    matched[gem1] = true
    matched[gem2] = true
    local SIZE = Grid.size

    local s1 = gem1.special or ""
    local s2 = gem2.special or ""

    local isStriped1 = s1 == "striped_h" or s1 == "striped_v"
    local isStriped2 = s2 == "striped_h" or s2 == "striped_v"
    local isWrapped1 = s1 == "wrapped"
    local isWrapped2 = s2 == "wrapped"

    if isStriped1 and isStriped2 then
        -- Cross: clear row of gem1 + column of gem1
        for c = 1, SIZE do
            local g = Grid.cells[gem1.row][c]
            if g then matched[g] = true end
        end
        for r = 1, SIZE do
            local g = Grid.cells[r][gem1.col]
            if g then matched[g] = true end
        end
    elseif (isStriped1 and isWrapped2) or (isWrapped1 and isStriped2) then
        -- Giant cross: 3 rows + 3 columns
        local cr, cc = gem1.row, gem1.col
        for dr = -1, 1 do
            local r = cr + dr
            if r >= 1 and r <= SIZE then
                for c = 1, SIZE do
                    local g = Grid.cells[r][c]
                    if g then matched[g] = true end
                end
            end
        end
        for dc = -1, 1 do
            local c = cc + dc
            if c >= 1 and c <= SIZE then
                for r = 1, SIZE do
                    local g = Grid.cells[r][c]
                    if g then matched[g] = true end
                end
            end
        end
    elseif isWrapped1 and isWrapped2 then
        -- 5x5 explosion
        for dr = -2, 2 do
            for dc = -2, 2 do
                local r, c = gem1.row + dr, gem1.col + dc
                if r >= 1 and r <= SIZE and c >= 1 and c <= SIZE then
                    local g = Grid.cells[r][c]
                    if g then matched[g] = true end
                end
            end
        end
    end

    return matched
end

---@type number
Grid.dropBias = 0

---Count consecutive same-type gems in a line from a position
---@param row integer
---@param col integer
---@param gemType integer
---@param dr integer row delta
---@param dc integer col delta
---@return integer count
local function countInDirection(row, col, gemType, dr, dc)
    local count = 0
    local SIZE = Grid.size
    local r, c = row + dr, col + dc
    while r >= 1 and r <= SIZE and c >= 1 and c <= SIZE do
        local g = Grid.cells[r][c]
        if g and g.type == gemType then
            count = count + 1
        else
            break
        end
        r, c = r + dr, c + dc
    end
    return count
end

---Check how many matches placing gemType at (row,col) would contribute to
---@param row integer
---@param col integer
---@param gemType integer
---@return integer matchPotential 0=none, 1=near-match(2 in a row), 2=forms match(3+)
local function evaluatePlacement(row, col, gemType)
    local best = 0

    -- Horizontal: count left + right
    local left = countInDirection(row, col, gemType, 0, -1)
    local right = countInDirection(row, col, gemType, 0, 1)
    local hTotal = left + right + 1
    if hTotal >= 3 then
        best = 2
    elseif hTotal == 2 and best < 1 then
        best = 1
    end

    -- Vertical: count up + down
    local up = countInDirection(row, col, gemType, -1, 0)
    local down = countInDirection(row, col, gemType, 1, 0)
    local vTotal = up + down + 1
    if vTotal >= 3 then
        best = 2
    elseif vTotal == 2 and best < 1 then
        best = 1
    end

    return best
end

---Smart drop: choose gem type with weighted random based on board state and bias
---@param row integer
---@param col integer
---@param bias number -1.0 to 1.0 (negative=harder, positive=easier, 0=uniform)
---@return integer gemType
function Grid.smartDrop(row, col, bias)
    if bias == 0 or Grid.numGemTypes <= 1 then
        return math.random(Grid.numGemTypes)
    end

    -- Build weights for each gem type
    local weights = {}
    local totalWeight = 0

    for t = 1, Grid.numGemTypes do
        local w = 1.0
        local potential = evaluatePlacement(row, col, t)

        if bias > 0 then
            -- Assist mode: favor colors that create near-matches or matches
            if potential == 2 then
                w = w + bias * 1.0   -- forms match: moderate boost
            elseif potential == 1 then
                w = w + bias * 2.0   -- near-match: stronger boost (more useful)
            end
        else
            -- Challenge mode: reduce colors that would easily match
            if potential == 2 then
                w = w * math.max(0.1, 1.0 + bias)  -- reduce but never zero
            elseif potential == 1 then
                w = w * math.max(0.3, 1.0 + bias * 0.5)
            end
        end

        weights[t] = w
        totalWeight = totalWeight + w
    end

    -- Weighted random selection
    local roll = math.random() * totalWeight
    local cumulative = 0
    for t = 1, Grid.numGemTypes do
        cumulative = cumulative + weights[t]
        if roll <= cumulative then
            return t
        end
    end

    return Grid.numGemTypes -- fallback
end

---@param onComplete? fun()
function Grid.applyGravity(onComplete)
    local totalAnims = 0
    local doneAnims = 0
    local SIZE = Grid.size

    local function checkDone()
        doneAnims = doneAnims + 1
        if doneAnims >= totalAnims and onComplete then
            onComplete()
        end
    end

    for col = 1, SIZE do
        local writeRow = SIZE
        for readRow = SIZE, 1, -1 do
            local gem = Grid.cells[readRow][col]
            if gem then
                if readRow ~= writeRow then
                    Grid.cells[writeRow][col] = gem
                    Grid.cells[readRow][col] = nil
                    local dist = writeRow - readRow
                    gem.row = writeRow
                    gem.targetX, gem.targetY = Utils.gridToPixel(writeRow, col)
                    local dur = math.min(Utils.FALL_DURATION * dist, 0.5)
                    totalAnims = totalAnims + 1
                    Tweens.add(gem, "y", gem.targetY, dur, "easeOutBounce", checkDone)
                end
                writeRow = writeRow - 1
            end
        end

        -- Spawn new gems for empty top slots (smart drop with bias)
        for row = writeRow, 1, -1 do
            local newGem = Gem.new(Grid.smartDrop(row, col, Grid.dropBias), row, col)
            Grid.cells[row][col] = newGem
            newGem.y = Utils.OFFSET_Y - (writeRow - row + 1) * Utils.CELL_SIZE
            newGem.targetY = select(2, Utils.gridToPixel(row, col))
            local dur = math.min(Utils.FALL_DURATION * (writeRow - row + 2), 0.5)
            totalAnims = totalAnims + 1
            Tweens.add(newGem, "y", newGem.targetY, dur, "easeOutBounce", checkDone)
        end
    end

    if totalAnims == 0 and onComplete then
        onComplete()
    end
end

---@param row integer
---@param col integer
---@return boolean
local function checkMatchAt(row, col)
    local SIZE = Grid.size
    local gemType = Grid.cells[row][col].type

    local left = col
    while left > 1 and Grid.cells[row][left - 1].type == gemType do
        left = left - 1
    end
    local right = col
    while right < SIZE and Grid.cells[row][right + 1].type == gemType do
        right = right + 1
    end
    if right - left + 1 >= 3 then return true end

    local top = row
    while top > 1 and Grid.cells[top - 1][col].type == gemType do
        top = top - 1
    end
    local bottom = row
    while bottom < SIZE and Grid.cells[bottom + 1][col].type == gemType do
        bottom = bottom + 1
    end
    if bottom - top + 1 >= 3 then return true end

    return false
end

---@return boolean
function Grid.hasValidMoves()
    local SIZE = Grid.size
    for row = 1, SIZE do
        for col = 1, SIZE do
            -- Color bombs are always swappable
            if Grid.cells[row][col].special == "color_bomb" then
                return true
            end
            if col < SIZE then
                if Grid.cells[row][col + 1].special == "color_bomb" then
                    return true
                end
                Grid.swap(row, col, row, col + 1)
                local valid = checkMatchAt(row, col) or checkMatchAt(row, col + 1)
                Grid.swap(row, col, row, col + 1)
                if valid then return true end
            end
            if row < SIZE then
                if Grid.cells[row + 1][col].special == "color_bomb" then
                    return true
                end
                Grid.swap(row, col, row + 1, col)
                local valid = checkMatchAt(row, col) or checkMatchAt(row + 1, col)
                Grid.swap(row, col, row + 1, col)
                if valid then return true end
            end
        end
    end
    return false
end

return Grid

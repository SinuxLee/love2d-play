local Utils = require("core.utils")

---@class Input
---@field selectedRow? integer    selected gem (for tap mode fallback)
---@field selectedCol? integer
---@field dragRow? integer        gem where drag started
---@field dragCol? integer
---@field dragStartX? number      pixel where press started
---@field dragStartY? number
---@field dragging boolean        true between press and release on a gem
---@field swipeFired boolean      true if swipe already triggered this drag
local Input = {}
Input.selectedRow = nil
Input.selectedCol = nil
Input.dragRow = nil
Input.dragCol = nil
Input.dragStartX = nil
Input.dragStartY = nil
Input.dragging = false
Input.swipeFired = false

-- Minimum pixel distance to recognize a swipe direction
local SWIPE_THRESHOLD = 20

function Input.clear()
    Input.selectedRow = nil
    Input.selectedCol = nil
    Input.dragRow = nil
    Input.dragCol = nil
    Input.dragStartX = nil
    Input.dragStartY = nil
    Input.dragging = false
    Input.swipeFired = false
end

---@return boolean
function Input.hasSelection()
    return Input.selectedRow ~= nil
end

---Called from love.mousepressed
---@param x number
---@param y number
---@param button integer
---@param statesCurrent StateType
---@param onSwap? fun(r1: integer, c1: integer, r2: integer, c2: integer)
---@return string? result "next_level" | "retry" | nil
function Input.mousepressed(x, y, button, statesCurrent, onSwap)
    if button ~= 1 then return end

    if statesCurrent == "level_complete" then
        return "next_level"
    end

    if statesCurrent == "level_fail" then
        return "retry"
    end

    if statesCurrent ~= "idle" then return end

    local row, col = Utils.pixelToGrid(x, y)
    if not row then
        Input.clear()
        return
    end

    -- Start drag tracking
    Input.dragRow = row
    Input.dragCol = col
    Input.dragStartX = x
    Input.dragStartY = y
    Input.dragging = true
    Input.swipeFired = false

    -- Also set visual selection
    Input.selectedRow = row
    Input.selectedCol = col
end

---Called from love.mousemoved (or love.update polling) to detect swipe mid-drag
---@param x number
---@param y number
---@param statesCurrent StateType
---@param onSwap? fun(r1: integer, c1: integer, r2: integer, c2: integer)
function Input.mousemoved(x, y, statesCurrent, onSwap)
    if not Input.dragging or Input.swipeFired then return end
    if statesCurrent ~= "idle" then return end
    if not Input.dragStartX then return end

    local dx = x - Input.dragStartX
    local dy = y - Input.dragStartY

    -- Check if moved past threshold in a cardinal direction
    local adx, ady = math.abs(dx), math.abs(dy)
    if adx < SWIPE_THRESHOLD and ady < SWIPE_THRESHOLD then return end

    -- Determine swipe direction
    local dr, dc = 0, 0
    if adx > ady then
        dc = dx > 0 and 1 or -1
    else
        dr = dy > 0 and 1 or -1
    end

    local targetRow = Input.dragRow + dr
    local targetCol = Input.dragCol + dc

    -- Validate target is on the grid
    local Grid = require("core.grid")
    if targetRow < 1 or targetRow > Grid.size or targetCol < 1 or targetCol > Grid.size then
        return
    end

    -- Fire the swap
    Input.swipeFired = true
    Input.selectedRow = nil
    Input.selectedCol = nil
    if onSwap then
        onSwap(Input.dragRow, Input.dragCol, targetRow, targetCol)
    end
end

---Called from love.mousereleased
---@param x number
---@param y number
---@param button integer
---@param statesCurrent StateType
---@param onSwap? fun(r1: integer, c1: integer, r2: integer, c2: integer)
function Input.mousereleased(x, y, button, statesCurrent, onSwap)
    if button ~= 1 then return end

    -- If swipe already fired, just clean up drag state
    if Input.swipeFired then
        Input.dragging = false
        Input.swipeFired = false
        Input.dragRow = nil
        Input.dragCol = nil
        Input.dragStartX = nil
        Input.dragStartY = nil
        return
    end

    -- No swipe happened — treat as tap (legacy click behavior)
    Input.dragging = false
    Input.dragRow = nil
    Input.dragCol = nil
    Input.dragStartX = nil
    Input.dragStartY = nil

    if statesCurrent ~= "idle" then return end

    local row, col = Utils.pixelToGrid(x, y)
    if not row then
        Input.clear()
        return
    end

    -- If we had a previous tap selection, check for adjacent tap-swap
    if Input.selectedRow and Input.selectedCol then
        local sr, sc = Input.selectedRow, Input.selectedCol

        if sr == row and sc == col then
            -- Tapped same gem: deselect
            Input.clear()
            return
        end

        local dist = math.abs(sr - row) + math.abs(sc - col)
        if dist == 1 then
            -- Adjacent tap: swap
            Input.selectedRow = nil
            Input.selectedCol = nil
            if onSwap then
                onSwap(sr, sc, row, col)
            end
            return
        end
    end

    -- Set/move selection to tapped gem
    Input.selectedRow = row
    Input.selectedCol = col
end

return Input

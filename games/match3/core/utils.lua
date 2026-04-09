---@alias Color number[] -- {r, g, b} each 0-1

---@alias GemSpecial
---| "striped_h"
---| "striped_v"
---| "wrapped"
---| "color_bomb"

---@alias StateType
---| "nick_input"
---| "idle"
---| "swapping"
---| "reverting"
---| "checking"
---| "clearing"
---| "falling"
---| "level_complete"
---| "level_fail"

---@class Gem
---@field type integer          gem color type 0-7 (0 = color bomb)
---@field special? GemSpecial   nil for normal gems
---@field row integer
---@field col integer
---@field x number              current pixel x
---@field y number              current pixel y
---@field targetX number        target pixel x for animation
---@field targetY number        target pixel y for animation
---@field scale number          0-1, for clear/spawn animation
---@field alpha number          0-1, for clear animation
---@field removing boolean

---@class Tween
---@field target table
---@field field string
---@field startVal number
---@field endVal number
---@field duration number
---@field elapsed number
---@field easing fun(t: number): number
---@field onComplete? fun()

---@class SpecialSpawn
---@field row integer
---@field col integer
---@field special GemSpecial
---@field gemType integer

---@class Utils
---@field GRID_SIZE integer
---@field CELL_SIZE integer
---@field GEM_RADIUS integer
---@field OFFSET_X integer
---@field OFFSET_Y integer
---@field NUM_GEM_TYPES integer
---@field GEM_COLORS Color[]
---@field SWAP_DURATION number
---@field FALL_DURATION number
---@field CLEAR_DURATION number
local Utils = {}

Utils.GRID_SIZE = 8
Utils.CELL_SIZE = 64
Utils.GEM_RADIUS = 26
Utils.OFFSET_X = 64
Utils.OFFSET_Y = 144
Utils.NUM_GEM_TYPES = 7

Utils.GEM_COLORS = {
    {0.9, 0.2, 0.2},   -- 1: Red
    {0.2, 0.4, 0.9},   -- 2: Blue
    {0.2, 0.8, 0.3},   -- 3: Green
    {0.95, 0.85, 0.2},  -- 4: Yellow
    {0.7, 0.2, 0.8},   -- 5: Purple
    {1.0, 0.5, 0.1},   -- 6: Orange
    {0.2, 0.85, 0.85},  -- 7: Cyan
}

Utils.SWAP_DURATION = 0.2
Utils.FALL_DURATION = 0.15
Utils.CLEAR_DURATION = 0.25

---@type integer original default board width for reference
Utils.DEFAULT_BOARD_PX = 512 -- 8 * 64

---Update layout constants for a new grid size (called from Grid.init)
---@param gridSize integer
function Utils.setGridSize(gridSize)
    Utils.GRID_SIZE = gridSize
    Utils.CELL_SIZE = math.floor(Utils.DEFAULT_BOARD_PX / gridSize)
    Utils.GEM_RADIUS = math.floor(Utils.CELL_SIZE * 0.406 + 0.5)
    local totalBoardW = gridSize * Utils.CELL_SIZE
    Utils.OFFSET_X = math.floor((640 - totalBoardW) / 2)
    -- OFFSET_Y stays fixed at 144
end

---@param row integer
---@param col integer
---@return number x, number y
function Utils.gridToPixel(row, col)
    local x = Utils.OFFSET_X + (col - 0.5) * Utils.CELL_SIZE
    local y = Utils.OFFSET_Y + (row - 0.5) * Utils.CELL_SIZE
    return x, y
end

---@param px number
---@param py number
---@return integer? row, integer? col
function Utils.pixelToGrid(px, py)
    local col = math.floor((px - Utils.OFFSET_X) / Utils.CELL_SIZE) + 1
    local row = math.floor((py - Utils.OFFSET_Y) / Utils.CELL_SIZE) + 1
    if row >= 1 and row <= Utils.GRID_SIZE and col >= 1 and col <= Utils.GRID_SIZE then
        return row, col
    end
    return nil, nil
end

---@param a number
---@param b number
---@param t number
---@return number
function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

return Utils

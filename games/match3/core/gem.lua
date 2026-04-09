local Utils = require("core.utils")

---@class GemModule
local Gem = {}

---@param gemType integer
---@param row integer
---@param col integer
---@param special? GemSpecial
---@return Gem
function Gem.new(gemType, row, col, special)
    local x, y = Utils.gridToPixel(row, col)
    return {
        type = gemType,
        special = special or nil,
        row = row,
        col = col,
        x = x,
        y = y,
        targetX = x,
        targetY = y,
        scale = 1.0,
        alpha = 1.0,
        removing = false,
    }
end

return Gem

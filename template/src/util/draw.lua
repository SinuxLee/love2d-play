local M = {}

function M.centerText(str, y)
    love.graphics.printf(str, 0, y, love.graphics.getWidth(), "center")
end

return M

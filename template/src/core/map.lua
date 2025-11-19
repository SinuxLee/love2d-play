local sti = require "libs.sti.sti"
local M = {}

function M.load(mapfile)
    local map = sti(mapfile)
    return map
end

return M

-- games/physics-testbed/src/geom.lua
local geom = {}

function geom.segmentsIntersect(ax, ay, bx, by, cx, cy, dx, dy)
    local function cross(ux, uy, vx, vy) return ux * vy - uy * vx end
    local rx, ry = bx - ax, by - ay
    local sx, sy = dx - cx, dy - cy
    local denom = cross(rx, ry, sx, sy)
    if math.abs(denom) < 1e-10 then return false end
    local qpx, qpy = cx - ax, cy - ay
    local t = cross(qpx, qpy, sx, sy) / denom
    local u = cross(qpx, qpy, rx, ry) / denom
    return t >= 0 and t <= 1 and u >= 0 and u <= 1
end

return geom

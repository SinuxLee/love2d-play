-- dynamic_split.lua
local DynamicSplit = {}
DynamicSplit.__index = DynamicSplit

function DynamicSplit:new()
    local o = setmetatable({}, DynamicSplit)
    o.splitMode = "merged"     -- "merged" | "split"
    o.splitProgress = 0        -- 0 = 合并, 1 = 完全分屏
    o.mergeDistance = 400       -- 低于此距离合屏
    o.splitDistance = 600       -- 高于此距离分屏
    o.transitionSpeed = 3
    o.splitAngle = 0           -- 分屏线角度（基于两人连线方向！）
    return o
end

function DynamicSplit:update(dt, p1, p2)
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local dist = math.sqrt(dx * dx + dy * dy)

    -- 分屏线角度 = 两玩家连线的垂直方向
    self.splitAngle = math.atan2(dy, dx) + math.pi / 2

    -- 判断合分状态
    if dist > self.splitDistance then
        self.splitMode = "split"
    elseif dist < self.mergeDistance then
        self.splitMode = "merged"
    end

    -- 平滑过渡
    local target = self.splitMode == "split" and 1 or 0
    self.splitProgress = self.splitProgress + 
        (target - self.splitProgress) * (1 - math.exp(-self.transitionSpeed * dt))
end

--- 判断当前是否在合屏模式
function DynamicSplit:isMerged()
    return self.splitProgress < 0.05
end

--- 合屏时的摄像机位置（两玩家中点）
function DynamicSplit:getMergedCamera(p1, p2)
    return (p1.x + p2.x) / 2, (p1.y + p2.y) / 2
end

--- 合屏时的自动缩放（确保两人都在画面内）
function DynamicSplit:getMergedScale(p1, p2, screenW, screenH)
    local dx = math.abs(p2.x - p1.x)
    local dy = math.abs(p2.y - p1.y)
    local margin = 200  -- 画面边距

    local scaleX = screenW / (dx + margin * 2)
    local scaleY = screenH / (dy + margin * 2)
    local scale = math.min(scaleX, scaleY)

    return math.max(0.3, math.min(scale, 1.5))  -- 限制范围
end

return DynamicSplit

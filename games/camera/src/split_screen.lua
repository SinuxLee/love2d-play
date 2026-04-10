-- splitscreen.lua
local SplitScreen = {}
SplitScreen.__index = SplitScreen

function SplitScreen:new(layout)
    local o = setmetatable({}, SplitScreen)
    o.screenW = love.graphics.getWidth()
    o.screenH = love.graphics.getHeight()
    o.layout  = layout or "horizontal"  -- "horizontal" | "vertical" | "quad"
    o.viewports = {}
    o.gap = 2  -- 分屏间隙（像素）
    return o
end

--- 根据布局计算每个视口的位置和大小
function SplitScreen:setupViewports(playerCount)
    self.viewports = {}
    local sw, sh = self.screenW, self.screenH
    local gap = self.gap

    if playerCount == 2 then
        if self.layout == "horizontal" then
            -- 左右分屏
            local halfW = math.floor((sw - gap) / 2)
            table.insert(self.viewports, { x = 0,            y = 0, w = halfW, h = sh })
            table.insert(self.viewports, { x = halfW + gap,  y = 0, w = halfW, h = sh })
        else
            -- 上下分屏
            local halfH = math.floor((sh - gap) / 2)
            table.insert(self.viewports, { x = 0, y = 0,            w = sw, h = halfH })
            table.insert(self.viewports, { x = 0, y = halfH + gap,  w = sw, h = halfH })
        end
    elseif playerCount == 3 then
        -- 上方两个，下方一个居中
        local halfW = math.floor((sw - gap) / 2)
        local halfH = math.floor((sh - gap) / 2)
        table.insert(self.viewports, { x = 0,            y = 0,            w = halfW, h = halfH })
        table.insert(self.viewports, { x = halfW + gap,  y = 0,            w = halfW, h = halfH })
        table.insert(self.viewports, { x = math.floor(sw/4), y = halfH + gap, w = halfW, h = halfH })
    elseif playerCount >= 4 then
        -- 田字格
        local halfW = math.floor((sw - gap) / 2)
        local halfH = math.floor((sh - gap) / 2)
        table.insert(self.viewports, { x = 0,           y = 0,            w = halfW, h = halfH })
        table.insert(self.viewports, { x = halfW + gap, y = 0,            w = halfW, h = halfH })
        table.insert(self.viewports, { x = 0,           y = halfH + gap,  w = halfW, h = halfH })
        table.insert(self.viewports, { x = halfW + gap, y = halfH + gap,  w = halfW, h = halfH })
    end

    -- 为每个视口创建 Canvas
    for _, vp in ipairs(self.viewports) do
        vp.canvas = love.graphics.newCanvas(vp.w, vp.h)
    end
end

--- 渲染单个视口
--- drawWorldFn(camX, camY, vpW, vpH) 为绘制世界的回调函数
function SplitScreen:renderViewport(index, camX, camY, drawWorldFn)
    local vp = self.viewports[index]
    if not vp then return end

    love.graphics.setCanvas(vp.canvas)
    love.graphics.clear(0.1, 0.1, 0.15, 1)

    love.graphics.push()
    love.graphics.translate(
        -camX + vp.w / 2,
        -camY + vp.h / 2
    )
    drawWorldFn(camX, camY, vp.w, vp.h)
    love.graphics.pop()

    love.graphics.setCanvas()
end

--- 合成所有视口到屏幕
function SplitScreen:compose()
    -- 先画黑色背景（间隙颜色）
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, self.screenW, self.screenH)

    love.graphics.setColor(1, 1, 1)
    for _, vp in ipairs(self.viewports) do
        love.graphics.draw(vp.canvas, vp.x, vp.y)
    end
end

--- 绘制每个视口的边框
function SplitScreen:drawBorders(colors)
    for i, vp in ipairs(self.viewports) do
        local c = colors and colors[i] or {1, 1, 1, 0.5}
        love.graphics.setColor(c)
        love.graphics.rectangle("line", vp.x, vp.y, vp.w, vp.h)
    end
    love.graphics.setColor(1, 1, 1)
end

return SplitScreen

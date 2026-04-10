-- main.lua (分屏示例)
local SplitScreen = require("split_screen")
local split = SplitScreen:new("horizontal")

-- 每个玩家独立数据
local players = {
    { x = 200, y = 200, color = {1, 0.3, 0.3}, keys = {left="a", right="d", up="w", down="s"} },
    { x = 800, y = 600, color = {0.3, 0.5, 1}, keys = {left="left", right="right", up="up", down="down"} },
}

-- 每个玩家独立摄像机
local cameras = {
    { x = 200, y = 200 },
    { x = 800, y = 600 },
}

-- 世界参数
local MAP_W, MAP_H = 3000, 2000
local SPEED = 250

function love.load()
    split:setupViewports(#players)
end

function love.update(dt)
    for i, p in ipairs(players) do
        local k = p.keys
        if love.keyboard.isDown(k.left)  then p.x = p.x - SPEED * dt end
        if love.keyboard.isDown(k.right) then p.x = p.x + SPEED * dt end
        if love.keyboard.isDown(k.up)    then p.y = p.y - SPEED * dt end
        if love.keyboard.isDown(k.down)  then p.y = p.y + SPEED * dt end
        p.x = math.max(0, math.min(p.x, MAP_W))
        p.y = math.max(0, math.min(p.y, MAP_H))

        -- 摄像机平滑跟随
        local cam = cameras[i]
        cam.x = cam.x + (p.x - cam.x) * (1 - math.exp(-6 * dt))
        cam.y = cam.y + (p.y - cam.y) * (1 - math.exp(-6 * dt))
    end
end

--- 世界绘制函数（被每个视口共用）
local function drawWorld(camX, camY, vpW, vpH)
    -- 网格
    love.graphics.setColor(0.25, 0.25, 0.3)
    for gx = 0, MAP_W, 100 do
        love.graphics.line(gx, 0, gx, MAP_H)
    end
    for gy = 0, MAP_H, 100 do
        love.graphics.line(0, gy, MAP_W, gy)
    end

    -- 世界边界
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle("line", 0, 0, MAP_W, MAP_H)

    -- 场景装饰物
    love.graphics.setColor(0.2, 0.6, 0.2)
    for i = 1, 30 do
        local tx = (i * 317) % MAP_W
        local ty = (i * 541) % MAP_H
        love.graphics.circle("fill", tx, ty, 15 + (i % 10))
    end

    -- 所有玩家（在每个视口中都能看到）
    for _, p in ipairs(players) do
        love.graphics.setColor(p.color)
        love.graphics.rectangle("fill", p.x - 16, p.y - 16, 32, 32)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", p.x - 16, p.y - 16, 32, 32)
    end
end

function love.draw()
    -- 渲染每个视口
    for i = 1, #players do
        split:renderViewport(i, cameras[i].x, cameras[i].y, drawWorld)
    end

    -- 合成到屏幕
    split:compose()

    -- 视口边框（玩家颜色）
    split:drawBorders({
        {1, 0.3, 0.3, 0.8},
        {0.3, 0.5, 1, 0.8},
    })

    -- 每个视口上方的玩家标签
    for i, vp in ipairs(split.viewports) do
        love.graphics.setColor(players[i].color)
        love.graphics.print("Player " .. i, vp.x + 10, vp.y + 5)
    end
    love.graphics.setColor(1, 1, 1)
end
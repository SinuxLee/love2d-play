local Camera = require("camera")

-- 切换模式：follow | lookat | lerp | exp | spring | deadzone | lookahead
local CAMERA_MODE = "follow"

local camera = Camera:new({
    mode = CAMERA_MODE,
    -- follow 示例：边界、死区、前瞻
    bounds = { x = 0, y = 0, w = 2000, h = 2000 },
    deadzone = { w = 40, h = 30 },
    lookAhead = 80,
    smoothSpeed = 8,
    scale = 1,
})

local player = {
    x = 400,
    y = 300,
    speed = 200,
    w = 30,
    h = 30,
}

local function moveDir()
    local dx, dy = 0, 0
    if love.keyboard.isDown("left") then dx = dx - 1 end
    if love.keyboard.isDown("right") then dx = dx + 1 end
    if love.keyboard.isDown("up") then dy = dy - 1 end
    if love.keyboard.isDown("down") then dy = dy + 1 end
    if dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        return dx / len, dy / len
    end
    return 0, 0
end

function love.update(dt)
    if love.keyboard.isDown("left") then player.x = player.x - player.speed * dt end
    if love.keyboard.isDown("right") then player.x = player.x + player.speed * dt end
    if love.keyboard.isDown("up") then player.y = player.y - player.speed * dt end
    if love.keyboard.isDown("down") then player.y = player.y + player.speed * dt end

    local dirX, dirY = moveDir()
    camera:follow(player, dirX, dirY, dt)
end

function love.wheelmoved(_x, y)
    if y > 0 then
        camera.scaleX = math.min(camera.scaleX * 1.1, 4)
        camera.scaleY = camera.scaleX
    elseif y < 0 then
        camera.scaleX = math.max(camera.scaleX / 1.1, 0.25)
        camera.scaleY = camera.scaleX
    end
end

function love.draw()
    local function drawScene()
        love.graphics.rectangle("line", 0, 0, 2000, 2000)
        love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)
        for i = 0, 2000, 200 do
            for j = 0, 2000, 200 do
                love.graphics.circle("line", i, j, 10)
            end
        end
    end

    camera:attach()
    drawScene()
    camera:detach()

    love.graphics.print("mode: " .. CAMERA_MODE .. "  cam: " .. math.floor(camera.x) .. ", " .. math.floor(camera.y), 10,
        10)
end

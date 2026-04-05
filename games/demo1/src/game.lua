local vector = require("hump.vector")
local g = love.graphics
-- [-1, 0 ,1]
local UP = vector.new(0, -1)
local RIGHT = vector.new(1, 0)
local DOWN = vector.new(0, 1)
local LEFT = vector.new(-1, 0)

local game = {
    gridRow = 0,
    gridCol = 0,
    gridStarX = 0,
    gridStarY = 0,
    gridSize = 100,
    speed = 100,
    pos = vector.new(0, 0),
    direction = RIGHT,
    accumMove = vector.new(0, 0), -- 累积移动量
    snake = {
        pos = vector.zero,
        next = nil
    }
}


function game.load()
    game.image = love.graphics.newImage("assets/texture/red.png")
    game.gridSize = game.image:getWidth()
    game.speed = game.gridSize*2

    game.gridRow = math.floor(g.getHeight() / game.gridSize)
    game.gridCol = math.floor(g.getWidth() / game.gridSize)

    game.gridStarY = math.floor((g.getHeight() - game.gridRow * game.gridSize) / 2)
    game.gridStarX = math.floor((g.getWidth() - game.gridCol * game.gridSize) / 2)

    local f = love.graphics.newFont(12)
    love.graphics.setFont(f)
    love.graphics.setColor(255, 0, 0, 255)
    love.graphics.setBackgroundColor(255, 255, 255)
end

function game.update(dt)
    if love.keyboard.isDown("left") then
        game.direction = LEFT
    elseif love.keyboard.isDown("right") then
        game.direction = RIGHT
    elseif love.keyboard.isDown("up") then
        game.direction = UP
    elseif love.keyboard.isDown("down") then
        game.direction = DOWN
    end

    local dtSpeed = game.speed * dt
    local move = game.direction * dtSpeed
    game.accumMove = game.accumMove + move

    -- 满一格才真正移动到 pos
    if math.abs(game.accumMove.x) >= game.gridSize then
        local steps = math.floor(math.abs(game.accumMove.x) / game.gridSize)
        local sign = game.accumMove.x > 0 and 1 or -1
        game.pos.x = game.pos.x + sign * steps * game.gridSize
        game.accumMove.x = game.accumMove.x - sign * steps * game.gridSize

        local c = game.pos.x / game.gridSize
        print(c)
        if c < 0 then
            game.pos.x = 0 -- 钳制到左边界
            game.direction = RIGHT
            game.accumMove.x = 0
        elseif c >= game.gridCol - 2 then
            game.pos.x = (game.gridCol - 2) * game.gridSize -- 钳制到右边界
            game.direction = LEFT
            game.accumMove.x = 0
        end
    end

    if math.abs(game.accumMove.y) >= game.gridSize then
        local steps = math.floor(math.abs(game.accumMove.y) / game.gridSize)
        local sign = game.accumMove.y > 0 and 1 or -1
        game.pos.y = game.pos.y + sign * steps * game.gridSize
        game.accumMove.y = game.accumMove.y - sign * steps * game.gridSize
    end
end

function game.draw()
    for r = 1, game.gridRow, 1 do
        for c = 1, game.gridCol, 1 do
            g.line(
                game.gridStarX + (c - 1) * game.gridSize, game.gridStarY + (r - 1) * game.gridSize,
                game.gridStarX + (game.gridCol - c) * game.gridSize, game.gridStarY + (r - 1) * game.gridSize
            )

            g.line(
                game.gridStarX + (c - 1) * game.gridSize, game.gridStarY + (r - 1) * game.gridSize,
                game.gridStarX + (c - 1) * game.gridSize, game.gridStarY + (game.gridRow - r) * game.gridSize
            )
        end
    end

    g.draw(game.image, game.pos.x + game.gridStarX, game.pos.y + game.gridStarY)

    g.print("Hello World!", 400, 300)
    g.print("Click and drag the cake around or use the arrow keys", 10, 10)
end

return game

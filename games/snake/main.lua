local g = love.graphics

local DIR = {
    LEFT = { x = -1, y = 0 },
    UP = { x = 0, y = -1 },
    RIGHT = { x = 1, y = 0 },
    DOWN = { x = 0, y = 1 }
}

local grid = {
    defaultSpeed = 2.0,
    pressedLive = 0,
    offsetY = 30,
    size = 20,
    row = 10,
    col = 10,
    food = { x = 0, y = 0 }
}

local snake = {
    live = 1,
    delta = 0,
    speed = 2.0,
    pos = { x = 10, y = 10, next = { x = 10, y = 9, next = { x = 10, y = 8, next = nil } } },
    dir = DIR.DOWN
}

function grid:genFood()
    local x = math.random(self.col - 1)
    local y = math.random(self.row - 1)
    for _ = 1, 10, 1 do
        if not snake:isCross(x, y) and self.foodx ~= x and self.food.y ~= y then
            break
        end
    end

    self.food.x = x
    self.food.y = y
    print('food: ' .. x .. ',' .. y)
end

function snake:isCross(x, y)
    local cur = self.pos
    while cur ~= nil do
        if cur.x == x and cur.y == y then
            return true
        end
        cur = cur.next
    end

    return false
end

function snake:move()
    self.live = self.live + 1
    local cur = self.pos
    local newX = cur.x + self.dir.x
    local newY = cur.y + self.dir.y

    local newNode = false
    if grid.food.x == newX and grid.food.y == newY then
        newNode = true
        grid:genFood()
    end

    while true do
        cur.x, cur.y, newX, newY = newX, newY, cur.x, cur.y

        if cur.next == nil then
            if newNode then
                cur.next = { x = newX, y = newY, next = nil }
            end
            break
        else
            cur = cur.next
        end
    end
end

function love.load()
    math.randomseed(os.time())
    g.setBackgroundColor(255, 255, 255)
    -- love.window.showMessageBox('haha', 'this is a test message', 'info')
    local width, height, _ = love.window.getMode()
    grid.col = math.floor(width / grid.size)
    grid.row = math.floor(height / grid.size)
    grid:genFood()
end

function love.keyreleased(key)
    if key == "escape" then
        love.event.quit()
        return
    end

    if grid.pressedLive == snake.live then
        return
    else
        grid.pressedLive = snake.live
    end

    if key == "left" and snake.dir ~= DIR.RIGHT then
        snake.dir = DIR.LEFT
        return
    end

    if key == "up" and snake.dir ~= DIR.DOWN then
        snake.dir = DIR.UP
        return
    end

    if key == "right" and snake.dir ~= DIR.LEFT then
        snake.dir = DIR.RIGHT
        return
    end

    if key == "down" and snake.dir ~= DIR.UP then
        snake.dir = DIR.DOWN
        return
    end
end

function love.update(dt)
    if love.keyboard.isDown("left") and snake.dir == DIR.LEFT then
        snake.speed = snake.speed + dt*grid.defaultSpeed
    elseif love.keyboard.isDown("up") and snake.dir == DIR.UP then
        snake.speed = snake.speed + dt*grid.defaultSpeed
    elseif love.keyboard.isDown("right") and snake.dir == DIR.RIGHT then
        snake.speed = snake.speed + dt*grid.defaultSpeed
    elseif love.keyboard.isDown("down") and snake.dir ~= DIR.DOWN then
        snake.speed = snake.speed + dt*grid.defaultSpeed
    else
        snake.speed = grid.defaultSpeed
    end

    snake.delta = snake.delta + dt * snake.speed -- 如果中途改变方向，则 delta 累加到新方向中

    if snake.delta > 1.0 then
        snake.delta = snake.delta - 1.0
        snake:move()
    end
end

function love.draw()
    g.setLineWidth(1)
    g.setColor(.83, .54, .93, 1)

    g.print("This is a pretty lame example.", 5, 5)

    g.setColor(.87, .87, .87, .75)
    for r = 1, grid.row + 1, 1 do
        for c = 1, grid.col + 1, 1 do
            g.line(
                (c - 1) * grid.size,
                grid.offsetY + (r - 1) * grid.size,
                c * grid.size,
                grid.offsetY + (r - 1) * grid.size
            )

            g.line(
                (c - 1) * grid.size,
                grid.offsetY + (r - 1) * grid.size,
                (c - 1) * grid.size,
                grid.offsetY + r * grid.size
            )
        end
    end

    local cur = snake.pos
    while cur ~= nil do
        if cur == snake.pos then
            g.setColor( .47, .76, .94, 1)
        else
            g.setColor(1, 1, 0, 1)
        end

        g.rectangle("fill", cur.x * grid.size, grid.offsetY + cur.y * grid.size, grid.size, grid.size)
        cur = cur.next
    end

    g.setColor(.97, .58, .77, 1)
    g.rectangle("fill", grid.food.x * grid.size, grid.offsetY + grid.food.y * grid.size, grid.size, grid.size)
end

if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end

-- run only once
function love.load()
    num = 0
    imgx, imgy = 300, 200
    whale = love.graphics.newImage("image/red.png")

    local f = love.graphics.newFont(12)
    love.graphics.setFont(f)
    love.graphics.setColor(255, 0, 0, 255)
    -- love.graphics.setBackgroundColor(255,255,255)
end

function love.draw()
    love.graphics.draw(whale, imgx, imgy)
    love.graphics.print("Hello World!", 400, 300)
    love.graphics.print("Click and drag the cake around or use the arrow keys", 10, 10)
end

function love.update(dt)
    if love.keyboard.isDown("up") then
        num = num + 100 * dt -- this would increment num by 100 per second
    end
end

function love.mousepressed(x, y, button, istouch)
    if button == 1 then
        imgx = x -- move image to where mouse clicked
        imgy = y
    end
end

function love.quit()
    print("Thanks for playing! Come back soon!")
end

local game = require('game')

-- run only once
function love.load()
    game.load()
end

function love.draw()
    game.draw()
end

function love.update(dt)
    game.update(dt)
end

function love.quit()
    print("Thanks for playing! Come back soon!")
end

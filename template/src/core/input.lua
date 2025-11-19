local input = {
    up    = false,
    down  = false,
    left  = false,
    right = false,
}

function love.keypressed(key)
    if key == "w" then input.up = true end
    if key == "s" then input.down = true end
    if key == "a" then input.left = true end
    if key == "d" then input.right = true end
end

function love.keyreleased(key)
    if key == "w" then input.up = false end
    if key == "s" then input.down = false end
    if key == "a" then input.left = false end
    if key == "d" then input.right = false end
end

return input

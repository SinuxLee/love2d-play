local input = {
    up    = false,
    down  = false,
    left  = false,
    right = false,
}

function input.keypressed(key)
    if key == "w" or key == "up" then input.up = true end
    if key == "s" or key == "down" then input.down = true end
    if key == "a" or key == "left" then input.left = true end
    if key == "d" or key == "right" then input.right = true end
end

function input.keyreleased(key)
    if key == "w" or key == "up" then input.up = false end
    if key == "s" or key == "down" then input.down = false end
    if key == "a" or key == "left" then input.left = false end
    if key == "d" or key == "right" then input.right = false end
end

return input

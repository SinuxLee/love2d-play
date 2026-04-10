---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-doc-name
local Utils = require("core.utils")
local Grid = require("core.grid")

---@class Renderer
local Renderer = {}

---@type table
local smallFont
---@type table
local largeFont
---@type table
local hugeFont
---@type table
local tinyFont

function Renderer.init()
    smallFont = love.graphics.newFont(18)
    largeFont = love.graphics.newFont(24)
    hugeFont = love.graphics.newFont(48)
    tinyFont = love.graphics.newFont(13)
end

function Renderer.drawBoard()
    local SIZE = Grid.size
    love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
    love.graphics.rectangle("fill", Utils.OFFSET_X - 4, Utils.OFFSET_Y - 4,
        SIZE * Utils.CELL_SIZE + 8, SIZE * Utils.CELL_SIZE + 8, 8, 8)

    for row = 1, SIZE do
        for col = 1, SIZE do
            if (row + col) % 2 == 0 then
                love.graphics.setColor(0.15, 0.15, 0.28, 0.5)
            else
                love.graphics.setColor(0.12, 0.12, 0.22, 0.5)
            end
            local cx = Utils.OFFSET_X + (col - 1) * Utils.CELL_SIZE
            local cy = Utils.OFFSET_Y + (row - 1) * Utils.CELL_SIZE
            love.graphics.rectangle("fill", cx, cy, Utils.CELL_SIZE, Utils.CELL_SIZE)
        end
    end
end

---Draw special overlays on top of a gem shape
---@param gem Gem
---@param radius number
local function drawSpecialOverlay(gem, radius)
    if not gem.special then return end

    if gem.special == "striped_h" then
        love.graphics.setColor(1, 1, 1, gem.alpha * 0.5)
        love.graphics.setLineWidth(2)
        for i = -1, 1 do
            local yOff = i * radius * 0.35
            love.graphics.line(-radius * 0.8, yOff, radius * 0.8, yOff)
        end
    elseif gem.special == "striped_v" then
        love.graphics.setColor(1, 1, 1, gem.alpha * 0.5)
        love.graphics.setLineWidth(2)
        for i = -1, 1 do
            local xOff = i * radius * 0.35
            love.graphics.line(xOff, -radius * 0.8, xOff, radius * 0.8)
        end
    elseif gem.special == "wrapped" then
        local pulse = math.sin(love.timer.getTime() * 5) * 0.2 + 0.6
        love.graphics.setColor(1, 1, 1, gem.alpha * pulse)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", 0, 0, radius + 4)
        love.graphics.circle("line", 0, 0, radius + 8)
    end
end

---@param gem Gem
local function drawGem(gem)
    if not gem or gem.alpha <= 0 then return end

    local radius = Utils.GEM_RADIUS * gem.scale

    love.graphics.push()
    love.graphics.translate(gem.x, gem.y)

    -- Color bomb: special rainbow drawing
    if gem.special == "color_bomb" then
        local colors = Utils.GEM_COLORS
        for i = #colors, 1, -1 do
            local c = colors[i]
            love.graphics.setColor(c[1], c[2], c[3], gem.alpha)
            love.graphics.circle("fill", 0, 0, radius * (i / #colors))
        end
        love.graphics.setColor(1, 1, 1, gem.alpha * 0.8)
        love.graphics.circle("fill", 0, 0, radius * 0.15)
        love.graphics.setColor(0.3, 0.3, 0.3, gem.alpha)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, radius)
        love.graphics.pop()
        return
    end

    local color = Utils.GEM_COLORS[gem.type]
    if not color then
        love.graphics.pop()
        return
    end
    local r, g, b = color[1], color[2], color[3]

    local gemType = gem.type

    if gemType == 1 then
        love.graphics.setColor(r, g, b, gem.alpha)
        love.graphics.circle("fill", 0, 0, radius)
        love.graphics.setColor(r + 0.2, g + 0.2, b + 0.2, gem.alpha * 0.6)
        love.graphics.circle("fill", -radius * 0.2, -radius * 0.2, radius * 0.5)
        love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, gem.alpha)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, radius)

    elseif gemType == 2 then
        local verts = {0, -radius, radius, 0, 0, radius, -radius, 0}
        love.graphics.setColor(r, g, b, gem.alpha)
        love.graphics.polygon("fill", verts)
        love.graphics.setColor(r + 0.15, g + 0.15, b + 0.15, gem.alpha * 0.5)
        local inner = radius * 0.5
        love.graphics.polygon("fill", 0, -inner, inner, 0, 0, inner, -inner, 0)
        love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, gem.alpha)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", verts)

    elseif gemType == 3 then
        love.graphics.setColor(r, g, b, gem.alpha)
        love.graphics.rectangle("fill", -radius, -radius, radius * 2, radius * 2, 6, 6)
        love.graphics.setColor(r + 0.15, g + 0.15, b + 0.15, gem.alpha * 0.5)
        local inner = radius * 0.5
        love.graphics.rectangle("fill", -inner, -inner, inner * 2, inner * 2, 4, 4)
        love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, gem.alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", -radius, -radius, radius * 2, radius * 2, 6, 6)

    elseif gemType == 4 then
        local h = radius * 1.1
        local verts = {0, -h, h * 0.866, h * 0.5, -h * 0.866, h * 0.5}
        love.graphics.setColor(r, g, b, gem.alpha)
        love.graphics.polygon("fill", verts)
        love.graphics.setColor(r + 0.1, g + 0.1, b + 0.1, gem.alpha * 0.5)
        local s = 0.5
        love.graphics.polygon("fill", 0, -h * s, h * 0.866 * s, h * 0.5 * s, -h * 0.866 * s, h * 0.5 * s)
        love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, gem.alpha)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", verts)

    elseif gemType == 5 then
        local verts = {}
        for i = 0, 5 do
            local angle = math.rad(60 * i - 30)
            table.insert(verts, radius * math.cos(angle))
            table.insert(verts, radius * math.sin(angle))
        end
        love.graphics.setColor(r, g, b, gem.alpha)
        love.graphics.polygon("fill", verts)
        love.graphics.setColor(r + 0.15, g + 0.15, b + 0.15, gem.alpha * 0.5)
        local innerVerts = {}
        for i = 0, 5 do
            local angle = math.rad(60 * i - 30)
            table.insert(innerVerts, radius * 0.55 * math.cos(angle))
            table.insert(innerVerts, radius * 0.55 * math.sin(angle))
        end
        love.graphics.polygon("fill", innerVerts)
        love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, gem.alpha)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", verts)

    elseif gemType == 6 then
        local verts = {}
        for i = 0, 5 do
            local outerAngle = math.rad(60 * i - 90)
            table.insert(verts, radius * math.cos(outerAngle))
            table.insert(verts, radius * math.sin(outerAngle))
            local innerAngle = math.rad(60 * i - 60)
            table.insert(verts, radius * 0.5 * math.cos(innerAngle))
            table.insert(verts, radius * 0.5 * math.sin(innerAngle))
        end
        love.graphics.setColor(r, g, b, gem.alpha)
        love.graphics.polygon("fill", verts)
        love.graphics.setColor(r + 0.1, g + 0.1, b + 0.1, gem.alpha * 0.5)
        love.graphics.circle("fill", 0, 0, radius * 0.3)
        love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, gem.alpha)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", verts)

    elseif gemType == 7 then
        local verts = {}
        for i = 0, 4 do
            local angle = math.rad(72 * i - 90)
            table.insert(verts, radius * math.cos(angle))
            table.insert(verts, radius * math.sin(angle))
        end
        love.graphics.setColor(r, g, b, gem.alpha)
        love.graphics.polygon("fill", verts)
        love.graphics.setColor(r + 0.15, g + 0.15, b + 0.15, gem.alpha * 0.5)
        local innerVerts = {}
        for i = 0, 4 do
            local angle = math.rad(72 * i - 90)
            table.insert(innerVerts, radius * 0.5 * math.cos(angle))
            table.insert(innerVerts, radius * 0.5 * math.sin(angle))
        end
        love.graphics.polygon("fill", innerVerts)
        love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, gem.alpha)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", verts)
    end

    -- Draw special overlay on top of base shape
    drawSpecialOverlay(gem, radius)

    love.graphics.pop()
end

---@param cells (Gem|nil)[][]
function Renderer.drawGems(cells)
    local SIZE = Grid.size
    for row = 1, SIZE do
        for col = 1, SIZE do
            drawGem(cells[row][col])
        end
    end
end

---@param selectedRow? integer
---@param selectedCol? integer
function Renderer.drawSelection(selectedRow, selectedCol)
    if not selectedRow then return end
    local x = Utils.OFFSET_X + (selectedCol - 1) * Utils.CELL_SIZE
    local y = Utils.OFFSET_Y + (selectedRow - 1) * Utils.CELL_SIZE
    local pulse = math.sin(love.timer.getTime() * 4) * 0.15 + 0.85
    love.graphics.setColor(1, 1, 1, pulse)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x + 2, y + 2, Utils.CELL_SIZE - 4, Utils.CELL_SIZE - 4, 4, 4)
end

---Draw hint highlight on two cells
---@param r1 integer
---@param c1 integer
---@param r2 integer
---@param c2 integer
---@param flashTimer number
function Renderer.drawHint(r1, c1, r2, c2, flashTimer)
    local alpha = math.sin(flashTimer * 3) * 0.3 + 0.5
    love.graphics.setColor(0.3, 1, 0.6, alpha)
    love.graphics.setLineWidth(2)
    local x1 = Utils.OFFSET_X + (c1 - 1) * Utils.CELL_SIZE
    local y1 = Utils.OFFSET_Y + (r1 - 1) * Utils.CELL_SIZE
    love.graphics.rectangle("line", x1 + 3, y1 + 3, Utils.CELL_SIZE - 6, Utils.CELL_SIZE - 6, 4, 4)
    local x2 = Utils.OFFSET_X + (c2 - 1) * Utils.CELL_SIZE
    local y2 = Utils.OFFSET_Y + (r2 - 1) * Utils.CELL_SIZE
    love.graphics.rectangle("line", x2 + 3, y2 + 3, Utils.CELL_SIZE - 6, Utils.CELL_SIZE - 6, 4, 4)
end

---Draw a single star (filled or outline)
---@param cx number center x
---@param cy number center y
---@param size number radius
---@param filled boolean
---@param color? number[] {r,g,b,a}
local function drawStar(cx, cy, size, filled, color)
    local verts = {}
    for i = 0, 4 do
        local outerAngle = math.rad(72 * i - 90)
        table.insert(verts, cx + size * math.cos(outerAngle))
        table.insert(verts, cy + size * math.sin(outerAngle))
        local innerAngle = math.rad(72 * i - 90 + 36)
        table.insert(verts, cx + size * 0.4 * math.cos(innerAngle))
        table.insert(verts, cy + size * 0.4 * math.sin(innerAngle))
    end
    if filled then
        love.graphics.setColor(color or {1, 0.9, 0.2, 1})
        love.graphics.polygon("fill", verts)
    end
    love.graphics.setColor(color and {color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, color[4] or 1} or {0.7, 0.6, 0.1, 1})
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", verts)
end

---Draw star rating (1-3 stars)
---@param cx number center x of the group
---@param cy number center y
---@param stars integer 0-3
---@param size? number star radius (default 16)
function Renderer.drawStars(cx, cy, stars, size)
    size = size or 16
    local spacing = size * 2.8
    local startX = cx - spacing
    for i = 1, 3 do
        local sx = startX + (i - 1) * spacing
        if i <= stars then
            drawStar(sx, cy, size, true)
        else
            drawStar(sx, cy, size, false, {0.4, 0.4, 0.5, 0.6})
        end
    end
end

---@param score integer
---@param combo integer
---@param level integer
---@param movesLeft integer
---@param targetScore integer
---@param objectives? Objective[]
---@param states? States
function Renderer.drawHUD(score, combo, level, movesLeft, targetScore, objectives, states)
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.7, 0.8, 1, 1)
    love.graphics.print("Level " .. level, 20, 10)

    love.graphics.setFont(largeFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(score .. " / " .. targetScore, 0, 10, 640, "center")

    local barX, barY, barW, barH = 170, 42, 300, 10
    local progress = math.min(score / targetScore, 1.0)
    love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)
    if progress > 0 then
        love.graphics.setColor(0.3, 0.9, 0.4, 1)
        love.graphics.rectangle("fill", barX, barY, barW * progress, barH, 4, 4)
    end

    love.graphics.setFont(largeFont)
    local movesColor = movesLeft <= 3 and {1, 0.3, 0.3, 1} or {1, 1, 1, 1}
    love.graphics.setColor(movesColor)
    love.graphics.printf("Moves: " .. movesLeft, 0, 10, 620, "right")

    if combo > 1 then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(1, 0.9, 0.2, 1)
        love.graphics.printf("Combo x" .. combo, 0, 42, 620, "right")
    end

    -- Draw secondary objectives below the progress bar
    if objectives and #objectives > 1 and states then
        love.graphics.setFont(tinyFont)
        local objY = 56
        for i = 2, #objectives do
            local obj = objectives[i]
            local current = 0
            if obj.type == "collect" then
                current = states.collected[obj.gemType] or 0
            elseif obj.type == "combo" then
                current = states.maxCombo
            elseif obj.type == "specials" then
                current = states.specialsCreated
            elseif obj.type == "moves_left" then
                current = movesLeft
            end
            local done = current >= obj.target
            local clr = done and {0.3, 1, 0.4, 1} or {0.7, 0.7, 0.8, 0.9}
            love.graphics.setColor(clr)
            local icon = done and "[v] " or "[ ] "
            love.graphics.printf(icon .. obj.description .. " (" .. current .. "/" .. obj.target .. ")",
                20, objY, 600, "left")
            objY = objY + 16
        end
    end
end

---@param bias number
---@param failCount integer
---@param modifiers? string[]
function Renderer.drawStatusBar(bias, failCount, modifiers)
    local SIZE = Grid.size
    local y = Utils.OFFSET_Y + SIZE * Utils.CELL_SIZE + 8
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.5, 0.5, 0.6, 0.8)
    local biasLabel = bias > 0 and "+" or ""
    local biasText = string.format("Drop Bias: %s%.2f", biasLabel, bias)
    if failCount > 0 then
        biasText = biasText .. string.format("  (retries: %d)", failCount)
    end
    love.graphics.printf(biasText, 0, y, 640, "center")

    -- Show active modifiers below bias
    if modifiers and #modifiers > 0 then
        y = y + 20
        love.graphics.setFont(tinyFont)
        love.graphics.setColor(0.6, 0.5, 0.9, 0.8)
        love.graphics.printf("Mods: " .. table.concat(modifiers, ", "), 0, y, 640, "center")
    end
end

---@param nick string
---@param message string
---@param cursorVisible boolean
function Renderer.drawNickInput(nick, message, cursorVisible)
    -- Background
    love.graphics.setColor(0.12, 0.12, 0.22, 1)
    love.graphics.rectangle("fill", 0, 0, 640, 720)

    -- Title
    love.graphics.setFont(hugeFont)
    love.graphics.setColor(0.4, 0.7, 1, 1)
    love.graphics.printf("Match-3", 0, 140, 640, "center")

    -- Prompt
    love.graphics.setFont(largeFont)
    love.graphics.setColor(0.8, 0.8, 0.9, 1)
    love.graphics.printf("Enter your nickname:", 0, 280, 640, "center")

    -- Input box
    local boxW, boxH = 300, 44
    local boxX = (640 - boxW) / 2
    local boxY = 330
    love.graphics.setColor(0.2, 0.2, 0.35, 1)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6, 6)
    love.graphics.setColor(0.5, 0.6, 0.9, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6, 6)

    -- Nick text + cursor
    love.graphics.setFont(largeFont)
    love.graphics.setColor(1, 1, 1, 1)
    local displayText = nick
    if cursorVisible then
        displayText = displayText .. "_"
    end
    love.graphics.printf(displayText, boxX + 10, boxY + 8, boxW - 20, "center")

    -- Message (welcome back / hint)
    if message and message ~= "" then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.5, 0.9, 0.5, 1)
        love.graphics.printf(message, 0, 395, 640, "center")
    end

    -- Hint
    local pulse = math.sin(love.timer.getTime() * 3) * 0.3 + 0.7
    love.graphics.setColor(0.6, 0.6, 0.7, pulse)
    love.graphics.setFont(smallFont)
    love.graphics.printf("Press Enter to Start", 0, 440, 640, "center")

    -- Character limit hint
    love.graphics.setColor(0.4, 0.4, 0.5, 0.6)
    love.graphics.printf("3-12 characters, letters and numbers", 0, 480, 640, "center")
end

---@param score integer
---@param level integer
---@param stars? integer
function Renderer.drawLevelComplete(score, level, stars)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 640, 720)

    love.graphics.setFont(hugeFont)
    love.graphics.setColor(0.3, 1, 0.4, 1)
    love.graphics.printf("Level " .. level .. " Clear!", 0, 220, 640, "center")

    -- Star rating
    if stars and stars > 0 then
        Renderer.drawStars(320, 300, stars, 20)
    end

    love.graphics.setFont(largeFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Score: " .. score, 0, 340, 640, "center")

    local pulse = math.sin(love.timer.getTime() * 3) * 0.3 + 0.7
    love.graphics.setColor(1, 1, 1, pulse)
    love.graphics.setFont(smallFont)
    love.graphics.printf("Click for Next Level", 0, 400, 640, "center")
end

---@param score integer
---@param targetScore integer
function Renderer.drawLevelFail(score, targetScore)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 640, 720)

    love.graphics.setFont(hugeFont)
    love.graphics.setColor(1, 0.3, 0.3, 1)
    love.graphics.printf("Level Failed", 0, 240, 640, "center")

    love.graphics.setFont(largeFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Score: " .. score .. " / " .. targetScore, 0, 320, 640, "center")

    local pulse = math.sin(love.timer.getTime() * 3) * 0.3 + 0.7
    love.graphics.setColor(1, 1, 1, pulse)
    love.graphics.setFont(smallFont)
    love.graphics.printf("Click to Retry", 0, 380, 640, "center")
end

return Renderer

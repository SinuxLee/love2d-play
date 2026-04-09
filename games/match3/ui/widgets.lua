---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-doc-name

---Lightweight immediate-mode UI widget library.
---Inspired by Dear ImGui's hot/active ID model.
---@class UI
---@field initialized boolean
---@field hotId string|nil       ID being hovered this frame
---@field activeId string|nil    ID being pressed/dragged
---@field mouseX number
---@field mouseY number
---@field mouseDown boolean
---@field mousePressed boolean   true only on the frame of press
---@field mouseReleased boolean  true only on the frame of release
local UI = {}
UI.initialized = false
UI.hotId = nil
UI.activeId = nil
UI.mouseX = 0
UI.mouseY = 0
UI.mouseDown = false
UI.mousePressed = false
UI.mouseReleased = false

---@type boolean
local pendingPress = false
---@type boolean
local pendingRelease = false
---@type boolean
local prevMouseDown = false

---@type table
local font
---@type table
local smallFont

---@param px number
---@param py number
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean
local function pointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function UI.init()
    font = love.graphics.newFont(14)
    smallFont = love.graphics.newFont(12)
    UI.initialized = true
end

---Call at the start of each frame (in love.update or love.draw)
function UI.beginFrame()
    if not UI.initialized then return end
    UI.mouseX, UI.mouseY = love.mouse.getPosition()
    UI.mouseDown = love.mouse.isDown(1)
    UI.mousePressed = pendingPress
    UI.mouseReleased = pendingRelease
    pendingPress = false
    pendingRelease = false
    UI.hotId = nil
end

---Call at the end of each frame
function UI.endFrame()
    if not UI.initialized then return end
    if not UI.mouseDown then
        UI.activeId = nil
    end
end

---Notify UI of a mouse press event (call from love.mousepressed)
function UI.onMousePressed()
    pendingPress = true
end

---Notify UI of a mouse release event (call from love.mousereleased)
function UI.onMouseReleased()
    pendingRelease = true
end

---Draw a semi-transparent panel background
---@param x number
---@param y number
---@param w number
---@param h number
function UI.panel(x, y, w, h)
    if not UI.initialized then return end
    love.graphics.setColor(0.05, 0.05, 0.12, 0.92)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(0.3, 0.4, 0.6, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
end

---Draw a text label
---@param x number
---@param y number
---@param text string
---@param color? number[]
function UI.label(x, y, text, color)
    if not UI.initialized then return end
    love.graphics.setFont(font)
    love.graphics.setColor(color or {0.8, 0.85, 0.95, 1})
    love.graphics.print(text, x, y)
end

---Draw a small text label
---@param x number
---@param y number
---@param text string
---@param color? number[]
function UI.smallLabel(x, y, text, color)
    if not UI.initialized then return end
    love.graphics.setFont(smallFont)
    love.graphics.setColor(color or {0.5, 0.6, 0.7, 0.9})
    love.graphics.print(text, x, y)
end

---Draw a clickable button. Returns true on the frame it was clicked.
---@param id string
---@param x number
---@param y number
---@param w number
---@param h number
---@param text string
---@return boolean clicked
function UI.button(id, x, y, w, h, text)
    if not UI.initialized then return false end
    local hover = pointInRect(UI.mouseX, UI.mouseY, x, y, w, h)
    local clicked = false

    if hover then
        UI.hotId = id
        if UI.mousePressed then
            UI.activeId = id
        end
    end

    if UI.activeId == id and UI.mouseReleased and hover then
        clicked = true
    end

    -- Draw
    love.graphics.setFont(font)
    if UI.activeId == id and hover then
        love.graphics.setColor(0.15, 0.16, 0.28, 1)
    elseif hover then
        love.graphics.setColor(0.25, 0.28, 0.42, 1)
    else
        love.graphics.setColor(0.2, 0.22, 0.35, 1)
    end
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(0.4, 0.5, 0.7, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)

    love.graphics.setColor(0.7, 0.8, 1, 1)
    local tw = font:getWidth(text)
    local th = font:getHeight()
    love.graphics.print(text, x + (w - tw) / 2, y + (h - th) / 2)

    return clicked
end

---Draw a checkbox. Returns the new checked state.
---@param id string
---@param x number
---@param y number
---@param text string
---@param checked boolean
---@return boolean newChecked
function UI.checkbox(id, x, y, text, checked)
    if not UI.initialized then return checked end
    local boxSize = 18
    local hover = pointInRect(UI.mouseX, UI.mouseY, x, y, boxSize, boxSize)
    local textHover = pointInRect(UI.mouseX, UI.mouseY, x, y, boxSize + 6 + font:getWidth(text), boxSize)
    local anyHover = hover or textHover

    if anyHover then
        UI.hotId = id
        if UI.mousePressed then
            UI.activeId = id
        end
    end

    if UI.activeId == id and UI.mouseReleased and anyHover then
        checked = not checked
    end

    -- Draw box
    love.graphics.setFont(font)
    if anyHover then
        love.graphics.setColor(0.25, 0.28, 0.42, 1)
    else
        love.graphics.setColor(0.2, 0.22, 0.35, 1)
    end
    love.graphics.rectangle("fill", x, y, boxSize, boxSize, 3, 3)
    love.graphics.setColor(0.4, 0.5, 0.7, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, boxSize, boxSize, 3, 3)

    -- Draw checkmark
    if checked then
        love.graphics.setColor(0.3, 1, 0.5, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 4, y + 9, x + 7, y + 14, x + 14, y + 4)
    end

    -- Draw label
    love.graphics.setColor(0.8, 0.85, 0.95, 1)
    love.graphics.print(text, x + boxSize + 6, y + 1)

    return checked
end

---Draw a radio button group. Returns the new selected index.
---@param id string
---@param x number
---@param y number
---@param options string[]
---@param selected integer
---@return integer newSelected
function UI.radioGroup(id, x, y, options, selected)
    if not UI.initialized then return selected end
    local radius = 7
    local spacing = 22

    love.graphics.setFont(font)

    for i, label in ipairs(options) do
        local iy = y + (i - 1) * spacing
        local cx, cy = x + radius, iy + radius
        local labelW = font:getWidth(label)
        local hover = pointInRect(UI.mouseX, UI.mouseY, x, iy, radius * 2 + 6 + labelW, spacing)
        local itemId = id .. "_" .. i

        if hover then
            UI.hotId = itemId
            if UI.mousePressed then
                UI.activeId = itemId
            end
        end

        if UI.activeId == itemId and UI.mouseReleased and hover then
            selected = i
        end

        -- Draw circle
        if i == selected then
            love.graphics.setColor(0.3, 0.8, 1, 1)
            love.graphics.circle("fill", cx, cy, radius)
            love.graphics.setColor(0.1, 0.1, 0.2, 1)
            love.graphics.circle("fill", cx, cy, radius - 3)
            love.graphics.setColor(0.3, 0.8, 1, 1)
            love.graphics.circle("fill", cx, cy, radius - 5)
        else
            love.graphics.setColor(0.3, 0.35, 0.5, 1)
            love.graphics.circle("fill", cx, cy, radius)
            love.graphics.setColor(0.15, 0.15, 0.25, 1)
            love.graphics.circle("fill", cx, cy, radius - 2)
        end

        -- Draw label
        if hover then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.7, 0.75, 0.85, 1)
        end
        love.graphics.print(label, x + radius * 2 + 6, iy)
    end

    return selected
end

---Draw a horizontal separator line
---@param x number
---@param y number
---@param w number
function UI.separator(x, y, w)
    if not UI.initialized then return end
    love.graphics.setColor(0.3, 0.35, 0.5, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y, x + w, y)
end

---Draw a collapsible section header. Returns the new open state.
---@param id string
---@param x number
---@param y number
---@param w number
---@param label string
---@param isOpen boolean
---@return boolean newIsOpen
---@return number height  total height consumed by this header
function UI.collapseHeader(id, x, y, w, label, isOpen)
    if not UI.initialized then return isOpen, 20 end
    local h = 20
    local hover = pointInRect(UI.mouseX, UI.mouseY, x, y, w, h)

    if hover then
        UI.hotId = id
        if UI.mousePressed then
            UI.activeId = id
        end
    end

    if UI.activeId == id and UI.mouseReleased and hover then
        isOpen = not isOpen
    end

    local arrow = isOpen and "v " or "> "
    love.graphics.setFont(smallFont)

    -- Subtle highlight on hover
    if hover then
        love.graphics.setColor(0.2, 0.25, 0.4, 0.5)
        love.graphics.rectangle("fill", x - 2, y, w + 4, h, 3, 3)
    end

    -- Label
    local clr = hover and {0.9, 0.95, 1, 1} or {0.65, 0.75, 0.9, 1}
    love.graphics.setColor(clr)
    love.graphics.print(arrow .. label, x, y + 2)

    -- Underline
    love.graphics.setColor(0.3, 0.4, 0.6, 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y + h, x + w, y + h)

    return isOpen, h + 4
end

return UI

-- framework/input_manager.lua
-- Per-scene input manager with action binding.
--
-- Source format for raw keys:  "key:<name>"  e.g. "key:space", "key:a"
-- Source format for mouse:     "mouse:<btn>" e.g. "mouse:1", "mouse:2"
--
-- Usage:
--   self.input:bind("jump",  {"key:space", "key:w",  "key:up"})
--   self.input:bind("fire",  {"key:z",     "mouse:1"})
--
--   self.input:actionDown("jump")     -- held this frame
--   self.input:actionPressed("fire")  -- just pressed this frame
--   self.input:actionReleased("jump") -- just released this frame
--
--   self.input:keyDown("space")       -- raw key query
--   self.input:mouseDown(1)           -- raw mouse button query
--   self.input.mouse.x, .mouse.y      -- cursor position

---@class InputManager
local InputManager = {}
InputManager.__index = InputManager

---Create a new InputManager
---@param defaultBindings table|nil  { actionName = {sources...}, ... }
---@return InputManager
function InputManager.new(defaultBindings)
    local self = setmetatable({
        _down     = {},   -- set of currently held sources  ("key:a" = true)
        _pressed  = {},   -- set of sources pressed THIS frame
        _released = {},   -- set of sources released THIS frame
        _actions  = {},   -- actionName -> { source1, source2, ... }
        mouse     = { x = 0, y = 0, dx = 0, dy = 0,
                      wheel = { x = 0, y = 0 } },
    }, InputManager)

    -- Apply default bindings from game config
    if defaultBindings then
        for action, sources in pairs(defaultBindings) do
            self:bind(action, sources)
        end
    end

    return self
end

-- ─── Internal: called by SceneManager event dispatch ────────────────────────

function InputManager:_keypressed(key)
    local src = "key:" .. key
    if not self._down[src] then
        self._pressed[src] = true
    end
    self._down[src] = true
end

function InputManager:_keyreleased(key)
    local src = "key:" .. key
    self._down[src] = nil
    self._released[src] = true
end

function InputManager:_mousepressed(x, y, button)
    self.mouse.x = x
    self.mouse.y = y
    local src = "mouse:" .. button
    if not self._down[src] then
        self._pressed[src] = true
    end
    self._down[src] = true
end

function InputManager:_mousereleased(x, y, button)
    self.mouse.x = x
    self.mouse.y = y
    local src = "mouse:" .. button
    self._down[src] = nil
    self._released[src] = true
end

function InputManager:_mousemoved(x, y, dx, dy)
    self.mouse.x  = x
    self.mouse.y  = y
    self.mouse.dx = self.mouse.dx + dx
    self.mouse.dy = self.mouse.dy + dy
end

function InputManager:_wheelmoved(x, y)
    self.mouse.wheel.x = self.mouse.wheel.x + x
    self.mouse.wheel.y = self.mouse.wheel.y + y
end

---Called by SceneManager at end of each UPDATE to reset one-frame states
function InputManager:flush()
    self._pressed  = {}
    self._released = {}
    self.mouse.dx          = 0
    self.mouse.dy          = 0
    self.mouse.wheel.x     = 0
    self.mouse.wheel.y     = 0
end

-- ─── Action binding ──────────────────────────────────────────────────────────

---Bind an action to one or more input sources
---@param action string Action name
---@param sources string|table  Single source string or table of source strings
function InputManager:bind(action, sources)
    if type(sources) == "string" then
        sources = { sources }
    end
    self._actions[action] = sources
end

---Remove an action binding
---@param action string
function InputManager:unbind(action)
    self._actions[action] = nil
end

-- ─── Action queries ──────────────────────────────────────────────────────────

---Returns true while any source of the action is held down
---@param action string
---@return boolean
function InputManager:actionDown(action)
    local sources = self._actions[action]
    if not sources then return false end
    for _, src in ipairs(sources) do
        if self._down[src] then return true end
    end
    return false
end

---Returns true on the frame any source of the action was first pressed
---@param action string
---@return boolean
function InputManager:actionPressed(action)
    local sources = self._actions[action]
    if not sources then return false end
    for _, src in ipairs(sources) do
        if self._pressed[src] then return true end
    end
    return false
end

---Returns true on the frame any source of the action was released
---@param action string
---@return boolean
function InputManager:actionReleased(action)
    local sources = self._actions[action]
    if not sources then return false end
    for _, src in ipairs(sources) do
        if self._released[src] then return true end
    end
    return false
end

-- ─── Raw key/mouse queries ───────────────────────────────────────────────────

---@param key string  Love2D key name  (e.g. "space", "a", "left")
---@return boolean
function InputManager:keyDown(key)
    return self._down["key:" .. key] == true
end

---@param key string
---@return boolean
function InputManager:keyPressed(key)
    return self._pressed["key:" .. key] == true
end

---@param key string
---@return boolean
function InputManager:keyReleased(key)
    return self._released["key:" .. key] == true
end

---@param btn integer  Mouse button index (1=left, 2=right, 3=middle)
---@return boolean
function InputManager:mouseDown(btn)
    return self._down["mouse:" .. btn] == true
end

---@param btn integer
---@return boolean
function InputManager:mousePressed(btn)
    return self._pressed["mouse:" .. btn] == true
end

---@param btn integer
---@return boolean
function InputManager:mouseReleased(btn)
    return self._released["mouse:" .. btn] == true
end

---Get current cursor position
---@return number x, number y
function InputManager:getMousePos()
    return self.mouse.x, self.mouse.y
end

return InputManager

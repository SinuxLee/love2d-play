-- framework/scene_manager.lua
-- Manages multiple parallel scenes with full Phaser 3-style lifecycle.
--
-- Scene Status:
--   RUNNING  – active: receives update + draw + input events
--   PAUSED   – receives draw only (no update, no input)
--   SLEEPING – completely dormant (no update, no draw, no input)
--   STOPPED  – removed; instance discarded (re-start creates fresh instance)
--
-- Phaser 3-style API on each scene instance via self.scene:
--   start(key, data)       – start a stopped/new scene
--   stop(key)              – stop a running scene (destroys instance)
--   switch(key, data)      – stop ALL active scenes, then start key
--   restart(data)          – stop + re-start the most recently active scene
--   launch(key, data)      – start a scene alongside existing ones
--   pause(key)             – RUNNING → PAUSED
--   resume(key)            – PAUSED  → RUNNING
--   sleep(key)             – RUNNING/PAUSED → SLEEPING (preserves instance)
--   wake(key, data)        – SLEEPING → RUNNING
--   bringToTop(key)        – move scene to top of render stack
--   sendToBack(key)        – move scene to bottom of render stack
--   get(key)               – return scene instance (or nil)
--   is(key, status)        – check scene status string
--   currentKey()           – key of the top-most RUNNING scene

local Timer        = require "hump.timer"
local Camera       = require "hump.camera"
local EventEmitter = require "framework.event_emitter"
local InputManager = require "framework.input_manager"

-- Lazy-load suit (may not be available in unit tests)
local suit
do
    local ok, s = pcall(require, "suit")
    if ok then suit = s end
end

-- ─── Optional system registry ────────────────────────────────────────────────
-- Maps system name → require path.  Modules are loaded on first use.
local SYSTEM_PATHS = {
    physics = "framework.systems.physics",
    anims   = "framework.systems.anims",
    map     = "framework.systems.map",
    fx      = "framework.systems.fx",
    ecs     = "framework.systems.ecs",
    save    = "framework.systems.save",
}
local _loadedSystems = {}   -- cache: path → module

local function loadSystem(name)
    local path = SYSTEM_PATHS[name]
    if not path then
        print("[Framework] Warning: unknown optional system '" .. name .. "'")
        return nil
    end
    if _loadedSystems[path] == nil then
        local ok, mod = pcall(require, path)
        _loadedSystems[path] = ok and mod or false
        if not ok then
            print("[Framework] Warning: failed to load system '" .. name .. "': " .. tostring(mod))
        end
    end
    return _loadedSystems[path] or nil
end

-- ─── Status constants ────────────────────────────────────────────────────────
local STATUS = {
    RUNNING  = "running",
    PAUSED   = "paused",
    SLEEPING = "sleeping",
    STOPPED  = "stopped",
}

-- ─── SceneManager ────────────────────────────────────────────────────────────
---@class SceneManager
local SceneManager = {}
SceneManager.__index = SceneManager
SceneManager.STATUS = STATUS

---Create a new SceneManager.
---@param registry table   { key = SceneClass, ... }
---@param config   table   Game config passed from Framework.game()
---@return SceneManager
function SceneManager.new(registry, config)
    return setmetatable({
        _registry   = registry,   -- key → Scene subclass
        _scenes     = {},         -- ordered list of scene entries (render order)
        _byKey      = {},         -- key → entry (for fast lookup)
        _config     = config or {},
        _sharedData = {},         -- global data shared across all scenes
    }, SceneManager)
end

-- ─── Private helpers ─────────────────────────────────────────────────────────

local function injectSubsystems(sm, instance)
    local cfg = sm._config
    local w = love.graphics and love.graphics.getWidth()  or 800
    local h = love.graphics and love.graphics.getHeight() or 600

    instance.time    = Timer.new()
    instance.tweens  = Timer.new()
    instance.cameras = Camera(w / 2, h / 2)
    instance.events  = EventEmitter.new()
    instance.input   = InputManager.new(cfg.input)
    instance.scene   = sm
    instance.data    = sm._sharedData

    if suit then
        instance.ui = suit.new()
    end
end

local function injectOptionalSystems(instance, systemList)
    for _, name in ipairs(systemList) do
        local mod = loadSystem(name)
        if mod then
            instance[name] = mod.new(instance)
        end
    end
end

local function createEntry(sm, key)
    local class = sm._registry[key]
    assert(class, "[Framework] Scene not found in registry: '" .. tostring(key) .. "'")

    local instance = class()   -- hump.class instantiation (calls init() if defined)
    injectSubsystems(sm, instance)

    local systemList = class.systems or instance.systems
    if systemList then
        injectOptionalSystems(instance, systemList)
    end

    return {
        key      = key,
        class    = class,
        instance = instance,
        status   = STATUS.STOPPED,
    }
end

-- Apply a status transition and fire the appropriate lifecycle callback.
local function applyTransition(entry, newStatus, data)
    local prev = entry.status
    entry.status = newStatus
    local inst = entry.instance

    if newStatus == STATUS.RUNNING then
        if prev == STATUS.STOPPED then
            -- Fresh start: subsystems are already injected; call create()
            if inst.create then inst:create(data) end
        elseif prev == STATUS.PAUSED then
            if inst.resume then inst:resume() end
        elseif prev == STATUS.SLEEPING then
            if inst.wake then inst:wake(data) end
        end

    elseif newStatus == STATUS.PAUSED then
        if inst.pause then inst:pause() end

    elseif newStatus == STATUS.SLEEPING then
        if inst.sleep then inst:sleep() end

    elseif newStatus == STATUS.STOPPED then
        if inst.destroy then inst:destroy() end
        -- Release subsystem resources
        if inst.time   then inst.time:clear()   end
        if inst.tweens then inst.tweens:clear() end
        if inst.events then inst.events:clear() end
    end
end

-- ─── Public API ──────────────────────────────────────────────────────────────

---Start a scene (must be STOPPED or not yet created).
---@param key  string
---@param data table|nil
---@return SceneManager self (for chaining)
function SceneManager:start(key, data)
    local entry = self._byKey[key]
    if entry then
        assert(entry.status == STATUS.STOPPED,
            "[Framework] Scene '" .. key .. "' is not stopped. "
            .. "Use restart(), wake(), or resume() instead.")
    end
    -- Always create a fresh entry when starting a stopped/new scene
    entry = createEntry(self, key)
    self._byKey[key] = entry
    table.insert(self._scenes, entry)
    applyTransition(entry, STATUS.RUNNING, data)
    return self
end

---Stop a running/paused/sleeping scene and discard its instance.
---@param key string
---@return SceneManager
function SceneManager:stop(key)
    local entry = self._byKey[key]
    if not entry then return self end
    applyTransition(entry, STATUS.STOPPED)
    -- Remove from ordered list
    for i = #self._scenes, 1, -1 do
        if self._scenes[i].key == key then
            table.remove(self._scenes, i)
            break
        end
    end
    self._byKey[key] = nil
    return self
end

---Stop ALL active scenes, then start the target scene.
---@param key  string
---@param data table|nil
---@return SceneManager
function SceneManager:switch(key, data)
    for i = #self._scenes, 1, -1 do
        local entry = self._scenes[i]
        applyTransition(entry, STATUS.STOPPED)
        self._byKey[entry.key] = nil
        table.remove(self._scenes, i)
    end
    self:start(key, data)
    return self
end

---Stop the topmost RUNNING scene and start it again with optional new data.
---@param data table|nil
---@return SceneManager
function SceneManager:restart(data)
    for i = #self._scenes, 1, -1 do
        local entry = self._scenes[i]
        if entry.status == STATUS.RUNNING then
            local key = entry.key
            self:stop(key)
            self:start(key, data)
            return self
        end
    end
    error("[Framework] SceneManager:restart() – no RUNNING scene found")
end

---Start a scene alongside any already-active scenes (parallel launch).
---If the scene is already running this is a no-op.
---If sleeping, it is woken instead.
---@param key  string
---@param data table|nil
---@return SceneManager
function SceneManager:launch(key, data)
    local entry = self._byKey[key]
    if entry then
        if entry.status == STATUS.RUNNING then return self end
        if entry.status == STATUS.SLEEPING then
            return self:wake(key, data)
        end
        if entry.status == STATUS.PAUSED then
            return self:resume(key)
        end
    end
    self:start(key, data)
    return self
end

---Transition a RUNNING scene to PAUSED (draw continues, update stops).
---@param key string
---@return SceneManager
function SceneManager:pause(key)
    local entry = self._byKey[key]
    if entry and entry.status == STATUS.RUNNING then
        applyTransition(entry, STATUS.PAUSED)
    end
    return self
end

---Transition a PAUSED scene back to RUNNING.
---@param key string
---@return SceneManager
function SceneManager:resume(key)
    local entry = self._byKey[key]
    if entry and entry.status == STATUS.PAUSED then
        applyTransition(entry, STATUS.RUNNING)
    end
    return self
end

---Put a scene to sleep (no update, no draw; instance preserved).
---@param key string
---@return SceneManager
function SceneManager:sleep(key)
    local entry = self._byKey[key]
    if entry and (entry.status == STATUS.RUNNING
               or entry.status == STATUS.PAUSED) then
        applyTransition(entry, STATUS.SLEEPING)
    end
    return self
end

---Wake a sleeping scene (SLEEPING → RUNNING).
---@param key  string
---@param data table|nil
---@return SceneManager
function SceneManager:wake(key, data)
    local entry = self._byKey[key]
    if entry and entry.status == STATUS.SLEEPING then
        applyTransition(entry, STATUS.RUNNING, data)
    end
    return self
end

---Return the scene instance for key, or nil if not active.
---@param key string
---@return table|nil
function SceneManager:get(key)
    local entry = self._byKey[key]
    return entry and entry.instance or nil
end

---Check whether a scene currently has the given status string.
---@param key    string
---@param status string  "running" | "paused" | "sleeping" | "stopped"
---@return boolean
function SceneManager:is(key, status)
    local entry = self._byKey[key]
    return entry ~= nil and entry.status == status
end

---Return the key of the top-most RUNNING scene (last in render order).
---@return string|nil
function SceneManager:currentKey()
    for i = #self._scenes, 1, -1 do
        if self._scenes[i].status == STATUS.RUNNING then
            return self._scenes[i].key
        end
    end
    return nil
end

---Move a scene to the top of the render stack (drawn last = on top).
---@param key string
---@return SceneManager
function SceneManager:bringToTop(key)
    for i, entry in ipairs(self._scenes) do
        if entry.key == key then
            table.remove(self._scenes, i)
            table.insert(self._scenes, entry)
            break
        end
    end
    return self
end

---Move a scene to the bottom of the render stack (drawn first = behind).
---@param key string
---@return SceneManager
function SceneManager:sendToBack(key)
    for i, entry in ipairs(self._scenes) do
        if entry.key == key then
            table.remove(self._scenes, i)
            table.insert(self._scenes, 1, entry)
            break
        end
    end
    return self
end

-- ─── Frame hooks (called by init.lua) ────────────────────────────────────────

function SceneManager:update(dt)
    for _, entry in ipairs(self._scenes) do
        if entry.status == STATUS.RUNNING then
            local inst = entry.instance
            -- Auto-tick core subsystem timers
            inst.time:update(dt)
            inst.tweens:update(dt)
            -- Tick optional systems that need per-frame updates
            -- (bump/physics does NOT need a per-frame tick; ecs does)
            if inst.ecs and inst.ecs.update then inst.ecs:update(dt) end
            -- Tick scene logic
            if inst.update then inst:update(dt) end
        end
    end
    -- Flush per-scene input AFTER all scene updates (preserves pressed/released
    -- state through the full update phase, cleared for next frame)
    for _, entry in ipairs(self._scenes) do
        if entry.status == STATUS.RUNNING then
            entry.instance.input:flush()
        end
    end
end

function SceneManager:draw()
    for _, entry in ipairs(self._scenes) do
        if entry.status == STATUS.RUNNING
        or entry.status == STATUS.PAUSED then
            local inst = entry.instance
            if inst.draw then inst:draw() end
            -- Auto-render suit UI widgets on top of scene content
            if inst.ui then inst.ui:draw() end
        end
    end
end

-- ─── Event dispatch ───────────────────────────────────────────────────────────
-- Called by init.lua for every Love2D callback that needs scene forwarding.

function SceneManager:dispatch(cbName, ...)
    for _, entry in ipairs(self._scenes) do
        if entry.status == STATUS.RUNNING then
            local inst = entry.instance

            -- Update per-scene input state for input-related callbacks
            if     cbName == "keypressed"    then inst.input:_keypressed((...))
            elseif cbName == "keyreleased"   then inst.input:_keyreleased((...))
            elseif cbName == "mousepressed"  then
                local x, y, btn = ...
                inst.input:_mousepressed(x, y, btn)
            elseif cbName == "mousereleased" then
                local x, y, btn = ...
                inst.input:_mousereleased(x, y, btn)
            elseif cbName == "mousemoved"    then inst.input:_mousemoved(...)
            elseif cbName == "wheelmoved"    then inst.input:_wheelmoved(...)
            end

            -- Forward keyboard events to suit UI
            if inst.ui then
                if     cbName == "keypressed"  then inst.ui:keypressed(...)
                elseif cbName == "textinput"   then inst.ui:textinput(...)
                elseif cbName == "textedited"  then inst.ui:textedited(...)
                end
            end

            -- Forward to the scene method if it defines one
            local fn = inst[cbName]
            if fn then fn(inst, ...) end
        end
    end
end

---Destroy all active scene instances (called on love.quit).
function SceneManager:destroyAll()
    for i = #self._scenes, 1, -1 do
        local entry = self._scenes[i]
        if entry.instance and entry.instance.destroy then
            entry.instance:destroy()
        end
    end
    self._scenes = {}
    self._byKey  = {}
end

return SceneManager

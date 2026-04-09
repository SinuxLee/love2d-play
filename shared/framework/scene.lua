-- framework/scene.lua
-- Scene base class. Extend it with Scene:extend("Name").
--
-- Lifecycle (called by the framework, override in subclasses):
--   create(data)   – called every time the scene starts or restarts.
--                    All subsystems are already injected at this point.
--   update(dt)     – called every frame when RUNNING
--   draw()         – called every frame when RUNNING or PAUSED
--   pause()        – called when scene transitions RUNNING → PAUSED
--   resume()       – called when scene transitions PAUSED → RUNNING
--   sleep()        – called when scene transitions RUNNING → SLEEPING
--   wake(data)     – called when scene transitions SLEEPING → RUNNING
--   destroy()      – called when scene is stopped (cleanup)
--
-- Subsystems auto-injected before create() is called:
--   self.time      – hump.timer instance (after/every/during)
--   self.tweens    – hump.timer instance used for tweens
--   self.cameras   – hump.camera instance centred on screen
--   self.events    – EventEmitter (scene-local pub/sub)
--   self.input     – InputManager (action binding + raw queries)
--   self.ui        – suit instance (immediate-mode GUI; auto-drawn after draw())
--   self.scene     – SceneManager reference (start/stop/switch scenes)
--   self.data      – shared table across all scenes (global state)
--
-- Optional systems (declared via MyScene.systems = {"physics", "anims", ...}):
--   self.physics   – bump.lua AABB world
--   self.anims     – anim8 animation factory
--   self.map       – sti Tiled map loader
--   self.fx        – moonshine shader-effect chain
--   self.ecs       – tiny-ecs world
--   self.save      – bitser serializer helpers
--
-- NOTE: Do NOT override hump.class's init() method; use create() instead.

local Class = require "hump.class"

---@class Scene
local Scene = Class {}
Scene.__name = "Scene"

---Create a subclass of Scene.
---@param name string  Human-readable class name (used in debug output)
---@return Scene  New Scene subclass
function Scene:extend(name)
    local Sub = Class { __includes = self }
    Sub.__name = name or "Scene"
    Sub.extend = Scene.extend   -- propagate extend() to all descendants
    return Sub
end

-- ─── Lifecycle stubs ────────────────────────────────────────────────────────
-- All return nothing by default; subclasses override what they need.

---Called every time the scene starts or is restarted.
---All subsystems (self.time, self.input, self.ui, ...) are ready to use.
---@param data table|nil  Data passed to SceneManager:start()/switch()/restart()
function Scene:create(data) end     -- luacheck: ignore

---Called every frame while the scene is RUNNING.
---@param dt number  Delta-time in seconds
function Scene:update(dt) end       -- luacheck: ignore

---Called every frame while the scene is RUNNING or PAUSED.
function Scene:draw() end

---Called when this scene is paused (RUNNING → PAUSED).
function Scene:pause() end

---Called when this scene resumes from pause (PAUSED → RUNNING).
function Scene:resume() end

---Called when this scene is put to sleep (RUNNING/PAUSED → SLEEPING).
function Scene:sleep() end

---Called when this scene wakes from sleep (SLEEPING → RUNNING).
---@param data table|nil  Optional data passed to SceneManager:wake()
function Scene:wake(data) end       -- luacheck: ignore

---Called when this scene is fully stopped (cleanup). Always called before
---the scene instance is discarded.
function Scene:destroy() end

-- Optional: override in subclass to declare Tier-2 optional systems.
-- Example:  MyScene.systems = { "physics", "anims", "map" }
-- Scene.systems = nil  -- (no optional systems by default)

return Scene

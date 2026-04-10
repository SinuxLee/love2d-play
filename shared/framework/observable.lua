-- framework/observable.lua
-- Lightweight observable table proxy.
-- Used for self.data (the shared data table across all scenes).
--
-- When a field changes, all registered watchers for that key are called.
-- Built-in watcher methods are read-only and protected from overwrite.
--
-- Usage:
--   -- Preferred: use the scene-level helper (auto-cleans on scene destroy)
--   self:watch("score", function(new, old) print("score:", old, "→", new) end)
--
--   -- Direct: manual unwatch required
--   local fn = self.data:watch("score", function(new, old) ... end)
--   self.data:unwatch("score", fn)
--
-- Notes:
--   • Watchers fire only when the value actually changes (new ~= old).
--   • Watchers called with (newValue, oldValue).
--   • Re-entrant: watchers added/removed during a notify do not affect
--     the current notification (snapshot-copy semantics).
--   • self.data:raw() returns the underlying plain table (read-only access,
--     useful for serialization or passing to libraries that need a real table).

local Observable = {}

--- Reserved method names that cannot be used as data keys.
local RESERVED = { watch = true, unwatch = true, clearWatchers = true, raw = true }

---Create a new observable proxy wrapping `init` (or an empty table).
---@param init table|nil  Initial key/value pairs
---@return table  Observable proxy
function Observable.new(init)
    local store = {}
    local hooks = {}    -- key → { fn, fn, ... }

    -- Copy initial values into store without triggering hooks
    if init then
        for k, v in pairs(init) do store[k] = v end
    end

    -- ── Method implementations ────────────────────────────────────────────────

    local function watch(_, key, fn)
        assert(type(key) == "string", "Observable:watch – key must be a string")
        assert(type(fn)  == "function", "Observable:watch – fn must be a function")
        hooks[key] = hooks[key] or {}
        table.insert(hooks[key], fn)
        return fn   -- returned so callers can store for later unwatch
    end

    local function unwatch(_, key, fn)
        local list = hooks[key]
        if not list then return end
        for i = #list, 1, -1 do
            if list[i] == fn then
                table.remove(list, i)
                return
            end
        end
    end

    local function clearWatchers(_)
        hooks = {}
    end

    local function raw(_)
        return store
    end

    local METHODS = {
        watch        = watch,
        unwatch      = unwatch,
        clearWatchers = clearWatchers,
        raw          = raw,
    }

    -- ── Proxy metatable ───────────────────────────────────────────────────────

    local proxy = setmetatable({}, {
        __index = function(_, key)
            local m = METHODS[key]
            if m then return m end
            return store[key]
        end,

        __newindex = function(_, key, value)
            assert(not RESERVED[key],
                "Observable: '" .. key .. "' is a reserved method name and cannot be used as a data key.")
            local old = store[key]
            store[key] = value
            if old ~= value then
                local list = hooks[key]
                if list then
                    -- Snapshot so add/remove inside a watcher is safe
                    local snap = {}
                    for i = 1, #list do snap[i] = list[i] end
                    for _, fn in ipairs(snap) do
                        fn(value, old)
                    end
                end
            end
        end,
    })

    return proxy
end

return Observable

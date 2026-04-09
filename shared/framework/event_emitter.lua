-- framework/event_emitter.lua
-- Per-scene event emitter for scene-local publish/subscribe

---@class EventEmitter
local EventEmitter = {}
EventEmitter.__index = EventEmitter

---Create a new EventEmitter instance
---@return EventEmitter
function EventEmitter.new()
    return setmetatable({ _handlers = {} }, EventEmitter)
end

---Subscribe to an event
---@param event string Event name
---@param fn function Callback function
---@return function The callback (for later removal with off())
function EventEmitter:on(event, fn)
    self._handlers[event] = self._handlers[event] or {}
    table.insert(self._handlers[event], fn)
    return fn
end

---Subscribe to an event, automatically unsubscribing after first call
---@param event string Event name
---@param fn function Callback function
---@return function The wrapper callback
function EventEmitter:once(event, fn)
    local wrapper
    wrapper = function(...)
        self:off(event, wrapper)
        fn(...)
    end
    return self:on(event, wrapper)
end

---Unsubscribe from an event
---@param event string Event name
---@param fn function|nil Specific callback to remove, or nil to remove all handlers for event
function EventEmitter:off(event, fn)
    if fn then
        local handlers = self._handlers[event]
        if handlers then
            for i = #handlers, 1, -1 do
                if handlers[i] == fn then
                    table.remove(handlers, i)
                    break
                end
            end
        end
    else
        self._handlers[event] = nil
    end
end

---Emit an event, calling all subscribed handlers
---@param event string Event name
---@param ... any Arguments forwarded to handlers
function EventEmitter:emit(event, ...)
    local handlers = self._handlers[event]
    if handlers then
        -- Iterate over a snapshot copy so handlers can safely call on/off
        local snap = {}
        for i, h in ipairs(handlers) do snap[i] = h end
        for _, fn in ipairs(snap) do
            fn(...)
        end
    end
end

---Remove all event handlers (useful on scene destroy)
function EventEmitter:clear()
    self._handlers = {}
end

return EventEmitter

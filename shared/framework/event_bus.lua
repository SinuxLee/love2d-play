-- framework/event_bus.lua
-- Global event bus for cross-scene communication
-- Singleton module; use it to broadcast events between scenes.
--
-- Usage:
--   local Bus = require "framework.event_bus"
--   Bus:on("player_died", function(score) ... end)
--   Bus:emit("player_died", score)

local EventEmitter = require "framework.event_emitter"

-- Single shared instance for all scenes
local bus = EventEmitter.new()

return bus

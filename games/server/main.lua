local Scheduler    = require "core.scheduler"
local log          = require "core.log"
local gate_fn      = require "service.gate"
local room_mgr     = require "service.room_mgr"
local test_client  = require "service.test_client"
local Panel        = require "ui.panel"
local suit         = require "suit"

local sched      = Scheduler.new()
local mgr_addr
local gate_addr
local start_time
local rooms_cache = {}
local snapshot_timer = 0
local SNAPSHOT_INTERVAL = 1.0
local panel

function love.load()
    start_time = love.timer.getTime()
    log.info("=== Game Server starting ===")

    mgr_addr  = sched:spawn(room_mgr)
    gate_addr = sched:spawn(gate_fn, {
        port          = 12345,
        room_mgr_addr = mgr_addr,
        scheduler     = sched,
    })

    log.info("server ready  mgr=%d  gate=%d  port=12345", mgr_addr, gate_addr)
    panel = Panel.new(sched, start_time)
end

function love.update(dt)
    sched:tick(dt)

    -- Periodically snapshot room list for the UI
    snapshot_timer = snapshot_timer + dt
    if snapshot_timer >= SNAPSHOT_INTERVAL then
        snapshot_timer = 0
        sched:spawn(function(ctx)
            local list = ctx:call(mgr_addr, "snapshot", {})
            rooms_cache = list or {}
            ctx:exit()
        end)
    end

    panel:set_rooms(rooms_cache)

    -- Spawn test client on button click
    if panel.spawn_test_client_pending then
        panel.spawn_test_client_pending = nil
        sched:spawn(test_client, {host = "127.0.0.1", port = 12345})
    end

    -- Dispatch announce broadcast
    if panel.announce_pending then
        panel.announce_pending = nil
        sched:spawn(function(ctx)
            ctx:call(mgr_addr, "snapshot", {})
            -- broadcast_except requires a room_id; a true server-wide broadcast
            -- requires an agent registry service (not yet implemented).
            -- The announce is already logged by panel.lua.
            ctx:exit()
        end)
    end
end

function love.draw()
    panel:draw()
end

function love.mousemoved(x, y, _dx, _dy)
    suit.updateMouse(x, y)
end
function love.mousepressed(x, y, btn)
    if btn == 1 then suit.updateMouse(x, y, true) end
end
function love.mousereleased(x, y, btn)
    if btn == 1 then suit.updateMouse(x, y, false) end
end
function love.keypressed(key)
    suit.keypressed(key)
end
function love.textinput(t)
    suit.textinput(t)
end

function love.quit()
    log.info("server shutting down")
end

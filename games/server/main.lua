local Scheduler = require "core.scheduler"
local log       = require "core.log"
local gate_fn   = require "service.gate"
local room_mgr  = require "service.room_mgr"

local sched      = Scheduler.new()
local mgr_addr
local gate_addr
local start_time
local rooms_cache = {}
local snapshot_timer = 0
local SNAPSHOT_INTERVAL = 1.0

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
end

function love.draw()
    local uptime = love.timer.getTime() - start_time

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format(
        "Game Server  |  port: 12345  |  services: %d  |  uptime: %.0fs",
        sched:service_count(), uptime), 10, 10)

    -- Room list
    love.graphics.print("Rooms:", 10, 40)
    if #rooms_cache == 0 then
        love.graphics.print("  (none)", 10, 60)
    else
        for i, r in ipairs(rooms_cache) do
            love.graphics.print(string.format("  [%d] %s  %d/%d",
                r.id, r.name, r.count, r.max), 10, 40 + i * 20)
        end
    end

    -- Recent log entries
    local entries = log._entries()
    local start_i = math.max(1, #entries - 15)
    for i = start_i, #entries do
        local e = entries[i]
        if e.level == "ERROR" then
            love.graphics.setColor(1, 0.3, 0.3)
        elseif e.level == "WARN" then
            love.graphics.setColor(1, 0.8, 0)
        else
            love.graphics.setColor(0.8, 0.8, 0.8)
        end
        love.graphics.print(string.format("[%s] %s", e.level, e.msg),
            10, love.graphics.getHeight() - (#entries - i + 1) * 16 - 10)
    end
    love.graphics.setColor(1, 1, 1)
end

function love.quit()
    log.info("server shutting down")
end

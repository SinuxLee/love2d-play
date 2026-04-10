local t = require "testing"
local Scheduler = require "core.scheduler"

t.describe("Scheduler", function()
    t.it("spawn runs service coroutine", function()
        local sched = Scheduler.new()
        local ran = false
        sched:spawn(function(ctx)
            ran = true
        end)
        sched:tick(0)
        t.assert.truthy(ran)
    end)

    t.it("send delivers message to mailbox", function()
        local sched = Scheduler.new()
        local received
        local addr = sched:spawn(function(ctx)
            local type, data = ctx:recv()
            received = {type = type, data = data}
        end)
        sched:tick(0)  -- service runs, blocks on recv
        sched:send(addr, "hello", {x = 1})
        sched:tick(0)  -- service resumes
        t.assert.eq(received.type, "hello")
        t.assert.eq(received.data.x, 1)
    end)

    t.it("call and reply work as synchronous RPC", function()
        local sched = Scheduler.new()
        local server_addr = sched:spawn(function(ctx)
            while true do
                local session, type, data = ctx:recv_call()
                if type == "add" then
                    ctx:reply(session, data.a + data.b)
                end
            end
        end)
        local result
        sched:spawn(function(ctx)
            result = ctx:call(server_addr, "add", {a = 3, b = 4})
        end)
        for _ = 1, 5 do sched:tick(0) end
        t.assert.eq(result, 7)
    end)

    t.it("kill removes service", function()
        local sched = Scheduler.new()
        local addr = sched:spawn(function(ctx)
            while true do ctx:recv() end
        end)
        sched:tick(0)
        t.assert.truthy(sched.services[addr])
        sched:kill(addr)
        sched:tick(0)
        t.assert.falsy(sched.services[addr])
    end)

    t.it("try_recv returns nil when mailbox empty", function()
        local sched = Scheduler.new()
        local got = "unset"
        sched:spawn(function(ctx)
            got = ctx:try_recv()
        end)
        sched:tick(0)
        t.assert.falsy(got)
    end)

    t.it("service_count returns live service count", function()
        local sched = Scheduler.new()
        sched:spawn(function(ctx) while true do ctx:recv() end end)
        sched:spawn(function(ctx) while true do ctx:recv() end end)
        sched:tick(0)
        t.assert.eq(sched:service_count(), 2)
    end)
end)

local room_mgr = require "service.room_mgr"

t.describe("room_mgr service", function()
    t.it("create returns room_id", function()
        local sched = Scheduler.new()
        local mgr_addr = sched:spawn(room_mgr)
        local room_id
        sched:spawn(function(ctx)
            room_id = ctx:call(mgr_addr, "create", {room_name = "test", max_players = 4})
            ctx:exit()
        end)
        for _ = 1, 10 do sched:tick(0) end
        t.assert.eq(room_id, 1)
    end)

    t.it("list returns rooms", function()
        local sched = Scheduler.new()
        local mgr_addr = sched:spawn(room_mgr)
        local results
        sched:spawn(function(ctx)
            ctx:call(mgr_addr, "create", {room_name = "x", max_players = 4})
            results = ctx:call(mgr_addr, "list", {})
            ctx:exit()
        end)
        for _ = 1, 10 do sched:tick(0) end
        t.assert.eq(#results, 1)
        t.assert.eq(results[1].name, "x")
    end)

    t.it("join returns room info and players", function()
        local sched = Scheduler.new()
        local mgr_addr = sched:spawn(room_mgr)
        local info, players
        sched:spawn(function(ctx)
            local rid = ctx:call(mgr_addr, "create", {room_name = "r", max_players = 4})
            info, players = ctx:call(mgr_addr, "join", {
                room_id = rid,
                player  = {id = 1, name = "alice"},
                agent_addr = ctx.addr,
            })
            ctx:exit()
        end)
        for _ = 1, 10 do sched:tick(0) end
        t.assert.truthy(info)
        t.assert.eq(#players, 1)
        t.assert.eq(players[1].name, "alice")
    end)

    t.it("leave removes player and destroys empty room", function()
        local sched = Scheduler.new()
        local mgr_addr = sched:spawn(room_mgr)
        local list_after
        sched:spawn(function(ctx)
            local rid = ctx:call(mgr_addr, "create", {room_name = "r", max_players = 4})
            ctx:call(mgr_addr, "join", {
                room_id = rid, player = {id = 1, name = "a"}, agent_addr = ctx.addr
            })
            ctx:call(mgr_addr, "leave", {room_id = rid, player_id = 1})
            list_after = ctx:call(mgr_addr, "list", {})
            ctx:exit()
        end)
        for _ = 1, 20 do sched:tick(0) end
        t.assert.eq(#list_after, 0)
    end)
end)

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

local Cosocket = require "core.cosocket"
local log      = require "core.log"

---@class Service
---@field addr integer
---@field co thread
---@field mailbox table[]
---@field cosock Cosocket|nil
---@field dead boolean
---@field waiting_session integer|nil

---@class Scheduler
local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    return setmetatable({
        services      = {},  -- [addr] = Service
        next_addr     = 1,
        next_session  = 1,
    }, Scheduler)
end

function Scheduler:_alloc_addr()
    local a = self.next_addr
    self.next_addr = self.next_addr + 1
    return a
end

function Scheduler:_alloc_session()
    local s = self.next_session
    self.next_session = self.next_session + 1
    return s
end

function Scheduler:_make_ctx(svc)
    local sched = self
    local ctx = {addr = svc.addr}

    function ctx:recv()
        while #svc.mailbox == 0 do
            coroutine.yield()
        end
        local msg = table.remove(svc.mailbox, 1)
        return msg.type, msg.data
    end

    function ctx:recv_call()
        while #svc.mailbox == 0 do
            coroutine.yield()
        end
        local msg = table.remove(svc.mailbox, 1)
        return msg.session, msg.type, msg.data
    end

    function ctx:try_recv()
        if #svc.mailbox == 0 then return nil end
        local msg = table.remove(svc.mailbox, 1)
        return msg.type, msg.data
    end

    function ctx:send(addr, type, data)
        sched:send(addr, type, data)
    end

    function ctx:call(addr, type, data)
        local session = sched:_alloc_session()
        svc.waiting_session = session   -- set BEFORE sending, so reply can find us
        sched:_raw_send(addr, type, data, session)
        coroutine.yield()
        -- After resume: find the _reply_ in mailbox
        for i, msg in ipairs(svc.mailbox) do
            if msg.type == "_reply_" and msg.session == session then
                table.remove(svc.mailbox, i)
                svc.waiting_session = nil
                return msg.result
            end
        end
        svc.waiting_session = nil
        return nil
    end

    function ctx:reply(session, result)
        sched:_deliver_reply(session, result)
    end

    function ctx:bind_socket(sock)
        svc.cosock = Cosocket.new(sock)
        return svc.cosock
    end

    function ctx:exit()
        svc.dead = true
    end

    return ctx
end

function Scheduler:spawn(func, ...)
    local addr = self:_alloc_addr()
    local svc = {
        addr            = addr,
        mailbox         = {},
        dead            = false,
        cosock          = nil,
        waiting_session = nil,
    }
    local ctx = self:_make_ctx(svc)
    local args = {...}
    svc.co = coroutine.create(function()
        func(ctx, unpack(args))
    end)
    self.services[addr] = svc
    self:_resume(svc)
    return addr
end

function Scheduler:send(addr, type, data)
    self:_raw_send(addr, type, data, nil)
end

function Scheduler:_raw_send(addr, type, data, session)
    local svc = self.services[addr]
    if not svc or svc.dead then return end
    table.insert(svc.mailbox, {type = type, data = data, session = session})
end

function Scheduler:_deliver_reply(session, result)
    for _, svc in pairs(self.services) do
        if svc.waiting_session == session then
            table.insert(svc.mailbox, {type = "_reply_", session = session, result = result})
            return
        end
    end
end

function Scheduler:kill(addr)
    local svc = self.services[addr]
    if svc then svc.dead = true end
end

function Scheduler:_resume(svc)
    if svc.dead then return end
    if coroutine.status(svc.co) == "dead" then
        svc.dead = true
        return
    end
    local ok, err = coroutine.resume(svc.co)
    if not ok then
        log.error("service %d crashed: %s", svc.addr, tostring(err))
        svc.dead = true
    end
end

function Scheduler:tick(dt)
    -- 1. Poll cosockets
    for _, svc in pairs(self.services) do
        if svc.cosock then
            svc.cosock:poll()
        end
    end

    -- 2. Resume services with pending work
    for _, svc in pairs(self.services) do
        if not svc.dead then
            local should_resume
            if svc.waiting_session then
                -- Service is mid-call(): only wake when matching reply arrives
                for _, msg in ipairs(svc.mailbox) do
                    if msg.type == "_reply_" and msg.session == svc.waiting_session then
                        should_resume = true
                        break
                    end
                end
            else
                should_resume = #svc.mailbox > 0
                    or (svc.cosock and (#svc.cosock.rbuf > 0 or svc.cosock.closed))
            end
            if should_resume then
                self:_resume(svc)
            end
        end
    end

    -- 3. Clean up dead services
    local dead_addrs = {}
    for addr, svc in pairs(self.services) do
        if svc.dead then
            dead_addrs[#dead_addrs + 1] = addr
        end
    end
    for _, addr in ipairs(dead_addrs) do
        local svc = self.services[addr]
        if svc.cosock then svc.cosock:close() end
        self.services[addr] = nil
    end
end

function Scheduler:service_count()
    local n = 0
    for _ in pairs(self.services) do n = n + 1 end
    return n
end

return Scheduler

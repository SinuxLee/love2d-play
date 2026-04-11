local socket   = require "socket"
local protocol = require "core.protocol"
local log      = require "core.log"

---@param ctx table  scheduler context
---@param opts {host:string|nil, port:integer|nil, name:string|nil}
local function test_client(ctx, opts)
    local host = (opts and opts.host) or "127.0.0.1"
    local port = (opts and opts.port) or 12345
    local name = (opts and opts.name) or ("TestBot-" .. ctx.addr)

    local sock = socket.tcp()
    local ok, err = sock:connect(host, port)
    if not ok then
        log.warn("test_client: connect failed: %s", tostring(err))
        ctx:exit()
        return
    end

    local cosock = ctx:bind_socket(sock)
    log.info("test_client '%s' connected (addr=%d)", name, ctx.addr)

    -- 登录
    cosock:queue_write(protocol.encode({type = "login", name = name}))

    -- 主循环：接收并打印服务端消息
    while not cosock.closed do
        local proxy = {data = cosock.rbuf}
        local msg = protocol.try_decode(proxy)
        if msg then
            cosock.rbuf = proxy.data
            log.info("[%s] recv: %s", name, msg.type)
        else
            coroutine.yield()
        end
    end

    log.info("test_client '%s' disconnected", name)
    ctx:exit()
end

return test_client

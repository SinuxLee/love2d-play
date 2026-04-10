local log = require "core.log"

local MAX_CONNECTIONS = 4096

---@param ctx table  scheduler context
---@param opts {port:integer, room_mgr_addr:integer, scheduler:table}
local function gate(ctx, opts)
    local socket = require "socket"
    local port   = opts.port or 12345
    local agent  = require "service.agent"

    local server = assert(socket.bind("*", port))
    server:settimeout(0)
    log.info("gate listening on port %d", port)

    local conn_count = 0

    while true do
        local client = server:accept()
        if client then
            if conn_count >= MAX_CONNECTIONS then
                log.warn("max connections reached (%d), rejecting", MAX_CONNECTIONS)
                client:close()
            else
                conn_count = conn_count + 1
                local peer = tostring(client:getpeername())
                log.info("new connection #%d from %s", conn_count, peer)
                opts.scheduler:spawn(agent, {
                    sock          = client,
                    room_mgr_addr = opts.room_mgr_addr,
                    on_close      = function()
                        conn_count = conn_count - 1
                    end,
                })
            end
        end
        coroutine.yield()
    end
end

return gate

local protocol = require "core.protocol"
local log      = require "core.log"

---@param ctx table  scheduler context
---@param opts {sock:table, room_mgr_addr:integer, on_close:function|nil}
local function agent(ctx, opts)
    local cosock   = ctx:bind_socket(opts.sock)
    local mgr_addr = opts.room_mgr_addr
    local on_close = opts.on_close
    local player   = nil   -- {id, name}  set after login
    local room_id  = nil   -- integer, set after join

    local function send_to_client(msg)
        cosock:queue_write(protocol.encode(msg))
    end

    local function handle_client_msg(msg)
        local t = msg.type

        if t == "login" then
            player = {id = ctx.addr, name = msg.name or ("Player" .. ctx.addr)}
            send_to_client({type = "login_ok", player_id = player.id})
            log.info("player %d '%s' logged in (addr=%d)", player.id, player.name, ctx.addr)

        elseif t == "room_list" then
            local list = ctx:call(mgr_addr, "list", {})
            send_to_client({type = "room_list", rooms = list or {}})

        elseif t == "create_room" then
            if not player then
                send_to_client({type = "error", message = "not logged in"})
                return
            end
            local rid = ctx:call(mgr_addr, "create", {
                room_name   = msg.room_name,
                max_players = msg.max_players or 8,
            })
            local info, players = ctx:call(mgr_addr, "join", {
                room_id    = rid,
                player     = player,
                agent_addr = ctx.addr,
            })
            if not info then
                send_to_client({type = "error", message = players or "join failed"})
            else
                room_id = rid
                send_to_client({type = "room_created", room_id = rid})
                send_to_client({type = "room_joined", room_id = rid, players = players or {}})
            end

        elseif t == "join_room" then
            if not player then
                send_to_client({type = "error", message = "not logged in"})
                return
            end
            local info, players = ctx:call(mgr_addr, "join", {
                room_id    = msg.room_id,
                player     = player,
                agent_addr = ctx.addr,
            })
            if not info then
                -- players holds the error string here
                send_to_client({type = "error", message = players or "join failed"})
            else
                room_id = msg.room_id
                send_to_client({type = "room_joined", room_id = room_id, players = players})
                ctx:call(mgr_addr, "broadcast_except", {
                    room_id     = room_id,
                    except_addr = ctx.addr,
                    msg         = {type = "player_joined", player = player},
                })
            end

        elseif t == "leave_room" then
            if room_id then
                ctx:call(mgr_addr, "leave", {room_id = room_id, player_id = player.id})
                ctx:call(mgr_addr, "broadcast_except", {
                    room_id     = room_id,
                    except_addr = ctx.addr,
                    msg         = {type = "player_left", player_id = player.id},
                })
                room_id = nil
                send_to_client({type = "room_left"})
            end

        elseif t == "room_msg" then
            if room_id and player then
                ctx:call(mgr_addr, "broadcast_except", {
                    room_id     = room_id,
                    except_addr = ctx.addr,
                    msg         = {type = "room_msg", from = player.id, data = msg.data},
                })
            end
        end
    end

    -- Main loop
    while not cosock.closed do
        -- 1. Try to decode one complete message from socket buffer
        local proxy = {data = cosock.rbuf}
        local msg = protocol.try_decode(proxy)
        if msg then
            cosock.rbuf = proxy.data
            handle_client_msg(msg)
        end

        -- 2. Drain mailbox (server->client forwards)
        local did_mailbox = false
        while true do
            local mtype, mdata = ctx:try_recv()
            if not mtype then break end
            did_mailbox = true
            if mtype == "forward" then
                send_to_client(mdata)
            end
        end

        -- 3. Yield if nothing happened this iteration
        if not msg and not did_mailbox then
            coroutine.yield()
        end
    end

    -- Disconnect cleanup
    if player and room_id then
        ctx:call(mgr_addr, "leave", {room_id = room_id, player_id = player.id})
        ctx:call(mgr_addr, "broadcast_except", {
            room_id     = room_id,
            except_addr = ctx.addr,
            msg         = {type = "player_left", player_id = player.id},
        })
    end
    if player then
        log.info("player %d '%s' disconnected", player.id, player.name)
    end
    if on_close then on_close() end
    ctx:exit()
end

return agent

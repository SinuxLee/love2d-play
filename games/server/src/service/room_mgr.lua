local Room = require "room.room"
local log  = require "core.log"

local MAX_PLAYERS_DEFAULT = 8

local function room_mgr(ctx)
    local rooms   = {}  -- [room_id] = Room
    local next_id = 1

    log.info("room_mgr started at addr=%d", ctx.addr)

    while true do
        local session, type, data = ctx:recv_call()

        if type == "create" then
            local room_name   = (data and data.room_name) or ("Room-" .. next_id)
            local max_players = (data and data.max_players) or MAX_PLAYERS_DEFAULT
            local room = Room.new(next_id, room_name, max_players)
            rooms[next_id] = room
            log.info("room created: id=%d name=%s", next_id, room_name)
            ctx:reply(session, next_id)
            next_id = next_id + 1

        elseif type == "join" then
            local room = rooms[data.room_id]
            if not room then
                ctx:reply(session, nil, "room not found")
            else
                local ok, err = room:add_player(data.player)
                if ok then
                    if data.agent_addr then
                        room.agent_addrs[data.player.id] = data.agent_addr
                    end
                    ctx:reply(session, room:to_info(), room.players)
                else
                    ctx:reply(session, nil, err)
                end
            end

        elseif type == "leave" then
            local room = rooms[data.room_id]
            if room then
                room:remove_player(data.player_id)
                if room:is_empty() then
                    rooms[data.room_id] = nil
                    log.info("room %d destroyed (empty)", data.room_id)
                end
            end
            ctx:reply(session, true)

        elseif type == "list" or type == "snapshot" then
            local list = {}
            for _, room in pairs(rooms) do
                list[#list + 1] = room:to_info()
            end
            ctx:reply(session, list)

        elseif type == "broadcast_except" then
            local room = rooms[data.room_id]
            if room then
                for pid, agent_addr in pairs(room.agent_addrs) do
                    if agent_addr ~= data.except_addr then
                        ctx:send(agent_addr, "forward", data.msg)
                    end
                end
            end
            ctx:reply(session, true)
        end
    end
end

return room_mgr

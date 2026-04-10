---@class Player
---@field id integer
---@field name string

---@class Room
---@field id integer
---@field name string
---@field max_players integer
---@field players Player[]
---@field agent_addrs table<integer, integer>  player_id -> agent addr
local Room = {}
Room.__index = Room

---@param id integer
---@param name string
---@param max_players integer
---@return Room
function Room.new(id, name, max_players)
    return setmetatable({
        id          = id,
        name        = name,
        max_players = max_players,
        players     = {},
        agent_addrs = {},
    }, Room)
end

---@param player Player
---@return boolean, string|nil
function Room:add_player(player)
    if #self.players >= self.max_players then
        return false, "room full"
    end
    table.insert(self.players, player)
    return true
end

---@param player_id integer
function Room:remove_player(player_id)
    for i, p in ipairs(self.players) do
        if p.id == player_id then
            table.remove(self.players, i)
            self.agent_addrs[player_id] = nil
            return
        end
    end
end

---@return integer[]
function Room:get_player_ids()
    local ids = {}
    for _, p in ipairs(self.players) do
        ids[#ids + 1] = p.id
    end
    return ids
end

---@return boolean
function Room:is_empty()
    return #self.players == 0
end

---@return {id:integer, name:string, count:integer, max:integer}
function Room:to_info()
    return {id = self.id, name = self.name, count = #self.players, max = self.max_players}
end

return Room

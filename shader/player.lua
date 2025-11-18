local json = require "json"

---@alias Data {errCode:integer, data:table}
---@alias Request fun(p: Player, robot_id: string): string,string,table<string,string>,string|nil
---@alias Response fun(p: Player, data: table<string,any>)

---@type Request
local function login(_, robot_id)
    local path = string.format("/auth/v1/inner/access_token?platform=wechat&open_id=robot_%d&app_id=1001", robot_id)
    local headers = { ["X-Robot-Index"] = robot_id, }
    return "GET", path, headers, nil
end

---@type Response
local function login_result(p, data)
    p.user_id = data.userId
    p.access_token = data.accessToken
end

---@type Request
local function user_info(p, robot_id)
    local path = string.format("/auth/v1/player/info?user_id=%d", p.user_id)
    local headers = { ["X-Robot-Index"] = robot_id, }
    return "GET", path, headers, nil
end

---@type Response
local function user_info_result(p, data)
    -- if data.userId ~= p.user_id then
    -- end
end

---@type Request
local function verify_token(p, robot_id)
    local path = string.format("/auth/v1/token/authentication?access_token=%s&user_id=%d", p.access_token, p.user_id)
    local headers = { ["X-Robot-Index"] = robot_id, }
    return "GET", path, headers, nil
end

---@type Response
local function verify_token_result(p, data)
    -- if data == nil then
    -- end
end


---@class Player
---@field user_id integer
---@field idx integer
---@field access_token string
---@field fun Request[]
local Player = {
    _version = "0.0.1"
}

-- 冒号 = 面向对象实例方法；点号 = 静态/工具函数
---@param idx integer
---@return Player
function Player.new(idx)
    local obj = { user_id = 0, idx = idx, access_token = "" }
    return setmetatable(obj, { __index = Player })
end

---@param robot_id string
---@return string method
---@return string path
---@return table<string,string> headers
---@return string|nil body
function Player:get_request(robot_id)
    local i = self.idx
    self.idx = i + 1
    return self.fun[i](self, robot_id)
end

function Player:restart()
    self.idx = 2
end

function Player:is_end()
    return self.idx > #self.fun
end

Player.fun = {
    [1] = login,
    [2] = user_info,
    [3] = verify_token,
}

---@type Response[] 处理 response
local switch = {
    [1] = login_result,
    [2] = login_result,
    [3] = user_info_result,
    [4] = verify_token_result,
}

function Player.parse_rsp(self, body)
    ---@type Data
    local rsp = json.decode(body)

    if rsp.errCode == 0 then
        local fun = switch[self.idx]
        if fun then
            fun(self, rsp.data)
        end
    end
end

return Player

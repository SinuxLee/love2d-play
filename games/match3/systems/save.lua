---@class SaveData
---@field nick string
---@field maxLevel integer
---@field totalScore integer
---@field levelScores table<integer, integer>
---@field levelStars table<integer, integer>  -- per-level best star rating (1-3)
---@field failCount integer    consecutive fails on current level
---@field lastDropBias number  last effective drop bias
---@field ddaCurve string      DDA curve name ("linear"|"quadratic"|"logarithmic")
---@field mlProfile table?     serialized PlayerProfile
---@field mlBandit table?      serialized DifficultyBandit
---@field mlEnabled boolean    true if ML-DDA mode is active

---@class Save
---@field nick string
---@field data SaveData
local Save = {}
Save.nick = ""
Save.data = { nick = "", maxLevel = 1, totalScore = 0, levelScores = {}, levelStars = {}, failCount = 0, lastDropBias = 0, ddaCurve =
"linear", mlProfile = nil, mlBandit = nil, mlEnabled = true }

---@param nick string
---@return string
function Save.getFilePath(nick)
    return "saves/" .. nick .. ".sav"
end

---Serialize a Lua value to a string (without "return" prefix)
---@param val any
---@return string
local function serializeValue(val)
    if type(val) == "table" then
        local parts = {}
        for k, v in pairs(val) do
            local key
            if type(k) == "number" then
                key = "[" .. k .. "]"
            else
                key = '["' .. tostring(k) .. '"]'
            end
            table.insert(parts, key .. "=" .. serializeValue(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif type(val) == "string" then
        return string.format("%q", val)
    else
        return tostring(val)
    end
end

---Serialize a Lua table to a saveable string
---@param tbl table
---@return string
function Save.serialize(tbl)
    return "return " .. serializeValue(tbl)
end

---Deserialize a string to a Lua table
---@param str string
---@return table?
function Save.deserialize(str)
    local fn, err = load(str, "save", "t", {})
    if fn then
        local ok, result = pcall(fn)
        if ok and type(result) == "table" then
            return result
        end
    end
    return nil
end

---Check if a save file exists for the given nick
---@param nick string
---@return boolean
function Save.exists(nick)
    if not love or not love.filesystem then return false end
    return love.filesystem.getInfo(Save.getFilePath(nick)) ~= nil
end

---Load save data for the given nick
---@param nick string
---@return boolean success
function Save.load(nick)
    Save.nick = nick
    if not love or not love.filesystem then
        Save.data = { nick = nick, maxLevel = 1, totalScore = 0, levelScores = {}, levelStars = {}, failCount = 0, lastDropBias = 0, ddaCurve =
        "linear" }
        return false
    end

    local path = Save.getFilePath(nick)
    if not love.filesystem.getInfo(path) then
        Save.data = { nick = nick, maxLevel = 1, totalScore = 0, levelScores = {}, levelStars = {}, failCount = 0, lastDropBias = 0, ddaCurve =
        "linear" }
        return false
    end

    local content = love.filesystem.read(path)
    if content then
        local data = Save.deserialize(content)
        if data then
            Save.data = data
            Save.data.nick = nick
            Save.data.maxLevel = Save.data.maxLevel or 1
            Save.data.totalScore = Save.data.totalScore or 0
            Save.data.levelScores = Save.data.levelScores or {}
            Save.data.levelStars = Save.data.levelStars or {}
            Save.data.failCount = Save.data.failCount or 0
            Save.data.lastDropBias = Save.data.lastDropBias or 0
            Save.data.ddaCurve = Save.data.ddaCurve or "linear"
            -- ML fields (backward compatible: old saves get defaults)
            if Save.data.mlEnabled == nil then Save.data.mlEnabled = true end
            -- mlProfile and mlBandit remain nil if absent (fresh state)
            return true
        end
    end

    Save.data = { nick = nick, maxLevel = 1, totalScore = 0, levelScores = {}, levelStars = {}, failCount = 0, lastDropBias = 0, ddaCurve =
    "linear" }
    return false
end

---Save current data to file
---@return boolean success
function Save.save()
    if not love or not love.filesystem then return false end
    love.filesystem.createDirectory("saves")
    local content = Save.serialize(Save.data)
    local ok, _ = love.filesystem.write(Save.getFilePath(Save.nick), content)
    return ok
end

---Set nick and initialize data
---@param nick string
function Save.setNick(nick)
    Save.nick = nick
    Save.load(nick)
end

---Update save after completing a level
---@param levelNum integer
---@param score integer
---@param ddaCurve? string
---@param stars? integer
function Save.onLevelComplete(levelNum, score, ddaCurve, stars)
    if levelNum >= Save.data.maxLevel then
        Save.data.maxLevel = levelNum + 1
    end
    Save.data.totalScore = Save.data.totalScore + score
    Save.data.levelScores[levelNum] = math.max(Save.data.levelScores[levelNum] or 0, score)
    if stars and stars > 0 then
        Save.data.levelStars[levelNum] = math.max(Save.data.levelStars[levelNum] or 0, stars)
    end
    Save.data.failCount = 0
    Save.data.lastDropBias = 0
    if ddaCurve then Save.data.ddaCurve = ddaCurve end
    Save.save()
end

---Update save after failing a level
---@param failCount integer
---@param dropBias number
---@param ddaCurve? string
function Save.onLevelFail(failCount, dropBias, ddaCurve)
    Save.data.failCount = failCount
    Save.data.lastDropBias = dropBias
    if ddaCurve then Save.data.ddaCurve = ddaCurve end
    Save.save()
end

return Save

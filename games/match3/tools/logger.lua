--- Structured JSON Lines logger
--- Writes to <project>/logs/game.log via io.open (agent-friendly path)
--- Gracefully disabled when project dir is not writable (fused builds)

---@class Logger
---@field enabled boolean
---@field level integer
local Logger = {}

Logger.TRACE = 1
Logger.DEBUG = 2
Logger.INFO = 3
Logger.WARN = 4
Logger.ERROR = 5

local LEVEL_NAMES = { [1] = "TRACE", [2] = "DEBUG", [3] = "INFO", [4] = "WARN", [5] = "ERROR" }

Logger.enabled = false
Logger.level = Logger.INFO

local buffer = {}
local fileHandle = nil
local flushTimer = 0
local sessionStart = 0

local FLUSH_INTERVAL = 3.0
local MAX_BUFFER = 80
local MAX_FILE_SIZE = 1024 * 1024 -- 1MB

-- ============================================================
-- Minimal JSON encoder (handles string/number/boolean/table)
-- ============================================================

local jsonEncode

---@param val any
---@return string
function jsonEncode(val)
    if val == nil then return "null" end
    local t = type(val)
    if t == "string" then
        return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"')
                         :gsub('\n', '\\n'):gsub('\r', '\\r')
                         :gsub('\t', '\\t') .. '"'
    elseif t == "number" then
        if val ~= val then return '"NaN"' end              -- NaN safety
        if val == math.huge then return '"Inf"' end
        if val == -math.huge then return '"-Inf"' end
        -- Emit integers without decimal point
        if val == math.floor(val) and math.abs(val) < 1e15 then
            return string.format("%d", val)
        end
        return string.format("%.4f", val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        -- Distinguish array (sequential integer keys) from object
        local n = #val
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = jsonEncode(val[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        if next(val) == nil then return "{}" end
        local parts = {}
        for k, v in pairs(val) do
            parts[#parts + 1] = jsonEncode(tostring(k)) .. ":" .. jsonEncode(v)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return '"' .. tostring(val) .. '"'
end

Logger.jsonEncode = jsonEncode -- expose for testing

-- ============================================================
-- Core API
-- ============================================================

function Logger.init()
    -- Determine writable project directory
    if not (love and love.filesystem) then return end
    local source = love.filesystem.getSource()
    if not source or love.filesystem.isFused() then return end

    local logDir = source .. "/logs"
    local logPath = logDir .. "/game.log"

    -- Try opening; create directory on failure
    fileHandle = io.open(logPath, "a")
    if not fileHandle then
        local sep = package.config:sub(1, 1)
        if sep == "\\" then
            os.execute('mkdir "' .. logDir:gsub("/", "\\") .. '" 2>NUL')
        else
            os.execute('mkdir -p "' .. logDir .. '" 2>/dev/null')
        end
        fileHandle = io.open(logPath, "a")
    end
    if not fileHandle then return end

    -- Rotate if file exceeds size limit
    local size = fileHandle:seek("end")
    if size and size > MAX_FILE_SIZE then
        fileHandle:close()
        os.remove(logPath .. ".prev")
        os.rename(logPath, logPath .. ".prev")
        fileHandle = io.open(logPath, "a")
        if not fileHandle then return end
    end

    Logger.enabled = true
    sessionStart = love.timer and love.timer.getTime() or os.clock()

    Logger.info("logger", "session_start", {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        log_path = logPath,
    })
    Logger.flush() -- ensure session_start is persisted immediately
end

---@param level integer
---@param module string
---@param msg string
---@param data? table
function Logger.log(level, module, msg, data)
    if not Logger.enabled or level < Logger.level then return end

    local gt = 0
    if love and love.timer then
        gt = love.timer.getTime() - sessionStart
    end

    -- Build JSON line manually (avoids full-table encode overhead for the envelope)
    local parts = {
        '"t":', jsonEncode(os.date("%H:%M:%S")),
        ',"gt":', string.format("%.2f", gt),
        ',"lvl":', jsonEncode(LEVEL_NAMES[level] or "?"),
        ',"mod":', jsonEncode(module),
        ',"msg":', jsonEncode(msg),
    }
    if data then
        parts[#parts + 1] = ',"data":'
        parts[#parts + 1] = jsonEncode(data)
    end

    buffer[#buffer + 1] = "{" .. table.concat(parts) .. "}"

    if #buffer >= MAX_BUFFER then
        Logger.flush()
    end
end

function Logger.trace(mod, msg, data) Logger.log(Logger.TRACE, mod, msg, data) end
function Logger.debug(mod, msg, data) Logger.log(Logger.DEBUG, mod, msg, data) end
function Logger.info(mod, msg, data)  Logger.log(Logger.INFO, mod, msg, data) end
function Logger.warn(mod, msg, data)  Logger.log(Logger.WARN, mod, msg, data) end
function Logger.error(mod, msg, data) Logger.log(Logger.ERROR, mod, msg, data) end

function Logger.flush()
    if not fileHandle or #buffer == 0 then return end
    fileHandle:write(table.concat(buffer, "\n") .. "\n")
    fileHandle:flush()
    buffer = {}
end

---@param dt number
function Logger.update(dt)
    if not Logger.enabled then return end
    flushTimer = flushTimer + dt
    if flushTimer >= FLUSH_INTERVAL then
        flushTimer = 0
        Logger.flush()
    end
end

function Logger.close()
    if not Logger.enabled then return end
    Logger.info("logger", "session_end")
    Logger.flush()
    if fileHandle then
        fileHandle:close()
        fileHandle = nil
    end
    Logger.enabled = false
end

return Logger

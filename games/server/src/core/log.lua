local MAX_ENTRIES = 200
local entries = {}

local function append(level, fmt, ...)
    local msg = string.format(fmt, ...)
    local entry = {level = level, msg = msg, time = os.clock()}
    table.insert(entries, entry)
    if #entries > MAX_ENTRIES then
        table.remove(entries, 1)
    end
    io.write(string.format("[%s] %s\n", level, msg))
    io.flush()
end

local log = {}

function log.info(fmt, ...)  append("INFO",  fmt, ...) end
function log.warn(fmt, ...)  append("WARN",  fmt, ...) end
function log.error(fmt, ...) append("ERROR", fmt, ...) end

function log._reset()   entries = {} end
function log._entries() return entries end

return log

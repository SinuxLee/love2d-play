local mp = require "msgpack"

local protocol = {}

function protocol.encode(msg)
    local payload = mp.pack(msg)
    local len = #payload
    local header = string.char(
        math.floor(len / 16777216) % 256,
        math.floor(len / 65536)    % 256,
        math.floor(len / 256)      % 256,
        len                        % 256
    )
    return header .. payload
end

function protocol.decode_from_buffer(frame)
    local len = string.byte(frame,1)*16777216 + string.byte(frame,2)*65536
              + string.byte(frame,3)*256 + string.byte(frame,4)
    local _, val = mp.unpack(frame:sub(5, 4 + len))
    return val
end

function protocol.try_decode(buf)
    if #buf.data < 4 then return nil end
    local len = string.byte(buf.data,1)*16777216 + string.byte(buf.data,2)*65536
              + string.byte(buf.data,3)*256 + string.byte(buf.data,4)
    if #buf.data < 4 + len then return nil end
    local payload = buf.data:sub(5, 4 + len)
    buf.data = buf.data:sub(5 + len)
    local _, val = mp.unpack(payload)
    return val
end

return protocol

local t = require "testing"
local protocol = require "core.protocol"

t.describe("protocol", function()
    t.it("encode produces 4-byte header + payload", function()
        local frame = protocol.encode({type = "ping"})
        t.assert.truthy(#frame > 4)
        local len = string.byte(frame,1)*16777216 + string.byte(frame,2)*65536
                  + string.byte(frame,3)*256 + string.byte(frame,4)
        t.assert.eq(len, #frame - 4)
    end)

    t.it("decode returns original message", function()
        local msg = {type = "join_room", room_id = 42, name = "alice"}
        local frame = protocol.encode(msg)
        local decoded = protocol.decode_from_buffer(frame)
        t.assert.eq(decoded.type, "join_room")
        t.assert.eq(decoded.room_id, 42)
        t.assert.eq(decoded.name, "alice")
    end)

    t.it("try_decode returns nil when incomplete", function()
        local frame = protocol.encode({type = "ping"})
        local partial = frame:sub(1, 3)
        local buf = {data = partial}
        local msg = protocol.try_decode(buf)
        t.assert.falsy(msg)
        t.assert.eq(buf.data, partial)
    end)

    t.it("try_decode consumes buffer when complete", function()
        local frame = protocol.encode({type = "pong", n = 7})
        local buf = {data = frame}
        local msg = protocol.try_decode(buf)
        t.assert.eq(msg.type, "pong")
        t.assert.eq(msg.n, 7)
        t.assert.eq(buf.data, "")
    end)

    t.it("try_decode handles two frames in buffer", function()
        local f1 = protocol.encode({type = "a"})
        local f2 = protocol.encode({type = "b"})
        local buf = {data = f1 .. f2}
        local m1 = protocol.try_decode(buf)
        local m2 = protocol.try_decode(buf)
        t.assert.eq(m1.type, "a")
        t.assert.eq(m2.type, "b")
        t.assert.eq(buf.data, "")
    end)
end)

local t = require "testing"
local Cosocket = require "core.cosocket"

local function make_mock_sock(recv_data, send_buf)
    recv_data = recv_data or ""
    send_buf = send_buf or {}
    local pos = 1
    return {
        _send_buf = send_buf,
        receive = function(self, n)
            if pos > #recv_data then return nil, "timeout" end
            local chunk = recv_data:sub(pos, pos + n - 1)
            pos = pos + #chunk
            return chunk
        end,
        send = function(self, data)
            table.insert(self._send_buf, data)
            return #data
        end,
        close = function(self) end,
        settimeout = function(self, t) end,
    }
end

t.describe("Cosocket", function()
    t.it("poll fills rbuf from socket", function()
        local sock = make_mock_sock("hello")
        local cs = Cosocket.new(sock)
        cs:poll()
        t.assert.eq(cs.rbuf, "hello")
    end)

    t.it("try_read returns nil when not enough data", function()
        local cs = Cosocket.new(make_mock_sock("hi"))
        cs:poll()
        t.assert.falsy(cs:try_read(10))
        t.assert.eq(cs.rbuf, "hi")
    end)

    t.it("try_read consumes exact bytes when available", function()
        local cs = Cosocket.new(make_mock_sock("abcdef"))
        cs:poll()
        local data = cs:try_read(3)
        t.assert.eq(data, "abc")
        t.assert.eq(cs.rbuf, "def")
    end)

    t.it("unread prepends data to rbuf", function()
        local cs = Cosocket.new(make_mock_sock("world"))
        cs:poll()
        cs:try_read(5)
        cs:unread("world")
        t.assert.eq(cs.rbuf, "world")
    end)

    t.it("queue_write flushes on poll", function()
        local sent = {}
        local sock = make_mock_sock("", sent)
        local cs = Cosocket.new(sock)
        cs:queue_write("ping")
        cs:poll()
        t.assert.eq(table.concat(sent), "ping")
        t.assert.eq(cs.wbuf, "")
    end)

    t.it("marks closed on non-timeout recv error", function()
        local sock = make_mock_sock()
        sock.receive = function() return nil, "closed" end
        local cs = Cosocket.new(sock)
        cs:poll()
        t.assert.truthy(cs.closed)
    end)
end)

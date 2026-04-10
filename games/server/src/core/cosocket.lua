---@class Cosocket
---@field sock table
---@field rbuf string
---@field wbuf string
---@field closed boolean
local Cosocket = {}
Cosocket.__index = Cosocket

function Cosocket.new(sock)
    sock:settimeout(0)
    return setmetatable({
        sock   = sock,
        rbuf   = "",
        wbuf   = "",
        closed = false,
    }, Cosocket)
end

function Cosocket:poll()
    if self.closed then return end

    local data, err = self.sock:receive(8192)
    if data then
        self.rbuf = self.rbuf .. data
    elseif err ~= "timeout" then
        self.closed = true
        return
    end

    if #self.wbuf > 0 then
        local sent, serr = self.sock:send(self.wbuf)
        if sent then
            self.wbuf = self.wbuf:sub(sent + 1)
        elseif serr ~= "timeout" then
            self.closed = true
        end
    end
end

function Cosocket:try_read(n)
    if #self.rbuf < n then return nil end
    local data = self.rbuf:sub(1, n)
    self.rbuf = self.rbuf:sub(n + 1)
    return data
end

function Cosocket:unread(data)
    self.rbuf = data .. self.rbuf
end

function Cosocket:queue_write(data)
    self.wbuf = self.wbuf .. data
end

function Cosocket:close()
    self.closed = true
    pcall(function() self.sock:close() end)
end

return Cosocket

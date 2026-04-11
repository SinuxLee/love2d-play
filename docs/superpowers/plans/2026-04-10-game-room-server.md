# Game Room Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `games/server/` 实现一个基于 Love2D 的游戏房间服务器，支持 4096+ 并发 TCP 连接，采用协程驱动的 Service/Actor 调度模型（借鉴 Skynet），cosocket 封装（借鉴 OpenResty），suit 管理面板。

**Architecture:** Scheduler 每帧驱动所有 Service 协程；每个客户端连接对应一个 agent service，socket I/O 通过 Cosocket 缓冲层解耦；Service 间通过 mailbox 异步通信，call/reply 模式实现同步语义。

**Tech Stack:** Love2D 11.4 + LuaJIT / luasocket (内置) / lua-msgpack (submodule) / suit (vendor)

---

## File Map

| 文件 | 职责 |
|------|------|
| `games/server/conf.lua` | Love2D 配置，关闭不需要的模块，设置 require 路径 |
| `games/server/main.lua` | 入口：初始化 scheduler，spawn gate/room_mgr，主循环 |
| `games/server/src/core/log.lua` | 带时间戳和级别的日志模块 |
| `games/server/src/core/protocol.lua` | 消息分帧：4字节大端长度 + msgpack payload |
| `games/server/src/core/cosocket.lua` | 非阻塞 socket 缓冲层（rbuf/wbuf），供 scheduler 驱动 |
| `games/server/src/core/scheduler.lua` | Service 调度器：spawn/send/call/reply/tick |
| `games/server/src/service/gate.lua` | 网关：监听端口，accept 新连接，spawn agent |
| `games/server/src/service/agent.lua` | 客户端代理：解析客户端消息，转发服务端消息 |
| `games/server/src/service/room_mgr.lua` | 房间管理：create/join/leave/list room |
| `games/server/src/room/room.lua` | 房间实例：玩家列表，广播 |
| `games/server/src/ui/panel.lua` | suit 管理面板，显示状态/房间/日志 |
| `games/server/tests/test_protocol.lua` | protocol 单元测试 |
| `games/server/tests/test_cosocket.lua` | cosocket 单元测试（mock socket）|
| `games/server/tests/test_scheduler.lua` | scheduler 单元测试 |
| `games/server/tests/test_room.lua` | room + room_mgr 单元测试 |

---

## Task 1: Add lua-msgpack submodule + project scaffold

**Files:**
- Create: `vendor/lua-msgpack/` (git submodule)
- Create: `games/server/conf.lua`
- Create: `games/server/main.lua`
- Create: `games/server/src/core/.gitkeep`

- [ ] **Step 1: 添加 lua-msgpack submodule**

```bash
cd /path/to/love2d-play
git submodule add https://github.com/kengonakajima/lua-msgpack vendor/lua-msgpack
```

预期输出：`Cloning into 'vendor/lua-msgpack'...` 然后看到 `vendor/lua-msgpack/msgpack.lua` 存在。

- [ ] **Step 2: 确认 msgpack API 可用**

```bash
luajit -e "
package.path = 'vendor/?.lua;vendor/?/?.lua;' .. package.path
local mp = require 'lua-msgpack.msgpack'
local s = mp.pack({type='hello', n=42})
local v = mp.unpack(s)
print(v.type, v.n)
"
```

预期输出：`hello	42`

- [ ] **Step 3: 创建目录结构**

```bash
mkdir -p games/server/src/core
mkdir -p games/server/src/service
mkdir -p games/server/src/room
mkdir -p games/server/src/ui
mkdir -p games/server/tests
```

- [ ] **Step 4: 创建 `games/server/conf.lua`**

```lua
do
    local source = love.filesystem.getSource()
    local root = source .. "/../../"
    package.path = source .. "/src/?.lua;"
        .. source .. "/src/?/init.lua;"
        .. root .. "vendor/?.lua;"
        .. root .. "vendor/?/init.lua;"
        .. root .. "vendor/lua-msgpack/?.lua;"
        .. root .. "shared/?.lua;"
        .. root .. "shared/?/init.lua;"
        .. package.path
end

function love.conf(t)
    t.version = "11.4"
    t.console = false

    t.window.title = "Game Server"
    t.window.width = 900
    t.window.height = 600
    t.window.resizable = true

    t.modules.audio    = false
    t.modules.joystick = false
    t.modules.physics  = false
    t.modules.sound    = false
    t.modules.touch    = false
    t.modules.video    = false
end
```

注意：`vendor/lua-msgpack/?.lua` 额外加入路径，使 `require "msgpack"` 可直接找到 `vendor/lua-msgpack/msgpack.lua`。

- [ ] **Step 5: 创建 `games/server/main.lua` 占位**

```lua
-- main.lua: 暂时只验证依赖可加载
local mp = require "msgpack"
assert(mp.pack and mp.unpack, "msgpack load failed")

function love.load()
    print("[server] starting...")
end

function love.update(dt)
end

function love.draw()
    love.graphics.print("Game Server - initializing", 10, 10)
end
```

- [ ] **Step 6: 验证 Love2D 能启动**

```bash
make run GAME=server
```

预期：打开窗口，显示 "Game Server - initializing"，控制台输出 `[server] starting...`

- [ ] **Step 7: Commit**

```bash
git add vendor/lua-msgpack vendor/.gitmodules .gitmodules
git add games/server/
git commit -m "feat(server): scaffold project and add lua-msgpack submodule"
```

---

## Task 2: log.lua

**Files:**
- Create: `games/server/src/core/log.lua`
- Create: `games/server/tests/test_log.lua`

- [ ] **Step 1: 写失败测试**

创建 `games/server/tests/test_log.lua`:

```lua
local t = require "testing"
local log = require "core.log"

t.describe("log", function()
    t.it("records messages with level", function()
        log._reset()
        log.info("hello %s", "world")
        local entries = log._entries()
        t.assert.eq(#entries, 1)
        t.assert.eq(entries[1].level, "INFO")
        t.assert.contains(entries[1].msg, "hello world")
    end)

    t.it("keeps only last 200 entries", function()
        log._reset()
        for i = 1, 210 do log.info("msg %d", i) end
        t.assert.eq(#log._entries(), 200)
    end)

    t.it("warn and error levels work", function()
        log._reset()
        log.warn("w")
        log.error("e")
        local entries = log._entries()
        t.assert.eq(entries[1].level, "WARN")
        t.assert.eq(entries[2].level, "ERROR")
    end)
end)
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
make unit-test GAME=server
```

预期：`[FAIL] log > records messages with level` (module not found)

- [ ] **Step 3: 实现 `games/server/src/core/log.lua`**

```lua
---@class LogEntry
---@field level string
---@field msg string
---@field time number

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

-- 测试辅助（不在生产代码中调用）
function log._reset()   entries = {} end
function log._entries() return entries end

return log
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
make unit-test GAME=server
```

预期：`RESULTS: 3 passed, 0 failed, 0 skipped (3 total)`

- [ ] **Step 5: Commit**

```bash
git add games/server/src/core/log.lua games/server/tests/test_log.lua
git commit -m "feat(server): add log module"
```

---

## Task 3: protocol.lua

**Files:**
- Create: `games/server/src/core/protocol.lua`
- Create: `games/server/tests/test_protocol.lua`

协议格式：`[4字节大端长度][msgpack payload]`，length 不含自身。

- [ ] **Step 1: 写失败测试**

创建 `games/server/tests/test_protocol.lua`:

```lua
local t = require "testing"
local protocol = require "core.protocol"

t.describe("protocol", function()
    t.it("encode produces 4-byte header + payload", function()
        local frame = protocol.encode({type = "ping"})
        t.assert.truthy(#frame > 4)
        -- 前4字节是长度
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

    t.it("decode_from_buffer returns nil when incomplete", function()
        local frame = protocol.encode({type = "ping"})
        local partial = frame:sub(1, 3)  -- 不完整
        local buf = {data = partial}
        local msg = protocol.try_decode(buf)
        t.assert.falsy(msg)
        t.assert.eq(buf.data, partial)  -- buffer 不变
    end)

    t.it("try_decode consumes buffer when complete", function()
        local frame = protocol.encode({type = "pong", n = 7})
        local buf = {data = frame}
        local msg = protocol.try_decode(buf)
        t.assert.eq(msg.type, "pong")
        t.assert.eq(msg.n, 7)
        t.assert.eq(buf.data, "")  -- buffer 已消费
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
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
make unit-test GAME=server
```

预期：module not found 错误

- [ ] **Step 3: 实现 `games/server/src/core/protocol.lua`**

```lua
local mp = require "msgpack"

local protocol = {}

--- 将 table 编码为带长度前缀的帧
---@param msg table
---@return string
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

--- 从完整帧字符串解码（用于测试）
---@param frame string
---@return table
function protocol.decode_from_buffer(frame)
    local len = string.byte(frame,1)*16777216 + string.byte(frame,2)*65536
              + string.byte(frame,3)*256 + string.byte(frame,4)
    return mp.unpack(frame:sub(5, 4 + len))
end

--- 尝试从缓冲区 buf.data 解码一帧，成功则消费缓冲区并返回 msg，否则返回 nil
---@param buf {data: string}
---@return table|nil
function protocol.try_decode(buf)
    if #buf.data < 4 then return nil end
    local len = string.byte(buf.data,1)*16777216 + string.byte(buf.data,2)*65536
              + string.byte(buf.data,3)*256 + string.byte(buf.data,4)
    if #buf.data < 4 + len then return nil end
    local payload = buf.data:sub(5, 4 + len)
    buf.data = buf.data:sub(5 + len)
    return mp.unpack(payload)
end

return protocol
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
make unit-test GAME=server
```

预期：`RESULTS: 8 passed, 0 failed, 0 skipped (8 total)`

- [ ] **Step 5: Commit**

```bash
git add games/server/src/core/protocol.lua games/server/tests/test_protocol.lua
git commit -m "feat(server): add protocol framing (4-byte length prefix + msgpack)"
```

---

## Task 4: cosocket.lua

**Files:**
- Create: `games/server/src/core/cosocket.lua`
- Create: `games/server/tests/test_cosocket.lua`

Cosocket 是 socket 的缓冲包装。scheduler 每帧调用 `cosocket:poll()` 填充 rbuf、flush wbuf。业务代码通过 `try_read`/`queue_write` 访问，不直接操作 socket。

- [ ] **Step 1: 写失败测试**

创建 `games/server/tests/test_cosocket.lua`:

```lua
local t = require "testing"
local Cosocket = require "core.cosocket"

-- Mock socket: 可以预置返回数据
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
        t.assert.eq(cs.rbuf, "hi")  -- 不消费
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
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
make unit-test GAME=server
```

- [ ] **Step 3: 实现 `games/server/src/core/cosocket.lua`**

```lua
---@class Cosocket
---@field sock table       luasocket tcp socket (settimeout(0))
---@field rbuf string      接收缓冲区
---@field wbuf string      发送缓冲区
---@field closed boolean
local Cosocket = {}
Cosocket.__index = Cosocket

---@param sock table
---@return Cosocket
function Cosocket.new(sock)
    sock:settimeout(0)
    return setmetatable({
        sock   = sock,
        rbuf   = "",
        wbuf   = "",
        closed = false,
    }, Cosocket)
end

--- 由 scheduler 每帧调用：非阻塞读填充 rbuf，flush wbuf
function Cosocket:poll()
    if self.closed then return end

    -- 读
    local data, err = self.sock:receive(8192)
    if data then
        self.rbuf = self.rbuf .. data
    elseif err ~= "timeout" then
        self.closed = true
        return
    end

    -- 写
    if #self.wbuf > 0 then
        local sent, serr = self.sock:send(self.wbuf)
        if sent then
            self.wbuf = self.wbuf:sub(sent + 1)
        elseif serr ~= "timeout" then
            self.closed = true
        end
    end
end

--- 尝试从 rbuf 读取 n 字节，不足返回 nil（不消费 buffer）
---@param n integer
---@return string|nil
function Cosocket:try_read(n)
    if #self.rbuf < n then return nil end
    local data = self.rbuf:sub(1, n)
    self.rbuf = self.rbuf:sub(n + 1)
    return data
end

--- 将 data 放回 rbuf 头部（用于协议层回退）
---@param data string
function Cosocket:unread(data)
    self.rbuf = data .. self.rbuf
end

--- 将数据加入发送队列（下次 poll 时写出）
---@param data string
function Cosocket:queue_write(data)
    self.wbuf = self.wbuf .. data
end

function Cosocket:close()
    self.closed = true
    pcall(function() self.sock:close() end)
end

return Cosocket
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
make unit-test GAME=server
```

预期：`RESULTS: 14 passed, 0 failed, 0 skipped (14 total)`

- [ ] **Step 5: Commit**

```bash
git add games/server/src/core/cosocket.lua games/server/tests/test_cosocket.lua
git commit -m "feat(server): add cosocket buffered socket wrapper"
```

---

## Task 5: scheduler.lua

**Files:**
- Create: `games/server/src/core/scheduler.lua`
- Create: `games/server/tests/test_scheduler.lua`

调度器核心：管理 Service 协程、mailbox、cosocket 绑定。

Service context（`ctx`）暴露给 service 函数：
- `ctx.addr` — 本 service 地址
- `ctx:recv()` — 从 mailbox 取消息（无消息时 yield）
- `ctx:try_recv()` — 非阻塞取消息（无则返回 nil）
- `ctx:send(addr, type, data)` — 投递消息给另一 service
- `ctx:call(addr, type, data)` — send + 等待回复（同步语义）
- `ctx:reply(session, ...)` — 回复 call

- [ ] **Step 1: 写失败测试**

创建 `games/server/tests/test_scheduler.lua`:

```lua
local t = require "testing"
local Scheduler = require "core.scheduler"

t.describe("Scheduler", function()
    t.it("spawn runs service coroutine", function()
        local sched = Scheduler.new()
        local ran = false
        sched:spawn(function(ctx)
            ran = true
        end)
        sched:tick(0)
        t.assert.truthy(ran)
    end)

    t.it("send delivers message to mailbox", function()
        local sched = Scheduler.new()
        local received
        local addr = sched:spawn(function(ctx)
            local type, data = ctx:recv()
            received = {type = type, data = data}
        end)
        sched:tick(0)  -- service runs, blocks on recv
        sched:send(addr, "hello", {x = 1})
        sched:tick(0)  -- service resumes
        t.assert.eq(received.type, "hello")
        t.assert.eq(received.data.x, 1)
    end)

    t.it("call and reply work as synchronous RPC", function()
        local sched = Scheduler.new()
        local server_addr = sched:spawn(function(ctx)
            while true do
                local session, type, data = ctx:recv_call()
                if type == "add" then
                    ctx:reply(session, data.a + data.b)
                end
            end
        end)
        local result
        sched:spawn(function(ctx)
            result = ctx:call(server_addr, "add", {a = 3, b = 4})
        end)
        -- 需要多次 tick 让 call/reply 传递
        for _ = 1, 5 do sched:tick(0) end
        t.assert.eq(result, 7)
    end)

    t.it("kill removes service", function()
        local sched = Scheduler.new()
        local addr = sched:spawn(function(ctx)
            while true do ctx:recv() end
        end)
        sched:tick(0)
        t.assert.truthy(sched.services[addr])
        sched:kill(addr)
        sched:tick(0)
        t.assert.falsy(sched.services[addr])
    end)

    t.it("try_recv returns nil when mailbox empty", function()
        local sched = Scheduler.new()
        local got = "unset"
        sched:spawn(function(ctx)
            got = ctx:try_recv()
        end)
        sched:tick(0)
        t.assert.falsy(got)
    end)
end)
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
make unit-test GAME=server
```

- [ ] **Step 3: 实现 `games/server/src/core/scheduler.lua`**

```lua
local Cosocket = require "core.cosocket"

---@class Service
---@field addr integer
---@field co thread
---@field mailbox table[]
---@field cosock Cosocket|nil
---@field dead boolean
---@field waiting_session integer|nil  -- 正在等待 call 回复的 session

---@class Scheduler
local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    return setmetatable({
        services    = {},  -- [addr] = Service
        next_addr   = 1,
        next_session = 1,
        pending_calls = {}, -- [session] = {svc, result_slot}
        _dead       = {},
    }, Scheduler)
end

function Scheduler:_alloc_addr()
    local a = self.next_addr
    self.next_addr = self.next_addr + 1
    return a
end

function Scheduler:_alloc_session()
    local s = self.next_session
    self.next_session = self.next_session + 1
    return s
end

function Scheduler:_make_ctx(svc)
    local sched = self
    local ctx = {addr = svc.addr}

    -- 阻塞取消息（无消息则 yield）
    function ctx:recv()
        while #svc.mailbox == 0 do
            coroutine.yield()
        end
        local msg = table.remove(svc.mailbox, 1)
        return msg.type, msg.data
    end

    -- 取 call 消息（含 session）
    function ctx:recv_call()
        while #svc.mailbox == 0 do
            coroutine.yield()
        end
        local msg = table.remove(svc.mailbox, 1)
        return msg.session, msg.type, msg.data
    end

    -- 非阻塞取消息
    function ctx:try_recv()
        if #svc.mailbox == 0 then return nil end
        local msg = table.remove(svc.mailbox, 1)
        return msg.type, msg.data
    end

    -- 投递消息（fire and forget）
    function ctx:send(addr, type, data)
        sched:send(addr, type, data)
    end

    -- 同步 RPC：发送并等待回复
    function ctx:call(addr, type, data)
        local session = sched:_alloc_session()
        sched:_raw_send(addr, type, data, session)
        -- 挂起，等待 reply 投递回本 service 的 mailbox
        svc.waiting_session = session
        coroutine.yield()
        svc.waiting_session = nil
        -- reply 已被放入 mailbox 作为 {type="_reply_", session=s, result=...}
        for i, msg in ipairs(svc.mailbox) do
            if msg.type == "_reply_" and msg.session == session then
                table.remove(svc.mailbox, i)
                return msg.result
            end
        end
        return nil
    end

    -- 回复 call
    function ctx:reply(session, result)
        sched:_reply(session, result)
    end

    -- 绑定 cosocket 到本 service
    function ctx:bind_socket(sock)
        svc.cosock = Cosocket.new(sock)
        return svc.cosock
    end

    -- 销毁本 service
    function ctx:exit()
        svc.dead = true
    end

    return ctx
end

function Scheduler:spawn(func, ...)
    local addr = self:_alloc_addr()
    local svc = {
        addr    = addr,
        mailbox = {},
        dead    = false,
        cosock  = nil,
        waiting_session = nil,
    }
    local ctx = self:_make_ctx(svc)
    local args = {...}
    svc.co = coroutine.create(function()
        func(ctx, table.unpack(args))
    end)
    self.services[addr] = svc
    -- 立即 kick off
    self:_resume(svc)
    return addr
end

--- 投递消息（普通 send，无 session）
function Scheduler:send(addr, type, data)
    self:_raw_send(addr, type, data, nil)
end

function Scheduler:_raw_send(addr, type, data, session)
    local svc = self.services[addr]
    if not svc or svc.dead then return end
    table.insert(svc.mailbox, {type = type, data = data, session = session})
end

function Scheduler:_reply(session, result)
    -- 找到等待该 session 的 service
    for _, svc in pairs(self.services) do
        if svc.waiting_session == session then
            table.insert(svc.mailbox, {type = "_reply_", session = session, result = result})
            return
        end
    end
end

function Scheduler:kill(addr)
    local svc = self.services[addr]
    if svc then svc.dead = true end
end

function Scheduler:_resume(svc)
    if svc.dead then return end
    if coroutine.status(svc.co) == "dead" then
        svc.dead = true
        return
    end
    local ok, err = coroutine.resume(svc.co)
    if not ok then
        require("core.log").error("service %d crashed: %s", svc.addr, tostring(err))
        svc.dead = true
    end
end

--- 每帧调用：poll cosockets，resume 有工作的 service
---@param dt number
function Scheduler:tick(dt)
    -- 1. poll 所有 cosocket
    for _, svc in pairs(self.services) do
        if svc.cosock then
            svc.cosock:poll()
        end
    end

    -- 2. resume 所有有工作的 service
    for _, svc in pairs(self.services) do
        if not svc.dead then
            local has_work = #svc.mailbox > 0
                or (svc.cosock and (#svc.cosock.rbuf > 0 or svc.cosock.closed))
            if has_work or coroutine.status(svc.co) == "suspended" then
                self:_resume(svc)
            end
        end
    end

    -- 3. 清理 dead service
    for addr, svc in pairs(self.services) do
        if svc.dead then
            if svc.cosock then svc.cosock:close() end
            self.services[addr] = nil
        end
    end
end

--- 注册全局访问点（gate/agent 需要）
function Scheduler:service_count()
    local n = 0
    for _ in pairs(self.services) do n = n + 1 end
    return n
end

return Scheduler
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
make unit-test GAME=server
```

预期：`RESULTS: 19 passed, 0 failed, 0 skipped (19 total)`

- [ ] **Step 5: Commit**

```bash
git add games/server/src/core/scheduler.lua games/server/tests/test_scheduler.lua
git commit -m "feat(server): add coroutine scheduler with service/actor model"
```

---

## Task 6: room.lua

**Files:**
- Create: `games/server/src/room/room.lua`
- Create: `games/server/tests/test_room.lua`

Room 是纯数据结构，不依赖 scheduler，方便单元测试。

- [ ] **Step 1: 写失败测试**

创建 `games/server/tests/test_room.lua`:

```lua
local t = require "testing"
local Room = require "room.room"

t.describe("Room", function()
    t.it("creates with correct defaults", function()
        local r = Room.new(1, "lobby", 4)
        t.assert.eq(r.id, 1)
        t.assert.eq(r.name, "lobby")
        t.assert.eq(r.max_players, 4)
        t.assert.eq(#r.players, 0)
    end)

    t.it("add_player succeeds when not full", function()
        local r = Room.new(1, "lobby", 2)
        local ok, err = r:add_player({id = 10, name = "alice"})
        t.assert.truthy(ok)
        t.assert.falsy(err)
        t.assert.eq(#r.players, 1)
    end)

    t.it("add_player fails when full", function()
        local r = Room.new(1, "lobby", 1)
        r:add_player({id = 1, name = "a"})
        local ok, err = r:add_player({id = 2, name = "b"})
        t.assert.falsy(ok)
        t.assert.contains(err, "full")
    end)

    t.it("remove_player removes by id", function()
        local r = Room.new(1, "lobby", 4)
        r:add_player({id = 10, name = "alice"})
        r:add_player({id = 11, name = "bob"})
        r:remove_player(10)
        t.assert.eq(#r.players, 1)
        t.assert.eq(r.players[1].id, 11)
    end)

    t.it("get_player_ids returns list of ids", function()
        local r = Room.new(1, "lobby", 4)
        r:add_player({id = 5, name = "x"})
        r:add_player({id = 7, name = "y"})
        local ids = r:get_player_ids()
        table.sort(ids)
        t.assert.eq(ids[1], 5)
        t.assert.eq(ids[2], 7)
    end)

    t.it("is_empty returns true when no players", function()
        local r = Room.new(1, "lobby", 4)
        t.assert.truthy(r:is_empty())
        r:add_player({id = 1, name = "a"})
        t.assert.falsy(r:is_empty())
    end)

    t.it("to_info returns summary table", function()
        local r = Room.new(3, "arena", 8)
        r:add_player({id = 1, name = "a"})
        local info = r:to_info()
        t.assert.eq(info.id, 3)
        t.assert.eq(info.name, "arena")
        t.assert.eq(info.count, 1)
        t.assert.eq(info.max, 8)
    end)
end)
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
make unit-test GAME=server
```

- [ ] **Step 3: 实现 `games/server/src/room/room.lua`**

```lua
---@class Player
---@field id integer
---@field name string

---@class Room
---@field id integer
---@field name string
---@field max_players integer
---@field players Player[]
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
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
make unit-test GAME=server
```

预期：`RESULTS: 26 passed, 0 failed, 0 skipped (26 total)`

- [ ] **Step 5: Commit**

```bash
git add games/server/src/room/room.lua games/server/tests/test_room.lua
git commit -m "feat(server): add room data model"
```

---

## Task 7: room_mgr.lua service

**Files:**
- Create: `games/server/src/service/room_mgr.lua`

room_mgr 是一个 service 函数，接收 call 消息，管理所有 Room 实例。

- [ ] **Step 1: 实现 `games/server/src/service/room_mgr.lua`**

```lua
local Room = require "room.room"
local log  = require "core.log"

local MAX_PLAYERS_DEFAULT = 8

--- room_mgr service 入口函数
---@param ctx table  scheduler context
local function room_mgr(ctx)
    local rooms    = {}  -- [room_id] = Room
    local next_id  = 1

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
            -- data = {room_id, player}
            local room = rooms[data.room_id]
            if not room then
                ctx:reply(session, nil, "room not found")
            else
                local ok, err = room:add_player(data.player)
                if ok then
                    ctx:reply(session, room:to_info(), room.players)
                else
                    ctx:reply(session, nil, err)
                end
            end

        elseif type == "leave" then
            -- data = {room_id, player_id}
            local room = rooms[data.room_id]
            if room then
                room:remove_player(data.player_id)
                if room:is_empty() then
                    rooms[data.room_id] = nil
                    log.info("room %d destroyed (empty)", data.room_id)
                end
            end
            ctx:reply(session, true)

        elseif type == "list" then
            local list = {}
            for _, room in pairs(rooms) do
                list[#list + 1] = room:to_info()
            end
            ctx:reply(session, list)

        elseif type == "get_room" then
            local room = rooms[data.room_id]
            ctx:reply(session, room)

        elseif type == "snapshot" then
            -- 用于 UI 面板读取状态（不修改状态）
            local list = {}
            for _, room in pairs(rooms) do
                list[#list + 1] = room:to_info()
            end
            ctx:reply(session, list)
        end
    end
end

return room_mgr
```

- [ ] **Step 2: 写 room_mgr 集成测试**

在 `games/server/tests/test_scheduler.lua` 末尾追加（注意文件末尾 `return` 前追加）：

```lua
-- room_mgr 集成测试
local room_mgr = require "service.room_mgr"

t.describe("room_mgr service", function()
    t.it("create and list rooms via call", function()
        local sched = Scheduler.new()
        local mgr_addr = sched:spawn(room_mgr)

        local room_id, results
        sched:spawn(function(ctx)
            room_id = ctx:call(mgr_addr, "create", {room_name = "test", max_players = 4})
            results = ctx:call(mgr_addr, "list", {})
        end)

        for _ = 1, 10 do sched:tick(0) end

        t.assert.eq(room_id, 1)
        t.assert.eq(#results, 1)
        t.assert.eq(results[1].name, "test")
    end)

    t.it("join room returns player list", function()
        local sched = Scheduler.new()
        local mgr_addr = sched:spawn(room_mgr)
        local info, players
        sched:spawn(function(ctx)
            local rid = ctx:call(mgr_addr, "create", {room_name = "x", max_players = 4})
            info, players = ctx:call(mgr_addr, "join", {
                room_id = rid, player = {id = 1, name = "alice"}
            })
        end)
        for _ = 1, 10 do sched:tick(0) end
        t.assert.truthy(info)
        t.assert.eq(#players, 1)
        t.assert.eq(players[1].name, "alice")
    end)
end)
```

- [ ] **Step 3: 运行测试，确认通过**

```bash
make unit-test GAME=server
```

预期：`RESULTS: 31 passed, 0 failed, 0 skipped (31 total)`

- [ ] **Step 4: Commit**

```bash
git add games/server/src/service/room_mgr.lua games/server/tests/test_scheduler.lua
git commit -m "feat(server): add room_mgr service with create/join/leave/list"
```

---

## Task 8: gate.lua + agent.lua

**Files:**
- Create: `games/server/src/service/gate.lua`
- Create: `games/server/src/service/agent.lua`

Gate 监听 TCP 端口，accept 连接，spawn agent。Agent 处理单个客户端的所有消息。

- [ ] **Step 1: 实现 `games/server/src/service/gate.lua`**

```lua
local socket = require "socket"
local log    = require "core.log"

local DEFAULT_PORT    = 12345
local MAX_CONNECTIONS = 4096

--- gate service 入口函数
---@param ctx table
---@param opts {port:integer, room_mgr_addr:integer, on_accept:function|nil}
local function gate(ctx, opts)
    local port         = (opts and opts.port) or DEFAULT_PORT
    local mgr_addr     = opts.room_mgr_addr
    local agent_func   = require "service.agent"

    local server = assert(socket.bind("*", port))
    server:settimeout(0)
    log.info("gate listening on port %d", port)

    -- 存储 server socket 供 scheduler poll（gate 自己轮询 accept）
    local conn_count = 0

    while true do
        -- 尝试 accept 新连接
        local client, err = server:accept()
        if client then
            if conn_count >= MAX_CONNECTIONS then
                log.warn("max connections reached, rejecting")
                client:close()
            else
                conn_count = conn_count + 1
                client:settimeout(0)
                log.info("new connection #%d from %s", conn_count, tostring(client:getpeername()))
                -- spawn agent，传入 raw socket
                ctx:send(ctx.addr, "_spawn_agent", {sock = client, mgr_addr = mgr_addr})
            end
        end

        -- 处理 spawn_agent 请求（自给自足，避免直接在 gate 里引用 scheduler）
        local type, data = ctx:try_recv()
        if type == "_spawn_agent" then
            -- 通过 scheduler 全局接口 spawn agent
            -- gate 需要访问 scheduler，通过 opts 传入
            if opts.scheduler then
                opts.scheduler:spawn(agent_func, {
                    sock       = data.sock,
                    mgr_addr   = data.mgr_addr,
                    on_close   = function() conn_count = conn_count - 1 end,
                })
            end
        end

        coroutine.yield()
    end
end

return gate
```

- [ ] **Step 2: 实现 `games/server/src/service/agent.lua`**

```lua
local protocol = require "core.protocol"
local log      = require "core.log"

local next_player_id = 1

--- agent service 入口函数
---@param ctx table
---@param opts {sock:table, mgr_addr:integer, on_close:function|nil}
local function agent(ctx, opts)
    local cosock   = ctx:bind_socket(opts.sock)
    local mgr_addr = opts.mgr_addr
    local player   = nil   -- {id, name} 登录后设置
    local room_id  = nil   -- 当前所在房间

    local function send_msg(msg)
        cosock:queue_write(protocol.encode(msg))
    end

    local function handle_client_msg(msg)
        local type = msg.type

        if type == "login" then
            player = {id = next_player_id, name = msg.name or ("Player" .. next_player_id)}
            next_player_id = next_player_id + 1
            send_msg({type = "login_ok", player_id = player.id})
            log.info("player %d '%s' logged in", player.id, player.name)

        elseif type == "room_list" then
            local list = ctx:call(mgr_addr, "list", {})
            send_msg({type = "room_list", rooms = list or {}})

        elseif type == "create_room" then
            if not player then
                send_msg({type = "error", message = "not logged in"})
                return
            end
            local rid = ctx:call(mgr_addr, "create", {
                room_name   = msg.room_name,
                max_players = msg.max_players or 8,
            })
            room_id = rid
            -- 加入刚创建的房间
            ctx:call(mgr_addr, "join", {room_id = rid, player = player})
            send_msg({type = "room_created", room_id = rid})

        elseif type == "join_room" then
            if not player then
                send_msg({type = "error", message = "not logged in"})
                return
            end
            local info, players, err = ctx:call(mgr_addr, "join", {
                room_id = msg.room_id, player = player
            })
            if not info then
                send_msg({type = "error", message = err or "join failed"})
            else
                room_id = msg.room_id
                send_msg({type = "room_joined", room_id = room_id, players = players})
                -- 通知房间内其他玩家
                ctx:send(mgr_addr, "broadcast_except", {
                    room_id    = room_id,
                    except_id  = ctx.addr,
                    msg        = {type = "player_joined", player = player},
                })
            end

        elseif type == "leave_room" then
            if room_id then
                ctx:call(mgr_addr, "leave", {room_id = room_id, player_id = player.id})
                ctx:send(mgr_addr, "broadcast_except", {
                    room_id   = room_id,
                    except_id = ctx.addr,
                    msg       = {type = "player_left", player_id = player.id},
                })
                room_id = nil
                send_msg({type = "room_left"})
            end

        elseif type == "room_msg" then
            if room_id and player then
                ctx:send(mgr_addr, "broadcast_except", {
                    room_id   = room_id,
                    except_id = ctx.addr,
                    msg       = {type = "room_msg", from = player.id, data = msg.data},
                })
            end
        end
    end

    -- 主循环
    while not cosock.closed do
        -- 1. 尝试读一条完整客户端消息
        local buf = cosock  -- try_decode 用 cosock 作 buf（cosock 实现了 rbuf 接口）
        -- 为 try_decode 适配：cosock.data = cosock.rbuf
        local proxy = {data = cosock.rbuf}
        local msg = protocol.try_decode(proxy)
        if msg then
            cosock.rbuf = proxy.data
            handle_client_msg(msg)
        end

        -- 2. 处理来自服务端的转发消息（server→client）
        while true do
            local mtype, mdata = ctx:try_recv()
            if not mtype then break end
            if mtype == "forward" then
                send_msg(mdata)
            end
        end

        -- 如果本轮没收到任何数据，yield 等待下次 tick
        if not msg then
            coroutine.yield()
        end
    end

    -- 断线清理
    if player and room_id then
        ctx:call(mgr_addr, "leave", {room_id = room_id, player_id = player.id})
    end
    if player then
        log.info("player %d '%s' disconnected", player.id, player.name)
    end
    ctx:exit()
end

return agent
```

- [ ] **Step 3: 更新 room_mgr，支持 broadcast_except**

在 `games/server/src/service/room_mgr.lua` 的 while 循环中加入处理（在最后一个 `elseif` 之后追加）：

```lua
        elseif type == "broadcast_except" then
            -- data = {room_id, except_id, msg}
            -- 向房间内除 except_id 外的所有 agent 投递 "forward" 消息
            -- 需要房间维护 agent_addr 映射
            -- 注：broadcast 通过 agent_addr_map 查找（在 join 时注册）
            ctx:reply(session, true)
```

注意：要让 room_mgr 能给 agent 发消息，join 时需要传入 `agent_addr`。更新 room_mgr 的 join 处理，保存 `agent_addr`：

```lua
        elseif type == "join" then
            -- data = {room_id, player, agent_addr}
            local room = rooms[data.room_id]
            if not room then
                ctx:reply(session, nil, "room not found")
            else
                local ok, err = room:add_player(data.player)
                if ok then
                    -- 记录 player_id → agent_addr 映射
                    room.agent_addrs = room.agent_addrs or {}
                    room.agent_addrs[data.player.id] = data.agent_addr
                    ctx:reply(session, room:to_info(), room.players)
                else
                    ctx:reply(session, nil, err)
                end
            end
```

同时在 leave 时清理 agent_addrs，broadcast_except 中遍历 room.agent_addrs：

```lua
        elseif type == "broadcast_except" then
            local room = rooms[data.room_id]
            if room and room.agent_addrs then
                for pid, agent_addr in pairs(room.agent_addrs) do
                    if agent_addr ~= data.except_id then
                        ctx:send(agent_addr, "forward", data.msg)
                    end
                end
            end
            ctx:reply(session, true)
```

将上述完整逻辑整合到 `games/server/src/service/room_mgr.lua`（重写文件以保持一致性）：

```lua
local Room = require "room.room"
local log  = require "core.log"

local MAX_PLAYERS_DEFAULT = 8

local function room_mgr(ctx)
    local rooms   = {}
    local next_id = 1

    log.info("room_mgr started at addr=%d", ctx.addr)

    while true do
        local session, type, data = ctx:recv_call()

        if type == "create" then
            local room_name   = (data and data.room_name) or ("Room-" .. next_id)
            local max_players = (data and data.max_players) or MAX_PLAYERS_DEFAULT
            local room = Room.new(next_id, room_name, max_players)
            room.agent_addrs = {}
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
                if room.agent_addrs then
                    room.agent_addrs[data.player_id] = nil
                end
                if room:is_empty() then
                    rooms[data.room_id] = nil
                    log.info("room %d destroyed (empty)", data.room_id)
                end
            end
            ctx:reply(session, true)

        elseif type == "list" then
            local list = {}
            for _, room in pairs(rooms) do
                list[#list + 1] = room:to_info()
            end
            ctx:reply(session, list)

        elseif type == "broadcast_except" then
            local room = rooms[data.room_id]
            if room and room.agent_addrs then
                for pid, agent_addr in pairs(room.agent_addrs) do
                    if agent_addr ~= data.except_id then
                        ctx:send(agent_addr, "forward", data.msg)
                    end
                end
            end
            ctx:reply(session, true)

        elseif type == "snapshot" then
            local list = {}
            for _, room in pairs(rooms) do
                list[#list + 1] = room:to_info()
            end
            ctx:reply(session, list)
        end
    end
end

return room_mgr
```

- [ ] **Step 4: 同步更新 agent.lua 的 join 调用，传入 agent_addr**

在 agent.lua 的 `join_room` 处理中，将 `ctx:call(mgr_addr, "join", ...)` 的 data 加上 `agent_addr = ctx.addr`：

```lua
            local info, players, err = ctx:call(mgr_addr, "join", {
                room_id    = msg.room_id,
                player     = player,
                agent_addr = ctx.addr,
            })
```

- [ ] **Step 5: 运行测试，确认无回归**

```bash
make unit-test GAME=server
```

预期：`RESULTS: 31 passed, 0 failed, 0 skipped (31 total)`

- [ ] **Step 6: Commit**

```bash
git add games/server/src/service/gate.lua
git add games/server/src/service/agent.lua
git add games/server/src/service/room_mgr.lua
git commit -m "feat(server): add gate/agent services and room broadcast"
```

---

## Task 9: main.lua wiring + 功能验证

**Files:**
- Modify: `games/server/main.lua`

- [ ] **Step 1: 重写 `games/server/main.lua`**

```lua
local Scheduler = require "core.scheduler"
local log       = require "core.log"
local gate_func = require "service.gate"
local room_mgr  = require "service.room_mgr"

local sched     = Scheduler.new()
local mgr_addr
local gate_addr
local start_time

function love.load()
    start_time = love.timer.getTime()
    log.info("=== Game Server starting ===")

    mgr_addr  = sched:spawn(room_mgr)
    gate_addr = sched:spawn(gate_func, {
        port         = 12345,
        room_mgr_addr = mgr_addr,
        scheduler    = sched,
    })

    log.info("server ready. mgr=%d gate=%d", mgr_addr, gate_addr)
end

function love.update(dt)
    sched:tick(dt)
end

function love.draw()
    -- panel 在 Task 10 实现，这里先显示基础信息
    local uptime = love.timer.getTime() - start_time
    love.graphics.print(string.format(
        "Game Server | port:12345 | services:%d | uptime:%.1fs",
        sched:service_count(), uptime
    ), 10, 10)

    local entries = log._entries()
    local start = math.max(1, #entries - 20)
    for i = start, #entries do
        local e = entries[i]
        local y = 40 + (i - start) * 16
        love.graphics.print(string.format("[%s] %s", e.level, e.msg), 10, y)
    end
end

-- 优雅退出：关闭 server socket
function love.quit()
    log.info("server shutting down")
end
```

- [ ] **Step 2: 启动服务器**

```bash
make run GAME=server
```

预期：窗口显示服务器状态，控制台输出：
```
[INFO] room_mgr started at addr=1
[INFO] gate listening on port 12345
[INFO] server ready. mgr=1 gate=2
```

- [ ] **Step 3: 用 telnet/nc 验证连接被 accept**

```bash
# 另一个终端
nc localhost 12345
```

预期：控制台输出 `[INFO] new connection #1 from 127.0.0.1`

- [ ] **Step 4: Commit**

```bash
git add games/server/main.lua
git commit -m "feat(server): wire main.lua with scheduler, gate, and room_mgr"
```

---

## Task 10: ui/panel.lua (suit 管理面板)

**Files:**
- Create: `games/server/src/ui/panel.lua`
- Modify: `games/server/main.lua`

- [ ] **Step 1: 实现 `games/server/src/ui/panel.lua`**

```lua
local suit = require "suit"

---@class Panel
---@field sched table      Scheduler 引用
---@field mgr_addr integer room_mgr service 地址
---@field start_time number
---@field selected_room integer|nil
---@field announce_text {text:string}
local Panel = {}
Panel.__index = Panel

function Panel.new(sched, mgr_addr, start_time)
    return setmetatable({
        sched        = sched,
        mgr_addr     = mgr_addr,
        start_time   = start_time,
        selected_room = nil,
        announce_text = {text = ""},
        _room_snapshot = {},
    }, Panel)
end

local COL1, COL2 = 10, 470
local ROW_H = 24
local W1, W2 = 450, 420

function Panel:draw()
    local W, H = love.graphics.getDimensions()
    local uptime = love.timer.getTime() - self.start_time
    local log = require "core.log"

    -- ── 状态栏 ──────────────────────────────────────────
    suit.layout:reset(COL1, 10, 4, 4)
    suit.Label(string.format("Game Server  |  port: 12345  |  services: %d  |  uptime: %.0fs",
        self.sched:service_count(), uptime),
        {align = "left"}, suit.layout:row(W - 20, ROW_H))

    -- ── 左列：房间列表 ──────────────────────────────────
    suit.layout:reset(COL1, 44, 4, 4)
    suit.Label("Rooms", {align = "left"}, suit.layout:row(W1, ROW_H))

    for _, info in ipairs(self._room_snapshot) do
        local label = string.format("[%d] %s  (%d/%d)",
            info.id, info.name, info.count, info.max)
        local btn = suit.Button(label, suit.layout:row(W1, ROW_H))
        if btn.hit then
            self.selected_room = info.id
        end
    end

    -- ── 右列：选中房间玩家 + 操作 ───────────────────────
    suit.layout:reset(COL2, 44, 4, 4)
    suit.Label(self.selected_room
        and ("Room #" .. self.selected_room .. " players")
        or  "Select a room",
        {align = "left"}, suit.layout:row(W2, ROW_H))

    -- ── 广播公告 ─────────────────────────────────────────
    local ay = H - 120
    suit.layout:reset(COL1, ay, 4, 4)
    suit.Label("Announce:", {align = "left"}, suit.layout:row(80, ROW_H))
    suit.layout:reset(COL1 + 84, ay, 4, 4)
    suit.Input(self.announce_text, suit.layout:row(W - 200, ROW_H))
    suit.layout:reset(W - 110, ay, 4, 4)
    local send_btn = suit.Button("Send", suit.layout:row(100, ROW_H))
    if send_btn.hit and #self.announce_text.text > 0 then
        log.info("[ANNOUNCE] %s", self.announce_text.text)
        self.announce_text.text = ""
    end

    -- ── 底部日志 ─────────────────────────────────────────
    local entries = log._entries()
    local log_y = H - 90
    suit.layout:reset(COL1, log_y, 4, 3)
    local start_i = math.max(1, #entries - 4)
    for i = start_i, #entries do
        local e = entries[i]
        local color = e.level == "ERROR" and {1,0.3,0.3,1}
                   or e.level == "WARN"  and {1,0.8,0,1}
                   or {0.8,0.8,0.8,1}
        suit.Label(string.format("[%s] %s", e.level, e.msg),
            {align = "left", color = {normal = {fg = color}}},
            suit.layout:row(W - 20, 16))
    end

    suit.draw()
end

--- 每帧更新（请求 room 快照）
function Panel:update()
    -- 通过 scheduler 发送快照请求给 room_mgr
    -- 由于 panel 在 love.draw() 中运行（不在协程），直接读 sched 内部状态
    -- 只更新每隔 30 帧一次，避免高频 call
    self._tick = (self._tick or 0) + 1
    if self._tick % 30 == 0 then
        -- 直接向 room_mgr mailbox 投递，下一 tick 处理
        self.sched:send(self.mgr_addr, "snapshot", {})
    end
end

return Panel
```

- [ ] **Step 2: 更新 room_mgr 处理 snapshot（不需要 reply，直接存储供 panel 读取）**

由于 panel 不在协程里，无法使用 call/reply。改为 panel 直接读 sched 的内存状态。将 panel:update() 改为：

```lua
function Panel:update(rooms_snapshot)
    if rooms_snapshot then
        self._room_snapshot = rooms_snapshot
    end
end
```

并在 main.lua 的 love.update 中，定期通过 spawn 一个临时协程查询快照：

- [ ] **Step 3: 更新 `games/server/main.lua` 集成 Panel**

```lua
local Scheduler = require "core.scheduler"
local log       = require "core.log"
local gate_func = require "service.gate"
local room_mgr  = require "service.room_mgr"
local Panel     = require "ui.panel"

local sched      = Scheduler.new()
local mgr_addr
local gate_addr
local start_time
local panel
local rooms_cache = {}

function love.load()
    start_time = love.timer.getTime()
    log.info("=== Game Server starting ===")

    mgr_addr  = sched:spawn(room_mgr)
    gate_addr = sched:spawn(gate_func, {
        port          = 12345,
        room_mgr_addr = mgr_addr,
        scheduler     = sched,
    })

    panel = Panel.new(sched, mgr_addr, start_time)
    log.info("server ready. mgr=%d gate=%d", mgr_addr, gate_addr)
end

local snapshot_timer = 0
local SNAPSHOT_INTERVAL = 1.0  -- 每秒刷新一次房间列表

function love.update(dt)
    sched:tick(dt)

    snapshot_timer = snapshot_timer + dt
    if snapshot_timer >= SNAPSHOT_INTERVAL then
        snapshot_timer = 0
        -- 用临时 service 查询房间快照
        sched:spawn(function(ctx)
            local list = ctx:call(mgr_addr, "snapshot", {})
            rooms_cache = list or {}
            ctx:exit()
        end)
    end

    panel:update(rooms_cache)
end

function love.draw()
    panel:draw()
end

function love.mousemoved(x, y)   suit.updateMouse(x, y) end
function love.mousepressed(x, y) suit.updateMouse(x, y, true) end
function love.mousereleased(x,y) suit.updateMouse(x, y, false) end
function love.keypressed(k)      suit.keypressed(k) end
function love.textinput(t)       suit.textinput(t) end

function love.quit()
    log.info("server shutting down")
end
```

- [ ] **Step 4: 启动验证**

```bash
make run GAME=server
```

预期：窗口显示带 suit UI 的管理面板，顶部状态栏、房间列表区域、底部日志区域均正常渲染。

- [ ] **Step 5: Commit**

```bash
git add games/server/src/ui/panel.lua games/server/main.lua
git commit -m "feat(server): add suit management panel with room/log view"
```

---

## 自检：Spec 覆盖确认

| Spec 要求 | 对应 Task |
|-----------|-----------|
| TCP 服务端 | Task 8 gate.lua |
| MessagePack 序列化 | Task 1 + Task 3 |
| 4 字节长度前缀分帧 | Task 3 protocol.lua |
| 4096+ 并发（非阻塞轮询）| Task 4 cosocket.lua + Task 5 scheduler.lua |
| Service/Actor 模型（Skynet）| Task 5 scheduler.lua |
| cosocket 封装（OpenResty）| Task 4 cosocket.lua |
| gate + agent 职责分离 | Task 8 |
| room_mgr service | Task 7 |
| room 实例 | Task 6 |
| send/call/reply 消息通信 | Task 5 scheduler.lua |
| suit 管理面板 | Task 10 |
| headless 支持 | conf.lua 注释说明 |
| login/create/join/leave/list/msg 协议 | Task 8 agent.lua |

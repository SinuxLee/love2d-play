# Game Room Server Design

## Overview

基于 Love2D 的通用游戏房间服务器，借鉴 Skynet（Actor/Service 模型）和 OpenResty（cosocket 协程封装）的设计思想，用纯 Lua 协程实现高并发非阻塞架构。

- **传输层**：luasocket TCP 非阻塞
- **序列化**：MessagePack（`kengonakajima/lua-msgpack`，submodule）
- **并发模型**：协程驱动的 Service/Actor 模型，支持 4096+ 并发连接
- **管理面板**：suit 即时模式 GUI，可选 headless

## Core Concepts（借鉴 Skynet / OpenResty）

### 1. Service（借鉴 Skynet Actor）

Service 是最小调度单元，每个 service 拥有：

- **独立协程**：service 的生命周期就是一个协程的生命周期
- **消息邮箱（mailbox）**：其他 service 通过 `send(addr, ...)` 投递消息，不直接调用函数
- **唯一地址（addr）**：整数 ID，全局寻址

```lua
-- 定义一个 service
local function agent(ctx)
    local msg = ctx:recv()          -- 从邮箱取消息，无消息时 yield
    ctx:send(other_addr, "hello")   -- 向另一个 service 投递消息
    ctx:call(other_addr, "rpc_req") -- send + recv 组合，同步风格的 RPC
end
```

与 Skynet 的区别：Skynet 是多线程 + Lua VM pool，这里是单线程 + 协程调度，更轻量。

### 2. Cosocket（借鉴 OpenResty）

对 luasocket 的协程封装，让网络 I/O 看起来像同步调用，底层自动 yield/resume：

```lua
-- cosocket 封装后的 API
local data, err = cosocket:receive(n)   -- 读 n 字节，不足则 yield 等待
local ok, err = cosocket:send(data)     -- 写数据，缓冲区满则 yield
cosocket:close()
```

实现要点：
- 底层 socket 设为 `settimeout(0)` 非阻塞
- `receive()` 尝试读取，返回 "timeout" 则 yield，调度器在下一轮 tick 检测到有数据时 resume
- `send()` 尝试写入，写不完则保存剩余数据，yield 等下一轮继续写
- 每个 cosocket 关联一个读缓冲区，处理 TCP 粘包

### 3. Scheduler（调度器）

中央调度器，驱动所有 service 和 cosocket：

```
每个 love.update(dt) tick:
  1. accept 新连接 → 创建 cosocket → 启动 agent service
  2. 遍历所有活跃 cosocket，非阻塞 recv
     - 有数据 → 追加到 cosocket 读缓冲区，标记对应 service 可唤醒
  3. 遍历所有 pending write 的 cosocket，尝试 flush
  4. 遍历所有有消息待处理的 service mailbox，resume 对应协程
  5. 清理已关闭的连接和 service
```

## Architecture

```
games/server/
├── conf.lua
├── main.lua
└── src/
    ├── core/
    │   ├── scheduler.lua    -- 调度器：驱动协程 + I/O 轮询
    │   ├── service.lua      -- Service 基类：邮箱、地址、生命周期
    │   ├── cosocket.lua     -- 协程 socket 封装
    │   ├── protocol.lua     -- 消息分帧：4字节大端长度 + msgpack payload
    │   └── log.lua          -- 日志模块（带时间戳、级别）
    ├── service/
    │   ├── gate.lua         -- 网关 service：监听端口、accept、分配 agent
    │   ├── agent.lua        -- 客户端代理 service：每连接一个，处理协议消息
    │   └── room_mgr.lua     -- 房间管理 service：创建/销毁/查询房间
    ├── room/
    │   └── room.lua         -- 房间实例（也是 service）：玩家列表、广播
    └── ui/
        └── panel.lua        -- suit 管理面板
```

### Service 职责

| Service | 数量 | 职责 |
|---------|------|------|
| **gate** | 1 | 监听 TCP 端口，accept 新连接，为每个连接创建 agent |
| **agent** | 每连接 1 个 | 持有 cosocket，解析协议，执行客户端请求（login/join/leave/msg） |
| **room_mgr** | 1 | 管理所有房间的生命周期，处理 create/destroy/list |
| **room** | 每房间 1 个 | 维护房间内玩家列表，转发房间内广播消息 |

### Service 间通信

借鉴 Skynet 的消息传递，service 之间不直接调用方法，而是通过 mailbox 投递消息：

```
Client TCP → [gate] accept → spawn [agent]
[agent] recv "create_room" → send [room_mgr] "create" → [room_mgr] spawn [room]
[agent] recv "join_room"   → send [room_mgr] "join"   → [room_mgr] send [room] "add_player"
[agent] recv "room_msg"    → send [room] "broadcast"   → [room] send each [agent] "forward"
[agent] disconnect         → send [room] "remove_player" → cleanup
```

### Scheduler 内部结构

```lua
---@class Scheduler
---@field services table<integer, Service>     -- addr → service
---@field cosockets table<integer, Cosocket>   -- fd → cosocket
---@field next_addr integer                     -- 地址分配器
local Scheduler = {}

-- 核心方法
Scheduler:spawn(func, ...)       -- 创建 service，返回 addr
Scheduler:send(addr, ...)        -- 向 service 邮箱投递消息
Scheduler:call(addr, ...)        -- send + 等待回复（同步 RPC 语义）
Scheduler:kill(addr)             -- 销毁 service
Scheduler:bindSocket(addr, sock) -- 将 cosocket 绑定到 service
Scheduler:tick(dt)               -- 每帧调用，驱动整个系统
```

## Message Protocol

### 帧格式

```
+----------------+--------------------+
| 4 bytes length | msgpack payload    |
| (big-endian)   |                    |
+----------------+--------------------+
```

length 不包含自身的 4 字节。最大单帧 16MB。

### 消息定义

所有消息为 msgpack 编码的 table，必须包含 `type` 字段。

**Client → Server:**

| type | 字段 | 说明 |
|------|------|------|
| `login` | `name` | 登录，设置玩家名 |
| `create_room` | `room_name`, `max_players` | 创建房间 |
| `join_room` | `room_id` | 加入房间 |
| `leave_room` | — | 离开当前房间 |
| `room_list` | — | 请求房间列表 |
| `room_msg` | `data` (any table) | 房间内广播，data 为任意业务数据 |

**Server → Client:**

| type | 字段 | 说明 |
|------|------|------|
| `login_ok` | `player_id` | 登录成功 |
| `room_created` | `room_id` | 房间已创建 |
| `room_joined` | `room_id`, `players` | 加入成功，附带当前玩家列表 |
| `room_left` | — | 已离开房间 |
| `room_list` | `rooms` [{id, name, count, max}] | 房间列表 |
| `room_msg` | `from`, `data` | 房间广播消息 |
| `player_joined` | `player` {id, name} | 有人加入房间 |
| `player_left` | `player_id` | 有人离开房间 |
| `error` | `message` | 错误信息 |

## Capacity

| 项 | 值 |
|----|----|
| 最大连接数 | 4096（配置项） |
| 非阻塞策略 | `settimeout(0)` + 遍历轮询，无 select FD_SETSIZE 限制 |
| 协程开销 | ~2-4KB/协程，4096 agent + room ≈ ~20MB |
| Service 总数 | 1 gate + 1 room_mgr + N agents + M rooms |
| 消息投递 | 同帧内投递，同帧内处理（零延迟） |
| 读缓冲区 | 每 cosocket 独立 buffer |
| 最大帧大小 | 16MB |

## UI: Management Panel (suit)

使用 suit 即时模式 GUI。headless 模式下（`t.modules.window = false`）跳过所有 UI 代码。

| 区域 | 内容 | suit 组件 |
|------|------|----------|
| 顶部状态栏 | 端口、在线数、房间数、运行时长 | `suit.Label` |
| 房间列表 | ID、名称、人数/上限，点击选中 | `suit.Label` + `suit.Button` |
| 玩家列表 | 选中房间后显示房间内玩家 | `suit.Label` |
| 操作按钮 | 踢人、关闭房间、广播公告 | `suit.Button` |
| 底部日志 | 最近日志滚动显示 | `suit.Label` 列表 |

## conf.lua 配置

```lua
t.window.title = "Game Server"
t.window.width = 900
t.window.height = 600

-- 服务器不需要的模块全部关闭
t.modules.audio = false
t.modules.joystick = false
t.modules.physics = false
t.modules.sound = false
t.modules.touch = false
t.modules.video = false
-- headless 模式下额外关闭:
-- t.modules.window = false
-- t.modules.graphics = false
-- t.modules.font = false
```

## Vendor Dependencies

| 库 | 来源 | 用途 |
|----|------|------|
| lua-msgpack | `kengonakajima/lua-msgpack` (submodule) | 消息序列化 |
| suit | 已有 vendor | 管理面板 GUI |
| luasocket | Love2D 内置 | TCP 网络 |

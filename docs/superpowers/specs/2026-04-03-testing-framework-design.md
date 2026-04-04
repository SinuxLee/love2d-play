# Testing Framework Design

Love2D monorepo 单元测试与集成测试框架设计。

## Goals

1. Coding agent 修改代码后一条命令验证正确性（`make test GAME=xxx`）
2. 支持 TDD 工作流（先写测试再写实现）
3. 零外部依赖，git clone 后开箱即用
4. 单元测试用纯 `lua` 跑（快），集成测试用 Love2D headless 跑（可用 `love.physics`）

## Architecture

两层架构：

- **测试库** (`shared/testing/`) — describe/it/assert API + 测试发现执行引擎
- **集成测试 runner** (`shared/testing/love_runner/`) — 微型 Love2D 项目，headless 模式运行集成测试

### 文件结构

```
shared/testing/
  init.lua                  -- API 入口 (describe/it/assert)
  runner.lua                -- 测试发现与执行
  assertions.lua            -- 断言库
  mock.lua                  -- spy/stub
  love_stub.lua             -- 单元测试用的 love 空壳
  love_runner/
    conf.lua                -- headless Love2D 配置
    main.lua                -- 集成测试执行入口
```

### 测试目录约定

每个游戏内 `tests/` 目录：

```
games/<name>/tests/
  test_*.lua           -- 单元测试（纯 Lua，无 love.* 依赖）
  integration_*.lua    -- 集成测试（需要 Love2D headless）
```

## Testing Library API

### describe / it

```lua
local t = require "testing"

t.describe("Player movement", function()
    t.it("normalizes diagonal movement", function()
        local dx, dy = normalize(1, 1)
        t.assert.near(dx, 0.7071, 0.001)
    end)
end)
```

### Assertions

| 断言 | 说明 |
|------|------|
| `assert.eq(a, b)` | 相等（深比较） |
| `assert.neq(a, b)` | 不等 |
| `assert.near(a, b, tol)` | 浮点近似 |
| `assert.truthy(v)` | 真值 |
| `assert.falsy(v)` | 假值 |
| `assert.errors(fn)` | 期望抛错 |
| `assert.contains(str, pat)` | 字符串包含 |
| `assert.type(v, name)` | 类型检查 |
| `assert.vec_near(a, b, tol)` | 向量近似 `{x, y}` |
| `assert.match(tbl, partial)` | 表部分匹配 |

### Mock

```lua
local mock = require "testing.mock"

-- spy: 记录调用
local fn = mock.spy()
fn(1, 2)
t.assert.eq(fn.calls[1], {1, 2})
t.assert.eq(fn.call_count, 1)

-- stub: 替换对象方法，返回恢复函数
local restore = mock.stub(obj, "method", function() return 42 end)
restore()
```

### Output Format

```
[PASS] Player movement > normalizes diagonal movement
[PASS] Player movement > clamps to max speed
[FAIL] Collision > detects wall collision
  assertions.lua:23: expected 'true', got 'false'
  stack traceback: ...

RESULTS: 2 passed, 1 failed, 0 skipped (3 total)
```

最后一行 `RESULTS:` 为固定格式，agent 可正则匹配。退出码：0=全通过，1=有失败。

## Runner Modes

### 单元测试（纯 Lua）

```bash
lua shared/testing/runner.lua games/<name>/tests/
```

runner.lua 负责：
1. 设置 `package.path`（复用 monorepo 路径约定）
2. 递归发现 `test_*.lua` 文件
3. 依次 `dofile` 执行
4. 汇总结果输出

### 集成测试（Love2D headless）

```bash
love shared/testing/love_runner --game=<name>
```

`love_runner/conf.lua` 关闭图形：
```lua
function love.conf(t)
    t.window = nil
    t.modules.audio = false
    t.modules.sound = false
    t.modules.joystick = false
end
```

可使用 `love.physics` 但不创建窗口。

`love_runner/main.lua` 通过 `arg` 表获取 `--game=<name>` 参数，拼出测试目录绝对路径，扫描 `integration_*.lua` 文件并执行。它使用 `love.filesystem.getSource()` 定位自身，再向上推导 monorepo 根目录来设置 `package.path`。

### Love stub（单元测试用）

`shared/testing/love_stub.lua` 提供 love 空壳，让 require 链不断：

```lua
love = love or {}
love.graphics = love.graphics or setmetatable({}, {
    __index = function() return function() end end
})
```

原则：stub 只防 require 报错。测 love.physics 行为用集成测试，不 mock。

## Makefile Targets

```makefile
test:              GAME=<name>  # 全部（单元+集成）
unit-test:         GAME=<name>  # 只跑 test_*.lua
integration-test:  GAME=<name>  # 只跑 integration_*.lua
test-all:                       # 遍历所有游戏跑全部测试
```

## Per-Game Test Strategy

### physics-testbed（最高优先级）

**单元测试：**
- `test_camera.lua` — 世界/屏幕坐标互转、缩放、拖拽平移
- `test_scenes.lua` — 各 scene setup 返回正确的 body/joint 数量
- `test_cut_the_rope.lua` — 线段相交算法

**集成测试：**
- `integration_physics.lua` — 真实 world 的重力、碰撞、关节约束
- `integration_testbed.lua` — scene 切换后 world 正确重建、暂停/恢复

### blocks（俄罗斯方块）

需先重构：从 `main.lua` 提取逻辑到 `src/grid.lua`、`src/pieces.lua`、`src/sequence.lua`。

**单元测试：**
- `test_grid.lua` — `canPieceMove()` 碰撞检测、旋转校验
- `test_clearing.lua` — 行消除、行下移
- `test_sequence.lua` — 方块随机序列

### template

**单元测试：**
- `test_player.lua` — 对角归一化、速度、位置更新
- `test_input.lua` — 按键状态转换

### water

需先重构：从 `main.lua` 提取逻辑到 `src/particle.lua`。

**单元测试：**
- `test_particle.lua` — 粘性混合、边界碰撞、生成速率

### demo1 / shader

暂不添加测试（代码极少且强依赖图形）。

## Refactoring Principle

对 blocks 和 water 这类所有逻辑在 main.lua 的项目：
1. 将可测试的纯逻辑提取到 `src/` 下的模块
2. `main.lua` 只负责调用模块 + Love2D 回调胶水
3. 保持游戏行为完全不变

## CLAUDE.md Updates

新增以下内容到 CLAUDE.md：

```markdown
## Testing

make test GAME=<name>              # Run all tests (unit + integration)
make unit-test GAME=<name>         # Run unit tests only (pure Lua)
make integration-test GAME=<name>  # Run integration tests (Love2D headless)
make test-all                      # Run all tests for all games

Test file conventions:
- tests/test_*.lua        → unit tests (pure Lua, no love.* dependency)
- tests/integration_*.lua → integration tests (needs Love2D)

Exit code: 0 = all passed, 1 = failures exist.
```

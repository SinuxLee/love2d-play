# Testing Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a zero-dependency unit test + integration test framework to the Love2D monorepo, enabling `make test GAME=xxx` for coding agents.

**Architecture:** Two-layer — a pure-Lua test library (`shared/testing/`) with describe/it/assert API, plus a Love2D headless runner for integration tests using `love.physics`. Unit tests run via `luajit`, integration tests via Love2D with no window.

**Tech Stack:** Lua (LuaJIT 2.0.5 compatible), Love2D 11.4 headless mode, GNU Make

**Compatibility note:** All test framework code must work with both LuaJIT (Lua 5.1) and Lua 5.4. Use `table.insert`/`table.remove` instead of `table.unpack` where needed. Use `unpack or table.unpack` for compatibility.

---

## File Structure

**New files to create:**

```
shared/testing/init.lua              -- API entry: exports describe, it, assert, run, reset
shared/testing/assertions.lua        -- Assertion functions
shared/testing/mock.lua              -- spy/stub utilities
shared/testing/love_stub.lua         -- Minimal love.* stubs for unit tests
shared/testing/runner.lua            -- CLI test discovery & execution script
shared/testing/love_runner/conf.lua  -- Headless Love2D config
shared/testing/love_runner/main.lua  -- Integration test execution entry

shared/testing/tests/test_assertions.lua  -- Self-tests for assertions
shared/testing/tests/test_mock.lua        -- Self-tests for mock

games/template/tests/test_input.lua       -- Input state tests
games/template/tests/test_player.lua      -- Player movement tests

games/physics-testbed/tests/test_camera.lua        -- Camera transforms
games/physics-testbed/tests/test_cut_the_rope.lua  -- Segment intersection
games/physics-testbed/tests/integration_physics.lua -- Physics world tests

games/blocks/src/grid.lua            -- Extracted grid logic
games/blocks/src/pieces.lua          -- Extracted piece data
games/blocks/tests/test_grid.lua     -- Grid collision & clearing tests

games/water/src/particle.lua         -- Extracted particle physics
games/water/tests/test_particle.lua  -- Particle physics tests
```

**Files to modify:**

```
Makefile                             -- Add test/unit-test/integration-test/test-all targets
CLAUDE.md                            -- Add testing section
games/blocks/main.lua                -- Require extracted modules instead of inline
games/blocks/conf.lua                -- Add src/ to package.path
games/water/main.lua                 -- Require extracted modules instead of inline
games/water/conf.lua                 -- Add src/ to package.path
```

---

### Task 1: Assertions Library

**Files:**
- Create: `shared/testing/assertions.lua`

- [ ] **Step 1: Create assertions.lua**

```lua
-- shared/testing/assertions.lua
local assertions = {}

local unpack = unpack or table.unpack

local function deep_equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not deep_equal(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function format_val(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts + 1] = tostring(k) .. "=" .. format_val(val)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function fail(msg)
    error(msg, 3)
end

function assertions.eq(a, b)
    if not deep_equal(a, b) then
        fail("expected " .. format_val(a) .. " == " .. format_val(b))
    end
end

function assertions.neq(a, b)
    if deep_equal(a, b) then
        fail("expected values to differ, both are " .. format_val(a))
    end
end

function assertions.near(a, b, tol)
    tol = tol or 0.0001
    if type(a) ~= "number" or type(b) ~= "number" then
        fail("assert.near requires numbers, got " .. type(a) .. " and " .. type(b))
    end
    if math.abs(a - b) > tol then
        fail("expected |" .. a .. " - " .. b .. "| <= " .. tol .. ", got " .. math.abs(a - b))
    end
end

function assertions.truthy(v)
    if not v then
        fail("expected truthy, got " .. format_val(v))
    end
end

function assertions.falsy(v)
    if v then
        fail("expected falsy, got " .. format_val(v))
    end
end

function assertions.errors(fn)
    local ok = pcall(fn)
    if ok then
        fail("expected function to error, but it succeeded")
    end
end

function assertions.contains(str, pattern)
    if type(str) ~= "string" then
        fail("assert.contains expects string, got " .. type(str))
    end
    if not string.find(str, pattern, 1, true) then
        fail("expected " .. format_val(str) .. " to contain " .. format_val(pattern))
    end
end

function assertions.type(v, expected)
    local actual = type(v)
    if actual ~= expected then
        fail("expected type " .. format_val(expected) .. ", got " .. format_val(actual))
    end
end

function assertions.vec_near(a, b, tol)
    tol = tol or 0.0001
    local ax, ay = a.x or a[1], a.y or a[2]
    local bx, by = b.x or b[1], b.y or b[2]
    if math.abs(ax - bx) > tol or math.abs(ay - by) > tol then
        fail("expected vec(" .. ax .. "," .. ay .. ") near vec(" .. bx .. "," .. by .. "), tol=" .. tol)
    end
end

function assertions.match(tbl, partial)
    if type(tbl) ~= "table" or type(partial) ~= "table" then
        fail("assert.match requires tables")
    end
    for k, v in pairs(partial) do
        if not deep_equal(tbl[k], v) then
            fail("key " .. format_val(k) .. ": expected " .. format_val(v) .. ", got " .. format_val(tbl[k]))
        end
    end
end

return assertions
```

- [ ] **Step 2: Verify file was created**

Run: `luajit -e "local a = dofile('shared/testing/assertions.lua'); print(type(a.eq))"`
Expected: `function`

- [ ] **Step 3: Commit**

```bash
git add shared/testing/assertions.lua
git commit -m "feat: add assertions library for test framework"
```

---

### Task 2: Test Framework Core (describe/it)

**Files:**
- Create: `shared/testing/init.lua`

- [ ] **Step 1: Create init.lua**

```lua
-- shared/testing/init.lua
local assertions = require "testing.assertions"

local testing = {}
testing.assert = assertions

local results = {passed = 0, failed = 0, skipped = 0, errors = {}}
local context_stack = {}

function testing.reset()
    results = {passed = 0, failed = 0, skipped = 0, errors = {}}
    context_stack = {}
end

local function full_name(name)
    local parts = {}
    for _, ctx in ipairs(context_stack) do
        parts[#parts + 1] = ctx
    end
    parts[#parts + 1] = name
    return table.concat(parts, " > ")
end

function testing.describe(name, fn)
    context_stack[#context_stack + 1] = name
    fn()
    context_stack[#context_stack] = nil
end

function testing.it(name, fn)
    local test_name = full_name(name)
    local ok, err = xpcall(fn, function(e)
        return e .. "\n" .. debug.traceback("", 2)
    end)
    if ok then
        results.passed = results.passed + 1
        print("[PASS] " .. test_name)
    else
        results.failed = results.failed + 1
        print("[FAIL] " .. test_name)
        print("  " .. tostring(err))
        results.errors[#results.errors + 1] = {name = test_name, err = err}
    end
end

function testing.get_results()
    return results
end

function testing.print_summary()
    local total = results.passed + results.failed + results.skipped
    print("")
    print(string.format("RESULTS: %d passed, %d failed, %d skipped (%d total)",
        results.passed, results.failed, results.skipped, total))
    return results.failed == 0
end

return testing
```

- [ ] **Step 2: Verify it loads**

Run: `cd /Users/centurygame/work/love2d-play && luajit -e "package.path='shared/?.lua;shared/?/init.lua;'..package.path; local t = require 'testing'; print(type(t.describe))"`
Expected: `function`

- [ ] **Step 3: Commit**

```bash
git add shared/testing/init.lua
git commit -m "feat: add test framework core with describe/it/assert"
```

---

### Task 3: Mock Library

**Files:**
- Create: `shared/testing/mock.lua`

- [ ] **Step 1: Create mock.lua**

```lua
-- shared/testing/mock.lua
local mock = {}

function mock.spy(base_fn)
    local s = {calls = {}, call_count = 0}
    setmetatable(s, {__call = function(self, ...)
        self.call_count = self.call_count + 1
        local args = {...}
        self.calls[self.call_count] = args
        if base_fn then
            return base_fn(...)
        end
    end})
    return s
end

function mock.stub(obj, method_name, replacement)
    local original = obj[method_name]
    obj[method_name] = replacement or function() end
    return function()
        obj[method_name] = original
    end
end

return mock
```

- [ ] **Step 2: Verify it loads**

Run: `cd /Users/centurygame/work/love2d-play && luajit -e "package.path='shared/?.lua;shared/?/init.lua;'..package.path; local m = require 'testing.mock'; local s = m.spy(); s(1,2); print(s.call_count)"`
Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add shared/testing/mock.lua
git commit -m "feat: add mock library with spy/stub"
```

---

### Task 4: Love Stub

**Files:**
- Create: `shared/testing/love_stub.lua`

- [ ] **Step 1: Create love_stub.lua**

```lua
-- shared/testing/love_stub.lua
-- Minimal love.* stubs so that unit tests can require game modules
-- that reference love.* at load time without crashing.
-- This does NOT simulate any real behavior — use integration tests for love.physics etc.

local function noop() end
local function noop_module()
    return setmetatable({}, {__index = function() return noop end})
end

love = love or {}
love.graphics = love.graphics or noop_module()
love.keyboard = love.keyboard or noop_module()
love.mouse = love.mouse or noop_module()
love.window = love.window or noop_module()
love.audio = love.audio or noop_module()
love.filesystem = love.filesystem or noop_module()
love.timer = love.timer or noop_module()
love.event = love.event or noop_module()
love.math = love.math or setmetatable({}, {
    __index = function(_, k)
        if k == "random" then return math.random end
        return noop
    end
})

-- love.graphics.getDimensions stub returning a sensible default
local lg = love.graphics
local mt = getmetatable(lg)
if mt then
    local old_index = mt.__index
    mt.__index = function(self, k)
        if k == "getDimensions" then return function() return 800, 600 end end
        if k == "getWidth" then return function() return 800 end end
        if k == "getHeight" then return function() return 600 end end
        if type(old_index) == "function" then return old_index(self, k) end
        return old_index[k]
    end
end
```

- [ ] **Step 2: Verify it loads**

Run: `cd /Users/centurygame/work/love2d-play && luajit -e "dofile('shared/testing/love_stub.lua'); local w,h = love.graphics.getDimensions(); print(w,h)"`
Expected: `800	600`

- [ ] **Step 3: Commit**

```bash
git add shared/testing/love_stub.lua
git commit -m "feat: add love stub for unit test compatibility"
```

---

### Task 5: Test Runner (CLI)

**Files:**
- Create: `shared/testing/runner.lua`

- [ ] **Step 1: Create runner.lua**

```lua
#!/usr/bin/env luajit
-- shared/testing/runner.lua
-- Unit test runner: discovers and executes test_*.lua files
-- Usage: luajit shared/testing/runner.lua <test_dir> [game_src_dir]

local test_dir = arg[1]
local game_src_dir = arg[2]

if not test_dir then
    io.stderr:write("Usage: luajit shared/testing/runner.lua <test_dir> [game_src_dir]\n")
    os.exit(1)
end

-- Determine monorepo root (runner.lua lives in shared/testing/)
local script_path = arg[0]
local root = script_path:match("^(.-)shared/testing/runner%.lua$") or "./"

-- Set up package.path to mirror monorepo convention
package.path = root .. "shared/?.lua;"
    .. root .. "shared/?/init.lua;"
    .. root .. "vendor/?.lua;"
    .. root .. "vendor/?/init.lua;"
    .. package.path

-- Add game src dir if provided
if game_src_dir then
    package.path = game_src_dir .. "/?.lua;"
        .. game_src_dir .. "/?/init.lua;"
        .. package.path
end

-- Load love stubs before any game code
dofile(root .. "shared/testing/love_stub.lua")

-- Load testing framework
local testing = require "testing"

-- Discover test files
local function discover_tests(dir, pattern)
    local files = {}
    local handle = io.popen('find "' .. dir .. '" -name "' .. pattern .. '" -type f 2>/dev/null | sort')
    if handle then
        for line in handle:lines() do
            files[#files + 1] = line
        end
        handle:close()
    end
    return files
end

local files = discover_tests(test_dir, "test_*.lua")

if #files == 0 then
    print("No test files found in " .. test_dir)
    print("")
    print("RESULTS: 0 passed, 0 failed, 0 skipped (0 total)")
    os.exit(0)
end

-- Run each test file
for _, file in ipairs(files) do
    print("--- " .. file .. " ---")
    local fn, err = loadfile(file)
    if fn then
        local ok, run_err = xpcall(fn, function(e)
            return e .. "\n" .. debug.traceback("", 2)
        end)
        if not ok then
            print("[ERROR] " .. file .. ": " .. tostring(run_err))
        end
    else
        print("[ERROR] " .. file .. ": " .. tostring(err))
    end
end

-- Summary
local passed = testing.print_summary()
os.exit(passed and 0 or 1)
```

- [ ] **Step 2: Verify runner works with no tests**

Run: `cd /Users/centurygame/work/love2d-play && mkdir -p /tmp/empty_tests && luajit shared/testing/runner.lua /tmp/empty_tests`
Expected output containing: `RESULTS: 0 passed, 0 failed, 0 skipped (0 total)`

- [ ] **Step 3: Commit**

```bash
git add shared/testing/runner.lua
git commit -m "feat: add CLI test runner with test discovery"
```

---

### Task 6: Love2D Integration Test Runner

**Files:**
- Create: `shared/testing/love_runner/conf.lua`
- Create: `shared/testing/love_runner/main.lua`

- [ ] **Step 1: Create love_runner/conf.lua**

```lua
-- shared/testing/love_runner/conf.lua
-- Headless Love2D configuration for integration tests

do
    local source = love.filesystem.getSource()
    -- love_runner is in shared/testing/love_runner/, root is 3 levels up
    local root = source .. "/../../../"
    package.path = root .. "shared/?.lua;"
        .. root .. "shared/?/init.lua;"
        .. root .. "vendor/?.lua;"
        .. root .. "vendor/?/init.lua;"
        .. package.path
end

function love.conf(t)
    t.version = "11.4"
    t.window = nil  -- no window
    t.modules.audio = false
    t.modules.sound = false
    t.modules.joystick = false
    t.modules.video = false
    t.modules.image = false
    t.modules.font = false
    t.modules.graphics = false
    t.modules.window = false
    t.modules.physics = true
    t.modules.math = true
    t.modules.data = true
    t.modules.timer = true
    t.modules.event = true
    t.modules.system = true
end
```

- [ ] **Step 2: Create love_runner/main.lua**

```lua
-- shared/testing/love_runner/main.lua
-- Integration test runner for Love2D headless mode
-- Usage: love shared/testing/love_runner --game=<name>

local testing = require "testing"

local function parse_args()
    local game_name = nil
    for _, v in ipairs(arg) do
        local name = v:match("^%-%-game=(.+)$")
        if name then game_name = name end
    end
    return game_name
end

local function get_root()
    local source = love.filesystem.getSource()
    -- source is shared/testing/love_runner, root is 3 levels up
    return source .. "/../../../"
end

local function discover_tests(dir, pattern)
    local files = {}
    local handle = io.popen('find "' .. dir .. '" -name "' .. pattern .. '" -type f 2>/dev/null | sort')
    if handle then
        for line in handle:lines() do
            files[#files + 1] = line
        end
        handle:close()
    end
    return files
end

function love.load()
    local game_name = parse_args()
    if not game_name then
        io.stderr:write("Usage: love shared/testing/love_runner --game=<name>\n")
        love.event.quit(1)
        return
    end

    local root = get_root()
    local game_dir = root .. "games/" .. game_name
    local test_dir = game_dir .. "/tests"

    -- Add game src to package.path
    package.path = game_dir .. "/src/?.lua;"
        .. game_dir .. "/src/?/init.lua;"
        .. package.path

    local files = discover_tests(test_dir, "integration_*.lua")

    if #files == 0 then
        print("No integration test files found in " .. test_dir)
        print("")
        print("RESULTS: 0 passed, 0 failed, 0 skipped (0 total)")
        love.event.quit(0)
        return
    end

    for _, file in ipairs(files) do
        print("--- " .. file .. " ---")
        local fn, err = loadfile(file)
        if fn then
            local ok, run_err = xpcall(fn, function(e)
                return e .. "\n" .. debug.traceback("", 2)
            end)
            if not ok then
                print("[ERROR] " .. file .. ": " .. tostring(run_err))
            end
        else
            print("[ERROR] " .. file .. ": " .. tostring(err))
        end
    end

    local passed = testing.print_summary()
    love.event.quit(passed and 0 or 1)
end
```

- [ ] **Step 3: Commit**

```bash
git add shared/testing/love_runner/conf.lua shared/testing/love_runner/main.lua
git commit -m "feat: add Love2D headless integration test runner"
```

---

### Task 7: Makefile Targets

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add test targets to Makefile**

Add the following after the existing `list` target. The `LUA_CMD` prefers luajit for LuaJIT/Love2D compatibility:

```makefile
LUA_CMD ?= luajit
ifeq ($(shell which luajit 2>/dev/null),)
	LUA_CMD := lua
endif

test:
ifndef GAME
	$(error Usage: make test GAME=<game_name>)
endif
	@$(MAKE) unit-test GAME=$(GAME)
	@$(MAKE) integration-test GAME=$(GAME)

unit-test:
ifndef GAME
	$(error Usage: make unit-test GAME=<game_name>)
endif
	@$(LUA_CMD) shared/testing/runner.lua games/$(GAME)/tests games/$(GAME)/src

integration-test:
ifndef GAME
	$(error Usage: make integration-test GAME=<game_name>)
endif
	@$(LOVE_CMD) shared/testing/love_runner --game=$(GAME)

test-all:
	@failed=0; \
	for game in $$(ls -1 games/ | grep -v '\.gitkeep'); do \
		if [ -d "games/$$game/tests" ]; then \
			echo "=== Testing $$game ==="; \
			$(MAKE) test GAME=$$game || failed=1; \
			echo ""; \
		fi; \
	done; \
	exit $$failed
```

- [ ] **Step 2: Update .PHONY**

Change the existing `.PHONY` line from:
```makefile
.PHONY: run pack new update-submodules list
```
to:
```makefile
.PHONY: run pack new update-submodules list test unit-test integration-test test-all
```

- [ ] **Step 3: Verify make targets are recognized**

Run: `cd /Users/centurygame/work/love2d-play && make -n unit-test GAME=template 2>&1 | head -3`
Expected: should show the luajit command, not an error about missing target

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "feat: add test/unit-test/integration-test/test-all make targets"
```

---

### Task 8: Self-Tests for the Framework

**Files:**
- Create: `shared/testing/tests/test_assertions.lua`
- Create: `shared/testing/tests/test_mock.lua`

- [ ] **Step 1: Create test_assertions.lua**

```lua
-- shared/testing/tests/test_assertions.lua
local t = require "testing"

t.describe("assertions.eq", function()
    t.it("passes for equal numbers", function()
        t.assert.eq(1, 1)
    end)

    t.it("passes for equal strings", function()
        t.assert.eq("hello", "hello")
    end)

    t.it("passes for deep-equal tables", function()
        t.assert.eq({1, {2, 3}}, {1, {2, 3}})
    end)

    t.it("fails for different values", function()
        t.assert.errors(function()
            t.assert.eq(1, 2)
        end)
    end)
end)

t.describe("assertions.neq", function()
    t.it("passes for different values", function()
        t.assert.neq(1, 2)
    end)

    t.it("fails for equal values", function()
        t.assert.errors(function()
            t.assert.neq(1, 1)
        end)
    end)
end)

t.describe("assertions.near", function()
    t.it("passes within tolerance", function()
        t.assert.near(1.0, 1.0001, 0.001)
    end)

    t.it("fails outside tolerance", function()
        t.assert.errors(function()
            t.assert.near(1.0, 2.0, 0.001)
        end)
    end)
end)

t.describe("assertions.truthy/falsy", function()
    t.it("truthy passes for true", function()
        t.assert.truthy(true)
    end)

    t.it("truthy passes for non-nil", function()
        t.assert.truthy(42)
    end)

    t.it("falsy passes for nil", function()
        t.assert.falsy(nil)
    end)

    t.it("falsy passes for false", function()
        t.assert.falsy(false)
    end)
end)

t.describe("assertions.contains", function()
    t.it("finds substring", function()
        t.assert.contains("hello world", "world")
    end)

    t.it("fails for missing substring", function()
        t.assert.errors(function()
            t.assert.contains("hello", "xyz")
        end)
    end)
end)

t.describe("assertions.type", function()
    t.it("checks number", function()
        t.assert.type(42, "number")
    end)

    t.it("checks string", function()
        t.assert.type("hi", "string")
    end)

    t.it("fails for wrong type", function()
        t.assert.errors(function()
            t.assert.type(42, "string")
        end)
    end)
end)

t.describe("assertions.vec_near", function()
    t.it("passes for close vectors (table keys)", function()
        t.assert.vec_near({x = 1.0, y = 2.0}, {x = 1.0001, y = 2.0001}, 0.001)
    end)

    t.it("passes for close vectors (array indices)", function()
        t.assert.vec_near({1.0, 2.0}, {1.0001, 2.0001}, 0.001)
    end)
end)

t.describe("assertions.match", function()
    t.it("matches partial table", function()
        t.assert.match({name = "player", hp = 100, mp = 50}, {name = "player", hp = 100})
    end)

    t.it("fails for mismatched key", function()
        t.assert.errors(function()
            t.assert.match({name = "player"}, {name = "enemy"})
        end)
    end)
end)
```

- [ ] **Step 2: Create test_mock.lua**

```lua
-- shared/testing/tests/test_mock.lua
local t = require "testing"
local mock = require "testing.mock"

t.describe("mock.spy", function()
    t.it("records calls", function()
        local fn = mock.spy()
        fn(1, 2)
        fn("a", "b")
        t.assert.eq(fn.call_count, 2)
        t.assert.eq(fn.calls[1], {1, 2})
        t.assert.eq(fn.calls[2], {"a", "b"})
    end)

    t.it("starts with zero calls", function()
        local fn = mock.spy()
        t.assert.eq(fn.call_count, 0)
        t.assert.eq(#fn.calls, 0)
    end)

    t.it("delegates to base function", function()
        local fn = mock.spy(function(x) return x * 2 end)
        local result = fn(5)
        t.assert.eq(result, 10)
        t.assert.eq(fn.call_count, 1)
    end)
end)

t.describe("mock.stub", function()
    t.it("replaces and restores method", function()
        local obj = {value = function() return "original" end}
        local restore = mock.stub(obj, "value", function() return "stubbed" end)
        t.assert.eq(obj.value(), "stubbed")
        restore()
        t.assert.eq(obj.value(), "original")
    end)
end)
```

- [ ] **Step 3: Run self-tests**

Run: `cd /Users/centurygame/work/love2d-play && luajit shared/testing/runner.lua shared/testing/tests`
Expected: All tests pass, output ends with `RESULTS: N passed, 0 failed, 0 skipped`

- [ ] **Step 4: Commit**

```bash
git add shared/testing/tests/test_assertions.lua shared/testing/tests/test_mock.lua
git commit -m "feat: add self-tests for testing framework"
```

---

### Task 9: Template Game — Input & Player Tests

**Files:**
- Create: `games/template/tests/test_input.lua`
- Create: `games/template/tests/test_player.lua`

- [ ] **Step 1: Create test_input.lua**

```lua
-- games/template/tests/test_input.lua
local t = require "testing"
local input = require "core.input"

t.describe("Input", function()
    -- reset state before each test
    local function reset()
        input.up = false
        input.down = false
        input.left = false
        input.right = false
    end

    t.it("starts with all directions false", function()
        reset()
        t.assert.falsy(input.up)
        t.assert.falsy(input.down)
        t.assert.falsy(input.left)
        t.assert.falsy(input.right)
    end)

    t.it("sets up=true on 'w' press", function()
        reset()
        input.keypressed("w")
        t.assert.truthy(input.up)
    end)

    t.it("sets up=true on 'up' press", function()
        reset()
        input.keypressed("up")
        t.assert.truthy(input.up)
    end)

    t.it("sets up=false on 'w' release", function()
        reset()
        input.keypressed("w")
        input.keyreleased("w")
        t.assert.falsy(input.up)
    end)

    t.it("handles all WASD keys", function()
        reset()
        input.keypressed("a")
        input.keypressed("s")
        input.keypressed("d")
        t.assert.truthy(input.left)
        t.assert.truthy(input.down)
        t.assert.truthy(input.right)
        t.assert.falsy(input.up)
    end)

    t.it("handles all arrow keys", function()
        reset()
        input.keypressed("left")
        input.keypressed("down")
        input.keypressed("right")
        t.assert.truthy(input.left)
        t.assert.truthy(input.down)
        t.assert.truthy(input.right)
    end)
end)
```

- [ ] **Step 2: Create test_player.lua**

The Player module requires `hump.class` and reads from `core.input`. We can test it by setting input state directly.

```lua
-- games/template/tests/test_player.lua
local t = require "testing"
local input = require "core.input"
local Player = require "entity.player"

t.describe("Player", function()
    local function reset_input()
        input.up = false
        input.down = false
        input.left = false
        input.right = false
    end

    t.it("initializes at given position", function()
        local p = Player(100, 200)
        t.assert.eq(p.x, 100)
        t.assert.eq(p.y, 200)
    end)

    t.it("has default speed 200", function()
        local p = Player(0, 0)
        t.assert.eq(p.speed, 200)
    end)

    t.it("does not move when no input", function()
        reset_input()
        local p = Player(100, 100)
        p:update(1.0)
        t.assert.eq(p.x, 100)
        t.assert.eq(p.y, 100)
    end)

    t.it("moves right at speed*dt", function()
        reset_input()
        input.right = true
        local p = Player(0, 0)
        p:update(0.5)
        t.assert.near(p.x, 100, 0.01)  -- 200 * 0.5
        t.assert.near(p.y, 0, 0.01)
    end)

    t.it("normalizes diagonal movement", function()
        reset_input()
        input.right = true
        input.down = true
        local p = Player(0, 0)
        p:update(1.0)
        -- diagonal: speed * 1/sqrt(2) ≈ 141.42
        local expected = 200 / math.sqrt(2)
        t.assert.near(p.x, expected, 0.01)
        t.assert.near(p.y, expected, 0.01)
    end)

    t.it("diagonal speed equals cardinal speed", function()
        reset_input()
        input.right = true
        local p1 = Player(0, 0)
        p1:update(1.0)
        local cardinal_dist = math.sqrt(p1.x * p1.x + p1.y * p1.y)

        reset_input()
        input.right = true
        input.down = true
        local p2 = Player(0, 0)
        p2:update(1.0)
        local diagonal_dist = math.sqrt(p2.x * p2.x + p2.y * p2.y)

        t.assert.near(cardinal_dist, diagonal_dist, 0.01)
    end)
end)
```

- [ ] **Step 3: Run template tests**

Run: `cd /Users/centurygame/work/love2d-play && make unit-test GAME=template`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add games/template/tests/test_input.lua games/template/tests/test_player.lua
git commit -m "feat: add unit tests for template game (input + player)"
```

---

### Task 10: Physics Testbed — Camera Unit Tests

**Files:**
- Create: `games/physics-testbed/tests/test_camera.lua`

The Camera module uses `love.graphics.getDimensions()` in `toWorld`/`toScreen`. Our love_stub returns 800x600.

- [ ] **Step 1: Create test_camera.lua**

```lua
-- games/physics-testbed/tests/test_camera.lua
local t = require "testing"
local Camera = require "camera"

t.describe("Camera", function()
    t.describe("new", function()
        t.it("initializes at origin with scale 1", function()
            local cam = Camera.new()
            t.assert.eq(cam.x, 0)
            t.assert.eq(cam.y, 0)
            t.assert.eq(cam.scale, 1)
        end)
    end)

    t.describe("toWorld / toScreen roundtrip", function()
        t.it("screen center maps to camera position", function()
            local cam = Camera.new()
            cam.x = 100
            cam.y = 200
            -- screen center is (400, 300) with 800x600 stub
            local wx, wy = cam:toWorld(400, 300)
            t.assert.near(wx, 100, 0.01)
            t.assert.near(wy, 200, 0.01)
        end)

        t.it("roundtrips correctly", function()
            local cam = Camera.new()
            cam.x = 50
            cam.y = 75
            cam.scale = 2.0
            local wx, wy = cam:toWorld(300, 200)
            local sx, sy = cam:toScreen(wx, wy)
            t.assert.near(sx, 300, 0.01)
            t.assert.near(sy, 200, 0.01)
        end)

        t.it("respects scale for toWorld", function()
            local cam = Camera.new()
            cam.x = 0
            cam.y = 0
            cam.scale = 2.0
            -- pixel (400, 300) is center -> world (0, 0)
            -- pixel (600, 300) is 200px right of center -> world (100, 0) at scale 2
            local wx, wy = cam:toWorld(600, 300)
            t.assert.near(wx, 100, 0.01)
            t.assert.near(wy, 0, 0.01)
        end)
    end)

    t.describe("wheelmoved", function()
        t.it("zooms in on scroll up", function()
            local cam = Camera.new()
            local old_scale = cam.scale
            cam:wheelmoved(0, 1)
            t.assert.truthy(cam.scale > old_scale)
        end)

        t.it("zooms out on scroll down", function()
            local cam = Camera.new()
            local old_scale = cam.scale
            cam:wheelmoved(0, -1)
            t.assert.truthy(cam.scale < old_scale)
        end)

        t.it("clamps to min_scale", function()
            local cam = Camera.new()
            for _ = 1, 100 do cam:wheelmoved(0, -1) end
            t.assert.near(cam.scale, cam.min_scale, 0.01)
        end)

        t.it("clamps to max_scale", function()
            local cam = Camera.new()
            for _ = 1, 100 do cam:wheelmoved(0, 1) end
            t.assert.near(cam.scale, cam.max_scale, 0.01)
        end)
    end)

    t.describe("reset", function()
        t.it("restores defaults", function()
            local cam = Camera.new()
            cam.x = 999
            cam.y = 888
            cam.scale = 5
            cam:reset()
            t.assert.eq(cam.x, 0)
            t.assert.eq(cam.y, 0)
            t.assert.eq(cam.scale, 1)
        end)
    end)

    t.describe("drag pan", function()
        t.it("pans camera on right-mouse drag", function()
            local cam = Camera.new()
            cam.x = 100
            cam.y = 100
            cam:mousepressed(400, 300, 2)
            t.assert.truthy(cam.dragging)
            cam:mousemoved(500, 400, 100, 100)
            -- drag 100px right and 100px down at scale 1 -> camera moves left and up
            t.assert.near(cam.x, 0, 0.01)   -- 100 - (500-400)/1
            t.assert.near(cam.y, 0, 0.01)   -- 100 - (400-300)/1
        end)

        t.it("ignores left-mouse for drag", function()
            local cam = Camera.new()
            cam:mousepressed(400, 300, 1)
            t.assert.falsy(cam.dragging)
        end)
    end)
end)
```

- [ ] **Step 2: Run camera tests**

Run: `cd /Users/centurygame/work/love2d-play && make unit-test GAME=physics-testbed`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add games/physics-testbed/tests/test_camera.lua
git commit -m "feat: add camera unit tests for physics-testbed"
```

---

### Task 11: Physics Testbed — Cut The Rope Segment Intersection Tests

**Files:**
- Modify: `games/physics-testbed/src/scenes/cut_the_rope.lua` (extract `segmentsIntersect`)
- Create: `games/physics-testbed/src/geom.lua`
- Create: `games/physics-testbed/tests/test_cut_the_rope.lua`

The `segmentsIntersect` function is currently a `local` inside `cut_the_rope.lua`. We need to extract it to a shared module so tests can require it.

- [ ] **Step 1: Create geom.lua with the extracted function**

```lua
-- games/physics-testbed/src/geom.lua
local geom = {}

function geom.segmentsIntersect(ax, ay, bx, by, cx, cy, dx, dy)
    local function cross(ux, uy, vx, vy) return ux * vy - uy * vx end
    local rx, ry = bx - ax, by - ay
    local sx, sy = dx - cx, dy - cy
    local denom = cross(rx, ry, sx, sy)
    if math.abs(denom) < 1e-10 then return false end
    local qpx, qpy = cx - ax, cy - ay
    local t = cross(qpx, qpy, sx, sy) / denom
    local u = cross(qpx, qpy, rx, ry) / denom
    return t >= 0 and t <= 1 and u >= 0 and u <= 1
end

return geom
```

- [ ] **Step 2: Update cut_the_rope.lua to use geom module**

Replace the local `segmentsIntersect` function and add a require. Change the top of the file from:

```lua
local scene = {}

-- state
local ropes = {}
local candy = nil
local target_body = nil
local collected = false
local cutting = false
local prev_cut = {x = 0, y = 0}
local cur_cut = {x = 0, y = 0}

-- line segment intersection test
local function segmentsIntersect(ax, ay, bx, by, cx, cy, dx, dy)
    local function cross(ux, uy, vx, vy) return ux * vy - uy * vx end
    local rx, ry = bx - ax, by - ay
    local sx, sy = dx - cx, dy - cy
    local denom = cross(rx, ry, sx, sy)
    if math.abs(denom) < 1e-10 then return false end
    local qpx, qpy = cx - ax, cy - ay
    local t = cross(qpx, qpy, sx, sy) / denom
    local u = cross(qpx, qpy, rx, ry) / denom
    return t >= 0 and t <= 1 and u >= 0 and u <= 1
end
```

to:

```lua
local geom = require "geom"

local scene = {}

-- state
local ropes = {}
local candy = nil
local target_body = nil
local collected = false
local cutting = false
local prev_cut = {x = 0, y = 0}
local cur_cut = {x = 0, y = 0}

local segmentsIntersect = geom.segmentsIntersect
```

- [ ] **Step 3: Verify the game still runs**

Run: `cd /Users/centurygame/work/love2d-play && make run GAME=physics-testbed`
Expected: Game launches without errors. Close it manually.

- [ ] **Step 4: Create test_cut_the_rope.lua**

```lua
-- games/physics-testbed/tests/test_cut_the_rope.lua
local t = require "testing"
local geom = require "geom"

t.describe("segmentsIntersect", function()
    local si = geom.segmentsIntersect

    t.it("detects crossing segments", function()
        -- X pattern: (0,0)-(10,10) crosses (10,0)-(0,10)
        t.assert.truthy(si(0, 0, 10, 10, 10, 0, 0, 10))
    end)

    t.it("rejects parallel segments", function()
        -- two horizontal parallel lines
        t.assert.falsy(si(0, 0, 10, 0, 0, 5, 10, 5))
    end)

    t.it("rejects non-touching segments", function()
        -- L shape that doesn't connect
        t.assert.falsy(si(0, 0, 5, 0, 10, 0, 10, 5))
    end)

    t.it("detects T intersection", function()
        -- vertical (5,0)-(5,10) crosses horizontal (0,5)-(10,5)
        t.assert.truthy(si(5, 0, 5, 10, 0, 5, 10, 5))
    end)

    t.it("detects endpoint touching", function()
        -- segments meeting at (5,5)
        t.assert.truthy(si(0, 0, 5, 5, 5, 5, 10, 10))
    end)

    t.it("rejects collinear non-overlapping", function()
        -- same line but no overlap: (0,0)-(1,0) and (2,0)-(3,0)
        t.assert.falsy(si(0, 0, 1, 0, 2, 0, 3, 0))
    end)
end)
```

- [ ] **Step 5: Run tests**

Run: `cd /Users/centurygame/work/love2d-play && make unit-test GAME=physics-testbed`
Expected: All tests pass (camera + cut_the_rope tests)

- [ ] **Step 6: Commit**

```bash
git add games/physics-testbed/src/geom.lua games/physics-testbed/src/scenes/cut_the_rope.lua games/physics-testbed/tests/test_cut_the_rope.lua
git commit -m "feat: extract segmentsIntersect to geom module, add tests"
```

---

### Task 12: Physics Testbed — Integration Tests

**Files:**
- Create: `games/physics-testbed/tests/integration_physics.lua`

- [ ] **Step 1: Create integration_physics.lua**

```lua
-- games/physics-testbed/tests/integration_physics.lua
local t = require "testing"

t.describe("Physics World (integration)", function()
    t.it("creates a world with gravity", function()
        local world = love.physics.newWorld(0, 98, true)
        local gx, gy = world:getGravity()
        t.assert.near(gx, 0, 0.01)
        t.assert.near(gy, 98, 0.01)
        world:destroy()
    end)

    t.it("dynamic body falls under gravity", function()
        local world = love.physics.newWorld(0, 100, true)
        local body = love.physics.newBody(world, 0, 0, "dynamic")
        local shape = love.physics.newCircleShape(10)
        love.physics.newFixture(body, shape, 1)

        local initial_y = body:getY()
        -- step the world several times
        for _ = 1, 60 do
            world:update(1/60)
        end
        local final_y = body:getY()

        t.assert.truthy(final_y > initial_y)
        world:destroy()
    end)

    t.it("static body does not move", function()
        local world = love.physics.newWorld(0, 100, true)
        local body = love.physics.newBody(world, 50, 50, "static")
        local shape = love.physics.newRectangleShape(100, 10)
        love.physics.newFixture(body, shape)

        for _ = 1, 60 do
            world:update(1/60)
        end

        t.assert.near(body:getX(), 50, 0.01)
        t.assert.near(body:getY(), 50, 0.01)
        world:destroy()
    end)

    t.it("bodies collide and stop", function()
        local world = love.physics.newWorld(0, 100, true)

        -- ground
        local ground = love.physics.newBody(world, 0, 100, "static")
        local gs = love.physics.newRectangleShape(200, 10)
        love.physics.newFixture(ground, gs)

        -- falling ball
        local ball = love.physics.newBody(world, 0, 0, "dynamic")
        local bs = love.physics.newCircleShape(5)
        local bf = love.physics.newFixture(ball, bs, 1)
        bf:setRestitution(0)

        -- simulate 5 seconds
        for _ = 1, 300 do
            world:update(1/60)
        end

        -- ball should have settled near ground (y ~= 95 - radius)
        local by = ball:getY()
        t.assert.truthy(by > 80)
        t.assert.truthy(by < 100)

        -- velocity should be near zero (settled)
        local _, vy = ball:getLinearVelocity()
        t.assert.near(vy, 0, 5)

        world:destroy()
    end)

    t.it("revolute joint constrains bodies", function()
        local world = love.physics.newWorld(0, 0, true)

        local a = love.physics.newBody(world, 0, 0, "static")
        love.physics.newFixture(a, love.physics.newCircleShape(5))

        local b = love.physics.newBody(world, 50, 0, "dynamic")
        love.physics.newFixture(b, love.physics.newCircleShape(5), 1)

        local joint = love.physics.newRevoluteJoint(a, b, 0, 0)

        t.assert.truthy(joint)
        t.assert.eq(#world:getJoints(), 1)

        world:destroy()
    end)

    t.it("scene stacking creates correct body count", function()
        local world = love.physics.newWorld(0, 98, true)
        -- Stacking scene: 1 ground + pyramid of boxes (rows=10: 10+9+8+...+1 = 55)
        local scenes = require "scenes"
        scenes.stacking.setup(world)

        local bodies = world:getBodies()
        t.assert.eq(#bodies, 56)  -- 1 ground + 55 boxes

        world:destroy()
    end)
end)
```

- [ ] **Step 2: Run integration tests**

Run: `cd /Users/centurygame/work/love2d-play && make integration-test GAME=physics-testbed`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add games/physics-testbed/tests/integration_physics.lua
git commit -m "feat: add physics integration tests for physics-testbed"
```

---

### Task 13: Blocks — Extract Logic from main.lua

**Files:**
- Create: `games/blocks/src/pieces.lua`
- Create: `games/blocks/src/grid.lua`
- Modify: `games/blocks/main.lua`
- Modify: `games/blocks/conf.lua`

- [ ] **Step 1: Add src/ to package.path in conf.lua**

In `games/blocks/conf.lua`, add the monorepo package path setup at the top of the file (before `function love.conf`). Read the file first to see its current contents, then add:

```lua
do
    local source = love.filesystem.getSource()
    local root = source .. "/../../"
    package.path = source .. "/src/?.lua;"
        .. source .. "/src/?/init.lua;"
        .. root .. "vendor/?.lua;"
        .. root .. "vendor/?/init.lua;"
        .. root .. "shared/?.lua;"
        .. root .. "shared/?/init.lua;"
        .. package.path
end
```

- [ ] **Step 2: Create pieces.lua**

```lua
-- games/blocks/src/pieces.lua
-- Piece structure data and constants extracted from main.lua

local pieces = {}

pieces.structures = {
    { -- I
        {
            { ' ', ' ', ' ', ' ' },
            { 'i', 'i', 'i', 'i' },
            { ' ', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'i', ' ', ' ' },
            { ' ', 'i', ' ', ' ' },
            { ' ', 'i', ' ', ' ' },
            { ' ', 'i', ' ', ' ' },
        },
    },
    { -- O
        {
            { ' ', ' ', ' ', ' ' },
            { ' ', 'o', 'o', ' ' },
            { ' ', 'o', 'o', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    { -- J
        {
            { ' ', ' ', ' ', ' ' },
            { 'j', 'j', 'j', ' ' },
            { ' ', ' ', 'j', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'j', ' ', ' ' },
            { ' ', 'j', ' ', ' ' },
            { 'j', 'j', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { 'j', ' ', ' ', ' ' },
            { 'j', 'j', 'j', ' ' },
            { ' ', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'j', 'j', ' ' },
            { ' ', 'j', ' ', ' ' },
            { ' ', 'j', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    { -- L
        {
            { ' ', ' ', ' ', ' ' },
            { 'l', 'l', 'l', ' ' },
            { 'l', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'l', ' ', ' ' },
            { ' ', 'l', ' ', ' ' },
            { ' ', 'l', 'l', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', ' ', 'l', ' ' },
            { 'l', 'l', 'l', ' ' },
            { ' ', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { 'l', 'l', ' ', ' ' },
            { ' ', 'l', ' ', ' ' },
            { ' ', 'l', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    { -- T
        {
            { ' ', ' ', ' ', ' ' },
            { 't', 't', 't', ' ' },
            { ' ', 't', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 't', ' ', ' ' },
            { ' ', 't', 't', ' ' },
            { ' ', 't', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 't', ' ', ' ' },
            { 't', 't', 't', ' ' },
            { ' ', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 't', ' ', ' ' },
            { 't', 't', ' ', ' ' },
            { ' ', 't', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    { -- S
        {
            { ' ', ' ', ' ', ' ' },
            { ' ', 's', 's', ' ' },
            { 's', 's', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { 's', ' ', ' ', ' ' },
            { 's', 's', ' ', ' ' },
            { ' ', 's', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    { -- Z
        {
            { ' ', ' ', ' ', ' ' },
            { 'z', 'z', ' ', ' ' },
            { ' ', 'z', 'z', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'z', ' ', ' ' },
            { 'z', 'z', ' ', ' ' },
            { 'z', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
}

pieces.PIECE_SIZE = 4
pieces.GRID_W = 10
pieces.GRID_H = 18

pieces.colors = {
    [' '] = { .87, .87, .87 },
    i = { .47, .76, .94 },
    j = { .93, .91, .42 },
    l = { .49, .85, .76 },
    o = { .92, .69, .47 },
    s = { .83, .54, .93 },
    t = { .97, .58, .77 },
    z = { .66, .83, .46 },
    preview = { .75, .75, .75 },
}

return pieces
```

- [ ] **Step 3: Create grid.lua**

```lua
-- games/blocks/src/grid.lua
-- Grid logic extracted from main.lua: collision, clearing, sequence

local pieces = require "pieces"

local grid = {}

function grid.newGrid()
    local g = {}
    for y = 1, pieces.GRID_H do
        g[y] = {}
        for x = 1, pieces.GRID_W do
            g[y][x] = ' '
        end
    end
    return g
end

function grid.canPieceMove(inert, pieceType, testX, testY, testRotation)
    local shape = pieces.structures[pieceType][testRotation]
    for y = 1, pieces.PIECE_SIZE do
        for x = 1, pieces.PIECE_SIZE do
            local testBlockX = testX + x
            local testBlockY = testY + y

            if shape[y][x] ~= ' ' and (
                    testBlockX < 1
                    or testBlockX > pieces.GRID_W
                    or testBlockY > pieces.GRID_H
                    or inert[testBlockY][testBlockX] ~= ' '
                ) then
                return false
            end
        end
    end
    return true
end

function grid.lockPiece(inert, pieceType, pieceX, pieceY, pieceRotation)
    local shape = pieces.structures[pieceType][pieceRotation]
    for y = 1, pieces.PIECE_SIZE do
        for x = 1, pieces.PIECE_SIZE do
            local block = shape[y][x]
            if block ~= ' ' then
                inert[pieceY + y][pieceX + x] = block
            end
        end
    end
end

function grid.clearFullRows(inert)
    local cleared = 0
    for y = 1, pieces.GRID_H do
        local complete = true
        for x = 1, pieces.GRID_W do
            if inert[y][x] == ' ' then
                complete = false
                break
            end
        end

        if complete then
            cleared = cleared + 1
            for removeY = y, 2, -1 do
                for removeX = 1, pieces.GRID_W do
                    inert[removeY][removeX] = inert[removeY - 1][removeX]
                end
            end
            for removeX = 1, pieces.GRID_W do
                inert[1][removeX] = ' '
            end
        end
    end
    return cleared
end

function grid.newSequence(sequence, random_fn)
    random_fn = random_fn or math.random
    for pieceTypeIndex = 1, #pieces.structures do
        local position = random_fn(#sequence + 1)
        table.insert(sequence, position, pieceTypeIndex)
    end
end

return grid
```

- [ ] **Step 4: Update blocks main.lua to use extracted modules**

Replace the entire `games/blocks/main.lua` with a version that requires the extracted modules. The game behavior is identical — we just delegate logic to `pieces` and `grid`:

```lua
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

local gl = love.graphics
local pieces = require "pieces"
local grid = require "grid"

local timerLimit = 0.5
local timer = 0
local inert = {}
local sequence = {}
local pieceX = 3
local pieceY = 0
local pieceRotation = 1
local pieceType = nil

local function newPiece()
    pieceX = 3
    pieceY = 0
    pieceRotation = 1
    pieceType = table.remove(sequence)

    if #sequence == 0 then
        grid.newSequence(sequence, love.math.random)
    end
end

local function reset()
    inert = grid.newGrid()
    grid.newSequence(sequence, love.math.random)
    newPiece()
    timer = 0
end

local DUMMY = function() end
local function switch(v, cases, ...)
    local f = cases[v] or cases['default'] or DUMMY
    return f(...)
end

function love.load()
    gl.setBackgroundColor(255, 255, 255)
    reset()
end

function love.update(dt)
    timer = timer + dt
    if timer < timerLimit then
        return
    end
    timer = 0

    local testY = pieceY + 1
    if grid.canPieceMove(inert, pieceType, pieceX, testY, pieceRotation) then
        pieceY = testY
        return
    end

    grid.lockPiece(inert, pieceType, pieceX, pieceY, pieceRotation)
    grid.clearFullRows(inert)
    newPiece()

    if not grid.canPieceMove(inert, pieceType, pieceX, pieceY, pieceRotation) then
        reset()
    end
end

local function handleKeyX()
    local testRotation = pieceRotation + 1
    if testRotation > #pieces.structures[pieceType] then
        testRotation = 1
    end
    if grid.canPieceMove(inert, pieceType, pieceX, pieceY, testRotation) then
        pieceRotation = testRotation
    end
end

local function handleKeyZ()
    local testRotation = pieceRotation - 1
    if testRotation < 1 then
        testRotation = #pieces.structures[pieceType]
    end
    if grid.canPieceMove(inert, pieceType, pieceX, pieceY, testRotation) then
        pieceRotation = testRotation
    end
end

local function handleKeyC()
    while grid.canPieceMove(inert, pieceType, pieceX, pieceY + 1, pieceRotation) do
        pieceY = pieceY + 1
        timer = timerLimit
    end
end

local function handleKeyLeft()
    if grid.canPieceMove(inert, pieceType, pieceX - 1, pieceY, pieceRotation) then
        pieceX = pieceX - 1
    end
end

local function handleKeyRight()
    if grid.canPieceMove(inert, pieceType, pieceX + 1, pieceY, pieceRotation) then
        pieceX = pieceX + 1
    end
end

function love.keypressed(key)
    switch(key, {
        x       = handleKeyX,
        z       = handleKeyZ,
        c       = handleKeyC,
        left    = handleKeyLeft,
        right   = handleKeyRight,
        default = function() print("unknown key") end
    })
end

function love.draw()
    local offsetX = 2
    local offsetY = 5
    local blockSize = 20
    local blockDrawSize = blockSize - 1

    local function drawBlock(block, x, y)
        local color = pieces.colors[block]
        gl.setColor(color)
        gl.rectangle('fill',
            (x - 1) * blockSize,
            (y - 1) * blockSize,
            blockDrawSize,
            blockDrawSize)
    end

    for y = 1, pieces.GRID_H do
        for x = 1, pieces.GRID_W do
            drawBlock(inert[y][x], x + offsetX, y + offsetY)
        end
    end

    local next = sequence[#sequence]
    local nextShape = pieces.structures[next][1]
    local curShape = pieces.structures[pieceType][pieceRotation]
    for y = 1, pieces.PIECE_SIZE do
        for x = 1, pieces.PIECE_SIZE do
            local block = curShape[y][x]
            if block ~= ' ' then
                drawBlock(block, x + pieceX + offsetX, y + pieceY + offsetY)
            end

            block = nextShape[y][x]
            if block ~= ' ' then
                drawBlock('preview', x + 5, y + 1)
            end
        end
    end
end
```

- [ ] **Step 5: Verify blocks game still runs**

Run: `cd /Users/centurygame/work/love2d-play && make run GAME=blocks`
Expected: Tetris game launches and works correctly. Close it manually.

- [ ] **Step 6: Commit**

```bash
git add games/blocks/src/pieces.lua games/blocks/src/grid.lua games/blocks/main.lua games/blocks/conf.lua
git commit -m "refactor: extract blocks logic into pieces.lua and grid.lua modules"
```

---

### Task 14: Blocks — Unit Tests

**Files:**
- Create: `games/blocks/tests/test_grid.lua`

- [ ] **Step 1: Create test_grid.lua**

```lua
-- games/blocks/tests/test_grid.lua
local t = require "testing"
local pieces = require "pieces"
local grid = require "grid"

t.describe("grid.newGrid", function()
    t.it("creates 18x10 grid of spaces", function()
        local g = grid.newGrid()
        t.assert.eq(#g, 18)
        t.assert.eq(#g[1], 10)
        t.assert.eq(g[1][1], ' ')
        t.assert.eq(g[18][10], ' ')
    end)
end)

t.describe("grid.canPieceMove", function()
    t.it("allows I-piece at starting position", function()
        local g = grid.newGrid()
        -- pieceType 1 = I, rotation 1, position (3, 0)
        t.assert.truthy(grid.canPieceMove(g, 1, 3, 0, 1))
    end)

    t.it("blocks piece past left wall", function()
        local g = grid.newGrid()
        -- I-piece horizontal: occupies columns testX+1..testX+4
        -- testX = -4 means columns -3..-0 -> out of bounds
        t.assert.falsy(grid.canPieceMove(g, 1, -4, 5, 1))
    end)

    t.it("blocks piece past right wall", function()
        local g = grid.newGrid()
        -- I-piece horizontal at testX = 8: columns 9,10,11,12 -> 11,12 out of bounds
        t.assert.falsy(grid.canPieceMove(g, 1, 8, 5, 1))
    end)

    t.it("blocks piece past bottom", function()
        local g = grid.newGrid()
        -- I-piece horizontal (row 2 of shape has blocks), testY=17 -> row 19 > 18
        t.assert.falsy(grid.canPieceMove(g, 1, 3, 17, 1))
    end)

    t.it("blocks piece on occupied cell", function()
        local g = grid.newGrid()
        g[2][4] = 'x'  -- occupy cell
        -- I-piece at (3,0) rotation 1: row 2 has blocks at columns 4,5,6,7
        t.assert.falsy(grid.canPieceMove(g, 1, 3, 0, 1))
    end)

    t.it("allows O-piece in open space", function()
        local g = grid.newGrid()
        -- O-piece (type 2) at center
        t.assert.truthy(grid.canPieceMove(g, 2, 4, 5, 1))
    end)
end)

t.describe("grid.lockPiece", function()
    t.it("writes piece cells to grid", function()
        local g = grid.newGrid()
        -- Lock I-piece (type 1, rotation 1) at (3, 0)
        -- I-piece row 2: columns 4,5,6,7 should be 'i'
        grid.lockPiece(g, 1, 3, 0, 1)
        t.assert.eq(g[2][4], 'i')
        t.assert.eq(g[2][5], 'i')
        t.assert.eq(g[2][6], 'i')
        t.assert.eq(g[2][7], 'i')
        -- other rows should remain empty
        t.assert.eq(g[1][4], ' ')
        t.assert.eq(g[3][4], ' ')
    end)
end)

t.describe("grid.clearFullRows", function()
    t.it("clears a full row", function()
        local g = grid.newGrid()
        -- fill bottom row
        for x = 1, 10 do
            g[18][x] = 'i'
        end
        local cleared = grid.clearFullRows(g)
        t.assert.eq(cleared, 1)
        -- bottom row should now be empty (shifted down from row above)
        for x = 1, 10 do
            t.assert.eq(g[18][x], ' ')
        end
    end)

    t.it("clears multiple full rows", function()
        local g = grid.newGrid()
        for x = 1, 10 do
            g[17][x] = 'j'
            g[18][x] = 'i'
        end
        local cleared = grid.clearFullRows(g)
        t.assert.eq(cleared, 2)
    end)

    t.it("does not clear incomplete rows", function()
        local g = grid.newGrid()
        for x = 1, 9 do
            g[18][x] = 'i'
        end
        -- column 10 is still empty
        local cleared = grid.clearFullRows(g)
        t.assert.eq(cleared, 0)
    end)

    t.it("shifts rows above down", function()
        local g = grid.newGrid()
        -- put something in row 17
        g[17][1] = 'z'
        -- fill row 18
        for x = 1, 10 do
            g[18][x] = 'i'
        end
        grid.clearFullRows(g)
        -- row 17's content should now be in row 18
        t.assert.eq(g[18][1], 'z')
        -- row 17 should be empty (shifted from row 16 which was empty)
        t.assert.eq(g[17][1], ' ')
    end)
end)

t.describe("grid.newSequence", function()
    t.it("adds 7 piece types to sequence", function()
        local seq = {}
        grid.newSequence(seq, math.random)
        t.assert.eq(#seq, 7)
    end)

    t.it("contains all 7 piece types", function()
        local seq = {}
        grid.newSequence(seq, math.random)
        local found = {}
        for _, v in ipairs(seq) do
            found[v] = true
        end
        for i = 1, 7 do
            t.assert.truthy(found[i])
        end
    end)

    t.it("appends to existing sequence", function()
        local seq = {1, 2, 3}
        grid.newSequence(seq, math.random)
        t.assert.eq(#seq, 10)  -- 3 + 7
    end)
end)
```

- [ ] **Step 2: Run blocks tests**

Run: `cd /Users/centurygame/work/love2d-play && make unit-test GAME=blocks`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add games/blocks/tests/test_grid.lua
git commit -m "feat: add unit tests for blocks game (grid, clearing, sequence)"
```

---

### Task 15: Water — Extract Logic and Add Tests

**Files:**
- Create: `games/water/src/particle.lua`
- Modify: `games/water/main.lua`
- Modify: `games/water/conf.lua`
- Create: `games/water/tests/test_particle.lua`

- [ ] **Step 1: Add src/ to package.path in water/conf.lua**

Read `games/water/conf.lua` first, then add the monorepo package path setup at the top:

```lua
do
    local source = love.filesystem.getSource()
    local root = source .. "/../../"
    package.path = source .. "/src/?.lua;"
        .. source .. "/src/?/init.lua;"
        .. root .. "vendor/?.lua;"
        .. root .. "vendor/?/init.lua;"
        .. root .. "shared/?.lua;"
        .. root .. "shared/?/init.lua;"
        .. package.path
end
```

- [ ] **Step 2: Create particle.lua**

```lua
-- games/water/src/particle.lua
-- Particle physics logic extracted from main.lua

local particle = {}

particle.GRAVITY = 900
particle.R = 1
particle.RESTITUTION = 0.0
particle.VISCOSITY = 0.02
particle.FLOOR_FRICTION = 0.6

function particle.integrate(p, dt, gravity)
    gravity = gravity or particle.GRAVITY
    p.vy = p.vy + gravity * dt
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
end

function particle.handleCollisions(p, container, restitution, floor_friction)
    restitution = restitution or particle.RESTITUTION
    floor_friction = floor_friction or particle.FLOOR_FRICTION
    local r = p.r or particle.R

    local left = container.x + r
    local right = container.x + container.w - r
    local top = container.y + r
    local bottom = container.y + container.h - r

    if p.y > bottom then
        p.y = bottom
        if p.vy > 0 then p.vy = -p.vy * restitution end
        p.vx = p.vx * floor_friction
    end
    if p.y < top then
        p.y = top
        if p.vy < 0 then p.vy = -p.vy * restitution end
    end
    if p.x < left then
        p.x = left
        if p.vx < 0 then p.vx = -p.vx * restitution end
    elseif p.x > right then
        p.x = right
        if p.vx > 0 then p.vx = -p.vx * restitution end
    end
end

function particle.applyViscosity(a, b, dt, viscosity, r)
    viscosity = viscosity or particle.VISCOSITY
    r = r or particle.R
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dist2 = dx * dx + dy * dy
    local influence = (r * 6) * (r * 6)
    if dist2 >= influence or dist2 <= 0 then return false end

    local dist = math.sqrt(dist2)
    local nx, ny = dx / dist, dy / dist

    -- separation force
    local overlap = (r * 2 - dist)
    if overlap > 0 then
        local sep = overlap * 0.5
        a.x = a.x - nx * sep
        a.y = a.y - ny * sep
        b.x = b.x + nx * sep
        b.y = b.y + ny * sep
    end

    -- velocity blending
    local mix = viscosity * dt * (1 - (dist / math.sqrt(influence)))
    local avx, avy = a.vx, a.vy
    local bvx, bvy = b.vx, b.vy
    a.vx = a.vx + (bvx - avx) * mix
    a.vy = a.vy + (bvy - avy) * mix
    b.vx = b.vx + (avx - bvx) * mix
    b.vy = b.vy + (avy - bvy) * mix

    return true
end

return particle
```

- [ ] **Step 3: Update water/main.lua to use particle module**

Replace the physics functions in `games/water/main.lua`. Keep the Love2D callbacks, replace `integrate`, `handleCollisions`, and `applyNeighbourViscosity` with calls to the module:

```lua
-- 简单粒子水模拟（可交互：按住鼠标左键倒水）

local particle = require "particle"

local particles = {}
local pool = {}
local maxParticles = 2000
local SPAWN_RATE = 600
local container = { x = 200, y = 200, w = 400, h = 260 }
local lastSpawn = 0

local function spawnParticle(x, y, vx, vy)
    local p = nil
    for i = 1, #pool do
        if not pool[i].active then
            p = pool[i]
            break
        end
    end

    if not p then return end

    p.active = true
    p.x = x
    p.y = y
    p.vx = vx or 0
    p.vy = vy or 0
    p.r = particle.R
    p.mass = 1
    p.color = { 0.2 + math.random() * 0.1, 0.4 + math.random() * 0.2, 0.9, 1 }
    particles[#particles + 1] = p
end

function love.load()
    for i = 1, maxParticles do
        pool[i] = { active = false }
    end
    love.graphics.setBackgroundColor(0.12, 0.12, 0.12)
    love.window.setMode(800, 600)
end

local function applyNeighbourViscosity(dt)
    local n = #particles
    for i = 1, n do
        local a = particles[i]
        if not a.active then goto continueA end
        for j = i + 1, n do
            local b = particles[j]
            if not b.active then goto continueB end
            particle.applyViscosity(a, b, dt)
            ::continueB::
        end
        ::continueA::
    end
end

function love.update(dt)
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        lastSpawn = lastSpawn + SPAWN_RATE * dt
        while lastSpawn >= 1 do
            local jitter = (math.random() - 0.5) * 6
            spawnParticle(mx + jitter, my + jitter, (math.random() - 0.5) * 60, -50 + math.random() * 40)
            lastSpawn = lastSpawn - 1
        end
    else
        lastSpawn = 0
    end

    applyNeighbourViscosity(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        if not p.active then
            table.remove(particles, i)
        else
            particle.integrate(p, dt)
            particle.handleCollisions(p, container)
            if p.y > love.graphics.getHeight() + 200 then
                p.active = false
                table.remove(particles, i)
            end
        end
    end
end

function love.draw()
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", container.x, container.y, container.w, container.h)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", container.x, container.y, container.w, container.h)

    for i = 1, #particles do
        local p = particles[i]
        love.graphics.setColor(p.color)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Hold left mouse to pour water. Particles: " .. tostring(#particles), 10, 10)
end
```

- [ ] **Step 4: Verify water game still runs**

Run: `cd /Users/centurygame/work/love2d-play && make run GAME=water`
Expected: Water sim launches and works. Close it manually.

- [ ] **Step 5: Create test_particle.lua**

```lua
-- games/water/tests/test_particle.lua
local t = require "testing"
local particle = require "particle"

t.describe("particle.integrate", function()
    t.it("applies gravity to vy", function()
        local p = {x = 0, y = 0, vx = 0, vy = 0}
        particle.integrate(p, 1.0, 100)
        t.assert.near(p.vy, 100, 0.01)
    end)

    t.it("moves position by velocity", function()
        local p = {x = 10, y = 20, vx = 5, vy = 0}
        particle.integrate(p, 1.0, 0)
        t.assert.near(p.x, 15, 0.01)
    end)

    t.it("gravity accumulates over multiple steps", function()
        local p = {x = 0, y = 0, vx = 0, vy = 0}
        particle.integrate(p, 0.5, 100)
        particle.integrate(p, 0.5, 100)
        -- after 2 steps: vy = 100, y = 50 + 75 = ... let's just check vy
        t.assert.near(p.vy, 100, 0.01)
    end)
end)

t.describe("particle.handleCollisions", function()
    local box = {x = 0, y = 0, w = 100, h = 100}

    t.it("clamps particle to bottom boundary", function()
        local p = {x = 50, y = 150, vx = 0, vy = 10, r = 1}
        particle.handleCollisions(p, box, 0, 1.0)
        t.assert.near(p.y, 99, 0.01)  -- container.h - r
        t.assert.near(p.vy, 0, 0.01)  -- restitution 0 -> vy = 0
    end)

    t.it("clamps particle to top boundary", function()
        local p = {x = 50, y = -10, vx = 0, vy = -5, r = 1}
        particle.handleCollisions(p, box, 0, 1.0)
        t.assert.near(p.y, 1, 0.01)  -- container.y + r
    end)

    t.it("clamps particle to left boundary", function()
        local p = {x = -5, y = 50, vx = -10, vy = 0, r = 1}
        particle.handleCollisions(p, box, 0, 1.0)
        t.assert.near(p.x, 1, 0.01)
    end)

    t.it("clamps particle to right boundary", function()
        local p = {x = 200, y = 50, vx = 10, vy = 0, r = 1}
        particle.handleCollisions(p, box, 0, 1.0)
        t.assert.near(p.x, 99, 0.01)
    end)

    t.it("applies floor friction on bottom hit", function()
        local p = {x = 50, y = 150, vx = 100, vy = 10, r = 1}
        particle.handleCollisions(p, box, 0, 0.5)
        t.assert.near(p.vx, 50, 0.01)  -- 100 * 0.5
    end)

    t.it("bounces with restitution", function()
        local p = {x = 50, y = 150, vx = 0, vy = 10, r = 1}
        particle.handleCollisions(p, box, 0.8, 1.0)
        t.assert.near(p.vy, -8, 0.01)  -- -10 * 0.8
    end)
end)

t.describe("particle.applyViscosity", function()
    t.it("blends velocities of nearby particles", function()
        local a = {x = 0, y = 0, vx = 10, vy = 0}
        local b = {x = 2, y = 0, vx = 0, vy = 0}
        local applied = particle.applyViscosity(a, b, 1.0, 0.5, 1)
        t.assert.truthy(applied)
        -- a should have lost some vx, b should have gained some
        t.assert.truthy(a.vx < 10)
        t.assert.truthy(b.vx > 0)
    end)

    t.it("does not affect distant particles", function()
        local a = {x = 0, y = 0, vx = 10, vy = 0}
        local b = {x = 100, y = 0, vx = 0, vy = 0}
        local applied = particle.applyViscosity(a, b, 1.0, 0.5, 1)
        t.assert.falsy(applied)
        t.assert.eq(a.vx, 10)
        t.assert.eq(b.vx, 0)
    end)

    t.it("separates overlapping particles", function()
        local a = {x = 0, y = 0, vx = 0, vy = 0}
        local b = {x = 0.5, y = 0, vx = 0, vy = 0}
        particle.applyViscosity(a, b, 1.0, 0.02, 1)
        -- particles should have been pushed apart
        t.assert.truthy(b.x - a.x > 0.5)
    end)
end)
```

- [ ] **Step 6: Run water tests**

Run: `cd /Users/centurygame/work/love2d-play && make unit-test GAME=water`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add games/water/src/particle.lua games/water/main.lua games/water/conf.lua games/water/tests/test_particle.lua
git commit -m "refactor: extract water particle physics, add unit tests"
```

---

### Task 16: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add testing section to CLAUDE.md**

Append the following to the end of `CLAUDE.md`:

```markdown

## Testing

```bash
make test GAME=<name>              # Run all tests (unit + integration)
make unit-test GAME=<name>         # Run unit tests only (pure Lua, via luajit)
make integration-test GAME=<name>  # Run integration tests (Love2D headless)
make test-all                      # Run all tests for all games
```

Test file conventions:
- `games/<name>/tests/test_*.lua` — unit tests (pure Lua, no `love.*` dependency)
- `games/<name>/tests/integration_*.lua` — integration tests (needs Love2D)

Exit code: 0 = all passed, 1 = failures exist. Last output line is always `RESULTS: N passed, N failed, N skipped (N total)`.

### Writing tests

Tests use the framework in `shared/testing/`:

```lua
local t = require "testing"

t.describe("Feature", function()
    t.it("does something", function()
        t.assert.eq(1 + 1, 2)
    end)
end)
```

Available assertions: `eq`, `neq`, `near`, `truthy`, `falsy`, `errors`, `contains`, `type`, `vec_near`, `match`.

Mock utilities in `require "testing.mock"`: `mock.spy([fn])`, `mock.stub(obj, name, fn)`.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add testing section to CLAUDE.md"
```

---

### Task 17: Final Verification

- [ ] **Step 1: Run all tests**

Run: `cd /Users/centurygame/work/love2d-play && make test-all`
Expected: All games with tests pass. Output shows results for template, physics-testbed, blocks, water, and framework self-tests.

- [ ] **Step 2: Verify each game still runs**

Run each game one at a time to confirm no regressions:
```bash
make run GAME=template       # close after confirming it loads
make run GAME=physics-testbed # close after confirming it loads
make run GAME=blocks         # close after confirming it loads
make run GAME=water          # close after confirming it loads
```

- [ ] **Step 3: Final commit (if any fixups needed)**

Only if previous verification revealed issues that were fixed.

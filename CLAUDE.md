# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Love2D game development monorepo. Multiple game projects share vendor libraries and common code. Uses Love2D 11.4 with LuaJIT runtime.

## Commands

```bash
make run GAME=<name>          # Run a game (e.g., make run GAME=physics-testbed)
make new GAME=<name>          # Scaffold a new game project
make pack GAME=<name>         # Package game into .love file (output: dist/)
make list                     # List all available games
make update-submodules        # Update vendor git submodules
```

On macOS, Love2D binary is at `/Applications/love.app/Contents/MacOS/love`.

## Architecture

**Monorepo structure:** Each game lives in `games/<name>/` and shares libraries from `vendor/` and `shared/`.

**Require path convention:** Every game's `conf.lua` sets up `package.path` so that:
- `require "foo"` resolves from `src/foo.lua` (game-local)
- `require "hump.timer"` resolves from `vendor/hump/timer.lua`
- `require "utils.math"` resolves from `shared/utils/math.lua`

This is the critical monorepo path setup pattern (must be in `conf.lua`):
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

**Game src/ organization convention:**
- `core/` - engine systems (timer, input, camera, map)
- `entity/` - game objects (player, enemy)
- `scene/` - game states (menu, game) using HUMP gamestate
- `system/` - game logic systems (bullet, battle)
- `util/` - helpers

## Vendor Libraries

Git submodules in `vendor/`:
- **hump** - gamestate, timer, camera, class, vector, signal (most commonly used)
- **suit** - immediate-mode GUI (used in physics-testbed debug UI)
- **sti** - Tiled map loader
- **lf** - LoveFrames GUI

## Love2D Physics API

Uses Box2D via `love.physics`. Bodies are created through the module, not the world object:
```lua
-- Correct:
local body = love.physics.newBody(world, x, y, "dynamic")
local shape = love.physics.newRectangleShape(w, h)
local fixture = love.physics.newFixture(body, shape, density)

-- Wrong: world:newBody() does not exist
```

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

## Code Style

- 4-space indentation in Lua files
- `love` is a global (no need to require it)
- Type hints via LuaLS annotations: `---@class`, `---@param`, `---@return`

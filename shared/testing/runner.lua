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

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

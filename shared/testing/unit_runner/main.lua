-- shared/testing/unit_runner/main.lua
-- Unit test runner using Love2D headless mode (cross-platform, no standalone lua needed)
-- Usage: love shared/testing/unit_runner --game=<name>

local testing = require "testing"

local function parse_args()
    for _, v in ipairs(arg or {}) do
        local name = v:match("^%-%-game=(.+)$")
        if name then return name end
    end
    return nil
end

-- Cross-platform file discovery (works on Windows and Unix)
local function discover_tests(dir, pattern)
    local files = {}
    local is_windows = package.config:sub(1, 1) == "\\"
    local handle
    if is_windows then
        -- dir /b /s lists files matching pattern recursively
        local cmd = 'dir /b /s "' .. dir:gsub("/", "\\") .. "\\" .. pattern .. '" 2>nul'
        handle = io.popen(cmd)
    else
        handle = io.popen('find "' .. dir .. '" -name "' .. pattern .. '" -type f 2>/dev/null | sort')
    end
    if handle then
        for line in handle:lines() do
            -- Normalize backslashes to forward slashes for consistency
            files[#files + 1] = line:gsub("\\", "/")
        end
        handle:close()
    end
    return files
end

function love.load()
    local game_name = parse_args()
    if not game_name then
        io.stderr:write("Usage: love shared/testing/unit_runner --game=<name>\n")
        love.event.quit(1)
        return
    end

    local source = love.filesystem.getSource()
    local root   = source .. "/../../../"
    local game_dir  = root .. "games/" .. game_name
    local test_dir  = game_dir .. "/tests"
    local src_dir   = game_dir .. "/src"

    -- Add game src dir to package.path
    package.path = src_dir .. "/?.lua;"
        .. src_dir .. "/?/init.lua;"
        .. package.path

    local files = discover_tests(test_dir, "test_*.lua")

    if #files == 0 then
        print("No unit test files found in: " .. test_dir)
        print("")
        print("RESULTS: 0 passed, 0 failed, 0 skipped (0 total)")
        love.event.quit(0)
        return
    end

    local all_ok = true
    for _, file in ipairs(files) do
        print("--- " .. file .. " ---")
        local fn, err = loadfile(file)
        if fn then
            local ok, run_err = xpcall(fn, function(e)
                return e .. "\n" .. debug.traceback("", 2)
            end)
            if not ok then
                print("[ERROR] " .. file .. ": " .. tostring(run_err))
                all_ok = false
            end
        else
            print("[ERROR] " .. file .. ": " .. tostring(err))
            all_ok = false
        end
    end

    local passed = testing.print_summary()
    love.event.quit((passed and all_ok) and 0 or 1)
end

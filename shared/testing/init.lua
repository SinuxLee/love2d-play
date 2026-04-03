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

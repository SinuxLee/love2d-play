---@class TestRunner
local T = {}

---@type integer
local passed = 0
---@type integer
local failed = 0
---@type string[]
local errors = {}
---@type string
local currentDescribe = ""

---@param name string
---@param fn fun()
function T.describe(name, fn)
    currentDescribe = name
    print("\n=== " .. name .. " ===")
    fn()
end

---@param name string
---@param fn fun()
function T.it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  [PASS] " .. name)
    else
        failed = failed + 1
        print("  [FAIL] " .. name)
        print("         " .. tostring(err))
        table.insert(errors, currentDescribe .. " > " .. name .. ": " .. tostring(err))
    end
end

---@param actual any
---@param expected any
---@param msg? string
function T.assert_equal(actual, expected, msg)
    if actual ~= expected then
        error((msg or "assert_equal") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

---@param val any
---@param msg? string
function T.assert_true(val, msg)
    if not val then
        error((msg or "assert_true") .. ": expected truthy, got " .. tostring(val), 2)
    end
end

---@param val any
---@param msg? string
function T.assert_false(val, msg)
    if val then
        error((msg or "assert_false") .. ": expected falsy, got " .. tostring(val), 2)
    end
end

---@param val any
---@param msg? string
function T.assert_nil(val, msg)
    if val ~= nil then
        error((msg or "assert_nil") .. ": expected nil, got " .. tostring(val), 2)
    end
end

---@param val any
---@param msg? string
function T.assert_not_nil(val, msg)
    if val == nil then
        error((msg or "assert_not_nil") .. ": expected non-nil", 2)
    end
end

---@param actual number
---@param expected number
---@param tolerance? number
---@param msg? string
function T.assert_near(actual, expected, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(actual - expected) > tolerance then
        error((msg or "assert_near") .. ": expected ~" .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

---@return boolean allPassed
function T.summary()
    print("\n" .. string.rep("-", 40))
    print("Results: " .. passed .. " passed, " .. failed .. " failed")
    if #errors > 0 then
        print("\nFailures:")
        for _, e in ipairs(errors) do
            print("  - " .. e)
        end
    end
    print(string.rep("-", 40))
    return failed == 0
end

function T.reset()
    passed = 0
    failed = 0
    errors = {}
end

return T

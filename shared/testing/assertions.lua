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

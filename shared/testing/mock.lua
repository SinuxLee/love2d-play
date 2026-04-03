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

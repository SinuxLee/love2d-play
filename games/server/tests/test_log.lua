local t = require "testing"
local log = require "core.log"

t.describe("log", function()
    t.it("records messages with level", function()
        log._reset()
        log.info("hello %s", "world")
        local entries = log._entries()
        t.assert.eq(#entries, 1)
        t.assert.eq(entries[1].level, "INFO")
        t.assert.contains(entries[1].msg, "hello world")
    end)

    t.it("keeps only last 200 entries", function()
        log._reset()
        for i = 1, 210 do log.info("msg %d", i) end
        t.assert.eq(#log._entries(), 200)
    end)

    t.it("warn and error levels work", function()
        log._reset()
        log.warn("w")
        log.error("e")
        local entries = log._entries()
        t.assert.eq(entries[1].level, "WARN")
        t.assert.eq(entries[2].level, "ERROR")
    end)
end)

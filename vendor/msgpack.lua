-- Shim: makes `require "msgpack"` work by loading lua-msgpack/msgpack.lua
-- relative to this file's location.
local here = debug.getinfo(1, "S").source:match("^@(.-)msgpack%.lua$") or ""
return dofile(here .. "lua-msgpack/msgpack.lua")

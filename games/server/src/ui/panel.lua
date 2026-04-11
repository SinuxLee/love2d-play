local suit = require "suit"

---@class Panel
---@field sched table
---@field start_time number
---@field selected_room integer|nil
---@field announce_text table
---@field _rooms table[]
local Panel = {}
Panel.__index = Panel

function Panel.new(sched, start_time)
    return setmetatable({
        sched          = sched,
        start_time     = start_time,
        selected_room  = nil,
        announce_text  = {text = ""},
        _rooms         = {},
    }, Panel)
end

--- Called from love.update — refresh room snapshot
function Panel:set_rooms(rooms)
    self._rooms = rooms or {}
end

--- Called from love.draw
function Panel:draw()
    local W, H    = love.graphics.getDimensions()
    local log_mod = require "core.log"
    local entries = log_mod._entries()
    local uptime  = love.timer.getTime() - self.start_time

    local PAD  = 8
    local ROW  = 22
    local COL1 = PAD
    local COL2 = math.floor(W * 0.5) + PAD
    local HALF = math.floor(W * 0.5) - PAD * 2

    -- ── Status bar ──────────────────────────────────────
    suit.layout:reset(COL1, PAD, 4, 4)
    suit.Label(
        string.format("Game Server  |  port:12345  |  services:%d  |  uptime:%.0fs",
            self.sched:service_count(), uptime),
        {align = "left"},
        suit.layout:row(W - PAD * 2, ROW))

    -- ── Left column: room list ───────────────────────────
    local list_top = PAD + ROW + 8
    suit.layout:reset(COL1, list_top, 4, 4)
    suit.Label("Rooms", {align = "left"}, suit.layout:row(HALF, ROW))

    if #self._rooms == 0 then
        suit.Label("  (no rooms)", {align = "left"}, suit.layout:row(HALF, ROW))
    else
        for _, r in ipairs(self._rooms) do
            local label  = string.format("[%d] %s  (%d/%d)", r.id, r.name, r.count, r.max)
            local btn    = suit.Button(label, suit.layout:row(HALF, ROW))
            if btn.hit then
                self.selected_room = r.id
            end
        end
    end

    -- ── Right column: selected room detail ──────────────
    suit.layout:reset(COL2, list_top, 4, 4)
    local title = self.selected_room
        and ("Room #" .. self.selected_room)
        or  "Select a room"
    suit.Label(title, {align = "left"}, suit.layout:row(HALF, ROW))

    -- ── Announce bar ────────────────────────────────────
    local ann_y = H - ROW * 2 - PAD * 4
    suit.layout:reset(COL1, ann_y, 4, 4)
    suit.Label("Announce:", {align = "left"}, suit.layout:col(80, ROW))
    suit.Input(self.announce_text,  suit.layout:col(W - 200, ROW))
    local send_btn = suit.Button("Send", suit.layout:col(100 - PAD, ROW))
    if send_btn.hit and #self.announce_text.text > 0 then
        require("core.log").info("[ANNOUNCE] %s", self.announce_text.text)
        self.announce_text.text = ""
    end

    -- ── Log panel ───────────────────────────────────────
    local log_y   = H - ROW * 1 - PAD * 2
    local n_lines = 4
    local start_i = math.max(1, #entries - n_lines + 1)
    suit.layout:reset(COL1, log_y - (n_lines - 1) * (ROW - 4), 4, 2)
    for i = start_i, #entries do
        local e   = entries[i]
        local col = e.level == "ERROR" and {1, 0.3, 0.3, 1}
                 or e.level == "WARN"  and {1, 0.8, 0,   1}
                 or {0.75, 0.75, 0.75, 1}
        suit.Label(
            string.format("[%s] %s", e.level, e.msg),
            {align = "left", color = {normal = {fg = col}}},
            suit.layout:row(W - PAD * 2, ROW - 4))
    end

    suit.draw()
end

return Panel

local UI = require("ui.widgets")
local Level = require("systems.level")
local Logger = require("tools.logger")
local Hints = require("systems.hints")

---@class GM
---@field visible boolean
---@field panelX number
---@field panelY number
---@field panelW number
---@field panelH number
local GM = {}
GM.visible = false
GM.panelX = 410
GM.panelY = 70
GM.panelW = 220
GM.panelH = 460

-- Collapse state for each section
local sections = {
    details = false,
    ml = true,
    autoplay = false,
}

-- Drag state
local dragging = false
local dragOffsetX = 0
local dragOffsetY = 0
local TITLE_BAR_H = 28

function GM.toggle()
    GM.visible = not GM.visible
end

---Save panel position and collapse state to disk
function GM.saveConfig()
    if not (love and love.filesystem and love.filesystem.write) then return end
    local data = string.format(
        "return {panelX=%d,panelY=%d,details=%s,ml=%s,autoplay=%s}\n",
        GM.panelX, GM.panelY,
        sections.details and "true" or "false",
        sections.ml and "true" or "false",
        sections.autoplay and "true" or "false"
    )
    love.filesystem.write("gm_config.lua", data)
end

---Load panel position and collapse state from disk
function GM.loadConfig()
    if not (love and love.filesystem and love.filesystem.load) then return end
    if not love.filesystem.getInfo("gm_config.lua") then return end
    local ok, fn = pcall(love.filesystem.load, "gm_config.lua")
    if not ok or not fn then return end
    local ok2, cfg = pcall(fn)
    if not ok2 or type(cfg) ~= "table" then return end
    GM.panelX = cfg.panelX or GM.panelX
    GM.panelY = cfg.panelY or GM.panelY
    if cfg.details ~= nil then sections.details = cfg.details end
    if cfg.ml ~= nil then sections.ml = cfg.ml end
    if cfg.autoplay ~= nil then sections.autoplay = cfg.autoplay end
end

---Check if a point is inside the GM panel bounds
---@param x number
---@param y number
---@return boolean
function GM.hitTest(x, y)
    if not GM.visible then return false end
    return x >= GM.panelX and x <= GM.panelX + GM.panelW
        and y >= GM.panelY and y <= GM.panelY + GM.panelH
end

---Draw the GM debug panel. Called each frame when visible.
---@param states States
---@param autoplay Autoplay
function GM.draw(states, autoplay)
    if not GM.visible then return end
    if not UI.initialized then return end

    local px, py, pw = GM.panelX, GM.panelY, GM.panelW
    local pad = 10
    local x = px + pad
    local w = pw - pad * 2
    local y = py
    local mx, my = UI.mouseX, UI.mouseY

    -- ── Drag handling on title bar ──
    if not dragging then
        if UI.mousePressed
            and mx >= px and mx <= px + pw
            and my >= py and my <= py + TITLE_BAR_H then
            dragging = true
            dragOffsetX = mx - px
            dragOffsetY = my - py
        end
    end
    if dragging then
        if UI.mouseDown then
            local ww = love.graphics.getWidth()
            local wh = love.graphics.getHeight()
            GM.panelX = math.max(0, math.min(ww - pw, mx - dragOffsetX))
            GM.panelY = math.max(0, math.min(wh - 50, my - dragOffsetY))
            px = GM.panelX
            py = GM.panelY
            x = px + pad
        else
            dragging = false
            GM.saveConfig()
        end
    end

    -- Panel background (drawn with estimated height, adjusted at end)
    UI.panel(px, py, pw, GM.panelH)
    y = y + 8

    -- ── Title ──
    local titleColor = dragging and {0.2, 1, 0.8, 1} or {0, 1, 0.6, 1}
    UI.label(x, y, "GM DEBUG PANEL", titleColor)
    y = y + 22

    -- ── Always-visible summary ──
    local bias = states.getEffectiveBias()
    local biasLabel = bias >= 0 and "+" or ""
    UI.smallLabel(x, y, string.format("Lv%d  %s%.2f  Fails:%d  %dG %dx%d",
        Level.current.number, biasLabel, bias, states.failCount,
        Level.current.numGemTypes, Level.current.gridSize, Level.current.gridSize),
        {0.6, 0.8, 1, 1})
    y = y + 18

    -- ── ML Difficulty section ──
    local hdr
    sections.ml, hdr = UI.collapseHeader("sec_ml", x, y, w, "Difficulty (ML)", sections.ml)
    y = y + hdr

    if sections.ml then
        -- ML toggle
        local newMl = UI.checkbox("ml_enabled", x, y, "ML Enabled", states.mlEnabled)
        if newMl ~= states.mlEnabled then
            states.mlEnabled = newMl
            Logger.info("gm", "ml_toggle", {enabled = newMl})
        end
        y = y + 22

        -- Hints toggle
        local newHints = UI.checkbox("hints_enabled", x, y, "Hints", Hints.enabled)
        if newHints ~= Hints.enabled then
            Hints.enabled = newHints
            Logger.info("gm", "hints_toggle", {enabled = newHints})
        end
        y = y + 24

        -- Profile info
        local prof = states.mlProfile
        if prof then
            local archClr = {0.6, 0.8, 1, 1}
            if prof.archetype == "casual" then archClr = {0.4, 1, 0.6, 1}
            elseif prof.archetype == "hardcore" then archClr = {1, 0.7, 0.3, 1}
            elseif prof.archetype == "expert" then archClr = {1, 0.4, 0.4, 1}
            end
            UI.smallLabel(x, y, string.format("Archetype: %s", prof.archetype), archClr)
            y = y + 14
            -- SkillScore with trend indicator
            local trend = ""
            if states.mlPrevSkillScore then
                local delta = prof.skillScore - states.mlPrevSkillScore
                if delta > 0.01 then trend = " ^"
                elseif delta < -0.01 then trend = " v"
                else trend = " -"
                end
            end
            UI.smallLabel(x, y, string.format("Skill: %.2f%s  Frust: %.2f", prof.skillScore, trend, prof.frustration))
            y = y + 14
            UI.smallLabel(x, y, string.format("ScoreEff: %.2f  MoveEff: %.2f", prof.scoreEfficiency, prof.moveEfficiency))
            y = y + 14
            UI.smallLabel(x, y, string.format("Combo: %.2f  Special: %.2f", prof.comboSkill, prof.specialSkill))
            y = y + 14
            UI.smallLabel(x, y, string.format("PassRate: %.2f  Attempts: %d", prof.passRate, prof.totalAttempts))
            y = y + 16
        end

        -- Bandit info
        local bandit = states.mlBandit
        if bandit then
            UI.smallLabel(x, y, string.format("Skill Est: mu=%.1f sig=%.1f", bandit.skill.mu, bandit.skill.sigma),
                {0.7, 0.8, 1, 1})
            y = y + 16

            -- Last decision
            local dec = states.mlLastDecision
            if dec then
                local biasStr = dec.bias >= 0 and string.format("+%.2f", dec.bias) or string.format("%.2f", dec.bias)
                UI.smallLabel(x, y, string.format("Arm: %d/%d  Bias: %s  Tier: %d",
                    dec.arm, #bandit.biasValues, biasStr, dec.tier), {0.8, 0.9, 0.6, 1})
                y = y + 14
                if dec.safetyValve then
                    UI.smallLabel(x, y, "SAFETY VALVE ACTIVE", {1, 0.3, 0.3, 1})
                    y = y + 14
                end
                if bandit.useFallback then
                    local fb = bandit.fallbackInfo
                    UI.smallLabel(x, y, string.format("FALLBACK: -%d pts +%d moves",
                        fb.targetReduction or 0, fb.bonusMoves or 0), {1, 0.6, 0.2, 1})
                    y = y + 14
                end
            end
            y = y + 2

            -- Decision explanation text
            if states.mlDecisionText then
                UI.smallLabel(x, y, states.mlDecisionText, {0.8, 0.8, 0.5, 0.9})
                y = y + 14
            end

            -- Arm states for current tier (compact: a/b)
            local tier = bandit.lastTier
            local arms = bandit.tiers[tier]
            if arms then
                UI.smallLabel(x, y, string.format("Tier %d arms (a/b):", tier), {0.5, 0.6, 0.7, 0.8})
                y = y + 14
                for i = 1, #arms do
                    local a = arms[i]
                    local biasVal = bandit.biasValues[i]
                    local biasLbl = biasVal >= 0 and string.format("+%.2f", biasVal) or string.format("%.2f", biasVal)
                    local selected = (dec and dec.arm == i)
                    local clr = selected and {0.3, 1, 0.5, 1} or {0.5, 0.55, 0.65, 0.8}
                    local marker = selected and ">" or " "
                    UI.smallLabel(x, y, string.format("%s%s %.1f/%.1f", marker, biasLbl, a.alpha, a.beta), clr)
                    y = y + 13
                end
            end
        end

        -- Profile weight tuning
        y = y + 4
        UI.separator(x, y, w)
        y = y + 6
        UI.smallLabel(x, y, "Profile Weights:", {0.6, 0.7, 0.9, 0.9})
        y = y + 14
        local Profile = require("systems.profile")
        local weightNames = {"scoreEff", "moveEff", "combo", "special", "passRate"}
        local weightLabels = {"ScoreEff", "MoveEff", "Combo", "Special", "PassRate"}
        for wi = 1, #weightNames do
            local wKey = weightNames[wi]
            local wVal = Profile.weights[wKey]
            UI.smallLabel(x, y, string.format("%s: %.2f", weightLabels[wi], wVal), {0.6, 0.65, 0.75, 0.9})
            local btnW = 24
            local btnX = x + w - btnW * 2 - 4
            if UI.button("w_down_" .. wKey, btnX, y - 2, btnW, 16, "-") then
                Profile.weights[wKey] = math.max(0, wVal - 0.05)
                states.mlProfile:recomputeSkillScore()
            end
            if UI.button("w_up_" .. wKey, btnX + btnW + 2, y - 2, btnW, 16, "+") then
                Profile.weights[wKey] = math.min(1, wVal + 0.05)
                states.mlProfile:recomputeSkillScore()
            end
            y = y + 18
        end

        y = y + 4
        if UI.button("reset_fails", x, y, w, 26, "Reset Fails") then
            Logger.info("gm", "reset_fails", {prev_count = states.failCount})
            states.failCount = 0
        end
        y = y + 32
    end

    -- ── Level Details section (modifiers / objectives / score mult) ──
    sections.details, hdr = UI.collapseHeader("sec_details", x, y, w, "Level Details", sections.details)
    y = y + hdr

    if sections.details then
        -- Modifiers
        local mods = Level.current.modifiers
        if mods and #mods > 0 then
            UI.smallLabel(x, y, "Modifiers:", {0.8, 0.6, 1, 1})
            y = y + 14
            for _, m in ipairs(mods) do
                UI.smallLabel(x + 8, y, "- " .. m, {0.7, 0.7, 0.9, 0.9})
                y = y + 13
            end
            y = y + 2
        else
            UI.smallLabel(x, y, "Modifiers: none", {0.5, 0.5, 0.6, 0.7})
            y = y + 16
        end

        -- Objectives progress
        local objs = Level.current.objectives
        if objs and #objs > 0 then
            UI.smallLabel(x, y, "Objectives:", {0.8, 0.8, 0.4, 1})
            y = y + 14
            for _, obj in ipairs(objs) do
                local current = 0
                if obj.type == "score" then
                    current = states.score
                elseif obj.type == "collect" then
                    current = states.collected[obj.gemType] or 0
                elseif obj.type == "combo" then
                    current = states.maxCombo
                elseif obj.type == "moves_left" then
                    current = states.movesLeft
                elseif obj.type == "specials" then
                    current = states.specialsCreated
                end
                local done = current >= obj.target
                local clr = done and {0.4, 1, 0.5, 0.9} or {0.7, 0.7, 0.8, 0.8}
                local icon = done and "+" or "-"
                UI.smallLabel(x + 8, y, string.format("%s %s %d/%d", icon, obj.type, current, obj.target), clr)
                y = y + 13
            end
            y = y + 2
        end

        -- Score multiplier if not 1.0
        if Level.current.scoreMultiplier and Level.current.scoreMultiplier ~= 1.0 then
            UI.smallLabel(x, y, string.format("ScoreMult: %.1fx", Level.current.scoreMultiplier), {1, 0.8, 0.4, 0.9})
            y = y + 16
        end

        y = y + 2
    end

    -- ── Auto-Play section ──
    sections.autoplay, hdr = UI.collapseHeader("sec_autoplay", x, y, w, "Auto-Play", sections.autoplay)
    y = y + hdr

    if sections.autoplay then
        -- Toggle
        local newEnabled = UI.checkbox("autoplay", x, y, "Enabled", autoplay.enabled)
        if newEnabled ~= autoplay.enabled then
            autoplay.enabled = newEnabled
            if newEnabled then
                autoplay.reset()
            end
            Logger.info("gm", "autoplay_toggle", {enabled = newEnabled, strategy = autoplay.currentStrategy})
        end
        y = y + 24

        -- Strategy radio group
        local stratNames = autoplay.getStrategyNames()
        if #stratNames > 0 then
            UI.smallLabel(x, y, "Strategy:")
            y = y + 16
            local stratIdx = autoplay.getStrategyIndex()
            local newStratIdx = UI.radioGroup("strategy", x + 4, y, stratNames, stratIdx)
            if newStratIdx ~= stratIdx then
                autoplay.setStrategyByIndex(newStratIdx)
                Logger.info("gm", "strategy_change", {strategy = stratNames[newStratIdx]})
            end
            y = y + #stratNames * 22 + 4
        end

        -- Stats
        if autoplay.enabled or autoplay.summary.totalAttempts > 0 then
            UI.separator(x, y, w)
            y = y + 6
            UI.smallLabel(x, y, "Stats:", {0.6, 0.8, 1, 1})
            y = y + 16

            local s = autoplay.summary
            UI.smallLabel(x, y, string.format("Level moves: %d", autoplay.levelMoves))
            y = y + 14

            if s.totalAttempts > 0 then
                UI.smallLabel(x, y, string.format("Attempts: %d  P:%d F:%d",
                    s.totalAttempts, s.totalPasses, s.totalFails))
                y = y + 14
                UI.smallLabel(x, y, string.format("Pass rate: %.0f%%", s.passRate * 100))
                y = y + 14

                if s.totalPasses > 0 then
                    UI.smallLabel(x, y, string.format("Avg moves/pass: %.1f", s.avgMovesPerPass))
                    y = y + 14
                    UI.smallLabel(x, y, string.format("Avg score/pass: %.0f", s.avgScorePerPass))
                    y = y + 14
                end

                local streakLabel = s.currentStreak > 0
                    and string.format("%dW", s.currentStreak)
                    or s.currentStreak < 0 and string.format("%dL", -s.currentStreak)
                    or "-"
                UI.smallLabel(x, y, string.format("Streak: %s  Reached: Lv%d",
                    streakLabel, s.levelsReached))
                y = y + 14

                -- Recent log entries
                UI.separator(x, y + 2, w)
                y = y + 8
                UI.smallLabel(x, y, "Recent:", {0.6, 0.8, 1, 1})
                y = y + 14
                local logLen = #autoplay.log
                local showCount = math.min(5, logLen)
                for i = 0, showCount - 1 do
                    local rec = autoplay.log[logLen - i]
                    local icon = rec.result == "pass" and "+" or "x"
                    local biasStr = rec.bias >= 0 and string.format("+%.2f", rec.bias) or string.format("%.2f", rec.bias)
                    local color = rec.result == "pass" and {0.4, 1, 0.5, 0.8} or {1, 0.5, 0.4, 0.8}
                    UI.smallLabel(x, y, string.format("%s Lv%d %d/%d b:%s f:%d",
                        icon, rec.level, rec.score, rec.targetScore, biasStr, rec.failCount), color)
                    y = y + 13
                end

                -- Reset stats button
                y = y + 4
                if UI.button("reset_stats", x, y, w, 22, "Reset Stats") then
                    autoplay.resetAll()
                end
                y = y + 28
            end
        end
    end

    -- ── Footer ──
    y = y + 4
    UI.smallLabel(x, y, "[F1] Toggle Panel", {0.4, 0.45, 0.55, 0.7})
    y = y + 16

    -- Adjust panel height for next frame
    GM.panelH = y - py + 8
end

return GM

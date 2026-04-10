local T = require("tools.test_runner")
local Level = require("systems.level")
local Modifiers = require("systems.modifiers")

T.describe("Level.generate", function()
    T.it("level 1 has 5 gem types", function()
        local cfg = Level.generate(1)
        T.assert_equal(cfg.numGemTypes, 5)
    end)

    T.it("level 8 still has 5 gem types", function()
        local cfg = Level.generate(8)
        T.assert_equal(cfg.numGemTypes, 5)
    end)

    T.it("level 9 has 6 gem types", function()
        local cfg = Level.generate(9)
        T.assert_equal(cfg.numGemTypes, 6)
    end)

    T.it("level 24 still has 6 gem types", function()
        local cfg = Level.generate(24)
        T.assert_equal(cfg.numGemTypes, 6)
    end)

    T.it("level 25 base has 7 gem types", function()
        local cfg = Level.generateBase(25)
        T.assert_equal(cfg.numGemTypes, 7)
    end)

    T.it("level 50 base caps at 7 gem types", function()
        local cfg = Level.generateBase(50)
        T.assert_equal(cfg.numGemTypes, 7)
    end)

    T.it("target score increases within each phase", function()
        -- Phase 1 (5 gems)
        local s1 = Level.generate(1).targetScore
        local s8 = Level.generate(8).targetScore
        T.assert_true(s8 > s1, "level 8 target > level 1")
        -- Phase 2 (6 gems)
        local s9 = Level.generate(9).targetScore
        local s18 = Level.generate(18).targetScore
        T.assert_true(s18 > s9, "level 18 target > level 9")
        -- Phase 3 (7 gems)
        local s30 = Level.generate(30).targetScore
        local s50 = Level.generate(50).targetScore
        T.assert_true(s50 > s30, "level 50 target > level 30")
    end)

    T.it("base target drops at gem-type transitions (breathing room)", function()
        local s8 = Level.generateBase(8).targetScore
        local s9 = Level.generateBase(9).targetScore
        T.assert_true(s9 < s8, "level 9 target should be less than level 8 (6-gem transition)")
        local s24 = Level.generateBase(24).targetScore
        local s25 = Level.generateBase(25).targetScore
        T.assert_true(s25 < s24, "level 25 target should be less than level 24 (7-gem transition)")
    end)

    T.it("base target growth is asymptotic (approaches cap)", function()
        -- 6-gem phase: growth should slow down (use base to avoid modifier interference)
        local s10 = Level.generateBase(10).targetScore
        local s15 = Level.generateBase(15).targetScore
        local s20 = Level.generateBase(20).targetScore
        local earlyGrowth = s15 - s10    -- first 5 levels
        local lateGrowth = s20 - s15     -- next 5 levels
        T.assert_true(lateGrowth < earlyGrowth, "6-gem target growth should decelerate")
    end)

    T.it("moves decrease with level but respect phase floors", function()
        local m1 = Level.generate(1).maxMoves
        local m15 = Level.generate(15).maxMoves
        local m50 = Level.generate(50).maxMoves
        T.assert_true(m1 > m15, "level 1 has more moves than level 15")
        T.assert_true(m50 >= 15, "level 50 should have at least 15 moves")
        -- 6-gem floor is 18
        local m20 = Level.generate(20).maxMoves
        T.assert_true(m20 >= 18, "6-gem level should have at least 18 moves")
    end)

    T.it("transition levels get bonus moves", function()
        local m8 = Level.generate(8).maxMoves
        local m9 = Level.generate(9).maxMoves
        T.assert_true(m9 >= m8, "level 9 should have >= moves as level 8 (transition bonus)")
    end)

    T.it("early levels have positive dropBias", function()
        local b1 = Level.generate(1).dropBias
        T.assert_true(b1 > 0, "level 1 should have positive bias")
    end)

    T.it("mid levels have neutral dropBias", function()
        local b10 = Level.generate(10).dropBias
        T.assert_equal(b10, 0, "level 10 should have neutral bias")
    end)

    T.it("late 6-gem levels have slight negative dropBias", function()
        local b20 = Level.generate(20).dropBias
        T.assert_true(b20 < 0, "level 20 should have negative bias")
    end)

    T.it("early 7-gem levels have slight positive dropBias (compensation)", function()
        local b26 = Level.generate(26).dropBias
        T.assert_true(b26 > 0, "level 26 should have positive bias for 7-gem compensation")
    end)
end)

T.describe("Level.start / next / retry", function()
    T.it("start sets current level", function()
        Level.start(3)
        T.assert_equal(Level.current.number, 3)
    end)

    T.it("next advances level number", function()
        Level.start(5)
        Level.next()
        T.assert_equal(Level.current.number, 6)
    end)

    T.it("retry keeps same level number", function()
        Level.start(7)
        Level.retry()
        T.assert_equal(Level.current.number, 7)
    end)

    T.it("maxReached tracks highest level", function()
        Level.maxReached = 1
        Level.start(3)
        Level.start(1)
        T.assert_equal(Level.maxReached, 3, "maxReached should stay at 3")
    end)
end)

-- ================================================================
-- Modifier tests
-- ================================================================
T.describe("Modifiers.assign", function()
    T.it("levels 1-9 have no modifiers", function()
        for lv = 1, 9 do
            local mods = Modifiers.assign(lv)
            T.assert_equal(#mods, 0, "level " .. lv .. " should have 0 modifiers")
        end
    end)

    T.it("levels 10-24 have exactly 1 modifier from mild pool", function()
        local mildSet = {}
        for _, n in ipairs(Modifiers.mildPool) do mildSet[n] = true end
        for lv = 10, 24 do
            local mods = Modifiers.assign(lv)
            T.assert_equal(#mods, 1, "level " .. lv .. " should have 1 modifier")
            T.assert_true(mildSet[mods[1]] == true, "level " .. lv .. " modifier should be from mild pool: " .. mods[1])
        end
    end)

    T.it("levels 50+ have exactly 2 modifiers", function()
        for lv = 50, 55 do
            local mods = Modifiers.assign(lv)
            T.assert_equal(#mods, 2, "level " .. lv .. " should have 2 modifiers")
        end
    end)

    T.it("same level always produces same modifiers (deterministic)", function()
        local m1 = Modifiers.assign(15)
        local m2 = Modifiers.assign(15)
        T.assert_equal(#m1, #m2)
        for i = 1, #m1 do
            T.assert_equal(m1[i], m2[i], "modifier " .. i .. " should be identical")
        end
    end)

    T.it("exclusive modifiers are never assigned together", function()
        for lv = 25, 80 do
            local mods = Modifiers.assign(lv)
            if #mods >= 2 then
                for i = 1, #mods do
                    local def = Modifiers.defs[mods[i]]
                    if def and def.exclusive then
                        for _, ex in ipairs(def.exclusive) do
                            for j = 1, #mods do
                                if j ~= i then
                                    T.assert_true(mods[j] ~= ex,
                                        "level " .. lv .. ": " .. mods[i] .. " and " .. ex .. " should not coexist")
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end)

T.describe("Modifiers.apply", function()
    T.it("color_limit reduces gem types and increases target", function()
        local cfg = Level.generate(1)
        local origTypes = cfg.numGemTypes
        local origTarget = cfg.targetScore
        Modifiers.apply(cfg, {"color_limit"})
        T.assert_equal(cfg.numGemTypes, origTypes - 1)
        T.assert_true(cfg.targetScore > origTarget, "target should increase")
    end)

    T.it("big_board sets gridSize to 9", function()
        local cfg = Level.generate(1)
        Modifiers.apply(cfg, {"big_board"})
        T.assert_equal(cfg.gridSize, 9)
    end)

    T.it("small_board sets gridSize to 6", function()
        local cfg = Level.generate(1)
        Modifiers.apply(cfg, {"small_board"})
        T.assert_equal(cfg.gridSize, 6)
    end)

    T.it("fragile reduces moves and increases scoreMultiplier", function()
        local cfg = Level.generate(1)
        local origMoves = cfg.maxMoves
        Modifiers.apply(cfg, {"fragile"})
        T.assert_true(cfg.maxMoves < origMoves, "moves should decrease")
        T.assert_true(cfg.scoreMultiplier > 1.0, "scoreMultiplier should be > 1.0")
    end)

    T.it("generous increases dropBias and target", function()
        local cfg = Level.generate(1)
        local origBias = cfg.dropBias
        local origTarget = cfg.targetScore
        Modifiers.apply(cfg, {"generous"})
        T.assert_true(cfg.dropBias > origBias, "dropBias should increase")
        T.assert_true(cfg.targetScore > origTarget, "target should increase")
    end)
end)

-- ================================================================
-- Objective tests
-- ================================================================
T.describe("Level objectives", function()
    T.it("all levels have at least 1 objective (score)", function()
        for lv = 1, 60 do
            local cfg = Level.generate(lv)
            T.assert_true(#cfg.objectives >= 1, "level " .. lv .. " should have >= 1 objective")
            T.assert_equal(cfg.objectives[1].type, "score", "first objective should be score")
        end
    end)

    T.it("levels before 15 have only score objective", function()
        for lv = 1, 14 do
            local cfg = Level.generate(lv)
            T.assert_equal(#cfg.objectives, 1, "level " .. lv .. " should have exactly 1 objective")
        end
    end)

    T.it("some levels 15+ have secondary objectives", function()
        local hasSecondary = false
        for lv = 15, 50 do
            local cfg = Level.generate(lv)
            if #cfg.objectives > 1 then
                hasSecondary = true
                local obj = cfg.objectives[2]
                T.assert_true(
                    obj.type == "collect" or obj.type == "combo" or
                    obj.type == "specials" or obj.type == "moves_left",
                    "secondary objective should be a valid type: " .. obj.type
                )
                T.assert_true(obj.target > 0, "objective target should be positive")
                T.assert_true(#obj.description > 0, "objective should have description")
            end
        end
        T.assert_true(hasSecondary, "at least some levels 15-50 should have secondary objectives")
    end)

    T.it("LevelConfig has new fields", function()
        local cfg = Level.generate(30)
        T.assert_not_nil(cfg.modifiers, "should have modifiers field")
        T.assert_not_nil(cfg.gridSize, "should have gridSize field")
        T.assert_not_nil(cfg.scoreMultiplier, "should have scoreMultiplier field")
        T.assert_not_nil(cfg.objectives, "should have objectives field")
    end)
end)

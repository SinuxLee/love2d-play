local T = require("tools.test_runner")
local Utils = require("core.utils")
local Gem = require("core.gem")
local Tweens = require("core.animation")
local Grid = require("core.grid")

T.describe("findMatches pattern detection", function()
    T.it("3-match returns no specials", function()
        Grid.init()
        Tweens.clear()
        local t = 1
        -- Set up exactly 3 in a row at row 1, ensure col 4 is different
        Grid.cells[1][1] = Gem.new(t, 1, 1)
        Grid.cells[1][2] = Gem.new(t, 1, 2)
        Grid.cells[1][3] = Gem.new(t, 1, 3)
        Grid.cells[1][4] = Gem.new(t == 1 and 2 or 1, 1, 4)
        local _, specials = Grid.findMatches()
        -- Check no special at row 1 cols 1-3
        local hasSpecial = false
        for _, s in ipairs(specials) do
            if s.row == 1 and s.col >= 1 and s.col <= 3 then
                hasSpecial = true
            end
        end
        T.assert_false(hasSpecial, "3-match should produce no specials")
    end)

    T.it("4 horizontal match returns striped_v special", function()
        Grid.init()
        Tweens.clear()
        local t = 1
        Grid.cells[2][1] = Gem.new(t, 2, 1)
        Grid.cells[2][2] = Gem.new(t, 2, 2)
        Grid.cells[2][3] = Gem.new(t, 2, 3)
        Grid.cells[2][4] = Gem.new(t, 2, 4)
        -- Ensure neighbors are different
        Grid.cells[2][5] = Gem.new(t == 1 and 2 or 1, 2, 5)
        -- Also ensure no vertical match
        Grid.cells[1][1] = Gem.new(t == 1 and 3 or 1, 1, 1)
        Grid.cells[3][1] = Gem.new(t == 1 and 4 or 1, 3, 1)

        local _, specials = Grid.findMatches()
        local found = false
        for _, s in ipairs(specials) do
            if s.special == "striped_v" and s.row == 2 then
                found = true
            end
        end
        T.assert_true(found, "4 horizontal match should produce striped_v")
    end)

    T.it("4 vertical match returns striped_h special", function()
        Grid.init()
        Tweens.clear()
        local t = 2
        local other1, other2, other3 = 3, 4, 5
        Grid.cells[1][5] = Gem.new(t, 1, 5)
        Grid.cells[2][5] = Gem.new(t, 2, 5)
        Grid.cells[3][5] = Gem.new(t, 3, 5)
        Grid.cells[4][5] = Gem.new(t, 4, 5)
        Grid.cells[5][5] = Gem.new(other1, 5, 5)
        -- Ensure no horizontal match from column neighbors
        for row = 1, 4 do
            Grid.cells[row][4] = Gem.new(other2, row, 4)
            Grid.cells[row][6] = Gem.new(other3, row, 6)
        end

        local _, specials = Grid.findMatches()
        local found = false
        for _, s in ipairs(specials) do
            if s.special == "striped_h" and s.col == 5 then
                found = true
            end
        end
        T.assert_true(found, "4 vertical match should produce striped_h")
    end)

    T.it("5 in a row returns color_bomb", function()
        Grid.init()
        Tweens.clear()
        local t = 3
        for c = 1, 5 do
            Grid.cells[3][c] = Gem.new(t, 3, c)
        end
        Grid.cells[3][6] = Gem.new(1, 3, 6)
        -- Prevent vertical matches by ensuring neighbors differ
        for c = 1, 5 do
            Grid.cells[2][c] = Gem.new(2, 2, c)
            Grid.cells[4][c] = Gem.new(4, 4, c)
        end

        local _, specials = Grid.findMatches()
        local found = false
        for _, s in ipairs(specials) do
            if s.special == "color_bomb" then
                found = true
            end
        end
        T.assert_true(found, "5 in a row should produce color_bomb")
    end)

    T.it("L-shape match returns wrapped", function()
        Grid.init()
        Tweens.clear()
        local t = 4
        -- Horizontal: row 4, cols 3-5
        Grid.cells[4][3] = Gem.new(t, 4, 3)
        Grid.cells[4][4] = Gem.new(t, 4, 4)
        Grid.cells[4][5] = Gem.new(t, 4, 5)
        -- Vertical: rows 4-6, col 3
        Grid.cells[5][3] = Gem.new(t, 5, 3)
        Grid.cells[6][3] = Gem.new(t, 6, 3)
        -- Ensure no extensions
        Grid.cells[4][2] = Gem.new(t == 4 and 1 or 4, 4, 2)
        Grid.cells[4][6] = Gem.new(t == 4 and 2 or 4, 4, 6)
        Grid.cells[3][3] = Gem.new(t == 4 and 3 or 4, 3, 3)
        Grid.cells[7][3] = Gem.new(t == 4 and 5 or 4, 7, 3)

        local _, specials = Grid.findMatches()
        local found = false
        for _, s in ipairs(specials) do
            if s.special == "wrapped" and s.row == 4 and s.col == 3 then
                found = true
            end
        end
        T.assert_true(found, "L-shape should produce wrapped at intersection (4,3)")
    end)
end)

T.describe("activateSpecials", function()
    T.it("striped_h clears entire row", function()
        Grid.init()
        Tweens.clear()
        local gem = Grid.cells[4][4]
        gem.special = "striped_h"
        local matched = { [gem] = true }
        Grid.activateSpecials(matched)
        for c = 1, Utils.GRID_SIZE do
            T.assert_true(matched[Grid.cells[4][c]] == true,
                "cell [4][" .. c .. "] should be matched")
        end
    end)

    T.it("striped_v clears entire column", function()
        Grid.init()
        Tweens.clear()
        local gem = Grid.cells[3][6]
        gem.special = "striped_v"
        local matched = { [gem] = true }
        Grid.activateSpecials(matched)
        for r = 1, Utils.GRID_SIZE do
            T.assert_true(matched[Grid.cells[r][6]] == true,
                "cell [" .. r .. "][6] should be matched")
        end
    end)

    T.it("wrapped clears 3x3 area", function()
        Grid.init()
        Tweens.clear()
        local gem = Grid.cells[4][4]
        gem.special = "wrapped"
        local matched = { [gem] = true }
        Grid.activateSpecials(matched)
        local count = 0
        for _ in pairs(matched) do count = count + 1 end
        T.assert_equal(count, 9, "wrapped at (4,4) should match 3x3 = 9 gems")
    end)

    T.it("wrapped at corner handles bounds", function()
        Grid.init()
        Tweens.clear()
        local gem = Grid.cells[1][1]
        gem.special = "wrapped"
        local matched = { [gem] = true }
        Grid.activateSpecials(matched)
        local count = 0
        for _ in pairs(matched) do count = count + 1 end
        T.assert_equal(count, 4, "wrapped at (1,1) should match 2x2 = 4 gems")
    end)
end)

T.describe("clearColor", function()
    T.it("clears all gems of target type", function()
        Grid.init()
        Tweens.clear()
        local bombGem = Gem.new(0, 1, 1, "color_bomb")
        Grid.cells[1][1] = bombGem
        local targetType = Grid.cells[2][2].type
        local matched = Grid.clearColor(targetType, bombGem)
        -- Verify bomb is matched
        T.assert_true(matched[bombGem], "bomb should be in matched")
        -- Verify all target type gems are matched
        for row = 1, Utils.GRID_SIZE do
            for col = 1, Utils.GRID_SIZE do
                local g = Grid.cells[row][col]
                if g and g.type == targetType then
                    T.assert_true(matched[g], "gem at [" .. row .. "][" .. col .. "] should be matched")
                end
            end
        end
    end)
end)

T.describe("comboSpecials", function()
    T.it("striped + striped clears cross", function()
        Grid.init()
        Tweens.clear()
        local gem1 = Grid.cells[4][4]
        gem1.special = "striped_h"
        local gem2 = Grid.cells[4][5]
        gem2.special = "striped_v"
        Grid.swap(4, 4, 4, 5)
        local matched = Grid.comboSpecials(Grid.cells[4][4], Grid.cells[4][5])
        -- Should have full row 4 + full col 4
        for c = 1, Utils.GRID_SIZE do
            T.assert_true(matched[Grid.cells[4][c]] ~= nil,
                "row 4 col " .. c .. " should be matched")
        end
    end)
end)

T.describe("spawnSpecials", function()
    T.it("places special gem on empty cell", function()
        Grid.init()
        Tweens.clear()
        Grid.cells[3][3] = nil
        Grid.spawnSpecials({{ row = 3, col = 3, special = "striped_h", gemType = 2 }})
        T.assert_not_nil(Grid.cells[3][3], "cell should have a gem")
        T.assert_equal(Grid.cells[3][3].special, "striped_h")
        T.assert_equal(Grid.cells[3][3].type, 2)
    end)
end)

T.describe("hasValidMoves with specials", function()
    T.it("color bomb counts as valid move", function()
        Grid.init()
        Tweens.clear()
        Grid.cells[1][1] = Gem.new(0, 1, 1, "color_bomb")
        T.assert_true(Grid.hasValidMoves(), "board with color bomb should have valid moves")
    end)
end)

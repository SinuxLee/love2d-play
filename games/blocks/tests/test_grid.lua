local t = require "testing"
local pieces = require "pieces"
local grid = require "grid"

t.describe("grid.newGrid", function()
    t.it("creates 18x10 grid of spaces", function()
        local g = grid.newGrid()
        t.assert.eq(#g, 18)
        t.assert.eq(#g[1], 10)
        t.assert.eq(g[1][1], ' ')
        t.assert.eq(g[18][10], ' ')
    end)
end)

t.describe("grid.canPieceMove", function()
    t.it("allows I-piece at starting position", function()
        local g = grid.newGrid()
        t.assert.truthy(grid.canPieceMove(g, 1, 3, 0, 1))
    end)

    t.it("blocks piece past left wall", function()
        local g = grid.newGrid()
        t.assert.falsy(grid.canPieceMove(g, 1, -4, 5, 1))
    end)

    t.it("blocks piece past right wall", function()
        local g = grid.newGrid()
        t.assert.falsy(grid.canPieceMove(g, 1, 8, 5, 1))
    end)

    t.it("blocks piece past bottom", function()
        local g = grid.newGrid()
        t.assert.falsy(grid.canPieceMove(g, 1, 3, 17, 1))
    end)

    t.it("blocks piece on occupied cell", function()
        local g = grid.newGrid()
        g[2][4] = 'x'
        t.assert.falsy(grid.canPieceMove(g, 1, 3, 0, 1))
    end)

    t.it("allows O-piece in open space", function()
        local g = grid.newGrid()
        t.assert.truthy(grid.canPieceMove(g, 2, 4, 5, 1))
    end)
end)

t.describe("grid.lockPiece", function()
    t.it("writes piece cells to grid", function()
        local g = grid.newGrid()
        grid.lockPiece(g, 1, 3, 0, 1)
        t.assert.eq(g[2][4], 'i')
        t.assert.eq(g[2][5], 'i')
        t.assert.eq(g[2][6], 'i')
        t.assert.eq(g[2][7], 'i')
        t.assert.eq(g[1][4], ' ')
        t.assert.eq(g[3][4], ' ')
    end)
end)

t.describe("grid.clearFullRows", function()
    t.it("clears a full row", function()
        local g = grid.newGrid()
        for x = 1, 10 do g[18][x] = 'i' end
        local cleared = grid.clearFullRows(g)
        t.assert.eq(cleared, 1)
        for x = 1, 10 do t.assert.eq(g[18][x], ' ') end
    end)

    t.it("clears multiple full rows", function()
        local g = grid.newGrid()
        for x = 1, 10 do
            g[17][x] = 'j'
            g[18][x] = 'i'
        end
        local cleared = grid.clearFullRows(g)
        t.assert.eq(cleared, 2)
    end)

    t.it("does not clear incomplete rows", function()
        local g = grid.newGrid()
        for x = 1, 9 do g[18][x] = 'i' end
        local cleared = grid.clearFullRows(g)
        t.assert.eq(cleared, 0)
    end)

    t.it("shifts rows above down", function()
        local g = grid.newGrid()
        g[17][1] = 'z'
        for x = 1, 10 do g[18][x] = 'i' end
        grid.clearFullRows(g)
        t.assert.eq(g[18][1], 'z')
        t.assert.eq(g[17][1], ' ')
    end)
end)

t.describe("grid.newSequence", function()
    t.it("adds 7 piece types to sequence", function()
        local seq = {}
        grid.newSequence(seq, math.random)
        t.assert.eq(#seq, 7)
    end)

    t.it("contains all 7 piece types", function()
        local seq = {}
        grid.newSequence(seq, math.random)
        local found = {}
        for _, v in ipairs(seq) do found[v] = true end
        for i = 1, 7 do t.assert.truthy(found[i]) end
    end)

    t.it("appends to existing sequence", function()
        local seq = {1, 2, 3}
        grid.newSequence(seq, math.random)
        t.assert.eq(#seq, 10)
    end)
end)

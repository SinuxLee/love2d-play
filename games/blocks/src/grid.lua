-- grid.lua
-- Pure logic functions for the blocks game grid

local pieces = require "pieces"

local grid = {}

--- Creates a new empty grid of GRID_H x GRID_W spaces
---@return Row[]
function grid.newGrid()
    local g = {}
    for y = 1, pieces.GRID_H do
        g[y] = {}
        for x = 1, pieces.GRID_W do
            g[y][x] = ' '
        end
    end
    return g
end

--- Checks whether a piece can be placed at the given position
---@param inert Row[] the grid of placed blocks
---@param pieceType integer piece type index (1-7)
---@param testX integer x offset (0-based grid column offset)
---@param testY integer y offset (0-based grid row offset)
---@param testRotation integer rotation variant index
---@return boolean
function grid.canPieceMove(inert, pieceType, testX, testY, testRotation)
    for y = 1, pieces.PIECE_SIZE do
        for x = 1, pieces.PIECE_SIZE do
            local testBlockX = testX + x
            local testBlockY = testY + y

            if pieces.structures[pieceType][testRotation][y][x] ~= ' ' and (
                    testBlockX < 1
                    or testBlockX > pieces.GRID_W
                    or testBlockY > pieces.GRID_H
                    or inert[testBlockY][testBlockX] ~= ' '
                ) then
                return false
            end
        end
    end

    return true
end

--- Writes the cells of a piece into the grid
---@param inert Row[] the grid of placed blocks
---@param pieceType integer piece type index (1-7)
---@param pieceX integer x offset
---@param pieceY integer y offset
---@param pieceRotation integer rotation variant index
function grid.lockPiece(inert, pieceType, pieceX, pieceY, pieceRotation)
    for y = 1, pieces.PIECE_SIZE do
        for x = 1, pieces.PIECE_SIZE do
            local block = pieces.structures[pieceType][pieceRotation][y][x]
            if block ~= ' ' then
                inert[pieceY + y][pieceX + x] = block
            end
        end
    end
end

--- Detects and clears complete rows, shifting rows above down
---@param inert Row[] the grid of placed blocks
---@return integer count of cleared rows
function grid.clearFullRows(inert)
    local cleared = 0
    for y = 1, pieces.GRID_H do
        local complete = true
        for x = 1, pieces.GRID_W do
            if inert[y][x] == ' ' then
                complete = false
                break
            end
        end

        if complete then
            cleared = cleared + 1
            for removeY = y, 2, -1 do
                for removeX = 1, pieces.GRID_W do
                    inert[removeY][removeX] = inert[removeY - 1][removeX]
                end
            end

            for removeX = 1, pieces.GRID_W do
                inert[1][removeX] = ' '
            end
        end
    end
    return cleared
end

--- Adds all 7 piece types in random order to the sequence
---@param sequence integer[] the piece sequence to append to
---@param random_fn function random number generator (defaults to math.random)
function grid.newSequence(sequence, random_fn)
    random_fn = random_fn or math.random
    for pieceTypeIndex = 1, #pieces.structures do
        local position = random_fn(#sequence + 1)
        table.insert(sequence, position, pieceTypeIndex)
    end
end

return grid

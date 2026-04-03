if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

local gl = love.graphics
local pieces = require "pieces"
local grid = require "grid"

---@enum Direction
local Direction = {
    UP = 1,
    DOWN = 2,
    LEFT = 3,
    RIGHT = 4
}

---@type number frame interval
local timerLimit = 0.5

---@type number ticker
local timer = 0

---@type Row[]
local inert = {}

---@type  integer[] piece sequence
local sequence = {}

---@type integer current piece position X
local pieceX = 3

---@type integer current piece position Y
local pieceY = 0

---@type integer current piece rotation
local pieceRotation = 1

---@type integer current piece type
local pieceType = nil

local function newPiece()
    pieceX = 3
    pieceY = 0
    pieceRotation = 1
    pieceType = table.remove(sequence)

    if #sequence == 0 then
        grid.newSequence(sequence, love.math.random)
    end
end

local function reset()
    inert = grid.newGrid()

    grid.newSequence(sequence, love.math.random)
    newPiece()

    timer = 0
end

---@param block string
---@param x integer
---@param y integer
local function drawBlock(block, x, y)
    local color = pieces.colors[block]
    local blockSize = 20
    local blockDrawSize = blockSize - 1

    gl.setColor(color)
    gl.rectangle(
        'fill',
        (x - 1) * blockSize,
        (y - 1) * blockSize,
        blockDrawSize,
        blockDrawSize
    )
end

local DUMMY = function() end
---@generic T
---@param v T
---@param cases table<T,function>
local function switch(v, cases, ...)
    local f = cases[v] or cases['default'] or DUMMY
    return f(...)
end

function love.load()
    gl.setBackgroundColor(255, 255, 255)
    reset()
end

---@param dt number
function love.update(dt)
    timer = timer + dt
    if timer < timerLimit then
        return
    end
    timer = 0

    local testY = pieceY + 1
    local ok = grid.canPieceMove(inert, pieceType, pieceX, testY, pieceRotation)
    if ok then
        pieceY = testY
        return
    end

    -- Add piece to inert
    grid.lockPiece(inert, pieceType, pieceX, pieceY, pieceRotation)

    -- Find and clear complete rows
    grid.clearFullRows(inert)

    newPiece()

    if not grid.canPieceMove(inert, pieceType, pieceX, pieceY, pieceRotation) then
        reset()
    end
end

local function handleKeyX()
    local testRotation = pieceRotation + 1
    if testRotation > #pieces.structures[pieceType] then
        testRotation = 1
    end

    if grid.canPieceMove(inert, pieceType, pieceX, pieceY, testRotation) then
        pieceRotation = testRotation
    end
end

local function handleKeyZ()
    local testRotation = pieceRotation - 1
    if testRotation < 1 then
        testRotation = #pieces.structures[pieceType]
    end

    if grid.canPieceMove(inert, pieceType, pieceX, pieceY, testRotation) then
        pieceRotation = testRotation
    end
end

local function handleKeyC()
    while grid.canPieceMove(inert, pieceType, pieceX, pieceY + 1, pieceRotation) do
        pieceY = pieceY + 1
        timer = timerLimit
    end
end

local function handleKeyLeft()
    local testX = pieceX - 1

    if grid.canPieceMove(inert, pieceType, testX, pieceY, pieceRotation) then
        pieceX = testX
    end
end

local function handleKeyRight()
    local testX = pieceX + 1

    if grid.canPieceMove(inert, pieceType, testX, pieceY, pieceRotation) then
        pieceX = testX
    end
end

---@param key string
function love.keypressed(key)
    switch(key, {
        x       = handleKeyX,     -- Rotate clockwise
        z       = handleKeyZ,     -- Rotate counterclockwise
        c       = handleKeyC,     -- Drop
        left    = handleKeyLeft,  -- Move left
        right   = handleKeyRight, -- Move right
        default = function() print("unknown key") end
    })
end

function love.draw()
    local offsetX = 2
    local offsetY = 5

    -- draw grid
    for y = 1, pieces.GRID_H do
        for x = 1, pieces.GRID_W do
            drawBlock(inert[y][x], x + offsetX, y + offsetY)
        end
    end

    local next = sequence[#sequence]
    local nextShape = pieces.structures[next][1]
    local curShape = pieces.structures[pieceType][pieceRotation]
    for y = 1, pieces.PIECE_SIZE do
        for x = 1, pieces.PIECE_SIZE do
            local block = curShape[y][x]
            if block ~= ' ' then
                drawBlock(block, x + pieceX + offsetX, y + pieceY + offsetY)
            end

            block = nextShape[y][x]
            if block ~= ' ' then
                drawBlock('preview', x + 5, y + 1)
            end
        end
    end
end

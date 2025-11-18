if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

local gl = love.graphics

---@enum Direction
local Direction = {
    UP = 1,
    DOWN = 2,
    LEFT = 3,
    RIGHT = 4
}

---@alias Cell string               -- 单格字符
---@alias Row  Cell[]               -- 一行
---@alias Shape Row[]               -- 一个4x4形状
---@alias ShapeGroup Shape[]        -- 一种积木的所有旋转情况
---@type ShapeGroup[]
local pieceStructures = {
    {
        {
            { ' ', ' ', ' ', ' ' },
            { 'i', 'i', 'i', 'i' },
            { ' ', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'i', ' ', ' ' },
            { ' ', 'i', ' ', ' ' },
            { ' ', 'i', ' ', ' ' },
            { ' ', 'i', ' ', ' ' },
        },
    },
    {
        {
            { ' ', ' ', ' ', ' ' },
            { ' ', 'o', 'o', ' ' },
            { ' ', 'o', 'o', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    {
        {
            { ' ', ' ', ' ', ' ' },
            { 'j', 'j', 'j', ' ' },
            { ' ', ' ', 'j', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'j', ' ', ' ' },
            { ' ', 'j', ' ', ' ' },
            { 'j', 'j', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { 'j', ' ', ' ', ' ' },
            { 'j', 'j', 'j', ' ' },
            { ' ', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'j', 'j', ' ' },
            { ' ', 'j', ' ', ' ' },
            { ' ', 'j', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    {
        {
            { ' ', ' ', ' ', ' ' },
            { 'l', 'l', 'l', ' ' },
            { 'l', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'l', ' ', ' ' },
            { ' ', 'l', ' ', ' ' },
            { ' ', 'l', 'l', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', ' ', 'l', ' ' },
            { 'l', 'l', 'l', ' ' },
            { ' ', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { 'l', 'l', ' ', ' ' },
            { ' ', 'l', ' ', ' ' },
            { ' ', 'l', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    {
        {
            { ' ', ' ', ' ', ' ' },
            { 't', 't', 't', ' ' },
            { ' ', 't', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 't', ' ', ' ' },
            { ' ', 't', 't', ' ' },
            { ' ', 't', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 't', ' ', ' ' },
            { 't', 't', 't', ' ' },
            { ' ', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 't', ' ', ' ' },
            { 't', 't', ' ', ' ' },
            { ' ', 't', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    {
        {
            { ' ', ' ', ' ', ' ' },
            { ' ', 's', 's', ' ' },
            { 's', 's', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { 's', ' ', ' ', ' ' },
            { 's', 's', ' ', ' ' },
            { ' ', 's', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
    {
        {
            { ' ', ' ', ' ', ' ' },
            { 'z', 'z', ' ', ' ' },
            { ' ', 'z', 'z', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
        {
            { ' ', 'z', ' ', ' ' },
            { 'z', 'z', ' ', ' ' },
            { 'z', ' ', ' ', ' ' },
            { ' ', ' ', ' ', ' ' },
        },
    },
}

---@alias Color number[]
---@type table<string,Color>
local colors = {
    [' '] = { .87, .87, .87 },
    i = { .47, .76, .94 },
    j = { .93, .91, .42 },
    l = { .49, .85, .76 },
    o = { .92, .69, .47 },
    s = { .83, .54, .93 },
    t = { .97, .58, .77 },
    z = { .66, .83, .46 },
    preview = { .75, .75, .75 },
}

---@type integer 网格宽度
local gridXCount = 10

---@type integer 网格高度
local gridYCount = 18

---@type integer 块宽度
local pieceXCount = 4

---@type integer 块高度
local pieceYCount = 4

---@type number frame interval
local timerLimit = 0.5

---@type number ticker
local timer = 0

---@type Row[]
local inert = {}

---@type  integer[] 方块序列
local sequence = {}

---@type integer 当前块位置 X
local pieceX = 3

---@type integer 当前块位置 Y
local pieceY = 0

---@type integer 当前块旋转标识
local pieceRotation = 1

---@type integer 当前块类型
local pieceType = table.remove(sequence)

local function newSequence()
    for pieceTypeIndex = 1, #pieceStructures do
        local position = love.math.random(#sequence + 1)
        table.insert(
            sequence,
            position,
            pieceTypeIndex
        )
    end
end

local function newPiece()
    pieceX = 3
    pieceY = 0
    pieceRotation = 1
    pieceType = table.remove(sequence)

    if #sequence == 0 then
        newSequence()
    end
end

local function reset()
    for y = 1, gridYCount do
        inert[y] = {}
        for x = 1, gridXCount do
            inert[y][x] = ' '
        end
    end

    newSequence()
    newPiece()

    timer = 0
end

---检查当前块是否能移动
---@param testX number
---@param testY number
---@param testRotation number
---@return boolean
local function canPieceMove(testX, testY, testRotation)
    for y = 1, pieceYCount do
        for x = 1, pieceXCount do
            local testBlockX = testX + x
            local testBlockY = testY + y

            if pieceStructures[pieceType][testRotation][y][x] ~= ' ' and (
                    testBlockX < 1
                    or testBlockX > gridXCount
                    or testBlockY > gridYCount
                    or inert[testBlockY][testBlockX] ~= ' '
                ) then
                return false
            end
        end
    end

    return true
end

---绘制块
---@param block string
---@param x integer
---@param y integer
local function drawBlock(block, x, y)
    local color = colors[block]
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
    -- 控制刷新频率
    timer = timer + dt
    if timer < timerLimit then
        return
    end
    timer = 0

    local testY = pieceY + 1
    local ok = canPieceMove(pieceX, testY, pieceRotation)
    if ok then
        pieceY = testY
        return
    end

    -- Add piece to inert
    for y = 1, pieceYCount do
        for x = 1, pieceXCount do
            local block =
                pieceStructures[pieceType][pieceRotation][y][x]
            if block ~= ' ' then
                inert[pieceY + y][pieceX + x] = block
            end
        end
    end

    -- Find complete rows
    for y = 1, gridYCount do
        local complete = true
        for x = 1, gridXCount do
            if inert[y][x] == ' ' then
                complete = false
                break
            end
        end

        if complete then
            for removeY = y, 2, -1 do
                for removeX = 1, gridXCount do
                    inert[removeY][removeX] = inert[removeY - 1][removeX]
                end
            end

            for removeX = 1, gridXCount do
                inert[1][removeX] = ' '
            end
        end
    end

    newPiece()

    if not canPieceMove(pieceX, pieceY, pieceRotation) then
        reset()
    end
end

local function handleKeyX()
    local testRotation = pieceRotation + 1
    if testRotation > #pieceStructures[pieceType] then
        testRotation = 1
    end

    if canPieceMove(pieceX, pieceY, testRotation) then
        pieceRotation = testRotation
    end
end

local function handleKeyZ()
    local testRotation = pieceRotation - 1
    if testRotation < 1 then
        testRotation = #pieceStructures[pieceType]
    end

    if canPieceMove(pieceX, pieceY, testRotation) then
        pieceRotation = testRotation
    end
end

local function handleKeyC()
    while canPieceMove(pieceX, pieceY + 1, pieceRotation) do
        pieceY = pieceY + 1
        timer = timerLimit
    end
end

local function handleKeyLeft()
    local testX = pieceX - 1

    if canPieceMove(testX, pieceY, pieceRotation) then
        pieceX = testX
    end
end

local function handleKeyRight()
    local testX = pieceX + 1

    if canPieceMove(testX, pieceY, pieceRotation) then
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
    for y = 1, gridYCount do
        for x = 1, gridXCount do
            drawBlock(inert[y][x], x + offsetX, y + offsetY)
        end
    end

    local next = sequence[#sequence]
    local nextShape = pieceStructures[next][1]
    local curShape = pieceStructures[pieceType][pieceRotation]
    for y = 1, pieceYCount do
        for x = 1, pieceXCount do
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

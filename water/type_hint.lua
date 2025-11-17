--#region
-- 常用注解总结
---@type          类型注解
---@param         参数类型
---@return        返回值类型
---@class         定义类
---@field         类的字段
---@alias         类型别名
---@generic       泛型
---@enum          枚举
---@overload      函数重载
---@deprecated    标记废弃
---@async         异步函数
---@nodiscard     返回值不应被忽略
--#endregion

-- 基本类型注解

---@type string 名字
local name = "player"

---@type number
local health = 100

---@type boolean 是否活着
local isAlive = true

---@type table
local data = {}

---@type string|number
local value = "hello" -- 可以是 string 或 number

---@type string|nil
local optionalName = nil



-- 函数类型注解

---@param name string 玩家名字
---@param age number 玩家年龄
---@return boolean success 是否成功
function createPlayer(name, age)
    return true
end

---@param x number
---@param y number
---@return number, number 返回两个数字
function getPosition(x, y)
    return x + 10, y + 10
end

---@param name string
---@param age? number 可选参数
---@return string
function greet(name, age)
    if age then
        return name .. " is " .. age
    end
    return name
end

-- 表（Table）类型注解
---@type table<string, number>
local scores = {
    alice = 100,
    bob = 95
}

---@class Player
---@field name string
---@field health number
---@field position {x: number, y: number}
---@field isAlive boolean

---@type Player
local player = {
    name = "Hero",
    health = 100,
    position = { x = 0, y = 0 },
    isAlive = true
}


---@class Enemy
---@field name string
---@field damage number
local Enemy = {}

---@param name string
---@param damage number
---@return Enemy
function Enemy.new(name, damage)
    local self = setmetatable({}, { __index = Enemy })
    self.name = name
    self.damage = damage
    return self
end

---@param target Player
---@return number
function Enemy:attack(target)
    target.health = target.health - self.damage
    return self.damage
end

-- 数组类型
---@type string[] 字符串数组
local names = { "alice", "bob", "charlie" }

---@type Player[] 玩家数组
local players = {}

---@type number[][]  二维数组
local grid = { { 1, 2, 3 }, { 4, 5, 6 } }

-- 函数类型
---@alias Callback fun(success: boolean, message: string): void

---@param callback Callback
function doSomething(callback)
    callback(true, "Done!")
end

-- 枚举类型
---@enum Direction
local Direction = {
    UP = 1,
    DOWN = 2,
    LEFT = 3,
    RIGHT = 4
}

---@param dir Direction
function move(dir)
    if dir == Direction.UP then
        print("Moving up")
    end
end

-- 泛型
---@generic T
---@param list T[]
---@return T|nil
function getFirst(list)
    return list[1]
end

-- 类型别名
---@alias Vector2 {x: number, y: number}
---@alias Color {r: number, g: number, b: number, a: number}

---@param pos Vector2
---@param color Color
function drawPoint(pos, color)
    -- 实现
end



-- ############

---@class GameObject
---@field x number
---@field y number
---@field width number
---@field height number
---@field speed number
local GameObject = {}

---@param x number
---@param y number
---@return GameObject
function GameObject.new(x, y)
    local self = setmetatable({}, {__index = GameObject})
    self.x = x
    self.y = y
    self.width = 32
    self.height = 32
    self.speed = 100
    return self
end

---@param dt number Delta time
function GameObject:update(dt)
    self.x = self.x + self.speed * dt
end

function GameObject:draw()
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
end

---@type GameObject[]
local gameObjects = {}

---@param dt number
function love.update(dt)
    for _, obj in ipairs(gameObjects) do
        obj:update(dt)
    end
end
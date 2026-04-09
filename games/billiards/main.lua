-- Billiards - 8 Ball Pool (Love2D Port)
-- Main entry point
-- Usage:
--   Normal:  love love2d
--   Tests:   love love2d --test

-- using ZeroBrane Studio to debug the game
if arg[#arg] == "-debug" then require("mobdebug").start() end

local Game = require("game")
local Audio = require("audio")
local Renderer = require("renderer")
local Config = require("config")

local game = nil
local isTestMode = false

function love.load(arg)
    -- Check for flags
    local testBreak = false
    for _, v in ipairs(arg or {}) do
        if v == "--test" then
            isTestMode = true
        elseif v == "--test-break" then
            testBreak = true
        end
    end

    if testBreak then
        local TestBreak = require("test_break")
        local output = TestBreak.run()
        love.filesystem.write("test_break_results.txt", output)
        print(output)
        love.event.quit()
        return
    end

    if isTestMode then
        local Tests = require("tests")
        local output, failures = Tests.run()

        -- Write results to Love2D save directory
        love.filesystem.write("test_results.txt", output)

        -- Also print to stdout if possible
        print(output)

        -- Exit with code
        love.event.quit(failures > 0 and 1 or 0)
        return
    end

    -- Normal game mode
    love.window.setTitle("Billiards - 8 Ball Pool")
    love.graphics.setBackgroundColor(0.12, 0.12, 0.15)
    love.graphics.setLineStyle("smooth")

    Renderer.init()
    Audio.init()

    game = Game.init()
    Audio.playBgMusic()
end

function love.update(dt)
    if isTestMode then return end
    dt = math.min(dt, 1 / 30)
    Game.update(game, dt)
end

function love.draw()
    if isTestMode then return end

    local ww, wh = love.graphics.getDimensions()
    local sx = ww / Config.DESIGN_WIDTH
    local sy = wh / Config.DESIGN_HEIGHT
    local scale = math.min(sx, sy)
    local offsetX = (ww - Config.DESIGN_WIDTH * scale) / 2
    local offsetY = (wh - Config.DESIGN_HEIGHT * scale) / 2

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    Game.draw(game)

    love.graphics.pop()
end

local function transformMouse(x, y)
    local ww, wh = love.graphics.getDimensions()
    local sx = ww / Config.DESIGN_WIDTH
    local sy = wh / Config.DESIGN_HEIGHT
    local scale = math.min(sx, sy)
    local offsetX = (ww - Config.DESIGN_WIDTH * scale) / 2
    local offsetY = (wh - Config.DESIGN_HEIGHT * scale) / 2
    return (x - offsetX) / scale, (y - offsetY) / scale
end

function love.mousepressed(x, y, button)
    if isTestMode then return end
    local gx, gy = transformMouse(x, y)
    Game.mousepressed(game, gx, gy, button)
end

function love.mousereleased(x, y, button)
    if isTestMode then return end
    local gx, gy = transformMouse(x, y)
    Game.mousereleased(game, gx, gy, button)
end

function love.mousemoved(x, y, dx, dy)
    if isTestMode then return end
    local gx, gy = transformMouse(x, y)
    local ww, wh = love.graphics.getDimensions()
    local sx = ww / Config.DESIGN_WIDTH
    local sy = wh / Config.DESIGN_HEIGHT
    local scale = math.min(sx, sy)
    Game.mousemoved(game, gx, gy, dx / scale, dy / scale)
end

function love.wheelmoved(x, y)
    if isTestMode then return end
    Game.wheelmoved(game, x, y)
end

function love.keypressed(key)
    if isTestMode then return end
    -- F5: hot-reload tuning.lua and restart game
    if key == "f5" then
        package.loaded["tuning"] = nil
        package.loaded["config"] = nil
        local Config = require("config")
        Game.restart(game)
        print("[Tuning] Reloaded tuning.lua, game restarted")
        return
    end
    Game.keypressed(game, key)
end

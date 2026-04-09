-- Check for --test / --benchmark flags before loading graphics modules
local runTests = false
local runBenchmark = false
for _, arg in ipairs(arg or {}) do
    if arg == "--test" then runTests = true end
    if arg == "--benchmark" then runBenchmark = true end
end

if runTests then
    -- Run unit tests without graphics
    local T = require("tools.test_runner")
    require("tests.test_utils")
    require("tests.test_animation")
    require("tests.test_grid")
    require("tests.test_level")
    require("tests.test_specials")
    require("tests.test_save")
    require("tests.test_autoplay")
    require("tests.test_profile")
    require("tests.test_bandit")
    local allPassed = T.summary()
    love.event.quit(allPassed and 0 or 1)
    return
end

if runBenchmark then
    local Benchmark = require("tools.benchmark")
    Benchmark.benchmark()
    love.event.quit(0)
    return
end

local Grid = require("core.grid")
local States = require("systems.states")
local Renderer = require("ui.renderer")
local Input = require("systems.input")
local Tweens = require("core.animation")
local Level = require("systems.level")
local Effects = require("core.effects")
local UI = require("ui.widgets")
local GM = require("ui.gm")
local Autoplay = require("tools.autoplay")
local Logger = require("tools.logger")
local Hints = require("systems.hints")

function love.load()
    love.graphics.setBackgroundColor(0.12, 0.12, 0.22)
    Logger.init()
    Renderer.init()
    Effects.init()
    UI.init()
    GM.loadConfig()
    -- Start in nick_input state (States.current defaults to "nick_input")
    Level.start(1) -- placeholder until nick confirmed
end

function love.update(dt)
    Logger.update(dt)
    if States.current == "nick_input" then return end
    Tweens.update(dt)
    States.update(dt)
    Effects.update(dt)
    Autoplay.update(dt, States)
end

function love.draw()
    if States.current == "nick_input" then
        local cursorVisible = math.floor(love.timer.getTime() * 2) % 2 == 0
        Renderer.drawNickInput(States.nickInput, States.nickMessage, cursorVisible)
        return
    end

    UI.beginFrame()

    -- Apply screen shake offset
    love.graphics.push()
    love.graphics.translate(Effects.shakeOffsetX, Effects.shakeOffsetY)

    Renderer.drawBoard()
    Renderer.drawGems(Grid.cells)
    Renderer.drawSelection(Input.selectedRow, Input.selectedCol)

    -- Hint highlight (drawn with shake applied, same as gems)
    if Hints.hintVisible and Hints.hintMove then
        local h = Hints.hintMove
        Renderer.drawHint(h.r1, h.c1, h.r2, h.c2, Hints.flashTimer)
    end

    love.graphics.pop()

    -- Effects drawn without shake (particles already positioned)
    Effects.draw()

    -- HUD and overlays without shake
    Renderer.drawHUD(States.score, States.combo, Level.current.number,
        States.movesLeft, Level.current.targetScore,
        Level.current.objectives, States)
    Renderer.drawStatusBar(States.getEffectiveBias(), States.failCount, Level.current.modifiers)

    -- GM panel overlay (draws UI widgets)
    GM.draw(States, Autoplay)

    if States.current == "level_complete" then
        Renderer.drawLevelComplete(States.score, Level.current.number, States.stars)
    elseif States.current == "level_fail" then
        Renderer.drawLevelFail(States.score, Level.current.targetScore)
    end

    UI.endFrame()
end

function love.textinput(text)
    States.textinput(text)
end

function love.keypressed(key)
    if key == "f1" and States.current ~= "nick_input" then
        GM.toggle()
        return
    end
    States.keypressed(key)
end

local function onSwap(r1, c1, r2, c2)
    States.startSwap(r1, c1, r2, c2)
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        UI.onMousePressed()
    end
    if States.current == "nick_input" then return end
    if GM.hitTest(x, y) then return end
    local result = Input.mousepressed(x, y, button, States.current, onSwap)
    if result == "next_level" then
        States.nextLevel()
        Input.clear()
    elseif result == "retry" then
        States.retryLevel()
        Input.clear()
    end
end

function love.mousemoved(x, y)
    if States.current == "nick_input" then return end
    if GM.hitTest(x, y) then return end
    Input.mousemoved(x, y, States.current, onSwap)
end

function love.mousereleased(x, y, button)
    if button == 1 then
        UI.onMouseReleased()
    end
    if States.current == "nick_input" then return end
    Input.mousereleased(x, y, button, States.current, onSwap)
end

function love.quit()
    GM.saveConfig()
    Logger.close()
end

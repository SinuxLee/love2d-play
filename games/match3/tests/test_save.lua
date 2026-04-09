local T = require("tools.test_runner")
local Save = require("systems.save")

T.describe("Save.serialize / deserialize", function()
    T.it("round-trips simple data", function()
        local data = { nick = "test", maxLevel = 5, totalScore = 1200, levelScores = {} }
        local str = Save.serialize(data)
        local result = Save.deserialize(str)
        T.assert_not_nil(result)
        T.assert_equal(result.nick, "test")
        T.assert_equal(result.maxLevel, 5)
        T.assert_equal(result.totalScore, 1200)
    end)

    T.it("round-trips levelScores table", function()
        local data = { nick = "p1", maxLevel = 3, totalScore = 900, levelScores = {[1] = 400, [2] = 500} }
        local str = Save.serialize(data)
        local result = Save.deserialize(str)
        T.assert_not_nil(result)
        T.assert_equal(result.levelScores[1], 400)
        T.assert_equal(result.levelScores[2], 500)
    end)

    T.it("deserialize returns nil for invalid input", function()
        local result = Save.deserialize("this is not valid lua")
        T.assert_nil(result)
    end)

    T.it("deserialize returns nil for empty string", function()
        local result = Save.deserialize("")
        T.assert_nil(result)
    end)
end)

T.describe("Save.getFilePath", function()
    T.it("returns saves/<nick>.sav", function()
        T.assert_equal(Save.getFilePath("player1"), "saves/player1.sav")
    end)
end)

T.describe("Save.load without filesystem", function()
    T.it("initializes default data for unknown nick", function()
        Save.load("nonexistent_test_user")
        T.assert_equal(Save.data.nick, "nonexistent_test_user")
        T.assert_equal(Save.data.maxLevel, 1)
        T.assert_equal(Save.data.totalScore, 0)
    end)
end)

T.describe("Save.onLevelComplete", function()
    T.it("advances maxLevel", function()
        Save.data = { nick = "test", maxLevel = 1, totalScore = 0, levelScores = {} }
        Save.nick = "test"
        Save.onLevelComplete(1, 500)
        T.assert_equal(Save.data.maxLevel, 2)
        T.assert_equal(Save.data.totalScore, 500)
        T.assert_equal(Save.data.levelScores[1], 500)
    end)

    T.it("keeps best score per level", function()
        Save.data = { nick = "test", maxLevel = 3, totalScore = 1000, levelScores = {[1] = 600} }
        Save.nick = "test"
        Save.onLevelComplete(1, 400) -- worse score
        T.assert_equal(Save.data.levelScores[1], 600, "should keep better score")
    end)

    T.it("does not regress maxLevel", function()
        Save.data = { nick = "test", maxLevel = 5, totalScore = 2000, levelScores = {} }
        Save.nick = "test"
        Save.onLevelComplete(2, 300) -- replaying earlier level
        T.assert_equal(Save.data.maxLevel, 5, "maxLevel should not decrease")
    end)
end)

-- games/physics-testbed/tests/integration_physics.lua
local t = require "testing"

t.describe("Physics World (integration)", function()
    t.it("creates a world with gravity", function()
        local world = love.physics.newWorld(0, 98, true)
        local gx, gy = world:getGravity()
        t.assert.near(gx, 0, 0.01)
        t.assert.near(gy, 98, 0.01)
        world:destroy()
    end)

    t.it("dynamic body falls under gravity", function()
        local world = love.physics.newWorld(0, 100, true)
        local body = love.physics.newBody(world, 0, 0, "dynamic")
        local shape = love.physics.newCircleShape(10)
        love.physics.newFixture(body, shape, 1)

        local initial_y = body:getY()
        for _ = 1, 60 do
            world:update(1/60)
        end
        local final_y = body:getY()
        t.assert.truthy(final_y > initial_y)
        world:destroy()
    end)

    t.it("static body does not move", function()
        local world = love.physics.newWorld(0, 100, true)
        local body = love.physics.newBody(world, 50, 50, "static")
        local shape = love.physics.newRectangleShape(100, 10)
        love.physics.newFixture(body, shape)

        for _ = 1, 60 do
            world:update(1/60)
        end

        t.assert.near(body:getX(), 50, 0.01)
        t.assert.near(body:getY(), 50, 0.01)
        world:destroy()
    end)

    t.it("bodies collide and stop", function()
        local world = love.physics.newWorld(0, 100, true)

        local ground = love.physics.newBody(world, 0, 100, "static")
        love.physics.newFixture(ground, love.physics.newRectangleShape(200, 10))

        local ball = love.physics.newBody(world, 0, 0, "dynamic")
        local bf = love.physics.newFixture(ball, love.physics.newCircleShape(5), 1)
        bf:setRestitution(0)

        for _ = 1, 300 do
            world:update(1/60)
        end

        local by = ball:getY()
        t.assert.truthy(by > 80)
        t.assert.truthy(by < 100)

        local _, vy = ball:getLinearVelocity()
        t.assert.near(vy, 0, 5)

        world:destroy()
    end)

    t.it("revolute joint constrains bodies", function()
        local world = love.physics.newWorld(0, 0, true)

        local a = love.physics.newBody(world, 0, 0, "static")
        love.physics.newFixture(a, love.physics.newCircleShape(5))

        local b = love.physics.newBody(world, 50, 0, "dynamic")
        love.physics.newFixture(b, love.physics.newCircleShape(5), 1)

        local joint = love.physics.newRevoluteJoint(a, b, 0, 0)
        t.assert.truthy(joint)
        t.assert.eq(#world:getJoints(), 1)

        world:destroy()
    end)

    t.it("scene stacking creates correct body count", function()
        local world = love.physics.newWorld(0, 98, true)
        local scenes = require "scenes"
        scenes.stacking.setup(world)

        local bodies = world:getBodies()
        t.assert.eq(#bodies, 56)  -- 1 ground + 55 boxes

        world:destroy()
    end)
end)

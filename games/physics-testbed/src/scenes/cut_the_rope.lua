local geom = require "geom"

local scene = {}

-- state
local ropes = {}
local candy = nil
local target_body = nil
local collected = false
local cutting = false
local prev_cut = {x = 0, y = 0}
local cur_cut = {x = 0, y = 0}

local segmentsIntersect = geom.segmentsIntersect

local function createRope(world, ax, ay, bx, by, num_links)
    local rope = {segments = {}, joints = {}, anchor = nil}

    -- anchor
    local anchor = love.physics.newBody(world, ax, ay, "static")
    love.physics.newFixture(anchor, love.physics.newCircleShape(6))
    anchor:setUserData("anchor")
    rope.anchor = anchor

    -- direction
    local dx = (bx - ax) / (num_links + 1)
    local dy = (by - ay) / (num_links + 1)
    local link_w = 6
    local link_h = math.sqrt(dx * dx + dy * dy) * 0.85

    local prev_body = anchor
    local prev_x, prev_y = ax, ay

    for i = 1, num_links do
        local x = ax + dx * i
        local y = ay + dy * i
        local body = love.physics.newBody(world, x, y, "dynamic")
        local shape = love.physics.newRectangleShape(link_w, link_h)
        local fixture = love.physics.newFixture(body, shape, 0.5)
        fixture:setFriction(0.2)
        body:setUserData("rope")

        local jx = (prev_x + x) / 2
        local jy = (prev_y + y) / 2
        local joint = love.physics.newRevoluteJoint(prev_body, body, jx, jy)
        table.insert(rope.joints, joint)
        table.insert(rope.segments, body)

        prev_body = body
        prev_x, prev_y = x, y
    end

    -- connect last segment to candy
    local jx = (prev_x + bx) / 2
    local jy = (prev_y + by) / 2
    local joint = love.physics.newRevoluteJoint(prev_body, candy, jx, jy)
    table.insert(rope.joints, joint)

    return rope
end

local function beginContact(a, b, contact)
    local ba, bb = a:getBody(), b:getBody()
    local uda = ba:getUserData()
    local udb = bb:getUserData()
    if (uda == "candy" and udb == "target") or (uda == "target" and udb == "candy") then
        collected = true
    end
end

function scene.setup(world)
    -- reset state
    ropes = {}
    candy = nil
    target_body = nil
    collected = false
    cutting = false

    -- walls
    local ground = love.physics.newBody(world, 400, 580, "static")
    love.physics.newFixture(ground, love.physics.newRectangleShape(900, 20))

    local left_wall = love.physics.newBody(world, -10, 300, "static")
    love.physics.newFixture(left_wall, love.physics.newRectangleShape(20, 700))

    local right_wall = love.physics.newBody(world, 810, 300, "static")
    love.physics.newFixture(right_wall, love.physics.newRectangleShape(20, 700))

    -- target zone
    target_body = love.physics.newBody(world, 400, 520, "static")
    local target_shape = love.physics.newCircleShape(35)
    local target_fixture = love.physics.newFixture(target_body, target_shape)
    target_fixture:setSensor(true)
    target_body:setUserData("target")

    -- candy
    candy = love.physics.newBody(world, 400, 200, "dynamic")
    local candy_shape = love.physics.newCircleShape(14)
    local candy_fixture = love.physics.newFixture(candy, candy_shape, 3)
    candy_fixture:setRestitution(0.3)
    candy_fixture:setFriction(0.3)
    candy:setUserData("candy")

    -- create ropes from different anchor points to candy
    local cx, cy = candy:getPosition()
    table.insert(ropes, createRope(world, 150, 50, cx, cy, 8))
    table.insert(ropes, createRope(world, 400, 30, cx, cy, 6))
    table.insert(ropes, createRope(world, 650, 60, cx, cy, 8))

    -- contact callback
    world:setCallbacks(beginContact, nil, nil, nil)
end

function scene.mousepressed(world, wx, wy, button)
    if button == 1 then
        cutting = true
        prev_cut.x = wx
        prev_cut.y = wy
        cur_cut.x = wx
        cur_cut.y = wy
        return true
    end
end

function scene.mousereleased(world, wx, wy, button)
    if button == 1 then
        cutting = false
        return true
    end
end

function scene.mousemoved(world, wx, wy, wdx, wdy)
    if not cutting then return end

    prev_cut.x = cur_cut.x
    prev_cut.y = cur_cut.y
    cur_cut.x = wx
    cur_cut.y = wy

    -- test swipe segment against each rope joint
    for _, rope in ipairs(ropes) do
        for i, joint in ipairs(rope.joints) do
            if joint and not joint:isDestroyed() then
                local x1, y1, x2, y2 = joint:getAnchors()
                if segmentsIntersect(prev_cut.x, prev_cut.y, cur_cut.x, cur_cut.y, x1, y1, x2, y2) then
                    joint:destroy()
                    rope.joints[i] = nil
                end
            end
        end
    end
end

function scene.draw(world)
    -- target zone
    if target_body and not target_body:isDestroyed() then
        local tx, ty = target_body:getPosition()
        if collected then
            love.graphics.setColor(0.2, 1.0, 0.3, 0.6)
        else
            love.graphics.setColor(0.2, 0.8, 0.2, 0.3)
        end
        love.graphics.circle("fill", tx, ty, 35)
        love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
        love.graphics.circle("line", tx, ty, 35)

        -- star icon (simple cross)
        love.graphics.setColor(1, 1, 0.3, 0.8)
        love.graphics.line(tx - 8, ty, tx + 8, ty)
        love.graphics.line(tx, ty - 8, tx, ty + 8)
        love.graphics.line(tx - 6, ty - 6, tx + 6, ty + 6)
        love.graphics.line(tx - 6, ty + 6, tx + 6, ty - 6)
    end

    -- candy highlight
    if candy and not candy:isDestroyed() then
        local cx, cy = candy:getPosition()
        love.graphics.setColor(1, 0.8, 0.2, 0.8)
        love.graphics.circle("line", cx, cy, 18)
        love.graphics.circle("line", cx, cy, 16)
    end

    -- cut line feedback
    if cutting then
        love.graphics.setColor(1, 0.2, 0.2, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.line(prev_cut.x, prev_cut.y, cur_cut.x, cur_cut.y)
        love.graphics.setLineWidth(1)
    end
end

function scene.drawHUD()
    local vh = love.graphics.getHeight()
    if collected then
        love.graphics.setColor(0.2, 1.0, 0.3, 0.9)
        love.graphics.print("Candy collected! Press R to reset.", 10, 50)
    else
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.print("LMB swipe across ropes to cut. Guide candy to green target.", 10, 50)
    end
end

return scene

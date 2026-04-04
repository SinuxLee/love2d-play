local debug_draw = {}

local defaults = {
    show_bodies = true,
    show_joints = true,
    show_contacts = false,
    show_aabbs = false,
    show_center_of_mass = false,
    show_velocity = false,
    wireframe = true,
}

function debug_draw.new()
    local opts = {}
    for k, v in pairs(defaults) do
        opts[k] = v
    end
    return opts
end

local function getBodyColor(body)
    local t = body:getType()
    if t == "static" then
        return 0.5, 0.9, 0.5, 0.7
    elseif t == "kinematic" then
        return 0.5, 0.5, 0.9, 0.7
    elseif not body:isAwake() then
        return 0.6, 0.6, 0.6, 0.5
    else
        return 0.9, 0.7, 0.4, 0.7
    end
end

local function drawShape(shape, body, opts, selected)
    local t = shape:getType()

    if t == "circle" then
        local cx, cy = body:getWorldPoint(shape:getPoint())
        local r = shape:getRadius()
        if opts.wireframe then
            love.graphics.circle("line", cx, cy, r)
        else
            love.graphics.circle("fill", cx, cy, r)
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.circle("line", cx, cy, r)
        end
        -- draw direction line
        local angle = body:getAngle()
        love.graphics.line(cx, cy, cx + r * math.cos(angle), cy + r * math.sin(angle))

    elseif t == "polygon" then
        local points = {body:getWorldPoints(shape:getPoints())}
        if opts.wireframe then
            love.graphics.polygon("line", points)
        else
            love.graphics.polygon("fill", points)
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.polygon("line", points)
        end

    elseif t == "edge" then
        local x1, y1, x2, y2 = body:getWorldPoints(shape:getPoints())
        love.graphics.line(x1, y1, x2, y2)

    elseif t == "chain" then
        local points = {body:getWorldPoints(shape:getPoints())}
        love.graphics.line(points)
    end
end

local function drawBody(body, opts, selected_body)
    local r, g, b, a = getBodyColor(body)
    local fixtures = body:getFixtures()

    for _, fixture in ipairs(fixtures) do
        local shape = fixture:getShape()
        if body == selected_body then
            love.graphics.setColor(1, 0.3, 0.3, 0.9)
        else
            love.graphics.setColor(r, g, b, a)
        end
        drawShape(shape, body, opts, body == selected_body)
    end
end

local function drawJoint(joint)
    local t = joint:getType()
    love.graphics.setColor(0.3, 0.8, 0.8, 0.8)

    if t == "distance" then
        local x1, y1, x2, y2 = joint:getAnchors()
        love.graphics.line(x1, y1, x2, y2)

    elseif t == "revolute" then
        local x1, y1, x2, y2 = joint:getAnchors()
        love.graphics.circle("line", x1, y1, 4)
        love.graphics.line(x1, y1, x2, y2)

    elseif t == "prismatic" then
        local x1, y1, x2, y2 = joint:getAnchors()
        love.graphics.line(x1, y1, x2, y2)
        love.graphics.rectangle("line", x1 - 3, y1 - 3, 6, 6)

    elseif t == "pulley" then
        local x1, y1, x2, y2 = joint:getAnchors()
        local gx1, gy1, gx2, gy2 = joint:getGroundAnchors()
        love.graphics.line(x1, y1, gx1, gy1)
        love.graphics.line(x2, y2, gx2, gy2)
        love.graphics.line(gx1, gy1, gx2, gy2)

    elseif t == "mouse" then
        local x1, y1, x2, y2 = joint:getAnchors()
        love.graphics.setColor(0.2, 1.0, 0.2, 0.8)
        love.graphics.line(x1, y1, x2, y2)
        love.graphics.circle("fill", x2, y2, 3)

    elseif t == "gear" then
        -- gear joints don't have meaningful visual anchors
    elseif t == "weld" then
        local x1, y1 = joint:getAnchors()
        love.graphics.circle("fill", x1, y1, 4)

    elseif t == "rope" then
        local x1, y1, x2, y2 = joint:getAnchors()
        love.graphics.setColor(0.8, 0.6, 0.3, 0.8)
        love.graphics.line(x1, y1, x2, y2)

    elseif t == "wheel" then
        local x1, y1, x2, y2 = joint:getAnchors()
        love.graphics.line(x1, y1, x2, y2)
        love.graphics.circle("line", x2, y2, 5)

    elseif t == "friction" then
        local x1, y1 = joint:getAnchors()
        love.graphics.setColor(0.8, 0.4, 0.4, 0.8)
        love.graphics.circle("line", x1, y1, 5)

    elseif t == "motor" then
        local x1, y1, x2, y2 = joint:getAnchors()
        love.graphics.setColor(0.4, 0.8, 0.4, 0.8)
        love.graphics.line(x1, y1, x2, y2)
    else
        local ok, x1, y1, x2, y2 = pcall(joint.getAnchors, joint)
        if ok and x1 then
            love.graphics.line(x1, y1, x2 or x1, y2 or y1)
        end
    end
end

local function drawAABB(body)
    love.graphics.setColor(0.8, 0.8, 0.2, 0.3)
    for _, fixture in ipairs(body:getFixtures()) do
        local topLeftX, topLeftY, bottomRightX, bottomRightY = fixture:getBoundingBox()
        love.graphics.rectangle("line", topLeftX, topLeftY,
            bottomRightX - topLeftX, bottomRightY - topLeftY)
    end
end

local function drawCenterOfMass(body)
    if body:getType() == "static" then return end
    local cx, cy = body:getWorldCenter()
    love.graphics.setColor(1, 0, 0, 0.8)
    love.graphics.circle("fill", cx, cy, 3)
end

local function drawVelocity(body)
    if body:getType() == "static" then return end
    local cx, cy = body:getWorldCenter()
    local vx, vy = body:getLinearVelocity()
    local scale = 0.1
    love.graphics.setColor(1, 1, 0, 0.6)
    love.graphics.line(cx, cy, cx + vx * scale, cy + vy * scale)
end

local function drawContacts(world)
    love.graphics.setColor(1, 0, 0, 0.9)
    local contacts = world:getContacts()
    for _, contact in ipairs(contacts) do
        if contact:isTouching() then
            local x1, y1, x2, y2 = contact:getPositions()
            if x1 then
                love.graphics.circle("fill", x1, y1, 3)
            end
            if x2 then
                love.graphics.circle("fill", x2, y2, 3)
            end
        end
    end
end

function debug_draw.draw(world, opts, selected_body)
    love.graphics.setLineWidth(1)

    if opts.show_bodies then
        local bodies = world:getBodies()
        for _, body in ipairs(bodies) do
            drawBody(body, opts, selected_body)
        end
    end

    if opts.show_aabbs then
        local bodies = world:getBodies()
        for _, body in ipairs(bodies) do
            drawAABB(body)
        end
    end

    if opts.show_center_of_mass then
        local bodies = world:getBodies()
        for _, body in ipairs(bodies) do
            drawCenterOfMass(body)
        end
    end

    if opts.show_velocity then
        local bodies = world:getBodies()
        for _, body in ipairs(bodies) do
            drawVelocity(body)
        end
    end

    if opts.show_joints then
        local joints = world:getJoints()
        for _, joint in ipairs(joints) do
            drawJoint(joint)
        end
    end

    if opts.show_contacts then
        drawContacts(world)
    end
end

function debug_draw.drawGrid(camera)
    local w, h = love.graphics.getDimensions()
    local left, top = camera:toWorld(0, 0)
    local right, bottom = camera:toWorld(w, h)

    local grid_size = 50
    local scale = camera.scale
    while grid_size * scale < 30 do grid_size = grid_size * 2 end
    while grid_size * scale > 120 do grid_size = grid_size / 2 end

    love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
    love.graphics.setLineWidth(1)

    local start_x = math.floor(left / grid_size) * grid_size
    local start_y = math.floor(top / grid_size) * grid_size

    for x = start_x, right, grid_size do
        love.graphics.line(x, top, x, bottom)
    end
    for y = start_y, bottom, grid_size do
        love.graphics.line(left, y, right, y)
    end

    -- axes
    love.graphics.setColor(0.4, 0.2, 0.2, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.line(left, 0, right, 0)
    love.graphics.setColor(0.2, 0.4, 0.2, 0.7)
    love.graphics.line(0, top, 0, bottom)
    love.graphics.setLineWidth(1)
end

return debug_draw

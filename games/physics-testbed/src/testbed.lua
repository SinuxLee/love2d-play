local Camera = require "camera"
local debug_draw = require "debug_draw"
local debug_panel = require "debug_panel"
local scenes = require "scenes"

local testbed = {}
testbed.__index = testbed

function testbed:init()
    self.camera = Camera.new()
    self.draw_opts = debug_draw.new()
    self.panel = debug_panel.new(self)

    -- physics state
    self.world = nil
    self.paused = false
    self.speed = 1.0
    self.speed_info = {value = 1.0, min = 0.0, max = 4.0, step = 0.25}
    self.accumulator = 0
    self.fixed_dt = 1 / 60

    -- iterations
    self.vel_iters = 8
    self.pos_iters = 3
    self.vel_iters_info = {value = 8, min = 1, max = 30, step = 1}
    self.pos_iters_info = {value = 3, min = 1, max = 20, step = 1}

    -- gravity
    self.gravity_x_info = {value = 0, min = -100, max = 100, step = 1}
    self.gravity_y_info = {value = 98, min = -500, max = 500, step = 1}

    -- interaction
    self.selected_body = nil
    self.mouse_joint = nil
    self.mouse_body = nil

    -- selected body property caches (reset on body change)
    self.sel_density_info = nil
    self.sel_friction_info = nil
    self.sel_restitution_info = nil
    self.sel_ldamp_info = nil
    self.sel_adamp_info = nil

    -- scenes
    self.scenes = scenes
    self.current_scene = nil
    self.current_scene_name = nil

    -- load first scene
    local list = self:getSceneList()
    if #list > 0 then
        self:switchScene(list[1])
    end
end

function testbed:getSceneList()
    local list = {}
    for name in pairs(self.scenes) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

function testbed:switchScene(name)
    self:destroyWorld()
    self.selected_body = nil
    self.sel_density_info = nil
    self.sel_friction_info = nil
    self.sel_restitution_info = nil
    self.sel_ldamp_info = nil
    self.sel_adamp_info = nil

    local gx = self.gravity_x_info.value
    local gy = self.gravity_y_info.value
    self.world = love.physics.newWorld(gx, gy, true)
    self.current_scene_name = name
    self.current_scene = self.scenes[name]

    if self.current_scene and self.current_scene.setup then
        self.current_scene.setup(self.world)
    end

    self.camera:reset()
    self.camera.x = 400
    self.camera.y = 300
    self.paused = false
end

function testbed:resetScene()
    if self.current_scene_name then
        self:switchScene(self.current_scene_name)
    end
end

function testbed:destroyWorld()
    if self.mouse_joint then
        self.mouse_joint:destroy()
        self.mouse_joint = nil
    end
    if self.mouse_body then
        self.mouse_body:destroy()
        self.mouse_body = nil
    end
    if self.world then
        self.world:destroy()
        self.world = nil
    end
end

function testbed:step()
    if self.world then
        self.world:update(self.fixed_dt, self.vel_iters, self.pos_iters)
        if self.current_scene and self.current_scene.update then
            self.current_scene.update(self.world, self.fixed_dt)
        end
    end
end

function testbed:update(dt)
    -- update panel UI
    self.panel:update(dt)

    if not self.world or self.paused then return end

    local scaled_dt = dt * self.speed
    self.accumulator = self.accumulator + scaled_dt

    while self.accumulator >= self.fixed_dt do
        self.world:update(self.fixed_dt, self.vel_iters, self.pos_iters)
        if self.current_scene and self.current_scene.update then
            self.current_scene.update(self.world, self.fixed_dt)
        end
        self.accumulator = self.accumulator - self.fixed_dt
    end

    -- update mouse joint target
    if self.mouse_joint then
        local mx, my = love.mouse.getPosition()
        local wx, wy = self.camera:toWorld(mx, my)
        self.mouse_joint:setTarget(wx, wy)
    end
end

function testbed:draw()
    love.graphics.clear(0.12, 0.12, 0.14)

    -- world viewport (exclude panel area)
    local panel_w = self.panel.visible and self.panel.width or 0
    local vw = love.graphics.getWidth() - panel_w
    local vh = love.graphics.getHeight()

    love.graphics.setScissor(0, 0, vw, vh)

    self.camera:attach()

    debug_draw.drawGrid(self.camera)

    if self.world then
        debug_draw.draw(self.world, self.draw_opts, self.selected_body)
    end

    if self.current_scene and self.current_scene.draw then
        self.current_scene.draw(self.world)
    end

    self.camera:detach()

    love.graphics.setScissor()

    -- HUD
    love.graphics.setColor(1, 1, 1, 0.7)
    local info = string.format("FPS: %d | Bodies: %d | Joints: %d | Contacts: %d",
        love.timer.getFPS(),
        self.world and #self.world:getBodies() or 0,
        self.world and #self.world:getJoints() or 0,
        self.world and #self.world:getContacts() or 0)
    love.graphics.print(info, 10, 10)

    if self.paused then
        love.graphics.setColor(1, 0.3, 0.3, 0.9)
        love.graphics.print("PAUSED", 10, 30)
    end

    love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
    love.graphics.print("RMB: Pan | Scroll: Zoom | Space: Pause | R: Reset | Tab: Panel | S: Step", 10, vh - 20)

    if self.current_scene and self.current_scene.drawHUD then
        self.current_scene.drawHUD()
    end

    -- panel
    self.panel:draw()
end

function testbed:findBodyAt(wx, wy)
    if not self.world then return nil end
    local bodies = self.world:getBodies()
    for _, body in ipairs(bodies) do
        for _, fixture in ipairs(body:getFixtures()) do
            if fixture:testPoint(wx, wy) then
                return body
            end
        end
    end
    return nil
end

function testbed:mousepressed(x, y, button)
    -- ignore if over panel
    if self.panel:isMouseOver(x, y) then return end

    local wx, wy = self.camera:toWorld(x, y)

    -- scene-level input
    if self.current_scene and self.current_scene.mousepressed then
        if self.current_scene.mousepressed(self.world, wx, wy, button) then
            self.camera:mousepressed(x, y, button)
            return
        end
    end

    if button == 1 then
        local body = self:findBodyAt(wx, wy)
        if body then
            self.selected_body = body
            -- reset property caches
            self.sel_density_info = nil
            self.sel_friction_info = nil
            self.sel_restitution_info = nil
            self.sel_ldamp_info = nil
            self.sel_adamp_info = nil

            if body:getType() == "dynamic" then
                -- create mouse joint for dragging
                if not self.mouse_body then
                    self.mouse_body = love.physics.newBody(self.world, 0, 0, "static")
                end
                self.mouse_joint = love.physics.newMouseJoint(body, wx, wy)
                self.mouse_joint:setMaxForce(1000 * body:getMass())
            end
        else
            self.selected_body = nil
        end
    end

    self.camera:mousepressed(x, y, button)
end

function testbed:mousereleased(x, y, button)
    local wx, wy = self.camera:toWorld(x, y)

    if self.current_scene and self.current_scene.mousereleased then
        if self.current_scene.mousereleased(self.world, wx, wy, button) then
            self.camera:mousereleased(x, y, button)
            return
        end
    end

    if button == 1 and self.mouse_joint then
        self.mouse_joint:destroy()
        self.mouse_joint = nil
    end
    self.camera:mousereleased(x, y, button)
end

function testbed:mousemoved(x, y, dx, dy)
    if self.current_scene and self.current_scene.mousemoved then
        local wx, wy = self.camera:toWorld(x, y)
        local wdx = dx / self.camera.scale
        local wdy = dy / self.camera.scale
        self.current_scene.mousemoved(self.world, wx, wy, wdx, wdy)
    end
    self.camera:mousemoved(x, y, dx, dy)
end

function testbed:wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()
    if not self.panel:isMouseOver(mx, my) then
        self.camera:wheelmoved(x, y)
    end
end

function testbed:keypressed(key)
    if self.current_scene and self.current_scene.keypressed then
        if self.current_scene.keypressed(key) then return end
    end

    if key == "space" then
        self.paused = not self.paused
    elseif key == "r" then
        self:resetScene()
    elseif key == "s" then
        self:step()
    elseif key == "tab" then
        self.panel:toggle()
    elseif key == "escape" then
        love.event.quit()
    end
end

function testbed:resize(w, h)
    -- nothing special needed, panel reflows automatically
end

return testbed

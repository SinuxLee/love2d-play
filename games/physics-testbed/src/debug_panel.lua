local suit = require "suit"

local panel = {}
panel.__index = panel

function panel.new(testbed)
    local self = setmetatable({}, panel)
    self.testbed = testbed
    self.width = 280
    self.scroll_y = 0
    self.visible = true

    -- scene list state
    self.scene_scroll = 0

    return self
end

function panel:update(dt)
    if not self.visible then return end

    local tb = self.testbed
    local x = love.graphics.getWidth() - self.width
    local y = 10
    local w = self.width - 20
    local pad = x + 10

    -- === Scene Selection ===
    suit.Label("-- SCENES --", {align = "center"}, pad, y, w, 20)
    y = y + 24

    local scenes = tb:getSceneList()
    for i, name in ipairs(scenes) do
        local label = name
        if name == tb.current_scene_name then
            label = "> " .. name
        end
        if suit.Button(label, {id = "scene_" .. name}, pad, y, w, 22).hit then
            tb:switchScene(name)
        end
        y = y + 24
    end
    y = y + 8

    -- === Simulation Controls ===
    suit.Label("-- SIMULATION --", {align = "center"}, pad, y, w, 20)
    y = y + 24

    local bw = (w - 8) / 3
    if suit.Button(tb.paused and "Play" or "Pause", {id = "btn_pause"}, pad, y, bw, 26).hit then
        tb.paused = not tb.paused
    end
    if suit.Button("Step", {id = "btn_step"}, pad + bw + 4, y, bw, 26).hit then
        tb:step()
    end
    if suit.Button("Reset", {id = "btn_reset"}, pad + (bw + 4) * 2, y, bw, 26).hit then
        tb:resetScene()
    end
    y = y + 32

    -- speed
    suit.Label(string.format("Speed: %.2fx", tb.speed), pad, y, w, 18)
    y = y + 20
    suit.Slider(tb.speed_info, pad, y, w, 16)
    tb.speed = tb.speed_info.value
    y = y + 24

    -- === Global Physics ===
    suit.Label("-- WORLD --", {align = "center"}, pad, y, w, 20)
    y = y + 24

    -- gravity
    suit.Label(string.format("Gravity X: %.1f", tb.gravity_x_info.value), pad, y, w, 18)
    y = y + 20
    suit.Slider(tb.gravity_x_info, pad, y, w, 16)
    y = y + 22

    suit.Label(string.format("Gravity Y: %.1f", tb.gravity_y_info.value), pad, y, w, 18)
    y = y + 20
    suit.Slider(tb.gravity_y_info, pad, y, w, 16)
    y = y + 22

    if tb.world then
        tb.world:setGravity(tb.gravity_x_info.value, tb.gravity_y_info.value)
    end

    -- iterations
    suit.Label(string.format("Vel Iters: %d", tb.vel_iters_info.value), pad, y, w, 18)
    y = y + 20
    suit.Slider(tb.vel_iters_info, pad, y, w, 16)
    tb.vel_iters = math.floor(tb.vel_iters_info.value + 0.5)
    y = y + 22

    suit.Label(string.format("Pos Iters: %d", tb.pos_iters_info.value), pad, y, w, 18)
    y = y + 20
    suit.Slider(tb.pos_iters_info, pad, y, w, 16)
    tb.pos_iters = math.floor(tb.pos_iters_info.value + 0.5)
    y = y + 28

    -- === Debug Render ===
    suit.Label("-- RENDER --", {align = "center"}, pad, y, w, 20)
    y = y + 24

    local draw_opts = tb.draw_opts
    local toggles = {
        {"Bodies",    "show_bodies"},
        {"Joints",    "show_joints"},
        {"Contacts",  "show_contacts"},
        {"AABBs",     "show_aabbs"},
        {"CoM",       "show_center_of_mass"},
        {"Velocity",  "show_velocity"},
        {"Wireframe", "wireframe"},
    }

    for _, t in ipairs(toggles) do
        local label, key = t[1], t[2]
        local chk = {checked = draw_opts[key]}
        if suit.Checkbox(chk, {id = "chk_" .. key}, pad, y, 20, 20).hit then
            draw_opts[key] = chk.checked
        end
        suit.Label(label, pad + 24, y, w - 24, 20)
        y = y + 22
    end
    y = y + 8

    -- === Selected Body ===
    local body = tb.selected_body
    if body and not body:isDestroyed() then
        suit.Label("-- SELECTED BODY --", {align = "center"}, pad, y, w, 20)
        y = y + 24

        -- body type
        local btype = body:getType()
        local types = {"dynamic", "static", "kinematic"}
        for _, bt in ipairs(types) do
            local label = bt:sub(1, 1):upper() .. bt:sub(2)
            if btype == bt then label = "[" .. label .. "]" end
            local bw2 = (w - 8) / 3
            local idx = bt == "dynamic" and 0 or (bt == "static" and 1 or 2)
            if suit.Button(label, {id = "btype_" .. bt}, pad + idx * (bw2 + 4), y, bw2, 22).hit then
                body:setType(bt)
            end
        end
        y = y + 28

        -- get first fixture for properties
        local fixtures = body:getFixtures()
        local fixture = fixtures[1]

        if fixture then
            -- density
            local density = fixture:getDensity()
            if not tb.sel_density_info or tb.sel_density_info._body ~= body then
                tb.sel_density_info = {value = density, min = 0, max = 50, step = 0.5, _body = body}
            end
            suit.Label(string.format("Density: %.1f", tb.sel_density_info.value), pad, y, w, 18)
            y = y + 20
            if suit.Slider(tb.sel_density_info, pad, y, w, 16).changed then
                fixture:setDensity(tb.sel_density_info.value)
                body:resetMassData()
            end
            y = y + 22

            -- friction
            local fric = fixture:getFriction()
            if not tb.sel_friction_info or tb.sel_friction_info._body ~= body then
                tb.sel_friction_info = {value = fric, min = 0, max = 2, step = 0.05, _body = body}
            end
            suit.Label(string.format("Friction: %.2f", tb.sel_friction_info.value), pad, y, w, 18)
            y = y + 20
            if suit.Slider(tb.sel_friction_info, pad, y, w, 16).changed then
                fixture:setFriction(tb.sel_friction_info.value)
            end
            y = y + 22

            -- restitution
            local rest = fixture:getRestitution()
            if not tb.sel_restitution_info or tb.sel_restitution_info._body ~= body then
                tb.sel_restitution_info = {value = rest, min = 0, max = 1, step = 0.05, _body = body}
            end
            suit.Label(string.format("Restitution: %.2f", tb.sel_restitution_info.value), pad, y, w, 18)
            y = y + 20
            if suit.Slider(tb.sel_restitution_info, pad, y, w, 16).changed then
                fixture:setRestitution(tb.sel_restitution_info.value)
            end
            y = y + 22
        end

        -- linear damping
        local ld = body:getLinearDamping()
        if not tb.sel_ldamp_info or tb.sel_ldamp_info._body ~= body then
            tb.sel_ldamp_info = {value = ld, min = 0, max = 10, step = 0.1, _body = body}
        end
        suit.Label(string.format("Linear Damp: %.1f", tb.sel_ldamp_info.value), pad, y, w, 18)
        y = y + 20
        if suit.Slider(tb.sel_ldamp_info, pad, y, w, 16).changed then
            body:setLinearDamping(tb.sel_ldamp_info.value)
        end
        y = y + 22

        -- angular damping
        local ad = body:getAngularDamping()
        if not tb.sel_adamp_info or tb.sel_adamp_info._body ~= body then
            tb.sel_adamp_info = {value = ad, min = 0, max = 10, step = 0.1, _body = body}
        end
        suit.Label(string.format("Angular Damp: %.1f", tb.sel_adamp_info.value), pad, y, w, 18)
        y = y + 20
        if suit.Slider(tb.sel_adamp_info, pad, y, w, 16).changed then
            body:setAngularDamping(tb.sel_adamp_info.value)
        end
        y = y + 22

        -- fixed rotation
        local chk_fixed = {checked = body:isFixedRotation()}
        if suit.Checkbox(chk_fixed, {id = "chk_fixrot"}, pad, y, 20, 20).hit then
            body:setFixedRotation(chk_fixed.checked)
        end
        suit.Label("Fixed Rotation", pad + 24, y, w - 24, 20)
        y = y + 22

        -- bullet
        local chk_bullet = {checked = body:isBullet()}
        if suit.Checkbox(chk_bullet, {id = "chk_bullet"}, pad, y, 20, 20).hit then
            body:setBullet(chk_bullet.checked)
        end
        suit.Label("Bullet (CCD)", pad + 24, y, w - 24, 20)
        y = y + 22

        -- mass info (read-only)
        suit.Label(string.format("Mass: %.2f", body:getMass()), pad, y, w, 18)
        y = y + 20
        suit.Label(string.format("Inertia: %.1f", body:getInertia()), pad, y, w, 18)
        y = y + 20
        local vx, vy = body:getLinearVelocity()
        suit.Label(string.format("Vel: (%.1f, %.1f)", vx, vy), pad, y, w, 18)
        y = y + 20
        suit.Label(string.format("AngVel: %.2f", body:getAngularVelocity()), pad, y, w, 18)
        y = y + 24
    end

    self.content_height = y
end

function panel:draw()
    if not self.visible then return end

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- panel background
    love.graphics.setColor(0.1, 0.1, 0.12, 0.9)
    love.graphics.rectangle("fill", w - self.width, 0, self.width, h)
    love.graphics.setColor(0.3, 0.3, 0.35, 1)
    love.graphics.line(w - self.width, 0, w - self.width, h)

    suit.draw()
end

function panel:isMouseOver(mx, my)
    if not self.visible then return false end
    return mx > love.graphics.getWidth() - self.width
end

function panel:toggle()
    self.visible = not self.visible
end

return panel

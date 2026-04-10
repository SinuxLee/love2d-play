-- parallax.lua
local ParallaxSystem = {}
ParallaxSystem.__index = ParallaxSystem

function ParallaxSystem:new()
    local o = setmetatable({}, ParallaxSystem)
    o.layers = {}
    return o
end

--[[
    添加视差层：
    image    : 纹理（推荐 wrap 模式设为 "repeat"）
    factor   : 视差因子 (0 = 不动/最远背景, 1 = 与摄像机同步/最近前景)
    scaleX/Y : 缩放
    offsetY  : 垂直偏移
    tint     : 颜色调制 {r, g, b, a}
]]
function ParallaxSystem:addLayer(config)
    local layer = {
        image   = config.image,
        factor  = config.factor or 0.5,
        scaleX  = config.scaleX or 1,
        scaleY  = config.scaleY or 1,
        offsetX = config.offsetX or 0,
        offsetY = config.offsetY or 0,
        tint    = config.tint or {1, 1, 1, 1},
        repeatX = config.repeatX ~= false,  -- 默认水平重复
        repeatY = config.repeatY or false,
    }

    -- 设置纹理重复模式
    if layer.repeatX or layer.repeatY then
        local wrapH = layer.repeatX and "repeat" or "clamp"
        local wrapV = layer.repeatY and "repeat" or "clamp"
        layer.image:setWrap(wrapH, wrapV)
    end

    -- 创建用于平铺的 Quad
    layer.quad = love.graphics.newQuad(
        0, 0,
        love.graphics.getWidth() / layer.scaleX + layer.image:getWidth(),
        love.graphics.getHeight() / layer.scaleY + layer.image:getHeight(),
        layer.image:getDimensions()
    )

    table.insert(self.layers, layer)

    -- 按 factor 排序（远景先画）
    table.sort(self.layers, function(a, b) return a.factor < b.factor end)
end

function ParallaxSystem:draw(camX, camY)
    for _, layer in ipairs(self.layers) do
        love.graphics.setColor(layer.tint)

        -- 核心公式：层偏移 = 摄像机位移 × 视差因子
        local scrollX = camX * layer.factor + layer.offsetX
        local scrollY = camY * layer.factor + layer.offsetY

        if layer.repeatX or layer.repeatY then
            -- 使用 Quad 实现无缝平铺
            local imgW = layer.image:getWidth()
            local imgH = layer.image:getHeight()

            local qx = scrollX % imgW
            local qy = scrollY % imgH

            layer.quad:setViewport(
                qx, qy,
                love.graphics.getWidth() / layer.scaleX,
                love.graphics.getHeight() / layer.scaleY
            )

            love.graphics.draw(layer.image, layer.quad,
                0, 0, 0,
                layer.scaleX, layer.scaleY
            )
        else
            love.graphics.draw(layer.image,
                -scrollX, -scrollY + layer.offsetY,
                0,
                layer.scaleX, layer.scaleY
            )
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ParallaxSystem

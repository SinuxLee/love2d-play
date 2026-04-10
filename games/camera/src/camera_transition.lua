-- camera_transition.lua
local CameraTransition = {}
CameraTransition.__index = CameraTransition

--- 过渡效果类型
local TransitionFX = {
    -- 简单交叉混合
    crossfade = {
        update = function(self, dt) end,
        getBlend = function(self, progress) return progress end,
    },
    -- 黑幕过渡
    fadeToBlack = {
        update = function(self, dt) end,
        getBlend = function(self, progress)
            -- 前半段淡入黑色，后半段淡出
            if progress < 0.5 then
                return 0  -- 还在用旧摄像机
            else
                return 1  -- 切到新摄像机
            end
        end,
        getBlackAlpha = function(self, progress)
            -- 黑色遮罩的透明度
            if progress < 0.5 then
                return progress * 2        -- 0 → 1
            else
                return (1 - progress) * 2  -- 1 → 0
            end
        end,
    },
    -- 白色闪光过渡（适合战斗开始）
    flashWhite = {
        getBlend = function(self, progress)
            return progress < 0.4 and 0 or 1
        end,
        getWhiteAlpha = function(self, progress)
            if progress < 0.3 then return progress / 0.3 end
            return math.max(0, 1 - (progress - 0.3) / 0.7)
        end,
    },
}

function CameraTransition:new()
    local o = setmetatable({}, CameraTransition)
    o.isTransitioning = false
    o.fromCam = nil
    o.toCam = nil
    o.duration = 1
    o.timer = 0
    o.fxType = "crossfade"
    o.easing = function(t) return t end
    return o
end

function CameraTransition:start(fromCam, toCam, duration, fxType, easing)
    self.isTransitioning = true
    self.fromCam = fromCam
    self.toCam = toCam
    self.duration = duration or 1
    self.timer = 0
    self.fxType = fxType or "crossfade"
    self.easing = easing or function(t)
        return -(math.cos(math.pi * t) - 1) / 2 -- easeInOutSine
    end
end

function CameraTransition:update(dt)
    if not self.isTransitioning then return end
    self.timer = self.timer + dt
    if self.timer >= self.duration then
        self.isTransitioning = false
    end
end

--- 获取当前混合后的摄像机参数
function CameraTransition:getBlended()
    if not self.isTransitioning then
        return self.toCam or self.fromCam
    end

    local rawT = math.min(self.timer / self.duration, 1)
    local t = self.easing(rawT)
    local fx = TransitionFX[self.fxType] or TransitionFX.crossfade
    local blend = fx.getBlend(fx, t)

    local from = self.fromCam
    local to = self.toCam

    -- 混合摄像机参数
    return {
        x = from.x + (to.x - from.x) * blend,
        y = from.y + (to.y - from.y) * blend,
        scale = from.scale + (to.scale - from.scale) * blend,
        rotation = (from.rotation or 0) + ((to.rotation or 0) - (from.rotation or 0)) * blend,
    }
end

--- 获取遮罩信息（用于绘制黑屏/白屏过渡）
function CameraTransition:getOverlay()
    if not self.isTransitioning then return nil end

    local rawT = math.min(self.timer / self.duration, 1)
    local fx = TransitionFX[self.fxType]

    if fx and fx.getBlackAlpha then
        return { type = "black", alpha = fx.getBlackAlpha(fx, rawT) }
    elseif fx and fx.getWhiteAlpha then
        return { type = "white", alpha = fx.getWhiteAlpha(fx, rawT) }
    end
    return nil
end

return CameraTransition

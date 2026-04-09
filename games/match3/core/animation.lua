---@class TweenModule
local Tweens = {}

---@type Tween[]
local activeTweens = {}

---@param t number
---@return number
local function linear(t)
    return t
end

---@param t number
---@return number
local function easeOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

---@param t number
---@return number
local function easeOutBounce(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    end
end

---@type table<string, fun(t: number): number>
local easings = {
    linear = linear,
    easeOutQuad = easeOutQuad,
    easeOutBounce = easeOutBounce,
}

---@param target table
---@param field string
---@param endVal number
---@param duration number
---@param easing? string
---@param onComplete? fun()
---@return Tween
function Tweens.add(target, field, endVal, duration, easing, onComplete)
    local tween = {
        target = target,
        field = field,
        startVal = target[field],
        endVal = endVal,
        duration = duration,
        elapsed = 0,
        easing = easings[easing] or linear,
        onComplete = onComplete,
    }
    table.insert(activeTweens, tween)
    return tween
end

---@param dt number
function Tweens.update(dt)
    local i = 1
    while i <= #activeTweens do
        local tw = activeTweens[i]
        tw.elapsed = tw.elapsed + dt
        local t = math.min(tw.elapsed / tw.duration, 1)
        local easedT = tw.easing(t)
        tw.target[tw.field] = tw.startVal + (tw.endVal - tw.startVal) * easedT

        if t >= 1 then
            tw.target[tw.field] = tw.endVal
            local cb = tw.onComplete
            table.remove(activeTweens, i)
            if cb then cb() end
        else
            i = i + 1
        end
    end
end

function Tweens.clear()
    activeTweens = {}
end

---@return boolean
function Tweens.isActive()
    return #activeTweens > 0
end

return Tweens

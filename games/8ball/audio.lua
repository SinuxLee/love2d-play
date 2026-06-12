-- Audio manager - loads and plays all sound effects and music
local Audio = {}

local sounds = {}
local bgMusic = nil
local bgMusic2 = nil
local sfxVolume = 0.5
local musicVolume = 0.3

local function loadSound(path, stype)
    local ok, src = pcall(love.audio.newSource, path, stype or "static")
    if ok then return src end
    return nil
end

function Audio.init()
    -- Core gameplay sounds
    sounds.ballHit = loadSound("sounds/BallHit.wav")
    sounds.ballCollider = loadSound("sounds/BallCollider.wav")
    sounds.cueHit = loadSound("sounds/CueHit.wav")
    sounds.pocket = loadSound("sounds/Pocket.wav")

    -- UI sounds
    sounds.click = loadSound("sounds/click.wav")
    sounds.fineTuning = loadSound("sounds/Fine_Tuning.mp3")

    -- Background music (two tracks, random or alternating)
    bgMusic = loadSound("sounds/Billiards_Bg_2.mp3", "stream")
    if bgMusic then
        bgMusic:setLooping(true)
        bgMusic:setVolume(musicVolume)
    end

    bgMusic2 = loadSound("sounds/Billiards_Bg_3.mp3", "stream")
    if bgMusic2 then
        bgMusic2:setLooping(true)
        bgMusic2:setVolume(musicVolume)
    end
end

function Audio.playBallHit(velocity)
    if sounds.ballHit then
        local vol = math.min(1.0, (velocity or 100) / 500) * sfxVolume
        local source = sounds.ballHit:clone()
        source:setVolume(vol)
        love.audio.play(source)
    end
end

function Audio.playBallCollider(velocity)
    local snd = sounds.ballCollider or sounds.ballHit
    if snd then
        local vol = math.min(1.0, (velocity or 100) / 500) * sfxVolume
        local source = snd:clone()
        source:setVolume(vol)
        love.audio.play(source)
    end
end

function Audio.playCueHit()
    if sounds.cueHit then
        local source = sounds.cueHit:clone()
        source:setVolume(sfxVolume)
        love.audio.play(source)
    end
end

function Audio.playPocket()
    if sounds.pocket then
        local source = sounds.pocket:clone()
        source:setVolume(sfxVolume)
        love.audio.play(source)
    end
end

function Audio.playClick()
    if sounds.click then
        local source = sounds.click:clone()
        source:setVolume(sfxVolume)
        love.audio.play(source)
    end
end

function Audio.playFineTuning()
    if sounds.fineTuning then
        local source = sounds.fineTuning:clone()
        source:setVolume(sfxVolume * 0.5)
        love.audio.play(source)
    end
end

function Audio.playBgMusic()
    -- Randomly pick one of the two tracks
    local track = bgMusic
    if bgMusic2 and math.random() > 0.5 then
        track = bgMusic2
    end
    if track then
        love.audio.play(track)
    end
end

function Audio.stopBgMusic()
    if bgMusic then love.audio.stop(bgMusic) end
    if bgMusic2 then love.audio.stop(bgMusic2) end
end

function Audio.setSfxVolume(vol)
    sfxVolume = vol
end

function Audio.setMusicVolume(vol)
    musicVolume = vol
    if bgMusic then bgMusic:setVolume(musicVolume) end
    if bgMusic2 then bgMusic2:setVolume(musicVolume) end
end

return Audio

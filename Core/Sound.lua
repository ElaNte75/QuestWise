-- Core: plays our sounds. Used by the quest-mob alert and the quest-complete sound.
-- Choices: "Default" (a sound of the game) + the files listed in Sounds/SoundList.lua.
-- Every file exists in several volumes: Sounds/<key>_<volume>.ogg
local ADDON, NA = ...

local Sound = {}
NA.Sound = Sound

Sound.SOUNDS = { { key = "Default", label = "Game default" } }
for _, s in ipairs(NA.SoundList or {}) do Sound.SOUNDS[#Sound.SOUNDS + 1] = s end
Sound.VOLUMES = NA.SoundVolumes or { 100 }

-- the add-on's own folder name (works before and after the folder is renamed)
local DIR = "Interface\\AddOns\\" .. ADDON .. "\\Sounds\\"

local function validChoice(choice)
    for _, s in ipairs(Sound.SOUNDS) do
        if s.key == choice then return choice end
    end
    return "Default"
end

-- the saved volume, snapped to the nearest volume we have files for
local function nearestVolume(v)
    v = tonumber(v) or 60
    local best = Sound.VOLUMES[1]
    for _, lvl in ipairs(Sound.VOLUMES) do
        if math.abs(lvl - v) < math.abs(best - v) then best = lvl end
    end
    return best
end

local function playDefault(kitName)
    local id = SOUNDKIT and (SOUNDKIT[kitName or ""] or SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01)
    if id and PlaySound then pcall(PlaySound, id, "Master") end
end

-- choice = saved choice key, volume = saved volume, kitName = which game sound "Default" means
function Sound.Play(choice, volume, kitName)
    choice = validChoice(choice)
    if choice == "Default" or not PlaySoundFile then return playDefault(kitName) end
    -- "Master" channel: follows the main game volume rather than the effects volume
    local ok, willPlay = pcall(PlaySoundFile, DIR .. choice .. "_" .. nearestVolume(volume) .. ".ogg", "Master")
    if not (ok and willPlay) then playDefault(kitName) end -- file missing: never stay silent
end

-- Options: "Sound" drop-down + "Volume" slider rows for one setting pair (used by the sound pages).
local ADDON, NA = ...

-- Adds two sub-rows to `stack` (see W.Stack).
-- keys = { choice = "<db key>", volume = "<db key>", kit = "<SOUNDKIT name of the game default>",
--          enabled = function() -> bool (optional: rows are dimmed while it returns false) }
-- Returns a refresh function.
function NA.Widgets.SoundPicker(parent, stack, keys)
    local W = NA.Widgets
    local S = NA.Sound
    local vols = S.VOLUMES

    local soundRow = stack:Add(W.Row(parent, "Sound"), "sub")
    local volumeRow = stack:Add(W.Row(parent, "Volume"), "sub")

    local function updateLook()
        local on = not keys.enabled or keys.enabled()
        W.SetActive(soundRow, on)
        -- "Default" is the game's own sound: our volume does not apply to it
        W.SetActive(volumeRow, on and (NA.db[keys.choice] or "Default") ~= "Default")
    end

    soundRow:SetControl(W.Dropdown(soundRow, S.SOUNDS,
        function() return NA.db[keys.choice] or "Default" end,
        function(key)
            NA.db[keys.choice] = key
            updateLook()
            S.Play(key, NA.db[keys.volume], keys.kit) -- you hear it once when you pick it
        end))

    volumeRow:SetControl(W.Slider(volumeRow, vols[1], vols[#vols], vols[2] and (vols[2] - vols[1]) or 10, "%",
        function() return NA.db[keys.volume] or 60 end,
        function(v) NA.db[keys.volume] = v end,
        function() S.Play(NA.db[keys.choice], NA.db[keys.volume], keys.kit) end)) -- plays when you let go

    return function()
        soundRow.control.Refresh()
        volumeRow.control.Refresh()
        updateLook()
    end
end

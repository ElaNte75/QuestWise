-- Options page "Quest complete": sound when a quest gets completed.
local ADDON, NA = ...

NA.Options.AddPage("complete", "Quest complete", function(parent)
    local W = NA.Widgets
    local st = W.Stack(parent)
    local refreshers = {}
    local function add(w) refreshers[#refreshers + 1] = w.Refresh; return w end

    st:Add(W.PageHeader(parent, "Quest complete", "What happens when a quest is ready to turn in."), "header")

    st:Add(W.Section(parent, "Sound"), "section")
    local refreshPicker
    st:Add(add(W.Checkbox(parent, "Play a sound when a quest is completed",
        "Plays a sound when one of your tracked quests has all its objectives done and is ready to turn in.",
        function() return NA.db.completeSoundEnabled end,
        function(v) NA.db.completeSoundEnabled = v; refreshPicker() end)), "row")

    refreshPicker = W.SoundPicker(parent, st, {
        choice = "completeSoundChoice", volume = "completeSoundVolume", kit = NA.CompleteSound.SOUND_KIT,
        enabled = function() return NA.db.completeSoundEnabled end,
    })

    return function()
        for _, r in ipairs(refreshers) do r() end
        refreshPicker()
    end
end)

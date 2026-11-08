-- Options page "Quest mobs": marking mobs, and what happens when you find a mob of a quest
-- that is not in your list (show the quest, for how long, play a sound).
local ADDON, NA = ...

NA.Options.AddPage("mobs", "Quest mobs", function(parent)
    local W = NA.Widgets
    local st = W.Stack(parent)
    local refreshers = {}
    local function add(w) refreshers[#refreshers + 1] = w.Refresh; return w end

    local function applyChange()
        if NA.Nameplates then NA.Nameplates.Apply() end
        if NA.QuestMobMarker then NA.QuestMobMarker.RefreshAll() end
    end

    st:Add(W.PageHeader(parent, "Quest mobs", "Marks on the enemies your quests need, and what happens when you meet one."), "header")

    -- 1. marking the mobs
    st:Add(W.Section(parent, "Marking"), "section")
    st:Add(add(W.Checkbox(parent, "Mark quest mobs",
        "Puts a quest mark on enemies that your quests still need: next to the health bar, or next to the name when the nameplates are off.",
        function() return NA.db.markQuestMobs end,
        function(v) NA.db.markQuestMobs = v; applyChange() end)), "row")

    st:Add(add(W.Checkbox(parent, "Show enemy nameplates",
        "The health bars above enemies (the V key). Turn it off to hide them: with the mark on you still see the name and mark of quest mobs.",
        function() return NA.db.showNameplates and true or false end,
        function(v) NA.db.showNameplates = v; applyChange() end)), "row")

    -- how far away enemies show up (the game's nameplate range): also how far a quest mob can be seen
    local rangeRow = st:Add(W.Row(parent, "Seen up to"), "row")
    local rangeSlider
    rangeSlider = add(rangeRow:SetControl(W.Slider(rangeRow, 10, 40, 5, " yd",
        function() return math.min(NA.db.nameplateRange or (NA.Nameplates and NA.Nameplates.Range()) or 40, 40) end,
        function(v) NA.db.nameplateRange = v; if NA.Nameplates then NA.Nameplates.Apply() end end,
        function()
            -- the game may cap the value: show what it really uses
            local actual = NA.Nameplates and NA.Nameplates.Range()
            if actual and actual ~= NA.db.nameplateRange then
                NA.db.nameplateRange = actual
                rangeSlider.Refresh()
            end
        end,
        { majorEvery = 10 })))
    st:Add(W.Note(parent, "How far away you see enemies (bars, names, quest marks). The game shows nothing beyond 40 yards."), "note")

    -- mark look: colour by difficulty, progress next to it (Mobs/MobLook.lua)
    local ML = NA.MobLook
    st:Add(W.Section(parent, "Mark look"), "section")
    local mobCustomCheck, mobColorRows = nil, {}
    local function refreshMobColors()
        local on = ML.ColorsOn()
        if mobCustomCheck then W.SetActive(mobCustomCheck, on) end
        for _, r in ipairs(mobColorRows) do W.SetActive(r, on and ML.CustomOn()) end
    end
    st:Add(add(W.Checkbox(parent, "Colour the mark by difficulty",
        "The quest mark takes the mob's difficulty colour: red very hard, orange hard, yellow your level, green easy, grey too easy. Mobs shown as ?? are always red.",
        function() return ML.ColorsOn() end,
        function(v) NA.db.mobColors = v; refreshMobColors(); applyChange() end)), "row")
    mobCustomCheck = st:Add(add(W.Checkbox(parent, "Use my own levels",
        "Ticked: the colours follow the level limits below instead of the game's. These are separate from the quest list colours.",
        function() return ML.CustomOn() end,
        function(v) NA.db.mobColorsCustom = v; refreshMobColors(); applyChange() end)), "sub")
    for _, s in ipairs({ { "red", "Red from", "+" }, { "orange", "Orange from", "+" },
                         { "green", "Green from", "-" }, { "grey", "Grey from", "-" } }) do
        local which, label, sign = s[1], s[2], s[3]
        local l = ML.LIMITS[which]
        local row = st:Add(W.Row(parent, label), "sub")
        add(row:SetControl(W.Slider(row, l.min, l.max, 1, "",
            function() return ML.Limit(which) end,
            function(v) ML.SetLimit(which, v); applyChange() end,
            nil, { format = function(v) return sign .. v .. " lv" end })))
        mobColorRows[#mobColorRows + 1] = row
    end
    st:Add(W.Note(parent, "Levels above or below yours. Between orange and green the mark is yellow."), "note")
    st:Add(add(W.Checkbox(parent, "Show progress next to the mark",
        "Shows how far the quest is with this kind of mob, e.g. 3/10 slain or 3/10 claws collected.",
        function() return ML.ProgressOn() end,
        function(v) NA.db.mobProgress = v; applyChange() end)), "row")
    st:Add(add(W.Checkbox(parent, "Show progress on quest objects",
        "Quest objects in the world (boulders, crates, plants) can't carry a mark, but while the mouse is over one, its progress (e.g. 7/8) shows next to the pointer.",
        function() return NA.ObjectProgress.IsOn() end,
        function(v) NA.db.objectProgress = v end)), "row")

    -- 2. when you find a mob of a quest that is not in the list
    st:Add(W.Heading(parent, "Quest mob found"), "section")

    st:Add(add(W.Checkbox(parent, "Ignore mobs tapped by others",
        "A mob another player has already tapped (grey name) gives you nothing if you kill it, so it does not show its quest in the list or play the sound. It keeps its mark, and counts again if it becomes free.",
        function() return NA.db.ignoreTapped ~= false end,
        function(v)
            NA.db.ignoreTapped = v
            if NA.QuestMobMarker then NA.QuestMobMarker.RefreshAll() end
        end)), "row")

    local keepRow -- usable only while "Show its quest" is on
    local function updateKeepLook()
        if keepRow then W.SetActive(keepRow, NA.db.mobAddsQuest ~= false) end
    end

    st:Add(add(W.Checkbox(parent, "Show its quest in the list",
        "When a mob that belongs to one of your quests comes into view (within the distance set above), and that quest is not in the list right now, the quest is shown in the list, whatever the filters say.",
        function() return NA.db.mobAddsQuest ~= false end,
        function(v)
            NA.db.mobAddsQuest = v
            updateKeepLook()
            if NA.Tracker then NA.Tracker.RequestRefresh() end
        end)), "row")

    keepRow = st:Add(W.Row(parent, "Keep it for"), "sub")
    add(keepRow:SetControl(W.Slider(keepRow, 10, 120, 10, "",
        function() return math.min(NA.db.keepSeconds or 60, 120) end,
        function(v) NA.db.keepSeconds = v end,
        nil, { majorEvery = 60, format = W.FormatSeconds })))

    local refreshPicker
    st:Add(add(W.Checkbox(parent, "Play a sound",
        "Plays a sound the first time you see a mob of a quest that is not in the list right now.",
        function() return NA.db.soundQuestMob end,
        function(v) NA.db.soundQuestMob = v; refreshPicker() end)), "row")

    refreshPicker = W.SoundPicker(parent, st, {
        choice = "soundChoice", volume = "soundVolume", kit = NA.QuestMobMarker.SOUND_KIT,
        enabled = function() return NA.db.soundQuestMob end,
    })

    return function()
        for _, r in ipairs(refreshers) do r() end
        updateKeepLook()
        refreshPicker()
        refreshMobColors()
    end
end)

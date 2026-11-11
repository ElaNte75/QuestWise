-- Options page "Quest list": list order, filters and the distance limit.
local ADDON, NA = ...

local function filterById(id)
    for _, f in ipairs(NA.Filters.list) do
        if f.id == id then return f end
    end
end

local function changed()
    if NA.Tracker then NA.Tracker.RequestRefresh() end
end

NA.Options.AddPage("quests", "Quest list", function(parent)
    local W = NA.Widgets
    local st = W.Stack(parent)
    local refreshers = {}
    local function add(w) refreshers[#refreshers + 1] = w.Refresh; return w end

    st:Add(W.PageHeader(parent, "Quest list", "How your quest list is sorted and which quests it shows."), "header")

    st:Add(W.Section(parent, "Order"), "section")
    st:Add(add(W.Checkbox(parent, "Nearest quest first",
        "Sorts the quest list so the quest closest to you is on top. Quests ready to turn in always come after the others, the closest turn-in first.",
        function() return NA.db.sortByDistance end,
        function(v) NA.db.sortByDistance = v; changed() end)), "row")
    st:Add(add(W.Checkbox(parent, "Manual focus on top",
        "A quest you focus yourself (on the map, in the quest log or here) is always in the list, on top, whatever the filters say. A quest the automatic focus picks is always in the list too (in its usual place). Class quests stay above it.",
        function() return NA.db.focusedFirst ~= false end,
        function(v) NA.db.focusedFirst = v; changed() end)), "row")

    -- Zone and Distance exclude each other (one or the other, or neither)
    local zone = filterById("zone")
    local dist = filterById("distance")
    local zoneCheck, distCheck, distRow, focusCheck, rangeCheck
    local function refreshScope()
        if zoneCheck then zoneCheck.Refresh() end
        if distCheck then distCheck.Refresh() end
        local autoOn = NA.db.autoFocusNearest ~= false
        if rangeCheck then W.SetActive(rangeCheck, autoOn) end
        if distRow then W.SetActive(distRow, NA.Filters.IsEnabled(dist) or (autoOn and NA.db.autoFocusInRange ~= false)) end
    end

    st:Add(W.Section(parent, "Filters"), "section")
    zoneCheck = st:Add(add(W.Checkbox(parent, "Only quests of this zone",
        "Hides quests that belong to other zones. They stay tracked and come back when you return. Turns the distance filter off.",
        function() return NA.Filters.IsEnabled(zone) end,
        function(v) NA.Filters.SetEnabled(zone, v); refreshScope(); changed() end)), "row")

    distCheck = st:Add(add(W.Checkbox(parent, "Only quests near me",
        "Shows only quests whose spot on the map is within the distance below. For quests ready to turn in, that spot is where you turn them in. Turns the zone filter off. (Quests of mobs you find can be added on the Quest mobs page.)",
        function() return NA.Filters.IsEnabled(dist) end,
        function(v) NA.Filters.SetEnabled(dist, v); refreshScope(); changed() end)), "row")

    distRow = st:Add(W.Row(parent, "Distance"), "sub")
    add(distRow:SetControl(W.Slider(distRow, 100, 3000, 100, " yd",
        function() return NA.db.distanceYards or 500 end,
        function(v) NA.db.distanceYards = v; changed() end,
        nil, { majorEvery = 500 })))

    local dungeon = filterById("dungeon")
    st:Add(add(W.Checkbox(parent, "Hide dungeon quests",
        "Quests the game marks as dungeon or raid quests are hidden while you are outside, and get no focus or arrow by themselves. Inside a dungeon they show (see below). A dungeon quest the game doesn't mark stays in the list.",
        function() return NA.Filters.IsEnabled(dungeon) end,
        function(v) NA.Filters.SetEnabled(dungeon, v); changed() end)), "row")
    st:Add(add(W.Checkbox(parent, "Inside a dungeon, only its quests",
        "Inside a dungeon, raid, battleground or scenario the list shows only its quests (also the ones you don't track), whatever the other filters and buttons say. None found = an empty list. Class quests stay on top. Unticked: inside, the list works with your filters as usual.",
        function() return NA.db.dungeonOnlyInside ~= false end,
        function(v) NA.db.dungeonOnlyInside = v; changed() end)), "row")

    focusCheck = st:Add(add(W.Checkbox(parent, "Focus the nearest quest",
        "The closest quest of your zone gets the focus by itself (yellow circle, map, arrow), whatever filter is on. Only quests still to be done count; when all are ready to turn in, the closest turn-in. A quest you focus yourself stays focused until it is done. Not while flying or in a major city.",
        function() return NA.db.autoFocusNearest ~= false end,
        function(v) NA.db.autoFocusNearest = v; refreshScope(); changed() end)), "row")
    rangeCheck = st:Add(add(W.Checkbox(parent, "Only within the distance",
        "The automatic focus picks only quests within the Distance above (also when the distance filter is off). Nothing that close = no automatic focus until a quest comes within it. Unticked: the closest quest of the zone, however far.",
        function() return NA.db.autoFocusInRange ~= false end,
        function(v) NA.db.autoFocusInRange = v; refreshScope(); changed() end)), "sub")

    -- quest colours by difficulty (UI/QuestColor.lua)
    st:Add(W.Section(parent, "Difficulty colours"), "section")
    local QC = NA.QuestColor
    local customCheck, colorRows = nil, {}
    local function refreshColors()
        local on = QC.IsOn()
        if customCheck then W.SetActive(customCheck, on) end
        for _, r in ipairs(colorRows) do W.SetActive(r, on and QC.CustomOn()) end
    end
    local function colorsChanged()
        refreshColors()
        if NA.Tracker then NA.Tracker.RequestRefresh() end
    end
    st:Add(add(W.Checkbox(parent, "Colour quests by difficulty",
        "Quest titles get the game's colours: red very hard, orange hard, yellow your level, green easy, grey too easy. Quests ready to turn in stay gold.",
        function() return QC.IsOn() end,
        function(v) NA.db.questColors = v; colorsChanged() end)), "row")
    customCheck = st:Add(add(W.Checkbox(parent, "Use my own levels",
        "Ticked: the colours follow the level limits below instead of the game's.",
        function() return QC.CustomOn() end,
        function(v) NA.db.questColorsCustom = v; colorsChanged() end)), "sub")
    local SLIDERS = {
        { "red", "Red from", "+" }, { "orange", "Orange from", "+" },
        { "green", "Green from", "-" }, { "grey", "Grey from", "-" },
    }
    for _, s in ipairs(SLIDERS) do
        local which, label, sign = s[1], s[2], s[3]
        local l = QC.LIMITS[which]
        local row = st:Add(W.Row(parent, label), "sub")
        add(row:SetControl(W.Slider(row, l.min, l.max, 1, "",
            function() return QC.Limit(which) end,
            function(v) QC.SetLimit(which, v); if NA.Tracker then NA.Tracker.RequestRefresh() end end,
            nil, { format = function(v) return sign .. v .. " lv" end })))
        colorRows[#colorRows + 1] = row
    end
    st:Add(W.Note(parent, "Levels above or below yours. Between orange and green the quest is yellow."), "note")

    -- quiet times (Quests/Quiet.lua)
    local function quietChanged()
        if NA.Quiet then NA.SafeCall(NA.Quiet.Check) end
        if NA.QuestMobMarker and NA.QuestMobMarker.RequestRefresh then NA.QuestMobMarker.RequestRefresh() end
        if NA.Arrow then NA.SafeCall(NA.Arrow.Update) end
        changed()
    end
    st:Add(W.Section(parent, "Stay quiet"), "section")
    st:Add(add(W.Checkbox(parent, "Quiet while flying",
        "While you fly with a flight master: no marks on quest mobs, no sounds, no arrow, and the automatic focus stops, and the quest list folds up to its title (you can still open it). When you land, the list opens again as soon as it has quests to show.",
        function() return NA.db.quietFlying ~= false end,
        function(v) NA.db.quietFlying = v; quietChanged() end)), "row")
    st:Add(add(W.Checkbox(parent, "Quiet in major cities",
        "In Stormwind, Ironforge, Darnassus, Orgrimmar, Thunder Bluff and Undercity: no marks on quest mobs, no sounds, no arrow, and the automatic focus stops, and the quest list folds up to its title (you can still open it). When you leave the city, the list opens again as soon as it has quests to show.",
        function() return NA.db.quietCities ~= false end,
        function(v) NA.db.quietCities = v; quietChanged() end)), "row")

    return function()
        NA.Filters.Apply({}) -- tidies saved settings (never both on) before showing them
        for _, r in ipairs(refreshers) do r() end
        refreshScope()
        refreshColors()
    end
end)

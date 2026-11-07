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

    -- Zone and Distance exclude each other (one or the other, or neither)
    local zone = filterById("zone")
    local dist = filterById("distance")
    local zoneCheck, distCheck, distRow, focusCheck
    local function refreshScope()
        if zoneCheck then zoneCheck.Refresh() end
        if distCheck then distCheck.Refresh() end
        if distRow then W.SetActive(distRow, NA.Filters.IsEnabled(dist)) end
        if focusCheck then W.SetActive(focusCheck, NA.Filters.IsEnabled(dist)) end
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

    focusCheck = st:Add(add(W.Checkbox(parent, "Focus the nearest quest",
        "The closest quest in the list gets the focus by itself (yellow circle, shown on the map). Only quests still to be done count; when all are ready to turn in, the closest turn-in. A quest you focus yourself stays focused until it is done or leaves the list.",
        function() return NA.db.autoFocusNearest ~= false end,
        function(v) NA.db.autoFocusNearest = v; changed() end)), "row")

    -- arrow to the focused quest (UI/Arrow.lua)
    local Arrow = NA.Arrow
    local lockCheck, arrowReset
    local function refreshArrow()
        local on = Arrow.IsOn()
        if lockCheck then W.SetActive(lockCheck, on) end
        if arrowReset then W.SetActive(arrowReset, on) end
    end
    st:Add(W.Section(parent, "Arrow"), "section")
    st:Add(add(W.Checkbox(parent, "Show an arrow to the focused quest",
        "An arrow on screen points toward the focused quest (the one you clicked, or the one focused by itself), with the distance and its name. It points at the middle of the quest's area and hides when you get there. Not shown in dungeons.",
        function() return Arrow.IsOn() end,
        function(v) NA.db.arrowEnabled = v; refreshArrow(); Arrow.Update() end)), "row")
    lockCheck = st:Add(add(W.Checkbox(parent, "Lock the arrow in place",
        "Untick it, then drag the arrow to move it. A gold outline shows while it can be moved.",
        function() return Arrow.IsLocked() end,
        function(v) NA.db.arrowLocked = v; Arrow.ApplyLook() end)), "row")
    arrowReset = st:Add(W.Row(parent, "Position"), "row")
    arrowReset:SetControl(W.ControlButton(arrowReset, "Back to default", function() Arrow.ResetPosition() end))

    return function()
        refreshArrow()
        NA.Filters.Apply({}) -- tidies saved settings (never both on) before showing them
        for _, r in ipairs(refreshers) do r() end
        refreshScope()
    end
end)

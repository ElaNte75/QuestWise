-- Options page "Arrow": the on-screen arrow to the focused quest (UI/Arrow.lua).
local ADDON, NA = ...

NA.Options.AddPage("arrow", "Arrow", function(parent)
    local W = NA.Widgets
    local Arrow = NA.Arrow
    local st = W.Stack(parent)
    local refreshers = {}
    local function add(w) refreshers[#refreshers + 1] = w.Refresh; return w end

    st:Add(W.PageHeader(parent, "Arrow", "An arrow on screen that points to the focused quest."), "header")

    local AC = NA.ArrowCombat
    local lockCheck, arrowReset, returnRow, turnInCheck, look, arriveRow, waitRow, areaCheck, areaRow
    local QA = NA.QuestArea
    local combatCheck, combatWaitCheck, combatDelayRow, corpseCheck, corpseRow
    local Corpse = NA.ArrowCorpse
    local function refreshArrow()
        local on = Arrow.IsOn()
        if lockCheck then W.SetActive(lockCheck, on) end
        if returnRow then W.SetActive(returnRow, on) end
        if arriveRow then W.SetActive(arriveRow, on) end
        if waitRow then W.SetActive(waitRow, on) end
        if areaCheck then W.SetActive(areaCheck, on) end
        if areaRow then W.SetActive(areaRow, on and QA.IsOn()) end
        if arrowReset then W.SetActive(arrowReset, on) end
        for _, r in ipairs(look or {}) do W.SetActive(r, on) end
        if turnInCheck then W.SetActive(turnInCheck, on and NA.db.autoFocusNearest ~= false) end
        if combatCheck then W.SetActive(combatCheck, on) end
        if combatWaitCheck then W.SetActive(combatWaitCheck, on and AC.IsOn()) end
        if combatDelayRow then W.SetActive(combatDelayRow, on and AC.IsOn() and AC.WaitOn()) end
        if corpseCheck then W.SetActive(corpseCheck, on) end
        if corpseRow then W.SetActive(corpseRow, on and Corpse.IsOn()) end
    end

    st:Add(add(W.Checkbox(parent, "Enable the arrow",
        "Ticked: an arrow on screen points toward the focused quest (the one you clicked, or the one focused by itself), with the distance and its name. Unticked: no arrow at all, and everything below is unused. Also the arrow button on the list's title.",
        function() return Arrow.IsOn() end,
        function(v) NA.db.arrowEnabled = v; refreshArrow(); Arrow.Update() end)), "row")

    st:Add(W.Section(parent, "Arrow"), "section")
    arriveRow = st:Add(W.Row(parent, "Hide within"), "sub")
    add(arriveRow:SetControl(W.Slider(arriveRow, 10, 150, 5, " yd",
        function() return Arrow.ArriveYards() end,
        function(v) NA.db.arrowArriveYards = v end,
        nil, { majorEvery = 50 })))
    returnRow = st:Add(W.Row(parent, "Show again past"), "sub")
    add(returnRow:SetControl(W.Slider(returnRow, 50, 500, 10, " yd",
        function() return Arrow.ReturnYards() end,
        function(v) NA.db.arrowReturnYards = v end,
        nil, { majorEvery = 100 })))
    waitRow = st:Add(W.Row(parent, "No progress for"), "sub")
    add(waitRow:SetControl(W.Slider(waitRow, 15, 180, 5, " s",
        function() return Arrow.WaitSeconds() end,
        function(v) NA.db.arrowWaitSeconds = v end,
        nil, { majorEvery = 60 })))
    areaCheck = st:Add(add(W.Checkbox(parent, "Use the quest's area on the map",
        "The blue area the map draws around a quest: while you are in it, or close to it, the arrow stays hidden, however far the middle is. It comes back once you are farther from the area than below. Quests without an area use the distances above.",
        function() return QA.IsOn() end,
        function(v) NA.db.arrowUseArea = v; QA.Reset(); refreshArrow(); Arrow.Update() end)), "row")
    areaRow = st:Add(W.Row(parent, "Stay hidden near the area"), "sub")
    add(areaRow:SetControl(W.Slider(areaRow, QA.MIN_YARDS, QA.MAX_YARDS, 10, " yd",
        function() return QA.Yards() end,
        function(v) NA.db.arrowAreaYards = v; QA.Reset() end,
        nil, { majorEvery = 50 })))
    turnInCheck = st:Add(add(W.Checkbox(parent, "Also lead to quests ready to turn in",
        "When the closest quest is focused by itself (Quest list page: Focus the nearest quest), quests ready to turn in count too: the arrow leads to whatever is closest, a quest to do or a quest to hand in. A quest you focus yourself always wins.",
        function() return NA.db.autoFocusTurnIns == true end,
        function(v) NA.db.autoFocusTurnIns = v; if NA.Tracker then NA.Tracker.RequestRefresh() end end)), "row")
    st:Add(W.Note(parent, "Hides near the quest's spot or when the quest moves on (a kill, a loot, the item used). Comes back only far away and with no progress for the time above."), "note")

    st:Add(W.Section(parent, "Combat"), "section")
    combatCheck = st:Add(add(W.Checkbox(parent, "Hide in combat",
        "The arrow hides while you are fighting and comes back when the fight is over.",
        function() return AC.IsOn() end,
        function(v) NA.db.arrowHideCombat = v; refreshArrow(); Arrow.Update() end)), "row")
    combatWaitCheck = st:Add(add(W.Checkbox(parent, "Wait after combat",
        "Ticked: after a fight the arrow comes back only after the time below. Unticked: it comes back right away.",
        function() return AC.WaitOn() end,
        function(v) NA.db.arrowCombatWait = v; refreshArrow(); Arrow.Update() end)), "row")
    combatDelayRow = st:Add(W.Row(parent, "Show again after"), "sub")
    add(combatDelayRow:SetControl(W.Slider(combatDelayRow, AC.MIN_DELAY, AC.MAX_DELAY, 5, " s",
        function() return AC.Delay() end,
        function(v) NA.db.arrowCombatDelay = v end,
        nil, { majorEvery = 30 })))

    st:Add(W.Section(parent, "Corpse run"), "section")
    corpseCheck = st:Add(add(W.Checkbox(parent, "Lead to your corpse",
        "When you die and release, the arrow points to your corpse instead of the quest. Unticked: no arrow at all until you are alive again.",
        function() return Corpse.IsOn() end,
        function(v) NA.db.arrowCorpse = v; refreshArrow(); Arrow.Update() end)), "row")
    corpseRow = st:Add(W.Row(parent, "Hide within"), "sub")
    add(corpseRow:SetControl(W.Slider(corpseRow, Corpse.MIN_YARDS, Corpse.MAX_YARDS, 5, " yd",
        function() return Corpse.HideYards() end,
        function(v) NA.db.arrowCorpseYards = v end,
        nil, { majorEvery = 10 })))

    st:Add(W.Section(parent, "Look"), "section")
    local styleRow = st:Add(W.Row(parent, "Arrow"), "row")
    add(styleRow:SetControl(W.Dropdown(styleRow, Arrow.STYLES,
        function() return NA.db.arrowStyle or "Game" end,
        function(key) NA.db.arrowStyle = key; Arrow.ApplyStyle() end)))
    local colorRow = st:Add(W.Row(parent, "Colour"), "row")
    add(colorRow:SetControl(W.Dropdown(colorRow, Arrow.COLORS,
        function() return NA.db.arrowColor or "Default" end,
        function(key) NA.db.arrowColor = key; Arrow.ApplyStyle() end)))
    local sizeRow = st:Add(W.Row(parent, "Size"), "row")
    add(sizeRow:SetControl(W.Slider(sizeRow, 24, 96, 2, " px",
        function() return Arrow.Size() end,
        function(v) NA.db.arrowSize = v; Arrow.ApplyStyle() end,
        nil, { majorEvery = 24 })))
    look = { styleRow, colorRow, sizeRow }

    st:Add(W.Section(parent, "Position"), "section")
    lockCheck = st:Add(add(W.Checkbox(parent, "Lock the arrow in place",
        "Untick it, then drag the arrow to move it. A gold outline shows while it can be moved.",
        function() return Arrow.IsLocked() end,
        function(v) NA.db.arrowLocked = v; Arrow.ApplyLook() end)), "row")
    arrowReset = st:Add(W.Row(parent, "Position"), "row")
    arrowReset:SetControl(W.ControlButton(arrowReset, "Back to default", function() Arrow.ResetPosition() end))

    return function()
        for _, r in ipairs(refreshers) do r() end
        refreshArrow()
    end
end)

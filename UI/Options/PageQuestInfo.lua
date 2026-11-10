-- Options page "Quest info": the small box on mouse-over (UI/QuestInfo.lua) and the quest details
-- window opened with the "i" button (UI/QuestInfoWindow.lua).
local ADDON, NA = ...

NA.Options.AddPage("questinfo", "Quest info", function(parent)
    local W = NA.Widgets
    local Win = NA.QuestInfoWindow
    local st = W.Stack(parent)
    local refreshers = {}
    local function add(w) refreshers[#refreshers + 1] = w.Refresh; return w end
    local function relist() if NA.Tracker then NA.Tracker.RequestRefresh() end end

    st:Add(W.PageHeader(parent, "Quest info", "What a quest asks of you, in a few words, and what it gives."), "header")

    local deps, hoverCheck, buttonCheck = {}, nil, nil
    local function refreshDeps()
        local all = NA.QuestInfo.Enabled()
        if hoverCheck then W.SetActive(hoverCheck, all) end
        if buttonCheck then W.SetActive(buttonCheck, all) end
        local on = Win.ButtonOn()
        for _, r in ipairs(deps) do W.SetActive(r, on) end
        if deps.opacity then W.SetActive(deps.opacity, on and NA.db.questInfoBackground ~= false) end
    end
    st:Add(add(W.Checkbox(parent, "Enable quest info",
        "Ticked: the summary on mouse-over and the \"i\" button with the details window, as set below. Unticked: none of them, the list works as without this.",
        function() return NA.QuestInfo.Enabled() end,
        function(v)
            NA.db.questInfoEnabled = v
            if not v then Win.Hide() end
            refreshDeps(); relist()
        end)), "row")

    st:Add(W.Section(parent, "Mouse over a quest"), "section")
    hoverCheck = st:Add(add(W.Checkbox(parent, "Show a short summary",
        "With the mouse over a quest in the list, a small box says what to do, how far it is and what each objective needs.",
        function() return NA.db.questInfoHover ~= false end,
        function(v) NA.db.questInfoHover = v end)), "row")

    st:Add(W.Section(parent, "Details window"), "section")
    buttonCheck = st:Add(add(W.Checkbox(parent, "Show the \"i\" button",
        "A small \"i\" button next to each quest in the list. Click it to open a window with what to do, the quest's text and its rewards; click it again (or the X) to close it. The window can be moved by its title.",
        function() return NA.db.questInfoButton ~= false end,
        function(v)
            NA.db.questInfoButton = v
            if not v then Win.Hide() end
            refreshDeps(); relist()
        end)), "row")
    deps[#deps + 1] = st:Add(add(W.Checkbox(parent, "Show the rewards",
        "The window lists the items you get (and the ones to choose from), the money and the experience. Mouse over an item to see it.",
        function() return Win.RewardsOn() end,
        function(v) NA.db.questInfoRewards = v; Win.Refresh() end)), "row")

    local fontRow = st:Add(W.Row(parent, "Text size"), "row")
    add(fontRow:SetControl(W.Slider(fontRow, Win.MIN_FONT, Win.MAX_FONT, 1, " px",
        function() return Win.FontSize() end,
        function(v) NA.db.questInfoFont = v; Win.Refresh() end,
        nil, { majorEvery = 1 })))
    deps[#deps + 1] = fontRow
    local wRow = st:Add(W.Row(parent, "Width"), "row")
    add(wRow:SetControl(W.Slider(wRow, Win.MIN_W, Win.MAX_W, 10, " px",
        function() return Win.Width() end,
        function(v) NA.db.questInfoWidth = v; Win.Refresh() end,
        nil, { majorEvery = 100 })))
    deps[#deps + 1] = wRow
    local hRow = st:Add(W.Row(parent, "Height"), "row")
    add(hRow:SetControl(W.Slider(hRow, Win.MIN_H, Win.MAX_H, 10, " px",
        function() return Win.Height() end,
        function(v) NA.db.questInfoHeight = v; Win.Refresh() end,
        nil, { majorEvery = 100 })))
    deps[#deps + 1] = hRow
    local scaleRow = st:Add(W.Row(parent, "Window scale"), "row")
    add(scaleRow:SetControl(W.Slider(scaleRow, Win.MIN_SCALE, Win.MAX_SCALE, 5, "%",
        function() return Win.Scale() end,
        function(v) NA.db.questInfoScale = v; Win.ApplyLook() end,
        nil, { majorEvery = 30 })))
    deps[#deps + 1] = scaleRow
    local bgCheck = st:Add(add(W.Checkbox(parent, "Show a background",
        "A dark panel with a thin gold edge behind the window. Untick it for text only.",
        function() return NA.db.questInfoBackground ~= false end,
        function(v) NA.db.questInfoBackground = v; refreshDeps(); Win.ApplyLook() end)), "row")
    deps[#deps + 1] = bgCheck
    local opacityRow = st:Add(W.Row(parent, "Opacity"), "sub")
    add(opacityRow:SetControl(W.Slider(opacityRow, 10, 100, 5, "%",
        function() return tonumber(NA.db.questInfoOpacity) or 85 end,
        function(v) NA.db.questInfoOpacity = v; Win.ApplyLook() end,
        nil, { majorEvery = 30 })))
    deps.opacity = opacityRow
    local resetRow = st:Add(W.Row(parent, "Position"), "row")
    resetRow:SetControl(W.ControlButton(resetRow, "Back to default", function() Win.ResetPosition() end))
    deps[#deps + 1] = resetRow
    st:Add(W.Note(parent, "Every quest opens in a window of this size; what doesn't fit scrolls with the mouse wheel. Back to default puts the window next to the quest list. Esc also closes it."), "note")

    return function()
        for _, r in ipairs(refreshers) do r() end
        refreshDeps()
    end
end)

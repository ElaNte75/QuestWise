-- Options page "Interface": where the quest list sits and how it looks.
local ADDON, NA = ...

NA.Options.AddPage("interface", "Interface", function(parent)
    local W = NA.Widgets
    local L = NA.ListLayout
    local st = W.Stack(parent)
    local refreshers = {}
    local function add(w) refreshers[#refreshers + 1] = w.Refresh; return w end

    local function sizeChanged()
        L.UpdatePreview()
        if NA.Tracker then NA.Tracker.RequestRefresh() end
    end

    -- while this page is open, show where the list can reach (width x maximum height)
    parent.PageToggle = function(on) L.ShowPreview(on) end

    st:Add(W.PageHeader(parent, "Interface", "Where the quest list sits and how it looks."), "header")

    -- position
    st:Add(W.Section(parent, "Position"), "section")
    st:Add(add(W.Checkbox(parent, "Lock the list in place",
        "Untick it, then drag the title bar of the quest list to move it. A gold outline shows while it can be moved.",
        function() return L.IsLocked() end,
        function(v) NA.db.listLocked = v; L.ApplyLook() end)), "row")

    local resetRow = st:Add(W.Row(parent, "Position"), "row")
    resetRow:SetControl(W.ControlButton(resetRow, "Back to default", function() L.ResetPosition() end))

    -- size
    st:Add(W.Section(parent, "Size"), "section")
    local widthRow = st:Add(W.Row(parent, "Width"), "row")
    add(widthRow:SetControl(W.Slider(widthRow, L.MIN_WIDTH, L.MAX_WIDTH, 10, " px",
        function() return L.Width() end,
        function(v) NA.db.listWidth = v; sizeChanged() end,
        nil, { majorEvery = 100 })))

    local heightRow = st:Add(W.Row(parent, "Maximum height"), "row")
    add(heightRow:SetControl(W.Slider(heightRow, L.MIN_HEIGHT, L.ScreenMax(), 50, " px",
        function() return L.MaxHeight() end,
        function(v) NA.db.listMaxHeight = v; sizeChanged() end,
        nil, { majorEvery = 250 })))

    st:Add(W.Note(parent, "The list grows with your quests up to this height, then you scroll it with the mouse wheel."), "note")

    -- scale and text
    st:Add(W.Section(parent, "Scale and text"), "section")
    local scaleRow = st:Add(W.Row(parent, "List scale"), "row")
    add(scaleRow:SetControl(W.Slider(scaleRow, L.MIN_SCALE, L.MAX_SCALE, 5, "%",
        function() return NA.db.listScale or 100 end,
        function(v) NA.db.listScale = v; L.ApplyScale(); sizeChanged() end,
        nil, { majorEvery = 30 })))

    local fontRow = st:Add(W.Row(parent, "Text size"), "row")
    add(fontRow:SetControl(W.Slider(fontRow, L.MIN_FONT, L.MAX_FONT, 1, " px",
        function() return L.FontSize() end,
        function(v) NA.db.listFontSize = v; sizeChanged() end,
        nil, { majorEvery = 1 })))

    local windowRow = st:Add(W.Row(parent, "Window scale"), "row")
    add(windowRow:SetControl(W.Slider(windowRow, 70, 130, 5, "%",
        function() return NA.db.optionsScale or 100 end,
        function(v) NA.db.optionsScale = v end,
        function() NA.Options.ApplyScale() end, -- applied when you let go, so the window doesn't jump under the mouse
        { majorEvery = 30 })))
    st:Add(W.Note(parent, "List scale and text size change the quest list. Window scale changes this options window when you let go of the slider."), "note")

    -- background
    st:Add(W.Section(parent, "Background"), "section")
    local opacityRow
    st:Add(add(W.Checkbox(parent, "Show a background",
        "Draws a dark panel behind the quest list so it is easier to read.",
        function() return NA.db.listBackground and true or false end,
        function(v)
            NA.db.listBackground = v
            if opacityRow then W.SetActive(opacityRow, v) end
            L.ApplyLook()
        end)), "row")

    opacityRow = st:Add(W.Row(parent, "Opacity"), "sub") -- indented label, control still on the grid
    add(opacityRow:SetControl(W.Slider(opacityRow, 10, 100, 10, "%",
        function() return NA.db.listOpacity or 60 end,
        function(v) NA.db.listOpacity = v; L.ApplyLook() end)))

    return function()
        for _, r in ipairs(refreshers) do r() end
        W.SetActive(opacityRow, NA.db.listBackground and true or false)
    end
end)

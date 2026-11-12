-- Options page "Map": the focused quest's area on the world map in our own colour (UI/MapArea.lua).
local ADDON, NA = ...

NA.Options.AddPage("map", "Map", function(parent)
    local W = NA.Widgets
    local MA = NA.MapArea
    local st = W.Stack(parent)
    local refreshers = {}
    local function add(w) refreshers[#refreshers + 1] = w.Refresh; return w end

    st:Add(W.PageHeader(parent, "Map", "How the focused quest looks on the world map and the minimap."), "header")

    local deps = {}
    local function refreshDeps()
        for _, r in ipairs(deps) do W.SetActive(r, MA.IsOn()) end
    end
    st:Add(add(W.Checkbox(parent, "Enable map colours",
        "Ticked: on the world map, the quest's area is drawn the way you set below. Unticked: the map is left exactly as the game draws it.",
        function() return MA.IsOn() end,
        function(v)
            NA.db.mapArea = v; refreshDeps(); MA.Apply()
            if NA.MinimapArea then NA.MinimapArea.Update(true) end
        end)), "row")

    st:Add(W.Section(parent, "Quest area"), "section")
    local colorRow = st:Add(W.Row(parent, "Colour"), "row")
    add(colorRow:SetControl(W.Dropdown(colorRow, MA.COLORS,
        function() return MA.Color() end,
        function(key) NA.db.mapAreaColor = key; MA.Apply() end)))
    deps[#deps + 1] = colorRow
    local opRow = st:Add(W.Row(parent, "Opacity"), "row")
    add(opRow:SetControl(W.Slider(opRow, MA.MIN_OPACITY, MA.MAX_OPACITY, 5, "%",
        function() return MA.Opacity() end,
        function(v) NA.db.mapAreaOpacity = v; MA.Apply() end,
        nil, { majorEvery = 30 })))
    deps[#deps + 1] = opRow
    deps[#deps + 1] = st:Add(add(W.Checkbox(parent, "Outline only",
        "Nothing inside the area: only a line around it, as if drawn with a pen, to show roughly where the quest is.",
        function() return MA.OutlineOnly() end,
        function(v) NA.db.mapAreaOutline = v; MA.Apply() end)), "row")
    local thickRow = st:Add(W.Row(parent, "Outline thickness"), "row")
    add(thickRow:SetControl(W.Slider(thickRow, MA.MIN_THICK, MA.MAX_THICK, 1, "",
        function() return MA.Thickness() end,
        function(v) NA.db.mapAreaThickness = v; MA.Apply() end,
        nil, { majorEvery = 1 })))
    deps[#deps + 1] = thickRow
    st:Add(W.Note(parent, "Changes show at once. The colours are pictures the game already has (it takes no others)."), "note")

    st:Add(W.Section(parent, "Other areas"), "section")
    deps[#deps + 1] = st:Add(add(W.Checkbox(parent, "Hide the other quests' areas (world map only)",
        "On the big world map, only the focused quest's area is drawn (all its parts, when it has 2-3), so the other quests' areas don't get in the way. Not on the minimap: see the note below.",
        function() return MA.HideOthers() end,
        function(v) NA.db.mapHideOthers = v; MA.Apply() end)), "row")
    deps[#deps + 1] = st:Add(add(W.Checkbox(parent, "Colour the minimap areas too",
        "The inside of the quest areas on the minimap takes the same colour. Their light-blue edge stays the game's: the game doesn't let us change it.",
        function() return NA.db.mapMinimap ~= false end,
        function(v) NA.db.mapMinimap = v; if NA.MinimapArea then NA.MinimapArea.Update(true) end end)), "row")
    st:Add(W.Note(parent, "Minimap: it always shows the areas of ALL your tracked quests, also with a quest focused. The game doesn't let an add-on hide some of them there, or tell which one is focused."), "note")

    return function()
        for _, r in ipairs(refreshers) do r() end
        refreshDeps()
    end
end)

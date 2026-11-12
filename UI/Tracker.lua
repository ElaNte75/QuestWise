-- UI: the main tracker frame ("All Objectives" + Quests section) and its refresh loop.
local ADDON, NA = ...

local Tracker = { ready = false }
NA.Tracker = Tracker

local WIDTH = 260
local HEADER_H = 32
local SECTION_Y = -HEADER_H - 6

local QUEST_EVENTS = {
    "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "UNIT_QUEST_LOG_CHANGED",
    "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_POI_UPDATE",
    "SUPER_TRACKING_CHANGED", "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "BAG_UPDATE", "BAG_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED",
    "PLAYER_LEVEL_UP", -- quest colours by difficulty (UI/QuestColor.lua)
}

local pending = false

function Tracker.IsActive()
    return Tracker.ready
end

-- Is this quest currently shown in our list?
function Tracker.IsVisible(title)
    return Tracker.visibleTitles ~= nil and Tracker.visibleTitles[title] == true
end

function Tracker.Refresh()
    pending = false
    if not Tracker.ready then return end
    -- quest item buttons are secure: the game won't let us change them in combat,
    -- so while one is on screen the list waits until combat ends
    if InCombatLockdown() and Tracker.itemsShown then
        Tracker.deferred = true
        return
    end
    Tracker.deferred = false
    Tracker.refreshCount = (Tracker.refreshCount or 0) + 1

    local all = NA.QuestSource.GetTracked()
    Tracker.allQuests = all
    Tracker.totalCount = #all
    NA.SafeCall(NA.CompleteSound.Check, all)
    local f = Tracker.frame
    local visible = NA.Filters.Apply(all)
    -- (inside a dungeon / battleground the list shows, even empty: Data/DungeonFilter.lua)
    if #all == 0 and not NA.Filters.narrowed then
        f:Hide()
        return
    end
    f:Show()

    visible = NA.DistanceSort.Apply(visible)
    NA.SafeCall(NA.AutoFocus.Update, all) -- closest quest of this zone gets the focus (Quests/AutoFocus.lua)
    -- a quest you focused yourself: always shown, on top (Quests/FocusFirst.lua)
    -- (not inside a dungeon that shows only its own quests: then nothing else joins the list)
    if not NA.Filters.narrowed then
        local okFF, ordered = NA.SafeCall(NA.FocusFirst.Apply, visible, all)
        if okFF and ordered then visible = ordered end
    end
    -- class quests: always shown, above everything (Quests/ClassQuests.lua)
    local okCQ, withClass = NA.SafeCall(NA.ClassQuests.Apply, visible, all)
    if okCQ and withClass then visible = withClass end
    Tracker.questCount = #visible
    -- after a flight / leaving a city the list opens once it has something to show (Quests/Quiet.lua)
    if NA.Quiet then NA.Quiet.AfterQuiet(#visible) end
    Tracker.visibleTitles = {}
    for _, q in ipairs(visible) do Tracker.visibleTitles[q.title] = true end

    -- size: width from the options; height = what the quests need, but never more than the
    -- maximum height (then the list scrolls with the mouse wheel)
    local L = NA.ListLayout
    L.ApplyScale() -- (a scale change made during combat is applied here once it is over)
    local w = L.Width()
    f:SetWidth(w)
    Tracker.header:SetWidthTo(w)
    Tracker.header:SetFontSize(L.FontSize() + 2)
    Tracker.header:SetCollapsed(NA.db.collapsedAll)
    L.ApplyLook() -- the quests' background panel hides while the list is folded
    if NA.db.collapsedAll then
        Tracker.scroll:Hide()
        f:SetHeight(HEADER_H)
    else
        Tracker.scroll:Show()
        local h = Tracker.section:Refresh(visible, NA.Filters.narrowed and "No quests here" or "No quests in this zone", w)
        local viewH = math.min(h, math.max(L.MaxHeight() - HEADER_H - 6, 60))
        local fullW = w + L.PAD_LEFT + L.PAD_RIGHT
        Tracker.content:SetSize(fullW, h)
        Tracker.scroll:SetSize(fullW, viewH)
        local maxScroll = math.max(h - viewH, 0)
        if (Tracker.scroll:GetVerticalScroll() or 0) > maxScroll then Tracker.scroll:SetVerticalScroll(maxScroll) end
        f:SetHeight(HEADER_H + 6 + viewH)
    end
    Tracker.itemsShown = Tracker.section:HasItemButtons()
    -- if something had to wait for combat to end, PLAYER_REGEN_ENABLED refreshes again
end

-- Several game events fire in a burst; refresh once on the next frame.
function Tracker.RequestRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        local ok, err = NA.SafeCall(Tracker.Refresh)
        if not ok then NA.LogError(err) end
    end)
end

NA.OnInit(function()
    local f = CreateFrame("Frame", "QuestSiftTrackerFrame", UIParent)
    f:SetSize(WIDTH, 100)
    f:SetFrameStrata("MEDIUM")
    Tracker.frame = f

    local header = NA.Header.Create(f, {
        width = WIDTH, height = HEADER_H, label = "QuestSift",
        bg = "UI-QuestTracker-Primary-Objective-Header", bgW = 300, bgH = 40,
        collapse = "UI-QuestTrackerButton-Collapse-All",
        expand = "UI-QuestTrackerButton-Expand-All",
        highlight = "UI-QuestTrackerButton-Red-Highlight",
        iconW = 18, iconH = 19, iconX = -1,
        reserve = 52 + 4 * 20, -- gear + collapse, and the 4 quick buttons (UI/HeaderToggles.lua)
    })
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetScript("OnClick", function()
        NA.db.collapsedAll = not NA.db.collapsedAll
        if NA.Quiet then NA.Quiet.ListToggledByHand() end
        Tracker.RequestRefresh()
    end)
    Tracker.header = header

    Tracker.optionsButton = NA.OptionsButton.Attach(header, -24)

    -- the quests live in a scroll frame under the title, so a long list can scroll (mouse wheel)
    local L = NA.ListLayout
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", -L.PAD_LEFT, SECTION_Y)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max((Tracker.content:GetHeight() or 0) - (self:GetHeight() or 0), 0)
        local v = math.min(math.max((self:GetVerticalScroll() or 0) - delta * 40, 0), maxScroll)
        self:SetVerticalScroll(v)
    end)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH + L.PAD_LEFT + L.PAD_RIGHT, 10)
    scroll:SetScrollChild(content)
    Tracker.scroll, Tracker.content = scroll, content

    Tracker.section = NA.QuestSection.New(content, Tracker.RequestRefresh)
    Tracker.section.frame:SetPoint("TOPLEFT", content, "TOPLEFT", L.PAD_LEFT, 0)

    L.Setup(f, header) -- position, background, moving

    local ev = CreateFrame("Frame")
    for _, name in ipairs(QUEST_EVENTS) do pcall(ev.RegisterEvent, ev, name) end
    ev:SetScript("OnEvent", Tracker.RequestRefresh)

    Tracker.ready = true
    Tracker.RequestRefresh()
    -- re-sort by distance as you move
    C_Timer.NewTicker(5, Tracker.RequestRefresh)
    -- quest data can arrive a little after login
    C_Timer.After(2, Tracker.RequestRefresh)
end)

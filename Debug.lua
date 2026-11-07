-- TEMPORARY debug log (remove once v1 is confirmed). Silent: writes to
-- QuestWiseProbeDB.debug, which WoW saves on /reload or logout.
local ADDON, NA = ...

QuestWiseProbeDB = QuestWiseProbeDB or {}

local ATLASES = {
    "UI-QuestTracker-Primary-Objective-Header", "UI-QuestTracker-Secondary-Objective-Header",
    "UI-QuestTrackerButton-Collapse-All", "UI-QuestTrackerButton-Expand-All",
    "UI-QuestTrackerButton-Secondary-Collapse", "UI-QuestTrackerButton-Secondary-Expand",
    "UI-QuestTrackerButton-Red-Highlight", "UI-QuestTrackerButton-Yellow-Highlight",
    "UI-QuestPoi-QuestNumber", "Quest-In-Progress-Icon-yellow", "UI-QuestIcon-TurnIn-Normal",
    "UI-QuestTracker-Tracker-Check",
}

local function snapshot(tag)
    local d = { tag = tag, time = date("%Y-%m-%d %H:%M:%S"), lines = {} }
    local function add(s) d.lines[#d.lines + 1] = s end

    local T = NA.Tracker
    add("tracker ready=" .. tostring(T and T.ready) .. " refreshes=" .. tostring(T and T.refreshCount) .. " quests=" .. tostring(T and T.questCount))
    if T and T.frame then
        local p, rel, rp, x, y = T.frame:GetPoint(1)
        add(string.format("frame shown=%s size=%.1fx%.1f point=%s>%s:%s(%s,%s) scale=%.2f",
            tostring(T.frame:IsShown()), T.frame:GetWidth(), T.frame:GetHeight(), tostring(p),
            tostring(rel and rel.GetName and rel:GetName()), tostring(rp), tostring(x), tostring(y), T.frame:GetEffectiveScale()))
    end
    add("blizzard ObjectiveTrackerFrame shown=" .. tostring(ObjectiveTrackerFrame and ObjectiveTrackerFrame:IsShown()))

    local missing = {}
    for _, a in ipairs(ATLASES) do
        if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(a) then missing[#missing + 1] = a end
    end
    add("missing atlases: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))

    if T and T.section then
        for i, b in ipairs(T.section.blocks) do
            if b.frame:IsShown() then
                add(string.format("block%d h=%.1f titleH=%.1f lines=%d text=%q", i, b.height or -1, b.title:GetStringHeight(), b.quest and #b.quest.lines or -1, b.title:GetText() or ""))
            end
        end
    end
    add("GetQuestLogSpecialItemInfo=" .. type(GetQuestLogSpecialItemInfo) .. " sortByDistance=" .. tostring(NA.db and NA.db.sortByDistance))
    if T and T.allQuests then
        for _, q in ipairs(T.allQuests) do
            if q.item then add("quest item: " .. q.title .. " -> " .. tostring(q.item.link) .. " id=" .. tostring(q.item.itemID)) end
        end
    end
    d.errors = {}
    for i, e in ipairs(NA.errors) do d.errors[i] = e end
    QuestWiseProbeDB.debug = d
end

NA.OnInit(function()
    C_Timer.After(6, function() NA.SafeCall(snapshot, "t+6s") end)
    C_Timer.After(20, function() NA.SafeCall(snapshot, "t+20s") end)
end)

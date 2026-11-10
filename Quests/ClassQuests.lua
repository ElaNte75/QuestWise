-- Quests: class quests (the ones the quest log files under your class name, e.g. "Shaman").
--   * tracked by themselves once, when they come into the quest log (if you untrack one
--     afterwards, it is left alone)
--   * always in the list, whatever the filters say, and on top
--   * marked "Important" next to the title (UI/QuestBlock.lua)
-- They get no arrow by themselves: the automatic focus works as before.
local ADDON, NA = ...

local CQ = {}
NA.ClassQuests = CQ

local function className()
    if type(UnitClass) ~= "function" then return nil end
    local ok, name = pcall(UnitClass, "player")
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- "ffRRGGBB" of your class colour (gold if the game doesn't say)
function CQ.ClassColorHex()
    if type(UnitClass) == "function" and type(RAID_CLASS_COLORS) == "table" then
        local ok, _, file = pcall(UnitClass, "player")
        local c = ok and file and RAID_CLASS_COLORS[file]
        if c and c.r then
            return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
        end
    end
    return "ffffd100"
end

function CQ.IsClassQuest(q)
    local name = className()
    return q ~= nil and name ~= nil and q.zone == name
end

-- quest log: questID -> logIndex for every quest under your class header
local function classQuestsInLog()
    local found = {}
    local name = className()
    local QL = C_QuestLog
    if not (name and QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return found end
    local header
    for i = 1, QL.GetNumQuestLogEntries() or 0 do
        local info = QL.GetInfo(i)
        if info then
            if info.isHeader then header = info.title
            elseif info.questID and header == name then found[info.questID] = i end
        end
    end
    return found
end

local function isWatched(questID)
    local QL = C_QuestLog
    if QL.GetQuestWatchType then
        local ok, w = pcall(QL.GetQuestWatchType, questID)
        if ok and w ~= nil then return true end
    end
    if QL.GetNumQuestWatches and QL.GetQuestIDForQuestWatchIndex then
        for i = 1, QL.GetNumQuestWatches() or 0 do
            if QL.GetQuestIDForQuestWatchIndex(i) == questID then return true end
        end
    end
    return false
end

local function watch(questID, logIndex)
    if C_QuestLog.AddQuestWatch then
        local ok = pcall(C_QuestLog.AddQuestWatch, questID)
        if ok then return end
    end
    if type(AddQuestWatch) == "function" and logIndex then pcall(AddQuestWatch, logIndex) end
end

-- track every class quest we haven't tracked before
function CQ.Check()
    NA.db.classTracked = NA.db.classTracked or {}
    local done = NA.db.classTracked
    local inLog = classQuestsInLog()
    local added = false
    for questID, logIndex in pairs(inLog) do
        if not done[questID] then
            if not isWatched(questID) then watch(questID, logIndex); added = true end
            done[questID] = true
        end
    end
    -- (questIDs are kept: there are only a few class quests, and forgetting one while the quest
    -- log is still loading would track again a quest you untracked yourself)
    if added and NA.Tracker then NA.Tracker.RequestRefresh() end
end

-- visible: the list after filters, sorting and FocusFirst; all: every tracked quest.
-- Class quests go on top (in the order they had), even when a filter hid them.
function CQ.Apply(visible, all)
    local top, seen = {}, {}
    for _, q in ipairs(visible) do
        if CQ.IsClassQuest(q) then top[#top + 1] = q; seen[q.questID] = true end
    end
    for _, q in ipairs(all) do
        if not seen[q.questID] and CQ.IsClassQuest(q) then top[#top + 1] = q; seen[q.questID] = true end
    end
    if #top == 0 then return visible end
    for _, q in ipairs(visible) do
        if not seen[q.questID] then top[#top + 1] = q end
    end
    return top
end

NA.OnInit(function()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED", "QUEST_LOG_UPDATE" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function() NA.SafeCall(CQ.Check) end)
    CQ.events = ev
    C_Timer.After(2, function() NA.SafeCall(CQ.Check) end) -- quest log can arrive a little after login
end)

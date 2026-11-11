-- Data: reads the tracked quests from the game and returns plain tables.
-- Result per quest: { questID, title, level, isComplete, lines = { {text, finished, plain} ... } }
local ADDON, NA = ...

local Source = {}
NA.QuestSource = Source

local READY_TEXT = "Ready for turn-in"

-- the focused quest counts too even when it isn't tracked (you focused it on the map / in the log):
-- Quests/FocusFirst.lua shows a quest you focused yourself on top of the list, whatever else
local function withFocused(ids, seen)
    local QL = C_QuestLog
    if not (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID) then return ids end
    local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    if ok and id and id ~= 0 and not seen[id] and QL.GetLogIndexForQuestID then
        local i = QL.GetLogIndexForQuestID(id)
        if i and i > 0 then ids[#ids + 1] = id end
    end
    return ids
end

local function trackedIDs()
    local ids = {}
    local seen = {}
    local QL = C_QuestLog
    if QL.GetNumQuestWatches and QL.GetQuestIDForQuestWatchIndex then
        for i = 1, QL.GetNumQuestWatches() or 0 do
            local id = QL.GetQuestIDForQuestWatchIndex(i)
            if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
        end
        if #ids > 0 then return withFocused(ids, seen) end
    end
    -- Fallback: walk the quest log and keep watched quests.
    for i = 1, QL.GetNumQuestLogEntries() or 0 do
        local info = QL.GetInfo(i)
        if info and not info.isHeader and info.questID and QL.GetQuestWatchType and QL.GetQuestWatchType(info.questID) then
            ids[#ids + 1] = info.questID
            seen[info.questID] = true
        end
    end
    return withFocused(ids, seen)
end

local function objectiveLines(questID)
    local lines = {}
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
    if ok and type(objs) == "table" then
        for _, o in ipairs(objs) do
            if o.text and o.text ~= "" then
                lines[#lines + 1] = { text = o.text, finished = o.finished and true or false }
            end
        end
    end
    return lines
end

local function completionText(logIndex)
    if logIndex and type(GetQuestLogCompletionText) == "function" then
        local ok, text = pcall(GetQuestLogCompletionText, logIndex)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    return nil
end

local function objectiveDescription(logIndex)
    if logIndex and type(GetQuestLogQuestText) == "function" then
        local ok, _, objectives = pcall(GetQuestLogQuestText, logIndex)
        if ok and type(objectives) == "string" and objectives ~= "" then return objectives end
    end
    return nil
end

-- The usable item a quest gave you (shown as a button next to the quest), or nil.
local function specialItem(logIndex, complete)
    if not logIndex or type(GetQuestLogSpecialItemInfo) ~= "function" then return nil end
    local ok, link, icon, charges, showWhenComplete = pcall(GetQuestLogSpecialItemInfo, logIndex)
    if not ok or not link then return nil end
    if complete and not showWhenComplete then return nil end
    local itemID = tonumber(tostring(link):match("item:(%d+)"))
    return { link = link, icon = icon, charges = charges, itemID = itemID }
end

-- questID -> name of the zone header it sits under in the quest log
local function zonesByQuest()
    local map = {}
    local header
    local QL = C_QuestLog
    for i = 1, QL.GetNumQuestLogEntries() or 0 do
        local info = QL.GetInfo(i)
        if info then
            if info.isHeader then header = info.title
            elseif info.questID then map[info.questID] = header end
        end
    end
    return map
end

local function build(questID, logIndex, info, zone)
    local QL = C_QuestLog
    local title = (info and info.title) or (QL.GetTitleForQuestID and QL.GetTitleForQuestID(questID))
    if not title then return nil end
    local complete = QL.IsComplete and QL.IsComplete(questID) and true or false
    local q = {
        questID = questID,
        title = title,
        level = info and info.level,
        zone = zone,
        isComplete = complete,
        item = specialItem(logIndex, complete),
        lines = {},
    }
    if complete then
        local text = completionText(logIndex)
        q.lines[1] = { text = text or READY_TEXT, finished = false, plain = true, dim = (text == nil) }
    else
        q.lines = objectiveLines(questID)
        if #q.lines == 0 then
            local desc = objectiveDescription(logIndex)
            if desc then q.lines[1] = { text = desc, finished = false, plain = true } end
        end
    end
    return q
end

function Source.GetTracked()
    local result = {}
    local QL = C_QuestLog
    local zones = zonesByQuest()
    for _, questID in ipairs(trackedIDs()) do
        local logIndex = QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(questID)
        local info = logIndex and QL.GetInfo(logIndex)
        local q = build(questID, logIndex, info, zones[questID])
        if q then result[#result + 1] = q end
    end
    return result
end

-- every quest in the quest log (tracked or not) whose header passes match(headerName)
-- (Data/DungeonFilter.lua: all the quests of the dungeon / battleground you are in)
function Source.GetInLog(match)
    local result = {}
    local QL = C_QuestLog
    local header
    for i = 1, QL.GetNumQuestLogEntries() or 0 do
        local info = QL.GetInfo(i)
        if info then
            if info.isHeader then header = info.title
            elseif info.questID and header and match(header) then
                local q = build(info.questID, i, info, header)
                if q then result[#result + 1] = q end
            end
        end
    end
    return result
end

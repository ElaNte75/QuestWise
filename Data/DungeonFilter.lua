-- Filter "Dungeon":
--  * outside an instance: hides quests the game marks as dungeon (or raid) quests. Such quests
--    also get no automatic focus (Quests/AutoFocus.lua). A dungeon quest the game doesn't mark stays shown.
--  * inside a dungeon / raid: the list shows only the quests filed under that dungeon's name in the
--    quest log, whatever the other filters (and this one) say - setting dungeonOnlyInside (on; user
--    decision: this switch was tied to the skull button, which was off - user report). Off = inside,
--    the list works with your filters as usual. If none is found, the list works as usual too.
local ADDON, NA = ...

local DUNGEON_TAGS = { [81] = true, [62] = true, [88] = true, [89] = true } -- Dungeon, Raid, Raid (10), Raid (25)

local Dungeon = { id = "dungeon", label = "Dungeon", default = true }
NA.DungeonFilter = Dungeon

local function inInstance()
    if type(IsInInstance) ~= "function" then return false end
    local ok, inside, kind = pcall(IsInInstance)
    return ok and inside and (kind == "party" or kind == "raid") or false
end

-- names the current instance may go by (instance name and zone name)
local function instanceNames()
    local names = {}
    if type(GetInstanceInfo) == "function" then
        local ok, name = pcall(GetInstanceInfo)
        if ok and type(name) == "string" and name ~= "" then names[name] = true end
    end
    if type(GetRealZoneText) == "function" then
        local ok, name = pcall(GetRealZoneText)
        if ok and type(name) == "string" and name ~= "" then names[name] = true end
    end
    return names
end

function Dungeon.IsDungeonQuest(questID)
    if not (questID and C_QuestLog.GetQuestTagInfo) then return false end
    local ok, tag = pcall(C_QuestLog.GetQuestTagInfo, questID)
    return ok and type(tag) == "table" and DUNGEON_TAGS[tag.tagID] == true or false
end

-- true = the filter is on and this quest must be hidden right now
function Dungeon.Hides(questID)
    return NA.Filters.IsEnabled(Dungeon) and not inInstance() and Dungeon.IsDungeonQuest(questID)
end

-- inside a dungeon: only the quests of this dungeon (nil when outside or none found)
function Dungeon.OnlyInside() return NA.db.dungeonOnlyInside ~= false end

function Dungeon.Narrow(quests)
    if not (Dungeon.OnlyInside() and inInstance()) then return nil end
    local names = instanceNames()
    local only = {}
    for _, q in ipairs(quests) do
        if q.zone and names[q.zone] then only[#only + 1] = q end
    end
    if #only == 0 then return nil end
    return only
end

function Dungeon.Prepare()
    return { inside = inInstance() }
end

function Dungeon.Test(q, ctx)
    if ctx.inside then return true end
    return not Dungeon.IsDungeonQuest(q.questID)
end

NA.Filters.Register(Dungeon)

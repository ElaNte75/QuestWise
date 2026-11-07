-- TEMPORARY PROBE (to be removed once the design is confirmed).
-- Silent: never prints to chat. Writes snapshots to QuestWiseProbeDB,
-- which WoW saves to disk on /reload or logout.
QuestWiseProbeDB = QuestWiseProbeDB or {}

local MAX_SNAPSHOTS = 10

local function has(tbl, name) return type(tbl) == "table" and type(tbl[name]) == "function" end

local function snapshot(reason)
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    add("reason=" .. tostring(reason))
    local apis = {
        {"C_QuestLog", "GetNumQuestLogEntries"}, {"C_QuestLog", "GetInfo"},
        {"C_QuestLog", "IsComplete"}, {"C_QuestLog", "GetQuestsOnMap"},
        {"C_QuestLog", "GetQuestWatchType"}, {"C_QuestLog", "AddQuestWatch"},
        {"C_QuestLog", "RemoveQuestWatch"}, {"C_QuestLog", "GetNumQuestWatches"},
        {"C_QuestLog", "GetQuestObjectives"}, {"C_QuestLog", "GetNextWaypoint"},
        {"C_Map", "GetBestMapForUnit"}, {"C_Map", "GetMapInfo"},
    }
    local missing = {}
    for _, a in ipairs(apis) do
        if not has(_G[a[1]], a[2]) then missing[#missing + 1] = a[1] .. "." .. a[2] end
    end
    add("missingAPIs=" .. (#missing > 0 and table.concat(missing, ",") or "none"))
    add("frames: QuestWatchFrame=" .. tostring(QuestWatchFrame ~= nil)
        .. " ObjectiveTrackerFrame=" .. tostring(ObjectiveTrackerFrame ~= nil))

    local mapID = has(C_Map, "GetBestMapForUnit") and C_Map.GetBestMapForUnit("player")
    local mapInfo = mapID and has(C_Map, "GetMapInfo") and C_Map.GetMapInfo(mapID)
    add(string.format("player: mapID=%s mapName=%s zone=%s subzone=%s",
        tostring(mapID), tostring(mapInfo and mapInfo.name), tostring(GetZoneText()), tostring(GetSubZoneText())))

    local onMap = {}
    if mapID and has(C_QuestLog, "GetQuestsOnMap") then
        local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(list) == "table" then
            for _, q in ipairs(list) do onMap[q.questID] = true end
            add("questsOnThisMap=" .. #list)
        else
            add("GetQuestsOnMap ERROR: " .. tostring(list))
        end
    end

    if has(C_QuestLog, "GetNumQuestLogEntries") and has(C_QuestLog, "GetInfo") then
        local header = "?"
        local n = C_QuestLog.GetNumQuestLogEntries() or 0
        add("logEntries=" .. n)
        for i = 1, n do
            local info = C_QuestLog.GetInfo(i)
            if info then
                if info.isHeader then
                    header = info.title
                else
                    local id = info.questID
                    local complete = has(C_QuestLog, "IsComplete") and C_QuestLog.IsComplete(id)
                    local watch = has(C_QuestLog, "GetQuestWatchType") and C_QuestLog.GetQuestWatchType(id)
                    add(string.format("quest id=%s title=%s | header=%s | complete=%s | watch=%s | onThisMap=%s",
                        tostring(id), tostring(info.title), tostring(header), tostring(complete),
                        tostring(watch), tostring(onMap[id] == true)))
                end
            end
        end
    end

    local db = QuestWiseProbeDB
    db.snapshots = db.snapshots or {}
    table.insert(db.snapshots, { time = date("%Y-%m-%d %H:%M:%S"), lines = lines })
    while #db.snapshots > MAX_SNAPSHOTS do table.remove(db.snapshots, 1) end
end

local function safeSnapshot(reason)
    local ok, err = pcall(snapshot, reason)
    if not ok then
        QuestWiseProbeDB.errors = QuestWiseProbeDB.errors or {}
        table.insert(QuestWiseProbeDB.errors, date("%H:%M:%S") .. " " .. tostring(err))
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", function(_, event)
    -- quest data loads a bit after entering the world, so wait a few seconds
    C_Timer.After(5, function() safeSnapshot(event) end)
end)

-- Filter "Zone": show only quests relevant to the zone you are in.
--  * not finished -> shown where it is done (map shows its objectives, or same zone as in the quest log)
--  * ready to turn in -> shown only where it is turned in (map shows its turn-in)
-- If the game gives no map data, everything is shown (never hide by mistake).
local ADDON, NA = ...

local Zone = { id = "zone", label = "Zone", default = true, group = "scope" } -- "scope": only one of Zone / Dist at a time

function Zone.Prepare()
    return NA.MapInfo.Get()
end

function Zone.Test(q, ctx)
    if not ctx.ok then return true end
    if ctx.onMap[q.questID] then return true end
    if not q.isComplete and q.zone and ctx.zoneName and q.zone == ctx.zoneName then return true end
    return false
end

-- TEMPORARY debug: remember what was decided each time the zone changes.
local lastKey
function Zone.Report(quests, ctx, passed)
    local key = tostring(ctx.mapID) .. "/" .. #quests
    if key == lastKey then return end
    lastKey = key
    local db = QuestWiseProbeDB
    if not db then return end
    db.zoneLog = db.zoneLog or {}
    local entry = { time = date("%H:%M:%S"), mapID = ctx.mapID, zoneID = ctx.zoneID, zoneName = ctx.zoneName, ok = ctx.ok, quests = {} }
    for _, q in ipairs(quests) do
        entry.quests[#entry.quests + 1] = string.format("%s | header=%s complete=%s onMap=%s -> %s",
            q.title, tostring(q.zone), tostring(q.isComplete), tostring(ctx.onMap[q.questID] == true), passed[q.questID] and "SHOW" or "hide")
    end
    table.insert(db.zoneLog, entry)
    while #db.zoneLog > 10 do table.remove(db.zoneLog, 1) end
end

NA.Filters.Register(Zone)

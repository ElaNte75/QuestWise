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

NA.Filters.Register(Zone)

-- Data: orders the quest list in two groups:
--   1. quests still to be done   2. quests ready to turn in (always below the first group)
-- With "Nearest quest first" on, each group is sorted closest first (for ready quests: closest
-- turn-in). Distances are rounded in 25-yard steps so the list doesn't jitter while you walk.
-- A quest whose mob you can see right now counts as "here" (distance 0).
local ADDON, NA = ...

local Sort = {}
NA.DistanceSort = Sort

local STEP = 25
local FAR = 1e9

function Sort.Apply(quests)
    if #quests < 2 then return quests end
    local ctx = NA.MapInfo.Get()
    local byDistance = NA.db.sortByDistance and ctx.ok and ctx.distOK

    local keyed = {}
    for i, q in ipairs(quests) do
        local d = 0
        if byDistance then
            d = ctx.dist[q.questID]
            if not q.isComplete and NA.QuestMobMarker and NA.QuestMobMarker.IsQuestNear(q.title) then d = 0 end
            d = d and math.floor(d / STEP) or FAR
        end
        keyed[i] = { q = q, i = i, g = q.isComplete and 1 or 0, d = d }
    end
    table.sort(keyed, function(a, b)
        if a.g ~= b.g then return a.g < b.g end
        if a.d ~= b.d then return a.d < b.d end
        return a.i < b.i
    end)

    local out = {}
    for i, k in ipairs(keyed) do out[i] = k.q end
    return out
end

-- Filter "Dist": show only quests whose spot on the map is within N yards of you.
-- Click the button to step through the limits; after the last one it switches off.
-- If the game gives no positions, everything is shown (never hide by mistake).
local ADDON, NA = ...

local STEPS = { 250, 500, 1000, 2000 }
local DEFAULT_YARDS = 500

local Dist = { id = "distance", label = "Dist", default = true, group = "scope" } -- excludes Zone

local function yards()
    if not NA.db.distanceYards then NA.db.distanceYards = DEFAULT_YARDS end
    return NA.db.distanceYards
end

function Dist.GetLabel()
    return "Dist " .. yards() .. "y"
end

function Dist.Click()
    if not NA.Filters.IsEnabled(Dist) then
        NA.Filters.SetEnabled(Dist, true)
        NA.db.distanceYards = STEPS[1]
        return
    end
    -- the options slider can set any value, so go to the next step above the current one
    local cur = yards()
    for _, v in ipairs(STEPS) do
        if v > cur then
            NA.db.distanceYards = v
            return
        end
    end
    -- already at or past the last step: switch off
    NA.Filters.SetEnabled(Dist, false)
end

function Dist.Prepare()
    return NA.MapInfo.Get()
end

function Dist.Test(q, ctx)
    if not ctx.ok or not ctx.distOK then return true end
    local d = ctx.dist[q.questID]
    if d ~= nil and d <= yards() then return true end
    -- ready to turn in: its spot on the map is where it is turned in; turned in elsewhere = not here
    if q.isComplete then return false end
    -- the map only gives one centre point per quest, but the real area is big:
    -- a mob of this quest right next to you also means "it's here"
    return NA.QuestMobMarker ~= nil and NA.QuestMobMarker.IsQuestNear(q.title)
end

-- TEMPORARY debug: distances seen (at most one entry every 5 seconds).
local lastLog = 0
function Dist.Report(quests, ctx, passed)
    local now = GetTime()
    if now - lastLog < 5 then return end
    lastLog = now
    local db = QuestWiseProbeDB
    if not db then return end
    db.distLog = db.distLog or {}
    local entry = { time = date("%H:%M:%S"), limit = yards(), distOK = ctx.distOK, quests = {} }
    for _, q in ipairs(quests) do
        local d = ctx.dist[q.questID]
        entry.quests[#entry.quests + 1] = string.format("%s | dist=%s -> %s", q.title, d and string.format("%.0f", d) or "nil", passed[q.questID] and "SHOW" or "hide")
    end
    table.insert(db.distLog, entry)
    while #db.distLog > 8 do table.remove(db.distLog, 1) end
end

NA.Filters.Register(Dist)

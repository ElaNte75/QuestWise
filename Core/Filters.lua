-- Core: filter registry. A filter is a table:
--   { id, label, default, group, Prepare() -> ctx, Test(quest, ctx) -> bool }
-- Filters never untrack anything; they only decide what our list shows.
local ADDON, NA = ...

local Filters = { list = {} }
NA.Filters = Filters

local function state()
    NA.db.filters = NA.db.filters or {}
    return NA.db.filters
end

function Filters.Register(f)
    Filters.list[#Filters.list + 1] = f
end

function Filters.IsEnabled(f)
    local v = state()[f.id]
    if v == nil then return f.default and true or false end
    return v
end

-- Filters with the same `group` exclude each other: turning one on turns the others off.
function Filters.SetEnabled(f, on)
    state()[f.id] = on and true or false
    if on and f.group then
        for _, other in ipairs(Filters.list) do
            if other ~= f and other.group == f.group then state()[other.id] = false end
        end
    end
end

-- If saved settings have two filters of one group on, keep only the one registered last.
local function normalize()
    local taken = {}
    for i = #Filters.list, 1, -1 do
        local f = Filters.list[i]
        if f.group and Filters.IsEnabled(f) then
            if taken[f.group] then state()[f.id] = false else taken[f.group] = true end
        end
    end
end

function Filters.Toggle(f)
    Filters.SetEnabled(f, not Filters.IsEnabled(f))
end

-- Returns visible quests and stats[id] = how many quests passed that filter.
function Filters.Apply(quests)
    normalize()
    local active = {}
    local stats = {}
    for _, f in ipairs(Filters.list) do
        if Filters.IsEnabled(f) then
            local ok, ctx = NA.SafeCall(f.Prepare or function() return {} end)
            active[#active + 1] = { f = f, ctx = ok and ctx or {} }
            stats[f.id] = 0
        end
    end

    -- A filter may narrow the whole list on its own (Narrow(quests) -> list or nil), even when it is
    -- switched off (it has its own setting); when it returns a non-empty list, that list is shown and
    -- the other filters are skipped. Filters.narrowed tells the tracker (nothing else is added then).
    Filters.narrowed = false
    for _, f in ipairs(Filters.list) do
        if f.Narrow then
            local ok, only = NA.SafeCall(f.Narrow, quests)
            if ok and type(only) == "table" and #only > 0 then
                for id in pairs(stats) do stats[id] = #only end
                Filters.narrowed = true
                return only, stats
            end
        end
    end

    local visible = {}
    for _, q in ipairs(quests) do
        local show = true
        for _, a in ipairs(active) do
            local ok, pass = NA.SafeCall(a.f.Test, q, a.ctx)
            if not ok then pass = true end -- a broken filter must never hide quests
            if pass then stats[a.f.id] = stats[a.f.id] + 1 else show = false end
        end
        if show then visible[#visible + 1] = q end
    end
    return visible, stats
end

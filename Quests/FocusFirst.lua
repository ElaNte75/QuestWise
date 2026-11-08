-- Quests: a quest YOU focused (on the map, in the quest log or in our list - not the automatic
-- focus of Quests/AutoFocus.lua) is always in the list, whatever the filters say, and on top.
-- Setting: focusedFirst (on). Called by UI/Tracker.lua after the filters and the sorting.
local ADDON, NA = ...

local FF = {}
NA.FocusFirst = FF

function FF.IsOn() return NA.db.focusedFirst ~= false end

local function focusedID()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
        if ok and id and id ~= 0 then return id end
    end
    return nil
end

-- the focused quest's ID when you set the focus yourself, else nil
function FF.ManualID()
    local id = focusedID()
    if not id then return nil end
    local AF = NA.AutoFocus
    -- auto focus on: it knows which focus was yours (and keeps it); off: every focus is yours
    if AF and AF.IsOn and AF.IsOn() and AF.ManualID then
        return AF.ManualID() == id and id or nil
    end
    return id
end

-- visible: the list after filters + sorting; all: every tracked quest. Returns the new list.
function FF.Apply(visible, all)
    if not FF.IsOn() then return visible end
    local id = FF.ManualID()
    if not id then return visible end
    local quest
    for _, q in ipairs(all) do
        if q.questID == id then quest = q; break end
    end
    if not quest then return visible end -- not tracked: nothing to show
    local out = { quest }
    for _, q in ipairs(visible) do
        if q.questID ~= id then out[#out + 1] = q end
    end
    return out
end

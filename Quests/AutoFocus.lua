-- Quests: the closest tracked quest of your zone gets the focus
-- (yellow circle / map highlight / arrow) by itself - WHATEVER the distance limit, so it also
-- picks quests the list hides. Quests of other zones have no distance here and never count.
--   * only quests still to be done count; if all are ready to turn in, the closest turn-in
--     (option autoFocusTurnIns: open and ready quests count the same - simply the closest)
--   * a quest you focus yourself (ANY quest, also one ready to turn in) is kept until it is
--     turned in / no longer tracked; an open one also until it gets done
--   * if you clear the focus yourself, it stays cleared until another quest becomes the closest
-- Runs on every list refresh (game events + every 5 seconds).
local ADDON, NA = ...

local AF = {}
NA.AutoFocus = AF

local SWITCH_MARGIN = 25 -- yards: a new quest must be this much closer before the focus moves

local lastSet      -- quest ID we focused last (nil = we haven't focused anything yet)
local manualID     -- quest the player focused by hand (0 = player cleared the focus)
local manualDone   -- was that quest already ready to turn in when the player chose it?
local clearedNear  -- closest quest at the moment the player cleared the focus

local function focusedID()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
        if ok and id and id ~= 0 then return id end
    end
    return 0
end

local function setFocus(id)
    if not (C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID) then return end
    lastSet = id
    pcall(C_SuperTrack.SetSuperTrackedQuestID, id)
end

local function reset()
    lastSet, manualID, clearedNear, manualDone = nil, nil, nil, nil
end

-- works with any filter (zone, distance or none) - user decision
-- the quest this module focused last (the arrow tells your own focus apart from ours)
function AF.LastSet() return lastSet end

function AF.IsOn()
    return NA.db.autoFocusNearest ~= false
end

-- distance of a quest from you (nil = unknown); a quest whose mob you see counts as 0
local function distanceOf(q, ctx)
    if not q.isComplete and NA.QuestMobMarker and NA.QuestMobMarker.IsQuestNear(q.title) then return 0 end
    return ctx.dist[q.questID]
end

-- closest tracked quest of this zone: open quests first, ready ones only if no open quest is known
local function nearest(visible, ctx)
    local mixed = NA.db.autoFocusTurnIns == true
    local best, bestD, bestDone, bestDoneD
    for _, q in ipairs(visible) do
        local d = distanceOf(q, ctx)
        if d then
            if q.isComplete then
                if not bestDoneD or d < bestDoneD then bestDone, bestDoneD = q, d end
            elseif not bestD or d < bestD then
                best, bestD = q, d
            end
        end
    end
    if mixed and bestDone and (not bestD or bestDoneD < bestD) then return bestDone, bestDoneD end
    if best then return best, bestD end
    return bestDone, bestDoneD
end

function AF.Update(visible) -- visible = ALL tracked quests (not only those the list shows)
    if not AF.IsOn() then reset(); return end
    local ctx = NA.MapInfo.Get()
    if not ctx.ok or not ctx.distOK then return end

    local cur = focusedID()
    -- the focus changed and it wasn't us: the player chose (or cleared) it
    if lastSet ~= nil and cur ~= lastSet then
        manualID = cur
        lastSet = cur
        clearedNear = nil
        manualDone = nil
    end

    local near, nearD = nearest(visible, ctx)
    local byID = {}
    for _, q in ipairs(visible) do byID[q.questID] = q end

    if manualID ~= nil then
        if manualID == 0 then
            -- player cleared the focus: wait until a different quest becomes the closest
            local nearID = near and near.questID or 0
            if clearedNear == nil then clearedNear = nearID end
            if nearID == clearedNear then return end
        else
            local q = byID[manualID]
            if q then
                if manualDone == nil then manualDone = q.isComplete and true or false end
                -- keep the player's quest; an open one only until it gets done
                if manualDone or not q.isComplete then return end
            end
        end
        manualID, clearedNear = nil, nil
    end

    if not near then return end
    if near.questID == cur then lastSet = cur; return end

    -- small hysteresis so two quests at about the same distance don't swap back and forth
    local curQ = byID[cur]
    if curQ and lastSet == cur and (NA.db.autoFocusTurnIns == true or curQ.isComplete == near.isComplete) then
        local curD = distanceOf(curQ, ctx)
        if curD and curD - nearD < SWITCH_MARGIN then return end
    end
    setFocus(near.questID)
end

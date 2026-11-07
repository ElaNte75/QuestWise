-- Quests: with "Only quests near me" on, the closest quest in the list gets the focus
-- (yellow circle / map highlight) by itself.
--   * only quests still to be done count; if all are ready to turn in, the closest turn-in
--   * a quest you focus yourself is kept until it is done or leaves the list
--   * if you clear the focus yourself, it stays cleared until another quest becomes the closest
-- Runs on every list refresh (game events + every 5 seconds).
local ADDON, NA = ...

local AF = {}
NA.AutoFocus = AF

local SWITCH_MARGIN = 25 -- yards: a new quest must be this much closer before the focus moves

local lastSet      -- quest ID we focused last (nil = we haven't focused anything yet)
local manualID     -- quest the player focused by hand (0 = player cleared the focus)
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
    lastSet, manualID, clearedNear = nil, nil, nil
end

function AF.IsOn()
    if NA.db.autoFocusNearest == false then return false end
    for _, f in ipairs(NA.Filters.list) do
        if f.id == "distance" then return NA.Filters.IsEnabled(f) end
    end
    return false
end

-- distance of a quest from you (nil = unknown); a quest whose mob you see counts as 0
local function distanceOf(q, ctx)
    if not q.isComplete and NA.QuestMobMarker and NA.QuestMobMarker.IsQuestNear(q.title) then return 0 end
    return ctx.dist[q.questID]
end

-- closest quest of the shown list: open quests first, ready ones only if no open quest is known
local function nearest(visible, ctx)
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
    if best then return best, bestD end
    return bestDone, bestDoneD
end

function AF.Update(visible)
    if not AF.IsOn() then reset(); return end
    local ctx = NA.MapInfo.Get()
    if not ctx.ok or not ctx.distOK then return end

    local cur = focusedID()
    -- the focus changed and it wasn't us: the player chose (or cleared) it
    if lastSet ~= nil and cur ~= lastSet then
        manualID = cur
        lastSet = cur
        clearedNear = nil
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
            if q and not q.isComplete then return end -- keep the player's quest
        end
        manualID, clearedNear = nil, nil
    end

    if not near then return end
    if near.questID == cur then lastSet = cur; return end

    -- small hysteresis so two quests at about the same distance don't swap back and forth
    local curQ = byID[cur]
    if curQ and lastSet == cur and (curQ.isComplete == near.isComplete) then
        local curD = distanceOf(curQ, ctx)
        if curD and curD - nearD < SWITCH_MARGIN then return end
    end
    setFocus(near.questID)
end

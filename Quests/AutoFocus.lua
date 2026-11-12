-- Quests: the closest tracked quest of your zone gets the focus
-- (yellow circle / map highlight / arrow) by itself - only within the distance you set (Quest list ->
-- Distance), user decision 2026-11-11 (autoFocusInRange, on; off = the closest whatever the distance).
-- Nothing within the distance = our focus is cleared until a quest comes within it.
-- Quests of other zones have no distance here and never count.
-- Flying with a flight master / in a major city (Quests/Quiet.lua), dead or a ghost: it does nothing
--   (user report 2026-11-11: it picked a quest while dead). A focus the game drops while you are dead
--   comes back when you are alive.
--   * your own focus is kept after /reload too (NA.db.autoFocusManual / autoFocusManualDone)
--   * easier quests first (autoFocusEasyFirst, on): grey, green, yellow, orange, then red / elite /
--     group (UI/QuestColor.lua QC.Tier), the closest within each - user decision 2026-11-11
--   * only quests still to be done count; if all are ready to turn in, the closest turn-in
--     (option autoFocusTurnIns: open and ready quests count the same - simply the closest)
--   * a quest you focus yourself (ANY quest, also one ready to turn in) is kept until it is
--     turned in / no longer tracked; an open one also until it gets done
--   * if you clear the focus yourself, it stays cleared until another quest becomes the closest
--   * distance = the quest's spot on the map only (seen quest mobs don't count)
-- Runs on every list refresh (game events + every 5 seconds).
local ADDON, NA = ...

local AF = {}
NA.AutoFocus = AF

local SWITCH_MARGIN = 25 -- yards: a new quest must be this much closer before the focus moves

local lastSet      -- quest ID we focused last (nil = we haven't focused anything yet)
local manualID     -- quest the player focused by hand (0 = player cleared the focus)
local manualDone   -- was that quest already ready to turn in when the player chose it?
local clearedNear  -- closest quest at the moment the player cleared the focus
local lastSeen     -- the focus as it was at the previous check (any change we didn't make = the player's)
local wasDead      -- the previous check was skipped because you were dead

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
    lastSeen = nil
end

-- works with any filter (zone, distance or none) - user decision
-- the quest this module focused last (the arrow tells your own focus apart from ours)
function AF.LastSet() return lastSet end
-- the quest the player focused and auto focus is leaving alone right now (nil = none)
function AF.ManualID() if manualID and manualID ~= 0 then return manualID end return nil end

function AF.IsOn()
    return NA.db.autoFocusNearest ~= false
end

function AF.InRangeOnly() return NA.db.autoFocusInRange ~= false end
local function rangeYards() return NA.db.distanceYards or 500 end

-- distance of a quest from you (nil = unknown): its spot on the map ONLY. A mob of a quest seen
-- nearby does NOT count (it made the focus jump to another quest whose area overlaps - user report);
-- the list still shows such a quest (Data/DistanceFilter.lua), only the focus ignores it.
local function distanceOf(q, ctx)
    return ctx.dist[q.questID]
end

function AF.EasyFirst() return NA.db.autoFocusEasyFirst ~= false end
local UNKNOWN_TIER = 3 -- level unknown: counted as your level (yellow)
local function tierOf(q)
    if q.isComplete or not AF.EasyFirst() then return 0 end
    return NA.QuestColor and NA.QuestColor.Tier(q) or UNKNOWN_TIER
end

-- closest tracked quest of this zone: open quests first (easier first), ready ones only if no open quest is known
local function nearest(visible, ctx)
    local mixed = NA.db.autoFocusTurnIns == true
    local best, bestD, bestT, bestDone, bestDoneD
    local DF = NA.DungeonFilter
    for _, q in ipairs(visible) do
        local d = distanceOf(q, ctx)
        if d and DF and DF.Hides(q.questID) then d = nil end -- dungeon quest while outside (Data/DungeonFilter.lua)
        if d and AF.InRangeOnly() and d > rangeYards() then d = nil end -- beyond the distance you set
        if d then
            if q.isComplete then
                if not bestDoneD or d < bestDoneD then bestDone, bestDoneD = q, d end
            else
                local t = tierOf(q)
                if not bestD or t < bestT or (t == bestT and d < bestD) then best, bestD, bestT = q, d, t end
            end
        end
    end
    if mixed and bestDone and (not bestD or bestDoneD < bestD) then return bestDone, bestDoneD end
    if best then return best, bestD end
    return bestDone, bestDoneD
end

local function dead()
    local M = NA.QuestMobMarker
    return M and M.PlayerDead and M.PlayerDead() or false
end

local function setFocusQuiet(id) -- puts a focus back without making it "ours"
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then pcall(C_SuperTrack.SetSuperTrackedQuestID, id) end
end

local function update(visible)
    if not AF.IsOn() then reset(); return end
    if dead() then wasDead = true; return end -- dead / ghost: nothing changes, not even "you chose"

    local cur = focusedID()
    if lastSeen == nil then
        -- first check after login / reload: your own focus from before is still yours
        local saved = tonumber(NA.db.autoFocusManual)
        if saved and saved ~= 0 and (cur == saved or cur == 0) then
            local tracked = false
            for _, q in ipairs(visible) do if q.questID == saved then tracked = true end end
            if tracked then
                if cur == 0 then setFocusQuiet(saved); cur = saved end
                manualID, lastSet, manualDone = saved, saved, NA.db.autoFocusManualDone
            end
        end
    elseif wasDead and cur == 0 and lastSeen ~= 0 then
        -- the game dropped the focus while you were dead: not your choice, it comes back
        setFocusQuiet(lastSeen); cur = lastSeen
    end
    wasDead = false

    -- the focus changed and it wasn't us: the player chose (or cleared) it.
    -- Checked BEFORE anything else (also when distances are unknown), and also before we ever set a
    -- focus ourselves (before, a focus of yours was missed then - user report: not on top of the list)
    if lastSeen ~= nil and cur ~= lastSeen and cur ~= lastSet then
        manualID = cur
        lastSet = cur
        clearedNear = nil
        manualDone = nil
    end
    lastSeen = cur

    if NA.Quiet and NA.Quiet.Mobs() then return end -- flying / major city: nothing changes

    local ctx = NA.MapInfo.Get()
    if not ctx.ok or not ctx.distOK then return end

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

    if not near then
        -- nothing within the distance: our own focus goes away (yours is never touched here)
        if AF.InRangeOnly() and cur ~= 0 and cur == lastSet then
            setFocus(0)
            lastSeen = 0
        end
        return
    end
    if near.questID == cur then lastSet = cur; return end

    -- small hysteresis so two quests at about the same distance don't swap back and forth
    local curQ = byID[cur]
    if curQ and lastSet == cur and (NA.db.autoFocusTurnIns == true or curQ.isComplete == near.isComplete)
        and tierOf(curQ) == tierOf(near) then
        local curD = distanceOf(curQ, ctx)
        local inRange = curD and not (AF.InRangeOnly() and curD > rangeYards())
        if inRange and curD - nearD < SWITCH_MARGIN then return end
    end
    setFocus(near.questID)
    lastSeen = near.questID
end

function AF.Update(visible) -- visible = ALL tracked quests (not only those the list shows)
    update(visible)
    NA.db.autoFocusManual = AF.ManualID()
    NA.db.autoFocusManualDone = AF.ManualID() and manualDone or nil
end

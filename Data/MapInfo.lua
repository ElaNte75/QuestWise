-- Data: shared map facts for filters (current zone, quests on the map, distance in yards).
-- Computed once per frame and shared by every filter that asks.
local ADDON, NA = ...

local M = {}
NA.MapInfo = M

local ZONE_MAP_TYPE = 3 -- Enum.UIMapType.Zone
local cache, cacheTime

local function playerPos(mapID)
    if not C_Map.GetPlayerMapPosition then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then return nil end
    local x, y = pos:GetXY()
    if not x or (x == 0 and y == 0) then return nil end
    return x, y
end

local function worldSize(mapID)
    if not C_Map.GetMapWorldSize then return nil end
    local ok, w, h = pcall(C_Map.GetMapWorldSize, mapID)
    if ok and w and w > 0 and h and h > 0 then return w, h end
    return nil
end

local function build()
    -- ok: map data available; distOK: distances in yards available
    local ctx = { ok = false, distOK = false, onMap = {}, dist = {} }
    if not (C_Map and C_Map.GetBestMapForUnit and C_QuestLog.GetQuestsOnMap) then return ctx end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return ctx end

    local zoneID = mapID
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local guard = 0
    while info and info.mapType and info.mapType > ZONE_MAP_TYPE and info.parentMapID and info.parentMapID > 0 and guard < 6 do
        zoneID = info.parentMapID
        info = C_Map.GetMapInfo(zoneID)
        guard = guard + 1
    end
    ctx.mapID, ctx.zoneID = mapID, zoneID
    ctx.zoneName = (info and info.name) or GetZoneText()

    local ids = { mapID }
    if zoneID ~= mapID then ids[2] = zoneID end
    for _, id in ipairs(ids) do
        local ok, list = pcall(C_QuestLog.GetQuestsOnMap, id)
        if ok and type(list) == "table" then
            ctx.ok = true
            local px, py = playerPos(id)
            local w, h = worldSize(id)
            local canMeasure = px and w
            if canMeasure then ctx.distOK = true end
            for _, q in ipairs(list) do
                ctx.onMap[q.questID] = true
                if canMeasure and q.x and q.y then
                    local dx, dy = (q.x - px) * w, (q.y - py) * h
                    local d = math.sqrt(dx * dx + dy * dy)
                    if not ctx.dist[q.questID] or d < ctx.dist[q.questID] then ctx.dist[q.questID] = d end
                end
            end
        end
    end
    return ctx
end

function M.Get()
    local now = GetTime()
    if cache and cacheTime == now then return cache end
    cache, cacheTime = build(), now
    return cache
end

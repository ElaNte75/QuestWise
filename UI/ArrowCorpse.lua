-- UI: while you are dead the quest arrow (UI/Arrow.lua) leads to your corpse instead of the quest.
--   * dead, not released yet: the arrow hides (nothing to walk to)
--   * ghost: it points to your corpse, with the distance and "Your corpse"
--     (if the game doesn't say where the corpse is on this map, the arrow hides)
--   * alive again: back to the focused quest as before
--   * option arrowCorpse off: no arrow at all while dead; arrowCorpseYards: hides this close to the corpse
local ADDON, NA = ...

local AC = {}
NA.ArrowCorpse = AC

AC.MIN_YARDS, AC.MAX_YARDS, AC.DEFAULT_YARDS = 20, 100, 30

function AC.IsOn() return NA.db.arrowCorpse ~= false end
function AC.HideYards()
    local v = tonumber(NA.db.arrowCorpseYards) or AC.DEFAULT_YARDS
    return math.min(math.max(v, AC.MIN_YARDS), AC.MAX_YARDS)
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

function AC.IsDead()
    return call(UnitIsDeadOrGhost, "player") and true or false
end

function AC.IsGhost()
    return call(UnitIsGhost, "player") and true or false
end

-- where the corpse is, measured on the map you are on (or its zone): { vec = {dx east, dy south}, dist } or nil
function AC.Target()
    if not AC.IsGhost() then return nil end
    if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and C_Map and C_Map.GetBestMapForUnit) then return nil end
    local M = NA.MapInfo
    local mapID = call(C_Map.GetBestMapForUnit, "player")
    local guard = 0
    while mapID and guard < 4 do
        local pos = call(C_DeathInfo.GetCorpseMapPosition, mapID)
        local cx, cy
        if pos and pos.GetXY then cx, cy = pos:GetXY() end
        local px, py = M.PlayerPos(mapID)
        local w, h = M.WorldSize(mapID)
        if cx and (cx ~= 0 or cy ~= 0) and px and w then
            local dx, dy = (cx - px) * w, (cy - py) * h
            return { vec = { dx, dy }, dist = math.sqrt(dx * dx + dy * dy) }
        end
        -- not on this map (e.g. a small sub-zone): try the bigger map around it
        local info = C_Map.GetMapInfo and call(C_Map.GetMapInfo, mapID)
        mapID = info and info.parentMapID ~= 0 and info.parentMapID or nil
        guard = guard + 1
    end
    return nil
end

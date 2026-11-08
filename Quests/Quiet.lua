-- Quests: "stay quiet" times - while flying (flight master) and inside the major cities.
--   * flying (quietFlying): no quest-mob marks, no sounds, no arrow
--   * major city (quietCities): the same, and the quest list folds up to its title; when you leave
--     the city it opens again (only if the city folded it - not if you folded it yourself)
-- Mobs/QuestMobMarker.lua and UI/Arrow.lua ask Quiet.Mobs() / Quiet.Arrow().
local ADDON, NA = ...

local Q = {}
NA.Quiet = Q

-- the six major cities: map IDs (classic and newer clients) and English names as a fallback
local CITY_MAPS = {
    [1453] = true, [1455] = true, [1457] = true, [1454] = true, [1456] = true, [1458] = true,
    [84] = true, [87] = true, [89] = true, [85] = true, [88] = true, [90] = true,
}
local CITY_NAMES = {
    ["Stormwind City"] = true, ["Stormwind"] = true, ["Ironforge"] = true, ["Darnassus"] = true,
    ["Orgrimmar"] = true, ["Thunder Bluff"] = true, ["Undercity"] = true,
}

function Q.FlyingOn() return NA.db.quietFlying ~= false end
function Q.CitiesOn() return NA.db.quietCities ~= false end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

function Q.IsFlying()
    return call(UnitOnTaxi, "player") and true or false
end

function Q.InCity()
    if C_Map and C_Map.GetBestMapForUnit then
        local mapID = call(C_Map.GetBestMapForUnit, "player")
        local guard = 0
        while mapID and guard < 4 do
            if CITY_MAPS[mapID] then return true end
            local info = C_Map.GetMapInfo and call(C_Map.GetMapInfo, mapID)
            if not info then break end
            if info.name and CITY_NAMES[info.name] then return true end
            mapID = info.parentMapID ~= 0 and info.parentMapID or nil
            guard = guard + 1
        end
    end
    local zone = call(GetRealZoneText)
    return zone ~= nil and CITY_NAMES[zone] == true
end

local function flyingQuiet() return Q.FlyingOn() and Q.IsFlying() end
local function cityQuiet() return Q.CitiesOn() and Q.InCity() end

-- no quest-mob marks / sounds / "near" quests right now
function Q.Mobs() return flyingQuiet() or cityQuiet() end
-- no arrow right now
function Q.Arrow() return flyingQuiet() or cityQuiet() end

-- the quest list folds up when you come into a city and opens again when you leave
local wasCity = nil
local wasQuiet = nil

local function refreshAll()
    if NA.QuestMobMarker and NA.QuestMobMarker.RequestRefresh then NA.QuestMobMarker.RequestRefresh() end
    if NA.Arrow then NA.SafeCall(NA.Arrow.Update) end
    if NA.Tracker then NA.Tracker.RequestRefresh() end
end

function Q.Check()
    local city = cityQuiet()
    if city ~= wasCity then
        if city then
            if not NA.db.collapsedAll then
                NA.db.collapsedAll = true
                NA.db.quietCityFolded = true
            end
        elseif NA.db.quietCityFolded then
            NA.db.collapsedAll = false
            NA.db.quietCityFolded = nil
        end
        wasCity = city
        if NA.Tracker then NA.Tracker.RequestRefresh() end
    end
    local quiet = Q.Mobs()
    if quiet ~= wasQuiet then
        wasQuiet = quiet
        refreshAll()
    end
end

-- you folded / opened the list yourself: the city no longer opens it for you when you leave
function Q.ListToggledByHand()
    NA.db.quietCityFolded = nil
end

NA.OnInit(function()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
                         "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function() NA.SafeCall(Q.Check) end)
    Q.events = ev
    -- taxi start / end doesn't always send an event: look every second as well
    C_Timer.NewTicker(1, function() NA.SafeCall(Q.Check) end)
    NA.SafeCall(Q.Check)
end)

-- Quests: "stay quiet" times - while flying (flight master) and inside the major cities.
--   * flying (quietFlying): no quest-mob marks, no sounds, no arrow, and the list folds up like in a
--     city (user decision 2026-11-10), opening again when you land
--   * major city (quietCities): the same, and the quest list folds up to its title
--   * both: the automatic focus stops (Quests/AutoFocus.lua). When you land / leave the city the list
--     opens again as soon as it has something to show (class quest, your focus, quests within the
--     distance) - even if it was folded before (user decision 2026-11-11); folding it by hand after
--     that keeps it folded.
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

-- the quest list folds up when you come into a city (or take a flight) and opens again after it
local wasCity = nil
local wasQuiet = nil
local expandPending = false

local function refreshAll()
    if NA.QuestMobMarker and NA.QuestMobMarker.RequestRefresh then NA.QuestMobMarker.RequestRefresh() end
    if NA.Arrow then NA.SafeCall(NA.Arrow.Update) end
    if NA.Tracker then NA.Tracker.RequestRefresh() end
end

function Q.Check()
    local city = cityQuiet() or flyingQuiet()
    if city ~= wasCity then
        if city then
            NA.db.collapsedAll = true
            expandPending = false
        elseif wasCity == true or NA.db.quietCityFolded then
            expandPending = true -- UI/Tracker.lua opens the list once it has quests (Q.AfterQuiet)
        end
        NA.db.quietCityFolded = nil
        wasCity = city
        if NA.Tracker then NA.Tracker.RequestRefresh() end
    end
    local quiet = Q.Mobs()
    if quiet ~= wasQuiet then
        wasQuiet = quiet
        refreshAll()
    end
end

-- you folded / opened the list yourself: it is left as you set it
function Q.ListToggledByHand()
    NA.db.quietCityFolded = nil
    expandPending = false
end

-- called by UI/Tracker.lua with how many quests the list shows now
function Q.AfterQuiet(count)
    if not expandPending or count == 0 then return end
    expandPending = false
    NA.db.collapsedAll = false
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

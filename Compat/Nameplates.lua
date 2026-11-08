-- Compat: keeps the game's "enemy nameplates" switch (the V key) in step with our two settings.
--   showNameplates  = you want the health bars
--   markQuestMobs   = you want quest marks (they need nameplates to exist, even if invisible)
-- The game's switch is on when either is wanted, and really off when neither is.
-- Pressing V while the mark is on toggles "Show enemy nameplates". Changes only outside combat.
local ADDON, NA = ...

local CVAR = "nameplateShowEnemies"
local get = (C_CVar and C_CVar.GetCVar) or GetCVar
local set = (C_CVar and C_CVar.SetCVar) or SetCVar

local RANGE_CVAR = "nameplateMaxDistance" -- how far away (yards) the game shows enemy nameplates

local expected -- what the game's switch should be ("1"/"0") after our last change

local function wanted()
    return (NA.db.markQuestMobs or NA.db.showNameplates) and "1" or "0"
end

-- The range the game really uses right now (it may cap what we ask for).
local function currentRange()
    return get and tonumber(get(RANGE_CVAR)) or nil
end

local function ensure()
    if not (get and set) or InCombatLockdown() then return end
    expected = wanted()
    if get(CVAR) ~= expected then pcall(set, CVAR, expected) end
    -- how far away you see enemies (set once in the options; nil = leave the game's own value)
    local range = tonumber(NA.db.nameplateRange)
    if range and currentRange() ~= range then pcall(set, RANGE_CVAR, range) end
end

-- Did the player change the game's switch (V key / game settings) since we last set it?
local function checkOutside()
    if not (get and expected) or InCombatLockdown() then return end
    local cur = get(CVAR)
    if cur == expected then return end
    if NA.db.markQuestMobs then
        NA.db.showNameplates = not NA.db.showNameplates -- V = show/hide the health bars
    else
        NA.db.showNameplates = (cur == "1")
    end
    ensure()
    if NA.QuestMobMarker then NA.QuestMobMarker.RefreshAll() end
    if NA.Options then NA.Options.RefreshCurrent() end
end

NA.Nameplates = { Apply = ensure, Check = checkOutside, Range = currentRange }

NA.OnInit(function()
    if NA.db.showNameplates == nil and get then
        NA.db.showNameplates = (get(CVAR) == "1") -- first run: start from what the game has now
    end
    ensure()
    C_Timer.NewTicker(1, function() NA.SafeCall(checkOutside) end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function()
        NA.SafeCall(checkOutside)
        NA.SafeCall(ensure)
    end)
end)

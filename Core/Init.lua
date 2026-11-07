-- Core: shared namespace, saved settings, startup callbacks, small helpers.
local ADDON, NA = ...

NA.name = ADDON
NA.errors = {}

local MAX_ERRORS = 20

local defaults = {
    collapsedAll = false,
    collapsedQuests = false,
    sortByDistance = true,   -- nearest quest first
    arrowEnabled = true,     -- arrow on screen pointing to the focused quest (UI/Arrow.lua)
    arrowLocked = true,      -- arrow can't be dragged
    -- arrowPos: saved spot {x, y} after you move the arrow (nil = top centre of the screen)
    autoFocusNearest = true, -- with "Only quests near me": the closest quest gets the focus
    listLocked = true,       -- quest list can't be dragged (Interface page)
    listWidth = 260,         -- px, 200..500
    listMaxHeight = 1050,    -- px: the list grows with its quests up to this, then scrolls
    listScale = 100,         -- % size of the whole list (60..150)
    listFontSize = 12,       -- px text size inside the list (9..16)
    optionsScale = 100,      -- % size of the options window (70..130)
    listBackground = false,  -- dark panel behind the list
    listOpacity = 60,        -- % of that panel
    -- listPos: saved spot {right, top} after you move the list (nil = the default spot, see UI/ListLayout.lua)
    completeSoundEnabled = true,    -- sound when a quest gets completed
    completeSoundChoice = "Default",
    completeSoundVolume = 60,
    soundVolume = 60,        -- 10..100 (steps of 10); 50 = "same loudness" level, 100 = twice as loud
    soundChoice = "Default", -- key from QuestMobMarker.SOUNDS
    soundQuestMob = true,    -- sound when a quest mob you aren't tracking-nearby appears
    mobAddsQuest = true,     -- quests of mobs you find are added to the list
    ignoreTapped = true,     -- mobs tapped by another player don't add their quest or play the sound
    keepSeconds = 60,        -- ...for how long after the mob went out of sight (10..120 s)
    markQuestMobs = true,    -- quest mark on quest mobs
    -- showNameplates: not listed on purpose - on first run it is read from the game's own setting
}

-- Record an error without printing anything to chat.
function NA.LogError(msg)
    local list = NA.errors
    list[#list + 1] = tostring(msg)
    while #list > MAX_ERRORS do table.remove(list, 1) end
end

local function handler(err)
    return debug.traceback(tostring(err), 2)
end

-- Run fn(...) and log (never print) any error. Returns ok, result.
function NA.SafeCall(fn, ...)
    local args = { ... }
    local n = select("#", ...)
    return xpcall(function() return fn(unpack(args, 1, n)) end, handler)
end

-- SetAtlas that never raises; uses `fallback` if `name` is unknown.
function NA.SetAtlas(tex, name, fallback)
    local use = name
    if C_Texture and C_Texture.GetAtlasInfo and fallback and not C_Texture.GetAtlasInfo(name) then
        use = fallback
    end
    local ok = pcall(tex.SetAtlas, tex, use)
    return ok
end

-- Uses the first atlas from `names` that exists. Returns ok, usedName.
function NA.SetAtlasFirst(tex, names)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    for _, name in ipairs(names) do
        if C_Texture.GetAtlasInfo(name) then
            local ok = pcall(tex.SetAtlas, tex, name)
            if ok then return true, name end
        end
    end
    return false
end

-- Startup callbacks run (in load order) at PLAYER_LOGIN.
local initCallbacks = {}
function NA.OnInit(fn)
    initCallbacks[#initCallbacks + 1] = fn
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        -- before it got its name the add-on kept its settings in NewAddonDB: move them over once
        if QuestWiseDB == nil and type(NewAddonDB) == "table" then QuestWiseDB = NewAddonDB end
        NewAddonDB = nil
        QuestWiseDB = QuestWiseDB or {}
        for k, v in pairs(defaults) do
            if QuestWiseDB[k] == nil then QuestWiseDB[k] = v end
        end
        NA.db = QuestWiseDB
    elseif event == "PLAYER_LOGIN" then
        for _, fn in ipairs(initCallbacks) do
            local ok, err = NA.SafeCall(fn)
            if not ok then NA.LogError(err) end
        end
    end
end)

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
    arrowArriveYards = 30,   -- the arrow hides when you are this close to the quest's spot (10..150 yd)
    arrowReturnYards = 150,  -- after you reach a quest, the arrow comes back only past this (50..500 yd)
    arrowWaitSeconds = 60,   -- ...and only after this long without progress for that quest (15..180 s)
    arrowHideCombat = true,  -- the arrow hides while you are in combat (UI/ArrowCombat.lua)
    arrowCombatWait = false, -- ...and comes back after arrowCombatDelay (off = right after the fight)
    arrowCombatDelay = 30,   -- seconds, 10..120
    arrowUseArea = true,     -- the arrow uses the quest's blue map area: hidden inside it and near it (UI/QuestArea.lua)
    arrowAreaYards = 40,     -- ..."near" = this close to the area (0..100 yd)
    arrowCorpse = true,      -- dead: the arrow leads to your corpse (off = no arrow until alive) - UI/ArrowCorpse.lua
    arrowCorpseYards = 30,   -- ...and hides this close to it (20..100 yd)
    arrowLocked = true,
    arrowStyle = "Game",     -- picture of the arrow (UI/Arrow.lua STYLES)
    arrowSize = 42,          -- px, 24..96
    arrowColor = "Default",  -- UI/Arrow.lua COLORS      -- arrow can't be dragged
    -- arrowPos: saved spot {x, y} after you move the arrow (nil = top centre of the screen)
    autoFocusTurnIns = false, -- auto focus / arrow also lead to quests ready to turn in (closest of all)
    mobColors = true,        -- quest mark on mobs coloured by the mob's difficulty (Mobs/MobLook.lua)
    mobColorsCustom = false, -- ...by your own level limits (separate from the quest colours)
    mobColorRed = 4, mobColorOrange = 2, mobColorGreen = 3, mobColorGrey = 7, -- levels above / below you
    mobProgress = true,
    objectProgress = true,   -- "7/8 !" next to the cursor over quest objects (Mobs/ObjectProgress.lua)      -- quest progress (e.g. 3/10) next to the mark
    quietFlying = true,      -- flying with a flight master: no mob marks / sounds / arrow (Quests/Quiet.lua)
    quietCities = true,      -- major cities: the same, and the quest list folds up while you are there
    questInfoEnabled = true, -- the whole quest info feature (summary + "i" button + window)
    questInfoHover = true,  -- small "what to do" box when the mouse is over a quest (UI/QuestInfo.lua)
    questInfoButton = true,  -- "i" button next to each quest: quest details window (UI/QuestInfoWindow.lua)
    questInfoRewards = true, -- ...the window shows the rewards
    questInfoFont = 12,      -- px text size in the window (9..16)
    questInfoScale = 100,    -- % size of the window (60..150)
    questInfoWidth = 360,    -- px, the same for every quest (280..560)
    questInfoHeight = 480,   -- px, the same for every quest; more scrolls (250..800)
    questInfoBackground = true, -- dark panel behind the window
    questInfoOpacity = 85,   -- % of that panel (10..100)
    -- questInfoPos: saved spot {x, y} after you move the window (nil = next to the quest list)
    mapArea = true,          -- the game's quest areas on the world map in our own colour (UI/MapArea.lua)
    mapAreaColor = "SoftWhite", -- UI/MapArea.lua COLORS
    mapAreaOpacity = 45,     -- % (10..100)
    mapAreaOutline = false,  -- only the line around the area, nothing inside
    mapAreaThickness = 2,    -- thickness of that line (1..5)
    mapHideOthers = true,    -- world map: only the focused quest's area, the others hidden
    mapMinimap = true,       -- minimap: the inside of the quest areas in the same colour (its edge stays the game's)
    dungeonOnlyInside = true, -- inside a dungeon: only its quests, whatever the filters (Data/DungeonFilter.lua)
    focusedFirst = true,    -- a quest you focus yourself is always in the list, on top (Quests/FocusFirst.lua)
    autoFocusNearest = true, -- with "Only quests near me": the closest quest gets the focus
    listLocked = true,       -- quest list can't be dragged (Interface page)
    listWidth = 260,         -- px, 200..500
    listMaxHeight = 1050,    -- px: the list grows with its quests up to this, then scrolls
    listScale = 100,         -- % size of the whole list (60..150)
    listFontSize = 12,       -- px text size inside the list (9..16)
    optionsScale = 100,      -- % size of the options window (70..130)
    questColors = true,      -- quest titles coloured by difficulty (UI/QuestColor.lua)
    questColorsCustom = false, -- ...by your own level limits instead of the game's
    questColorRed = 5,       -- levels above you: very hard (1..10)
    questColorOrange = 3,    -- levels above you: hard (1..10)
    questColorGreen = 3,     -- levels below you: easy (1..10)
    questColorGrey = 8,      -- levels below you: too easy (1..15)
    listBackground = false,  -- dark panel behind the list
    listFrame = true,        -- frame picture around the list background (presets GearQuest / Stone)
    theme = "QuestWise",     -- look preset (UI/Theme.lua): QuestWise, GearQuest, Midnight, Forest, Game (shown as "Stone")
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

-- Debug log. Does nothing on its own: the separate QuestWise_Debug add-on (game folder only, never
-- published) replaces it when it is installed. Use: NA.Debug("topic", ...)
function NA.Debug() end

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
        QuestWiseDB = QuestWiseDB or {}
        for k, v in pairs(defaults) do
            if QuestWiseDB[k] == nil then QuestWiseDB[k] = v end
        end
        NA.db = QuestWiseDB
    elseif event == "PLAYER_LOGIN" then
        -- the optional debug add-on gets our shared table (it is not there for players)
        if type(QuestWiseDebug_Attach) == "function" then NA.SafeCall(QuestWiseDebug_Attach, NA) end
        for _, fn in ipairs(initCallbacks) do
            local ok, err = NA.SafeCall(fn)
            if not ok then NA.LogError(err) end
        end
    end
end)

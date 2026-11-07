import os
import sys
from lupa import LuaRuntime

root = sys.argv[1]
# the add-on's name = its folder name (New_Addon before the rename, QuestWise after)
ADDON_NAME = os.path.basename(os.path.normpath(root))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ADDON_NAME = ADDON_NAME

mock = r'''
-- Minimal fake WoW environment: every frame/texture/fontstring accepts any method.
local timers = {}
unpack = unpack or table.unpack
local function newObj(kind)
    local o = { _kind = kind, _shown = true, _text = "", _w = 100, _h = 20 }
    local mt = {}
    mt.__index = function(t, k)
        if k == "GetStringHeight" then return function(self) return 11.67 end end
        if k == "Text" or k == "Low" or k == "High" then return nil end
        if k == "GetFrameLevel" then return function() return 1 end end
        if k == "GetStringWidth" then return function(self) return 40 end end
        if k == "GetText" then return function(self) return self._text end end
        if k == "SetText" then return function(self, s) self._text = s end end
        if k == "SetShown" then return function(self, v) self._shown = v and true or false end end
        if k == "IsShown" then return function(self) return self._shown end end
        if k == "Show" then return function(self) self._shown = true end end
        if k == "Hide" then return function(self) self._shown = false end end
        if k == "SetSize" then return function(self, w, h) self._w, self._h = w, h end end
        if k == "SetWidth" then return function(self, w) self._w = w end end
        if k == "SetHeight" then return function(self, h) self._h = h end end
        if k == "GetWidth" then return function(self) return self._w end end
        if k == "GetHeight" then return function(self) return self._h end end
        if k == "GetPoint" then return function() return "TOPRIGHT", nil, "TOPRIGHT", 0, -26 end end
        if k == "GetEffectiveScale" then return function() return 1 end end
        if k == "CreateFontString" or k == "CreateTexture" then return function() return newObj("region") end end
        if k == "HookScript" then return function(self, ev, fn) self._hook = fn end end
        if k == "SetScript" then return function(self, ev, fn) self["_s_" .. ev] = fn end end
        if k == "GetScript" then return function(self, ev) return rawget(self, "_s_" .. ev) end end
        if k == "GetFrameLevel" then return function() return 1 end end
        if k == "SetAtlas" then return function() end end
        return function() end
    end
    return setmetatable(o, mt)
end

local registered = {}
function CreateFrame(kind, name, parent)
    local f = newObj(kind)
    if name then _G[name] = f end
    f.RegisterEvent = function(self, ev) registered[ev] = self end
    f.GetName = function(self) return name end
    return f
end
UIParent = newObj("Frame")
SlashCmdList = {}
UISpecialFrames = {}
SOUNDKIT = { UI_QUEST_ROLLING_FORWARD_01 = 1 }
soundCalls = 0
function PlaySound() soundCalls = soundCalls + 1 end
function PlaySoundFile() soundCalls = soundCalls + 1; return true end
RightManagedFrameContainer = newObj("Frame")
ObjectiveTrackerFrame = newObj("Frame")
GameTooltip = newObj("Frame")
C_Timer = { After = function(sec, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
C_Texture = { GetAtlasInfo = function(n) return n ~= "UI-QuestTrackerButton-Expand-All" and {} or nil end }
function date() return "now" end
function IsShiftKeyDown() return false end
function InCombatLockdown() return false end
local cvars = { nameplateShowEnemies = "0", nameplateMaxDistance = "60" }
-- the fake game caps the nameplate range at 60 yards, like a game might
C_CVar = { GetCVar = function(n) return cvars[n] end,
           SetCVar = function(n, v) if n == "nameplateMaxDistance" then v = math.min(tonumber(v), 60) end cvars[n] = v end }
C_NamePlate = { GetNamePlateForUnit = function(u) return nil end }
function UnitExists() return false end
function UnitGUID() return "guid" end
function hooksecurefunc() end
function hooksecurefunc() end

local log = {{ id = 1, title = "Dwarven Digging", level = 8, complete = false, objs = { {text="0/5 Broken Tools", finished=false} } },
             { id = 2, title = "Mazzranache", level = 8, complete = false, objs = { {text="1/1 Prairie Wolf Heart", finished=true}, {text="0/1 Femur", finished=false} } },
             { id = 3, title = "Longwalker Malah", level = 9, complete = true, objs = {} } }
_G.mocklog = log
C_QuestLog = {
    GetNumQuestWatches = function() return #log end,
    GetQuestIDForQuestWatchIndex = function(i) return log[i].id end,
    GetLogIndexForQuestID = function(id) return id end,
    GetInfo = function(i) return { title = log[i].title, level = log[i].level, questID = i } end,
    IsComplete = function(id) return log[id].complete end,
    GetQuestObjectives = function(id) return log[id].objs end,
    GetTitleForQuestID = function(id) return log[id].title end,
    RemoveQuestWatch = function() end,
    SetSelectedQuest = function() end,
    GetNumQuestLogEntries = function() return #log end,
}
C_Map = { GetBestMapForUnit = function() return 1412 end,
          GetMapInfo = function(id) return { name = "Mulgore", mapType = 3, parentMapID = 12 } end }
-- map is 4000x3000 yards; player at (0.5,0.5); quest1 ~120y away, quest2 ~1200y, quest3 ~600y
C_Map.GetMapWorldSize = function(id) return 4000, 3000 end
C_Map.GetPlayerMapPosition = function(id, unit) return { GetXY = function() return 0.5, 0.5 end } end
C_QuestLog.GetQuestsOnMap = function(id) return { {questID = 1, x = 0.53, y = 0.5}, {questID = 2, x = 0.8, y = 0.5}, {questID = 3, x = 0.65, y = 0.5} } end
GetTime = function() return os.clock() + 100 end
GetZoneText = function() return "Mulgore" end
QuestWiseProbeDB = {}
GetQuestLogSpecialItemInfo = function(i) if i == 2 then return "|cff0070dd|Hitem:5555::::::::|h[Magic Stone]|h|r", "icon", 1, false end end
GetItemCount = function() return 3 end
C_Container = { GetItemCooldown = function() return 0, 0, 1 end }
_G.mockFocus = 0
C_SuperTrack = { GetSuperTrackedQuestID = function() return _G.mockFocus end,
                 SetSuperTrackedQuestID = function(id) _G.mockFocus = id end }
C_QuestLog.GetQuestsOnMap = function(id) return { {questID = 1, x = 0.58, y = 0.5}, {questID = 2, x = 0.51, y = 0.5}, {questID = 3, x = 0.65, y = 0.5} } end
GetQuestLogCompletionText =function(i) if i == 3 then return "Find Longwalker Malah near the edge." end return "" end
GetQuestLogQuestText = function(i) return "desc", "objective text" end

-- load files in TOC order with the shared namespace
local NA = {}
local function loadFile(path)
    local f = assert(io.open(path, "r")); local src = f:read("*a"); f:close()
    local chunk = assert(load(src, path))
    return chunk(ADDON_NAME, NA)
end
return { NA = NA, loadFile = loadFile, registered = registered, timers = timers }
'''
env = lua.execute(mock)
toc = open(os.path.join(root, ADDON_NAME + ".toc"), encoding="utf-8").read().splitlines()
files = [l.strip() for l in toc if l.strip() and not l.startswith("##") and not l.strip().startswith("Probe")]
for f in files:
    env.loadFile(root + "/" + f)

run = lua.eval(r'''
function(env)
    -- fire ADDON_LOADED then PLAYER_LOGIN through the frame registered by Init
    local init = env.registered["ADDON_LOADED"]
    init._s_OnEvent(init, "ADDON_LOADED", ADDON_NAME)
    local init2 = env.registered["PLAYER_LOGIN"]
    init2._s_OnEvent(init2, "PLAYER_LOGIN")
    -- run all queued timers (twice, in case timers queue timers)
    for round = 1, 3 do
        local t = env.timers
        env.timers = {}
        for _, fn in ipairs(t) do fn() end
    end
    local NA = env.NA
    local out = {}
    if not NA.Tracker.frame then
        return "NO FRAME. errors:\n" .. table.concat(NA.errors, "\n")
    end
    out[#out+1] = "ready=" .. tostring(NA.Tracker.ready) .. " refreshes=" .. tostring(NA.Tracker.refreshCount) .. " quests=" .. tostring(NA.Tracker.questCount)
    out[#out+1] = "blizzard hidden=" .. tostring(not ObjectiveTrackerFrame:IsShown())
    out[#out+1] = "tracker frame height=" .. tostring(NA.Tracker.frame:GetHeight())
    for i, b in ipairs(NA.Tracker.section.blocks) do
        out[#out+1] = "block " .. i .. " h=" .. tostring(b.height) .. " title=" .. tostring(b.title:GetText()) .. " lines=" .. tostring(#b.quest.lines)
    end
    out[#out+1] = "total=" .. tostring(NA.Tracker.totalCount) .. " visible=" .. tostring(NA.Tracker.questCount)
    for _, e in ipairs(QuestWiseProbeDB.zoneLog or {}) do for _, l in ipairs(e.quests) do out[#out+1] = "zonelog: " .. l end end
    for _, e in ipairs(QuestWiseProbeDB.distLog or {}) do for _, l in ipairs(e.quests) do out[#out+1] = "distlog(" .. e.limit .. "): " .. l end end
    -- gear button on the title opens/closes Options
    local ob = NA.Tracker.optionsButton
    ob:GetScript("OnEnter")(ob); ob:GetScript("OnLeave")(ob)
    ob:GetScript("OnMouseDown")(ob); ob:GetScript("OnMouseUp")(ob)
    ob:GetScript("OnClick")(ob)
    out[#out+1] = "gear click -> options shown=" .. tostring(NA.Options.frame ~= nil and NA.Options.frame:IsShown())
    ob:GetScript("OnClick")(ob)
    NA.Options.Open()
    if not NA.Options.frame then return "OPTIONS FAILED:\n" .. table.concat(NA.errors, "\n") end
    NA.Options.SelectPage("mobs")
    NA.Options.SelectPage("complete")
    NA.Options.SelectPage("quests")
    local oc = NA.Options.frame.pageFrames
    out[#out+1] = "options: frame=" .. tostring(NA.Options.frame ~= nil) .. " pages=" .. tostring(#NA.Options.order) .. " refreshers=" .. tostring(NA.Options.frame.refreshers.quests ~= nil and NA.Options.frame.refreshers.mobs ~= nil)
    NA.QuestMobMarker.TestSound()
    SlashCmdList["QUESTWISE"]()
    -- nameplate switch logic (cvars is the fake game setting)
    local function cv() return C_CVar.GetCVar("nameplateShowEnemies") end
    NA.db.markQuestMobs = true;  NA.db.showNameplates = false; NA.Nameplates.Apply(); local n1 = cv()  -- name only
    NA.db.markQuestMobs = false; NA.db.showNameplates = false; NA.Nameplates.Apply(); local n2 = cv()  -- neither
    NA.db.markQuestMobs = false; NA.db.showNameplates = true;  NA.Nameplates.Apply(); local n3 = cv()  -- bars only
    NA.db.markQuestMobs = true;  NA.db.showNameplates = false; NA.Nameplates.Apply()
    C_CVar.SetCVar("nameplateShowEnemies", "0"); NA.Nameplates.Check()                                   -- V pressed in name-only mode
    local n4 = tostring(NA.db.showNameplates) .. "/" .. cv()
    C_CVar.SetCVar("nameplateShowEnemies", "0"); NA.Nameplates.Check()                                   -- V pressed again
    local n5 = tostring(NA.db.showNameplates) .. "/" .. cv()
    NA.db.markQuestMobs = false; NA.db.showNameplates = true; NA.Nameplates.Apply()
    C_CVar.SetCVar("nameplateShowEnemies", "0"); NA.Nameplates.Check()                                   -- V with mark off
    local n6 = tostring(NA.db.showNameplates) .. "/" .. cv()
    out[#out+1] = "nameplates: nameOnly=" .. n1 .. " neither=" .. n2 .. " barsOnly=" .. n3 .. " V(nameOnly)=" .. n4 .. " V again=" .. n5 .. " V(markOff)=" .. n6
    -- nameplate range: asked 45 -> game uses 45; asked 100 -> the game caps it at 60 and we read the real value back
    NA.db.nameplateRange = 45; NA.Nameplates.Apply(); local r1 = NA.Nameplates.Range()
    NA.db.nameplateRange = 100; NA.Nameplates.Apply(); local r2 = NA.Nameplates.Range()
    out[#out+1] = "range: asked45->" .. tostring(r1) .. " asked100->" .. tostring(r2)
    -- marker on a fake plate in both modes
    local plate = CreateFrame("Frame", nil, UIParent); plate.UnitFrame = CreateFrame("Frame", nil, plate)
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    function UnitExists() return true end
    function UnitCanAttack() return true end
    function UnitIsPlayer() return false end
    function UnitIsDead() return false end
    function UnitName() return "Palemane Tanner" end
    function UnitSelectionColor() return 1, 0, 0 end
    C_QuestLog.UnitIsRelatedToActiveQuest = function() return true end
    local e0 = #NA.errors
    NA.db.markQuestMobs = true; NA.db.showNameplates = false; NA.QuestMobMarker.UpdateUnit("nameplate1")
    NA.db.showNameplates = true; NA.QuestMobMarker.UpdateUnit("nameplate1")
    NA.db.markQuestMobs = false; NA.QuestMobMarker.UpdateUnit("nameplate1")
    out[#out+1] = "marker modes: new errors=" .. (#NA.errors - e0)
    -- tapped by another player: mark yes, quest added no (unless the option is off)
    C_TooltipInfo = { GetUnit = function() return { lines = { { type = 17, leftText = "Tapped Quest" } } } end }
    Enum = Enum or {}; Enum.TooltipDataLineType = { QuestTitle = 17 }
    function UnitGUID() return "guid-1" end
    NA.db.markQuestMobs = true; NA.db.mobAddsQuest = true
    function UnitIsTapDenied() return true end
    NA.db.ignoreTapped = true;  NA.QuestMobMarker.UpdateUnit("nameplate1")
    local t1 = tostring(NA.QuestMobMarker.IsQuestNear("Tapped Quest"))
    NA.db.ignoreTapped = false; NA.QuestMobMarker.UpdateUnit("nameplate1")
    local t2 = tostring(NA.QuestMobMarker.IsQuestNear("Tapped Quest"))
    function UnitIsTapDenied() return false end
    out[#out+1] = "tapped: ignoreOn->near=" .. t1 .. " ignoreOff->near=" .. t2
    C_TooltipInfo = nil
    local Z, D = NA.Filters.list[1], NA.Filters.list[2]
    local s1 = tostring(NA.Filters.IsEnabled(Z)) .. "/" .. tostring(NA.Filters.IsEnabled(D))
    NA.Filters.SetEnabled(Z, true)
    local s2 = tostring(NA.Filters.IsEnabled(Z)) .. "/" .. tostring(NA.Filters.IsEnabled(D))
    NA.Filters.SetEnabled(D, true)
    local s3 = tostring(NA.Filters.IsEnabled(Z)) .. "/" .. tostring(NA.Filters.IsEnabled(D))
    NA.Filters.SetEnabled(D, false)
    local s4 = tostring(NA.Filters.IsEnabled(Z)) .. "/" .. tostring(NA.Filters.IsEnabled(D))
    NA.db.filters.zone = true; NA.db.filters.distance = true  -- both on in old saved settings
    NA.Filters.Apply({})
    local s5 = tostring(NA.Filters.IsEnabled(Z)) .. "/" .. tostring(NA.Filters.IsEnabled(D))
    NA.Filters.SetEnabled(D, true)
    out[#out+1] = "zone/dist: start=" .. s1 .. " zoneOn=" .. s2 .. " distOn=" .. s3 .. " distOff=" .. s4 .. " bothSaved->" .. s5
    -- quest-complete sound: nothing at first look, one sound when a quest turns complete, none again
    local before = soundCalls
    NA.Tracker.Refresh()
    local same = soundCalls - before
    mocklog[1].complete = true
    NA.Tracker.Refresh()
    local after = soundCalls - before
    NA.Tracker.Refresh()
    local again = soundCalls - before
    out[#out+1] = "complete sound: unchanged=" .. same .. " afterComplete=" .. after .. " afterAgain=" .. again
    local pg = {}
    for _, k in ipairs(NA.Options.order) do pg[#pg+1] = NA.Options.pages[k].label end
    out[#out+1] = "pages: " .. table.concat(pg, " | ")
    -- list layout: width, background, unlocked outline, saved position, scroll
    local Lay = NA.ListLayout
    NA.db.listWidth = 420; NA.db.listBackground = true; NA.db.listOpacity = 30; NA.db.listLocked = false
    Lay.ApplyLook(); NA.Tracker.Refresh()
    out[#out+1] = "layout: width=" .. NA.Tracker.frame:GetWidth() .. " headerW=" .. NA.Tracker.header:GetWidth() .. " blockW=" .. NA.Tracker.section.blocks[1].frame:GetWidth() .. " locked=" .. tostring(Lay.IsLocked())
    NA.db.listPos = { right = 900, top = 700 }; Lay.ApplyPosition(); Lay.ResetPosition()
    out[#out+1] = "position reset: " .. tostring(NA.db.listPos == nil)
    NA.db.listMaxHeight = 150; NA.db.listWidth = 100  -- out-of-range values are cut to the limits
    out[#out+1] = "limits: width=" .. Lay.Width() .. " maxHeight=" .. Lay.MaxHeight()
    NA.Options.SelectPage("interface")
    out[#out+1] = "interface page ok"
    Lay.ShowPreview(true); NA.db.listWidth = 300; NA.db.listMaxHeight = 150; Lay.UpdatePreview(); Lay.ShowPreview(false)
    out[#out+1] = "preview ok: " .. tostring(Lay.preview ~= nil)
    -- scale and text size: out-of-range values are cut, applying them works, window scale applies
    NA.db.listScale = 500; NA.db.listFontSize = 30
    out[#out+1] = "scale/font limits: scale=" .. Lay.Scale() .. " font=" .. Lay.FontSize()
    NA.db.listScale = 130; NA.db.listFontSize = 14; NA.db.optionsScale = 90
    Lay.ApplyScale(); NA.Options.ApplyScale(); NA.Tracker.Refresh()
    out[#out+1] = "scale applied: ok"
    out[#out+1] = "itemsShown=" .. tostring(NA.Tracker.itemsShown)
    local order = {}
    for i, b in ipairs(NA.Tracker.section.blocks) do if b.frame:IsShown() then order[#order+1] = b.quest.title end end
    out[#out+1] = "order: " .. table.concat(order, " > ")
    -- ready-to-turn-in quests: shown within the distance, always after the open ones, closest first
    NA.db.distanceYards = 1000; NA.db.sortByDistance = true
    NA.Tracker.Refresh()
    local order2 = {}
    for _, q in ipairs(NA.DistanceSort.Apply(NA.Filters.Apply(NA.Tracker.allQuests))) do
        order2[#order2+1] = q.title .. (q.isComplete and "(done)" or "")
    end
    out[#out+1] = "order 1000y: " .. table.concat(order2, " > ")
    -- auto focus: closest open quest; a quest focused by hand is kept; a cleared focus stays cleared
    -- (in the mock only quest 2 is still open; 1 and 3 are ready to turn in)
    NA.Tracker.Refresh(); local f1 = _G.mockFocus
    _G.mockFocus = 3; NA.Tracker.Refresh(); local f2 = _G.mockFocus   -- ready quest by hand: released
    _G.mockFocus = 0; NA.Tracker.Refresh(); local f3 = _G.mockFocus   -- cleared by hand: stays cleared
    NA.db.autoFocusNearest = false; _G.mockFocus = 3; NA.Tracker.Refresh(); local f4 = _G.mockFocus
    NA.db.autoFocusNearest = true
    out[#out+1] = "auto focus (want 2/2/0/3): " .. f1 .. "/" .. f2 .. "/" .. f3 .. "/" .. f4
    out[#out+1] = "errors=" .. tostring(#NA.errors)
    for _, e in ipairs(NA.errors) do out[#out+1] = e end
    -- click paths
    NA.Actions.OnClick(1, "LeftButton")
    NA.Actions.ShowTooltip(nil, NA.Tracker.section.blocks[1].quest)
    out[#out+1] = "click/tooltip ok"
    return table.concat(out, "\n")
end
''')
print(run(env))

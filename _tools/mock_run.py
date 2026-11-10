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
do local tn = tonumber
   tonumber = function(...) if select("#", ...) > 1 and select(2, ...) == nil then error("bad argument #2 to 'tonumber' (base out of range)") end return tn(...) end end
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

local log = {{ id = 1, title = "Dwarven Digging", level = 8, complete = false, objs = { {text="0/5 Broken Tools", finished=false, type="item", numFulfilled=0, numRequired=5} } },
             { id = 2, title = "Mazzranache", level = 8, complete = false, objs = { {text="1/1 Prairie Wolf Heart", finished=true, type="item"}, {text="Bristleback Quilboar slain: 3/8", finished=false, type="monster", numFulfilled=3, numRequired=8} } },
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
    -- dead: no scanning, no sound, no "near" quest; alive again: back to normal
    C_TooltipInfo = { GetUnit = function() return { lines = { { type = 17, leftText = "Ghost Quest" } } } end }
    NA.db.soundQuestMob = true
    UnitIsDeadOrGhost = function() return true end
    local sc0 = soundCalls; NA.QuestMobMarker.UpdateUnit("nameplate1")
    local d1 = tostring(NA.QuestMobMarker.IsQuestNear("Ghost Quest")) .. "/sound=" .. (soundCalls - sc0)
    UnitIsDeadOrGhost = function() return false end
    NA.QuestMobMarker.UpdateUnit("nameplate1")
    local d2 = tostring(NA.QuestMobMarker.IsQuestNear("Ghost Quest"))
    UnitIsDeadOrGhost = nil
    out[#out+1] = "mobs while dead (want false/sound=0 then true): " .. d1 .. " then " .. d2
    -- quiet: flying -> no near quest / sound; city -> also list folds and opens again when leaving
    local flying = true; UnitOnTaxi = function() return flying end
    sc0 = soundCalls; NA.QuestMobMarker.UpdateUnit("nameplate1")
    local qf = tostring(NA.QuestMobMarker.IsQuestNear("Ghost Quest")) .. "/sound=" .. (soundCalls - sc0)
    NA.db.quietFlying = false; local qf2 = tostring(NA.QuestMobMarker.IsQuestNear("Ghost Quest")); NA.db.quietFlying = true
    NA.db.collapsedAll = false; NA.Quiet.Check(); local qfl = tostring(NA.db.collapsedAll)
    flying = false; NA.Quiet.Check(); qfl = qfl .. "/" .. tostring(NA.db.collapsedAll)
    out[#out+1] = "list folds while flying (want true/false): " .. qfl
    local realBest = C_Map.GetBestMapForUnit
    NA.db.collapsedAll = false
    C_Map.GetBestMapForUnit = function() return 1454 end; NA.Quiet.Check()
    local qc1 = tostring(NA.db.collapsedAll) .. "/" .. tostring(NA.Quiet.Mobs())
    C_Map.GetBestMapForUnit = realBest; NA.Quiet.Check()
    local qc2 = tostring(NA.db.collapsedAll) .. "/" .. tostring(NA.Quiet.Mobs())
    C_Map.GetBestMapForUnit = function() return 1454 end; NA.Quiet.Check()
    NA.Tracker.header:GetScript("OnClick")(NA.Tracker.header)   -- opened by hand in the city
    NA.Tracker.header:GetScript("OnClick")(NA.Tracker.header)   -- and folded by hand again
    C_Map.GetBestMapForUnit = realBest; NA.Quiet.Check()
    local qc3 = tostring(NA.db.collapsedAll)
    NA.db.collapsedAll = false; UnitOnTaxi = nil; NA.Quiet.Check()
    out[#out+1] = "quiet flying (want false/sound=0, off->true): " .. qf .. ", " .. qf2
    out[#out+1] = "quiet city (want true/true, false/false, by hand stays true): " .. qc1 .. ", " .. qc2 .. ", " .. qc3
    -- mob mark look: colour by the mob's level (player 6), progress from the tooltip or the quest lines
    local mobLv = 9
    UnitLevel = function(u) if u == "player" then return 6 end return mobLv end
    local ML, QCc = NA.MobLook, NA.QuestColor
    local function mc() local c = ML.ColorFor("nameplate1"); for k, v in pairs(QCc.COLORS) do if v == c then return k end end; return tostring(c) end
    local m1 = mc(); mobLv = -1; local m2 = mc(); mobLv = 6; local m3 = mc()
    NA.db.mobColorsCustom = true; mobLv = 8; local m4 = mc(); NA.db.mobColorsCustom = false
    NA.db.mobColors = false; local m5 = mc(); NA.db.mobColors = true
    UnitLevel = function(u) if u == "player" then return 13 end return mobLv end
    mobLv = 10; local m6 = mc(); mobLv = 11; local m7 = mc(); mobLv = 7; local m8 = mc()
    UnitLevel = function(u) if u == "player" then return 6 end return mobLv end
    out[#out+1] = "mob colours me 13 (want 10=green, 11=yellow, 7=grey): " .. m6 .. "," .. m7 .. "," .. m8
    C_TooltipInfo = { GetUnit = function() return { lines = { { type = 17, leftText = "Tanner Quest" }, { type = 8, leftText = "Palemane Tanner slain: 2/7" } } } end }
    local e1 = #NA.errors; NA.QuestMobMarker.UpdateUnit("nameplate1")
    local p1 = ML.ProgressFor("nameplate1", { { title = "Tanner Quest", progress = "2/7" } }, { "Tanner Quest" })
    local p2 = ML.ProgressFor("nameplate1", {}, { "Mazzranache" })
    NA.db.mobProgress = false; local p3 = tostring(ML.ProgressFor("nameplate1", { { title = "Tanner Quest", progress = "2/7" } }, { "Tanner Quest" })); NA.db.mobProgress = true
    C_TooltipInfo = nil; UnitLevel = nil
    out[#out+1] = "mob colours (want orange,red,yellow,orange,nil): " .. m1 .. "," .. m2 .. "," .. m3 .. "," .. m4 .. "," .. m5 .. " errors=" .. (#NA.errors - e1)
    out[#out+1] = "mob progress (want 2/7, nil, nil): " .. tostring(p1) .. ", " .. tostring(p2) .. ", " .. p3
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
    -- old save (from the bottom-left) becomes "from the nearest corner"; screen 1920x1080 in this test
    UIParent.GetWidth = function() return 1920 end; UIParent.GetHeight = function() return 1080 end
    NA.db.listPos = { right = 1850, top = 680 }; Lay.ApplyPosition()
    local lp = NA.db.listPos
    local pos1 = tostring(lp.vert) .. lp.side .. " " .. lp.x .. "," .. lp.y
    local c2 = Lay.CornerPos(500, 200, 260)
    out[#out+1] = "position corners (want TOPRIGHT -70,-400 / BOTTOMLEFT 240,200): " .. pos1 .. " / " .. c2.vert .. c2.side .. " " .. c2.x .. "," .. c2.y
    Lay.events:GetScript("OnEvent")(Lay.events, "DISPLAY_SIZE_CHANGED")
    Lay.ResetPosition()
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
    _G.mockFocus = 3; NA.Tracker.Refresh(); NA.Tracker.Refresh(); local f2 = _G.mockFocus   -- ready quest by hand: kept
    _G.mockFocus = 0; NA.Tracker.Refresh(); local f3 = _G.mockFocus   -- cleared by hand: stays cleared
    NA.db.autoFocusNearest = false; _G.mockFocus = 3; NA.Tracker.Refresh(); local f4 = _G.mockFocus
    NA.db.autoFocusNearest = true
    -- arrow: points to the focused quest; hides when arrived / no focus
    GetPlayerFacing = function() return 0 end
    _G.mockFocus = 2; NA.Arrow.Update()
    local a1 = tostring(NA.Arrow.frame:IsShown()) .. " " .. tostring(NA.Arrow.dist:GetText())
    -- combat: hidden while fighting; back at once, or after the wait when "Wait after combat" is on
    local ce = NA.ArrowCombat.events
    local function sh() NA.Arrow.Update(); return tostring(NA.Arrow.frame:IsShown()) end
    ce:GetScript("OnEvent")(ce, "PLAYER_REGEN_DISABLED"); local k1 = sh()
    ce:GetScript("OnEvent")(ce, "PLAYER_REGEN_ENABLED"); local k2 = sh()
    NA.db.arrowCombatWait = true; NA.db.arrowCombatDelay = 30
    ce:GetScript("OnEvent")(ce, "PLAYER_REGEN_DISABLED"); ce:GetScript("OnEvent")(ce, "PLAYER_REGEN_ENABLED"); local k3 = sh()
    local ct = GetTime; GetTime = function() return ct() + 31 end; local k4 = sh(); GetTime = ct
    NA.db.arrowHideCombat = false; ce:GetScript("OnEvent")(ce, "PLAYER_REGEN_DISABLED"); local k5 = sh()
    ce:GetScript("OnEvent")(ce, "PLAYER_REGEN_ENABLED")
    NA.db.arrowHideCombat, NA.db.arrowCombatWait = true, false; GetTime = function() return ct() + 1000 end; sh(); GetTime = ct
    -- dead: not released = hidden; ghost = points to the corpse (map 4000x3000, corpse 0.5,0.55 = 150 yd south)
    local dead, ghost = false, false
    UnitIsDeadOrGhost = function() return dead or ghost end
    UnitIsGhost = function() return ghost end
    C_DeathInfo = { GetCorpseMapPosition = function() return { GetXY = function() return 0.5, 0.55 end } end }
    dead = true; local g1 = sh()
    dead, ghost = false, true; local g2 = sh() .. " " .. tostring(NA.Arrow.dist:GetText()) .. " " .. tostring(NA.Arrow.title:GetText())
    ghost = false; local g3 = sh() .. " " .. tostring(NA.Arrow.title:GetText())
    ghost = true; NA.db.arrowCorpse = false; local g4 = sh(); NA.db.arrowCorpse = true
    C_DeathInfo.GetCorpseMapPosition = function() return { GetXY = function() return 0.5, 0.515 end } end -- 45 yd
    local g5 = sh(); NA.db.arrowCorpseYards = 50; local g6 = sh(); NA.db.arrowCorpseYards = nil
    -- died in a fight with "Wait after combat" on: the corpse arrow shows at once
    C_DeathInfo.GetCorpseMapPosition = function() return { GetXY = function() return 0.5, 0.55 end } end
    NA.db.arrowCombatWait = true; ce:GetScript("OnEvent")(ce, "PLAYER_REGEN_DISABLED"); ce:GetScript("OnEvent")(ce, "PLAYER_REGEN_ENABLED")
    local g7 = sh(); NA.db.arrowCombatWait = false
    ghost = false; GetTime = function() return ct() + 2000 end; sh(); GetTime = ct
    out[#out+1] = "corpse right after combat with wait (want true): " .. g7
    -- quest area: player at 0.5,0.5 on a 4000x3000 map; quest 2's area = x 0.51..0.60 (40 yd east of you)
    local realCF = CreateFrame
    local areaFrom = 0.51
    CreateFrame = function(kind, ...)
        local f = realCF(kind, ...)
        if kind == "QuestPOIFrame" then
            f.DrawBlob = function() end
            f.UpdateMouseOverTooltip = function(_, x, y) if x >= areaFrom and x <= 0.60 then return 2, 1 end return nil end
        end
        return f
    end
    NA.QuestArea.Reset(true); _G.mockFocus = 2
    NA.db.arrowAreaYards = 0; local ar1 = sh()                -- outside, no margin: arrow shows
    NA.db.arrowAreaYards = 60; NA.QuestArea.Reset(); local ar2 = sh()   -- 40 yd from the area, margin 60: hidden
    areaFrom = 0.53; NA.QuestArea.Reset(); local ar3 = sh()    -- area now 120 yd away: back at once
    areaFrom = 0.40; NA.QuestArea.Reset(); local ar4 = sh()    -- inside: hidden
    NA.db.arrowUseArea = false; areaFrom = 0.53; NA.QuestArea.Reset(); local ar5 = sh(); NA.db.arrowUseArea = nil
    CreateFrame = realCF; NA.QuestArea.Reset(true); NA.db.arrowAreaYards = nil
    out[#out+1] = "arrow area (want true/false/true/false, off->false: arrival kept, old rules): " .. ar1 .. "/" .. ar2 .. "/" .. ar3 .. "/" .. ar4 .. ", " .. ar5
    out[#out+1] = "arrow dead (want false / true 150 yd Your corpse / true Mazzranache): " .. g1 .. " / " .. g2 .. " / " .. g3
    out[#out+1] = "corpse options (want off=false / 45yd,hide30=true / hide50=false): " .. g4 .. " / " .. g5 .. " / " .. g6
    out[#out+1] = "arrow combat (want false/true/false/true/true): " .. k1 .. "/" .. k2 .. "/" .. k3 .. "/" .. k4 .. "/" .. k5
    -- quest colours by difficulty (player level 6 in this test)
    UnitLevel = function() return 6 end
    local QC = NA.QuestColor
    local function cname(c) for k, v in pairs(QC.COLORS) do if v == c then return k end end return c == QC.GOLD and "gold" or "?" end
    local function col(lv, done) return cname(QC.For({ level = lv, isComplete = done })) end
    local q1 = col(12) .. "," .. col(9) .. "," .. col(6) .. "," .. col(3) .. "," .. col(1) .. "," .. col(12, true)
    NA.db.questColorsCustom = true; NA.db.questColorRed = 2; NA.db.questColorGrey = 4
    local q2 = col(8) .. "," .. col(7) .. "," .. col(4) .. "," .. col(3) .. "," .. col(2)
    NA.db.questColorsCustom, NA.db.questColorRed, NA.db.questColorGrey = false, 5, 8
    NA.db.questColors = false; local q3 = col(12); NA.db.questColors = true
    NA.Tracker.Refresh()
    out[#out+1] = "quest colours game (want red,orange,yellow,green,grey,gold): " .. q1
    out[#out+1] = "quest colours custom red+2 grey-4 (want red,yellow,yellow,green,grey): " .. q2
    out[#out+1] = "quest colours off (want gold): " .. q3
    _G.mockFocus = 0; NA.Arrow.Update()
    local a2 = tostring(NA.Arrow.frame:IsShown())
    NA.db.arrowLocked = false; NA.Arrow.ApplyLook(); local a3 = tostring(NA.Arrow.frame:IsShown())
    NA.db.arrowLocked = true; NA.Arrow.ApplyLook(); _G.mockFocus = 3
    NA.Arrow.driver:GetScript("OnUpdate")(nil, 1)
    for _, st in ipairs(NA.Arrow.STYLES) do for _, c in ipairs(NA.Arrow.COLORS) do
        NA.db.arrowStyle, NA.db.arrowColor = st.key, c.key; NA.Arrow.ApplyStyle() end end
    NA.db.arrowSize = 500; out[#out+1] = "arrow styles ok, size limit=" .. NA.Arrow.Size()
    NA.db.arrowSize, NA.db.arrowStyle, NA.db.arrowColor = nil, nil, nil; NA.Arrow.ApplyStyle()
    -- progress = arrived: hidden although far away; comes back only far + after the wait
    _G.mockFocus = 2; NA.Arrow.Update(); local p1 = tostring(NA.Arrow.frame:IsShown())
    NA.Arrow.Activity(2, "test"); NA.Arrow.Update(); local p2 = tostring(NA.Arrow.frame:IsShown())
    NA.db.arrowReturnYards = 30; NA.db.arrowArriveYards = 10; NA.db.arrowWaitSeconds = 0 -- quest 2 is 40 yd away
    local t0 = GetTime; GetTime = function() return t0() + 1000 end
    NA.Arrow.Update(); local p3 = tostring(NA.Arrow.frame:IsShown()); GetTime = t0
    NA.db.arrowReturnYards, NA.db.arrowArriveYards, NA.db.arrowWaitSeconds = nil, nil, nil
    NA.Arrow.CheckProgress(); NA.Arrow.CheckProgress()
    out[#out+1] = "arrow progress (want true/false/true): " .. p1 .. "/" .. p2 .. "/" .. p3
    -- quest gets done while "arrived": the arrow must guide again (to the turn-in)
    _G.mockFocus = 2; NA.Arrow.CheckProgress(); NA.Arrow.Activity(2, "test"); NA.Arrow.Update()
    local c1 = tostring(NA.Arrow.frame:IsShown())
    _G.mocklog[2].complete = true; NA.Arrow.CheckProgress(); NA.Arrow.Update()
    local c2 = tostring(NA.Arrow.frame:IsShown()); _G.mocklog[2].complete = false
    out[#out+1] = "arrow after quest done (want false/true): " .. c1 .. "/" .. c2
    out[#out+1] = "arrow (want shown/hidden/unlocked shown): " .. a1 .. " / " .. a2 .. " / " .. a3
    -- beyond the distance limit: still focuses the closest open quest (list may hide it)
    NA.db.distanceYards = 100; _G.mockFocus = 0; NA.Tracker.Refresh(); NA.Tracker.Refresh()
    local f5 = _G.mockFocus; NA.db.distanceYards = 1000
    -- turn-ins count too: ready quest 1 moved to ~20 yd, open quest 2 at ~40 yd
    local oldMap = C_QuestLog.GetQuestsOnMap
    -- the map info is cached per GetTime(): make the fake clock always move on (os.clock may not)
    local tick = 5000; GetTime = function() tick = tick + 0.01; return tick end
    C_QuestLog.GetQuestsOnMap = function() return { {questID = 1, x = 0.505, y = 0.5}, {questID = 2, x = 0.51, y = 0.5}, {questID = 3, x = 0.65, y = 0.5} } end
    local function fresh() NA.db.autoFocusNearest = false; NA.Tracker.Refresh(); NA.db.autoFocusNearest = true; _G.mockFocus = 0; NA.Tracker.Refresh() end
    NA.db.autoFocusTurnIns = false; fresh(); local f6 = _G.mockFocus
    NA.db.autoFocusTurnIns = true; fresh(); local f7 = _G.mockFocus
    NA.db.autoFocusTurnIns = false; C_QuestLog.GetQuestsOnMap = oldMap; fresh()
    out[#out+1] = "turn-ins (want 2 then 1): " .. tostring(f6) .. " then " .. tostring(f7)
    out[#out+1] = "auto focus (want 2/3/0/3): " .. f1 .. "/" .. f2 .. "/" .. f3 .. "/" .. f4 .. " | beyond limit (want 2 or 0-cleared): " .. f5
    -- quick buttons on the title: arrow / distance / zone
    local HT = NA.HeaderToggles
    local function st() local z, d
        for _, f in ipairs(NA.Filters.list) do if f.id == "zone" then z = NA.Filters.IsEnabled(f) elseif f.id == "distance" then d = NA.Filters.IsEnabled(f) end end
        return string.format("arrow=%s dist=%s zone=%s", tostring(NA.Arrow.IsOn()), tostring(d), tostring(z)) end
    local hb = {}; for _, b in ipairs(HT.buttons) do hb[b.def.key] = b; b:GetScript("OnEnter")(b); b:GetScript("OnLeave")(b) end
    local h0 = st()
    hb.arrow:GetScript("OnClick")(hb.arrow); local h1 = st()
    hb.zone:GetScript("OnClick")(hb.zone); local h2 = st()
    hb.distance:GetScript("OnClick")(hb.distance); local h3 = st()
    hb.distance:GetScript("OnClick")(hb.distance); local h4 = st()
    hb.arrow:GetScript("OnClick")(hb.arrow); local h5 = st()
    local dg0 = tostring(NA.Filters.IsEnabled(NA.DungeonFilter))
    hb.dungeon:GetScript("OnClick")(hb.dungeon); local dgb1 = tostring(NA.Filters.IsEnabled(NA.DungeonFilter))
    hb.dungeon:GetScript("OnClick")(hb.dungeon); local dgb2 = tostring(NA.Filters.IsEnabled(NA.DungeonFilter))
    out[#out+1] = "dungeon button (want true/false/true): " .. dg0 .. "/" .. dgb1 .. "/" .. dgb2
    out[#out+1] = "header buttons: " .. #HT.buttons .. " | start " .. h0 .. " | arrow " .. h1 .. " | zone " .. h2 .. " | dist " .. h3 .. " | dist " .. h4 .. " | arrow " .. h5
    -- info box on mouse-over: print what it says for each quest
    local cap = {}
    local tt = GameTooltip
    local oA, oD = tt.AddLine, tt.AddDoubleLine
    tt.AddLine = function(_, t) cap[#cap+1] = "    " .. tostring(t) end
    tt.AddDoubleLine = function(_, l, r) cap[#cap+1] = "    " .. tostring(l) .. "   [" .. tostring(r) .. "]" end
    for _, b in ipairs(NA.Tracker.section.blocks) do
        if b.quest then cap[#cap+1] = "  --- box:"; NA.Actions.ShowTooltip(b.titleBtn, b.quest) end
    end
    tt.AddLine, tt.AddDoubleLine = oA, oD
    out[#out+1] = "quest info box:" .. string.char(10) .. table.concat(cap, string.char(10))
    -- quest object tooltip: "7/8" read from its lines; a mob (unit) or our own buttons don't count
    local lines = { "Smooth Boulder", "Rocks to Rests", " - Smooth Boulder: 7/8" }
    local ft = { NumLines = function() return #lines end, GetName = function() return "FakeTip" end,
                 IsShown = function() return true end, GetUnit = function() return nil end, GetItem = function() return nil end,
                 GetOwner = function() return UIParent end }
    for i = 1, 3 do _G["FakeTipTextLeft" .. i] = { GetText = function() return lines[i] end } end
    GetCursorPosition = function() return 500, 400 end
    local op1 = tostring(NA.ObjectProgress.ReadProgress(ft))
    NA.ObjectProgress.Refresh(ft)
    lines[3] = " - Smooth Boulder: 8/8"; local op2, op2d = NA.ObjectProgress.ReadProgress(ft)
    ft.GetOwner = function() return NA.Tracker.header end; NA.ObjectProgress.Refresh(ft)
    -- dungeon filter: quest 2 marked as a dungeon quest by the game
    C_QuestLog.GetQuestTagInfo = function(id) if id == 2 then return { tagID = 81, tagName = "Dungeon" } end return nil end
    local function shows2()
        for _, q in ipairs(NA.Filters.Apply(NA.Tracker.allQuests)) do if q.questID == 2 then return "shown" end end
        return "hidden"
    end
    local dg1 = shows2() .. "/" .. tostring(NA.DungeonFilter.Hides(2))
    IsInInstance = function() return true, "party" end; local dg2 = shows2(); IsInInstance = nil
    NA.Filters.SetEnabled(NA.DungeonFilter, false); local dg3 = shows2(); NA.Filters.SetEnabled(NA.DungeonFilter, true)
    C_QuestLog.GetQuestTagInfo = nil
    -- focused by hand: first in the list, even when a filter hides it
    local function firstID() return NA.Tracker.section.blocks[1] and NA.Tracker.section.blocks[1].questID end
    NA.db.collapsedAll = false
    _G.mockFocus = 1; NA.Tracker.Refresh(); NA.Tracker.Refresh(); local ff1 = tostring(firstID())
    C_QuestLog.GetQuestTagInfo = function(id) if id == 1 then return { tagID = 81 } end return nil end
    NA.Tracker.Refresh(); local ff2 = tostring(firstID()) .. "/" .. tostring(NA.Tracker.questCount)
    NA.db.focusedFirst = false; NA.Tracker.Refresh(); local ff3 = tostring(firstID()); NA.db.focusedFirst = nil
    C_QuestLog.GetQuestTagInfo = function(id) if id == 2 then return { tagID = 81, tagName = "Dungeon" } end return nil end
    out[#out+1] = "focused first (want 1, 1 even as dungeon, off->not 1): " .. ff1 .. ", " .. ff2 .. ", " .. ff3
    -- a focus of yours while the distances are unknown is still yours (was missed - user report)
    local realGet = NA.MapInfo.Get
    NA.MapInfo.Get = function() return { ok = false } end
    _G.mockFocus = 3; NA.Tracker.Refresh()
    local mf = tostring(NA.AutoFocus.ManualID()) .. "/" .. tostring(firstID())
    NA.MapInfo.Get = realGet; NA.Tracker.Refresh()
    mf = mf .. "/" .. tostring(NA.AutoFocus.ManualID())
    out[#out+1] = "manual focus with no distances (want 3/3/3): " .. mf
    -- inside a dungeon: only its quests even with the skull off (user report); option off = filters as usual
    local all = NA.Tracker.allQuests
    local dz = "Ragefire Chasm"
    local oldZ1, oldZ2 = all[1].zone, all[2].zone
    all[1].zone, all[2].zone = dz, dz
    local nIn = 2
    IsInInstance = function() return true, "party" end
    GetInstanceInfo = function() return dz end
    NA.Filters.SetEnabled(NA.DungeonFilter, false)
    local v1 = NA.Filters.Apply(all); local n1 = #v1 .. "/" .. tostring(NA.Filters.narrowed)
    NA.db.dungeonOnlyInside = false
    local v2 = NA.Filters.Apply(all); local n2 = tostring(NA.Filters.narrowed)
    NA.db.dungeonOnlyInside = nil; NA.Filters.SetEnabled(NA.DungeonFilter, true)
    IsInInstance = nil; GetInstanceInfo = nil; all[1].zone, all[2].zone = oldZ1, oldZ2
    out[#out+1] = "dungeon only inside, skull off (want " .. nIn .. "/true, off->false): " .. n1 .. ", " .. n2
    out[#out+1] = "dungeon filter (want hidden/true, inside shown, off shown): " .. dg1 .. ", " .. dg2 .. ", " .. dg3
    -- a mob's tooltip refilled without its unit (seen in game) must not show the label
    local realUE = UnitExists; UnitExists = function() return false end
    ft.GetOwner = function() return UIParent end; lines[1] = "Sunscale Lashtail"; lines[3] = " - Sunscale Lashtail slain: 3/8"
    ft.GetUnit = function() return "Sunscale Lashtail" end; NA.ObjectProgress.Refresh(ft)
    ft.GetUnit = function() return nil end; NA.ObjectProgress.Refresh(ft); local op3 = tostring(NA.ObjectProgress.IsLabelShown())
    lines[1] = "Smooth Boulder"; lines[3] = " - Smooth Boulder: 7/8"
    GameTooltip:GetScript("OnHide") -- (no real hide in the mock)
    UnitExists = realUE
    out[#out+1] = "object label after a mob tooltip (want false): " .. op3
    out[#out+1] = "object progress (want 7/8, 8/8 done=true): " .. op1 .. ", " .. tostring(op2) .. " done=" .. tostring(op2d)
    -- quest details window ("i" button), rewards, mouse-over box off
    GetNumQuestLogChoices = function() return 2 end
    GetQuestLogChoiceInfo = function(i) return "Choice " .. i, "icon" .. i, 1, 3, true end
    GetNumQuestLogRewards = function() return 1 end
    GetQuestLogRewardInfo = function(i) return "Reward", "iconR", 5, 1, true end
    GetQuestLogRewardMoney = function() return 12345 end
    GetQuestLogRewardXP = function() return 850 end
    GetQuestLogItemLink = function(k, i) return "|Hitem:1|h[" .. k .. i .. "]|h" end
    local selected = {}
    SelectQuestLogEntry = function(i) selected[#selected + 1] = i end
    GetQuestLogSelection = function() return 7 end
    NA.Tracker.Refresh()
    local QIW = NA.QuestInfoWindow
    local b1 = NA.Tracker.section.blocks[1]
    b1.info:GetScript("OnClick")(b1.info)
    local w1 = tostring(QIW.ShownID() == b1.questID)
    QIW.Refresh()
    local wt = {}
    for _, fs in ipairs(QIW.pools.heads) do if fs.fs:IsShown() then wt[#wt+1] = "#" .. fs.fs:GetText() end end
    for i = 1, QIW.pools.texts.used do wt[#wt+1] = QIW.pools.texts[i]:GetText() end
    for i = 1, QIW.pools.tiles.used do wt[#wt+1] = "[" .. QIW.pools.tiles[i].name:GetText() .. "]" end
    out[#out+1] = "details window: " .. table.concat(wt, " | ")
    local sz1 = QuestWiseInfoWindow:GetWidth() .. "x" .. QuestWiseInfoWindow:GetHeight()
    NA.db.questInfoWidth = 9999; NA.db.questInfoHeight = 300; QIW.Refresh()
    local sz2 = QuestWiseInfoWindow:GetWidth() .. "x" .. QuestWiseInfoWindow:GetHeight()
    NA.db.questInfoWidth, NA.db.questInfoHeight = nil, nil; QIW.Refresh()
    out[#out+1] = "details window size (want 360x480, 560x300): " .. sz1 .. ", " .. sz2
    out[#out+1] = "quest log selection put back (want ..,7): " .. table.concat(selected, ",")
    b1.info:GetScript("OnClick")(b1.info); local w2 = tostring(QIW.ShownID())
    local b2 = NA.Tracker.section.blocks[2]
    b1.info:GetScript("OnClick")(b1.info); b2.info:GetScript("OnClick")(b2.info)
    local w3 = tostring(QIW.ShownID() == b2.questID)
    NA.db.questInfoRewards = false; QIW.Refresh(); local w4 = tostring(QIW.pools.tiles.used); NA.db.questInfoRewards = true
    NA.db.questInfoScale = 500; NA.db.questInfoBackground = false; QIW.ApplyLook(); NA.db.questInfoScale = nil; NA.db.questInfoBackground = nil
    NA.db.questInfoButton = false; NA.Tracker.Refresh(); local w5 = tostring(b1.info:IsShown()); NA.db.questInfoButton = true; NA.Tracker.Refresh()
    b1.info:GetScript("OnClick")(b1.info); NA.db.questInfoEnabled = false; NA.Tracker.Refresh()
    local en1 = tostring(b1.info:IsShown()) .. "/" .. tostring(NA.QuestInfo.HoverOn()); NA.db.questInfoEnabled = nil; NA.Tracker.Refresh()
    out[#out+1] = "quest info disabled (want false/false): " .. en1
    QIW.Hide()
    out[#out+1] = "details window (want true/nil/true/0/false): " .. w1 .. "/" .. w2 .. "/" .. w3 .. "/" .. w4 .. "/" .. w5
    local shown = 0; local oShow = GameTooltip.Show; GameTooltip.Show = function() shown = shown + 1 end
    NA.db.questInfoHover = false; NA.Actions.ShowTooltip(b1.titleBtn, b1.quest); local hv1 = shown
    NA.db.questInfoHover = true; NA.Actions.ShowTooltip(b1.titleBtn, b1.quest); local hv2 = shown
    GameTooltip.Show = oShow
    out[#out+1] = "mouse-over box (want 0 then 1): " .. hv1 .. " then " .. hv2
    -- the game's quest area on the world map, painted in our colour
    local paints, drawn = {}, {}
    local pin = { SetFillTexture = function(_, p) paints[#paints+1] = p:match("[^%c]-([%w%-]+)$") end,
                  DrawBlob = function(_, id) drawn[#drawn+1] = id end }
    WorldMapFrame = CreateFrame("Frame")
    WorldMapFrame.EnumeratePinsByTemplate = function() local done = false; return function() if not done then done = true; return pin end end end
    _G.mockFocus = 2; NA.MapArea.Update(); NA.MapArea.Update()
    NA.db.mapAreaColor = "Red"; NA.MapArea.Apply()
    local fa, sc = {}, {}
    pin.SetFillAlpha = function(_, v) fa[#fa+1] = v end
    pin.SetBorderScalar = function(_, v) sc[#sc+1] = string.format("%.2f", v) end
    NA.db.mapAreaOutline = true; NA.db.mapAreaThickness = 1; NA.MapArea.Update()
    NA.db.mapAreaThickness = 99; NA.MapArea.Update(); NA.db.mapAreaOutline = nil; NA.db.mapAreaThickness = nil
    out[#out+1] = "outline only (want fill 0,0 / thickness 0.04,0.20): " .. table.concat(fa, ",") .. " / " .. table.concat(sc, ",")
    pin.SetFillAlpha, pin.SetBorderScalar = nil, nil
    NA.db.mapArea = false; NA.MapArea.Apply(); NA.MapArea.Apply()
    NA.db.mapArea = nil; NA.db.mapAreaColor = nil; WorldMapFrame = nil
    out[#out+1] = "map area paints (want UI-StatusBar, REDGRAD64, UI-QuestBlob-Inside): " .. table.concat(paints, ", ") .. " | drawn " .. table.concat(drawn, ",")
    -- options pages build
    NA.Options.Open(); NA.Options.SelectPage("questinfo"); NA.Options.SelectPage("map"); NA.Options.frame:Hide()
    -- minimap areas (UI/MinimapArea.lua): our inside colour, the game's back when off
    local mmPics = {}
    Minimap = { SetQuestBlobInsideTexture = function(_, f) mmPics[#mmPics+1] = (f:match("[^\\]+$")) end }
    NA.db.mapAreaColor = "Red"; NA.MinimapArea.Update(true)
    NA.db.mapMinimap = false; NA.MinimapArea.Update(); NA.MinimapArea.Update()
    NA.db.mapMinimap = nil; NA.db.mapAreaColor = nil; Minimap = nil
    out[#out+1] = "minimap area (want REDGRAD64, UI-QuestBlob-Inside): " .. table.concat(mmPics, ", ")
    -- look presets (UI/Theme.lua): every preset with the options window, list background and details window shown
    local te = #NA.errors
    NA.Options.Open(); NA.Options.SelectPage("interface")
    NA.db.listBackground = true
    NA.QuestInfoWindow.Show(NA.Tracker.section.blocks[1].quest)
    local golds = {}
    for _, p in ipairs(NA.Theme.PRESETS) do
        NA.Theme.Set(p.key)
        golds[#golds+1] = p.key .. "=" .. string.format("%.2f", NA.Widgets.colors.gold[1])
    end
    NA.Theme.Set("Nope"); NA.Theme.Set("QuestWise")
    golds[#golds+1] = "back=" .. string.format("%.2f", NA.Widgets.colors.gold[1]) .. "/" .. NA.db.theme
    NA.QuestInfoWindow.Hide(); NA.db.listBackground = false; NA.ListLayout.ApplyLook(); NA.Options.frame:Hide()
    out[#out+1] = "look presets (want QuestWise=1.00 GearQuest=0.90 Midnight=0.81 Forest=0.85 Game=1.00 back=1.00/QuestWise): "
        .. table.concat(golds, " ") .. " new errors=" .. (#NA.errors - te)
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

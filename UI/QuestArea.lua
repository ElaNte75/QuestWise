-- UI: is the player inside (or near) the blue area the game draws for a quest on the map?
-- The game gives add-ons only the middle of a quest's area, not its shape. But the same kind of
-- frame the world map uses for those blue areas can be asked "which quest area is at this point"
-- (tested in game: inside -> the quest, outside -> nothing). We keep one hidden such frame, draw the
-- focused quest's area on it and ask it at your spot, and at points around you for "near it".
-- Used by UI/Arrow.lua. Settings: arrowUseArea (on), arrowAreaYards (40, 0..100 = "near" margin).
local ADDON, NA = ...

local QA = {}
NA.QuestArea = QA

QA.MIN_YARDS, QA.MAX_YARDS, QA.DEFAULT_YARDS = 0, 100, 40
local CACHE = 0.5 -- seconds an answer is kept (the arrow asks 20 times a second)

function QA.IsOn() return NA.db.arrowUseArea ~= false end
function QA.Yards()
    local v = tonumber(NA.db.arrowAreaYards) or QA.DEFAULT_YARDS
    return math.min(math.max(v, QA.MIN_YARDS), QA.MAX_YARDS)
end

local blob          -- the hidden area frame (nil = not made yet, false = this game can't)
local drawn = {}    -- what is drawn on it now: { quest, map }
local cache = {}    -- [questID] = { time, answer }

local function getBlob()
    if blob ~= nil then return blob or nil end
    local ok, f = pcall(CreateFrame, "QuestPOIFrame", nil, UIParent)
    if not ok or not f or not f.DrawBlob or not f.UpdateMouseOverTooltip then
        blob = false
        return nil
    end
    f:SetSize(1000, 1000)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetAlpha(0)
    if f.EnableMouse then pcall(f.EnableMouse, f, false) end
    f:Show()
    blob = f
    return f
end

local function areaAt(f, questID, x, y)
    if x < 0 or x > 1 or y < 0 or y > 1 then return false end
    local ok, q = pcall(f.UpdateMouseOverTooltip, f, x, y)
    return ok and q == questID
end

local function ask(questID)
    local f = getBlob()
    if not f then return nil end
    local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local M = NA.MapInfo
    local px, py = M.PlayerPos(mapID)
    if not px then return nil end
    if drawn.quest ~= questID or drawn.map ~= mapID then
        if f.SetMapID then pcall(f.SetMapID, f, mapID) end
        if f.DrawNone then pcall(f.DrawNone, f) end
        pcall(f.DrawBlob, f, questID, true)
        drawn.quest, drawn.map = questID, mapID
    end
    if areaAt(f, questID, px, py) then return true end
    -- near it: any of 16 points around you (at the margin and half of it) inside the area
    local yards = QA.Yards()
    local w, h = M.WorldSize(mapID)
    if yards <= 0 or not w then return false end
    for _, r in ipairs({ yards / 2, yards }) do
        for i = 0, 7 do
            local a = i * math.pi / 4
            if areaAt(f, questID, px + math.cos(a) * r / w, py + math.sin(a) * r / h) then return true end
        end
    end
    return false
end

-- true = you are in the quest's area or within arrowAreaYards of it; false = not (or the quest has
-- no area here); nil = the game can't tell (option off, no map, no area frame)
function QA.Near(questID)
    if not (questID and QA.IsOn()) then return nil end
    local now = GetTime()
    local c = cache[questID]
    if c and now - c.time < CACHE then return c.answer end
    local ok, answer = pcall(ask, questID)
    if not ok then answer = nil end
    cache[questID] = { time = now, answer = answer }
    return answer
end

-- quest log / map changed: draw again next time (frame = true: also make the area frame again)
function QA.Reset(frame)
    drawn = {}
    cache = {}
    if frame == true then blob = nil end
end

NA.OnInit(function()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", QA.Reset)
    QA.events = ev
end)

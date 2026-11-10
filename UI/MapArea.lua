-- UI: on the world map, the focused quest's area in another colour instead of the game's blue.
-- We paint the game's OWN area (its quest-area pins on the map), so it follows the map when you zoom
-- or move it, exactly like the game's.
-- Found by testing in game: that area takes ONLY the game's own pictures. Pictures from our add-on
-- folder (tga or blp) show up plain green, even after a full restart. So the colours below are
-- pictures the game already has, each tried in game. A new colour shows after a /reload.
-- (A first try drew a second area of our own on top: it did not follow the zoom - seen in game.)
-- Settings: mapArea (on), mapAreaColor ("SoftWhite"), mapAreaOpacity (45, 10..100),
-- mapAreaOutline (off = filled; on = only the line around the area), mapAreaThickness (2, 1..5),
-- mapHideOthers (on = only the focused quest's area; the others hidden - tried in game, works).
local ADDON, NA = ...

local MA = {}
NA.MapArea = MA

-- fill = picture inside the area, border = picture of its edge (the same when the game has no edge one)
MA.COLORS = {
    { key = "SoftWhite", label = "Soft white", fill = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "White", label = "White", fill = "Interface\\Buttons\\WHITE8X8" },
    { key = "Grey", label = "Grey", fill = "Interface\\QuestFrame\\UI-QuestTitleHighlight" },
    { key = "Orange", label = "Orange", fill = "Interface\\WorldMap\\UI-ArchaeologyBlob-Inside",
        border = "Interface\\WorldMap\\UI-ArchaeologyBlob-Outside" },
    { key = "Amber", label = "Amber", fill = "Interface\\Buttons\\YELLOWORANGE64" },
    { key = "Red", label = "Red", fill = "Interface\\Buttons\\REDGRAD64" },
    -- the game's own blue pictures (with your opacity / outline / thickness)
    { key = "Game", label = "Game default", fill = "Interface\\WorldMap\\UI-QuestBlob-Inside",
        border = "Interface\\WorldMap\\UI-QuestBlob-Outside" },
    { key = "Blue", label = "Blue", fill = "Interface\\Buttons\\BLUEGRAD64" },
}
local DEFAULT_COLOR = "SoftWhite"
MA.MIN_OPACITY, MA.MAX_OPACITY = 10, 100
local TICK = 0.25
-- how thick the edge of the area is: thickness 1..10 x this (game scale 1.0 and 0.3 were far too
-- thick in game; the default 2 = 0.08)
local SCALAR_STEP = 0.04
MA.MIN_THICK, MA.MAX_THICK, MA.DEFAULT_THICK = 1, 5, 2
local PIN_TEMPLATE = "QuestBlobPinTemplate"
-- the game's own look, put back when our colour is turned off
local GAME = { fill = "Interface\\WorldMap\\UI-QuestBlob-Inside", border = "Interface\\WorldMap\\UI-QuestBlob-Outside",
    fillAlpha = 128, borderAlpha = 192, scalar = 1.0 }

local painted = setmetatable({}, { __mode = "k" }) -- [pin] = the look we gave it ("Gold45")

function MA.IsOn() return NA.db.mapArea ~= false end
function MA.Opacity()
    local v = tonumber(NA.db.mapAreaOpacity) or 45
    return math.min(math.max(v, MA.MIN_OPACITY), MA.MAX_OPACITY)
end
function MA.OutlineOnly() return NA.db.mapAreaOutline == true end
function MA.HideOthers() return NA.db.mapHideOthers ~= false end
function MA.Thickness()
    local v = tonumber(NA.db.mapAreaThickness) or MA.DEFAULT_THICK
    return math.min(math.max(math.floor(v + 0.5), MA.MIN_THICK), MA.MAX_THICK)
end
function MA.Color()
    local c = NA.db.mapAreaColor
    for _, x in ipairs(MA.COLORS) do if x.key == c then return c end end
    return DEFAULT_COLOR
end

-- kind = "Fill" or "Border"
function MA.TexPath(kind)
    local key = MA.Color()
    for _, x in ipairs(MA.COLORS) do
        if x.key == key then return kind == "Border" and x.border or x.fill end
    end
end

local function call(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, obj, ...)
    return ok and a or nil
end

-- the game's quest areas on the map (its pins)
local function eachGamePin(fn)
    local map = WorldMapFrame
    if not (map and map.EnumeratePinsByTemplate) then return end
    local ok, iter = pcall(map.EnumeratePinsByTemplate, map, PIN_TEMPLATE)
    if not ok or not iter then return end
    for pin in iter do fn(pin) end
end

local function paint(pin, fill, border, fillAlpha, borderAlpha, scalar)
    call(pin, "SetFillTexture", fill)
    call(pin, "SetBorderTexture", border)
    call(pin, "SetFillAlpha", fillAlpha)
    call(pin, "SetBorderAlpha", borderAlpha)
    call(pin, "SetBorderScalar", scalar)
end

local function focusID()
    return NA.Actions and NA.Actions.GetFocusedQuestID() or nil
end

-- paints the game's areas in our colour (or gives them back their blue). force = paint again even
-- if a pin already has this look (after a colour change).
function MA.Update(force)
    local map = WorldMapFrame
    if not (map and map:IsShown()) then return end
    local on = MA.IsOn()
    local outline = MA.OutlineOnly()
    local look = on and (MA.Color() .. MA.Opacity() .. tostring(outline) .. MA.Thickness()) or nil
    -- only the focused quest's area: the game draws the others too, so clear and draw ours on every check
    local qidNow = focusID()
    local hideNow = on and MA.HideOthers() and qidNow
    eachGamePin(function(pin)
        if painted[pin] == look and not force then return end
        if look then
            local a = math.floor(MA.Opacity() / 100 * 255 + 0.5)
            -- outline only = nothing inside, just the line around the area
            paint(pin, MA.TexPath("Fill"), MA.TexPath("Border"), outline and 0 or a,
                outline and math.min(255, a + 80) or math.min(255, a + 40), MA.Thickness() * SCALAR_STEP)
        elseif painted[pin] then
            paint(pin, GAME.fill, GAME.border, GAME.fillAlpha, GAME.borderAlpha, GAME.scalar)
        end
        painted[pin] = look
        if hideNow then return end -- drawn below anyway
        -- draw it again so the new look shows now (the game draws the focused quest's area)
        -- (the edge thickness only changes when the area is cleared first - seen in game)
        local qid = focusID()
        if qid then
            call(pin, "DrawNone")
            call(pin, "DrawBlob", qid, true)
        end
    end)
    if hideNow then
        eachGamePin(function(pin)
            call(pin, "DrawNone")
            call(pin, "DrawBlob", qidNow, true)
        end)
    end
end

-- from the options: paint again with the new look (or give the game its blue back)
function MA.Apply()
    MA.Update(true)
end

local function attach()
    local map = WorldMapFrame
    if not map or MA.driver then return end
    local driver = CreateFrame("Frame", nil, map)
    local acc = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < TICK then return end
        acc = 0
        local ok, err = NA.SafeCall(MA.Update)
        if not ok then NA.LogError(err) end
    end)
    MA.driver = driver
end

NA.OnInit(function()
    attach()
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "ADDON_LOADED")
    ev:SetScript("OnEvent", function() attach() end)
    MA.events = ev
end)

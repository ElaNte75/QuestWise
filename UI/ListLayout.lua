-- UI: where the quest list sits and how it looks: width, maximum height, background, moving it.
-- The settings live in QuestWiseDB (listWidth, listMaxHeight, listBackground, listOpacity,
-- listLocked, listPos). The tracker asks this module for the numbers; the Options page changes them.
local ADDON, NA = ...

local L = {}
NA.ListLayout = L

local DEFAULT_WIDTH, MIN_WIDTH, MAX_WIDTH = 260, 200, 500
local DEFAULT_HEIGHT, MIN_HEIGHT = 1050, 150
-- default spot = the owner's own setup: this far from the top-right corner of the screen
local DEFAULT_X, DEFAULT_Y = -67, -403

-- Room around the list inside its scroll frame (the scroll frame cuts off what is outside it,
-- and the quest circles / item buttons stick out of the quest text a little).
L.PAD_LEFT = 24
L.PAD_RIGHT = 6

-- background panel edges around the list frame, and how far under the title bar its gold line ends
local BG_LEFT, BG_RIGHT, BG_TOP = -12, 4, 0
local TITLE_LINE = 3
-- folded list: the title's dark panel sits just inside the gold frame of the bar picture
local FOLD_IN_LEFT, FOLD_IN_RIGHT, FOLD_IN_Y = 9, 15, 6 -- the picture's right end is wider

local function clamp(v, lo, hi) return math.min(math.max(v, lo), hi) end

L.MIN_WIDTH, L.MAX_WIDTH, L.MIN_HEIGHT = MIN_WIDTH, MAX_WIDTH, MIN_HEIGHT

function L.Width()
    return clamp(tonumber(NA.db.listWidth) or DEFAULT_WIDTH, MIN_WIDTH, MAX_WIDTH)
end

-- scale of the whole list (60..150 %) and the text size inside it (the title bars are 2 bigger)
L.MIN_SCALE, L.MAX_SCALE = 60, 150
L.MIN_FONT, L.MAX_FONT = 9, 16

function L.Scale()
    return clamp(tonumber(NA.db.listScale) or 100, L.MIN_SCALE, L.MAX_SCALE) / 100
end

function L.FontSize()
    return clamp(math.floor(tonumber(NA.db.listFontSize) or 12), L.MIN_FONT, L.MAX_FONT)
end

-- tallest list that still fits on this screen (in list units: a bigger scale = fewer fit)
function L.ScreenMax()
    return math.max(MIN_HEIGHT, math.floor(((UIParent:GetHeight() or 800) - 60) / L.Scale() / 50) * 50)
end

function L.MaxHeight()
    return clamp(tonumber(NA.db.listMaxHeight) or DEFAULT_HEIGHT, MIN_HEIGHT, L.ScreenMax())
end

function L.IsLocked()
    return NA.db.listLocked ~= false
end

-- Saved spot (screen units, kept from the corner of the screen nearest to the list, so a change of
-- resolution doesn't move it away from the minimap / bars):
--   listPos = { side = "LEFT"/"RIGHT", vert = "TOP"/"BOTTOM", x = from that side, y = list top from that edge }
-- Old saves { right, top } (from the bottom-left corner) are turned into this the first time.
local function screenSize()
    return UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
end

-- right / top of the list in screen units -> saved spot from the nearest corner
local function cornerPos(right, top, width)
    local sw, sh = screenSize()
    local left = right - (width or 0)
    local side = ((left + right) / 2 > sw / 2) and "RIGHT" or "LEFT"
    local vert = (top > sh / 2) and "TOP" or "BOTTOM"
    return {
        side = side, vert = vert,
        x = side == "RIGHT" and (right - sw) or left,
        y = vert == "TOP" and (top - sh) or top,
    }
end
L.CornerPos = cornerPos

-- Puts the list where you left it, or at the default spot (right side, below the minimap).
-- Not in combat (the list holds a secure item button): then it is done when the fight ends.
function L.ApplyPosition(f)
    f = f or L.frame
    if not f then return end
    if InCombatLockdown() then L.positionPending = true; return end
    L.positionPending = false
    -- positions are kept in screen units; the frame's offsets are in its own (scaled) units
    local r = f:GetScale() or 1
    local p = NA.db.listPos
    if p and p.right and p.top and not p.side then -- old save
        p = cornerPos(p.right, p.top, (f:GetWidth() or 0) * r)
        NA.db.listPos = p
    end
    f:ClearAllPoints()
    if p and p.side and p.x and p.y then
        f:SetPoint("TOP" .. p.side, UIParent, p.vert .. p.side, p.x / r, p.y / r)
    else
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", DEFAULT_X / r, DEFAULT_Y / r)
    end
end

-- Applies the list scale (not in combat: the list holds a secure item button; the tracker retries).
function L.ApplyScale()
    local f = L.frame
    if not f then return end
    local s = L.Scale()
    if math.abs((f:GetScale() or 1) - s) < 0.001 then return end
    if InCombatLockdown() then return end
    f:SetScale(s)
    L.ApplyPosition(f)
    L.UpdatePreview()
end

function L.ResetPosition()
    NA.db.listPos = nil
    L.ApplyPosition()
end

-- Background and the "you can move me" outline.
function L.ApplyLook()
    if not L.bg then return end
    local on = NA.db.listBackground and true or false
    local a = clamp(tonumber(NA.db.listOpacity) or 60, 10, 100) / 100
    -- the title bar has its own panel, a little darker; the list's panel starts under its gold line
    L.titleBg:SetShown(on)
    L.titleBg:ClearAllPoints()
    local art = L.header and L.header.art
    if NA.db.collapsedAll and art then
        L.titleBg:SetPoint("TOPLEFT", art, "TOPLEFT", FOLD_IN_LEFT, -FOLD_IN_Y)
        L.titleBg:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", -FOLD_IN_RIGHT, FOLD_IN_Y)
    else
        L.titleBg:SetPoint("TOPLEFT", L.frame, "TOPLEFT", BG_LEFT, BG_TOP)
        L.titleBg:SetPoint("BOTTOMRIGHT", L.header, "BOTTOMRIGHT", BG_RIGHT, -TITLE_LINE)
    end
    L.titleBg:SetColorTexture(0.012, 0.01, 0.008, math.min(1, a + 0.2))
    L.bg:SetShown(on and not NA.db.collapsedAll)
    L.bg:SetColorTexture(0.03, 0.025, 0.02, a)
    local unlocked = not L.IsLocked()
    for _, e in ipairs(L.edges) do e:SetShown(unlocked) end
end

-- Preview while you adjust the size in the options: a gold frame hanging from the same top
-- corner as the list, as wide as the list and as tall as its maximum height.
local function buildPreview()
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetFrameStrata("MEDIUM")
    p:SetFrameLevel(1) -- below the list itself
    local fill = p:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(1, 0.82, 0.30, 0.10)
    local function edge(a1, a2, w, h)
        local t = p:CreateTexture(nil, "BORDER")
        t:SetPoint(a1); t:SetPoint(a2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        t:SetColorTexture(1, 0.82, 0.30, 0.9)
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 2)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
    edge("TOPLEFT", "BOTTOMLEFT", 2, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
    local label = p:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    label:SetTextColor(1, 0.82, 0.30)
    label:SetPoint("BOTTOM", p, "BOTTOM", 0, 8)
    p.label = label
    p:Hide()
    return p
end

function L.UpdatePreview()
    local p = L.preview
    if not (p and p:IsShown() and L.frame) then return end
    local s = L.Scale() -- the preview is not scaled itself: it is as big as the scaled list
    p:SetSize((L.Width() + 20) * s, (L.MaxHeight() + 14) * s)
    p:ClearAllPoints()
    p:SetPoint("TOPRIGHT", L.frame, "TOPRIGHT", 8 * s, 6 * s)
    p.label:SetText(L.Width() .. " x " .. L.MaxHeight() .. " px")
end

function L.ShowPreview(on)
    if on and L.frame then
        L.preview = L.preview or buildPreview()
        L.preview:Show()
        L.UpdatePreview()
    elseif L.preview then
        L.preview:Hide()
    end
end

-- Called once by the tracker: f = the list frame, header = its title bar (drag it to move).
function L.Setup(f, header)
    L.frame = f
    L.header = header
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    -- background: one panel for the title bar (down to its gold line) and one for the quests under it.
    -- A little wider than the list on the left (the quest circles stick out there).
    local titleBg = f:CreateTexture(nil, "BACKGROUND")
    titleBg:SetPoint("TOPLEFT", f, "TOPLEFT", BG_LEFT, BG_TOP)
    titleBg:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", BG_RIGHT, -TITLE_LINE)
    L.titleBg = titleBg
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", header, "BOTTOMLEFT", BG_LEFT, -TITLE_LINE)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", BG_RIGHT, -8)
    L.bg = bg

    -- thin gold outline, visible only while the list is unlocked
    L.edges = {}
    local function edge(a1, a2, w, h)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetPoint(a1, f, a1, a1:find("LEFT") and BG_LEFT or BG_RIGHT, a1:find("TOP") and BG_TOP or -8)
        t:SetPoint(a2, f, a2, a2:find("LEFT") and BG_LEFT or BG_RIGHT, a2:find("TOP") and BG_TOP or -8)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        t:SetColorTexture(1, 0.82, 0.30, 0.8)
        L.edges[#L.edges + 1] = t
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

    -- drag the title bar to move (only while unlocked)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if L.IsLocked() then return end
        L.moving = true
        f:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        if not L.moving then return end
        L.moving = false
        f:StopMovingOrSizing()
        local right, top, r = f:GetRight(), f:GetTop(), f:GetScale() or 1
        if right and top then NA.db.listPos = cornerPos(right * r, top * r, (f:GetWidth() or 0) * r) end -- screen units
        L.ApplyPosition(f) -- anchor it cleanly at the new spot
    end)

    L.ApplyScale()
    L.ApplyPosition(f)
    L.ApplyLook()

    -- the game's resolution / window size / UI scale changed (e.g. a screen went dark and came back):
    -- put the list back where you left it
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_REGEN_ENABLED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not L.positionPending then return end
        if L.moving then return end
        NA.SafeCall(L.ApplyPosition)
    end)
    L.events = ev
end

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

-- Puts the list where you left it, or at the default spot (right side, below the minimap).
function L.ApplyPosition(f)
    f = f or L.frame
    if not f then return end
    f:ClearAllPoints()
    -- positions are kept in screen units; the frame's offsets are in its own (scaled) units
    local r = f:GetScale() or 1
    local p = NA.db.listPos
    if p and p.right and p.top then
        f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", p.right / r, p.top / r)
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
    L.bg:SetShown(NA.db.listBackground and true or false)
    local a = clamp(tonumber(NA.db.listOpacity) or 60, 10, 100) / 100
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
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    -- background panel: a little larger than the list
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", -12, 6)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 8, -8)
    L.bg = bg

    -- thin gold outline, visible only while the list is unlocked
    L.edges = {}
    local function edge(a1, a2, w, h)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetPoint(a1, f, a1, a1:find("LEFT") and -12 or 8, a1:find("TOP") and 6 or -8)
        t:SetPoint(a2, f, a2, a2:find("LEFT") and -12 or 8, a2:find("TOP") and 6 or -8)
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
        if right and top then NA.db.listPos = { right = right * r, top = top * r } end -- screen units
        L.ApplyPosition(f) -- anchor it cleanly at the new spot
    end)

    L.ApplyScale()
    L.ApplyPosition(f)
    L.ApplyLook()
end

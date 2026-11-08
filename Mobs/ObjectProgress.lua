-- Mobs: quest objects in the world (boulders, crates, plants...). Add-ons can't put a mark on them,
-- but while the mouse is over one, the game's tooltip names its quest and the progress (e.g. 7/8).
-- We read that and show a small "7/8 !" next to the cursor, in the same style as the mob marks.
-- Setting: objectProgress (on). Not while dead, flying or in a major city (Quests/Quiet.lua).
local ADDON, NA = ...

local OP = {}
NA.ObjectProgress = OP

local ICON_ATLASES = { "QuestNormal", "Quest-In-Progress-Icon-yellow" }
local READ_EVERY = 0.2 -- seconds: progress can change while you look at it

function OP.IsOn() return NA.db.objectProgress ~= false end

local function quiet()
    local M = NA.QuestMobMarker
    if M and M.PlayerDead and M.PlayerDead() then return true end
    return NA.Quiet ~= nil and NA.Quiet.Mobs()
end

-- the first unfinished "a/b" in the tooltip (below its first line = the object's name); else the first a/b
function OP.ReadProgress(tt)
    local first
    for i = 2, (tt:NumLines() or 0) do
        local fs = _G[tt:GetName() .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            local a, b = text:match("(%d+)%s*/%s*(%d+)")
            if a then
                local done = tonumber(a) >= tonumber(b)
                if not done then return a .. "/" .. b, false end
                first = first or (a .. "/" .. b)
            end
        end
    end
    if first then return first, true end
    return nil
end

local label -- the frame next to the cursor

local function build()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(1, 1)
    f:SetFrameStrata("TOOLTIP")
    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("RIGHT", f, "CENTER", 0, 0)
    NA.SetAtlasFirst(icon, ICON_ATLASES)
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    text:SetPoint("RIGHT", icon, "LEFT", 4, 0)
    f.icon, f.text = icon, text
    f:Hide()
    return f
end

local function place(f)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    f:ClearAllPoints()
    -- on the left of the cursor, a little lower, so the mouse pointer doesn't cover it
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s - 8, y / s - 6)
end

-- a tooltip for something in the world (not for a button of ours or of the game's windows)
local function forWorld(tt)
    if tt:GetOwner() ~= UIParent then return false end
    -- the mouse is on a creature / NPC (its tooltip may still hold the last mob's lines for a moment)
    if UnitExists and UnitExists("mouseover") then return false end
    local focus
    if GetMouseFoci then
        local ok, list = pcall(GetMouseFoci)
        focus = ok and type(list) == "table" and list[1] or nil
    elseif GetMouseFocus then
        local ok, f = pcall(GetMouseFocus)
        focus = ok and f or nil
    end
    return focus == nil or focus == WorldFrame
end

-- this tooltip was made for a creature: when the mouse leaves it, the game lets the same tooltip fade
-- out with the mob's lines still in it (and no unit any more) - not an object, until it is cleared
local unitTip = false
-- names whose tooltip was ever a creature's: the game sometimes refills a mob's tooltip without the
-- unit (seen in game: same lines, no unit, no tooltip data) - a name in here is never an object
local unitNames = {}

local function firstLine(tt)
    local fs = _G[tt:GetName() .. "TextLeft1"]
    return fs and fs:GetText()
end

local elapsed = 0
local function refresh(tt)
    local name = firstLine(tt)
    if tt:GetUnit() then
        unitTip = true
        if name then unitNames[name] = true end
    end
    if not (OP.IsOn() and tt:IsShown()) or unitTip or (name and unitNames[name]) or quiet() or tt:GetItem() or not forWorld(tt) then
        if label then label:Hide() end
        return
    end
    local progress, done = OP.ReadProgress(tt)
    if not progress then
        if label then label:Hide() end
        return
    end
    label = label or build()
    label.text:SetText(progress)
    if done then label.text:SetTextColor(0.6, 0.6, 0.6) else label.text:SetTextColor(1, 0.82, 0) end
    label.icon:SetDesaturated(done)
    place(label)
    label:Show()
end
OP.Refresh = refresh
function OP.IsLabelShown() return label ~= nil and label:IsShown() end

NA.OnInit(function()
    local tt = GameTooltip
    if not (tt and tt.HookScript) then return end
    tt:HookScript("OnShow", function(self)
        elapsed = 0
        C_Timer.After(0, function() NA.SafeCall(refresh, self) end) -- the lines are filled just after
    end)
    tt:HookScript("OnHide", function() unitTip = false; if label then label:Hide() end end)
    pcall(tt.HookScript, tt, "OnTooltipCleared", function() unitTip = false end)
    pcall(tt.HookScript, tt, "OnTooltipSetUnit", function(self)
        unitTip = true
        local name = firstLine(self)
        if name then unitNames[name] = true end
        if label then label:Hide() end
    end)
    tt:HookScript("OnUpdate", function(self, dt)
        if label and label:IsShown() then place(label) end
        elapsed = elapsed + (dt or 0)
        if elapsed < READ_EVERY then return end
        elapsed = 0
        NA.SafeCall(refresh, self)
    end)
end)

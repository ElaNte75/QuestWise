-- UI: look presets (colours + frames) for everything QuestWise draws: the quest list's background,
-- the quest details window and the options window. One setting: QuestWiseDB.theme (preset key).
-- Theme.Apply() copies the preset's options colours into W.colors (the same tables, changed in
-- place, so every widget keeps pointing at them), repaints the options window and asks the list and
-- the details window to redraw their look.
local ADDON, NA = ...

local T = {}
NA.Theme = T

T.DEFAULT = "QuestWise"

-- Edges drawn with the game's own border pictures (free to use: they come with the game).
local EDGE_METAL = {          -- thin metal line, coloured gold (the look of GearQuest Forever)
    file = "Interface\\Tooltips\\UI-Tooltip-Border", size = 16, out = 3,
}
local EDGE_DIALOG = {         -- the game's dialog box frame
    file = "Interface\\DialogFrame\\UI-DialogBox-Border", size = 24, out = 6,
}

-- opt  = the options window colours (the same names as W.colors)
-- list = quest list panels { bg = under the quests, title = behind the title bar } (rgb, opacity from the options)
-- info = details window { bg, header (rgb), border, divider (rgba), head (section titles), grey (small notes) }
-- edge = nil (1 px line in opt.border) or a game border picture + its colour
T.PRESETS = {
    {
        key = "QuestWise", label = "QuestWise",
        opt = {
            frameBg = { 0.055, 0.047, 0.039, 0.97 }, headerBg = { 0.095, 0.078, 0.057, 1 },
            sidebarBg = { 0.072, 0.060, 0.045, 1 }, contentBg = { 0.050, 0.043, 0.035, 1 },
            border = { 0.78, 0.64, 0.34, 0.85 }, divider = { 0.78, 0.64, 0.34, 0.22 },
            gold = { 1.00, 0.82, 0.30, 1 }, goldDim = { 0.80, 0.66, 0.36, 1 },
            text = { 0.93, 0.91, 0.87, 1 }, textDim = { 0.60, 0.58, 0.54, 1 },
            controlBg = { 0, 0, 0, 0.40 }, controlBorder = { 0.78, 0.64, 0.34, 0.45 },
            hover = { 1, 1, 1, 0.06 }, selectedBg = { 1, 0.82, 0.30, 0.12 },
            buttonBg = { 1, 0.82, 0.30, 0.08 }, buttonHover = { 1, 0.82, 0.30, 0.16 },
            popupBg = { 0.06, 0.05, 0.04, 0.98 }, sliderFill = { 0.80, 0.66, 0.36, 0.75 },
            thumbHover = { 1, 0.92, 0.55, 1 },
        },
        list = { bg = { 0.03, 0.025, 0.02 }, title = { 0.012, 0.01, 0.008 } },
        info = {
            bg = { 0.055, 0.047, 0.039 }, header = { 0.095, 0.078, 0.057 },
            border = { 0.78, 0.64, 0.34, 0.85 }, divider = { 0.78, 0.64, 0.34, 0.30 },
            head = { 0.80, 0.66, 0.36 }, grey = { 0.62, 0.62, 0.62 },
        },
    },
    {
        -- colours as in GearQuest Forever (by Henrik8210): brown bars, gold text, near-black lists
        key = "GearQuest", label = "GearQuest",
        opt = {
            frameBg = { 0.14, 0.10, 0.06, 0.97 }, headerBg = { 0.28, 0.22, 0.08, 1 },
            sidebarBg = { 0.17, 0.125, 0.075, 1 }, contentBg = { 0.12, 0.09, 0.055, 1 },
            border = { 0.90, 0.75, 0.28, 1 }, divider = { 0.62, 0.54, 0.36, 0.45 },
            gold = { 0.90, 0.75, 0.28, 1 }, goldDim = { 0.78, 0.72, 0.58, 1 },
            text = { 1, 1, 1, 1 }, textDim = { 0.78, 0.76, 0.72, 1 },
            controlBg = { 0, 0, 0, 0.60 }, controlBorder = { 0.62, 0.54, 0.36, 0.70 },
            hover = { 0.62, 0.50, 0.18, 0.35 }, selectedBg = { 0.28, 0.22, 0.08, 0.85 },
            buttonBg = { 0.28, 0.22, 0.08, 0.70 }, buttonHover = { 0.62, 0.50, 0.18, 0.55 },
            popupBg = { 0.07, 0.06, 0.05, 0.98 }, sliderFill = { 0.62, 0.54, 0.36, 0.80 },
            thumbHover = { 1, 0.88, 0.45, 1 },
        },
        list = { bg = { 0.12, 0.09, 0.055 }, title = { 0.28, 0.22, 0.08 } },
        info = {
            bg = { 0.12, 0.09, 0.055 }, header = { 0.28, 0.22, 0.08 },
            border = { 0.90, 0.75, 0.28, 1 }, divider = { 0.62, 0.54, 0.36, 0.60 },
            head = { 0.90, 0.75, 0.28 }, grey = { 0.72, 0.72, 0.72 },
        },
        edge = { style = EDGE_METAL, color = { 0.90, 0.75, 0.28, 1 } },
    },
    {
        key = "Midnight", label = "Midnight",
        opt = {
            frameBg = { 0.09, 0.13, 0.20, 0.97 }, headerBg = { 0.14, 0.21, 0.31, 1 },
            sidebarBg = { 0.11, 0.16, 0.24, 1 }, contentBg = { 0.08, 0.12, 0.18, 1 },
            border = { 0.56, 0.66, 0.77, 0.85 }, divider = { 0.56, 0.66, 0.77, 0.25 },
            gold = { 0.81, 0.88, 0.95, 1 }, goldDim = { 0.60, 0.70, 0.82, 1 },
            text = { 0.88, 0.91, 0.95, 1 }, textDim = { 0.58, 0.63, 0.70, 1 },
            controlBg = { 0, 0, 0, 0.40 }, controlBorder = { 0.56, 0.66, 0.77, 0.45 },
            hover = { 1, 1, 1, 0.06 }, selectedBg = { 0.56, 0.72, 0.95, 0.14 },
            buttonBg = { 0.56, 0.72, 0.95, 0.10 }, buttonHover = { 0.56, 0.72, 0.95, 0.20 },
            popupBg = { 0.05, 0.07, 0.10, 0.98 }, sliderFill = { 0.60, 0.70, 0.82, 0.75 },
            thumbHover = { 0.92, 0.96, 1, 1 },
        },
        list = { bg = { 0.08, 0.12, 0.18 }, title = { 0.14, 0.21, 0.31 } },
        info = {
            bg = { 0.08, 0.12, 0.18 }, header = { 0.14, 0.21, 0.31 },
            border = { 0.56, 0.66, 0.77, 0.85 }, divider = { 0.56, 0.66, 0.77, 0.35 },
            head = { 0.60, 0.70, 0.82 }, grey = { 0.62, 0.66, 0.72 },
        },
    },
    {
        key = "Forest", label = "Forest",
        opt = {
            frameBg = { 0.08, 0.14, 0.09, 0.97 }, headerBg = { 0.13, 0.22, 0.15, 1 },
            sidebarBg = { 0.10, 0.17, 0.11, 1 }, contentBg = { 0.07, 0.12, 0.08, 1 },
            border = { 0.69, 0.54, 0.29, 0.85 }, divider = { 0.69, 0.54, 0.29, 0.25 },
            gold = { 0.85, 0.72, 0.40, 1 }, goldDim = { 0.72, 0.60, 0.36, 1 },
            text = { 0.89, 0.90, 0.86, 1 }, textDim = { 0.58, 0.61, 0.55, 1 },
            controlBg = { 0, 0, 0, 0.40 }, controlBorder = { 0.69, 0.54, 0.29, 0.45 },
            hover = { 1, 1, 1, 0.06 }, selectedBg = { 0.85, 0.72, 0.40, 0.12 },
            buttonBg = { 0.85, 0.72, 0.40, 0.08 }, buttonHover = { 0.85, 0.72, 0.40, 0.16 },
            popupBg = { 0.05, 0.07, 0.05, 0.98 }, sliderFill = { 0.72, 0.60, 0.36, 0.75 },
            thumbHover = { 0.95, 0.85, 0.55, 1 },
        },
        list = { bg = { 0.07, 0.12, 0.08 }, title = { 0.13, 0.22, 0.15 } },
        info = {
            bg = { 0.07, 0.12, 0.08 }, header = { 0.13, 0.22, 0.15 },
            border = { 0.69, 0.54, 0.29, 0.85 }, divider = { 0.69, 0.54, 0.29, 0.35 },
            head = { 0.72, 0.60, 0.36 }, grey = { 0.62, 0.64, 0.60 },
        },
    },
    {
        -- "Stone": stone background and dialog box frame of the game, game gold (1, 0.82, 0), white text
        key = "Game", label = "Stone", -- (key kept: saved settings use it)
        opt = {
            frameBg = { 0.12, 0.12, 0.12, 0.97 }, headerBg = { 0.30, 0.20, 0.08, 1 },
            sidebarBg = { 0.15, 0.15, 0.15, 1 }, contentBg = { 0.12, 0.12, 0.12, 1 },
            border = { 0.60, 0.60, 0.60, 1 }, divider = { 0.60, 0.60, 0.60, 0.35 },
            gold = { 1, 0.82, 0, 1 }, goldDim = { 0.90, 0.74, 0.10, 1 },
            text = { 1, 1, 1, 1 }, textDim = { 0.70, 0.70, 0.70, 1 },
            controlBg = { 0, 0, 0, 0.55 }, controlBorder = { 0.50, 0.50, 0.50, 0.70 },
            hover = { 1, 1, 1, 0.08 }, selectedBg = { 1, 0.82, 0, 0.12 },
            buttonBg = { 0.45, 0.06, 0.04, 0.85 }, buttonHover = { 0.65, 0.10, 0.06, 0.90 },
            popupBg = { 0.05, 0.05, 0.05, 0.98 }, sliderFill = { 0.90, 0.74, 0.10, 0.75 },
            thumbHover = { 1, 0.92, 0.45, 1 },
        },
        list = { bg = { 0.12, 0.12, 0.12 }, title = { 0.30, 0.20, 0.08 } },
        info = {
            bg = { 0.12, 0.12, 0.12 }, header = { 0.30, 0.20, 0.08 },
            border = { 0.60, 0.60, 0.60, 1 }, divider = { 0.60, 0.60, 0.60, 0.40 },
            head = { 1, 0.82, 0 }, grey = { 0.70, 0.70, 0.70 },
        },
        edge = { style = EDGE_DIALOG, color = { 1, 1, 1, 1 } },
        -- the game's own stone background picture (tiled) on these panels; the colours above are
        -- the fallback when none of the pictures exists in this game
        bgTex = {
            files = {
                "Interface\\FrameGeneral\\UI-Background-Rock",
                "Interface\\FrameGeneral\\UI-Background-Marble",
                "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                "Interface\\DialogFrame\\UI-DialogBox-Background",
            },
            keys = { frameBg = 1, contentBg = 1, sidebarBg = 0.80, listBg = 1, infoBg = 1 }, -- brightness
        },
    },
}

-- ------------------------------------------------------------------ background pictures

local bgFileCache = {} -- preset key -> first picture that loads (false = none)

-- the background picture of the current preset, or nil
function T.BgFile()
    local p = T.Current()
    if not p.bgTex then return nil end
    if bgFileCache[p.key] == nil then
        bgFileCache[p.key] = false
        local probe = UIParent:CreateTexture(nil, "BACKGROUND")
        T.bgTried = {}
        for _, file in ipairs(p.bgTex.files) do
            local ok, loaded = pcall(probe.SetTexture, probe, file)
            T.bgTried[#T.bgTried + 1] = file .. "=" .. tostring(ok and loaded)
            if ok and loaded ~= false then bgFileCache[p.key] = file; break end
        end
        probe:Hide()
    end
    return bgFileCache[p.key] or nil
end

-- Paints a panel: the preset's background picture when it has one for `key`, else the colour.
-- key = a W.colors name (frameBg, contentBg, sidebarBg) or "listBg" / "infoBg"; alpha = opacity.
function T.PaintPanel(tex, key, rgb, alpha)
    tex:SetVertexColor(1, 1, 1, 1)
    local p = T.Current()
    local bright = p.bgTex and p.bgTex.keys[key]
    local file = bright and T.BgFile()
    if file then
        tex:SetTexture(file, "REPEAT", "REPEAT")
        if tex.SetHorizTile then tex:SetHorizTile(true); tex:SetVertTile(true) end
        tex:SetVertexColor(bright, bright, bright, alpha or 1)
        return true
    end
    if tex.SetHorizTile then tex:SetHorizTile(false); tex:SetVertTile(false) end
    tex:SetColorTexture(rgb[1], rgb[2], rgb[3], alpha or rgb[4] or 1)
    return false
end

local byKey = {}
for _, p in ipairs(T.PRESETS) do byKey[p.key] = p end

-- the chosen preset (an unknown saved key falls back to the default)
function T.Current()
    return byKey[NA.db and NA.db.theme or T.DEFAULT] or byKey[T.DEFAULT]
end

-- ------------------------------------------------------------------ edges (game border pictures)

local edges = {} -- every edge made by T.Edge, repainted when the preset changes

local function paintEdge(e)
    local p = T.Current()
    local want = p.edge and e.wanted ~= false
    if not (want and e.frame.SetBackdrop) then
        e.frame:Hide()
        return false
    end
    local s = p.edge.style
    e.frame:ClearAllPoints()
    e.frame:SetPoint("TOPLEFT", e.topLeft or e.owner, "TOPLEFT", -s.out, s.out)
    e.frame:SetPoint("BOTTOMRIGHT", e.bottomRight or e.owner, "BOTTOMRIGHT", s.out, -s.out)
    e.frame:SetBackdrop({ edgeFile = s.file, edgeSize = s.size })
    if e.frame.SetBackdropBorderColor then e.frame:SetBackdropBorderColor(unpack(p.edge.color)) end
    e.frame:Show()
    return true
end

-- An edge around `owner` (or around topLeft .. bottomRight when given). Returns a handle:
--   h:Refresh(shown) -> true when the preset draws a game border (then hide your own 1 px line)
function T.Edge(owner, levelUp, topLeft, bottomRight)
    local ok, fr = pcall(CreateFrame, "Frame", nil, owner, "BackdropTemplate")
    if not ok or not fr then fr = CreateFrame("Frame", nil, owner) end
    if not fr.SetBackdrop and Mixin and BackdropTemplateMixin then Mixin(fr, BackdropTemplateMixin) end
    fr:SetFrameLevel((owner:GetFrameLevel() or 1) + (levelUp or 20))
    fr:Hide()
    local e = { owner = owner, frame = fr, topLeft = topLeft, bottomRight = bottomRight }
    function e:Refresh(shown)
        self.wanted = shown
        return paintEdge(self)
    end
    function e:SetCorners(tl, br) self.topLeft, self.bottomRight = tl, br end
    edges[#edges + 1] = e
    return e
end

function T.HasEdge() return T.Current().edge ~= nil end

-- ------------------------------------------------------------------ apply

-- copies the preset's colours into W.colors without replacing the tables
local function fillOptionColours()
    local W = NA.Widgets
    if not W then return end
    for k, v in pairs(T.Current().opt) do
        local c = W.colors[k]
        if c then
            for i = 1, 4 do c[i] = v[i] end
        else
            W.colors[k] = { v[1], v[2], v[3], v[4] }
        end
    end
end

function T.Apply()
    fillOptionColours()
    for _, e in ipairs(edges) do paintEdge(e) end
    if NA.Widgets and NA.Widgets.Recolor then NA.Widgets.Recolor() end
    if NA.Options and NA.Options.ApplyTheme then NA.SafeCall(NA.Options.ApplyTheme) end
    if NA.ListLayout and NA.ListLayout.ApplyLook then NA.SafeCall(NA.ListLayout.ApplyLook) end
    if NA.QuestInfoWindow and NA.QuestInfoWindow.ApplyLook then NA.SafeCall(NA.QuestInfoWindow.ApplyLook) end
end

function T.Set(key)
    if not byKey[key] then return end
    NA.db.theme = key
    T.Apply()
end

-- before anything is drawn: the options colours of the saved preset
NA.OnInit(fillOptionColours)

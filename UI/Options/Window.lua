-- Options UI: the settings window (title bar, left menu of pages, content, footer with Close).
-- Pages register themselves with NA.Options.AddPage(key, label, build); build(parent) returns a refresh function.
local ADDON, NA = ...

local Opt = { pages = {}, order = {} }
NA.Options = Opt

local WIDTH, HEIGHT = 560, 520
local HEADER_H, FOOTER_H, SIDEBAR_W = 46, 44, 150
local PAD = 20
local NAV_H = 28

function Opt.AddPage(key, label, build)
    Opt.pages[key] = { key = key, label = label, build = build }
    Opt.order[#Opt.order + 1] = key
end

local function navButton(parent, label)
    local W = NA.Widgets
    local C = W.colors
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIDEBAR_W, NAV_H)
    b.bg = W.Fill(b, C.selectedBg)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    W.Paint(hl, C.hover)
    b.accent = b:CreateTexture(nil, "ARTWORK")
    b.accent:SetPoint("TOPLEFT"); b.accent:SetPoint("BOTTOMLEFT")
    b.accent:SetWidth(2)
    W.Paint(b.accent, C.gold)
    b.text = W.Text(b, W.size.font, C.text)
    b.text:SetPoint("LEFT", 16, 0)
    b.text:SetText(label)
    function b:SetSelected(on)
        self.bg:SetShown(on)
        self.accent:SetShown(on)
        self.text:SetTextColor(unpack(on and C.gold or C.text))
    end
    b:SetSelected(false)
    return b
end

local function build()
    local W = NA.Widgets
    local C = W.colors

    local f = CreateFrame("Frame", "QuestSiftOptionsWindow", UIParent)
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(30)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    -- closing the window also hides the size preview of the Interface page
    f:HookScript("OnHide", function() if NA.ListLayout then NA.ListLayout.ShowPreview(false) end end)
    W.Fill(f, C.frameBg)
    if UISpecialFrames then table.insert(UISpecialFrames, "QuestSiftOptionsWindow") end -- Esc closes it

    -- title bar (drag here to move the window)
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_H)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    W.Fill(header, C.headerBg)
    local title = W.Text(header, 16, C.gold)
    title:SetPoint("LEFT", PAD, 0)
    title:SetText("QuestSift")
    local accent = W.Text(header, 16, C.text)
    accent:SetPoint("LEFT", title, "RIGHT", 8, 0)
    accent:SetText("Options")

    -- footer
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("BOTTOMRIGHT")
    footer:SetHeight(FOOTER_H)
    W.Fill(footer, C.headerBg)
    local close = W.Button(footer, "Close", 90, 24, function() f:Hide() end)
    close:SetPoint("RIGHT", -PAD + 6, 0)
    local note = W.Text(footer, W.size.small, C.textDim)
    note:SetPoint("LEFT", PAD, 0)
    note:SetText("Changes apply immediately.")

    -- left menu + content
    local sidebar = CreateFrame("Frame", nil, f)
    sidebar:SetPoint("TOPLEFT", 0, -HEADER_H)
    sidebar:SetPoint("BOTTOMLEFT", 0, FOOTER_H)
    sidebar:SetWidth(SIDEBAR_W)
    W.Fill(sidebar, C.sidebarBg)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", 0, FOOTER_H)
    W.Fill(content, C.contentBg)

    -- divider lines + outer border (drawn last so they sit on top)
    local frameBorder = CreateFrame("Frame", nil, f)
    frameBorder:SetAllPoints()
    frameBorder:SetFrameLevel(f:GetFrameLevel() + 20)
    W.Outline(frameBorder, C.border)
    f.frameBorder = frameBorder
    -- presets with a game border picture draw it around the window (UI/Theme.lua)
    f.edge = NA.Theme and NA.Theme.Edge(f, 25)
    local function line(a1, rel, a2, w, h)
        local t = frameBorder:CreateTexture(nil, "ARTWORK")
        W.Paint(t, C.divider)
        t:SetPoint(a1, rel, a2, 0, 0)
        if w then t:SetSize(w, 1) else t:SetSize(1, h) end
    end
    line("TOPLEFT", header, "BOTTOMLEFT", WIDTH)
    line("BOTTOMLEFT", footer, "TOPLEFT", WIDTH)
    line("TOPRIGHT", sidebar, "TOPRIGHT", nil, HEIGHT - HEADER_H - FOOTER_H)

    -- pages
    f.navButtons, f.pageFrames, f.scrollPages, f.refreshers = {}, {}, {}, {}
    local y = -12
    for _, key in ipairs(Opt.order) do
        local page = Opt.pages[key]
        local nb = navButton(sidebar, page.label)
        nb:SetPoint("TOPLEFT", 0, y)
        y = y - NAV_H - 2
        f.navButtons[key] = nb

        -- every page scrolls (thin scrollbar on the right) when it is taller than the window
        local sp = W.ScrollPage(content, {
            left = PAD, top = PAD - 2, right = PAD, bottom = PAD, barX = 7,
            pageW = WIDTH - SIDEBAR_W - 2 * PAD,
            viewH = HEIGHT - HEADER_H - FOOTER_H - (PAD - 2) - PAD,
        })
        local pf = sp.page
        f.pageFrames[key] = pf
        f.scrollPages[key] = sp
        local ok, refresh = NA.SafeCall(page.build, pf)
        if not ok then NA.LogError(refresh) end
        f.refreshers[key] = ok and refresh or nil
        sp.SetContentHeight((pf.stackHeight or 0) + 6)

        nb:SetScript("OnClick", function() Opt.SelectPage(key) end)
    end
    Opt.frame = f
    Opt.ApplyTheme()
    return f
end

-- the look preset changed (UI/Theme.lua has already repainted the colours): game border or 1 px line,
-- and re-read the open page so selected items get their colours back
function Opt.ApplyTheme()
    local f = Opt.frame
    if not f then return end
    local framed = f.edge and f.edge:Refresh(true)
    if framed then f.frameBorder:SetOutlineColor(0, 0, 0, 0) end
    if Opt.current and f.navButtons[Opt.current] then Opt.SelectPage(Opt.current) end
end

function Opt.SelectPage(key)
    local f = Opt.frame
    if not f then return end
    Opt.current = key
    for k, pf in pairs(f.pageFrames) do
        local on = (k == key)
        f.scrollPages[k].SetShown(on)
        if pf.PageToggle then pf.PageToggle(on) end -- pages may react to being shown/hidden
        f.navButtons[k]:SetSelected(on)
    end
    local refresh = f.refreshers[key]
    if type(refresh) == "function" then NA.SafeCall(refresh) end
end

-- Re-reads the settings shown on the open page (e.g. after the V key changed the nameplates).
function Opt.RefreshCurrent()
    local f = Opt.frame
    if not (f and f:IsShown() and Opt.current) then return end
    local refresh = f.refreshers[Opt.current]
    if type(refresh) == "function" then NA.SafeCall(refresh) end
end

-- Scale of this window (Interface page): 70..130 %.
function Opt.ApplyScale()
    if not Opt.frame then return end
    local pct = math.min(math.max(tonumber(NA.db.optionsScale) or 100, 70), 130)
    Opt.frame:SetScale(pct / 100)
end

function Opt.Open()
    if not Opt.frame then
        local ok, f = NA.SafeCall(build)
        if not ok then NA.LogError(f); return end
        Opt.frame = f
    end
    Opt.ApplyScale()
    Opt.frame:Show()
    Opt.SelectPage(Opt.current or Opt.order[1])
end

function Opt.Toggle()
    if Opt.frame and Opt.frame:IsShown() then
        Opt.frame:Hide()
    else
        Opt.Open()
    end
end

-- /questsift or /qs opens the window (quiet: prints nothing)
SLASH_QUESTSIFT1 = "/questsift"
SLASH_QUESTSIFT2 = "/qs"
SlashCmdList["QUESTSIFT"] = function() Opt.Toggle() end

-- AddOn list button (top-right of the game's minimap area) entry points; see the .toc
function QuestSift_OnCompartmentClick() Opt.Toggle() end

-- Options UI: ONE shared look (colours, sizes, spacing) and the widgets every page is built from.
-- Pages never pick their own colours or gaps: they use W.colors / W.size and W.Stack.
local ADDON, NA = ...

local W = {}
NA.Widgets = W

local FONT = "Fonts\\FRIZQT__.TTF"

W.colors = {
    frameBg       = { 0.055, 0.047, 0.039, 0.97 },
    headerBg      = { 0.095, 0.078, 0.057, 1 },
    sidebarBg     = { 0.072, 0.060, 0.045, 1 },
    contentBg     = { 0.050, 0.043, 0.035, 1 },
    border        = { 0.78, 0.64, 0.34, 0.85 },
    divider       = { 0.78, 0.64, 0.34, 0.22 },
    gold          = { 1.00, 0.82, 0.30, 1 },
    goldDim       = { 0.80, 0.66, 0.36, 1 },
    text          = { 0.93, 0.91, 0.87, 1 },
    textDim       = { 0.60, 0.58, 0.54, 1 },
    orange        = { 1.00, 0.56, 0.12, 1 },
    controlBg     = { 0, 0, 0, 0.40 },
    controlBorder = { 0.78, 0.64, 0.34, 0.45 },
    hover         = { 1, 1, 1, 0.06 },
    selectedBg    = { 1, 0.82, 0.30, 0.12 },
    track         = { 1, 1, 1, 0.10 },
    buttonBg      = { 1, 0.82, 0.30, 0.08 },
    buttonHover   = { 1, 0.82, 0.30, 0.16 },
    popupBg       = { 0.06, 0.05, 0.04, 0.98 },
    sliderFill    = { 0.80, 0.66, 0.36, 0.75 },
    thumbHover    = { 1, 0.92, 0.55, 1 },
}
local C = W.colors
-- (UI/Theme.lua changes these colours in place when you pick another look preset)

-- Everything painted with one of W.colors is remembered, so a new preset can repaint it.
local painted = {}
local function keyOf(color)
    for k, v in pairs(C) do if v == color then return k end end
end
local function remember(obj, color, kind)
    local key = keyOf(color)
    if key then painted[#painted + 1] = { obj = obj, key = key, kind = kind } end
end
-- panels may get the preset's background picture instead of a flat colour (UI/Theme.lua)
function W.PaintFill(tex, key, color)
    if NA.Theme and NA.Theme.PaintPanel then return NA.Theme.PaintPanel(tex, key, color) end
    tex:SetColorTexture(unpack(color))
end

local function paint(p)
    local c = C[p.key]
    if p.kind == "fill" then W.PaintFill(p.obj, p.key, c)
    elseif p.kind == "vertex" then p.obj:SetVertexColor(unpack(c))
    elseif p.kind == "text" then p.obj:SetTextColor(unpack(c))
    elseif p.kind == "outline" then p.obj:SetOutlineColor(unpack(c)) end
end

-- colour a texture with one of W.colors (and repaint it when the preset changes)
function W.Paint(tex, color)
    tex:SetColorTexture(unpack(color))
    remember(tex, color, "fill")
end
function W.Tint(tex, color)
    tex:SetVertexColor(unpack(color))
    remember(tex, color, "vertex")
end

-- repaints everything with the current W.colors (called by UI/Theme.lua)
function W.Recolor()
    for _, p in ipairs(painted) do paint(p) end
end

-- every distance on every page comes from here
W.size = {
    font = 12, small = 11, title = 15,
    row = 24,          -- checkbox row
    subRow = 28,       -- "Label  [control]" row under a checkbox
    rowGap = 4,        -- between rows
    sectionGap = 18,   -- before a section heading
    afterSection = 8,  -- between a heading and its first row
    indent = 26,       -- sub-rows start where the checkbox text starts
    -- THE GRID (the same on every page; pages never place anything themselves):
    --   check boxes, titles, descriptions and notes start at x = 0
    --   row labels start at x = 0 (or at `indent` for sub-rows)
    --   EVERY control (slider, drop-down, button) starts at x = controlX and is controlW wide,
    --   so all controls on all pages line up in one column
    controlX = 140,
    controlW = 150,
    controlH = 22,
}
local S = W.size

-- ---------------------------------------------------------------- basics

function W.Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(FONT, size or S.font, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(unpack(color or C.text))
    remember(fs, color or C.text, "text")
    return fs
end

function W.Fill(frame, color, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    local key = keyOf(color)
    if key then W.PaintFill(t, key, color) else t:SetColorTexture(unpack(color)) end
    remember(t, color, "fill")
    return t
end

-- 1px outline; frame:SetOutlineColor(r, g, b, a) recolours it
function W.Outline(frame, color)
    local edges = {}
    local function edge(a1, a2, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetPoint(a1); t:SetPoint(a2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        edges[#edges + 1] = t
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    function frame:SetOutlineColor(r, g, b, a)
        for _, t in ipairs(edges) do t:SetColorTexture(r, g, b, a) end
    end
    frame:SetOutlineColor(unpack(color or C.border))
    remember(frame, color or C.border, "outline")
end

local function attachTooltip(frame, title, text)
    if not text or text == "" then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title or "", unpack(C.gold))
        GameTooltip:AddLine(text, 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- dims a control (or row) and stops it from reacting while `on` is false
function W.SetActive(frame, on)
    frame:SetAlpha(on and 1 or 0.4)
    if frame.SetEnabled then frame:SetEnabled(on) end
    if frame.control and frame.control.SetEnabled then frame.control:SetEnabled(on) end
    if frame.control and frame.control.EnableMouse then frame.control:EnableMouse(on) end
end

-- ---------------------------------------------------------------- layout

-- Vertical stack: puts each widget under the previous one with the shared spacing.
-- stack:Add(widget, kind) where kind = "header" | "section" | "row" | "sub"
function W.Stack(parent)
    local st = { y = 0, last = nil }
    function st:Add(w, kind)
        local gap, indent, full = S.rowGap, 0, false
        if kind == "header" then gap, full = 0, true
        elseif kind == "section" then gap, full = (self.last and S.sectionGap or 0), true
        elseif kind == "note" then full = true
        elseif kind == "sub" then indent = S.indent end
        if self.last == "section" then gap = S.afterSection end
        if not self.last then gap = 0 end
        self.y = self.y - gap
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", parent, "TOPLEFT", indent, self.y)
        if full then w:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, self.y) end
        self.y = self.y - (w:GetHeight() or S.row)
        self.last = kind
        w.indentX = indent
        if w.Place then w:Place() end -- rows put their label and control on the grid
        parent.stackHeight = -self.y -- how tall the page is (the window uses it to scroll)
        return w
    end
    return st
end

-- Page title + one line that says what the page is for.
function W.PageHeader(parent, title, desc)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(34)
    local t = W.Text(f, S.title, C.text)
    t:SetPoint("TOPLEFT", 0, 0)
    t:SetText(title)
    local d = W.Text(f, S.small, C.textDim)
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -5)
    d:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    d:SetText(desc or "")
    return f
end

-- Section heading: gold caps text with a thin line to the right edge.
-- opts.important = orange text with the game's quest "!" in front.
function W.Section(parent, text, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(18)
    local x = 0
    if opts.important then
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", 0, 0)
        NA.SetAtlasFirst(icon, { "QuestNormal", "Quest-In-Progress-Icon-yellow" })
        x = 18
    end
    local fs = W.Text(f, S.small, opts.important and C.orange or C.goldDim)
    fs:SetPoint("LEFT", x, 0)
    fs:SetText(string.upper(text))
    local line = f:CreateTexture(nil, "ARTWORK")
    W.Paint(line, C.divider)
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    return f
end

-- A short explanation in small dim text (use with stack kind "note").
function W.Note(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(26)
    local t = W.Text(f, S.small, C.textDim)
    t:SetPoint("TOPLEFT", 0, 0)
    t:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    t:SetJustifyV("TOP")
    t:SetText(text)
    return f
end

function W.Heading(parent, text)
    return W.Section(parent, text, { important = true })
end

-- Sub-row: "Label" in a fixed column, then the control. row:SetControl(c) places it.
function W.Row(parent, label)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(S.controlX + S.controlW + 80, S.subRow)
    local fs = W.Text(row, S.font, C.textDim)
    fs:SetPoint("LEFT", 0, 0)
    fs:SetText(label)
    row.label = fs
    row.indentX = 0
    local ctl -- the control of this row, once SetControl has been called
    -- label and control sit on the grid: the control always starts at x = controlX of the page
    function row:Place()
        fs:SetWidth(S.controlX - row.indentX - 8)
        if ctl then
            ctl:ClearAllPoints()
            ctl:SetPoint("LEFT", row, "LEFT", S.controlX - row.indentX, 0)
        end
    end
    function row:SetControl(c)
        ctl = c
        row.control = c
        row:Place()
        return c
    end
    return row
end

-- ---------------------------------------------------------------- controls

-- Check box bound to get()/set(bool). The whole label is clickable. check.Refresh() re-reads.
function W.Checkbox(parent, label, tip, get, set)
    local check = CreateFrame("CheckButton", nil, parent)
    check:SetHeight(S.row)

    local box = CreateFrame("Frame", nil, check)
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 0, 0)
    W.Fill(box, C.controlBg)
    W.Outline(box, C.controlBorder)

    local mark = box:CreateTexture(nil, "OVERLAY")
    mark:SetSize(20, 20)
    mark:SetPoint("CENTER", 1, 0)
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    W.Tint(mark, C.gold)

    local text = W.Text(check, S.font, C.text)
    text:SetPoint("LEFT", box, "RIGHT", S.indent - 16, 0)
    text:SetText(label)
    check.label = text
    check:SetWidth(S.indent + (text:GetStringWidth() or 0) + 8)

    local function show(v) mark:SetShown(v and true or false) end
    check:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        show(v)
        set(v)
    end)
    check:SetScript("OnEnter", function() box:SetOutlineColor(unpack(C.gold)) end)
    check:SetScript("OnLeave", function() box:SetOutlineColor(unpack(C.controlBorder)) end)
    check.Refresh = function()
        local v = get() and true or false
        check:SetChecked(v)
        show(v)
    end
    attachTooltip(check, label, tip)
    return check
end

-- A button placed in a Row's control column: always the grid's control size.
function W.ControlButton(parent, text, onClick)
    return W.Button(parent, text, S.controlW, S.controlH, onClick)
end

-- Flat button in the window's style.
function W.Button(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    local bg = W.Fill(b, C.buttonBg)
    W.Outline(b, C.controlBorder)
    local fs = W.Text(b, S.font, C.gold)
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(text)
    b:SetScript("OnEnter", function() b:SetOutlineColor(unpack(C.gold)); bg:SetColorTexture(unpack(C.buttonHover)) end)
    b:SetScript("OnLeave", function() b:SetOutlineColor(unpack(C.controlBorder)); bg:SetColorTexture(unpack(C.buttonBg)) end)
    b:SetScript("OnMouseDown", function() fs:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function() fs:SetPoint("CENTER", 0, 0) end)
    b:SetScript("OnClick", onClick)
    return b
end

-- UI: one quest entry (round icon, "[level] Title", objective lines).
local ADDON, NA = ...

local Block = {}
Block.__index = Block
NA.QuestBlock = Block

local FONT = "Fonts\\FRIZQT__.TTF"
local WIDTH = 240
local TEXT_WIDTH = 230.83
local DASH_WIDTH = 9.17
local TITLE_GAP = 4
local LINE_GAP = 2

local function styleText(fs, justifyV)
    fs:SetFont(FONT, 12, "")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV(justifyV or "TOP")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
end

local function createLine(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:SetWidth(WIDTH)

    line.dash = line:CreateFontString(nil, "OVERLAY")
    styleText(line.dash)
    line.dash:SetPoint("TOPLEFT", 0, 1)
    line.dash:SetText("- ")
    line.dash:SetTextColor(1, 1, 1)

    line.text = line:CreateFontString(nil, "OVERLAY")
    styleText(line.text)

    line.check = line:CreateTexture(nil, "ARTWORK")
    line.check:SetSize(16, 16)
    line.check:SetPoint("TOPLEFT", -10, 2)
    NA.SetAtlas(line.check, "UI-QuestTracker-Tracker-Check")
    return line
end

function Block.New(parent)
    local self = setmetatable({}, Block)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(WIDTH, 20)
    self.frame = f
    self.lines = {}

    local title = f:CreateFontString(nil, "OVERLAY")
    styleText(title)
    title:SetWidth(WIDTH)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetTextColor(1, 0.82, 0)
    self.title = title

    self.itemSlot = nil -- quest item button, created the first time a quest needs one

    local titleBtn = CreateFrame("Button", nil, f)
    titleBtn:SetPoint("TOPLEFT", title, "TOPLEFT")
    titleBtn:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT")
    titleBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.titleBtn = titleBtn

    local poi = CreateFrame("Button", nil, f)
    poi:SetSize(20, 20)
    poi:SetPoint("TOPRIGHT", f, "TOPLEFT", -7, 5)
    poi:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local ring = poi:CreateTexture(nil, "ARTWORK")
    ring:SetSize(32, 32)
    ring:SetPoint("CENTER")
    NA.SetAtlas(ring, "UI-QuestPoi-QuestNumber")
    local glow = poi:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(64, 64)
    glow:SetPoint("CENTER")
    NA.SetAtlas(glow, "UI-QuestPoi-OuterGlow")
    glow:Hide()
    self.glow = glow
    local disc = poi:CreateTexture(nil, "ARTWORK", nil, 1)
    disc:Hide()
    local glyph = poi:CreateTexture(nil, "OVERLAY", nil, 1)
    glyph:SetSize(32, 32)
    glyph:SetPoint("CENTER")
    self.poi = poi
    self.glyph = glyph
    self.ring = ring
    self.disc = disc

    local function onClick(_, button)
        if NA.Actions then NA.Actions.OnClick(self.questID, button) end
    end
    local function onEnter()
        title:SetTextColor(1, 1, 1)
        if NA.Actions then NA.Actions.ShowTooltip(titleBtn, self.quest) end
    end
    local function onLeave()
        title:SetTextColor(1, 0.82, 0)
        if NA.Actions then NA.Actions.HideTooltip() end
    end
    titleBtn:SetScript("OnClick", onClick)
    titleBtn:SetScript("OnEnter", onEnter)
    titleBtn:SetScript("OnLeave", onLeave)
    poi:SetScript("OnClick", function()
        if NA.Actions then NA.Actions.ToggleFocus(self.questID) end
    end)
    poi:SetScript("OnEnter", onEnter)
    poi:SetScript("OnLeave", onLeave)

    return self
end

-- width = how wide the block's text area is (the list width minus the left margin)
function Block:SetData(q, width)
    self.quest = q
    self.questID = q.questID
    width = width or WIDTH
    self.frame:SetWidth(width)

    -- quest item button (right side). Secure: can only change outside combat.
    local item = q.item
    if item and InCombatLockdown() then
        item = nil
        if NA.Tracker then NA.Tracker.deferred = true end
    end
    local inCombat = InCombatLockdown()
    if item then
        if not self.itemSlot then self.itemSlot = NA.QuestItemButton.New(self.frame) end
        self.itemSlot.btn:ClearAllPoints()
        self.itemSlot.btn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
        self.itemSlot.questID = q.questID
        self.itemSlot:Set(item)
    elseif self.itemSlot and not inCombat then
        self.itemSlot:Clear()
    end
    self.hasItem = item ~= nil
    local availW = width - (item and (NA.QuestItemButton.SIZE + 4) or 0)
    self.title:SetWidth(availW)

    -- text size from the options (title and objective lines use the same size)
    local fsz = NA.ListLayout.FontSize()
    local dashW = DASH_WIDTH * fsz / 12
    self.title:SetFont(FONT, fsz, "")
    local label = q.level and string.format("[%d] %s", q.level, q.title) or q.title
    self.title:SetText(label)
    local titleH = math.max(self.title:GetStringHeight(), fsz)

    -- Same art the game uses: normal = yellow glyph on dark ring;
    -- focused = "SuperTracked" ring (yellow inside) + "Brown" glyph (dark dots) + soft outer glow.
    local focused = NA.Actions and NA.Actions.GetFocusedQuestID() == q.questID
    self.disc:Hide()
    self.glyph:SetVertexColor(1, 1, 1)
    if focused then
        NA.SetAtlas(self.ring, "UI-QuestPoi-QuestNumber-SuperTracked", "UI-QuestPoi-QuestNumber")
        self.glow:Show()
        local glyphNames = q.isComplete and { "UI-QuestPoi-QuestBangTurnIn", "UI-QuestIcon-TurnIn-Brown" } or { "Quest-In-Progress-Icon-Brown" }
        local ok, used = NA.SetAtlasFirst(self.glyph, glyphNames)
        NA.focusGlyphAtlas = ok and used or "none (dark tint fallback)"
        if not ok then
            NA.SetAtlas(self.glyph, q.isComplete and "UI-QuestIcon-TurnIn-Normal" or "Quest-In-Progress-Icon-yellow", "Quest-In-Progress-Icon-yellow")
            self.glyph:SetVertexColor(0.25, 0.12, 0)
        end
    else
        NA.SetAtlas(self.ring, "UI-QuestPoi-QuestNumber")
        self.glow:Hide()
        if q.isComplete then
            NA.SetAtlas(self.glyph, "UI-QuestIcon-TurnIn-Normal", "Quest-In-Progress-Icon-yellow")
        else
            NA.SetAtlas(self.glyph, "Quest-In-Progress-Icon-yellow")
        end
    end

    local y = -(titleH + TITLE_GAP)
    local n = #q.lines
    for i = 1, n do
        local o = q.lines[i]
        local line = self.lines[i]
        if not line then
            line = createLine(self.frame)
            self.lines[i] = line
        end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, y)
        line:SetWidth(width)
        line:Show()

        local text = line.text
        text:SetFont(FONT, fsz, "")
        line.dash:SetFont(FONT, fsz, "")
        text:ClearAllPoints()
        if o.plain then
            line.dash:Hide()
            line.check:Hide()
            text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
            text:SetWidth(availW)
            if o.dim then text:SetTextColor(0.6, 0.6, 0.6) else text:SetTextColor(0.8, 0.8, 0.8) end
        else
            text:SetPoint("TOPLEFT", line, "TOPLEFT", dashW, 0)
            text:SetWidth(availW - dashW)
            line.dash:SetShown(not o.finished)
            line.check:SetShown(o.finished)
            if o.finished then text:SetTextColor(0.6, 0.6, 0.6) else text:SetTextColor(0.8, 0.8, 0.8) end
        end
        text:SetText(o.text)
        local h = math.max(text:GetStringHeight(), fsz)
        line:SetHeight(h)
        y = y - h - LINE_GAP
    end
    for i = n + 1, #self.lines do self.lines[i]:Hide() end

    local height = (n > 0) and (-y - LINE_GAP) or titleH
    if item then height = math.max(height, NA.QuestItemButton.SIZE) end
    self.height = height
    self.frame:SetHeight(height)
end

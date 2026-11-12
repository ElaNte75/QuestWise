-- UI: our own quest details window. Opened / closed with the small "i" button next to each quest in
-- the list (UI/QuestBlock.lua). One window: it shows the quest whose button you pressed last.
-- Says what to do (UI/QuestInfo.lua Build), the quest's own text, and its rewards
-- (Data/QuestRewards.lua). Drag it by its title to move it; X or Esc closes it.
-- Settings: questInfoButton (on), questInfoRewards (on), questInfoFont (12), questInfoScale (100),
-- questInfoBackground (on), questInfoOpacity (85), questInfoPos { x, y } (nil = next to the list),
-- questInfoWidth (360) / questInfoHeight (480): the same size for every quest; longer content scrolls.
local ADDON, NA = ...

local Win = {}
NA.QuestInfoWindow = Win

local FONT = "Fonts\\FRIZQT__.TTF"
local PAD = 12
local BAR_ROOM = 12 -- room on the right of the text for the scrollbar
local TILE_H = 36
Win.MIN_FONT, Win.MAX_FONT = 9, 16
Win.MIN_SCALE, Win.MAX_SCALE = 60, 150
-- one fixed size for every quest (the content scrolls when it is longer). The default fits a big
-- quest: title, 4 objectives + quest item, ~6 lines of quest text, 6 rewards to choose from + 1 more,
-- money and experience (more than that scrolls).
Win.MIN_W, Win.MAX_W, Win.DEF_W = 280, 560, 360
Win.MIN_H, Win.MAX_H, Win.DEF_H = 250, 800, 480
local contentW = Win.DEF_W -- width of the text inside (set by layout)

-- colours of the look preset (UI/Theme.lua); filled in place by ApplyLook
local BORDER = { 0.78, 0.64, 0.34, 0.85 }
local DIVIDER = { 0.78, 0.64, 0.34, 0.30 }
local HEAD = { 0.80, 0.66, 0.36 }
local GREY = { 0.62, 0.62, 0.62 }
local dividers = {} -- every divider line, repainted when the preset changes

local f            -- the window (made the first time it opens)
local current      -- the quest table shown now
local pools = {}   -- texts / heads / tiles, reused on every layout

function Win.ButtonOn() return NA.QuestInfo.Enabled() and NA.db.questInfoButton ~= false end
function Win.RewardsOn() return NA.db.questInfoRewards ~= false end
function Win.FontSize()
    local v = tonumber(NA.db.questInfoFont) or 12
    return math.min(math.max(v, Win.MIN_FONT), Win.MAX_FONT)
end
function Win.Scale()
    local v = tonumber(NA.db.questInfoScale) or 100
    return math.min(math.max(v, Win.MIN_SCALE), Win.MAX_SCALE)
end
function Win.Width()
    local v = tonumber(NA.db.questInfoWidth) or Win.DEF_W
    return math.min(math.max(v, Win.MIN_W), Win.MAX_W)
end
function Win.Height()
    local v = tonumber(NA.db.questInfoHeight) or Win.DEF_H
    return math.min(math.max(v, Win.MIN_H), Win.MAX_H)
end
function Win.ShownID() return f and f:IsShown() and current and current.questID or nil end

local function style(fs, size)
    fs:SetFont(FONT, size, "")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
end

-- ------------------------------------------------------------------ pieces (pooled)

local function take(kind, make)
    local p = pools[kind]
    p.used = p.used + 1
    local o = p[p.used]
    if not o then
        o = make()
        p[p.used] = o
    end
    return o
end

local function newText()
    local fs = f.body:CreateFontString(nil, "OVERLAY")
    style(fs, 12)
    return fs
end

local function newHead()
    local h = {}
    h.fs = f.body:CreateFontString(nil, "OVERLAY")
    style(h.fs, 11)
    h.line = f.body:CreateTexture(nil, "ARTWORK")
    h.line:SetColorTexture(unpack(DIVIDER))
    dividers[#dividers + 1] = h.line
    h.line:SetHeight(1)
    function h:Hide() self.fs:Hide(); self.line:Hide() end
    return h
end

local function newTile()
    local b = CreateFrame("Button", nil, f.body)
    b:SetHeight(TILE_H)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.04)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0.3, 0.10)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(TILE_H - 4, TILE_H - 4)
    b.icon:SetPoint("LEFT", 2, 0)
    b.count = b:CreateFontString(nil, "OVERLAY")
    style(b.count, 11)
    b.count:SetJustifyH("RIGHT")
    b.count:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", -1, 2)
    b.name = b:CreateFontString(nil, "OVERLAY")
    style(b.name, 11)
    b.name:SetJustifyV("MIDDLE")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
    b.name:SetPoint("RIGHT", b, "RIGHT", -3, 0)
    b.name:SetHeight(TILE_H - 4)
    b:SetScript("OnEnter", function(self)
        local it = self.item
        if not it then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok = false
        if it.link then ok = pcall(GameTooltip.SetHyperlink, GameTooltip, it.link) end
        if not ok then pcall(GameTooltip.SetQuestLogItem, GameTooltip, it.kind, it.index) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function resetPools()
    for _, p in pairs(pools) do p.used = 0 end
end

local function hideUnused()
    for _, p in pairs(pools) do
        for i = p.used + 1, #p do p[i]:Hide() end
    end
end

-- ------------------------------------------------------------------ layout

local function addText(y, text, color, size, x, width)
    local fs = take("texts", newText)
    style(fs, size)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", f.body, "TOPLEFT", x or 0, y)
    fs:SetWidth(width or contentW)
    fs:SetText(text or "")
    local c = color or { 1, 1, 1 }
    fs:SetTextColor(c[1], c[2], c[3])
    fs:Show()
    return y - math.max(fs:GetStringHeight() or size, size)
end

local function addHead(y, text, color, size)
    local h = take("heads", newHead)
    h.fs:SetFont(FONT, size, "")
    h.fs:ClearAllPoints()
    h.fs:SetPoint("TOPLEFT", f.body, "TOPLEFT", 0, y)
    h.fs:SetText(string.upper(text or ""))
    local c = color or HEAD
    h.fs:SetTextColor(c[1], c[2], c[3])
    h.fs:Show()
    h.line:ClearAllPoints()
    h.line:SetPoint("LEFT", h.fs, "RIGHT", 8, 0)
    h.line:SetPoint("RIGHT", f.body, "RIGHT", 0, 0)
    h.line:Show()
    return y - size - 6
end

-- items in two columns
local function addTiles(y, list, fsz)
    local tw = (contentW - 6) / 2
    for i, it in ipairs(list) do
        local b = take("tiles", newTile)
        b.item = it
        b:SetWidth(tw)
        b:ClearAllPoints()
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        b:SetPoint("TOPLEFT", f.body, "TOPLEFT", col * (tw + 6), y - row * (TILE_H + 4))
        b.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        if it.usable then b.icon:SetVertexColor(1, 1, 1) else b.icon:SetVertexColor(1, 0.3, 0.3) end
        b.count:SetText((it.count or 1) > 1 and tostring(it.count) or "")
        b.name:SetFont(FONT, math.max(fsz - 1, 9), "")
        b.name:SetText(it.name or "?")
        b.name:SetTextColor(NA.QuestRewards.QualityColor(it.quality))
        b:Show()
    end
    local rows = math.ceil(#list / 2)
    return y - rows * (TILE_H + 4)
end

local function addRewards(y, q, fsz)
    local R = NA.QuestRewards
    local r = R and R.Get(q.questID)
    y = y - 6
    y = addHead(y, "Rewards", nil, math.max(fsz - 1, 9))
    if not r then return addText(y, "Can't read the rewards right now", GREY, fsz) end
    if r.empty then return addText(y, "No rewards", GREY, fsz) end
    if #r.choices > 0 then
        y = addText(y, #r.choices > 1 and "Choose one of:" or "You will receive:", GREY, fsz) - 4
        y = addTiles(y, r.choices, fsz)
    end
    if #r.items > 0 then
        if #r.choices > 0 then y = y - 2 end
        y = addText(y, #r.choices > 0 and "You will also receive:" or "You will receive:", GREY, fsz) - 4
        y = addTiles(y, r.items, fsz)
    end
    local money = R.MoneyText(r.money)
    if money then y = addText(y - 2, "Money:  " .. money, { 1, 1, 1 }, fsz) - 2 end
    if r.xp and r.xp > 0 then
        local xp = BreakUpLargeNumbers and BreakUpLargeNumbers(r.xp) or tostring(r.xp)
        y = addText(y - 2, "Experience:  " .. xp, { 0.6, 0.75, 1 }, fsz) - 2
    end
    return y
end

local function layout()
    local q = current
    if not q then return end
    local fsz = Win.FontSize()
    local width, height = Win.Width(), Win.Height()
    f:SetSize(width, height)
    local cw = width - 2 * PAD
    contentW = cw - BAR_ROOM
    resetPools()

    -- header: title in its difficulty colour, level and zone under it
    style(f.title, fsz + 3)
    f.title:SetWidth(cw - 20)
    local titleText = q.title or "?"
    local CQ = NA.ClassQuests
    if CQ and CQ.IsClassQuest(q) then -- class quest: "(Class quest)" in your class colour
        titleText = titleText .. " |c" .. CQ.ClassColorHex() .. "(Class quest)|r"
    end
    f.title:SetText(titleText)
    local tc = NA.QuestColor and NA.QuestColor.For(q) or { 1, 0.82, 0 }
    f.title:SetTextColor(tc[1], tc[2], tc[3])
    local th = math.max(f.title:GetStringHeight() or 0, fsz + 3)
    local parts = {}
    if q.level then parts[#parts + 1] = "Level " .. q.level end
    if q.zone then parts[#parts + 1] = q.zone end
    if q.isComplete then parts[#parts + 1] = "|cff59ff59ready to turn in|r" end
    style(f.sub, math.max(fsz - 1, 9))
    f.sub:SetWidth(cw)
    f.sub:SetText(table.concat(parts, "  -  "))
    f.sub:SetTextColor(GREY[1], GREY[2], GREY[3])
    local sh = math.max(f.sub:GetStringHeight() or 0, fsz - 1)
    local headerH = PAD + th + 3 + sh + 8
    f.header:SetHeight(headerH)

    -- body: the part under the title, scrolls when the quest says more than fits
    f.view:ClearAllPoints()
    f.view:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(headerH + 8))
    f.view:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
    f.scrollOpts.viewH = height - headerH - 8 - PAD
    f.scrollOpts.pageW = contentW
    f.body:SetWidth(contentW)
    local y = 0
    local entries = NA.QuestInfo.Build(q, { window = true })
    for _, e in ipairs(entries) do
        if e.kind == "gap" then
            y = y - 6
        elseif e.kind == "head" then
            y = addHead(y, e.text, e.color, math.max(fsz - 1, 9))
        elseif e.kind == "sub" then
            y = addText(y, e.text, e.color, math.max(fsz - 1, 9)) - 2
        else
            y = addText(y, e.text, e.color, fsz) - 3
        end
    end
    if Win.RewardsOn() then y = addRewards(y - 4, q, fsz) end
    hideUnused()
    f.scroll.SetContentHeight(-y + 4)
end

-- ------------------------------------------------------------------ the window

local function savePos()
    local s = f:GetScale() or 1
    local x, y = f:GetLeft(), f:GetTop()
    if x and y then NA.db.questInfoPos = { x = x * s, y = y * s } end
end

local function place()
    f:ClearAllPoints()
    local pos = NA.db.questInfoPos
    local s = f:GetScale() or 1
    if type(pos) == "table" and pos.x and pos.y then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x / s, pos.y / s)
    elseif QuestSiftTrackerFrame then
        f:SetPoint("TOPRIGHT", QuestSiftTrackerFrame, "TOPLEFT", -40, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", -200, 100)
    end
end

local function build()
    f = CreateFrame("Frame", "QuestSiftInfoWindow", UIParent)
    f:SetSize(Win.DEF_W, Win.DEF_H)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "QuestSiftInfoWindow") end -- Esc closes it

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    -- the gold edge sits on its own layer above everything (the title's background covered it)
    local edge = CreateFrame("Frame", nil, f)
    edge:SetAllPoints()
    edge:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
    f.borders = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = edge:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(unpack(BORDER))
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
        end
        f.borders[#f.borders + 1] = t
    end
    f.edge = NA.Theme and NA.Theme.Edge(f, 25) -- presets with a game border picture

    -- title area (drag here to move)
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(50)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePos() end)
    f.header = header
    f.headerBg = header:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.headerBg:SetAllPoints()
    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(DIVIDER))
    dividers[#dividers + 1] = line
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", PAD, 0)
    line:SetPoint("BOTTOMRIGHT", -PAD, 0)

    f.title = header:CreateFontString(nil, "OVERLAY")
    style(f.title, 15)
    f.title:SetPoint("TOPLEFT", PAD, -PAD)
    f.sub = header:CreateFontString(nil, "OVERLAY")
    style(f.sub, 11)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)

    -- close button: the game's X, or a plain one if this game has no such template
    local ok, close = pcall(CreateFrame, "Button", nil, header, "UIPanelCloseButton")
    if not ok or not close then
        close = CreateFrame("Button", nil, header)
        close:SetSize(20, 20)
        local x = close:CreateFontString(nil, "OVERLAY")
        style(x, 14)
        x:SetPoint("CENTER")
        x:SetText("x")
        x:SetTextColor(1, 0.82, 0.3)
    end
    close:SetSize(18, 18) -- (24 at the very corner looked too big and stuck out - seen in game)
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() Win.Hide() end)

    -- the scrolling part (same thin scrollbar as the options window, UI/Options/Scroll.lua)
    f.view = CreateFrame("Frame", nil, f)
    f.scrollOpts = { left = 0, top = 0, right = BAR_ROOM, bottom = 0, barX = 0,
        pageW = Win.DEF_W - 2 * PAD - BAR_ROOM, viewH = Win.DEF_H - 100 }
    f.scroll = NA.Widgets.ScrollPage(f.view, f.scrollOpts)
    f.body = f.scroll.page
    f.scroll.SetShown(true)

    pools.texts, pools.heads, pools.tiles = { used = 0 }, { used = 0 }, { used = 0 }
    Win.pools = pools -- (read by _tools/mock_run.py)

    -- distance and objectives change while you play: re-read every second while it is open
    local acc = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 1 then return end
        acc = 0
        Win.Refresh()
    end)
    f:SetScript("OnHide", function()
        if NA.Tracker then NA.Tracker.RequestRefresh() end -- the "i" buttons stop glowing
    end)
end

-- looks from the options (scale, background)
function Win.ApplyLook()
    if not f then return end
    f:SetScale(Win.Scale() / 100)
    local on = NA.db.questInfoBackground ~= false
    local a = (tonumber(NA.db.questInfoOpacity) or 85) / 100
    local look = NA.Theme and NA.Theme.Current().info
    if look then
        for i = 1, 4 do
            BORDER[i], DIVIDER[i] = look.border[i], look.divider[i]
            if i <= 3 then HEAD[i], GREY[i] = look.head[i], look.grey[i] end
        end
    end
    local bg, hd = look and look.bg or { 0.055, 0.047, 0.039 }, look and look.header or { 0.095, 0.078, 0.057 }
    if NA.Theme then NA.Theme.PaintPanel(f.bg, "infoBg", bg, on and a or 0)
    else f.bg:SetColorTexture(bg[1], bg[2], bg[3], on and a or 0) end
    f.headerBg:SetColorTexture(hd[1], hd[2], hd[3], on and math.min(a + 0.1, 1) or 0)
    for _, t in ipairs(dividers) do t:SetColorTexture(unpack(DIVIDER)) end
    local framed = f.edge and f.edge:Refresh(on)
    for _, t in ipairs(f.borders) do
        t:SetColorTexture(unpack(BORDER))
        t:SetShown(on and not framed)
    end
    place()
    if f:IsShown() then layout() end
end

-- the newest copy of the quest (the list re-reads quests on every change)
local function fresh(q)
    for _, x in ipairs((NA.Tracker and NA.Tracker.allQuests) or {}) do
        if x.questID == q.questID then return x end
    end
    return q
end

function Win.Refresh()
    if not (f and f:IsShown() and current) then return end
    local i = NA.QuestInfo.LogIndexOf(current.questID)
    if not i or i == 0 then return Win.Hide() end -- handed in or abandoned
    current = fresh(current)
    local ok, err = NA.SafeCall(layout)
    if not ok then NA.LogError(err) end
end

function Win.Show(quest)
    if not quest then return end
    if not f then
        local ok, err = NA.SafeCall(build)
        if not ok then NA.LogError(err); f = nil; return end
    end
    current = quest
    f:Show()
    f.scroll.SetShown(true) -- a new quest starts at the top
    Win.ApplyLook()
    if NA.Tracker then NA.Tracker.RequestRefresh() end -- this quest's "i" button glows
end

function Win.Hide()
    if f then f:Hide() end
end

-- the "i" button: same quest = close, another quest = show that one
function Win.Toggle(quest)
    if not quest then return end
    if Win.ShownID() == quest.questID then Win.Hide() else Win.Show(quest) end
end

function Win.ResetPosition()
    NA.db.questInfoPos = nil
    if f then place() end
end

NA.OnInit(function()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("QUEST_LOG_UPDATE")
    ev:SetScript("OnEvent", function() Win.Refresh() end)
    Win.events = ev
end)

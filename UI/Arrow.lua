-- UI: an arrow on screen that points toward the focused quest (clicked by you or focused by
-- itself), with the distance and the quest name under it.
--   * it points at the quest's spot on the map (the centre of its area - the game gives one point)
--   * hidden when: option off, no focused quest, no position (e.g. dungeons), quest not on this
--     map, or you are within ARRIVE yards (it comes back when you walk away again)
--   * unlock it in Options -> Quest list to drag it; while unlocked it always shows, with an outline
-- Settings: arrowEnabled, arrowLocked, arrowPos {x, y} (centre, screen units from bottom-left).
local ADDON, NA = ...

local A = {}
NA.Arrow = A

local SIZE = 42
local ARRIVE, LEAVE = 30, 40 -- yards: hide under ARRIVE, show again past LEAVE
local TICK = 0.05             -- seconds between updates
local GOLD = { 1, 0.82, 0.30 }

local arrived = false

local function focusedID()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
        if ok and id and id ~= 0 then return id end
    end
    return nil
end

local function questTitle(id)
    if C_QuestLog.GetTitleForQuestID then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
        if ok and t then return t end
    end
    return ""
end

local function facing()
    if not GetPlayerFacing then return nil end
    local ok, f = pcall(GetPlayerFacing)
    if ok then return f end
    return nil
end

function A.IsOn() return NA.db.arrowEnabled ~= false end
function A.IsLocked() return NA.db.arrowLocked ~= false end

function A.ApplyPosition()
    local f = A.frame
    if not f then return end
    f:ClearAllPoints()
    local p = NA.db.arrowPos
    if p and p.x and p.y then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
end

function A.ResetPosition()
    NA.db.arrowPos = nil
    A.ApplyPosition()
end

-- lock state: mouse only while unlocked (locked, it never blocks clicks on the world)
function A.ApplyLook()
    local f = A.frame
    if not f then return end
    local unlocked = not A.IsLocked()
    f:EnableMouse(unlocked)
    for _, e in ipairs(A.edges) do e:SetShown(unlocked) end
    A.Update()
end

local function hide()
    if A.IsLocked() then A.frame:Hide(); return end
    -- unlocked: stay visible so it can be moved
    A.frame:Show()
    A.arrow:SetRotation(0)
    A.arrow:SetAlpha(0.4)
    A.dist:SetText("Arrow")
    A.title:SetText("drag to move")
end

function A.Update()
    local f = A.frame
    if not f then return end
    if not A.IsOn() then f:Hide(); return end

    local id = focusedID()
    if not id then return hide() end
    local ctx = NA.MapInfo.Get()
    local v = ctx.vec and ctx.vec[id]
    local d = ctx.dist and ctx.dist[id]
    local face = facing()
    if not (v and d and face) then return hide() end

    if arrived then
        if d > LEAVE then arrived = false end
    elseif d < ARRIVE then
        arrived = true
    end
    if arrived then return hide() end

    -- bearing to the quest, counter-clockwise from north (map x = east, map y = south),
    -- minus where you face = how much to turn the arrow (it points up = straight ahead)
    local bearing = (math.atan2 or math.atan)(-v[1], -v[2])
    A.arrow:SetRotation(bearing - face)
    A.arrow:SetAlpha(1)
    A.dist:SetText(string.format("%d yd", math.floor(d + 0.5)))
    A.title:SetText(questTitle(id))
    f:Show()
end

NA.OnInit(function()
    local f = CreateFrame("Frame", "QuestWiseArrowFrame", UIParent)
    f:SetSize(SIZE + 80, SIZE + 34)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    A.frame = f

    local arrow = f:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(SIZE, SIZE)
    arrow:SetPoint("TOP", f, "TOP", 0, 0)
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    A.arrow = arrow

    local dist = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dist:SetPoint("TOP", arrow, "BOTTOM", 0, -1)
    dist:SetTextColor(unpack(GOLD))
    A.dist = dist

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOP", dist, "BOTTOM", 0, -2)
    title:SetWidth(220)
    title:SetWordWrap(false)
    A.title = title

    -- thin gold outline while unlocked
    A.edges = {}
    local function edge(a1, a2, w, h)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetPoint(a1, f, a1, 0, 0)
        t:SetPoint(a2, f, a2, 0, 0)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
        A.edges[#A.edges + 1] = t
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if A.IsLocked() then return end
        self.moving = true
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        if not self.moving then return end
        self.moving = false
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local s = self:GetEffectiveScale() / (UIParent:GetEffectiveScale() or 1)
        if x and y then NA.db.arrowPos = { x = x * s, y = y * s } end
        A.ApplyPosition()
    end)

    -- updates run on a separate always-shown frame, so a hidden arrow still notices changes
    local driver = CreateFrame("Frame")
    local acc = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < TICK then return end
        acc = 0
        local ok, err = NA.SafeCall(A.Update)
        if not ok then NA.LogError(err) end
    end)
    A.driver = driver

    A.ApplyPosition()
    A.ApplyLook()
end)

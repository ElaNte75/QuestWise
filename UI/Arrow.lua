-- UI: an arrow on screen that points toward the focused quest (clicked by you or focused by
-- itself), with the distance and the quest name under it.
--   * it points at the quest's spot on the map (the centre of its area - the game gives one point)
--   * hidden when: option off, no focused quest, no position (e.g. dungeons), quest not on this
--     map, or you "arrived": got within arrowArriveYards OR the quest moved on (counted kill,
--     looted item, quest item used). It comes back only when you are farther than
--     arrowReturnYards AND nothing happened for that quest for arrowWaitSeconds.
--   * the quest's blue map area (UI/QuestArea.lua, option arrowUseArea): hidden while you are in it
--     or within arrowAreaYards of it; back as soon as you are farther from it
--   * unlock it in Options -> Quest list to drag it; while unlocked it always shows, with an outline
-- Settings: arrowEnabled, arrowLocked, arrowPos {x, y} (centre, screen units from bottom-left),
--   arrowStyle (STYLES key), arrowSize (px), arrowColor (COLORS key).
-- Hidden in combat: UI/ArrowCombat.lua. Dead: leads to your corpse (UI/ArrowCorpse.lua).
-- Our arrow pictures are white (Textures/Arrow_*.tga, made by _tools/make_arrows.py) and get
-- tinted with the chosen colour; new picture files need a full game restart.
local ADDON, NA = ...

local A = {}
NA.Arrow = A

local DEFAULT_SIZE, MIN_SIZE, MAX_SIZE = 42, 24, 96
local TEX = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\Arrow_"

A.STYLES = {
    { key = "Game",    label = "Game arrow", path = "Interface\\Minimap\\MinimapArrow", game = true },
    { key = "Classic", label = "Classic", path = TEX .. "Classic" },
    { key = "Chevron", label = "Chevron", path = TEX .. "Chevron" },
    { key = "Block",   label = "Block",   path = TEX .. "Block" },
    { key = "Double",  label = "Double",  path = TEX .. "Double" },
    { key = "Slim",    label = "Slim",    path = TEX .. "Slim" },
    { key = "Needle",  label = "Needle",  path = TEX .. "Needle" },
}
-- "Default": our arrows gold, the game arrow with its own colours
A.COLORS = {
    { key = "Default", label = "Default" },
    { key = "Gold",    label = "Gold",   rgb = { 1, 0.82, 0.30 } },
    { key = "Yellow",  label = "Yellow", rgb = { 1, 1, 0.25 } },
    { key = "Orange",  label = "Orange", rgb = { 1, 0.55, 0.10 } },
    { key = "Red",     label = "Red",    rgb = { 1, 0.25, 0.20 } },
    { key = "Green",   label = "Green",  rgb = { 0.30, 1, 0.30 } },
    { key = "Blue",    label = "Blue",   rgb = { 0.35, 0.65, 1 } },
    { key = "Purple",  label = "Purple", rgb = { 0.75, 0.45, 1 } },
    { key = "White",   label = "White",  rgb = { 1, 1, 1 } },
}
local DEFAULT_ARRIVE = 30    -- yards: hide when this close to the quest's spot (option arrowArriveYards)
local DEFAULT_RETURN = 150   -- yards: ...and show again only past this (option arrowReturnYards)
local TICK = 0.05             -- seconds between updates
local GOLD = { 1, 0.82, 0.30 }

local DEFAULT_WAIT = 60      -- seconds without progress before it may come back (option arrowWaitSeconds)

local state = {}    -- [questID] = { arrived = bool, active = time of the last progress / visit }
local progress = {} -- [questID] = sum of done objective counts, to notice progress
local doneBefore = {} -- [questID] = was it ready to turn in at the last check?

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

local function inDungeon() -- dungeon, raid, battleground, arena, scenario (Data/DungeonFilter.lua)
    return NA.DungeonFilter ~= nil and NA.DungeonFilter.InInstance()
end

local function facing()
    if not GetPlayerFacing then return nil end
    local ok, f = pcall(GetPlayerFacing)
    if ok then return f end
    return nil
end

function A.IsOn() return NA.db.arrowEnabled ~= false end
local function find(list, key)
    for _, it in ipairs(list) do if it.key == key then return it end end
    return list[1]
end
function A.Size() return math.min(math.max(NA.db.arrowSize or DEFAULT_SIZE, MIN_SIZE), MAX_SIZE) end

-- picture, size and colour from the settings
function A.ApplyStyle()
    local f, arrow = A.frame, A.arrow
    if not f then return end
    local style = find(A.STYLES, NA.db.arrowStyle or "Game")
    local color = find(A.COLORS, NA.db.arrowColor or "Default")
    arrow:SetTexture(style.path)
    local rgb = color.rgb or (not style.game and GOLD) or { 1, 1, 1 }
    arrow:SetVertexColor(rgb[1], rgb[2], rgb[3])
    local size = A.Size()
    arrow:SetSize(size, size)
    f:SetSize(math.max(size, 80) + 40, size + 34)
end

function A.ArriveYards() return NA.db.arrowArriveYards or DEFAULT_ARRIVE end
function A.ReturnYards() return NA.db.arrowReturnYards or DEFAULT_RETURN end
function A.WaitSeconds() return NA.db.arrowWaitSeconds or DEFAULT_WAIT end

-- Something was done for this quest (objective went up, quest item used): you are there.
function A.Activity(questID, why)
    if not questID then return end
    local s = state[questID]
    state[questID] = { arrived = true, active = GetTime() }
end

local function progressOf(questID)
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objs) ~= "table" then return nil end
    local n = 0
    for _, o in ipairs(objs) do
        n = n + (tonumber(o.numFulfilled) or 0) + (o.finished and 1 or 0)
    end
    return n
end

local function isComplete(questID)
    local ok, v = pcall(C_QuestLog.IsComplete, questID)
    return ok and v and true or false
end

-- quest log changed: did the focused quest move on?
-- Done (ready to turn in) = a NEW place to go (where you hand it in): guide again from scratch.
local function checkProgress()
    local id = focusedID()
    if not id then return end
    local n = progressOf(id)
    if not n then return end
    local before = progress[id]
    local done = isComplete(id)
    local wasDone = doneBefore[id]
    progress[id], doneBefore[id] = n, done
    if done and wasDone == false then
        state[id] = nil
    elseif not done and before and n > before then
        A.Activity(id, "progress")
    end
end
A.CheckProgress = checkProgress

-- focus changed: one YOU chose (not the automatic one) always starts guiding from scratch
local function onFocusChanged()
    local id = focusedID()
    if not id then return end
    local AF = NA.AutoFocus
    if not (AF and AF.LastSet and AF.LastSet() == id) then
        state[id] = nil
    end
    checkProgress()
end
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
    -- dead: lead to your corpse instead (UI/ArrowCorpse.lua); not released yet = nothing to show.
    -- Checked before the combat hiding: dying ends the fight, and the corpse arrow must not wait for it.
    local C = NA.ArrowCorpse
    if C and C.IsDead() then
        local t = C.IsOn() and C.Target()
        local face = facing()
        if not (t and face) or t.dist < C.HideYards() then return hide() end
        return A.PointTo(t.vec, t.dist, face, "Your corpse")
    end
    -- in combat (and the wait after it, if chosen): hidden - UI/ArrowCombat.lua
    if NA.ArrowCombat and NA.ArrowCombat.IsHiding() then f:Hide(); return end
    -- flying / in a major city: hidden - Quests/Quiet.lua
    if NA.Quiet and NA.Quiet.Arrow() then f:Hide(); return end
    if inDungeon() then f:Hide(); return end -- never inside a dungeon / raid, not even for your own focus

    local id = focusedID()
    if not id then return hide() end
    local ctx = NA.MapInfo.Get()
    local v = ctx.vec and ctx.vec[id]
    local d = ctx.dist and ctx.dist[id]
    local face = facing()
    if not (v and d and face) then return hide() end

    -- "arrived" = you got close to its spot OR the quest moved on (A.Activity); remembered per quest.
    -- It comes back only when you are far away AND nothing happened for that quest for a while.
    local s = state[id]
    local now = GetTime()
    -- inside the quest's blue map area or near it (UI/QuestArea.lua): you are there, hidden.
    -- Arrived that way, it comes back as soon as you are farther from the area than the margin.
    local QA = NA.QuestArea
    local near = QA and QA.Near(id)
    if near then
        state[id] = { arrived = true, active = now, byArea = true }
        return hide()
    end
    if near == false and s and s.arrived and s.byArea then
        s.arrived = false
    end
    if d < A.ArriveYards() then
        s = { arrived = true, active = now }
        state[id] = s
    end
    if s and s.arrived then
        if d > math.max(A.ReturnYards(), A.ArriveYards() + 10) and now - s.active > A.WaitSeconds() then
            s.arrived = false
        else
            return hide()
        end
    end

    -- bearing to the quest, counter-clockwise from north (map x = east, map y = south),
    -- minus where you face = how much to turn the arrow (it points up = straight ahead)
    A.PointTo(v, d, face, questTitle(id))
end

-- turn the arrow toward v = {dx east, dy south} (yards), show the distance d and a name
function A.PointTo(v, d, face, name)
    local bearing = (math.atan2 or math.atan)(-v[1], -v[2])
    A.arrow:SetRotation(bearing - face)
    A.arrow:SetAlpha(1)
    A.dist:SetText(string.format("%d yd", math.floor(d + 0.5)))
    A.title:SetText(name)
    A.frame:Show()
end

NA.OnInit(function()
    local f = CreateFrame("Frame", "QuestWiseArrowFrame", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    A.frame = f

    local arrow = f:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("TOP", f, "TOP", 0, 0)
    A.arrow = arrow -- picture, size and colour: A.ApplyStyle()

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

    -- quest progress (a counted kill, an item looted...) = you are at the quest
    local ev = CreateFrame("Frame")
    for _, name in ipairs({ "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "SUPER_TRACKING_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, name)
    end
    ev:SetScript("OnEvent", function(_, event)
        if event == "SUPER_TRACKING_CHANGED" then NA.SafeCall(onFocusChanged)
        else NA.SafeCall(checkProgress) end
    end)
    A.events = ev

    A.ApplyStyle()
    A.ApplyPosition()
    A.ApplyLook()
end)

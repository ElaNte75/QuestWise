-- Mobs: puts a small quest icon on the nameplate of enemies that belong to one of your active quests.
-- Only works for mobs the game has loaded around you (nameplate range).
local ADDON, NA = ...

local Marker = {}
NA.QuestMobMarker = Marker

local ICON_SIZE = 16
local ICON_ATLASES = { "QuestNormal", "Quest-In-Progress-Icon-yellow" }

local pending = false

-- Quests seen "nearby": title -> time a mob of that quest was last seen around you.
local NEAR_SECONDS = 30
local near = {}

-- how long a quest stays "nearby" after its mob went out of sight (setting on the Quest list page)
local function keepSeconds()
    return math.min(tonumber(NA.db.keepSeconds) or NEAR_SECONDS, 120)
end

-- Is the quest of a mob you found still counted as "here"? (off = quests are never added because of mobs)
-- dead or a ghost: no scanning, no marks, no sound, no "near" quests until you are alive again
local function playerDead()
    if type(UnitIsDeadOrGhost) ~= "function" then return false end
    local ok, v = pcall(UnitIsDeadOrGhost, "player")
    return ok and v and true or false
end
Marker.PlayerDead = playerDead

-- dead, flying, or in a major city (Quests/Quiet.lua): no scanning, marks, sound or "near" quests
local function quiet()
    return playerDead() or (NA.Quiet ~= nil and NA.Quiet.Mobs())
end

function Marker.IsQuestNear(title)
    if NA.db.mobAddsQuest == false or quiet() then return false end
    local t = title and near[title]
    return t ~= nil and (GetTime() - t) <= keepSeconds()
end

-- Units (nameplate tokens) we currently know belong to a quest: unit -> { guid, titles }.
-- While such a mob is still around, its quest keeps counting as "nearby".
local relatedUnits = {}

-- Short sound when you first see a mob of a quest that is not in your list right now.
local SOUND_COOLDOWN = 10
local lastSound = 0
-- the sound and volume chosen on the "Quest mobs" page
Marker.SOUND_KIT = "UI_QUEST_ROLLING_FORWARD_01" -- what "Game default" means here
local function playSound()
    NA.Sound.Play(NA.db.soundChoice, NA.db.soundVolume, Marker.SOUND_KIT)
end

function Marker.TestSound()
    playSound()
end

local function alertSound()
    if not NA.db.soundQuestMob then return end
    local now = GetTime()
    if now - lastSound < SOUND_COOLDOWN then return end
    lastSound = now
    playSound()
end

-- Mob already tapped by someone else (grey name: killing it gives you nothing)?
-- Such a mob keeps its mark but does not add its quest to the list or play the sound.
local function ignoredAsTapped(unit)
    if NA.db.ignoreTapped == false or not UnitIsTapDenied then return false end
    local ok, tapped = pcall(UnitIsTapDenied, unit)
    return ok and tapped and true or false
end

local function noteNear(titles)
    local changed = false
    local now = GetTime()
    for _, title in ipairs(titles) do
        if not Marker.IsQuestNear(title) then
            changed = true
            if not (NA.Tracker and NA.Tracker.IsVisible(title)) then alertSound() end
        end
        near[title] = now
    end
    if changed and NA.Tracker then NA.Tracker.RequestRefresh() end
end

-- Reads the unit's tooltip. Returns a list of { title, fractions, open } (one per quest the
-- tooltip names; "open" counts objective lines like 3/10 that are not finished) and the raw lines.
local function readTooltip(unit)
    local quests, raw = {}, {}
    if C_TooltipInfo and C_TooltipInfo.GetUnit and Enum and Enum.TooltipDataLineType then
        local okT, data = pcall(C_TooltipInfo.GetUnit, unit)
        if okT and type(data) == "table" and data.lines then
            local QT = Enum.TooltipDataLineType.QuestTitle
            local cur
            for _, line in ipairs(data.lines) do
                local text = line.leftText
                if #raw < 12 then raw[#raw + 1] = tostring(line.type) .. ": " .. tostring(text) end
                if line.type == QT and text then
                    cur = { title = text, fractions = 0, open = 0 }
                    quests[#quests + 1] = cur
                elseif cur and text then
                    local a, b = text:match("(%d+)%s*/%s*(%d+)")
                    if a then
                        cur.fractions = cur.fractions + 1
                        if tonumber(a) < tonumber(b) then
                            cur.open = cur.open + 1
                            cur.progress = cur.progress or (a .. "/" .. b) -- shown next to the mark (Mobs/MobLook.lua)
                        end
                    end
                end
            end
        end
    end
    return quests, raw
end

local function trackedQuest(title)
    local all = NA.Tracker and NA.Tracker.allQuests
    if not all then return nil end
    for _, q in ipairs(all) do
        if q.title == title then return q end
    end
    return nil
end

-- Does this quest still need this kind of mob? (never "no" when unsure)
local function stillNeeded(t, unitName)
    if t.fractions > 0 then return t.open > 0 end -- tooltip shows progress: trust it
    local q = trackedQuest(t.title)
    if q then
        if q.isComplete then return false end
        local name = unitName and unitName:lower()
        local matched, open = 0, 0
        for _, line in ipairs(q.lines) do
            if name and line.text:lower():find(name, 1, true) then
                matched = matched + 1
                if not line.finished then open = open + 1 end
            end
        end
        if matched > 0 then return open > 0 end
    end
    return true
end

-- Is this unit part of a quest that still needs it? Returns bool, method, open quest titles, raw tooltip.
local function isQuestMob(unit)
    local quests, raw = readTooltip(unit)
    if #quests > 0 then
        local name = UnitName(unit)
        local titles = {}
        for _, t in ipairs(quests) do
            if stillNeeded(t, name) then titles[#titles + 1] = t.title end
        end
        return #titles > 0, "tooltip", titles, raw, quests
    end
    if C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok, r = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok and r then return true, "api", {}, raw end
    end
    return false, "none", {}, raw
end

local function getPlate(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then return nil end
    if plate.IsForbidden and plate:IsForbidden() then return nil end
    return plate
end

local function healthBarOf(uf)
    return uf and (uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar))
end

-- Two independent settings (Quest mobs page):
--   markQuestMobs   = put a quest mark on quest mobs
--   showNameplates  = show the game's nameplates (health bars) on enemies
-- Mark on + nameplates off = "name only": the game's plates are made invisible and the quest
-- mobs get just their name with the mark next to it.
local function nameOnly()
    return NA.db.markQuestMobs and not NA.db.showNameplates
end

-- Our own little overlay on each plate (a child of the plate itself, so it stays visible
-- even when the game's plate drawing is made invisible): the mark and, in name-only mode, the name.
local overlays = {}
local function getOverlay(plate)
    local o = overlays[plate]
    if o then return o end
    local f = CreateFrame("Frame", nil, plate)
    f:SetSize(1, 1)
    f:SetPoint("CENTER", plate, "CENTER", 0, 0)
    f:SetFrameLevel((plate:GetFrameLevel() or 1) + 10)
    local icon = f:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    NA.SetAtlasFirst(icon, ICON_ATLASES)
    local name = f:CreateFontString(nil, "OVERLAY")
    name:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    name:SetPoint("CENTER", f, "CENTER", 0, 0)
    -- quest progress (e.g. 3/10) on the left of the mark, its right end tucked close to the "!"
    -- (the "!" is thin in the middle of its square, so +4 reaches into the empty side); longer numbers grow leftwards
    local progress = f:CreateFontString(nil, "OVERLAY")
    progress:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    progress:SetPoint("RIGHT", icon, "LEFT", 4, 0)
    o = { frame = f, icon = icon, name = name, progress = progress }
    overlays[plate] = o
    return o
end

-- the mark's colour by difficulty and the progress text (Mobs/MobLook.lua)
local function styleMark(o, unit, quests, titles)
    local ML = NA.MobLook
    local c = ML and ML.ColorFor(unit)
    o.icon:SetDesaturated(c ~= nil)
    if c then o.icon:SetVertexColor(c[1], c[2], c[3]) else o.icon:SetVertexColor(1, 1, 1) end
    local text = ML and ML.ProgressFor(unit, quests, titles)
    if text then
        o.progress:SetText(text)
        if c then o.progress:SetTextColor(c[1], c[2], c[3]) else o.progress:SetTextColor(1, 0.82, 0) end
        o.progress:Show()
    else
        o.progress:Hide()
    end
end

local function showMark(plate, unit, quests, titles)
    local o = getOverlay(plate)
    styleMark(o, unit, quests, titles)
    o.icon:ClearAllPoints()
    if nameOnly() then
        local r, g, b = 1, 0.15, 0.15
        if UnitSelectionColor then r, g, b = UnitSelectionColor(unit) end
        o.name:SetTextColor(r or 1, g or 0.15, b or 0.15)
        o.name:SetText(UnitName(unit) or "")
        o.name:Show()
        o.icon:SetPoint("RIGHT", o.name, "LEFT", -3, 0)
    else
        o.name:Hide()
        -- the level badge sits on the right of the bar, so the mark goes on the left
        local uf = plate.UnitFrame
        o.icon:SetPoint("RIGHT", healthBarOf(uf) or uf or plate, "LEFT", -3, 0)
    end
    o.icon:Show()
end

local function hideMark(plate)
    local o = overlays[plate]
    if o then o.icon:Hide(); o.name:Hide(); o.progress:Hide() end
end

-- In name-only mode the game's own plate drawing is kept invisible (and made invisible again
-- if the game tries to fade it back in). Outside that mode we give back what we hid.
local hiddenFrames, hooked = {}, {}
local function applyPlateMode(plate)
    local uf = plate.UnitFrame
    if not uf then return end
    if nameOnly() then
        if not hooked[uf] then
            hooked[uf] = true
            hooksecurefunc(uf, "SetAlpha", function(self, a)
                if nameOnly() and a ~= 0 then self:SetAlpha(0) end
            end)
        end
        hiddenFrames[uf] = true
        uf:SetAlpha(0)
    elseif hiddenFrames[uf] then
        hiddenFrames[uf] = nil
        uf:SetAlpha(1)
    end
end

function Marker.UpdateUnit(unit)
    if not unit or not UnitExists(unit) then return end
    local plate = getPlate(unit)
    if not plate then return end
    applyPlateMode(plate)
    local related, method, titles, raw, quests = false, "off", {}, {}, nil
    if NA.db.markQuestMobs and not quiet() and UnitCanAttack("player", unit) and not UnitIsPlayer(unit) and not UnitIsDead(unit) then
        related, method, titles, raw, quests = isQuestMob(unit)
    end
    local counts = related and not ignoredAsTapped(unit)
    relatedUnits[unit] = (counts and #titles > 0) and { guid = UnitGUID(unit), titles = titles } or nil
    if related then
        if counts then noteNear(titles) end
        showMark(plate, unit, quests, titles)
    else
        hideMark(plate)
    end
end

function Marker.RefreshAll()
    pending = false
    for i = 1, 40 do Marker.UpdateUnit("nameplate" .. i) end
end

local function requestRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function() NA.SafeCall(Marker.RefreshAll) end)
end
Marker.RequestRefresh = requestRefresh

NA.OnInit(function()
    -- every few seconds: quests whose mob is still around stay "nearby"; quests whose mobs are
    -- gone are dropped once the keep time has passed (and the list is refreshed when that happens)
    C_Timer.NewTicker(3, function()
        local now = GetTime()
        for unit, info in pairs(relatedUnits) do
            if not quiet() and UnitExists(unit) and UnitGUID(unit) == info.guid and not UnitIsDead(unit)
                and not ignoredAsTapped(unit) then
                for _, title in ipairs(info.titles) do near[title] = now end
            else
                relatedUnits[unit] = nil
            end
        end
        local expired = false
        for title in pairs(near) do
            if not Marker.IsQuestNear(title) then near[title] = nil; expired = true end
        end
        if expired and NA.Tracker then NA.Tracker.RequestRefresh() end
    end)

    local ev = CreateFrame("Frame")
    for _, name in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
                            "UNIT_FLAGS", "UNIT_DYNAMIC_FLAGS", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
        pcall(ev.RegisterEvent, ev, name)
    end
    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_FLAGS" or event == "UNIT_DYNAMIC_FLAGS" then
            -- a mob got tapped or freed again: look at it again (nameplate mobs only)
            if type(unit) == "string" and unit:find("^nameplate") then NA.SafeCall(Marker.UpdateUnit, unit) end
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            NA.SafeCall(Marker.UpdateUnit, unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            relatedUnits[unit] = nil
            local plate = getPlate(unit)
            if plate then hideMark(plate) end
        else
            requestRefresh()
        end
    end)
end)

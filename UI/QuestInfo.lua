-- UI: what we say about a quest, in a few words: each objective as an action (kill / collect / use /
-- do) with its count, the quest item to use, how far the quest is, whether a mob of it is near, and
-- when it is done where to go. Only what the game gives us (no database of places or mobs).
-- Info.Build(quest) makes the list of lines once; two places show it:
--   - the small box when the mouse is over a quest in our list (game tooltip, Info.Show) - option
--     questInfoHover
--   - our own window (UI/QuestInfoWindow.lua), opened with the "i" button next to each quest
local ADDON, NA = ...

local Info = {}
NA.QuestInfo = Info

local GOLD = { 1, 0.82, 0 }
local GREY = { 0.62, 0.62, 0.62 }
local WHITE = { 1, 1, 1 }
local GREEN = { 0.35, 1, 0.35 }
local BLUE = { 0.55, 0.78, 1 }
local ORANGE = { 1, 0.55, 0.1 }
Info.COLORS = { gold = GOLD, grey = GREY, white = WHITE, green = GREEN, blue = BLUE, orange = ORANGE }
local MAX_NOTES = 220 -- characters of the game's own quest text in the small box (the window shows all)

local function icon(path) return "|T" .. path .. ":0:0:0:0|t " end
local ICONS = {
    monster = icon("Interface\\CURSOR\\Attack"),
    item = icon("Interface\\CURSOR\\Pickup"),
    object = icon("Interface\\CURSOR\\Interact"),
    event = icon("Interface\\CURSOR\\Interact"),
    talk = icon("Interface\\CURSOR\\Speak"),
    other = icon("Interface\\CURSOR\\Point"),
    done = icon("Interface\\RaidFrame\\ReadyCheck-Ready"),
    turnin = icon("Interface\\GossipFrame\\ActiveQuestIcon"),
}
local VERB = { monster = "Kill", item = "Collect", object = "Use", event = "Do" }

function Info.Enabled() return NA.db.questInfoEnabled ~= false end -- the whole feature (Options: Enable quest info)
function Info.HoverOn() return Info.Enabled() and NA.db.questInfoHover ~= false end

local function logIndexOf(questID)
    local QL = C_QuestLog
    if QL.GetLogIndexForQuestID then
        local ok, i = pcall(QL.GetLogIndexForQuestID, questID)
        if ok then return i end
    end
    return nil
end
Info.LogIndexOf = logIndexOf

local function questNotes(logIndex, maxLen)
    if not (logIndex and type(GetQuestLogQuestText) == "function") then return nil end
    local ok, _, objectives = pcall(GetQuestLogQuestText, logIndex)
    if not ok or type(objectives) ~= "string" or objectives == "" then return nil end
    objectives = objectives:gsub("%s+", " ")
    if maxLen and #objectives > maxLen then objectives = objectives:sub(1, maxLen):gsub("%s%S*$", "") .. "..." end
    return objectives
end

local function completionText(logIndex)
    if not (logIndex and type(GetQuestLogCompletionText) == "function") then return nil end
    local ok, text = pcall(GetQuestLogCompletionText, logIndex)
    if ok and type(text) == "string" and text ~= "" then return text end
    return nil
end

-- "Plainstrider slain: 3/8" -> "Plainstrider", 3, 8 (kept as it is when it doesn't look like that)
local function splitObjective(o)
    local text = o.text or ""
    local name, have, need = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
    if not name then
        have, need, name = text:match("^%s*(%d+)%s*/%s*(%d+)%s+(.+)$")
    end
    have = tonumber(have) or tonumber(o.numFulfilled)
    need = tonumber(need) or tonumber(o.numRequired)
    if not name or name == "" then return text, nil, nil end
    name = name:gsub("%s+[Ss]lain$", ""):gsub("%s+[Kk]illed$", "")
    return name, have, need
end

-- the lines about a quest: { kind = "title"|"sub"|"head"|"line"|"gap"|"hint", text, right, color, wrap }
-- opts.window = for our window (full quest text, no click hints, no title line: the window has its own)
function Info.Build(quest, opts)
    opts = opts or {}
    local out = {}
    local function add(kind, text, color, extra)
        local e = extra or {}
        e.kind, e.text, e.color = kind, text, color
        out[#out + 1] = e
    end
    local id = quest.questID
    local logIndex = logIndexOf(id)

    -- title + level / zone
    local right = {}
    if quest.level then right[#right + 1] = "Level " .. quest.level end
    if quest.zone then right[#right + 1] = quest.zone end
    if not opts.window then
        add("title", quest.title, GOLD, { right = table.concat(right, " - ") })
    end

    -- how far, and is something of it right here
    local ctx = NA.MapInfo and NA.MapInfo.Get() or {}
    local d = ctx.dist and ctx.dist[id]
    local near = not quest.isComplete and NA.QuestMobMarker and NA.QuestMobMarker.IsQuestNear(quest.title)
    if near then
        add("sub", "A mob of this quest is near you", ORANGE)
    elseif d then
        local where = quest.isComplete and "where you hand it in" or "middle of the quest area"
        add("sub", string.format("About %d yd away (%s)", math.floor(d + 0.5), where), GREY)
    elseif opts.window then
        add("sub", "Not on this map", GREY)
    end

    if quest.isComplete then
        add("gap")
        add("head", "Done", GREEN)
        add("line", ICONS.turnin .. "Go back and hand it in", GREEN, { wrap = true })
        local text = completionText(logIndex)
        if text then add("line", text, WHITE, { wrap = true }) end
    else
        add("gap")
        add("head", "What to do", GOLD)
        local ok, objs = pcall(C_QuestLog.GetQuestObjectives, id)
        local any = false
        if ok and type(objs) == "table" then
            for _, o in ipairs(objs) do
                if o.text and o.text ~= "" then
                    any = true
                    local kind = VERB[o.type] and o.type or "other"
                    local name, have, need = splitObjective(o)
                    local count = (have and need and need > 1) and string.format("  %d/%d", have, need) or ""
                    local line = (VERB[kind] and (VERB[kind] .. ": ") or "") .. name .. count
                    if o.finished then
                        add("line", ICONS.done .. line, GREEN, { wrap = true })
                    else
                        add("line", ICONS[kind] .. line, WHITE, { wrap = true })
                    end
                end
            end
        end
        if not any then
            local notes = questNotes(logIndex, MAX_NOTES)
            if notes then add("line", ICONS.other .. notes, WHITE, { wrap = true }) end
        end
        if quest.item and quest.item.link then
            local pic = quest.item.icon and ("|T" .. quest.item.icon .. ":0:0:0:0|t ") or ""
            add("line", pic .. "Use " .. quest.item.link .. " (button next to the quest)", BLUE, { wrap = true })
        end
        -- the game's own short text, as a reminder of the story
        local notes = questNotes(logIndex, not opts.window and MAX_NOTES or nil)
        if notes then
            add("gap")
            if opts.window then add("head", "The quest", GOLD) end
            add("line", notes, GREY, { wrap = true })
        end
    end

    if not opts.window then
        add("gap")
        local hint = "Click: quest log   Shift-click: stop tracking   Circle: focus"
        if NA.QuestInfoWindow and NA.QuestInfoWindow.ButtonOn() then hint = hint .. "   i: details" end
        add("hint", hint, { 0.5, 0.5, 0.5 })
    end
    return out
end

-- the small box (game tooltip)
function Info.Fill(tt, quest)
    for _, e in ipairs(Info.Build(quest)) do
        local c = e.color or WHITE
        if e.kind == "title" then
            tt:AddDoubleLine(e.text, e.right, c[1], c[2], c[3], GREY[1], GREY[2], GREY[3])
        elseif e.kind == "gap" then
            tt:AddLine(" ")
        else
            tt:AddLine(e.text, c[1], c[2], c[3], e.wrap and true or false)
        end
    end
end

-- owner: the quest's title (or circle); the box opens to the left of the list
function Info.Show(owner, quest)
    if not quest or not Info.HoverOn() then return end
    local tt = GameTooltip
    tt:SetOwner(owner, "ANCHOR_NONE")
    tt:ClearAllPoints()
    tt:SetPoint("TOPRIGHT", owner, "TOPLEFT", -34, 6)
    local ok, err = NA.SafeCall(Info.Fill, tt, quest)
    if not ok then NA.LogError(err) end
    tt:Show()
end

function Info.Hide()
    if Info.HoverOn() then GameTooltip:Hide() end
end

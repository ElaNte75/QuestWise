-- UI: the info box shown when the mouse is over a quest in our list (game tooltip style).
-- Says in a few words what to do: each objective as an action (kill / collect / use / do) with
-- its count, the quest item to use, how far the quest is, whether a mob of it is near, and when
-- it is done where to go. Only what the game gives us (no database of places or mobs).
local ADDON, NA = ...

local Info = {}
NA.QuestInfo = Info

local GOLD = { 1, 0.82, 0 }
local GREY = { 0.62, 0.62, 0.62 }
local WHITE = { 1, 1, 1 }
local GREEN = { 0.35, 1, 0.35 }
local BLUE = { 0.55, 0.78, 1 }
local MAX_NOTES = 220 -- characters of the game's own quest text we show

local function icon(path) return "|T" .. path .. ":15:15:0:0|t " end
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

local function logIndexOf(questID)
    local QL = C_QuestLog
    if QL.GetLogIndexForQuestID then
        local ok, i = pcall(QL.GetLogIndexForQuestID, questID)
        if ok then return i end
    end
    return nil
end

local function questNotes(logIndex)
    if not (logIndex and type(GetQuestLogQuestText) == "function") then return nil end
    local ok, _, objectives = pcall(GetQuestLogQuestText, logIndex)
    if not ok or type(objectives) ~= "string" or objectives == "" then return nil end
    objectives = objectives:gsub("%s+", " ")
    if #objectives > MAX_NOTES then objectives = objectives:sub(1, MAX_NOTES):gsub("%s%S*$", "") .. "..." end
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

local function addObjectives(tt, questID)
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objs) ~= "table" or #objs == 0 then return false end
    for _, o in ipairs(objs) do
        if o.text and o.text ~= "" then
            local kind = VERB[o.type] and o.type or "other"
            local name, have, need = splitObjective(o)
            local count = (have and need and need > 1) and string.format("  %d/%d", have, need) or ""
            local line = (VERB[kind] and (VERB[kind] .. ": ") or "") .. name .. count
            if o.finished then
                tt:AddLine(ICONS.done .. line, GREEN[1], GREEN[2], GREEN[3], true)
            else
                tt:AddLine(ICONS[kind] .. line, WHITE[1], WHITE[2], WHITE[3], true)
            end
        end
    end
    return true
end

-- quest: the table from Data/QuestSource.lua
function Info.Fill(tt, quest)
    local id = quest.questID
    local logIndex = logIndexOf(id)

    -- title + level / zone
    local right = {}
    if quest.level then right[#right + 1] = "Level " .. quest.level end
    if quest.zone then right[#right + 1] = quest.zone end
    tt:AddDoubleLine(quest.title, table.concat(right, " - "), GOLD[1], GOLD[2], GOLD[3], GREY[1], GREY[2], GREY[3])

    -- how far, and is something of it right here
    local ctx = NA.MapInfo and NA.MapInfo.Get() or {}
    local d = ctx.dist and ctx.dist[id]
    local near = not quest.isComplete and NA.QuestMobMarker and NA.QuestMobMarker.IsQuestNear(quest.title)
    if near then
        tt:AddLine("A mob of this quest is near you", 1, 0.55, 0.1)
    elseif d then
        local where = quest.isComplete and "where you hand it in" or "middle of the quest area"
        tt:AddLine(string.format("About %d yd away (%s)", math.floor(d + 0.5), where), GREY[1], GREY[2], GREY[3])
    end

    tt:AddLine(" ")
    if quest.isComplete then
        tt:AddLine(ICONS.turnin .. "Done - go back and hand it in", GREEN[1], GREEN[2], GREEN[3], true)
        local text = completionText(logIndex)
        if text then tt:AddLine(text, WHITE[1], WHITE[2], WHITE[3], true) end
    else
        tt:AddLine("What to do", GOLD[1], GOLD[2], GOLD[3])
        if not addObjectives(tt, id) then
            local notes = questNotes(logIndex)
            if notes then tt:AddLine(ICONS.other .. notes, WHITE[1], WHITE[2], WHITE[3], true) end
        end
        if quest.item and quest.item.link then
            local pic = quest.item.icon and ("|T" .. quest.item.icon .. ":15:15:0:0|t ") or ""
            tt:AddLine(pic .. "Use " .. quest.item.link .. " (button next to the quest)", BLUE[1], BLUE[2], BLUE[3], true)
        end
        -- the game's own short text, as a reminder of the story
        local notes = questNotes(logIndex)
        if notes then
            tt:AddLine(" ")
            tt:AddLine(notes, GREY[1], GREY[2], GREY[3], true)
        end
    end

    tt:AddLine(" ")
    tt:AddLine("Click: quest log   Shift-click: stop tracking   Circle: focus", 0.5, 0.5, 0.5)
end

-- owner: the quest's title (or circle); the box opens to the left of the list
function Info.Show(owner, quest)
    if not quest then return end
    local tt = GameTooltip
    tt:SetOwner(owner, "ANCHOR_NONE")
    tt:ClearAllPoints()
    tt:SetPoint("TOPRIGHT", owner, "TOPLEFT", -34, 6)
    local ok, err = NA.SafeCall(Info.Fill, tt, quest)
    if not ok then NA.LogError(err) end
    tt:Show()
end

function Info.Hide()
    GameTooltip:Hide()
end

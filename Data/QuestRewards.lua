-- Data: what a quest in your log gives you (items, items to choose one of, money, experience).
-- The game's reward functions read the quest that is "selected" in the quest log, so we select ours
-- for a moment and put the old selection back. Answers are kept per quest (rewards don't change),
-- so this runs only when the info window opens on a quest - never on every quest log update
-- (selecting can itself make the game send a quest log update).
local ADDON, NA = ...

local R = {}
NA.QuestRewards = R

local cache = {} -- [questID] = rewards table (only kept when the game had the data)

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if ok then return a, b, c, d, e, f end
    return nil
end

local function logIndexOf(questID)
    local QL = C_QuestLog
    local i = QL and call(QL.GetLogIndexForQuestID, questID)
    if i and i > 0 then return i end
    return nil
end

local function selectQuest(questID, logIndex)
    local QL = C_QuestLog
    local prevIndex = call(GetQuestLogSelection)
    local prevQuest = QL and call(QL.GetSelectedQuest)
    call(SelectQuestLogEntry, logIndex)
    if QL then call(QL.SetSelectedQuest, questID) end
    return function()
        if prevIndex and prevIndex > 0 then call(SelectQuestLogEntry, prevIndex) end
        if QL and prevQuest and prevQuest ~= 0 then call(QL.SetSelectedQuest, prevQuest) end
    end
end

local function readList(kind, count, infoFn, questID)
    local list = {}
    for i = 1, (tonumber(count) or 0) do
        local name, icon, num, quality, usable = call(infoFn, i, questID)
        local link = call(GetQuestLogItemLink, kind, i)
        if (not name or not icon) and link and GetItemInfo then
            local n, _, q, _, _, _, _, _, _, tex = call(GetItemInfo, link)
            name, quality, icon = name or n, quality or q, icon or tex
        end
        if name or link then
            list[#list + 1] = { name = name or "?", icon = icon, count = tonumber(num) or 1,
                quality = tonumber(quality), usable = usable ~= false, link = link, kind = kind, index = i }
        end
    end
    return list
end

local function read(questID)
    local logIndex = logIndexOf(questID)
    if not logIndex then return nil end
    local restore = selectQuest(questID, logIndex)
    local r = {}
    r.choices = readList("choice", call(GetNumQuestLogChoices, questID, true), GetQuestLogChoiceInfo, questID)
    r.items = readList("reward", call(GetNumQuestLogRewards, questID), GetQuestLogRewardInfo, questID)
    r.money = tonumber((call(GetQuestLogRewardMoney, questID))) or 0
    r.xp = tonumber((call(GetQuestLogRewardXP, questID))) or 0
    restore()
    -- every item has a name = the game had all the data (else ask again next time)
    local complete = true
    for _, list in ipairs({ r.choices, r.items }) do
        for _, it in ipairs(list) do if it.name == "?" or not it.icon then complete = false end end
    end
    r.complete = complete
    r.empty = #r.choices == 0 and #r.items == 0 and r.money == 0 and r.xp == 0
    return r
end

-- rewards of questID: { choices = {...}, items = {...}, money = copper, xp = number, empty = bool }
-- item = { name, icon, count, quality, usable, link, kind = "choice"|"reward", index }
function R.Get(questID)
    if not questID then return nil end
    -- kept for good when the game had everything; else asked again at most every 5 s, 3 times
    local c = cache[questID]
    local now = GetTime()
    if c and (c.final or now - c.time < 5 or (c.r and c.reads >= 3)) then return c.r end
    local ok, r = pcall(read, questID)
    if not ok then NA.LogError(r); r = nil end
    local reads = (c and c.reads or 0) + 1
    cache[questID] = { r = r, time = now, reads = reads, final = r and r.complete and not r.empty }
    return r
end

function R.Forget(questID)
    if questID then cache[questID] = nil else cache = {} end
end

-- copper -> "1g 20s 5c" with the game's coin pictures
function R.MoneyText(copper)
    copper = tonumber(copper) or 0
    if copper <= 0 then return nil end
    if type(GetCoinTextureString) == "function" then
        local ok, s = pcall(GetCoinTextureString, copper)
        if ok and s then return s end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t" end
    if s > 0 then parts[#parts + 1] = s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t" end
    if c > 0 then parts[#parts + 1] = c .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t" end
    return table.concat(parts, " ")
end

-- colour of an item quality (grey .. legendary); white when unknown
function R.QualityColor(q)
    if q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
        local c = ITEM_QUALITY_COLORS[q]
        return c.r, c.g, c.b
    end
    if q and type(GetItemQualityColor) == "function" then
        local ok, r, g, b = pcall(GetItemQualityColor, q)
        if ok and r then return r, g, b end
    end
    return 1, 1, 1
end

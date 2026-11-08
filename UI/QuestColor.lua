-- UI: colour of a quest's title in the list by how hard it is for you (like the game's quest log).
--   red = very hard, orange = hard, yellow = your level, green = easy, grey = too easy.
-- Settings: questColors (on/off), questColorsCustom (your own level limits instead of the game's),
--   questColorRed / questColorOrange = levels ABOVE you, questColorGreen / questColorGrey = levels BELOW you.
-- Quests ready to turn in keep the normal gold.
local ADDON, NA = ...

local QC = {}
NA.QuestColor = QC

QC.GOLD = { 1, 0.82, 0 }
QC.COLORS = {
    red = { 1, 0.1, 0.1 },
    orange = { 1, 0.5, 0.25 },
    yellow = { 1, 0.82, 0 },
    green = { 0.25, 0.75, 0.25 },
    grey = { 0.5, 0.5, 0.5 },
}

-- slider ranges and starting values (levels)
QC.LIMITS = {
    red = { min = 1, max = 10, default = 5 },
    orange = { min = 1, max = 10, default = 3 },
    green = { min = 1, max = 10, default = 3 },
    grey = { min = 1, max = 15, default = 8 },
}
local KEYS = { red = "questColorRed", orange = "questColorOrange", green = "questColorGreen", grey = "questColorGrey" }

function QC.IsOn() return NA.db.questColors ~= false end
function QC.CustomOn() return NA.db.questColorsCustom == true end

function QC.Limit(which)
    local l = QC.LIMITS[which]
    local v = tonumber(NA.db[KEYS[which]]) or l.default
    return math.min(math.max(v, l.min), l.max)
end

function QC.SetLimit(which, v) NA.db[KEYS[which]] = v end

local function playerLevel()
    if type(UnitLevel) ~= "function" then return nil end
    local ok, lv = pcall(UnitLevel, "player")
    if ok and type(lv) == "number" and lv > 0 then return lv end
    return nil
end

-- the game's own colours (its function when there is one, else the classic rules)
-- gameFn (optional): the game's colour function to ask first (default GetQuestDifficultyColor;
-- false = only the classic rules below)
local function gameColor(level, diff, gameFn)
    if gameFn == nil then gameFn = GetQuestDifficultyColor end
    if type(gameFn) == "function" then
        local ok, c = pcall(gameFn, level)
        if ok and type(c) == "table" and c.r then return { c.r, c.g, c.b } end
    end
    if diff >= 5 then return QC.COLORS.red end
    if diff >= 3 then return QC.COLORS.orange end
    if diff >= -2 then return QC.COLORS.yellow end
    -- classic "grey level": quests at or below it give (almost) no experience
    local me = level - diff
    local greyLevel
    if me <= 5 then greyLevel = 0
    elseif me <= 39 then greyLevel = me - math.floor(me / 10) - 5
    elseif me <= 59 then greyLevel = me - math.floor(me / 5) - 1
    else greyLevel = me - 9 end
    if level > greyLevel then return QC.COLORS.green end
    return QC.COLORS.grey
end

-- your own limits: diff = quest level - your level; limit(which) gives the 4 limits
local function customColor(diff, limit)
    limit = limit or QC.Limit
    if diff >= limit("red") then return QC.COLORS.red end
    if diff >= limit("orange") then return QC.COLORS.orange end
    if -diff >= limit("grey") then return QC.COLORS.grey end
    if -diff >= limit("green") then return QC.COLORS.green end
    return QC.COLORS.yellow
end
-- shared with the mob marks (Mobs/MobLook.lua)
QC.GameColor, QC.CustomColor, QC.PlayerLevel = gameColor, customColor, playerLevel

-- {r, g, b} for a quest table from Data/QuestSource.lua
function QC.For(q)
    if not (q and QC.IsOn()) or q.isComplete then return QC.GOLD end
    local level, me = tonumber(q.level), playerLevel()
    if not (level and level > 0 and me) then return QC.GOLD end
    local diff = level - me
    if QC.CustomOn() then return customColor(diff) end
    return gameColor(level, diff)
end

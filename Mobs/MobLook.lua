-- Mobs: how the quest mark on a mob looks (Mobs/QuestMobMarker.lua draws it).
--   * colour by the mob's difficulty for you (mobColors): the game's colours, or your own level limits
--     (mobColorsCustom + mobColorRed / Orange / Green / Grey), separate from the quest colours.
--     "??" mobs (far above you) are always red.
--   * progress next to the mark (mobProgress): e.g. 3/10 - what the quest still needs from this mob.
local ADDON, NA = ...

local ML = {}
NA.MobLook = ML

ML.LIMITS = {
    red = { min = 1, max = 10, default = 4 },
    orange = { min = 1, max = 10, default = 2 },
    green = { min = 1, max = 10, default = 3 },
    grey = { min = 1, max = 15, default = 7 },
}
local KEYS = { red = "mobColorRed", orange = "mobColorOrange", green = "mobColorGreen", grey = "mobColorGrey" }

function ML.ColorsOn() return NA.db.mobColors ~= false end
function ML.CustomOn() return NA.db.mobColorsCustom == true end
function ML.ProgressOn() return NA.db.mobProgress ~= false end

function ML.Limit(which)
    local l = ML.LIMITS[which]
    local v = tonumber(NA.db[KEYS[which]]) or l.default
    return math.min(math.max(v, l.min), l.max)
end
function ML.SetLimit(which, v) NA.db[KEYS[which]] = v end

-- {r, g, b} for the mark, or nil = the mark's own yellow
function ML.ColorFor(unit)
    if not ML.ColorsOn() then return nil end
    local QC = NA.QuestColor
    if not QC then return nil end
    local ok, level = pcall(UnitLevel, unit)
    if not ok or type(level) ~= "number" then return nil end
    if level <= 0 then return QC.COLORS.red end -- "??": far above you
    local me = QC.PlayerLevel()
    if not me then return nil end
    local diff = level - me
    if ML.CustomOn() then return QC.CustomColor(diff, ML.Limit) end
    -- the classic rules, like the level number on the game's nameplates (yellow from 2 levels below
    -- you; 3 below = green). The game's colour functions here keep 3 below yellow - checked in game.
    return QC.GameColor(level, diff, false)
end

-- "3/10" for the first objective this mob still counts for, or nil
-- tooltipQuests: { title, progress } from the mob's tooltip (Mobs/QuestMobMarker.lua)
function ML.ProgressFor(unit, tooltipQuests, titles)
    if not ML.ProgressOn() then return nil end
    local wanted = {}
    for _, t in ipairs(titles or {}) do wanted[t] = true end
    for _, t in ipairs(tooltipQuests or {}) do
        if wanted[t.title] and t.progress then return t.progress end
    end
    -- no numbers in the tooltip: look for an objective of the quest that names this mob
    local all = NA.Tracker and NA.Tracker.allQuests
    local name = UnitName(unit)
    if not (all and name) then return nil end
    name = name:lower()
    for _, q in ipairs(all) do
        if wanted[q.title] and not q.isComplete then
            for _, line in ipairs(q.lines or {}) do
                if not line.finished and line.text and line.text:lower():find(name, 1, true) then
                    local a, b = line.text:match("(%d+)%s*/%s*(%d+)")
                    if a then return a .. "/" .. b end
                end
            end
        end
    end
    return nil
end

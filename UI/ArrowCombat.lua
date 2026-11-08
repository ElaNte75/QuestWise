-- UI: hides the quest arrow (UI/Arrow.lua) while you are in combat.
-- After combat it comes back at once, or - when "Wait after combat" is ticked - after arrowCombatDelay seconds.
-- Settings: arrowHideCombat, arrowCombatWait, arrowCombatDelay (10..120 s).
local ADDON, NA = ...

local AC = {}
NA.ArrowCombat = AC

AC.MIN_DELAY, AC.MAX_DELAY, AC.DEFAULT_DELAY = 10, 120, 30

local inCombat = false
local combatEnded = nil -- GetTime() when the last fight ended

function AC.IsOn() return NA.db.arrowHideCombat ~= false end
function AC.WaitOn() return NA.db.arrowCombatWait == true end
function AC.Delay()
    local v = tonumber(NA.db.arrowCombatDelay) or AC.DEFAULT_DELAY
    return math.min(math.max(v, AC.MIN_DELAY), AC.MAX_DELAY)
end

local function fighting()
    if inCombat then return true end
    if UnitAffectingCombat then
        local ok, v = pcall(UnitAffectingCombat, "player")
        if ok and v then return true end
    end
    return false
end

-- true = the arrow must stay hidden right now
function AC.IsHiding()
    if not AC.IsOn() then return false end
    if fighting() then return true end
    if AC.WaitOn() and combatEnded and GetTime() - combatEnded < AC.Delay() then return true end
    return false
end

NA.OnInit(function()
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_DISABLED")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
        else
            inCombat = false
            combatEnded = GetTime()
        end
    end)
    AC.events = ev
end)

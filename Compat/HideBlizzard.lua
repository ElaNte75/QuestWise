-- Compat: hides the game's own tracker, but only once ours is up and running.
local ADDON, NA = ...

local hooked = false

NA.OnInit(function()
    local blizz = ObjectiveTrackerFrame
    if not blizz or not (NA.Tracker and NA.Tracker.IsActive()) then return end

    if not hooked then
        hooked = true
        -- if the game tries to show it again, hide it again
        blizz:HookScript("OnShow", function(self)
            if NA.Tracker.IsActive() then self:Hide() end
        end)
    end
    blizz:Hide()
end)

-- Quests: plays a sound when one of your tracked quests becomes complete (ready to turn in).
-- Nothing plays at login or for quests that were already complete when they were first seen.
local ADDON, NA = ...

local Complete = {}
NA.CompleteSound = Complete

Complete.SOUND_KIT = "IG_QUEST_LIST_COMPLETE" -- what "Game default" means here

local known -- questID -> was it complete the last time we looked

function Complete.Play()
    NA.Sound.Play(NA.db.completeSoundChoice, NA.db.completeSoundVolume, Complete.SOUND_KIT)
end

-- called by the tracker every time it reads the quest list
function Complete.Check(quests)
    local now = {}
    local justCompleted = false
    for _, q in ipairs(quests) do
        now[q.questID] = q.isComplete and true or false
        if known and q.isComplete and known[q.questID] == false then justCompleted = true end
    end
    known = now
    if justCompleted and NA.db.completeSoundEnabled then Complete.Play() end
end

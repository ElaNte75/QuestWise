-- Actions: what happens when you click or hover a quest in our tracker.
local ADDON, NA = ...

local Actions = {}
NA.Actions = Actions

local function openQuestLog(questID)
    if type(QuestMapFrame_OpenToQuestDetails) == "function" then
        pcall(QuestMapFrame_OpenToQuestDetails, questID)
        return
    end
    pcall(C_QuestLog.SetSelectedQuest, questID)
    if type(ToggleQuestLog) == "function" then
        pcall(ToggleQuestLog)
    elseif QuestLogFrame then
        pcall(ShowUIPanel, QuestLogFrame)
    end
end

function Actions.OnClick(questID, button)
    if not questID then return end
    if IsShiftKeyDown() then
        pcall(C_QuestLog.RemoveQuestWatch, questID)
        if NA.Tracker then NA.Tracker.RequestRefresh() end
        return
    end
    openQuestLog(questID)
end

-- Round icon: focus this quest (super-track); click again to clear the focus.
function Actions.GetFocusedQuestID()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local id = C_SuperTrack.GetSuperTrackedQuestID()
        if id and id ~= 0 then return id end
    end
    return nil
end

function Actions.ToggleFocus(questID)
    if not questID or not (C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID) then return end
    if Actions.GetFocusedQuestID() == questID then
        pcall(C_SuperTrack.SetSuperTrackedQuestID, 0)
    else
        pcall(C_SuperTrack.SetSuperTrackedQuestID, questID)
    end
    if NA.Tracker then NA.Tracker.RequestRefresh() end
end

function Actions.ShowTooltip(owner, quest)
    if not quest then return end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine(quest.title, 1, 0.82, 0)
    GameTooltip:AddLine("Click: open quest log", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift-click: stop tracking", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function Actions.HideTooltip()
    GameTooltip:Hide()
end

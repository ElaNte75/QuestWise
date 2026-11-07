-- UI: the clickable quest-item button shown at the right of a quest. Click = use the item.
-- It is a secure button, so the game only lets us change it outside combat.
local ADDON, NA = ...

local Item = {}
Item.__index = Item
NA.QuestItemButton = Item

local SIZE = 26
Item.SIZE = SIZE

local function cooldownOf(itemID)
    if not itemID then return nil end
    if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(itemID) end
    if GetItemCooldown then return GetItemCooldown(itemID) end
    return nil
end

function Item.New(parent)
    local self = setmetatable({}, Item)
    local btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    btn:SetSize(SIZE, SIZE)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "item")
    self.btn = btn

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    self.icon = icon

    local count = btn:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", -1, 1)
    self.count = count

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints()
    self.cd = cd

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    btn:SetScript("OnEnter", function()
        if self.item and self.item.link then
            GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.item.link)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- using the quest item tells the arrow you are at the quest (UI/Arrow.lua)
    btn:HookScript("PostClick", function()
        if NA.Arrow and self.questID then NA.SafeCall(NA.Arrow.Activity, self.questID, "item used") end
    end)
    return self
end

function Item:UpdateCooldown()
    local start, duration = cooldownOf(self.item and self.item.itemID)
    if start and duration and duration > 0 then
        self.cd:SetCooldown(start, duration)
    else
        self.cd:Clear()
    end
end

-- Show the button for `item` (table from QuestSource). Only call outside combat.
function Item:Set(item)
    self.item = item
    self.btn:SetAttribute("item", item.link)
    if item.icon then self.icon:SetTexture(item.icon) end
    local n = item.itemID and GetItemCount and GetItemCount(item.itemID) or 0
    self.count:SetText(n and n > 1 and n or "")
    self:UpdateCooldown()
    self.btn:Show()
end

-- Hide the button. Only call outside combat.
function Item:Clear()
    self.item = nil
    self.btn:Hide()
end

function Item:IsShown()
    return self.btn:IsShown()
end

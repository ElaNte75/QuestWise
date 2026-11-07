-- UI: small gear button on the tracker title (left of the collapse button) that opens Options.
local ADDON, NA = ...

NA.OptionsButton = {}

local SIZE = 16
local GEAR_ATLASES = { "QuestLog-icon-setting", "GM-icon-settings" }
local GEAR_FILE = "Interface\\Buttons\\UI-OptionsButton"

local function setGear(tex)
    if not NA.SetAtlasFirst(tex, GEAR_ATLASES) then
        tex:SetTexture(GEAR_FILE)
    end
end

-- header: the title button; xOffset: distance from its right edge
function NA.OptionsButton.Attach(header, xOffset)
    local btn = CreateFrame("Button", nil, header)
    btn:SetSize(SIZE, SIZE)
    btn:SetPoint("RIGHT", header, "RIGHT", xOffset or -24, 0)
    btn:SetFrameLevel(header:GetFrameLevel() + 2)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    setGear(icon)
    icon:SetVertexColor(0.85, 0.85, 0.85)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    setGear(hl)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.5)

    -- tiny "pressed" nudge
    btn:SetScript("OnMouseDown", function()
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", 1, -1)
    end)
    btn:SetScript("OnMouseUp", function()
        icon:ClearAllPoints()
        icon:SetAllPoints()
    end)
    btn:SetScript("OnClick", function() if NA.Options then NA.Options.Toggle() end end)
    btn:SetScript("OnEnter", function(self)
        icon:SetVertexColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Options")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        icon:SetVertexColor(0.85, 0.85, 0.85)
        GameTooltip:Hide()
    end)
    return btn
end

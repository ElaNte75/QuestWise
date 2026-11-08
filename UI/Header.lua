-- UI: builds a collapsible header bar (used for "All Objectives" and "Quests").
local ADDON, NA = ...

local FONT = "Fonts\\FRIZQT__.TTF"

NA.Header = {}

-- opts: width, height, bg, bgW, bgH, collapse, expand, iconW, iconH, highlight, iconX, label, reserve
-- (reserve = room kept free on the right for the buttons)
function NA.Header.Create(parent, opts)
    local btn = CreateFrame("Button", nil, parent)
    local reserve = opts.reserve or 52
    btn:SetSize(opts.width, opts.height)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(opts.bgW, opts.bgH)
    bg:SetPoint("CENTER")
    NA.SetAtlas(bg, opts.bg)
    btn.art = bg -- the gold-framed bar picture (UI/ListLayout.lua fits the folded background inside it)

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 14, "")
    text:SetTextColor(1, 0.82, 0)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetJustifyH("LEFT")
    text:SetPoint("LEFT", 7, 0)
    text:SetWidth(opts.width - reserve)
    text:SetText(opts.label)
    btn.text = text

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(opts.iconW, opts.iconH)
    icon:SetPoint("RIGHT", opts.iconX or -1, 0)
    NA.SetAtlas(icon, opts.collapse)

    -- The highlight lights up only when the mouse is on the collapse button itself, and it is the
    -- SAME icon added on top (a little brighter) - so the icon never changes its look on hover.
    local iconBtn = CreateFrame("Button", nil, btn)
    iconBtn:SetSize(opts.iconW, opts.iconH)
    iconBtn:SetPoint("RIGHT", opts.iconX or -1, 0)
    local hl = iconBtn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    NA.SetAtlas(hl, opts.collapse)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.4)
    iconBtn:SetScript("OnClick", function() btn:Click() end)

    function btn:SetFontSize(size)
        text:SetFont(FONT, size, "")
    end

    -- the list can be made wider or narrower in the options
    function btn:SetWidthTo(w)
        btn:SetWidth(w)
        text:SetWidth(w - reserve)
    end

    function btn:SetCollapsed(collapsed)
        -- "expand" atlas is a best guess; fall back to the collapse art if unknown
        if collapsed then
            NA.SetAtlas(icon, opts.expand, opts.collapse)
            NA.SetAtlas(hl, opts.expand, opts.collapse)
        else
            NA.SetAtlas(icon, opts.collapse)
            NA.SetAtlas(hl, opts.collapse)
        end
    end

    return btn
end

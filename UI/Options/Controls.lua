-- Options UI: drop-down list and slider, drawn in the shared look from Widgets.lua.
local ADDON, NA = ...

local W = NA.Widgets
local C, S = W.colors, W.size

-- Drop-down list: click to open, pick an item (set(key) runs), click anywhere else to close.
-- items = { {key=, label=}, ... }; get() returns the current key. Long lists use several columns.
function W.Dropdown(parent, items, get, set, width)
    local PER_COLUMN, COL_W, ROW_H = 8, 140, 22

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or S.controlW, S.controlH)
    local bg = W.Fill(btn, C.controlBg)
    W.Outline(btn, C.controlBorder)
    local text = W.Text(btn, S.font, C.text)
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -22, 0)
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", -5, -1)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    W.Tint(arrow, C.goldDim)

    -- popup list (above everything) and a click-catcher behind it
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(10)
    catcher:Hide()
    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(20)
    W.Fill(popup, C.popupBg)
    W.Outline(popup, C.border)
    popup:Hide()
    local columns = math.ceil(#items / PER_COLUMN)
    popup:SetSize(columns * COL_W + 8, math.min(#items, PER_COLUMN) * ROW_H + 8)

    local function close() popup:Hide(); catcher:Hide() end
    catcher:SetScript("OnClick", close)

    local rows = {}
    for i, it in ipairs(items) do
        local row = CreateFrame("Button", nil, popup)
        row:SetSize(COL_W, ROW_H)
        local col, r = math.floor((i - 1) / PER_COLUMN), (i - 1) % PER_COLUMN
        row:SetPoint("TOPLEFT", 4 + col * COL_W, -4 - r * ROW_H)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        W.Paint(hl, C.hover)
        row.sel = W.Fill(row, C.selectedBg)
        row.sel:Hide()
        row.text = W.Text(row, S.font, C.text)
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetText(it.label)
        row:SetScript("OnClick", function()
            set(it.key)
            btn.Refresh()
            close()
        end)
        rows[i] = row
    end

    btn.Refresh = function()
        local cur = get()
        local label = items[1].label
        for i, it in ipairs(items) do
            local selected = it.key == cur
            rows[i].sel:SetShown(selected)
            rows[i].text:SetTextColor(unpack(selected and C.gold or C.text))
            if selected then label = it.label end
        end
        text:SetText(label)
    end
    btn:SetScript("OnEnter", function() btn:SetOutlineColor(unpack(C.gold)); bg:SetColorTexture(1, 1, 1, 0.05) end)
    btn:SetScript("OnLeave", function() btn:SetOutlineColor(unpack(C.controlBorder)); bg:SetColorTexture(unpack(C.controlBg)) end)
    btn:SetScript("OnClick", function()
        if popup:IsShown() then close(); return end
        btn.Refresh()
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        catcher:Show()
        popup:Show()
    end)
    btn:SetScript("OnHide", close)
    return btn
end

-- 30 -> "30 s", 60 -> "1 min", 90 -> "1 min 30 s"
function W.FormatSeconds(v)
    if v < 60 then return v .. " s" end
    local m, s = math.floor(v / 60), v % 60
    return s == 0 and (m .. " min") or (m .. " min " .. s .. " s")
end

-- Flat slider: thin track, gold fill up to the handle, value shown at the right.
-- onRelease() runs when you let go of the mouse.
-- opts (optional): width, majorEvery (faint tick marks), format (function(value) -> text)
function W.Slider(parent, min, max, step, suffix, get, set, onRelease, opts)
    opts = opts or {}
    local width = opts.width or S.controlW
    local function fmt(v) return opts.format and opts.format(v) or (v .. suffix) end

    local s = CreateFrame("Slider", nil, parent)
    s:SetSize(width, 16)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouse(true)
    s:SetHitRectInsets(0, 0, -4, -4)

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetHeight(4)
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    W.Paint(track, C.track)

    if opts.majorEvery then
        for v = min, max, opts.majorEvery do
            local t = s:CreateTexture(nil, "BACKGROUND")
            t:SetColorTexture(1, 1, 1, 0.22)
            t:SetSize(1, 4)
            t:SetPoint("TOP", s, "LEFT", 4 + (v - min) / (max - min) * (width - 8), -5)
        end
    end

    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 14)
    W.Paint(thumb, C.gold)
    s:SetThumbTexture(thumb)

    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(4)
    fill:SetPoint("LEFT", track, "LEFT", 0, 0)
    fill:SetPoint("RIGHT", thumb, "CENTER", 0, 0)
    W.Paint(fill, C.sliderFill)

    local value = W.Text(s, S.font, C.gold)
    value:SetPoint("LEFT", s, "RIGHT", 12, 0)

    s:SetScript("OnEnter", function() thumb:SetColorTexture(unpack(C.thumbHover)) end)
    s:SetScript("OnLeave", function() thumb:SetColorTexture(unpack(C.gold)) end)

    local updating = false
    s:SetScript("OnValueChanged", function(_, raw)
        if updating then return end
        local v = math.floor(raw / step + 0.5) * step
        set(v)
        value:SetText(fmt(v))
    end)
    s:HookScript("OnMouseUp", function() if onRelease then onRelease() end end)
    s.Refresh = function()
        updating = true
        local v = get()
        s:SetValue(v)
        value:SetText(fmt(v))
        updating = false
    end
    return s
end

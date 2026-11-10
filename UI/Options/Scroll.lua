-- Options UI: a page that scrolls, with a thin scrollbar on the right.
-- The bar is dark while you don't touch it and takes the gold colour when you point at it or drag it.
local ADDON, NA = ...

local W = NA.Widgets

local BAR_W, WHEEL_STEP, MIN_THUMB = 6, 40, 28

-- content: the frame the page sits in.
-- o = { left, top, right, bottom = distances of the page from `content`,
--       barX = distance of the scrollbar from the right edge, pageW, viewH = size of the visible part }
-- Returns { frame, page, SetContentHeight(h), SetShown(on) }; build the page's widgets inside `page`.
function W.ScrollPage(content, o)
    local sp = {}

    local sf = CreateFrame("ScrollFrame", nil, content)
    sf:SetPoint("TOPLEFT", content, "TOPLEFT", o.left, -o.top)
    sf:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -o.right, o.bottom)
    sf:EnableMouseWheel(true)
    sf:Hide()

    local page = CreateFrame("Frame", nil, sf)
    page:SetSize(o.pageW, 10)
    sf:SetScrollChild(page)

    -- scrollbar: track + thumb (outside the scroll frame, in the right margin)
    local bar = CreateFrame("Frame", nil, content)
    bar:SetWidth(BAR_W)
    bar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -o.barX, -o.top)
    bar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -o.barX, o.bottom)
    bar:EnableMouse(true)
    bar:EnableMouseWheel(true)
    bar:Hide()
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.04)
    local thumb = CreateFrame("Button", nil, bar)
    thumb:SetWidth(BAR_W)
    local tex = thumb:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()

    local contentH, barHover, thumbHover, dragging = 0, false, false, false

    local function paint()
        if barHover or thumbHover or dragging then
            local g = W.colors.gold -- the preset's accent colour
            tex:SetColorTexture(g[1], g[2], g[3], 0.9)
        else
            tex:SetColorTexture(1, 1, 1, 0.14)
        end
    end
    paint()

    local function maxScroll() return math.max(contentH - o.viewH, 0) end

    local function layoutThumb()
        local ms = maxScroll()
        if ms <= 0 then bar:Hide(); return end
        bar:Show()
        local th = math.max(MIN_THUMB, o.viewH * o.viewH / contentH)
        thumb:SetHeight(th)
        local off = sf:GetVerticalScroll() or 0
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", bar, "TOP", 0, -(o.viewH - th) * (off / ms))
    end

    local function scrollTo(v)
        sf:SetVerticalScroll(math.min(math.max(v, 0), maxScroll()))
    end

    sf:SetScript("OnVerticalScroll", layoutThumb)
    local function wheel(_, delta) scrollTo((sf:GetVerticalScroll() or 0) - delta * WHEEL_STEP) end
    sf:SetScript("OnMouseWheel", wheel)
    bar:SetScript("OnMouseWheel", wheel)

    -- hover colour
    bar:SetScript("OnEnter", function() barHover = true; paint() end)
    bar:SetScript("OnLeave", function() barHover = false; paint() end)
    thumb:SetScript("OnEnter", function() thumbHover = true; paint() end)
    thumb:SetScript("OnLeave", function() thumbHover = false; paint() end)

    -- drag the thumb
    local startY, startOff
    local function cursorY() return select(2, GetCursorPosition()) / bar:GetEffectiveScale() end
    thumb:SetScript("OnMouseDown", function()
        dragging = true
        startY, startOff = cursorY(), sf:GetVerticalScroll() or 0
        paint()
    end)
    thumb:SetScript("OnMouseUp", function() dragging = false; paint() end)
    thumb:SetScript("OnUpdate", function()
        if not dragging then return end
        local travel = o.viewH - thumb:GetHeight()
        if travel > 0 then scrollTo(startOff + (startY - cursorY()) / travel * maxScroll()) end
    end)

    -- click on the empty track: one page up or down
    bar:SetScript("OnMouseDown", function()
        local y = cursorY()
        local cur = sf:GetVerticalScroll() or 0
        if thumb:GetTop() and y > thumb:GetTop() then scrollTo(cur - o.viewH * 0.9)
        elseif thumb:GetBottom() and y < thumb:GetBottom() then scrollTo(cur + o.viewH * 0.9) end
    end)

    sp.frame, sp.page = sf, page
    function sp.SetContentHeight(h)
        contentH = h
        page:SetHeight(math.max(h, 10))
        scrollTo(sf:GetVerticalScroll() or 0) -- keep the position inside the new range
        layoutThumb()
    end
    function sp.SetShown(on)
        sf:SetShown(on)
        if on then
            sf:SetVerticalScroll(0)
            layoutThumb()
        else
            bar:Hide()
        end
    end
    return sp
end

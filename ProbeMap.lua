-- TEMPORARY probe: dumps how the world map draws quest icons / blue areas.
-- Silent. Open the world map once, then /reload. Result: QuestWiseProbeDB.map
local ADDON, NA = ...
QuestWiseProbeDB = QuestWiseProbeDB or {}

local MAX = 300

local function keysOf(t, filter)
    local out = {}
    if type(t) ~= "table" then return out end
    for k, v in pairs(t) do
        if type(k) == "string" and (not filter or k:find(filter)) then out[#out + 1] = k .. ":" .. type(v) end
    end
    table.sort(out)
    return out
end

local function dump()
    local d = { time = date("%H:%M:%S"), lines = {} }
    local function add(s) if #d.lines < MAX then d.lines[#d.lines + 1] = s end end
    local W = WorldMapFrame
    if not W then add("no WorldMapFrame"); QuestWiseProbeDB.map = d; return end

    add("WorldMapFrame fields(match): " .. table.concat(keysOf(W, "[Pp]rovider") , ", "))
    add("WorldMapFrame fields(pool/pin): " .. table.concat(keysOf(W, "[Pp]in"), ", "))
    add("mapID=" .. tostring(W.GetMapID and W:GetMapID()))

    local globals = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "table" and (k:find("QuestBlob") or k:find("QuestPOI") or k:find("QuestDataProvider") or k:find("MapQuest") or k:find("QuestPin") or k:find("QuestMap")) then
            globals[#globals + 1] = k
        end
    end
    table.sort(globals)
    add("GLOBAL tables: " .. table.concat(globals, ", "))

    local providers = W.dataProviders
    if type(providers) == "table" then
        local n = 0
        for p in pairs(providers) do
            n = n + 1
            local names = {}
            if type(p) == "table" then
                for k, v in pairs(p) do if type(k) == "string" then names[#names + 1] = k end end
            end
            table.sort(names)
            local text = table.concat(names, ",")
            if text:find("Quest") or text:find("Blob") then
                add("PROVIDER#" .. n .. " (quest/blob related) keys: " .. text:sub(1, 900))
            else
                add("provider#" .. n .. " keys(short): " .. text:sub(1, 120))
            end
        end
    else
        add("W.dataProviders is " .. type(providers))
    end

    local pools = W.pinPools
    if type(pools) == "table" then
        for template, pool in pairs(pools) do
            local count = 0
            local ok = pcall(function()
                if pool.EnumerateActive then
                    for pin in pool:EnumerateActive() do
                        count = count + 1
                        if tostring(template):find("Quest") or tostring(template):find("Blob") then
                            add(string.format("  pin[%s] questID=%s shown=%s keys=%s", tostring(template), tostring(pin.questID), tostring(pin.IsShown and pin:IsShown()),
                                table.concat(keysOf(pin, "[Qq]uest"), ",")))
                        end
                    end
                end
            end)
            add("POOL " .. tostring(template) .. " active=" .. count .. (ok and "" or " (enumerate failed)"))
        end
    else
        add("W.pinPools is " .. type(pools))
    end
    QuestWiseProbeDB.map = d
end

-- Minimap: which quest-blob methods exist and what they currently return
local function dumpMinimap()
    local d = { time = date("%H:%M:%S"), lines = {} }
    local function add(s) if #d.lines < MAX then d.lines[#d.lines + 1] = s end end
    if not Minimap then add("no Minimap"); QuestWiseProbeDB.minimap = d; return end
    local mt = getmetatable(Minimap)
    local idx = mt and mt.__index
    local names = {}
    if type(idx) == "table" then
        for k, v in pairs(idx) do
            if type(k) == "string" and (k:find("Quest") or k:find("Blob") or k:find("Ring")) then names[#names + 1] = k end
        end
    end
    table.sort(names)
    add("Minimap methods: " .. table.concat(names, ", "))
    for _, k in ipairs(names) do
        if k:sub(1, 3) == "Get" then
            local ok, a, b, c = pcall(Minimap[k], Minimap)
            add(string.format("  %s() -> %s, %s, %s (ok=%s)", k, tostring(a), tostring(b), tostring(c), tostring(ok)))
        end
    end
    add("Minimap fields: " .. table.concat(keysOf(Minimap), ", "):sub(1, 600))
    local st = {}
    if C_SuperTrack then for k, v in pairs(C_SuperTrack) do st[#st + 1] = k end end
    table.sort(st)
    add("C_SuperTrack: " .. table.concat(st, ", "))
    add("supertracked quest=" .. tostring(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()))
    add("focus glyph art used: " .. tostring(NA.focusGlyphAtlas))
    if C_Texture and C_Texture.GetAtlasElements then
        local ok, all = pcall(C_Texture.GetAtlasElements)
        if ok and type(all) == "table" then
            local m = {}
            for _, n in ipairs(all) do
                if type(n) == "string" and (n:find("QuestPoi") or n:find("QuestIcon") or n:find("In%-Progress")) then m[#m + 1] = n end
            end
            table.sort(m)
            add("ATLASES: " .. table.concat(m, ", "))
        else
            add("GetAtlasElements failed")
        end
    else
        add("no GetAtlasElements")
    end
    QuestWiseProbeDB.minimap = d
end

local hooked = false
local function tryHook()
    if hooked or not WorldMapFrame then return end
    hooked = true
    WorldMapFrame:HookScript("OnShow", function()
        C_Timer.After(1.5, function() NA.SafeCall(dump) end)
    end)
end

NA.OnInit(function()
    tryHook()
    C_Timer.After(3, tryHook)
    C_Timer.After(8, function() NA.SafeCall(dumpMinimap) end)
end)

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_WorldMap" then tryHook() end
end)

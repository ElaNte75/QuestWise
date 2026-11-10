-- UI: on the minimap, the inside of the quest areas in the same colour as on the world map
-- (UI/MapArea.lua). Tried in game: the minimap takes our colour for the INSIDE only; its light-blue
-- edge stays the game's whatever we give it (4 tries), and it can't tell the focused quest's area
-- from the others (no "selected" picture in this game), so nothing here hides the other areas.
-- Setting: mapMinimap (on); also off when the map colours are off (mapArea).
local ADDON, NA = ...

local MM = {}
NA.MinimapArea = MM

local GAME_INSIDE = "Interface\\WorldMap\\UI-QuestBlob-Inside" -- the game's own, put back when off
local TICK = 1

function MM.IsOn()
    return NA.db.mapMinimap ~= false and NA.MapArea and NA.MapArea.IsOn()
end

local applied -- picture we gave the minimap last (nil = the game's own, untouched)

local function setInside(file)
    if not (Minimap and Minimap.SetQuestBlobInsideTexture) then return end
    pcall(Minimap.SetQuestBlobInsideTexture, Minimap, file)
end

-- paints the minimap areas (or gives them back the game's look); force = even if nothing changed
function MM.Update(force)
    local want = MM.IsOn() and NA.MapArea.TexPath("Fill") or nil
    if want == applied and not force then return end
    if want then
        setInside(want)
    elseif applied then
        setInside(GAME_INSIDE)
    end
    applied = want
end

NA.OnInit(function()
    MM.Update(true)
    -- the colour can change in the options at any time, and the game may set its own look again
    -- (zone change): look once a second, and paint again every few seconds
    local acc, again = 0, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < TICK then return end
        acc = 0
        again = again + 1
        local ok, err = NA.SafeCall(MM.Update, again >= 5)
        if again >= 5 then again = 0 end
        if not ok then NA.LogError(err) end
    end)
    MM.driver = f
end)

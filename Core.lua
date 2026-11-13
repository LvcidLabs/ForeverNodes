local ADDON, FN = ...

local HBD = LibStub("HereBeDragons-2.0")
local Pins = LibStub("HereBeDragons-Pins-2.0")

local floor = math.floor

-- Distance (yards) at which the game's own Find Herbs / Find Minerals dots
-- appear on the minimap. Inside it the node picture becomes a plain circle.
-- Measured in Forever: the dot appears between 189 and 190 yards.
FN.DEFAULT_RANGE = 190

local SHOW_RADIUS = 400 -- wider than the largest minimap view, corners and draw range included
local CELL = 400        -- spatial grid cell size in yards (must be >= SHOW_RADIUS)
local REAPPEAR = 3      -- extra yards before a circle turns back into a picture, so it does not flicker at the edge

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\"
FN.MEDIA = MEDIA
local DISC = MEDIA .. "disc"

-- A ring whose line is `line` px wide at `diameter` px across. The art comes in
-- 16 line weights (ring16 is a solid disc); pick the closest.
local function RingTexture(line, diameter)
    local n = floor(line / (diameter / 2) * 16 + 0.5)
    if n < 1 then n = 1 elseif n > 16 then n = 16 end
    return MEDIA .. "Rings\\ring" .. n
end

-- Professions, in display order.
FN.kinds = { "herb", "ore", "fish" }
FN.kindNames = { herb = "Herbalism", ore = "Mining", fish = "Fishing" }
local SKILL_LINES = { herb = 182, ore = 186, fish = 356 }

FN.defaults = {
    range = FN.DEFAULT_RANGE,
    minimap = true,
    worldmap = true,
    minimapShape = "auto", -- "auto" (detected), "round" or "square": where minimap icons stop
    minimapEdge = 95,      -- how far out minimap icons draw, in % of the minimap's radius
    -- How node pictures look, set separately for each map:
    --   size   picture size, px
    --   round  crop every picture to a circle
    --   zoom   how far a round picture is zoomed in
    icons = {
        minimap = { size = 15, round = true, zoom = 1.3 },
        world = { size = 16, round = false, zoom = 1.5 },
    },
    -- Marker for a node inside the tracking range: a "circle" or a "dot".
    nearStyle = "dot",
    circleSize = 9,
    circleLine = 2,                  -- line width, px
    circleBorder = 1,                -- outline around the line, px (0 = none)
    circleBorderColor = { 0, 0, 0 },
    dotSize = 4,
    dotBorder = 0.5,
    dotBorderColor = { 0, 0, 0 },
    -- The dot's optional second border: a thin ring around it, a little larger
    -- than a node picture, marking where the picture was.
    dotRing = false,
    dotRingSize = 13,
    dotRingWidth = 1,
    dotRingColor = { 0, 0, 0, 0.345 }, -- black, about a third opaque
    showAll = false, -- professions the character lacks can be opened (they are always listed, greyed)
    record = true,   -- save the spot of fishing pools the character fishes from
    recordHerb = true, -- save the spot of herbs the character gathers
    recordOre = true,  -- save the spot of veins the character mines
    sort = "level",  -- "level" or "name"
    scale = 1,       -- floating options window scale
    dockScale = 1,   -- docked panel scale (its own, so the two never mix)
    dock = true,     -- the world map button opens the options as a side panel in the quest log's place
    colors = {
        herb = { 0.435, 0.796, 0.161 }, -- lime
        ore  = { 0.62, 0.71, 0.80 }, -- steel
        fish = { 0.20, 0.90, 0.90 }, -- aqua
    },
}

local db

-- Node lookup --------------------------------------------------------------

FN.byKey = {}
for _, node in ipairs(FN.nodes) do
    node.icon = MEDIA .. node.icon
    FN.byKey[node.key] = node
end

-- Character state ------------------------------------------------------------

-- The character's skill in a gathering profession and the profession's icon;
-- nil when it is not known.
function FN:GetSkill(kind)
    if not (GetProfessions and GetProfessionInfo) then return nil end
    local line = SKILL_LINES[kind]
    local slots = { GetProfessions() }
    for i = 1, 6 do
        local index = slots[i]
        if index then
            local _, icon, rank, _, _, _, id = GetProfessionInfo(index)
            if id == line then return rank or 0, icon end
        end
    end
    return nil
end

-- Forever fishes with the pole in the main hand.
local poleEquipped = false
function FN:PoleEquipped() return poleEquipped end
local function CheckPole()
    local id = GetInventoryItemID("player", INVSLOT_MAINHAND or 16)
    if not id then return false end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
    local weapon = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
    local pole = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
    return classID == weapon and subClassID == pole
end

-- Pin frames (shared by minimap and world map) -------------------------------

local pool = {}

-- Applies the current look: picture (plain or round) or in-range circle.
local function StylePin(pin)
    local node = pin.node
    local color = db.colors[node.kind]
    if pin.near then
        pin.bg:Hide()
        pin.icon:Hide()

        -- `mark` is the colored circle or dot; `edge` is its outline, drawn underneath.
        local size, border, borderColor, markTexture, edgeTexture
        local ringSize = 0 -- the dot's optional second border
        if db.nearStyle == "dot" then
            size, border, borderColor = db.dotSize, db.dotBorder, db.dotBorderColor
            markTexture, edgeTexture = DISC, DISC
            if db.dotRing then ringSize = db.dotRingSize end
        else
            size, border, borderColor = db.circleSize, db.circleBorder, db.circleBorderColor
            markTexture = RingTexture(db.circleLine, size)
            edgeTexture = RingTexture(db.circleLine + 2 * border, size + 2 * border)
        end
        local outer = math.max(size + 2 * border, 1)
        local whole = math.max(outer, ringSize)
        pin:SetSize(whole, whole)
        pin.edge:SetTexture(edgeTexture)
        pin.edge:SetSize(outer, outer)
        pin.edge:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
        pin.edge:SetShown(border > 0)
        pin.mark:SetTexture(markTexture)
        pin.mark:SetSize(math.max(size, 0.01), math.max(size, 0.01))
        pin.mark:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        pin.mark:SetShown(size > 0)
        if ringSize > 0 then
            local ringColor = db.dotRingColor
            pin.halo:SetTexture(RingTexture(db.dotRingWidth, ringSize))
            pin.halo:SetSize(ringSize, ringSize)
            pin.halo:SetVertexColor(ringColor[1], ringColor[2], ringColor[3], ringColor[4] or 1)
            pin.halo:Show()
        else
            pin.halo:Hide()
        end
        return
    end

    local look = db.icons[pin.where] or db.icons.minimap
    pin:SetSize(look.size, look.size)
    pin.mark:Hide()
    pin.edge:Hide()
    pin.halo:Hide()
    pin.icon:SetTexture(node.icon)
    pin.icon:Show()
    if look.round then
        local inset = (1 - 1 / look.zoom) / 2
        pin.icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
        if not pin.masked then
            pin.icon:AddMaskTexture(pin.mask)
            pin.masked = true
        end
        pin.bg:Show()
    else
        pin.icon:SetTexCoord(0, 1, 0, 1)
        if pin.masked then
            pin.icon:RemoveMaskTexture(pin.mask)
            pin.masked = false
        end
        pin.bg:Hide()
    end
end

-- `where` is "minimap" or "world": each map has its own picture settings.
local function AcquirePin(node, where)
    local pin = table.remove(pool)
    if not pin then
        pin = CreateFrame("Frame", nil, UIParent)
        -- Purely visual: hovering and clicking go straight through to the minimap / map.
        pin:EnableMouse(false)

        pin.bg = pin:CreateTexture(nil, "BACKGROUND")
        pin.bg:SetAllPoints()
        pin.bg:SetTexture(DISC)
        pin.bg:SetVertexColor(0.05, 0.05, 0.05, 0.9)

        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetAllPoints()

        pin.mask = pin:CreateMaskTexture()
        pin.mask:SetAllPoints(pin.icon)
        pin.mask:SetTexture(DISC, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

        pin.halo = pin:CreateTexture(nil, "BORDER") -- the dot's second border, outermost
        pin.halo:SetPoint("CENTER")

        pin.edge = pin:CreateTexture(nil, "ARTWORK")
        pin.edge:SetPoint("CENTER")

        pin.mark = pin:CreateTexture(nil, "OVERLAY")
        pin.mark:SetPoint("CENTER")
    end
    pin.node = node
    pin.where = where
    pin.near = false
    StylePin(pin)
    return pin
end

local function ReleasePin(pin)
    pin:Hide()
    pin:ClearAllPoints()
    pin:SetParent(UIParent)
    pin.node = nil
    pool[#pool + 1] = pin
end

local function SetNear(pin, near)
    if pin.near ~= near then
        pin.near = near
        StylePin(pin)
    end
end

-- World-coordinate index of the enabled nodes ------------------------------

local worldCache = {} -- [key] = { point, ... }; point = { x, y, inst, node }
local grid = {}       -- [instanceID][cellKey] = { point, ... }
local active = {}     -- [point] = minimap pin currently shown

local function CellKey(cx, cy)
    return (cx + 1000) * 4096 + (cy + 1000)
end

local function WorldPoints(key)
    local list = worldCache[key]
    if list then return list end
    list = {}
    local node = FN.byKey[key]
    for mapID, flat in pairs(FN.points[key]) do
        for i = 1, #flat, 2 do
            local x, y, inst = HBD:GetWorldCoordinatesFromZone(flat[i], flat[i + 1], mapID)
            if x and y and inst then
                list[#list + 1] = { x = x, y = y, inst = inst, node = node }
            end
        end
    end
    worldCache[key] = list
    return list
end

local function ClearMinimap()
    for point, pin in pairs(active) do
        ReleasePin(pin)
        active[point] = nil
    end
end

local function RebuildGrid()
    ClearMinimap()
    wipe(grid)
    for _, node in ipairs(FN.nodes) do
        -- Pools have no tracking spell: they show on the minimap while a pole is in hand.
        if db.enabled[node.key] and (node.kind ~= "fish" or poleEquipped) then
            local list = WorldPoints(node.key)
            for i = 1, #list do
                local point = list[i]
                local cells = grid[point.inst]
                if not cells then
                    cells = {}
                    grid[point.inst] = cells
                end
                local key = CellKey(floor(point.x / CELL), floor(point.y / CELL))
                local cell = cells[key]
                if not cell then
                    cell = {}
                    cells[key] = cell
                end
                cell[#cell + 1] = point
            end
        end
    end
end

-- Minimap placement ------------------------------------------------------------
-- Minimap icons are placed here rather than by the pin library, whose cut-off is
-- fixed at 90% of the radius and which only knows the shape minimap addons report.

-- The minimap's shape. Minimap addons may report it with GetMinimapShape(); many
-- (EllesmereUI among them) only swap the minimap's mask, so the mask is watched too.
local SHAPES = {
    -- which quarters are round: { upper-left, lower-left, upper-right, lower-right }
    ROUND                   = { true,  true,  true,  true },
    SQUARE                  = { false, false, false, false },
    ["CORNER-TOPLEFT"]      = { true,  false, false, false },
    ["CORNER-TOPRIGHT"]     = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]   = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]  = { false, false, false, true },
    ["SIDE-LEFT"]           = { true,  true,  false, false },
    ["SIDE-RIGHT"]          = { false, false, true,  true },
    ["SIDE-TOP"]            = { true,  false, true,  false },
    ["SIDE-BOTTOM"]         = { false, true,  false, true },
    ["TRICORNER-TOPLEFT"]   = { true,  true,  true,  false },
    ["TRICORNER-TOPRIGHT"]  = { true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"] = { true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { false, true,  true,  true },
}
local ROUND_MASKS = {
    [186178] = true, -- Textures\MinimapMask, the game's own
    ["textures\\minimapmask"] = true,
    ["interface\\charactersheet\\tempportraitalphamask"] = true,
    ["interface\\characterframe\\tempportraitalphamask"] = true,
}
local maskShape -- "ROUND" / "SQUARE" from the last mask set on the minimap, if any
if Minimap and Minimap.SetMaskTexture then
    hooksecurefunc(Minimap, "SetMaskTexture", function(_, mask)
        if type(mask) == "string" then mask = mask:lower():gsub("/", "\\") end
        maskShape = ROUND_MASKS[mask] and "ROUND" or "SQUARE"
    end)
end

-- The detected shape's name, for the options ("ROUND", "SQUARE" or a corner shape).
function FN:DetectedMinimapShape()
    local reported = GetMinimapShape and GetMinimapShape()
    if reported and SHAPES[reported] then return reported end
    return maskShape or "ROUND"
end

local function CurrentShape()
    if db.minimapShape == "round" then return SHAPES.ROUND end
    if db.minimapShape == "square" then return SHAPES.SQUARE end
    return SHAPES[FN:DetectedMinimapShape()]
end

local OUTDOOR_RADIUS = { [0] = 233 + 1/3, 200, 166 + 2/3, 133 + 1/3, 100, 66 + 2/3 } -- yards, by zoom
local function ViewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then return C_Minimap.GetViewRadius() end
    return OUTDOOR_RADIUS[Minimap:GetZoom()] or OUTDOOR_RADIUS[0]
end

-- Moves every minimap icon to where it belongs; hides the ones past the draw range.
-- Runs every frame, but only does work when the view changed.
local lastX, lastY, lastFacing, lastRadius, lastW, lastH, lastShape, lastEdge
local placeDirty = true
local function PlaceMinimapPins()
    local px, py = HBD:GetPlayerWorldPosition()
    if not px then return end
    local rotate = GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing() or 0
    if not facing then return end
    local radius = ViewRadius()
    local w, h = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
    local shape, edge = CurrentShape(), db.minimapEdge / 100
    if not placeDirty and px == lastX and py == lastY and facing == lastFacing and radius == lastRadius
        and w == lastW and h == lastH and shape == lastShape and edge == lastEdge then
        return
    end
    placeDirty = false
    lastX, lastY, lastFacing, lastRadius, lastW, lastH, lastShape, lastEdge = px, py, facing, radius, w, h, shape, edge
    if not radius or radius <= 0 or w <= 0 or h <= 0 then return end

    local s, c = math.sin(facing), math.cos(facing)
    local edge2 = edge * edge
    for point, pin in pairs(active) do
        local dx, dy = px - point.x, py - point.y
        if rotate then dx, dy = dx * c - dy * s, dx * s + dy * c end
        dx, dy = dx / radius, dy / radius
        local quarter = (dx < 0 and 1 or 3) + (dy < 0 and 0 or 1)
        local inside
        if shape[quarter] then
            inside = dx * dx + dy * dy <= edge2
        else
            inside = math.max(math.abs(dx), math.abs(dy)) <= edge
        end
        if inside then
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", Minimap, "CENTER", dx * w, -dy * h)
            pin:Show()
        else
            pin:Hide()
        end
    end
end

-- Minimap --------------------------------------------------------------------

local function UpdateMinimap()
    local px, py, inst = HBD:GetPlayerWorldPosition()
    local on = db.minimap and px and py and inst and not IsInInstance()

    local range = db.range
    local hide2 = range * range
    local back2 = (range + REAPPEAR) * (range + REAPPEAR)
    local show2 = SHOW_RADIUS * SHOW_RADIUS

    -- Drop icons that fell out of view; swap picture <-> circle at the tracking range.
    for point, pin in pairs(active) do
        local keep = false
        if on and point.inst == inst then
            local dx, dy = point.x - px, point.y - py
            local d2 = dx * dx + dy * dy
            keep = d2 < show2
            if keep then SetNear(pin, d2 < (pin.near and back2 or hide2)) end
        end
        if not keep then
            ReleasePin(pin)
            active[point] = nil
        end
    end

    if not on then return end
    local cells = grid[inst]
    if not cells then return end

    local cx, cy = floor(px / CELL), floor(py / CELL)
    for ix = cx - 1, cx + 1 do
        for iy = cy - 1, cy + 1 do
            local cell = cells[CellKey(ix, iy)]
            if cell then
                for i = 1, #cell do
                    local point = cell[i]
                    if not active[point] then
                        local dx, dy = point.x - px, point.y - py
                        local d2 = dx * dx + dy * dy
                        if d2 < show2 then
                            local pin = AcquirePin(point.node, "minimap")
                            pin:SetParent(Minimap)
                            pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
                            pin:Hide() -- placed (and shown, if inside the draw range) next frame
                            SetNear(pin, d2 < hide2)
                            active[point] = pin
                            placeDirty = true
                        end
                    end
                end
            end
        end
    end
end

-- World map ------------------------------------------------------------------

local mapPins = {}
local mapRefreshQueued = false

local function RefreshWorldMapNow()
    mapRefreshQueued = false
    Pins:RemoveAllWorldMapIcons(ADDON)
    for i = #mapPins, 1, -1 do
        ReleasePin(mapPins[i])
        mapPins[i] = nil
    end

    if not (db and db.worldmap and WorldMapFrame and WorldMapFrame:IsShown()) then return end
    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end

    for _, node in ipairs(FN.nodes) do
        -- Pools show only while a pole is in hand, as on the minimap.
        if db.enabled[node.key] and (node.kind ~= "fish" or poleEquipped) then
            local flat = FN.points[node.key][mapID]
            if flat then
                for i = 1, #flat, 2 do
                    local pin = AcquirePin(node, "world")
                    Pins:AddWorldMapIconMap(ADDON, pin, mapID, flat[i], flat[i + 1])
                    mapPins[#mapPins + 1] = pin
                end
            end
        end
    end
end

-- Opening the map fires several events at once; collapse them into one refresh.
local function QueueWorldMapRefresh()
    if mapRefreshQueued then return end
    mapRefreshQueued = true
    C_Timer.After(0, RefreshWorldMapNow)
end

-- Public -----------------------------------------------------------------------

-- Call after a change to which nodes are shown, or where.
function FN:Refresh()
    RebuildGrid()
    UpdateMinimap()
    QueueWorldMapRefresh()
end

-- Call after locations were added to a node (Record.lua).
function FN:PointsChanged(key)
    worldCache[key] = nil
    if db.enabled[key] then FN:Refresh() end
    if FN.RefreshOptions then FN:RefreshOptions() end
end

-- Call after a change to looks only (sizes, colors, round icons): cheap enough for a slider drag.
function FN:Restyle()
    for _, pin in pairs(active) do StylePin(pin) end
    for i = 1, #mapPins do StylePin(mapPins[i]) end
end

-- Startup ----------------------------------------------------------------------

local function InitDB()
    ForeverNodesDB = ForeverNodesDB or {}
    db = ForeverNodesDB
    -- Fresh install: every herb and ore node is off until ticked; fishing pools
    -- start on (they only show with a pole equipped anyway).
    if type(db.enabled) ~= "table" then
        db.enabled = {}
        for _, node in ipairs(FN.nodes) do
            if node.kind == "fish" then db.enabled[node.key] = true end
        end
    end

    -- Herbs and ore were recorded under one setting before; each now has its own.
    if type(db.recordGather) == "boolean" then
        if db.recordHerb == nil then db.recordHerb = db.recordGather end
        if db.recordOre == nil then db.recordOre = db.recordGather end
        db.recordGather = nil
    end
    for key, value in pairs(FN.defaults) do
        if key ~= "colors" and key ~= "icons" and type(db[key]) ~= type(value) then
            db[key] = type(value) == "table" and { value[1], value[2], value[3], value[4] } or value
        end
    end

    -- Picture settings per map. Settings saved before the split (one size / round /
    -- zoom for both maps) carry over to each map.
    if type(db.icons) ~= "table" then db.icons = {} end
    for where, look in pairs(FN.defaults.icons) do
        local saved = db.icons[where]
        if type(saved) ~= "table" then
            saved = {}
            db.icons[where] = saved
        end
        if type(saved.size) ~= "number" then saved.size = type(db.iconSize) == "number" and db.iconSize or look.size end
        if type(saved.round) ~= "boolean" then
            if type(db.round) == "boolean" then saved.round = db.round else saved.round = look.round end
        end
        if type(saved.zoom) ~= "number" then saved.zoom = type(db.zoom) == "number" and db.zoom or look.zoom end
    end
    db.iconSize, db.round, db.zoom, db.roundDefault = nil, nil, nil, nil
    -- One-time: docking to the world map became the default.
    if not db.dockDefault then
        db.dock = true
        db.dockDefault = true
    end
    if type(db.colors) ~= "table" then db.colors = {} end
    for kind, color in pairs(FN.defaults.colors) do
        if type(db.colors[kind]) ~= "table" then
            db.colors[kind] = { color[1], color[2], color[3] }
        end
    end

    -- One-time: replace the first release's guessed 100-yard default with the measured value.
    if not db.rangeMeasured then
        if db.range == 100 then db.range = FN.DEFAULT_RANGE end
        db.rangeMeasured = true
    end
    FN.db = db
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
driver:RegisterEvent("SKILL_LINES_CHANGED")

local elapsedSince, sincePoleCheck = 0, 0
local function OnUpdate(_, elapsed)
    if next(active) then PlaceMinimapPins() end
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.2 then return end
    -- Re-check the main hand about once a second, in case an equipment event was missed.
    sincePoleCheck = sincePoleCheck + elapsedSince
    elapsedSince = 0
    if sincePoleCheck >= 1 then
        sincePoleCheck = 0
        local pole = CheckPole()
        if pole ~= poleEquipped then
            poleEquipped = pole
            if FN.UpdatePoleNote then FN:UpdatePoleNote() end
            QueueWorldMapRefresh()
            RebuildGrid()
        end
    end
    UpdateMinimap()
end

-- "/fn pole": what the addon sees in the main hand, for troubleshooting.
local function PrintPoleInfo()
    local id = GetInventoryItemID("player", INVSLOT_MAINHAND or 16)
    local classID, subClassID
    if id then classID, subClassID = select(6, C_Item.GetItemInfoInstant(id)) end
    local pools = 0
    for _, node in ipairs(FN.nodes) do
        if node.kind == "fish" and db.enabled[node.key] then pools = pools + 1 end
    end
    print(("|cffffd100Forever Nodes|r main hand item %s, class %s, subclass %s, fishing pole: %s, pool types ticked: %d")
        :format(tostring(id), tostring(classID), tostring(subClassID), tostring(CheckPole()), pools))
end

driver:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        InitDB()
        self:UnregisterEvent("ADDON_LOADED")
    elseif not db then
        return
    elseif event == "PLAYER_LOGIN" then
        poleEquipped = CheckPole()
        if FN.LoadRecorded then FN:LoadRecorded() end -- pools recorded in earlier sessions
        RebuildGrid()
        self:SetScript("OnUpdate", OnUpdate)
        if WorldMapFrame then
            WorldMapFrame:HookScript("OnShow", QueueWorldMapRefresh)
            WorldMapFrame:HookScript("OnHide", QueueWorldMapRefresh)
            if WorldMapFrame.OnMapChanged then
                hooksecurefunc(WorldMapFrame, "OnMapChanged", QueueWorldMapRefresh)
            end
        end
        FN:SetupButtons()
        local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "1.1.1"
        -- Gold name, white version, gold author; the hint goes on its own indented line.
        -- The yellow star is the game's own raid target marker, drawn at text height.
        print(("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t |cffffd100Forever Nodes|r |cffffffffv%s by Lvcid|r"
            .. " |cffffffff(|r|cffffd100/fn|r|cffffffff to open)|r"):format(version))
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED" then
        local pole = CheckPole()
        if pole ~= poleEquipped then
            poleEquipped = pole
            if FN.UpdatePoleNote then FN:UpdatePoleNote() end
            QueueWorldMapRefresh()
            RebuildGrid()
        end
        UpdateMinimap()
    elseif event == "SKILL_LINES_CHANGED" then
        if FN.RefreshOptions then FN:RefreshOptions() end
    end
end)

SLASH_FOREVERNODES1 = "/fn"
SLASH_FOREVERNODES2 = "/fnodes"
SLASH_FOREVERNODES3 = "/forevernodes"
SlashCmdList.FOREVERNODES = function(text)
    text = text and text:lower() or ""
    if text:match("^%s*pole") then
        PrintPoleInfo()
    elseif text:match("^%s*debug") then
        -- Prints where fishing loot came from, to check that pool recording sees pools.
        db.debug = not db.debug
        print("|cffffd100Forever Nodes:|r debug messages " .. (db.debug and "on" or "off"))
    else
        FN:OpenFromCommand()
    end
end

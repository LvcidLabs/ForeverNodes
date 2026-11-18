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

-- Draws a ring on `tex`: `radius` to the middle of its line, `width` px thick. Returns how
-- wide it is across (0 when there is nothing to draw).
local function Ring(tex, radius, width, c)
    local across = 2 * radius + width
    if width <= 0 or across <= 0 then
        tex:Hide()
        return 0
    end
    tex:SetTexture(RingTexture(math.min(width, across / 2), across))
    tex:SetSize(across, across)
    tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    tex:Show()
    return across
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
    -- Marker for a node inside the tracking range, up to four parts drawn together (bottom to
    -- top): the circle's border, the circle, the dot and the dot's border. Each part is on or
    -- off, takes the profession's color or its own ("prof" / "custom"), and has its own size.
    -- Ring radii are from the center to the middle of the line.
    dotOn = true,
    dotColorMode = "prof",
    dotColor = { 1, 1, 1 },
    dotSize = 4,
    dotEdgeOn = true,
    dotEdgeColorMode = "custom",
    dotEdgeColor = { 0, 0, 0, 0.63 },
    dotEdgeRadius = 2.25,
    dotEdgeWidth = 1,
    circleOn = false,
    circleColorMode = "prof",
    circleColor = { 0, 0, 0 },
    circleRadius = 6.25,
    circleWidth = 1.5,
    circleEdgeOn = true,
    circleEdgeColorMode = "custom",
    circleEdgeColor = { 0, 0, 0, 0.63 },
    circleEdgeRadius = 7.5,
    circleEdgeWidth = 0.5,
    tone = "auto",   -- the panel's colors: "auto" (follows the interface), "brown" or "dark"
    mapButtonShown = true, -- the node panel's button on the world map
    showAll = true,  -- nodes of professions the character lacks can be ticked and shown on the maps
    onlyTracked = true, -- herbs show only while Find Herbs is on, ore only while Find Minerals is on
    onlyPole = true,    -- fishing pools show only while a fishing pole is equipped
    cutoffs = true,     -- (Lvl sort) a faint line where each untrained rank ends
    azShowBeyond = true, -- (A-Z sort) list nodes beyond the current rank too
    muteAtMax = true,   -- at trained skill 300 the list drops its difficulty colors
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
    local info = FN:GetSkillInfo(kind)
    if info then return info.rank, info.icon end
    return nil
end

-- Everything about a gathering profession the character knows, or nil:
--   rank       trained skill (what ranks and the 300 check go by)
--   max        the current rank's cap (75, 150, 225 or 300)
--   bonus      skill from gear, racials, food... (rankModifier)
--   effective  rank + bonus: what the character can actually gather
--   icon       the profession's icon
function FN:GetSkillInfo(kind)
    if not (GetProfessions and GetProfessionInfo) then return nil end
    local line = SKILL_LINES[kind]
    local slots = { GetProfessions() }
    for i = 1, 6 do
        local index = slots[i]
        if index then
            local _, icon, rank, maxRank, _, _, id, rankModifier = GetProfessionInfo(index)
            if id == line then
                rank = rank or 0
                local bonus = rankModifier or 0
                return { rank = rank, max = maxRank or 0, bonus = bonus, effective = rank + bonus, icon = icon }
            end
        end
    end
    return nil
end

-- Gathering difficulty color for a node needing `need` skill, as the game colors it in
-- Forever: orange from the requirement, yellow from +25, green from +65 (Classic used +50),
-- grey from +100, red below the requirement. `skill` nil (profession not known) is red.
-- Returns r, g, b and a name ("red", "orange", "yellow", "green", "grey").
function FN:DifficultyColor(skill, need)
    if not skill or skill < need then return 1, 0.13, 0.13, "red" end
    local over = skill - need
    if over < 25 then return 1, 0.5, 0.25, "orange" end
    if over < 65 then return 1, 1, 0, "yellow" end
    if over < 100 then return 0.25, 0.75, 0.25, "green" end
    return 0.5, 0.5, 0.5, "grey"
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

-- Find Herbs / Find Minerals: which one is on. Each kind is true (tracking on),
-- false (the character has it but it is off) or nil (no such tracking spell, or
-- the game gave no answer); only false hides that kind's nodes.
local TRACK_SPELL = { herb = 2383, ore = 2580 }
local TRACK_ICON = {
    herb = { [133939] = true, ["interface\\icons\\inv_misc_flower_02"] = true },
    ore = { [136025] = true, ["interface\\icons\\spell_nature_earthquake"] = true },
}

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

-- Which tracking kind a tracking entry is, from its spell, icon or name.
local function TrackKind(name, texture, spellID)
    if type(texture) == "string" then texture = texture:lower() end
    for kind, id in pairs(TRACK_SPELL) do
        if spellID == id or (texture and TRACK_ICON[kind][texture])
            or (name and name == SpellName(id)) then
            return kind
        end
    end
end

local tracking = {}
local function ReadTracking()
    local state = {}
    if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
        for i = 1, C_Minimap.GetNumTrackingTypes() or 0 do
            local name, texture, active, spellID
            local info = C_Minimap.GetTrackingInfo(i)
            if type(info) == "table" then
                name, texture, active, spellID = info.name, info.texture, info.active, info.spellID
            else
                local _
                name, texture, active, _, _, spellID = C_Minimap.GetTrackingInfo(i)
            end
            -- Protected ("secret") values can't be read by addons: such an entry counts as
            -- unknown, which never hides anything.
            local secret = issecretvalue and (issecretvalue(name) or issecretvalue(texture)
                or issecretvalue(active) or issecretvalue(spellID))
            local ok, kind = false, nil
            if not secret then ok, kind = pcall(TrackKind, name, texture, spellID) end
            if ok and kind then state[kind] = active and true or false end
        end
    elseif GetTrackingTexture then
        -- Older clients: one tracking at a time, known only by its icon.
        local on = TrackKind(nil, GetTrackingTexture())
        for kind, id in pairs(TRACK_SPELL) do
            if IsPlayerSpell and IsPlayerSpell(id) then state[kind] = (on == kind) end
        end
    end
    return state
end

-- Re-reads tracking; true when it changed.
local function UpdateTracking()
    local state = ReadTracking()
    local changed = state.herb ~= tracking.herb or state.ore ~= tracking.ore
    tracking = state
    return changed
end

-- Which gathering professions this character has. True when that changed.
local learned = {}
local function UpdateLearned()
    local changed = false
    for _, kind in ipairs(FN.kinds) do
        local has = FN:GetSkillInfo(kind) ~= nil
        if has ~= learned[kind] then
            learned[kind] = has
            changed = true
        end
    end
    return changed
end

-- Whether a ticked node type is shown right now.
local function Showable(node)
    -- Ticks for an unlearned profession are kept, but rest while the option is off.
    if not db.showAll and not learned[node.kind] then return false end
    -- Pools have no tracking spell: they show while a pole is in hand.
    if node.kind == "fish" then return poleEquipped or not db.onlyPole end
    if db.onlyTracked and tracking[node.kind] == false then return false end
    return true
end

-- The in-range marker, drawn on `f` (a pin, or the settings' preview), which holds the
-- textures halo (circle), inner (the circle's border), mark (dot) and edge (the dot's
-- border). `color` is the profession's color. Sizes `f` to its largest part.
function FN:DrawMarker(f, color)
    local whole = 1
    local function Grow(d) if d > whole then whole = d end end
    local function Pick(mode, own) return mode == "custom" and own or color end

    -- Circle, with its border underneath.
    if db.circleOn then
        Grow(Ring(f.halo, db.circleRadius, db.circleWidth, Pick(db.circleColorMode, db.circleColor)))
    else
        f.halo:Hide()
    end
    if db.circleEdgeOn then
        Grow(Ring(f.inner, db.circleEdgeRadius, db.circleEdgeWidth, Pick(db.circleEdgeColorMode, db.circleEdgeColor)))
    else
        f.inner:Hide()
    end

    -- Dot, and its border on top of it.
    if db.dotOn and db.dotSize > 0 then
        local c = Pick(db.dotColorMode, db.dotColor)
        f.mark:SetTexture(DISC)
        f.mark:SetSize(db.dotSize, db.dotSize)
        f.mark:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        f.mark:Show()
        Grow(db.dotSize)
    else
        f.mark:Hide()
    end
    if db.dotEdgeOn then
        Grow(Ring(f.edge, db.dotEdgeRadius, db.dotEdgeWidth, Pick(db.dotEdgeColorMode, db.dotEdgeColor)))
    else
        f.edge:Hide()
    end
    f:SetSize(whole, whole)
end

-- Gives `f` the marker's textures, bottom to top: the circle's border, circle, dot, the
-- dot's border.
function FN:MarkerTextures(f)
    f.inner = f:CreateTexture(nil, "BORDER", nil, 0)
    f.halo = f:CreateTexture(nil, "BORDER", nil, 1)
    f.mark = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.edge = f:CreateTexture(nil, "OVERLAY")
    for _, t in ipairs({ f.inner, f.halo, f.mark, f.edge }) do t:SetPoint("CENTER") end
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
        FN:DrawMarker(pin, color)
        return
    end

    local look = db.icons[pin.where] or db.icons.minimap
    pin:SetSize(look.size, look.size)
    pin.mark:Hide()
    pin.edge:Hide()
    pin.halo:Hide()
    pin.inner:Hide()
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

        FN:MarkerTextures(pin) -- the in-range marker
    end
    pin.node = node
    pin.where = where
    pin.near = false
    -- World map icons can show a tooltip: hover only, clicks still reach the map.
    -- Minimap icons never take the mouse.
    local hover = where == "world" and FN:TipCfg("world").on and pin.EnableMouseMotion ~= nil
    if hover then
        pin:EnableMouseMotion(true)
        if pin.SetMouseClickEnabled then pin:SetMouseClickEnabled(false) end
        pin:SetScript("OnEnter", function(self) if FN.ShowWorldTip then FN:ShowWorldTip(self) end end)
        pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        pin:EnableMouse(false)
        pin:SetScript("OnEnter", nil)
        pin:SetScript("OnLeave", nil)
    end
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
        if FN.enabled[node.key] and Showable(node) then
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

-- Minimap tooltips -----------------------------------------------------------
-- The game's own minimap tooltip no longer lets addons read which herb or vein a
-- yellow dot is, so it is worked out from where the cursor is: the known spawn
-- points (of every herb and ore, whether ticked or not) right under it.

local tipGrid -- [instanceID][cellKey] = { point, ... }, every herb and ore spawn point

local function TipGrid()
    if tipGrid then return tipGrid end
    tipGrid = {}
    for _, node in ipairs(FN.nodes) do
        if node.kind ~= "fish" and node.skill and node.skill > 0 then
            local list = WorldPoints(node.key)
            for i = 1, #list do
                local point = list[i]
                local cells = tipGrid[point.inst]
                if not cells then
                    cells = {}
                    tipGrid[point.inst] = cells
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
    return tipGrid
end

-- The herb and vein types with a spawn point within `reach` px of the cursor on the minimap,
-- as { node = distance in px, ... }. Only kinds that have dots count (see below). nil when
-- the minimap view can't be worked out.
function FN:MinimapNodesNearCursor(reach)
    local px, py, inst = HBD:GetPlayerWorldPosition()
    if not (px and py and inst) or IsInInstance() then return nil end
    local rotate = GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing() or 0
    if not facing then return nil end
    local radius = ViewRadius()
    local w, h = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    if not (radius and radius > 0 and w > 0 and h > 0 and mx and scale and scale > 0) then return nil end

    -- The cursor in the same terms the icons are placed in (see PlaceMinimapPins).
    local cx, cy = GetCursorPosition()
    local ndx, ndy = (cx / scale - mx) / w, -(cy / scale - my) / h
    -- The world spot under the cursor, to find the grid cells to look in.
    local s, c = math.sin(facing), math.cos(facing)
    local wx, wy = ndx * radius, ndy * radius
    if rotate then wx, wy = wx * c + wy * s, -wx * s + wy * c end
    local tx, ty = px - wx, py - wy

    local cells = TipGrid()[inst]
    if not cells then return nil end
    local near, reach2 = {}, reach * reach
    -- Which kinds have dots: the ones being tracked. Where the game gives no tracking answer
    -- for a kind (the character lacks that tracking spell), the character must at least know
    -- the profession, or e.g. veins would be matched while only herbs show.
    local shown = {}
    for _, kind in ipairs({ "herb", "ore" }) do
        if tracking[kind] == nil then shown[kind] = FN:GetSkillInfo(kind) ~= nil
        else shown[kind] = tracking[kind] end
    end
    local gx, gy = floor(tx / CELL), floor(ty / CELL)
    for ix = gx - 1, gx + 1 do
        for iy = gy - 1, gy + 1 do
            local cell = cells[CellKey(ix, iy)]
            if cell then
                for i = 1, #cell do
                    local point = cell[i]
                    local node = point.node
                    if shown[node.kind] then
                        local dx, dy = px - point.x, py - point.y
                        if rotate then dx, dy = dx * c - dy * s, dx * s + dy * c end
                        local ox, oy = (dx / radius - ndx) * w, (dy / radius - ndy) * h
                        local d = ox * ox + oy * oy
                        if d <= reach2 and (not near[node] or d < near[node]) then near[node] = d end
                    end
                end
            end
        end
    end
    for node, d in pairs(near) do near[node] = math.sqrt(d) end
    return near
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
FN.mapPins = mapPins -- for the world map tooltip (Tooltips.lua)
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
        -- Same rules as the minimap (pole for pools, tracking for herbs and ore).
        if FN.enabled[node.key] and Showable(node) then
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
    tipGrid = nil
    if FN.enabled[key] then FN:Refresh() end
    if FN.RefreshOptions then FN:RefreshOptions() end
end

-- Call after a change to looks only (sizes, colors, round icons): cheap enough for a slider drag.
function FN:Restyle()
    for _, pin in pairs(active) do StylePin(pin) end
    for i = 1, #mapPins do StylePin(mapPins[i]) end
    if FN.MarkerPreview then FN:MarkerPreview() end -- the settings' sample
end

-- Startup ----------------------------------------------------------------------

local function InitDB()
    ForeverNodesDB = ForeverNodesDB or {}
    db = ForeverNodesDB
    -- A first install starts on the defaults: nothing older to carry over.
    if next(db) == nil then
        db.markerParts = true
        db.tips = {} -- each tooltip then takes its own defaults (see FN:TipCfg)
    end
    -- Once per account, new installs and players updating alike: the next world map opening
    -- points out the panel button and offers the tutorial.
    if not db.tutorialOffered then
        db.tutorialOffered = true
        db.spotlightDue = true
    end
    db.enabled = nil -- the old account-wide starting list: new characters now start empty

    -- Which nodes are ticked and whether the panel is open are kept per character;
    -- everything else stays account-wide. A new character starts with nothing ticked
    -- and the panel closed.
    ForeverNodesCharDB = ForeverNodesCharDB or {}
    local char = ForeverNodesCharDB
    local isNew = type(char.enabled) ~= "table"
    if isNew then char.enabled = {} end
    FN.enabled = char.enabled
    if type(char.panel) ~= "table" then
        -- A character from before this was per character carries on as the account was left.
        local old = not isNew and type(db.panel) == "table" and db.panel.open
        char.panel = { open = old and true or false }
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
    -- One-time (1.2.2): the "circle or dot" choice became four parts that can show together.
    -- Each old look is rebuilt from its own settings (or the old defaults, where one was never
    -- saved), so markers look the same as before. The old settings are dropped afterwards.
    if not db.markerParts then
        local OLD = { nearStyle = "dot", circleSize = 9, circleLine = 2, circleBorder = 1,
            circleBorderColor = { 0, 0, 0 }, dotBorder = 0.5, dotBorderColor = { 0, 0, 0 },
            dotRing = false, dotRingSize = 13, dotRingWidth = 1, dotRingColor = { 0, 0, 0, 0.345 } }
        local function Old(key)
            local v = db[key]
            if type(v) ~= type(OLD[key]) then v = OLD[key] end
            return v
        end
        local function Copy(c) return { c[1], c[2], c[3], c[4] } end
        if Old("nearStyle") == "circle" then
            -- The old circle's size was across its outside edge.
            local size, line, border = Old("circleSize"), Old("circleLine"), Old("circleBorder")
            db.dotOn, db.dotEdgeOn = false, false
            db.circleOn, db.circleColorMode = true, "prof"
            db.circleWidth = line
            db.circleRadius = size / 2 - line / 2
            -- Its outline ran along both sides of the line, touching it: one wider ring under
            -- the circle, showing on each side of it, looks the same.
            db.circleEdgeOn = border > 0
            db.circleEdgeColorMode, db.circleEdgeColor = "custom", Copy(Old("circleBorderColor"))
            db.circleEdgeRadius = db.circleRadius
            db.circleEdgeWidth = line + 2 * border
        else
            local border = Old("dotBorder")
            db.dotOn, db.dotColorMode = true, "prof"
            -- The old border showed just outside the dot.
            db.dotEdgeOn = border > 0
            db.dotEdgeColorMode, db.dotEdgeColor = "custom", Copy(Old("dotBorderColor"))
            if border > 0 then db.dotEdgeWidth = border end
            db.dotEdgeRadius = db.dotSize / 2 + db.dotEdgeWidth / 2
            -- The old second ring becomes the circle, in its own color.
            local ringWidth = Old("dotRingWidth")
            db.circleOn = Old("dotRing")
            db.circleColorMode, db.circleColor = "custom", Copy(Old("dotRingColor"))
            db.circleWidth = ringWidth
            db.circleRadius = Old("dotRingSize") / 2 - ringWidth / 2
            db.circleEdgeOn = false
        end
        for key in pairs(OLD) do db[key] = nil end
        db.markerParts = true
    end
    -- Settings no longer used by this version.
    db.trainerCols, db.mapButtonSide, db.tipMinimap = nil, nil, nil
    if type(db.tips) == "table" then -- the 1.2.1 tooltip settings, once carried over (FN:TipCfg)
        db.tipWorldMap, db.tipOverworld, db.tipOverworldLine = nil, nil, nil
        db.tipBrackets, db.tipPosition, db.tipColor = nil, nil, nil
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
driver:RegisterEvent("MINIMAP_UPDATE_TRACKING")

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
        -- Same for tracking, in case MINIMAP_UPDATE_TRACKING was missed.
        if UpdateTracking() and db.onlyTracked then
            QueueWorldMapRefresh()
            RebuildGrid()
        end
    end
    UpdateMinimap()
end

-- "/fn checkpole": what the addon sees in the main hand, for troubleshooting.
local function PrintPoleInfo()
    local id = GetInventoryItemID("player", INVSLOT_MAINHAND or 16)
    local classID, subClassID
    if id then classID, subClassID = select(6, C_Item.GetItemInfoInstant(id)) end
    local pools = 0
    for _, node in ipairs(FN.nodes) do
        if node.kind == "fish" and FN.enabled[node.key] then pools = pools + 1 end
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
        UpdateTracking()
        UpdateLearned()
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
        local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "1.4.0"
        -- Gold name, white version, gold author; the hint goes on its own indented line.
        -- The yellow star is the game's own raid target marker, drawn at text height.
        -- The hint names the quickest way in that this player has on screen.
        local button = db.mapButtonShown and "map button"
            or (FN.MinimapButtonShown and FN:MinimapButtonShown() and "minimap button")
        local also = button and ("|cffffffff or |r|cffffd100" .. button .. "|r") or ""
        print(("|cffffd100<Forever Nodes>|r |cffffffffv%s by Lvcid|r"
            .. " |cffffffff(|r|cffffd100/fn|r%s|cffffffff to open)|r"):format(version, also))
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
        local tracked = UpdateTracking() and db.onlyTracked -- a tracking spell learned
        local profession = UpdateLearned() and not db.showAll -- its resting ticks wake up
        if tracked or profession then FN:Refresh() end
    elseif event == "MINIMAP_UPDATE_TRACKING" then
        if UpdateTracking() and db.onlyTracked then FN:Refresh() end
    end
end)

SLASH_FOREVERNODES1 = "/fn"
SLASH_FOREVERNODES2 = "/fnodes"
SLASH_FOREVERNODES3 = "/forevernodes"
SlashCmdList.FOREVERNODES = function(text)
    text = text and text:lower() or ""
    local command = text:match("^%s*(%a+)")
    if command == "help" or command == "tutorial" or command == "dfl" then
        db.spotlightDue = true
        print("|cffffd100Forever Nodes:|r the quick guide shows the next time the world map opens")
        return
    end
    if text:match("^%s*checkpole") then
        PrintPoleInfo()
    elseif text:match("^%s*ttdebug") then
        -- Prints what the minimap tooltip matching sees (widths, candidates, learned padding).
        FN.tipDebug = not FN.tipDebug
        print("|cffffd100Forever Nodes:|r minimap tooltip debug " .. (FN.tipDebug and "on" or "off"))
    elseif text:match("^%s*ttreset") then
        db.tipWidthPads = nil
        print("|cffffd100Forever Nodes:|r minimap tooltip widths forgotten; they are learned again")
    elseif text:match("^%s*debug") then
        -- Prints where fishing loot came from, to check that pool recording sees pools.
        db.debug = not db.debug
        print("|cffffd100Forever Nodes:|r debug messages " .. (db.debug and "on" or "off"))
    else
        FN:OpenFromCommand()
    end
end

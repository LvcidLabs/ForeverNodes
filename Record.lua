local _, FN = ...

-- Recording fishing pools ----------------------------------------------------------
-- The bundled data has no locations for several pool types, so the addon learns
-- them: when a catch comes out of a pool, the pool's spot is saved. A pool type
-- that is not in the list yet is added to the Fishing list, unticked.
--
-- Two ways to tell that a catch came from a pool, and which one:
--   1. The loot's source. Open-water loot comes from the bobber; if the game
--      names a different object, that object is the pool.
--   2. The pool the player pointed at. Hovering a pool shows its name, the only
--      place the game gives an addon an object's name. A pool hovered shortly
--      before the catch (as when aiming the cast) is taken to be the one fished.

local HBD = LibStub("HereBeDragons-2.0")

local BOBBER = 35591
local CAST_DISTANCE = 13 -- yards from the player to where the bobber usually lands
local MERGE = 0.004      -- map fraction: closer than this to a known spot is the same pool
local HOVER_WINDOW = 90  -- seconds a hovered pool stays the likely source of the next catch
local CAST_WINDOW = 45   -- seconds after a Fishing cast in which loot counts as a catch

-- Pool object ID -> the bundled node it belongs to.
local KNOWN = {
    firefin_snapper_school = { 180902, 180683, 180657, 180752 },
    oily_blackmouth_school = { 180750, 180900, 180682, 180664, 180582 },
    sagefish_school = { 180656, 180663 },
    floating_debris = { 180655 },
    floating_wreckage = { 180685, 180662, 180901, 180751 },
}
local keyByID = {}
for key, ids in pairs(KNOWN) do
    for _, id in ipairs(ids) do keyByID[id] = key end
end

-- Pool types the game has but the bundled data has no locations for.
local NAMES = {
    [180658] = "School of Deviate Fish",
    [180684] = "Greater Sagefish School",
    [180712] = "Stonescale Eel Swarm",
    [180753] = "Patch of Elemental Water",
    [180248] = "School of Tastyfish",
    [180184] = "School of Fish",
    [180369] = "Muddy Churning Waters",
    [572928] = "School of Whimsyfin",
}

-- Words that mark an object name as a fishing pool, for types in neither table.
local POOL_WORDS = { "School", "Swarm", "Wreckage", "Debris", "Patch of", "Churning", "Pool" }

local function Say(text)
    -- The same yellow star marker the login line starts with.
    FN:Print("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t |cffffd100Forever Nodes:|r " .. text)
end

local function Debug(text)
    if FN.db and FN.db.debug then Say(text) end
end

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- The last world object the cursor was over.
local hoveredName, hoveredAt
local OnTooltipRead -- set further down: remembers the tooltip if it names a pool
local function NoteHovered(title)
    if title and not IsSecret(title) and title ~= "" then
        hoveredName, hoveredAt = title, GetTime()
        if OnTooltipRead then OnTooltipRead() end
    end
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(_, data)
        NoteHovered(data and data.lines and data.lines[1] and data.lines[1].leftText)
    end)
end

-- A second way to see what the cursor is over, in case the client does not send
-- world-object tooltips through the hook above: read the tooltip's first line a
-- few times a second while it is showing.
local function ReadTooltip()
    if not (GameTooltip and GameTooltip:IsShown()) then return end
    local line = GameTooltipTextLeft1
    local text = line and line:GetText()
    if text and not IsSecret(text) and text ~= "" then
        hoveredName, hoveredAt = text, GetTime()
        if OnTooltipRead then OnTooltipRead() end
    end
end
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.25, ReadTooltip) end

-- Pool name -> node key, for every pool type the addon knows.
local function KeyForName(name)
    for _, node in ipairs(FN.nodes) do
        if node.kind == "fish" and FN:NodeMatches(node, name) then return node.key end
    end
    for id, known in pairs(NAMES) do
        if known == name or FN:ClientName(known) == name then return "pool_" .. id end
    end
    for _, word in ipairs(POOL_WORDS) do
        if name:find(word, 1, true) then
            return "pool_" .. name:lower():gsub("[^%a%d]+", "_")
        end
    end
    return nil
end

-- The last *pool* the cursor was over (other tooltips in between do not erase it).
local poolName, poolAt
local function NotePool()
    if hoveredName and KeyForName(hoveredName) then poolName, poolAt = hoveredName, hoveredAt end
end

OnTooltipRead = NotePool

-- The pool the player pointed at recently: key and name, or nil.
local function HoveredPool()
    NotePool()
    if not (poolName and poolAt) or GetTime() - poolAt > HOVER_WINDOW then return nil end
    return KeyForName(poolName), poolName
end

-- Stand-in pictures for recorded node types the bundled data has no art for.
local NEW_TYPE_ICONS = { fish = "Fish\\Fishhook", herb = "Herb\\peacebloom", ore = "Ore\\copper" }

-- Adds a recorded node type to the node list (once), unticked. `kind` defaults to a pool.
local function EnsureNode(key, name, kind)
    if FN.byKey[key] then return false end
    kind = kind or "fish"
    local node = { key = key, kind = kind, name = name, icon = FN.MEDIA .. NEW_TYPE_ICONS[kind], skill = 0 }
    FN.nodes[#FN.nodes + 1] = node
    FN.byKey[key] = node
    FN.points[key] = FN.points[key] or {}
    return true
end

local function HasPointNear(flat, x, y)
    for i = 1, #flat, 2 do
        if math.abs(flat[i] - x) < MERGE and math.abs(flat[i + 1] - y) < MERGE then return true end
    end
    return false
end

-- Called at login: puts everything recorded in earlier sessions back into the data.
function FN:LoadRecorded()
    local db = FN.db
    if type(db.recordedNodes) ~= "table" then db.recordedNodes = {} end
    if type(db.recordedPoints) ~= "table" then db.recordedPoints = {} end
    -- Herbs once taken for pools (picked soon after a fishing cast) are dropped.
    local herbOrOre = FN.gatherKeyByID or {}
    for key, info in pairs(db.recordedNodes) do
        if info.kind == "fish" and info.id and herbOrOre[info.id] then
            db.recordedNodes[key], db.recordedPoints[key] = nil, nil
        end
    end
    for key, info in pairs(db.recordedNodes) do
        EnsureNode(key, info.name or key, info.kind)
    end
    for key, maps in pairs(db.recordedPoints) do
        if FN.points[key] then
            for mapID, flat in pairs(maps) do
                local target = FN.points[key][mapID]
                if not target then
                    target = {}
                    FN.points[key][mapID] = target
                end
                for i = 1, #flat, 2 do
                    if not HasPointNear(target, flat[i], flat[i + 1]) then
                        target[#target + 1] = flat[i]
                        target[#target + 1] = flat[i + 1]
                    end
                end
            end
        end
    end
end

-- Where the pool probably is: a cast's length in front of the player, in map coordinates.
local function PoolPosition()
    local x, y, mapID = HBD:GetPlayerZonePosition()
    if not (x and y and mapID) then return nil end
    local facing = GetPlayerFacing and GetPlayerFacing()
    local width, height = HBD:GetZoneSize(mapID)
    if facing and not IsSecret(facing) and width and height and width > 0 and height > 0 then
        -- Facing 0 is north and turns counter-clockwise; map x runs east, map y runs south.
        x = x - math.sin(facing) * CAST_DISTANCE / width
        y = y - math.cos(facing) * CAST_DISTANCE / height
    end
    return x, y, mapID
end

-- Saves a spot for node `key` (adding the node type first if it is new).
-- `x, y, mapID`: where it is; `kind`: "fish", "herb" or "ore".
local LIST_NAMES = { fish = "Fishing", herb = "Herbalism", ore = "Mining" }
local TYPE_WORDS = { fish = "pool", herb = "herb", ore = "ore" }
local function RecordSpot(key, name, objectID, kind, x, y, mapID)
    local db = FN.db
    x, y = math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000

    local isNewType = false
    if not FN.byKey[key] then
        name = name or ((kind == "fish" and "Fishing Pool " or "Unknown Node ") .. tostring(objectID or "?"))
        db.recordedNodes[key] = { name = name, id = objectID, kind = kind }
        isNewType = EnsureNode(key, name, kind)
    end
    local node = FN.byKey[key]

    local known = FN.points[key][mapID]
    if not known then
        known = {}
        FN.points[key][mapID] = known
    end
    if HasPointNear(known, x, y) then
        Debug(("%s here is already on the map"):format(node.name))
        return
    end
    known[#known + 1] = x
    known[#known + 1] = y

    db.recordedPoints[key] = db.recordedPoints[key] or {}
    local saved = db.recordedPoints[key][mapID]
    if not saved then
        saved = {}
        db.recordedPoints[key][mapID] = saved
    end
    saved[#saved + 1] = x
    saved[#saved + 1] = y

    if isNewType then
        Say(("new %s type recorded: %s. It is in the %s list, unticked.")
            :format(TYPE_WORDS[kind] or "node", node.name, LIST_NAMES[kind] or "node"))
    else
        Say(("recorded a new spot for %s."):format(node.name))
    end
    FN:PointsChanged(key)
end

local function RecordPool(key, name, objectID)
    local x, y, mapID = PoolPosition()
    if not x then
        Debug("pool not recorded: the game gave no map position here")
        return
    end
    RecordSpot(key, name, objectID, "fish", x, y, mapID)
end

-- The object the fishing loot came out of when it is not the bobber, or nil.
local function LootSourceObject()
    if not (GetNumLootItems and GetLootSourceInfo) then return nil end
    for slot = 1, GetNumLootItems() do
        local guid = GetLootSourceInfo(slot)
        if guid and not IsSecret(guid) then
            Debug("fishing loot source: " .. guid)
            local kind, _, _, _, _, id = strsplit("-", guid)
            id = tonumber(id)
            if kind == "GameObject" and id and id ~= BOBBER then return id end
        elseif guid then
            Debug("fishing loot source is hidden from addons")
        end
    end
    return nil
end

-- Whether the loot window that just opened is a fishing catch. The game's own
-- answer is used when it has one; a recent Fishing cast counts as well, in case
-- this client does not flag fishing loot.
local FISHING_SPELLS = { 7620, 7731, 7732, 18248, 131474 }
local castAt = 0
local function IsFishingSpell(spellID)
    if not spellID or IsSecret(spellID) then return false end
    for _, id in ipairs(FISHING_SPELLS) do
        if id == spellID then return true end
    end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    local fishing = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(7620)
    return name ~= nil and name == fishing
end
-- Where the game can say whether loot is a catch, only its word counts: a herb
-- picked soon after a cast must not be taken for a pool.
local function IsCatch()
    if IsFishingLoot then return IsFishingLoot() and true or false end
    return GetTime() - castAt < CAST_WINDOW
end
local gatherKeyByID -- herb and ore object IDs (filled in below), never recorded as pools

local lastCatchAt = 0
local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    local db = FN.db
    if not (db and db.record) then return end

    if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and IsFishingSpell(spellID) then
            castAt = GetTime()
            ReadTooltip() -- the pool is often under the cursor at the moment of the cast
            NotePool()
            Debug("fishing cast seen" .. (poolName and (", last pool pointed at: " .. poolName) or ""))
        end
        return
    end

    if not IsCatch() then return end
    if GetTime() - lastCatchAt < 2 then return end -- both loot events fire for one catch

    local objectID = LootSourceObject()
    local key, name = HoveredPool()
    if objectID and gatherKeyByID[objectID] then
        Debug("loot came from a herb or vein, not a pool: not recorded as a pool")
    elseif objectID then
        lastCatchAt = GetTime()
        RecordPool(keyByID[objectID] or ("pool_" .. objectID), NAMES[objectID], objectID)
    elseif key then
        lastCatchAt = GetTime()
        Debug("pool taken from the last one pointed at: " .. name)
        RecordPool(key, name, nil)
    else
        Debug("catch not recorded: the loot came from the bobber and no pool was pointed at in the last "
            .. HOVER_WINDOW .. " seconds" .. (hoveredName and (" (last tooltip: " .. hoveredName .. ")") or ""))
    end
    castAt = 0 -- this cast's catch has been dealt with
end)

-- Recording herbs and ore ----------------------------------------------------------
-- When the character picks a herb or mines a vein, the spot they are standing on
-- is saved (gathering needs you within a few yards, so it is accurate). Which
-- node it was comes from the loot's source object, or failing that the name of
-- the node being interacted with or last pointed at. A herb or ore the list does
-- not have yet joins its profession's list, unticked.

local GATHER_WINDOW = 15 -- seconds between the gather cast and its loot window

-- Object ID -> bundled node, for every herb and ore.
local GATHER_IDS = {
    peacebloom = { 1618, 3724, 656160 }, silverleaf = { 1617, 3725, 656161 },
    hyjal_silphium = { 654624 }, tomb_weed = { 694732 }, earthroot = { 1619, 3726 },
    mageroyal = { 1620, 3727 }, briarthorn = { 1621, 3729 }, stranglekelp = { 2045 },
    bruiseweed = { 1622, 3730 }, wild_steelbloom = { 1623 }, grave_moss = { 1628 },
    kingsblood = { 1624 }, nightmare_moss = { 439557 }, liferoot = { 2041 }, fadeleaf = { 2042 },
    goldthorn = { 2046 }, khadgars_whisker = { 2043 }, wintersbite = { 2044 }, firebloom = { 2866 },
    dreamroot = { 439627 }, purple_lotus = { 142140, 180165 }, arthas_tears = { 142141, 176642 },
    sungrass = { 142142, 176636, 180164 }, blindweed = { 142143, 183046 }, ghost_mushroom = { 142144 },
    gromsblood = { 142145, 176637 }, moonroot = { 439810 }, star_lotus = { 439762 },
    golden_sansam = { 176583, 176638, 180167 }, dreamfoil = { 176584, 176639, 180168 },
    mountain_silversage = { 176586, 176640, 180166 }, plaguebloom = { 176587, 176641 },
    icecap = { 176588 }, black_lotus = { 176589 }, demonsage = { 566786 },
    copper_vein = { 1731, 2055, 3763, 103713, 103714, 562111 }, chunk_of_amber = { 656332 },
    large_chunk_of_amber = { 656333 }, tin_vein = { 1732, 3764, 2054, 103711, 103709 },
    incendicite_mineral_vein = { 1610, 1667 }, silver_vein = { 1733, 105569, 73940 },
    lesser_bloodstone_deposit = { 2653 }, iron_deposit = { 1735, 103710, 103712, 73939 },
    cold_iron_deposit = { 439558 }, indurium_mineral_vein = { 19903 },
    gold_vein = { 1734, 150080, 181109, 73941 }, mithril_deposit = { 2040, 150079, 176645, 123310 },
    fools_gold_vein = { 439628 }, truesilver_deposit = { 2047, 150081, 181108, 123309 },
    dark_iron_deposit = { 165658 }, small_thorium_vein = { 324, 150082, 176643, 123848 },
    starsilver_vein = { 439778 }, greater_moonstone_formation = { 439815 },
    rich_thorium_vein = { 175404, 176644, 177388 }, hakkari_thorium_vein = { 180215 },
    heavy_thorium_vein = { 566779 }, small_obsidian_chunk = { 181068 }, large_obsidian_chunk = { 181069 },
}
gatherKeyByID = {}
for key, ids in pairs(GATHER_IDS) do
    for _, id in ipairs(ids) do gatherKeyByID[id] = key end
end
FN.gatherKeyByID = gatherKeyByID

-- The gathering spell (any rank) -> "herb" or "ore", by its name, as ranks differ.
local function GatherKind(spellID)
    if not spellID or IsSecret(spellID) or not (C_Spell and C_Spell.GetSpellName) then return nil end
    local name = C_Spell.GetSpellName(spellID)
    if not name then return nil end
    if name == C_Spell.GetSpellName(2366) then return "herb" end -- Herb Gathering
    if name == C_Spell.GetSpellName(2575) then return "ore" end  -- Mining
    return nil
end

-- A node of `kind` by its shown name, or nil.
local function GatherKeyForName(name, kind)
    if not name then return nil end
    for _, node in ipairs(FN.nodes) do
        if node.kind == kind and FN:NodeMatches(node, name) then return node.key end
    end
    return nil
end

-- The node being gathered from: the soft-interact target's name and object ID, if the game shares them.
local function InteractTarget()
    local name = UnitExists and UnitExists("softinteract") and UnitName("softinteract")
    local guid = UnitGUID and UnitGUID("softinteract")
    local id
    if guid and not IsSecret(guid) then
        local unitType, _, _, _, _, objectID = strsplit("-", guid)
        if unitType == "GameObject" then id = tonumber(objectID) end
    end
    if name and IsSecret(name) then name = nil end
    return name, id
end

-- The game object the loot came out of, or nil.
local function LootObject()
    if not (GetNumLootItems and GetLootSourceInfo) then return nil end
    for slot = 1, GetNumLootItems() do
        local guid = GetLootSourceInfo(slot)
        if guid and not IsSecret(guid) then
            local unitType, _, _, _, _, id = strsplit("-", guid)
            if unitType == "GameObject" then return tonumber(id) end
        end
    end
    return nil
end

local gather -- the gather in progress: { kind, at, x, y, mapID, name, id }

local function StartGather(kind)
    local x, y, mapID = HBD:GetPlayerZonePosition()
    if not (x and y and mapID) then
        Debug("gather not recorded: the game gave no map position here")
        return
    end
    local name, id = InteractTarget()
    if id and gatherKeyByID[id] then FN:RememberNodeName(gatherKeyByID[id], name) end
    if not name and hoveredName and hoveredAt and GetTime() - hoveredAt < 10 then name = hoveredName end
    gather = { kind = kind, at = GetTime(), x = x, y = y, mapID = mapID, name = name, id = id }
    Debug(("%s gather seen%s"):format(kind, name and (": " .. name) or ""))
end

local function FinishGather()
    local g = gather
    gather = nil
    local id = LootObject() or g.id
    local key = (id and gatherKeyByID[id]) or GatherKeyForName(g.name, g.kind)
    if not key then
        if not (id or g.name) then
            Debug("gather not recorded: could not tell which node it was")
            return
        end
        -- A herb or ore the list does not have: a new type, named from the game if possible.
        key = id and ("gather_" .. id) or ("gather_" .. g.name:lower():gsub("[^%a%d]+", "_"))
        if FN.byKey[key] and FN.byKey[key].kind ~= g.kind then return end
    end
    RecordSpot(key, g.name, id, g.kind, g.x, g.y, g.mapID)
end

local gatherEvents = CreateFrame("Frame")
gatherEvents:RegisterEvent("UNIT_SPELLCAST_START")
gatherEvents:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
gatherEvents:RegisterEvent("LOOT_READY")
gatherEvents:SetScript("OnEvent", function(_, event, unit, _, spellID)
    local db = FN.db
    if not db then return end
    -- Herbs and ore each have their own "record" setting.
    local function Records(kind)
        return (kind == "herb" and db.recordHerb) or (kind == "ore" and db.recordOre) or false
    end
    if event == "LOOT_READY" then
        if gather and GetTime() - gather.at < GATHER_WINDOW and Records(gather.kind) then FinishGather() end
        return
    end
    if unit ~= "player" then return end
    local kind = GatherKind(spellID)
    if not kind or not Records(kind) then return end
    -- The cast's start is when the node is still targeted; its success confirms it.
    if event == "UNIT_SPELLCAST_START" or not gather then StartGather(kind) end
end)

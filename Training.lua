local _, FN = ...

-- Training: profession ranks, where to learn them, what they cost, map pins and the
-- chat messages around rank caps. Data is for WoW: Forever (checked in game where
-- noted); anything a trainer window shows is recorded and wins over this table.

local HBD = LibStub("HereBeDragons-2.0")

-- Ranks ---------------------------------------------------------------------------

-- skill = skill needed to learn the rank; cap = the rank's skill cap.
FN.RANKS = {
    { name = "Apprentice", cap = 75,  skill = 0 },
    { name = "Journeyman", cap = 150, skill = 50 },
    { name = "Expert",     cap = 225, skill = 125 },
    { name = "Artisan",    cap = 300, skill = 200 },
}

-- Base cost in copper per rank (before the reputation discount). Herbalism and Mining
-- confirmed for Artisan in game (5g); fishing Expert is the book (1g, confirmed), its
-- Artisan rank is a quest (free).
local COST = {
    herb = { 10, 500, 5000, 50000 },
    ore  = { 10, 500, 5000, 50000 },
    fish = { 100, 500, 10000, 0 },
}

-- Character level needed per rank. Forever removed them for Herbalism and Mining
-- (confirmed: Artisan offered at level 25). Fishing keeps them: Expert book 20
-- (confirmed), Artisan quest 35 (Wowhead), Journeyman 10 (Classic, unconfirmed).
local LEVEL = {
    herb = { 0, 0, 0, 0 },
    ore  = { 0, 0, 0, 0 },
    fish = { 0, 10, 20, 35 },
}

-- Index of the rank whose cap is `max` (0 when nothing is learned).
local function RankIndex(max)
    for i, r in ipairs(FN.RANKS) do
        if max <= r.cap then return max == r.cap and i or i - 1 end
    end
    return #FN.RANKS
end

-- The next rank to learn for `kind`, as a table, or nil when fully trained.
-- A profession the character doesn't have returns Apprentice.
function FN:NextRank(kind)
    local info = FN:GetSkillInfo(kind)
    local i = info and RankIndex(info.max) + 1 or 1
    local r = FN.RANKS[i]
    if not r then return nil end
    local learned = FN.db and FN.db.learned and FN.db.learned[kind] and FN.db.learned[kind][r.name]
    return {
        index = i, name = r.name, cap = r.cap, skill = r.skill,
        level = (learned and learned.level) or LEVEL[kind][i],
        cost = COST[kind][i],
    }
end

-- True when the character could learn its next rank right now (skill and level).
function FN:CanTrain(kind)
    local info = FN:GetSkillInfo(kind)
    if not info then return false end
    local nxt = FN:NextRank(kind)
    if not nxt then return false end
    return info.rank >= nxt.skill and UnitLevel("player") >= nxt.level
end

-- True at a rank cap below 300 (75/150/225), until the next rank is learned.
function FN:IsCapped(kind)
    local info = FN:GetSkillInfo(kind)
    return info ~= nil and info.max < 300 and info.rank >= info.max and info.max > 0
end

-- Trainers -------------------------------------------------------------------------
-- name | zone | town | x | y | faction ("A", "H", "N") | reputation faction ID (or 0) | what they teach
-- teach: "all" (every rank), "app" (Apprentice only), "jour" (up to Journeyman),
--        "book" (fishing Expert book vendor), "quest" (fishing Artisan quest giver).
-- Coordinates from Wowhead's WoW: Forever profession guides (patch 1.60.1).

local REP = { Orgrimmar = 76, ThunderBluff = 81, Undercity = 68, Darkspear = 530,
    Stormwind = 72, Ironforge = 47, Darnassus = 69, BootyBay = 21, Gadgetzan = 369, Cenarion = 609 }

local T = {}
local function Add(kind, list)
    T[kind] = T[kind] or {}
    for _, e in ipairs(list) do
        T[kind][#T[kind] + 1] = { name = e[1], zone = e[2], town = e[3], x = e[4] / 100, y = e[5] / 100,
            faction = e[6], rep = e[7] ~= 0 and e[7] or nil, teach = e[8] }
    end
end

Add("herb", {
    { "Jandi", "Orgrimmar", "The Drag", 55.6, 39.6, "H", REP.Orgrimmar, "all" },
    { "Komin Winterhoof", "Thunder Bluff", "Middle Rise", 49.8, 39.8, "H", REP.ThunderBluff, "all" },
    { "Martha Alliestar", "Undercity", "Apothecarium", 54.8, 50.2, "H", REP.Undercity, "all" },
    { "Mishiki", "Durotar", "Sen'jin Village", 55.4, 75.0, "H", REP.Darkspear, "all" },
    { "Faruza", "Tirisfal Glades", "Brill", 59.8, 52.0, "H", REP.Undercity, "all" },
    { "Aranae Venomblood", "Hillsbrad Foothills", "Tarren Mill", 61.6, 19.6, "H", REP.Undercity, "all" },
    { "Angrun", "Stranglethorn Vale", "Grom'gol", 32.2, 27.6, "H", REP.Darkspear, "all" },
    { "Ruw", "Feralas", "Camp Mojache", 76.0, 43.4, "H", REP.ThunderBluff, "all" },
    { "Zor'la", "Durotar", "Valley of Trials", 42.6, 67.4, "H", REP.Orgrimmar, "app" },
    { "Garan Sunstrider", "Mulgore", "Red Cloud Mesa", 44.2, 77.8, "H", REP.ThunderBluff, "app" },
    { "Florence Nightshade", "Tirisfal Glades", "Deathknell", 32.4, 65.2, "H", REP.Undercity, "app" },
    { "Firodren Mooncaller", "Darnassus", "Temple Gardens", 48.0, 68.0, "A", REP.Darnassus, "all" },
    { "Reyna Stonebranch", "Ironforge", "The Great Forge", 55.6, 58.0, "A", REP.Ironforge, "all" },
    { "Tannysa", "Stormwind City", "Mage Quarter", 44.8, 77.0, "A", REP.Stormwind, "all" },
    { "Shylamiir", "Stormwind City", "The Park", 15.2, 49.8, "A", REP.Stormwind, "all" },
    { "Malorne Bladeleaf", "Teldrassil", "Dolanaar", 57.6, 60.6, "A", REP.Darnassus, "all" },
    { "Herbalist Pomeroy", "Elwynn Forest", "Stormwind Gates", 39.8, 48.4, "A", REP.Stormwind, "all" },
    { "Kali Healtouch", "Loch Modan", "Thelsamar", 36.6, 48.4, "A", REP.Ironforge, "all" },
    { "Alma Jainrose", "Redridge Mountains", "Lakeshire", 21.8, 45.8, "A", REP.Stormwind, "all" },
    { "Cylania Rootstalker", "Ashenvale", "Silverwind Refuge", 50.6, 67.0, "A", REP.Darnassus, "all" },
    { "Telurinon Moonshadow", "Wetlands", "Menethil Harbor", 8.0, 55.8, "A", REP.Stormwind, "all" },
    { "Brant Jasperbloom", "Dustwallow Marsh", "Theramore Isle", 64.0, 47.6, "A", 0, "all" },
    { "Edward Egan", "Alterac Mountains", "Dalaran", 18.4, 63.2, "A", 0, "all" },
    { "Nancy Songflower", "Elwynn Forest", "Northshire", 52.4, 43.8, "A", REP.Stormwind, "app" },
    { "Emrys Flintbeard", "Dun Morogh", "Coldridge Valley", 28.8, 66.6, "A", REP.Ironforge, "app" },
    { "Eleyna Duskbreeze", "Teldrassil", "Shadowglen", 59.8, 41.4, "A", REP.Darnassus, "app" },
    { "Halassa Fernbreeze", "Zephras Isle", "Shen'dar Village", 43.0, 43.6, "N", 0, "all" },
    { "Syriel Nightrain", "Zephras Isle", "Valanaar", 57.8, 75.4, "N", 0, "all" },
    { "Flora Silverwind", "Stranglethorn Vale", "Booty Bay", 27.6, 77.6, "N", REP.BootyBay, "all" },
    { "Malvor", "Moonglade", "Nighthaven", 45.6, 46.8, "N", REP.Cenarion, "all" },
})

Add("ore", {
    { "Makaru", "Orgrimmar", "Valley of Honor", 73.0, 26.4, "H", REP.Orgrimmar, "all" },
    { "Brek Stonehoof", "Thunder Bluff", "Middle Rise", 34.6, 57.6, "H", REP.ThunderBluff, "all" },
    { "Brom Killian", "Undercity", "War Quarter", 56.0, 37.0, "H", REP.Undercity, "all" },
    { "Krunn", "Durotar", "Razor Hill", 51.8, 40.8, "H", REP.Orgrimmar, "all" },
    { "Johan Focht", "Silverpine Forest", "The Sepulcher", 43.4, 40.6, "H", REP.Undercity, "all" },
    { "Norzsh", "Durotar", "Valley of Trials", 40.6, 68.0, "H", REP.Orgrimmar, "app" },
    { "Vartha Rockmane", "Mulgore", "Red Cloud Mesa", 44.2, 78.2, "H", REP.ThunderBluff, "app" },
    { "Walter Mason", "Tirisfal Glades", "Deathknell", 32.2, 65.8, "H", REP.Undercity, "app" },
    { "Geofram Bouldertoe", "Ironforge", "The Great Forge", 50.4, 26.0, "A", REP.Ironforge, "all" },
    { "Gelman Stonehand", "Stormwind City", "Dwarven District", 59.0, 37.6, "A", REP.Stormwind, "all" },
    { "Yarr Hammerstone", "Dun Morogh", "Steelgrill's Depot", 50.0, 50.2, "A", REP.Ironforge, "all" },
    { "Dank Drizzlecut", "Dun Morogh", "Gol'Bolar Quarry", 69.2, 55.4, "A", REP.Ironforge, "all" },
    { "Brock Stoneseeker", "Loch Modan", "Thelsamar", 37.2, 46.8, "A", REP.Ironforge, "all" },
    { "Kurdram Stonehammer", "Darkshore", "Auberdine", 38.2, 41.0, "A", REP.Darnassus, "all" },
    { "Matt Johnson", "Duskwood", "Darkshire", 74.0, 49.6, "A", REP.Stormwind, "all" },
    { "Kelsey Fargo", "Elwynn Forest", "Northshire", 47.2, 32.6, "A", REP.Stormwind, "app" },
    { "Sally Swiftwrench", "Dun Morogh", "Coldridge Valley", 28.8, 67.8, "A", REP.Ironforge, "app" },
    { "Fanorran Stilloak", "Teldrassil", "Shadowglen", 58.2, 41.6, "A", REP.Darnassus, "app" },
    { "Messana Crestwind", "Zephras Isle", "Shen'dar Village", 44.8, 44.4, "N", 0, "all" },
    { "Halavuul Cragwind", "Zephras Isle", "Valanaar", 65.4, 80.4, "N", 0, "all" },
    { "Pikkle", "Tanaris", "Gadgetzan", 51.0, 28.0, "N", REP.Gadgetzan, "all" },
    { "Grungle", "Riverglades", "Powderfuse Port", 77.6, 51.8, "N", 0, "all" },
})

Add("fish", {
    { "Armand Cromwell", "Undercity", "Magic Quarter", 80.8, 31.2, "H", REP.Undercity, "jour" },
    { "Clyde Kellen", "Tirisfal Glades", "Brightwater Lake", 67.2, 51.0, "H", REP.Undercity, "jour" },
    { "Kah Mistrunner", "Thunder Bluff", "Middle Tier", 56.0, 46.8, "H", REP.ThunderBluff, "jour" },
    { "Katoom the Angler", "The Hinterlands", "Revantusk Village", 80.2, 81.4, "H", REP.Darkspear, "jour" },
    { "Kil'Hiwana", "Ashenvale", "Zoram Strand", 10.8, 33.6, "H", REP.Orgrimmar, "jour" },
    { "Lau'Tiki", "Durotar", "Sen'jin Village", 53.2, 81.6, "H", REP.Darkspear, "jour" },
    { "Lui'Mala", "Desolace", "Shadowprey Village", 22.6, 72.6, "H", REP.ThunderBluff, "jour" },
    { "Lumak", "Orgrimmar", "Valley of Honor", 69.8, 29.6, "H", REP.Orgrimmar, "jour" },
    { "Uthan Stillwater", "Mulgore", "Bloodhoof Village", 44.6, 60.6, "H", REP.ThunderBluff, "jour" },
    { "Androl Oakhand", "Teldrassil", "Rut'theran Village", 56.0, 93.6, "A", REP.Darnassus, "jour" },
    { "Arnold Leland", "Stormwind City", "Trade District", 55.0, 69.6, "A", REP.Stormwind, "jour" },
    { "Astaia", "Darnassus", "Temple Gardens", 47.6, 56.6, "A", REP.Darnassus, "jour" },
    { "Brannock", "Feralas", "Feathermoon Stronghold", 32.2, 41.6, "A", REP.Darnassus, "jour" },
    { "Donald Rabonne", "Hillsbrad Foothills", "Southshore", 50.6, 61.0, "A", REP.Stormwind, "jour" },
    { "Grimnur Stonebrand", "Ironforge", "Forlorn Cavern", 48.4, 6.4, "A", REP.Ironforge, "jour" },
    { "Harold Riggs", "Wetlands", "Menethil Harbor", 8.2, 58.6, "A", REP.Stormwind, "jour" },
    { "Lee Brown", "Elwynn Forest", "Goldshire", 47.6, 62.2, "A", REP.Stormwind, "jour" },
    { "Matthew Hooper", "Redridge Mountains", "Lakeshire", 26.8, 50.4, "A", REP.Stormwind, "jour" },
    { "Paxton Ganter", "Dun Morogh", "Brewnall Village", 35.6, 40.4, "A", REP.Ironforge, "jour" },
    { "Warg Deepwater", "Loch Modan", "Thelsamar", 40.6, 39.6, "A", REP.Ironforge, "jour" },
    { "Myizz Luckycatch", "Stranglethorn Vale", "Booty Bay", 27.6, 77.0, "N", REP.BootyBay, "jour" },
    { "Fenn Fairweather", "Zephras Isle", "Shen'dar Village", 45.0, 48.4, "N", 0, "jour" },
    { "Baelann Swiftcurrent", "Zephras Isle", "Valanaar", 63.2, 75.6, "N", 0, "jour" },
    { "Krix", "Riverglades", "Powderfuse Port", 79.2, 54.6, "N", 0, "jour" },
    { "Old Man Heming", "Stranglethorn Vale", "Booty Bay", 27.4, 77.0, "N", REP.BootyBay, "book" },
    { "Nat Pagle", "Dustwallow Marsh", "", 58.6, 60.0, "N", 0, "quest" },
})

-- Whether a trainer entry teaches rank number `i` (1 Apprentice ... 4 Artisan).
local function Teaches(t, kind, i)
    if t.teach == "all" then return true end
    if t.teach == "app" then return i == 1 end
    if t.teach == "jour" then return i <= 2 end
    if t.teach == "book" then return kind == "fish" and i == 3 end
    if t.teach == "quest" then return kind == "fish" and i == 4 end
    return false
end

-- Map IDs, looked up by zone name once (Forever adds zones of its own).
local zoneIDs
local function ZoneMapID(name)
    if not zoneIDs then
        zoneIDs = {}
        if C_Map and C_Map.GetMapInfo then
            for id = 1, 3000 do
                local info = C_Map.GetMapInfo(id)
                if info and info.name and (info.mapType == 3 or info.mapType == 4) and not zoneIDs[info.name] then
                    zoneIDs[info.name] = id
                end
            end
        end
    end
    return zoneIDs[name]
end

-- The continent (or top-level map) a map belongs to: its map ID and name.
local function Continent(mapID)
    local id = mapID
    while id do
        local info = C_Map.GetMapInfo(id)
        if not info then break end
        if info.mapType == 2 then return id, info.name end
        if not info.parentMapID or info.parentMapID == 0 or info.mapType < 2 then break end
        id = info.parentMapID
    end
    -- Not on a continent (Forever's islands sit straight under Azeroth): use the zone itself.
    local own = C_Map.GetMapInfo(mapID)
    return mapID, own and own.name
end

-- Reputation: standing ID (4 Neutral, 5 Friendly, 6 Honored ...) with a faction, or nil.
local function Standing(factionID)
    if not factionID then return nil end
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local data = C_Reputation.GetFactionDataByID(factionID)
        if data and data.reaction then return data.reaction end
    end
    if GetFactionInfoByID then
        local _, _, standing = GetFactionInfoByID(factionID)
        return standing
    end
    return nil
end

-- Classic rule (confirmed in Forever): a flat 10% off at Honored and above, nothing below.
local function Discounted(cost, factionID)
    local s = Standing(factionID)
    if cost > 0 and s and s >= 6 then return math.floor(cost * 0.9 + 0.5), true end
    return cost, false
end

-- How a trainer's name is colored, like the game colors NPC names: own faction friendly;
-- neutral towns by standing (Neutral yellow, Friendly+ green, hostile red).
local function Reaction(t)
    if t.faction ~= "N" then return "friendly" end
    local s = Standing(t.rep)
    if not s then return "neutral" end
    if s >= 5 then return "friendly" end
    if s <= 3 then return "hostile" end
    return "neutral"
end

-- Every trainer the character can use for `kind`'s next rank, with distances and prices.
-- Sorted by distance (same continent first, nearest first), then continent, then name.
-- Each entry: name, zone, town, mapID, x, y, cost, discounted, reaction, yards (or nil),
-- continent (name, for ones without a distance), teach, entry (the data row).
function FN:TrainersFor(kind)
    local nxt = FN:NextRank(kind)
    if not nxt then return {}, nil end
    local mine = UnitFactionGroup("player") == "Alliance" and "A" or "H"
    local px, py, pInstance = HBD:GetPlayerWorldPosition()
    local recorded = FN.db and FN.db.trainerCosts or {}
    local out = {}
    for _, t in ipairs(T[kind] or {}) do
        if (t.faction == mine or t.faction == "N") and Teaches(t, kind, nxt.index) then
            local mapID = ZoneMapID(t.zone)
            local base = recorded[t.name] and recorded[t.name][nxt.name] or nxt.cost
            local cost, disc = Discounted(base, t.rep)
            if recorded[t.name] and recorded[t.name][nxt.name] then cost, disc = base, false end -- already what that trainer charges you
            local yards, contName, wx, wy, inst
            if mapID then
                wx, wy, inst = HBD:GetWorldCoordinatesFromZone(t.x, t.y, mapID)
                if wx and px and inst == pInstance then
                    yards = math.floor(HBD:GetWorldDistance(inst, px, py, wx, wy) + 0.5)
                end
                local _, cname = Continent(mapID)
                contName = cname
            end
            out[#out + 1] = { name = t.name, zone = t.zone, town = t.town, mapID = mapID, x = t.x, y = t.y,
                wx = wx, wy = wy, inst = inst,
                cost = cost, discounted = disc, reaction = Reaction(t), yards = yards,
                continent = contName or t.zone, teach = t.teach, entry = t }
        end
    end
    table.sort(out, function(a, b)
        if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
        if a.yards and b.yards and a.yards ~= b.yards then return a.yards < b.yards end
        if a.continent ~= b.continent then return a.continent < b.continent end
        return a.name < b.name
    end)
    return out, nxt
end

-- Yards from the player to a trainer entry from FN:TrainersFor (nil on another continent).
function FN:TrainerYards(t)
    if not t.wx then return nil end
    local px, py, pInstance = HBD:GetPlayerWorldPosition()
    if not px or pInstance ~= t.inst then return nil end
    return math.floor(HBD:GetWorldDistance(t.inst, px, py, t.wx, t.wy) + 0.5)
end

-- Recording what trainers actually say -------------------------------------------------
-- When a trainer window is open, its services list real costs (with your discount) and
-- level requirements. Those replace the built-in guesses from then on.
local SERVICE = {}
for _, r in ipairs(FN.RANKS) do
    SERVICE[r.name .. " Herbalism"] = { "herb", r.name }
    SERVICE[r.name .. " Mining"] = { "ore", r.name }
    SERVICE[r.name .. " Fishing"] = { "fish", r.name }
end

local function RecordTrainer()
    if not (GetNumTrainerServices and GetTrainerServiceInfo and FN.db) then return end
    local npc = UnitName("npc")
    for i = 1, GetNumTrainerServices() do
        local name = GetTrainerServiceInfo(i)
        local svc = name and SERVICE[name]
        if svc then
            local kind, rank = svc[1], svc[2]
            FN.db.learned = FN.db.learned or {}
            FN.db.learned[kind] = FN.db.learned[kind] or {}
            local level = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i)
            if level then FN.db.learned[kind][rank] = { level = level } end
            if npc and GetTrainerServiceCost then
                FN.db.trainerCosts = FN.db.trainerCosts or {}
                FN.db.trainerCosts[npc] = FN.db.trainerCosts[npc] or {}
                FN.db.trainerCosts[npc][rank] = GetTrainerServiceCost(i)
            end
        end
    end
end

-- Map pins -----------------------------------------------------------------------------
-- One game map pin at a time. The addon remembers where it put it (per character) and
-- only ever treats the pin as its own while it is still exactly there, so a pin the
-- player placed is never touched.

local function CharDB()
    ForeverNodesCharDB = ForeverNodesCharDB or {}
    return ForeverNodesCharDB
end

local function PinIsOurs()
    local rec = CharDB().pin
    if not (rec and C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then return false end
    local p = C_Map.GetUserWaypoint()
    if not (p and p.uiMapID == rec.mapID and p.position) then return false end
    -- On this client the position can come back as a plain {x, y} table, without GetXY.
    local pos = p.position
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if not (x and y) then return false end
    return math.abs(x - rec.x) < 0.0005 and math.abs(y - rec.y) < 0.0005
end

-- The trainer name our pin is on, or nil.
function FN:PinnedTrainer()
    if PinIsOurs() then return CharDB().pin.name end
    return nil
end

function FN:PinTrainer(t, kind)
    if not (t.mapID and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then return false end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(t.mapID) then return false end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(t.mapID, t.x, t.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    local nxt = FN:NextRank(kind)
    CharDB().pin = { mapID = t.mapID, x = t.x, y = t.y, name = t.name, kind = kind, rank = nxt and nxt.name }
    return true
end

function FN:ClearOurPin()
    if PinIsOurs() and C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
    CharDB().pin = nil
end

-- Pin or unpin: clicking the pinned trainer again removes it.
function FN:TogglePin(t, kind)
    if FN:PinnedTrainer() == t.name then
        FN:ClearOurPin()
    elseif FN:PinTrainer(t, kind) then
        -- Show where it went: the open world map turns to the trainer's zone.
        local map = WorldMapFrame
        if map and map:IsShown() and map.SetMapID and map:GetMapID() ~= t.mapID then
            map:SetMapID(t.mapID)
        end
    end
    if FN.RefreshOptions then FN:RefreshOptions() end
end

-- Forget the record when the pin has moved or gone; clear it once its rank is trained.
local function CheckPin()
    local rec = CharDB().pin
    if not rec then return end
    if not PinIsOurs() then CharDB().pin = nil return end
    local nxt = FN:NextRank(rec.kind)
    if not nxt or nxt.name ~= rec.rank then FN:ClearOurPin() end
end

-- Chat messages --------------------------------------------------------------------------
-- Each one is said once per character: the "told" table remembers what was sent.

local TAG = "|cffffd100[Forever Nodes]|r "

local function Hex(kind)
    local c = FN.db and FN.db.colors and FN.db.colors[kind] or { 1, 1, 1 }
    local function B(v) return math.floor((v or 1) * 255 + 0.5) end
    return ("%02x%02x%02x"):format(B(c[1]), B(c[2]), B(c[3]))
end
local function Colored(kind, text) return "|cff" .. Hex(kind) .. text .. "|r" end

local function Say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(TAG .. text, 1, 1, 1) end
end

local function Told(key)
    local db = CharDB()
    db.told = db.told or {}
    if db.told[key] then return true end
    db.told[key] = true
    return false
end

-- What to do next, per profession and rank (fishing's Expert is a book, Artisan a quest).
local function NextStep(kind, nxt)
    if kind == "fish" and nxt.name == "Expert" then return "to see where to get the Expert Fishing book." end
    if kind == "fish" and nxt.name == "Artisan" then return "to see where to start Nat Pagle's Artisan quest." end
    return "to see where you can train " .. nxt.name .. "."
end

local function Congrats(kind, info)
    local nxt = FN:NextRank(kind)
    if not nxt then return end
    if Told("cap:" .. kind .. ":" .. info.max) then return end
    local cur = FN.RANKS[nxt.index - 1]
    local msg = ("Gz on %s! You've hit the %s cap. Open the Forever Nodes panel %s")
        :format(Colored(kind, info.max .. " " .. FN.kindNames[kind]), cur and cur.name or "rank", NextStep(kind, nxt))
    if UnitLevel("player") < nxt.level then
        msg = msg .. (" You'll need level %d to learn it."):format(nxt.level)
    end
    Say(msg)
end

local function Mastered(kind)
    if Told("max:" .. kind) then return end
    local msg = ("Gz on %s! You've mastered it, nothing left to train."):format(Colored(kind, "300 " .. FN.kindNames[kind]))
    if FN.db and FN.db.muteAtMax then msg = msg .. " Difficulty colors in your list are now muted." end
    Say(msg)
end

-- Login: one reminder for every capped profession the character can train but hasn't.
local function LoginReminder()
    local due = {}
    for _, kind in ipairs(FN.kinds) do
        local info = FN:GetSkillInfo(kind)
        if info and FN:IsCapped(kind) and FN:CanTrain(kind) then
            local nxt = FN:NextRank(kind)
            if not Told("remind:" .. kind .. ":" .. info.max) then due[#due + 1] = { kind = kind, rank = nxt.name } end
        end
    end
    if #due == 0 then return end
    local sameRank = true
    for i = 2, #due do if due[i].rank ~= due[1].rank then sameRank = false end end
    local names = {}
    for i, d in ipairs(due) do
        names[i] = Colored(d.kind, FN.kindNames[d.kind]) .. (sameRank and "" or (" (" .. d.rank .. ")"))
    end
    local list = #names == 1 and names[1] or (table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names])
    local tail = sameRank and (" (" .. due[1].rank .. ")") or ""
    Say(("Don't forget to train your next %s rank%s%s! See the Forever Nodes panel for trainers and cost.")
        :format(list, #names > 1 and "s" or "", tail))
end

-- Level-up: a capped profession whose next rank just became learnable by level (fishing).
local function LevelReminder(newLevel)
    for _, kind in ipairs(FN.kinds) do
        local info = FN:GetSkillInfo(kind)
        local nxt = FN:NextRank(kind)
        if info and nxt and FN:IsCapped(kind) and nxt.level > 0 and newLevel == nxt.level
            and info.rank >= nxt.skill and not Told("level:" .. kind .. ":" .. nxt.level) then
            if kind == "fish" and nxt.name == "Artisan" then
                Say(("You're now level %d: you can start Nat Pagle's Artisan %s quest! See the Forever Nodes panel for where to find him.")
                    :format(newLevel, Colored(kind, "Fishing")))
            elseif kind == "fish" and nxt.name == "Expert" then
                Say(("You're now level %d: you can learn Expert %s! See the Forever Nodes panel for where to get the book.")
                    :format(newLevel, Colored(kind, "Fishing")))
            else
                Say(("You're now level %d: you can train %s %s! See the Forever Nodes panel for trainers and cost.")
                    :format(newLevel, nxt.name, Colored(kind, FN.kindNames[kind])))
            end
        end
    end
end

-- Watching skills ------------------------------------------------------------------------

local last = {} -- [kind] = { rank, max } as of the previous check
local function Snapshot()
    for _, kind in ipairs(FN.kinds) do
        local info = FN:GetSkillInfo(kind)
        last[kind] = info and { rank = info.rank, max = info.max } or nil
    end
end

local function SkillsChanged()
    for _, kind in ipairs(FN.kinds) do
        local info = FN:GetSkillInfo(kind)
        local was = last[kind]
        if info and was then
            if info.rank > was.rank then
                if info.rank >= 300 and was.rank < 300 then
                    Mastered(kind)
                elseif info.rank >= info.max and info.max < 300 then
                    Congrats(kind, info)
                end
            end
            if info.max > was.max then FN:FireTrained(kind) end
        end
    end
    Snapshot()
    CheckPin()
    if FN.RefreshOptions then FN:RefreshOptions() end
end

-- Hook for the panel: called when a rank was trained (the skill bar and list redraw).
function FN:FireTrained(kind)
    if FN.OnRankTrained then FN:OnRankTrained(kind) end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("SKILL_LINES_CHANGED")
watcher:RegisterEvent("PLAYER_LEVEL_UP")
watcher:RegisterEvent("TRAINER_SHOW")
watcher:RegisterEvent("TRAINER_UPDATE")
pcall(watcher.RegisterEvent, watcher, "USER_WAYPOINT_UPDATED")
watcher:SetScript("OnEvent", function(_, event, arg1)
    if not FN.db then return end
    if event == "PLAYER_LOGIN" then
        Snapshot()
        CheckPin()
        C_Timer.After(6, LoginReminder) -- after the login chat spam settles
    elseif event == "SKILL_LINES_CHANGED" then
        SkillsChanged()
    elseif event == "PLAYER_LEVEL_UP" then
        C_Timer.After(1, function() LevelReminder(arg1) end)
    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        RecordTrainer()
    elseif event == "USER_WAYPOINT_UPDATED" then
        CheckPin()
        if FN.RefreshOptions then FN:RefreshOptions() end
    end
end)

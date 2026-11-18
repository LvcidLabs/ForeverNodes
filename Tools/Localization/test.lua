-- lua Tools/Localization/test.lua (Lua 5.1+, from the repository root)
unpack = unpack or table.unpack
local FN = {db = {uiLocale = "auto"}}
local client = "ruRU"
GetLocale = function() return client end
local secret = {}
issecretvalue = function(value) return value == secret end
local function load(name) assert(loadfile(name))("ForeverNodes", FN) end
load("Localization.lua"); load("Locales/ruRU.lua"); load("Data.lua")
local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " != " .. tostring(expected))
end
local peace = FN.nodes[1]
equal(FN:Text("Clear Selection"), "Снять выбор")
equal(FN:Text("Peacebloom"), "Мироцвет")
equal(FN:Text("Herbalism"), "Травничество")
FN:SetUILocale("enUS")
equal(FN:Text("Clear Selection"), "Clear Selection")
equal(FN:Text("Peacebloom"), "Мироцвет")
equal(FN:NodeName(peace), "Мироцвет")
client = "enUS"
FN:SetUILocale("ruRU")
equal(FN:Text("Clear Selection"), "Снять выбор")
equal(FN:Text("Peacebloom"), "Peacebloom")
equal(FN:Text("Herbalism"), "Травничество")
FN:SetUILocale("auto")
equal(FN:Text("Clear Selection"), "Clear Selection")
equal(FN:Text("Peacebloom"), "Peacebloom")
client = "ruRU"
equal(FN:Text("round"), "круг")
equal(FN:Text(123), 123)
equal(FN:Text(secret), secret)
equal(FN:Text("An unknown future label"), "An unknown future label")
equal(FN:Text("|cffffd100Peacebloom|r"), "|cffffd100Мироцвет|r")
equal(FN:Text("|A:Example_Icon:16:16|a Open"), "|A:Example_Icon:16:16|a Открыть")
equal(FN:Text("|TInterface\\Icons\\Mining:16|t Mining"), "|TInterface\\Icons\\Mining:16|t Горное дело")
local link = "|Hitem:2447::::::::|h[Peacebloom]|h"
equal(FN:Text(link), link)
equal(FN:Text("Record new |cff00ff00herb|r locations"), "Записывать новые точки: |cff00ff00травы|r")
equal(FN:Text("recorded a new spot for Peacebloom."), "Записана новая точка: Мироцвет.")
equal(peace.name, "Peacebloom")
assert(FN:NodeMatches(peace, "Мироцвет"))
local function widget(kind, parent)
    return {GetObjectType = function() return kind end, GetParent = function() return parent end,
        SetText = function(self, text) self.text = text end}
end
local label, edit = widget("FontString"), widget("EditBox")
FN:SetText(label, "Select All"); FN:SetText(edit, "Select All")
equal(label.text, "Выбрать всё"); equal(edit.text, "Select All")
FN:SetUILocale("enUS")
equal(label.text, "Select All"); equal(edit.text, "Select All")
FN:SetUILocale("ruRU"); equal(label.text, "Выбрать всё")
local tooltip = widget("GameTooltip")
local tipLine = widget("FontString", tooltip)
FN:SetText(tipLine, "Select All"); tipLine.text = "Another addon's tooltip"
FN:SetUILocale("enUS"); equal(tipLine.text, "Another addon's tooltip")
print("Language matrix, live switching, markup, secrets and saved-key checks passed")

-- Exercise the real recording module with localized names and no object GUID:
-- it must append to existing canonical points, never create a Russian duplicate.
local frames, callbacks = {}, {}
local now = 100
GetTime = function() return now end
GetPlayerFacing = function() return 0 end
UnitExists = function() return true end
UnitName = function() return "Мироцвет" end
UnitGUID = function() return nil end
GetNumLootItems = function() return 0 end
C_Spell = {GetSpellName = function(id) return id == 2366 and "Сбор трав" or "Рыбная ловля" end}
LibStub = function() return {GetPlayerZonePosition = function() return 0.1, 0.2, 999 end,
    GetZoneSize = function() return 1000, 1000 end} end
CreateFrame = function()
    local f = {RegisterEvent = function() end, SetScript = function(self, key, fn) self[key] = fn end}
    frames[#frames + 1] = f
    return f
end
Enum = {TooltipDataType = {Object = 1}}
TooltipDataProcessor = {AddTooltipPostCall = function(_, fn) callbacks[#callbacks + 1] = fn end}
GameTooltip = {IsShown = function() return false end, HookScript = function() end}
FN.db = {recordHerb = true, recordOre = true, record = true, uiLocale = "enUS"}
FN.MEDIA, FN.byKey = "", {}
for _, node in ipairs(FN.nodes) do FN.byKey[node.key] = node end
FN.PointsChanged = function() end
load("Record.lua")
FN:LoadRecorded()
local count = #FN.nodes
frames[2].OnEvent(frames[2], "UNIT_SPELLCAST_START", "player", nil, 2366)
frames[2].OnEvent(frames[2], "LOOT_READY")
equal(#FN.nodes, count)
equal(#FN.db.recordedPoints.peacebloom[999], 2)
equal(next(FN.db.recordedNodes), nil)
now = 105
callbacks[1](nil, {lines = {{leftText = "Обломки в воде"}}})
frames[1].OnEvent(frames[1], "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 7620)
frames[1].OnEvent(frames[1], "LOOT_READY")
equal(#FN.nodes, count)
equal(#FN.db.recordedPoints.floating_wreckage[999], 2)
equal(next(FN.db.recordedNodes), nil)
print("Real recording module: Russian herb/pool fallback preserves existing node keys")
FN:RememberNodeName("demonsage", "Название из клиента")
equal(FN:NodeName(FN.byKey.demonsage), "Название из клиента")
equal(FN:Text("Demonsage"), "Название из клиента")
equal(FN.db.localizedNodeNames.ruRU.Demonsage, "Название из клиента")
client = "enUS"
equal(FN:NodeName(FN.byKey.demonsage), "Demonsage")
client = "ruRU"

-- Run the real options module's segmented control and tooltip formatter.
-- debug is used only by this standalone test, never by the installed addon.
local widgets = {}
local methods = {}
local make
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:GetObjectType() return self.kind end
function methods:GetParent() return self.parent end
function methods:GetStringWidth() return #(self.text or "") * 5 end
function methods:SetWidth(value) self.width = value end
function methods:CreateFontString() return make("FontString", self) end
function methods:CreateTexture() return make("Texture", self) end
function methods:GetFont() return "font", 12, "" end
function methods:GetFontObject() return "font" end
function methods:GetNumPoints() return 0 end
local meta = {__index = function(_, key)
    if methods[key] then return methods[key] end
    if key:match("^Set") or key:match("^Hook") or key:match("^Clear")
        or key == "Hide" or key == "Show" then return function() end end
end}
make = function(kind, parent)
    local object = setmetatable({kind = kind, parent = parent}, meta)
    widgets[#widgets + 1] = object
    return object
end
CreateFrame = function(kind, _, parent) return make(kind, parent) end
UIParent = make("Frame")
GameTooltip, GameTooltipTextLeft1, GameTooltipTextRight1 = make("GameTooltip"), make("FontString"), make("FontString")
hooksecurefunc = function() end
load("Options.lua")
local visited = {}
local function find(fn, wanted)
    if visited[fn] then return end
    visited[fn] = true
    local i = 1
    while true do
        local name, value = debug.getupvalue(fn, i)
        if not name then return end
        if name == wanted then return value end
        if type(value) == "function" then
            local found = find(value, wanted)
            if found then return found end
        end
        i = i + 1
    end
end
local multi = assert(find(FN.ToggleOptions, "MultiToggle"), "real MultiToggle must be reachable")
FN:SetUILocale("enUS")
local toggle = multi(UIParent, {"World map", "Minimap", "Overworld"}, function() end)
toggle:SetPick(2)
local englishWidth = toggle.width
FN.RefreshOptions = nil -- layout parent is not instantiated in this focused test
FN:SetUILocale("ruRU")
assert(toggle.width > englishWidth, "translated captions must resize control hit regions")
equal(toggle.localePick, 2)
FN:SetUILocale("enUS"); equal(toggle.width, englishWidth)
load("Tooltips.lua")
local cfg = {style = "square", place = "before", color = "none"}
equal(FN:FormatTipLine(peace, nil, cfg, 1, 1, 1), "[1] Мироцвет")
equal(FN:FormatSkillText(cfg, 150, FN:ClientName("Herbalism")), "[150] Травничество")
equal(peace.name, "Peacebloom")
print("Real options control resizes on language change; tooltip names use client locale")

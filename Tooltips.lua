local _, FN = ...

-- Tooltips: the skill a herb or vein needs, in its difficulty color.
--   World map: hovering our icons shows one line per node type under the cursor.
--   Overworld: the game's own tooltip for a herb or vein in the world gets the level, on its
--              name line or on its skill line ("150 Herbalism").
--   Minimap:   the game's own tooltip for a yellow tracking dot gets the level after the name,
--              or on a skill line of our own under it.
-- Nothing else about the game's tooltips is changed.
-- Each follows its own settings in Settings > Tooltips (see FN:TipCfg).
-- Fishing pools have no skill requirement and get nothing.

local byName = {}
local function Index()
    for _, node in ipairs(FN.nodes) do
        if node.kind ~= "fish" and node.skill and node.skill > 0 then byName[node.name] = node end
    end
end

local function Hex(r, g, b)
    return ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- Settings, one set per tooltip ("world", "minimap", "overworld"):
--   on      shown at all
--   attach  "name" (on the name line) or "skill" (on the skill line: "150 Herbalism"); not world
--   place   "before" or "after" what it's attached to
--   style   "none" (150), "round" ((150)), "square" ([150]) or "separator" (150 | Liferoot)
--   color   what takes the difficulty color: "level", "brackets" (level and its brackets or
--           separator), "name", "line" or "none"
--   size    (world only) the text size of every line
local TIP_DEFAULTS = {
    world = { on = false, attach = "name", place = "before", style = "square", color = "brackets", size = 11 },
    minimap = { on = true, attach = "name", place = "after", style = "none", color = "level" },
    overworld = { on = true, attach = "skill", place = "before", style = "square", color = "brackets" },
}
function FN:TipCfg(target)
    local db = FN.db
    if type(db.tips) ~= "table" then
        -- From the single shared style of 1.2.0 / 1.2.1.
        db.tips = {}
        local style = (db.tipBrackets == "square" or db.tipBrackets == "round") and db.tipBrackets or "none"
        local place = db.tipPosition == "after" and "after" or "before"
        local color = db.tipColor or "level"
        db.tips.world = { on = db.tipWorldMap ~= false, place = place, style = style, color = color }
        db.tips.overworld = { on = db.tipOverworld ~= false, attach = db.tipOverworldLine == "skill" and "skill" or "name",
            place = place, style = style, color = color }
        db.tipWorldMap, db.tipOverworld, db.tipOverworldLine, db.tipMinimap = nil, nil, nil, nil
        db.tipBrackets, db.tipPosition, db.tipColor = nil, nil, nil
    end
    local t = db.tips[target]
    if type(t) ~= "table" then t = {}; db.tips[target] = t end
    for k, v in pairs(TIP_DEFAULTS[target] or TIP_DEFAULTS.overworld) do
        if t[k] == nil then t[k] = v end
    end
    return t
end

-- The level's own pieces in a style: what goes before it, after it, and the separator.
function FN:TipPieces(cfg)
    if cfg.style == "square" then return "[", "]", nil end
    if cfg.style == "round" then return "(", ")", nil end
    if cfg.style == "separator" then return "", "", "|" end
    return "", "", nil
end

-- "150 Liferoot" (or "Liferoot | 150", ...) in a tooltip's style. `name` is the text to keep
-- (it may carry its own color codes, kept unless the style colors the name). The difficulty
-- color comes from the character's skill, or is given (`r, g, b`, for previews).
function FN:FormatTipLine(node, name, cfg, r, g, b)
    cfg = cfg or FN:TipCfg("overworld")
    if not r then
        local info = FN:GetSkillInfo(node.kind)
        r, g, b = FN:DifficultyColor(info and info.effective, node.skill)
    end
    local c = "|cff" .. Hex(r, g, b)
    local open, close, sep = FN:TipPieces(cfg)
    local mode = cfg.color
    local level = tostring(node.skill)
    local text = name or node.name
    if mode == "line" then
        local num = open .. level .. close
        local mid = sep and (" " .. sep .. " ") or " "
        return c .. (cfg.place == "after" and node.name .. mid .. num
            or num .. mid .. node.name) .. "|r"
    end
    local num
    if mode == "level" then num = open .. c .. level .. "|r" .. close
    elseif mode == "brackets" then num = c .. open .. level .. close .. "|r"
    else num = open .. level .. close end
    if mode == "name" then text = c .. node.name .. "|r" end
    local mid = " "
    if sep then mid = " " .. (mode == "brackets" and (c .. sep .. "|r") or sep) .. " " end
    return cfg.place == "after" and (text .. mid .. num) or (num .. mid .. text)
end

-- The level and a profession name, plain: "150 Herbalism", "Herbalism | 150", "[150] Herbalism".
function FN:FormatSkillText(cfg, level, profession)
    local open, close, sep = FN:TipPieces(cfg)
    local num = open .. level .. close
    local mid = sep and (" " .. sep .. " ") or " "
    return cfg.place == "after" and (profession .. mid .. num) or (num .. mid .. profession)
end

-- World map ---------------------------------------------------------------------------------

local resized -- the tooltip lines given a new size, with the fonts they had: { [line] = { font, size, flags } }

function FN:ShowWorldTip(owner)
    local cfg = FN:TipCfg("world")
    if not cfg.on then return end
    if not next(byName) then Index() end
    local seen, lines = {}, {}
    for _, pin in ipairs(FN.mapPins or {}) do
        local node = pin.node
        if node and pin:IsShown() and pin:IsMouseOver() and not seen[node.key] then
            seen[node.key] = true
            lines[#lines + 1] = node
        end
    end
    if #lines == 0 and owner.node then lines[1] = owner.node end
    table.sort(lines, function(a, b)
        if (a.skill or 0) ~= (b.skill or 0) then return (a.skill or 0) < (b.skill or 0) end
        return a.name < b.name
    end)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for _, node in ipairs(lines) do
        if node.kind == "fish" or not node.skill or node.skill <= 0 then
            GameTooltip:AddLine(node.name, 1, 1, 1)
        else
            GameTooltip:AddLine(FN:FormatTipLine(node, nil, cfg), 1, 1, 1)
        end
    end
    GameTooltip:Show()
    -- Every line the same size (the game draws the first line larger, as a title). Done once
    -- the tooltip is up: UI skins (EllesmereUI) set their own fonts as it opens. Their font face
    -- is kept; only the size changes. The game's tooltip is shared, so the lines get their own
    -- fonts back once it moves on.
    local first = _G.GameTooltipTextLeft1
    local path, _, flags = first and first:GetFont()
    if not path then path, _, flags = GameTooltipText:GetFont() end
    for i = 1, #lines do
        local fs = _G["GameTooltipTextLeft" .. i]
        if fs then
            if not resized[i] then resized[i] = { fs:GetFont() } end
            fs:SetFont(path, cfg.size or 11, flags)
        end
    end
    GameTooltip:Show() -- already up: only re-fits its size to the new text
end

-- Gives the tooltip's lines back the fonts they had before a world map tooltip resized them.
resized = {}
local function RestoreFonts()
    for i, f in pairs(resized) do
        local fs = _G["GameTooltipTextLeft" .. i]
        if fs and f[1] then fs:SetFont(f[1], f[2], f[3]) end
        resized[i] = nil
    end
end
GameTooltip:HookScript("OnHide", RestoreFonts)
hooksecurefunc(GameTooltip, "SetOwner", RestoreFonts)

-- Overworld ------------------------------------------------------------------------------------
-- Runs after the game and other addons have built the tooltip. Only lines whose text is exactly
-- a known herb or vein name (or, for the skill line, exactly the profession's name) are touched,
-- and only by adding the level; a line already done is left alone, so refreshing tooltips never
-- stack levels.

local busy = false
local function Strip(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- A line's text, or nil when it is missing, empty or protected ("secret": an addon may not
-- read or compare it).
local function LineText(i)
    local fs = _G["GameTooltipTextLeft" .. i]
    local text = fs and fs:GetText()
    if issecretvalue and issecretvalue(text) then return nil end
    if type(text) ~= "string" or text == "" then return nil end
    return text, fs
end

-- "150 Herbalism": the level on the skill line, in that line's own color and size.
local function OnSkillLine(tip, node, from, cfg)
    local want = FN.kindNames[node.kind]
    for i = from, tip:NumLines() do
        local text, fs = LineText(i)
        if text and text == fs.fnDone then
            if Strip(text):find(want, 1, true) then return true end -- already done
        elseif text and Strip(text) == want then
            -- A line colored by a code (not by the line's own color) keeps that code for the level.
            local code = text:match("^|c%x%x%x%x%x%x%x%x")
            local done = FN:FormatSkillText(cfg, node.skill, Strip(text))
            if code then done = code .. done .. "|r" end
            fs:SetText(done)
            fs.fnDone = done
            return true
        end
    end
    return false
end

local function Process(tip)
    if busy or not FN.db then return end
    local cfg = FN:TipCfg("overworld")
    if not cfg.on then return end
    if tip ~= GameTooltip then return end
    if not next(byName) then Index() end
    local owner = tip:GetOwner()
    if owner and owner.node then return end -- our own world map tooltip
    local skillLine = cfg.attach == "skill"
    local changed = false
    for i = 1, tip:NumLines() do
        local text, fs = LineText(i)
        -- Skip a line this code already wrote (the same tooltip can be processed twice).
        if text and text ~= fs.fnDone then
            -- Several names can come one per line in one string.
            local out, any, single, parts = {}, false, nil, 0
            for part in (text .. "\n"):gmatch("(.-)\n") do
                parts = parts + 1
                local node = byName[Strip(part)]
                if node then single = node end
                out[#out + 1] = node and FN:FormatTipLine(node, part, cfg) or part
                any = any or node ~= nil
            end
            -- One name with the skill line below it: the level goes there instead.
            if any and skillLine and parts == 1 and OnSkillLine(tip, single, i + 1, cfg) then
                changed = true
            elseif any then
                local done = table.concat(out, "\n")
                fs:SetText(done)
                fs.fnDone = done
                changed = true
            end
        end
    end
    if changed then
        -- Let the tooltip resize itself the normal way to fit the longer line.
        busy = true
        tip:Show()
        busy = false
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes or Enum.TooltipDataType.Object, Process)
end
GameTooltip:HookScript("OnShow", Process)

-- Minimap ----------------------------------------------------------------------------------------
-- The game rebuilds its minimap tooltip every frame, and its text is protected: it can't be read,
-- and color codes added to it show as plain text. Its width can be read, though: the herb or vein
-- is the one, among the types with a spawn point near the cursor (FN:MinimapNodesNearCursor),
-- whose name makes the tooltip exactly as wide as it is. The level is written after every rebuild:
--   - colored level: drawn in the tooltip's right-hand column, moved up against the name, in the
--     name's font; the column gap the tooltip leaves is cropped off its right padding.
--   - otherwise: added to the name as plain text, and the whole line recolored if asked.
-- A tooltip listing more than one thing (a herb beside an NPC, or two dots together) is taller
-- than one line: then nothing is added. Every other tooltip gets the right-hand column and the
-- padding back as they were.

local MINIMAP_TYPE = Enum and Enum.TooltipDataType and Enum.TooltipDataType.MinimapMouseover or 21
-- How near the cursor a spawn point must be to be a candidate (minimap pixels; the game shows
-- its tooltip a fair way around a dot), and how closely a width must fit (px).
local MATCH_PX, FIT_PX = 30, 0.75

-- Gap after the name and the right-padding crop, tuned by eye; EllesmereUI's tooltip font
-- leaves a little room of its own after the text.
local function Spacing()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded and loaded("EllesmereUI") then return 1.54, 39.15 end
    return 2.54, 37.15
end

local R = GameTooltipTextRight1
local L = GameTooltipTextLeft1
local saved   -- true while the right-hand column and padding are changed
local oneLine -- the shortest minimap tooltip seen: the height of one line

-- Anything read while the minimap tooltip is up comes back protected, so the right-hand
-- column's own place and font are taken once, now, while nothing is hidden yet.
local function Clean(...)
    if not issecretvalue then return true end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end
local home = { points = {}, fontObject = R:GetFontObject() }
for i = 1, R:GetNumPoints() do
    local point = { R:GetPoint(i) }
    if Clean(unpack(point, 1, 5)) then home.points[#home.points + 1] = point end
end
-- (The game's own template anchor, should none be readable.)
if #home.points == 0 then home.points[1] = { "RIGHT", L, "LEFT", 40, 0 } end
home.font, home.size, home.flags = R:GetFont()
home.padding = { 0, 0, 0, 0 }
if GameTooltip.GetPadding then
    local r, b, l, t = GameTooltip:GetPadding()
    if Clean(r, b, l, t) then home.padding = { r or 0, b or 0, l or 0, t or 0 } end
end

local function Restore(tip)
    if not saved then return end
    local padding = saved
    saved = nil
    R:SetText("")
    R:Hide()
    R:ClearAllPoints()
    for _, p in ipairs(home.points) do R:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    if home.fontObject then R:SetFontObject(home.fontObject)
    elseif home.font then R:SetFont(home.font, home.size, home.flags) end
    if tip.SetPadding then tip:SetPadding(unpack(padding)) end
end

-- Remembers the padding to put back (other addons may have set their own).
local function Save(tip)
    if saved then return end
    local padding = home.padding
    if tip.GetPadding then
        local r, b, l, t = tip:GetPadding()
        if Clean(r, b, l, t) then padding = { r or 0, b or 0, l or 0, t or 0 } end
    end
    saved = padding
end

local function IsMinimapTip(tip)
    if not tip.GetTooltipData then return false end
    local ok, data = pcall(tip.GetTooltipData, tip)
    local kind = ok and type(data) == "table" and data.type
    if issecretvalue and issecretvalue(kind) then return false end
    return kind == MINIMAP_TYPE
end

-- The tooltip is always as wide as its name plus a fixed amount (padding, and the up/down arrow
-- when there is one): one amount with the arrow, one without. Those amounts are learned from
-- hovers with only one candidate nearby (kept per font, as { [amount] = times seen }), and then
-- tell which of several candidates' names fits.
local measure
local function NameWidth(name, font, size, flags)
    if not measure then
        measure = UIParent:CreateFontString(nil, "BACKGROUND")
        measure:SetAlpha(0)
        measure:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -100)
    end
    measure:SetFont(font, size, flags)
    measure:SetText(name)
    return measure:GetStringWidth()
end

local lastLearned, lastDebug
local function Learned(fontKey)
    FN.db.tipWidthPads = FN.db.tipWidthPads or {}
    local t = FN.db.tipWidthPads[fontKey]
    if not t then t = {}; FN.db.tipWidthPads[fontKey] = t end
    return t
end
local function Learn(pads, fontKey, extra)
    local k = math.floor(extra * 2 + 0.5) / 2
    local mark = fontKey .. ":" .. k
    if mark == lastLearned then return end -- one count per hover, not per frame
    lastLearned = mark
    pads[k] = math.min((pads[k] or 0) + 1, 99)
end
local function Fits(pads, extra)
    for k, seen in pairs(pads) do
        if seen >= 2 and math.abs(extra - k) <= FIT_PX then return true end
    end
    return false
end
local function AnyTrusted(pads)
    for _, seen in pairs(pads) do if seen >= 2 then return true end end
    return false
end
-- Whether a leftover could be the known amount plus the up/down arrow (an icon about a letter
-- or so wide), when that wider amount hasn't been learned yet.
local function MaybeArrow(pads, extra, size)
    local base
    for k, seen in pairs(pads) do
        if seen >= 2 and (not base or k < base) then base = k end
    end
    return base and extra > base + FIT_PX and extra <= base + size * 1.8
end

-- The one node the tooltip is about, or nil. The tooltip must be as the game made it.
local function MinimapNode(tip)
    if tip:NumLines() ~= 1 or not L:GetText() then return nil end
    local h, w = tip:GetHeight(), tip:GetWidth()
    if not (h and w) or not Clean(h, w) then return nil end
    if not oneLine or h < oneLine then oneLine = h end
    local font, size, flags = L:GetFont()
    if not (font and size) or not Clean(font, size, flags) then return nil end
    if h > oneLine + size * 0.5 then return nil end -- more than one line
    local near = FN:MinimapNodesNearCursor(MATCH_PX)
    if not near or not next(near) then
        if FN.tipDebug and lastDebug ~= "none" then
            lastDebug = "none"
            print("|cffffd100FN tip|r no herb or ore spawn point within " .. MATCH_PX .. "px of the cursor")
        end
        return nil
    end

    local fontKey = font .. ":" .. math.floor(size * 10 + 0.5)
    local pads = Learned(fontKey)
    local only, count, fit, fits = nil, 0, nil, 0
    for node in pairs(near) do
        count = count + 1
        only = node
        local extra = w - NameWidth(node.name, font, size, flags)
        node.fnExtra = extra
        if Fits(pads, extra) then fit, fits = node, fits + 1 end
    end
    if FN.tipDebug then
        local key = ("%.1f"):format(w)
        for node, d in pairs(near) do key = key .. node.key .. ("%.0f"):format(d) end
        if key ~= lastDebug then
            lastDebug = key
            local list = {}
            for k, seen in pairs(pads) do list[#list + 1] = ("%s(x%d)"):format(k, seen) end
            print(("|cffffd100FN tip|r width %.1f  learned: %s"):format(w, table.concat(list, " ")))
            for node, d in pairs(near) do
                print(("   %s  %.0fpx away  leftover %.1f%s"):format(node.name, d, node.fnExtra,
                    Fits(pads, node.fnExtra) and "  FITS" or ""))
            end
        end
    end
    if count == 1 then
        -- Only one type nearby: it teaches the amount. Shown when it fits what was learned
        -- (or nothing is learned yet); otherwise the dot is probably one our data lacks.
        Learn(pads, fontKey, only.fnExtra)
        if not AnyTrusted(pads) or Fits(pads, only.fnExtra) or MaybeArrow(pads, only.fnExtra, size) then
            return only
        end
        return nil
    end
    if fits == 1 then
        Learn(pads, fontKey, fit.fnExtra)
        return fit
    end
    if fits == 0 then
        -- None fits, but exactly one would with the arrow: that's it (and the amount is learned).
        local arrow, arrows = nil, 0
        for node in pairs(near) do
            if MaybeArrow(pads, node.fnExtra, size) then arrow, arrows = node, arrows + 1 end
        end
        if arrows == 1 then
            Learn(pads, fontKey, arrow.fnExtra)
            return arrow
        end
    end
    return nil
end

local function DecorateMinimap(tip)
    local node = MinimapNode(tip)
    if not node then Restore(tip); return end
    local info = FN:GetSkillInfo(node.kind)
    local r, g, b = FN:DifficultyColor(info and info.effective, node.skill)
    local cfg = FN:TipCfg("minimap")
    local open, close, sep = FN:TipPieces(cfg)
    -- On the name line the level always comes after the name (the name itself can't be moved).
    local level = (sep and (sep .. " ") or "") .. open .. node.skill .. close
    local mode = cfg.color
    if cfg.attach == "skill" then
        -- A skill line of our own under the name, like the overworld tooltip's: "150 Herbalism".
        Restore(tip)
        tip:AddLine(FN:FormatSkillText(cfg, node.skill, FN.kindNames[node.kind] or ""), r, g, b)
        busy = true
        tip:Show()
        busy = false
    elseif mode == "level" or mode == "brackets" then
        local gap, crop = Spacing()
        Save(tip)
        R:SetText(level)
        R:SetTextColor(r, g, b)
        local font, size, flags = L:GetFont()
        if font then R:SetFont(font, size, flags) end
        R:Show()
        if tip.SetPadding then tip:SetPadding(-crop, saved[2], saved[3], saved[4]) end
        busy = true
        tip:Show()
        busy = false
        R:ClearAllPoints()
        R:SetPoint("LEFT", L, "RIGHT", gap, 0)
    else
        Restore(tip)
        L:SetText(L:GetText() .. " " .. level)
        if mode == "name" or mode == "line" then L:SetTextColor(r, g, b) end
        busy = true
        tip:Show()
        busy = false
    end
end

hooksecurefunc(GameTooltip, "Show", function(tip)
    if busy then return end
    if FN.db and FN:TipCfg("minimap").on and IsMinimapTip(tip) then
        -- Undo last frame's change first, so the width read is the game's own.
        if saved then
            Restore(tip)
            busy = true
            tip:Show()
            busy = false
        end
        DecorateMinimap(tip)
    elseif saved then
        Restore(tip)
        busy = true
        tip:Show()
        busy = false
    end
end)
GameTooltip:HookScript("OnHide", function(tip)
    Restore(tip)
    lastLearned = nil -- the next hover counts again
end)

local ADDON, FN = ...

-- Tooltips: the skill a herb or vein needs, in its difficulty color.
--   World map: hovering our icons shows one line per node type under the cursor.
--   Overworld: the game's own tooltips (nodes in the world and the minimap's tracking dots)
--              get the level added. Nothing else about those tooltips is changed.
-- The format follows Settings > Tooltips (brackets, position, what gets colored).
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

-- "150 Liferoot" in the chosen style. Colors come from the character's effective skill;
-- a profession the character doesn't have shows red. `name` is the text to keep (it may
-- already carry its own color codes, which stay as they are unless the style colors it).
function FN:FormatTipLine(node, name)
    local db = FN.db
    local info = FN:GetSkillInfo(node.kind)
    local r, g, b = FN:DifficultyColor(info and info.effective, node.skill)
    local c = "|cff" .. Hex(r, g, b)
    local open, close = "", ""
    if db.tipBrackets == "square" then open, close = "[", "]" elseif db.tipBrackets == "round" then open, close = "(", ")" end
    local mode = db.tipColor
    local level = tostring(node.skill)
    local num
    if mode == "level" then num = open .. c .. level .. "|r" .. close
    elseif mode == "brackets" then num = c .. open .. level .. close .. "|r"
    else num = open .. level .. close end
    local text = name or node.name
    if mode == "name" then text = c .. node.name .. "|r" end
    local line = db.tipPosition == "after" and (text .. " " .. num) or (num .. " " .. text)
    if mode == "line" then
        line = c .. (db.tipPosition == "after" and (node.name .. " " .. open .. level .. close)
            or (open .. level .. close .. " " .. node.name)) .. "|r"
    end
    return line
end

-- World map ---------------------------------------------------------------------------------

function FN:ShowWorldTip(owner)
    if not FN.db.tipWorldMap then return end
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
            GameTooltip:AddLine(FN:FormatTipLine(node), 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

-- Overworld ------------------------------------------------------------------------------------
-- Runs after the game and other addons have built the tooltip. Only lines whose text is exactly
-- a known herb or vein name are touched, and only by adding the level; a line already done is
-- left alone, so refreshing tooltips never stack prefixes.

local busy = false
local function Strip(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function Process(tip)
    if busy or not (FN.db and FN.db.tipOverworld) then return end
    if tip ~= GameTooltip then return end
    if not next(byName) then Index() end
    local owner = tip:GetOwner()
    if owner and owner.node then return end -- our own world map tooltip
    local changed = false
    for i = 1, tip:NumLines() do
        local fs = _G["GameTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        -- The game can hand out protected ("secret") text, e.g. the minimap's own tooltip; an
        -- addon may not read or compare it, so such lines are left exactly as they are.
        if issecretvalue and issecretvalue(text) then text = nil end
        -- Skip a line this code already wrote (the same tooltip can be processed twice).
        if text and text ~= "" and text ~= fs.fnDone then
            -- The minimap's tracking tooltip can list several names, one per line, in one string.
            local out, any = {}, false
            for part in (text .. "\n"):gmatch("(.-)\n") do
                local node = byName[Strip(part)]
                if node then
                    out[#out + 1] = FN:FormatTipLine(node, part)
                    any = true
                else
                    out[#out + 1] = part
                end
            end
            if any then
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

local _, FN = ...

-- English strings remain canonical keys in data and SavedVariables. Localization
-- is applied only at display boundaries, independently for UI and world names.
FN.locales = {}
FN.clientNames = {}
FN.localeLayouts = setmetatable({}, { __mode = "k" })
local texts = setmetatable({}, { __mode = "k" })
local cache, cacheSize = {}, 0
local nameRules
local function Secret(value) return issecretvalue and issecretvalue(value) end

function FN:GetUILocale()
    local choice = self.db and self.db.uiLocale
    if choice == "ruRU" or choice == "enUS" then return choice end
    return GetLocale() == "ruRU" and "ruRU" or "enUS"
end

function FN:NodeName(node)
    return self:ClientName(node.name)
end

function FN:ClientName(name)
    local names = self.clientNames[GetLocale()]
    return names and names[name] or name
end

function FN:LoadClientNames()
    for locale, names in pairs(self.db.localizedNodeNames or {}) do
        self.clientNames[locale] = self.clientNames[locale] or {}
        for canonical, observed in pairs(names) do self.clientNames[locale][canonical] = observed end
    end
    cache, cacheSize, nameRules = {}, 0, nil
end

function FN:RememberNodeName(key, name)
    local node = self.byKey and self.byKey[key]
    if not node or Secret(name) or type(name) ~= "string" or name == "" then return end
    local locale = GetLocale()
    local names = self.clientNames[locale] or {}
    if (names[node.name] or node.name) == name then return end
    self.db.localizedNodeNames = self.db.localizedNodeNames or {}
    self.db.localizedNodeNames[locale] = self.db.localizedNodeNames[locale] or {}
    self.db.localizedNodeNames[locale][node.name] = name
    self:LoadClientNames()
end

-- The same alias is accepted when matching a world tooltip or a recorded node.
function FN:NodeMatches(node, name)
    return node.name == name or self:NodeName(node) == name
end

local function Escape(text) return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end
local rules = {}
local function Rules(locale)
    if rules[locale] then return rules[locale] end
    local result = {}
    for source, target in pairs(FN.locales[locale] or {}) do
        local parts, previous, formatted = {}, 1, false
        for start, token, stop in source:gmatch("()(%%[ds])()") do
            parts[#parts + 1] = Escape(source:sub(previous, start - 1))
            parts[#parts + 1] = token == "%d" and "(%d+)" or "(.-)"
            previous, formatted = stop, true
        end
        parts[#parts + 1] = Escape(source:sub(previous))
        result[#result + 1] = { source, target, table.concat(parts), formatted }
    end
    table.sort(result, function(a, b) return #a[1] > #b[1] end)
    rules[locale] = result
    return result
end

local function Replace(text, entries, replacements)
    for _, entry in ipairs(entries) do
        -- Frontier checks stop short labels (e.g. "Name") matching inside names.
        local pattern = entry[3]
        if entry[1]:match("^%a") then pattern = "%f[%a]" .. pattern end
        if entry[4] and entry[1]:match("%%s$") then
            pattern = pattern .. "$"
        elseif entry[1]:match("%a$") and not entry[1]:match("%%[ds]$") then
            pattern = pattern .. "%f[%A]"
        end
        text = text:gsub(pattern, function(...)
            local translated = entry[2]
            if entry[4] then
                local args = {...}
                for i = 1, #args do args[i] = FN:Text(args[i]) end
                local ok, value = pcall(string.format, translated, unpack(args))
                if not ok then return nil end
                translated = value
            end
            replacements[#replacements + 1] = translated
            return "\001" .. #replacements .. "\002"
        end)
    end
    return text
end

function FN:Text(value)
    if Secret(value) or type(value) ~= "string" or value == "" then return value end
    local key = self:GetUILocale() .. ":" .. GetLocale() .. ":" .. value
    if cache[key] then return cache[key] end
    local names = self.clientNames[GetLocale()] or {}
    -- Protect node names before translating UI words: an English-client user
    -- choosing Russian UI must still see English herbs, veins and schools.
    if not nameRules then
        nameRules = {}
        for _, node in ipairs(self.nodes or {}) do
            nameRules[#nameRules + 1] = {node.name, node.name, Escape(node.name)}
        end
        local seen = {}
        for _, entry in ipairs(nameRules) do seen[entry[1]] = true end
        for source in pairs(self.clientNames.ruRU or {}) do
            if not seen[source] and source ~= "Herbalism" and source ~= "Mining" and source ~= "Fishing" then
                nameRules[#nameRules + 1] = {source, source, Escape(source)}
            end
        end
        table.sort(nameRules, function(a, b) return #a[1] > #b[1] end)
    end
    local replacements = {}
    local protected = {}
    -- Preserve links, textures and atlases byte-for-byte; never translate IDs.
    value = value:gsub("|H.-|h.-|h", function(token) protected[#protected + 1] = token; return "\003" .. #protected .. "\004" end)
    value = value:gsub("|[TA].-|[ta]", function(token) protected[#protected + 1] = token; return "\003" .. #protected .. "\004" end)
    value = value:gsub("|c%x%x%x%x%x%x%x%x", function(token) protected[#protected + 1] = token; return "\003" .. #protected .. "\004" end)
    value = value:gsub("|r", function(token) protected[#protected + 1] = token; return "\003" .. #protected .. "\004" end)
    for _, entry in ipairs(nameRules) do entry[2] = names[entry[1]] or entry[1] end
    value = Replace(value, nameRules, replacements)
    local locale = self:GetUILocale()
    if locale ~= "enUS" then
        value = Replace(value, Rules(locale), replacements)
    end
    -- A formatted phrase can contain an already protected node name.
    for _ = 1, 4 do
        local expanded = value:gsub("\001(%d+)\002", function(index) return replacements[tonumber(index)] end)
        if expanded == value then break end
        value = expanded
    end
    value = value:gsub("\003(%d+)\004", function(index) return protected[tonumber(index)] end)
    if cacheSize >= 2048 then cache, cacheSize = {}, 0 end
    cache[key], cacheSize = value, cacheSize + 1
    return value
end

function FN:SetText(widget, value)
    local source = value
    if type(value) == "function" then value = value() end
    local kind = widget.GetObjectType and widget:GetObjectType()
    -- Custom text boxes delegate to their FontString. EditBoxes keep input intact.
    if kind == "FontString" or kind == "Button" or kind == "CheckButton" then
        local parent = widget.GetParent and widget:GetParent()
        if not (parent and parent.GetObjectType and parent:GetObjectType() == "GameTooltip") then
            texts[widget] = source
        end
        widget:SetText(self:Text(value))
    elseif kind == "GameTooltip" then
        widget:SetText(self:Text(value))
    else
        widget:SetText(value)
    end
end

function FN:SetUILocale(locale)
    if locale ~= "auto" and locale ~= "ruRU" and locale ~= "enUS" then return end
    self.db.uiLocale = locale
    for widget, source in pairs(texts) do
        widget:SetText(self:Text(type(source) == "function" and source() or source))
    end
    for widget in pairs(self.localeLayouts) do widget:RefreshLocaleLayout() end
    if self.RefreshOptions then self:RefreshOptions() end
end

function FN:Print(...)
    local args = {...}
    for i = 1, select("#", ...) do args[i] = self:Text(args[i]) end
    print(unpack(args, 1, select("#", ...)))
end

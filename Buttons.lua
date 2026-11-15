local ADDON, FN = ...

local TITLE = "Forever Nodes"

local function Fill(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- A one-line tooltip directly to the left of `owner`, level with it.
-- Drawn here rather than with the game's tooltip, whose padding cannot be tightened
-- and whose text sits off-center when it holds a single short line.
local tip
-- `sub`, if given, is a second, very small line under the first. `subWidest`, if
-- given, is the longest text that line can show: the tooltip is always sized for it,
-- so it keeps the same size when the line changes. `subAtlas`, if given, is a
-- picture drawn in front of that line (as a texture of its own, so it keeps its size).
local SUB_ICON = 16
function FN.ShowTipLeftOf(owner, text, sub, subWidest, subAtlas)
    if not tip then
        tip = CreateFrame("Frame", nil, UIParent)
        tip:SetFrameStrata("TOOLTIP")
        -- The box is drawn to the bounds of `tip.plate`, an empty frame that may sit a
        -- little inside the tooltip (see the trim below) without moving the text.
        -- The textures stay the tooltip's own, so they draw under its text.
        tip.plate = CreateFrame("Frame", nil, tip)
        local bg = Fill(tip, "BACKGROUND", 0.03, 0.03, 0.03, 0.92)
        bg:SetAllPoints(tip.plate)
        for _, edge in ipairs({
            { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
            { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true },
        }) do
            local t = Fill(tip, "BORDER", 1, 1, 1, 0.18)
            t:SetPoint(edge[1], tip.plate, edge[1])
            t:SetPoint(edge[2], tip.plate, edge[2])
            if edge[3] then t:SetWidth(1) else t:SetHeight(1) end
        end
        tip.text = tip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tip.sub = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local skin = FN.skin
        if skin and skin.Font and FN:UsesEllesmereLook() then
            skin.Font(tip.text)
            skin.Font(tip.sub)
        end
        local font, _, flags = tip.sub:GetFont()
        if font then tip.sub:SetFont(font, 9, flags) end
        tip.sub:SetTextColor(0.75, 0.75, 0.75)
        tip.subIcon = tip:CreateTexture(nil, "OVERLAY")
        tip.subIcon:SetSize(SUB_ICON, SUB_ICON)
    end
    tip.text:SetText(text)
    tip.sub:SetText(sub or "")
    tip.sub:SetShown(sub ~= nil)
    local hasIcon = sub ~= nil and subAtlas ~= nil
    if hasIcon then tip.subIcon:SetAtlas(subAtlas, false) end
    tip.subIcon:SetShown(hasIcon)
    -- Sized in the owner's own scale so it lines up with the button exactly.
    tip:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
    -- The measured width runs a few pixels past the last letter (letter spacing and
    -- the text shadow), so the right-hand padding is trimmed to look equal to the left.
    local function Width(fs)
        return math.floor((fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()) + 0.5)
    end
    local width = Width(tip.text)
    tip.text:ClearAllPoints()
    tip.sub:ClearAllPoints()
    if sub then
        local iconSpace = hasIcon and SUB_ICON + 2 or 0
        local subWidth = Width(tip.sub)
        if subWidest then
            tip.sub:SetText(subWidest)
            subWidth = math.max(subWidth, Width(tip.sub))
            tip.sub:SetText(sub)
        end
        width = math.max(width, iconSpace + subWidth)
        tip.text:SetPoint("TOPLEFT", 7, -6) -- the text sits high in its line, so a little more room on top
        local lineHeight = math.ceil(tip.sub:GetStringHeight())
        if hasIcon then
            lineHeight = math.max(lineHeight, SUB_ICON)
            tip.subIcon:ClearAllPoints()
            tip.subIcon:SetPoint("TOPLEFT", tip.text, "BOTTOMLEFT", -2, -1)
            -- Level with the icon by a whole-pixel offset from its top (centering could land on a half pixel).
            local drop = math.floor((SUB_ICON - tip.sub:GetStringHeight()) / 2 + 0.5)
            tip.sub:SetPoint("TOPLEFT", tip.subIcon, "TOPRIGHT", 2, -drop)
        else
            tip.sub:SetPoint("TOPLEFT", tip.text, "BOTTOMLEFT", 0, -2)
        end
        tip:SetSize(width + 7 + 4, math.ceil(tip.text:GetStringHeight()) + lineHeight + 2 + 10)
    else
        tip.text:SetPoint("LEFT", 7, 0)
        tip:SetSize(width + 7 + 4, math.max(20, math.min(owner:GetHeight(), 26)))
    end
    -- The two-line box is drawn one pixel short on the right and at the bottom, which
    -- looks more even; only the drawing moves, so the text stays crisp.
    tip.plate:ClearAllPoints()
    tip.plate:SetPoint("TOPLEFT")
    tip.plate:SetPoint("BOTTOMRIGHT", sub and -1 or 0, sub and 1 or 0)
    tip:ClearAllPoints()
    tip:SetPoint("RIGHT", owner, "LEFT", -3, 0)
    tip:Show()
end

function FN.HideTip()
    if tip then tip:Hide() end
end

-- World map button -----------------------------------------------------------------
-- Sits on the map itself, so it is there with and without the quest log panel.

local function SetupWorldMapButton()
    local map = WorldMapFrame
    if not map then return end
    local viewport = map.ScrollContainer or map

    local btn = CreateFrame("Button", "ForeverNodesWorldMapButton", map)
    btn:SetSize(26, 26)
    btn:SetFrameLevel(math.min(map:GetFrameLevel() + 2000, 9900))

    -- The round icon stays 26px; the button around it may grow into a square (see Place).
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("CENTER")
    icon:SetTexture(FN.MEDIA .. "icon") -- the addon's own icon; round, with its own gold rim
    btn.Icon = icon -- by this name EllesmereUI's button skin leaves it alone
    local glow = btn:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(icon)
    glow:SetTexture(FN.MEDIA .. "disc")
    glow:SetVertexColor(1, 1, 1, 0.25)

    -- Left click opens the options; right click turns the world map icons on or off.
    -- The game's own right-mouse-button picture, if this client has it; "RMB:" otherwise.
    local mouseAtlas
    local atlasInfo = C_Texture and C_Texture.GetAtlasInfo
    for _, atlas in ipairs({ "NPE_RightClick", "newplayertutorial-icon-mouse-rightbutton" }) do
        if atlasInfo and atlasInfo(atlas) then
            mouseAtlas = atlas
            break
        end
    end
    local function ShowTip(self)
        local line = (mouseAtlas and "" or "RMB: ") .. "Map icons <%s>"
        FN.ShowTipLeftOf(self, TITLE,
            line:format(FN.db.worldmap and "|cff33ff33ON|r" or "|cffff4040OFF|r"),
            line:format("OFF"), -- sized for the longer state, so ON and OFF take the same space
            mouseAtlas)
    end
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            FN:ToggleWorldMapIcons()
            ShowTip(self) -- same tooltip, new state
        else
            FN:ToggleMapPanel()
        end
    end)
    btn:SetScript("OnEnter", ShowTip)
    btn:SetScript("OnLeave", FN.HideTip)
    btn:HookScript("OnHide", FN.HideTip)

    -- Beside the quest log's open/close arrow: the two buttons swap the side panel.
    -- The arrow the player sees is one of the toggle's two child buttons.
    local toggle = map.SidePanelToggle
    local arrow = toggle and (toggle.CloseButton or toggle.OpenButton) or toggle

    -- Label the quest log's arrow the same way ours is labelled.
    if toggle then
        for _, key in ipairs({ "OpenButton", "CloseButton" }) do
            local button = toggle[key]
            if button and button.HookScript then
                button:HookScript("OnEnter", function(self)
                    FN.ShowTipLeftOf(self, "Quest Log")
                end)
                button:HookScript("OnLeave", FN.HideTip)
                button:HookScript("OnHide", FN.HideTip)
            end
        end
    end

    -- EllesmereUI look: both buttons are drawn here, identically: the same dark
    -- see-through square, thin edge and hover tint, with only the symbol differing.
    -- (Borrowing the quest button's own skin left the two a different shade and
    -- with different hover behaviour.)
    local function DrawSquare(owner)
        local fill = owner:CreateTexture(nil, "BACKGROUND")
        fill:SetColorTexture(0.03, 0.03, 0.03, 0.78)
        fill:SetAllPoints()
        for _, edge in ipairs({
            { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
            { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true },
        }) do
            local t = owner:CreateTexture(nil, "BORDER")
            t:SetColorTexture(1, 1, 1, 0.14)
            t:SetPoint(edge[1])
            t:SetPoint(edge[2])
            if edge[3] then t:SetWidth(1) else t:SetHeight(1) end
        end
        local hover = owner:CreateTexture(nil, "ARTWORK")
        hover:SetColorTexture(1, 1, 1, 0.10)
        hover:SetAllPoints()
        hover:Hide()
        return hover
    end

    -- Stock look: our button borrows the quest log button's own square. That art
    -- has the button's glyph baked in, so the middle is covered and our icon put there.
    -- Places `target` on our button the way `source` sits on the quest log's button:
    -- same anchors, offsets and size (button art is often larger or smaller than
    -- the button itself, so "fill the button" is not the same thing).
    local function CopyPlacement(source, target)
        target:ClearAllPoints()
        local placed = false
        for i = 1, source:GetNumPoints() do
            local point, relative, relativePoint, x, y = source:GetPoint(i)
            if relative == nil or relative == arrow then
                target:SetPoint(point, btn, relativePoint, x, y)
                placed = true
            end
        end
        if not placed then
            target:SetAllPoints(btn)
            return
        end
        local width, height = source:GetSize()
        if width and width > 0 and height and height > 0 then target:SetSize(width, height) end
    end

    local stockSquared = false
    local function StockSquare()
        local width, height = arrow:GetSize()
        if not width or width < 20 then width, height = 32, 32 end
        btn:SetSize(width, height)
        if stockSquared then return end
        stockSquared = true

        local square = btn:CreateTexture(nil, "BACKGROUND")
        square:SetAllPoints()
        local source = arrow.GetNormalTexture and arrow:GetNormalTexture()
        local atlas = source and source.GetAtlas and source:GetAtlas()
        local file = source and source:GetTexture()
        local hasGlyph = true
        if atlas and atlas ~= "" then
            square:SetAtlas(atlas)
            CopyPlacement(source, square)
        elseif file then
            square:SetTexture(file)
            square:SetTexCoord(source:GetTexCoord())
            CopyPlacement(source, square)
        else
            square:SetTexture("Interface\\Buttons\\UI-SquareButton-Up") -- the game's plain gold-edged square
            hasGlyph = false
        end
        -- A solid dark middle in every case: it hides the baked-in glyph, and the
        -- plain fallback square has a pale face that made the dots look see-through.
        local inset = math.floor(math.min(width, height) * (hasGlyph and 0.22 or 0.16) + 0.5) -- inside the gold edge
        local middle = btn:CreateTexture(nil, "BORDER")
        middle:SetColorTexture(0.05, 0.04, 0.03, 1)
        middle:SetPoint("TOPLEFT", inset, -inset)
        middle:SetPoint("BOTTOMRIGHT", -inset, inset)
        -- Inside the square the icon drops its own circle and rim (the square is the
        -- frame here) and shows just the three dots, as large as the gold edge allows.
        -- The dots come on their own solid dark backing, so nothing behind can show
        -- through between them; it fills the square's middle up to the gold edge.
        -- The image runs right up to the inside of the gold edge; its dots are drawn
        -- smaller within it, so on screen they stay the size they were.
        local size = math.floor(math.min(width, height) * 0.77 + 0.5)
        btn.Icon:SetTexture(FN.MEDIA .. "icon_dots_dark")
        btn.Icon:SetSize(size, size)
        -- Hover: drop the round glow made for the bare icon, and light the square
        -- the way the quest log's button lights up (its own highlight art if readable).
        glow:SetAlpha(0)
        local lit = btn:CreateTexture(nil, "HIGHLIGHT")
        lit:SetAllPoints()
        local hover = arrow.GetHighlightTexture and arrow:GetHighlightTexture()
        local hoverAtlas = hover and hover.GetAtlas and hover:GetAtlas()
        local hoverFile = hover and hover:GetTexture()
        if hoverAtlas and hoverAtlas ~= "" then
            lit:SetAtlas(hoverAtlas)
            lit:SetBlendMode(hover:GetBlendMode())
            CopyPlacement(hover, lit)
        elseif hoverFile then
            lit:SetTexture(hoverFile)
            lit:SetTexCoord(hover:GetTexCoord())
            lit:SetBlendMode(hover:GetBlendMode())
            CopyPlacement(hover, lit)
        else
            lit:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
            lit:SetBlendMode("ADD")
            lit:SetAlpha(0.45)
        end
    end

    local skinned = false
    local function Place()
        btn:SetFrameLevel(math.min(map:GetFrameLevel() + 2000, 9900))
        local squared = arrow ~= nil and FN.UsesEllesmereLook ~= nil and FN:UsesEllesmereLook()
        if squared then
            -- EllesmereUI look: a square button exactly the arrow's size, skinned the
            -- way EllesmereUI skins buttons, and joined to the arrow with no gap. The
            -- quest log's arrow button itself is left exactly as EllesmereUI draws it.
            local width, height = arrow:GetSize()
            if not width or width < 20 then width, height = 34, 34 end
            btn:SetSize(width, height)
            if not skinned then
                skinned = true
                -- Just the three dots, no circle: the dark square is the frame.
                btn.Icon:SetTexture(FN.MEDIA .. "icon_dots")
                btn.Icon:SetSize(22, 22)
                btn.Icon:SetDrawLayer("OVERLAY") -- above the hover tint, like the question mark
                glow:SetAlpha(0) -- the round hover glow belonged to the round icon
                -- EllesmereUI's own button skin, so the square matches the arrow's;
                -- a square drawn here stands in if that skin is unavailable.
                if not FN:SkinAsButton(btn, { "Icon" }) then
                    local hover = DrawSquare(btn)
                    btn:HookScript("OnEnter", function() hover:Show() end)
                    btn:HookScript("OnLeave", function() hover:Hide() end)
                    btn:HookScript("OnHide", function() hover:Hide() end)
                end
            end
        elseif arrow then
            -- Stock look: the same gold-edged square the quest log's button is drawn on.
            StockSquare()
        else
            btn:SetSize(26, 26)
        end

        btn:ClearAllPoints()
        if not arrow then
            btn:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -8, 48)
        else
            -- Always above the arrow: both buttons' labels open to the left.
            btn:SetPoint("BOTTOM", arrow, "TOP", 0, 0)
        end
    end
    Place()
    map:HookScript("OnShow", Place)
end

-- Right click on either button: world map icons on or off.
function FN:ToggleWorldMapIcons()
    FN.db.worldmap = not FN.db.worldmap
    FN:Refresh()
    if FN.RefreshOptions then FN:RefreshOptions() end -- the "Show on world map" tick box
end

-- Minimap button -------------------------------------------------------------------
-- Made with LibDBIcon, so minimap addons (EllesmereUI's button drawer among them)
-- treat it like every other addon's button. Its position and whether it shows are
-- kept in the saved settings (db.minimapIcon, the library's own format).

local function SetupMinimapButton()
    local ldb = LibStub("LibDataBroker-1.1", true)
    local dbicon = LibStub("LibDBIcon-1.0", true)
    if not (ldb and dbicon) then return end
    local db = FN.db
    if type(db.minimapIcon) ~= "table" then db.minimapIcon = { hide = false } end

    local broker
    -- The game's own mouse button pictures (the same ones the map button's tooltip uses),
    -- when this client has them; the tutorial art or plain words otherwise.
    local function MouseIcon(atlases, fallback)
        local info = C_Texture and C_Texture.GetAtlasInfo
        for _, atlas in ipairs(atlases) do
            if info and info(atlas) then return "|A:" .. atlas .. ":14:14|a" end
        end
        return fallback
    end
    local LMB = MouseIcon({ "NPE_LeftClick", "newplayertutorial-icon-mouse-leftbutton" }, "Left-click:")
    local RMB = MouseIcon({ "NPE_RightClick", "newplayertutorial-icon-mouse-rightbutton" }, "Right-click:")
    local function FillTooltip(tooltip)
        tooltip:AddLine(TITLE)
        tooltip:AddLine(LMB .. " Open", 1, 1, 1)
        tooltip:AddLine(RMB .. " Options", 1, 1, 1)
    end

    -- Right click: a short menu of the most used settings.
    local function ShowMenu(owner)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then
            FN:ToggleWorldMapIcons() -- no menu system: the old right click
            return
        end
        -- The button's hover tooltip would sit next to the menu: hide it while the menu is up.
        if dbicon.tooltip then dbicon.tooltip:Hide() end
        if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle("|cffffd100Forever Nodes|r")
            root:CreateDivider()

            local icons = root:CreateButton("Icons")
            for _, entry in ipairs({ { "worldmap", "World map" }, { "minimap", "Minimap" } }) do
                icons:CreateCheckbox(entry[2], function() return db[entry[1]] end, function()
                    db[entry[1]] = not db[entry[1]]
                    FN:Refresh()
                    if FN.RefreshOptions then FN:RefreshOptions() end
                end)
            end

            local tips = root:CreateButton("Tooltips")
            for _, entry in ipairs({ { "world", "World map" }, { "minimap", "Minimap" }, { "overworld", "Overworld" } }) do
                tips:CreateCheckbox(entry[2], function() return FN:TipCfg(entry[1]).on end, function()
                    local cfg = FN:TipCfg(entry[1])
                    cfg.on = not cfg.on
                    if entry[1] == "world" then FN:Refresh() end
                    if FN.RefreshOptions then FN:RefreshOptions() end
                end)
            end

            local panel = root:CreateButton("Panel")
            for _, entry in ipairs({ { true, "Docked to world map" }, { false, "Floating panel" } }) do
                panel:CreateRadio(entry[2], function() return (db.dock and true or false) == entry[1] end, function()
                    db.dock = entry[1]
                    if FN.DockSettingChanged then FN:DockSettingChanged() end
                    if FN.RefreshOptions then FN:RefreshOptions() end
                end)
            end

            root:CreateButton("Settings", function() FN:OpenToSettings() end)
        end)
    end
    broker = ldb:NewDataObject(ADDON, {
        type = "launcher",
        text = TITLE,
        icon = FN.MEDIA .. "icon",
        OnClick = function(self, button)
            if button == "RightButton" then
                ShowMenu(self)
            else
                FN:OpenFromCommand()
            end
        end,
        OnTooltipShow = FillTooltip,
    })
    dbicon:Register(ADDON, broker, db.minimapIcon)

    -- The icon's own gold rim is the button's border: the library's ring and dark
    -- backing are hidden, and the icon is sized to where that ring was drawn
    -- (26 across, centered), so it sits among the other minimap buttons the same way.
    local button = dbicon:GetMinimapButton(ADDON)
    if button and button.icon then
        for _, region in ipairs({ button:GetRegions() }) do
            if region ~= button.icon and region:IsObjectType("Texture") then
                local layer = region:GetDrawLayer()
                if layer == "OVERLAY" or layer == "BACKGROUND" then region:Hide() end
            end
        end
        button.icon:ClearAllPoints()
        button.icon:SetPoint("CENTER", button, "CENTER")
        button.icon:SetSize(26, 26)
        -- The whole picture always (the library otherwise trims its edges, which would cut the rim).
        button.icon.UpdateCoord = function(icon) icon:SetTexCoord(0, 1, 0, 1) end
        button.icon:UpdateCoord()
    end
end

function FN:MinimapButtonShown()
    return not (FN.db.minimapIcon and FN.db.minimapIcon.hide)
end

function FN:SetMinimapButtonShown(show)
    local dbicon = LibStub("LibDBIcon-1.0", true)
    if type(FN.db.minimapIcon) ~= "table" then FN.db.minimapIcon = {} end
    FN.db.minimapIcon.hide = not show
    if not dbicon then return end
    if show then dbicon:Show(ADDON) else dbicon:Hide(ADDON) end
end

-- Options > AddOns page --------------------------------------------------------------
-- The settings live in Forever Nodes' own window; this page says so and opens it.

local function SetupSettingsPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    -- Laid out like the game's own addon pages: a large white title, the divider under
    -- it, then the contents indented, in the normal-size fonts those pages use.
    local page = CreateFrame("Frame")
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 7, -22)
    title:SetText(TITLE)
    -- Version and author beside the title, smaller and grey, on the same baseline.
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    -- A step smaller than body text, sitting on the title's baseline, with the version a
    -- shade dimmer than the author so the two read as separate bits.
    local byline = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    byline:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 10, 2)
    byline:SetText((version and ("|cff6f6f6fv" .. version .. "|r \226\128\148 ") or "") .. "by Lvcid") -- an em dash between
    local divider = page:CreateTexture(nil, "ARTWORK")
    if not pcall(divider.SetAtlas, divider, "Options_HorizontalDivider", true) or not divider:GetAtlas() then
        divider:SetColorTexture(1, 1, 1, 0.12) -- the plain line where the atlas is missing
    end
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 0, -50)
    divider:SetPoint("TOPRIGHT", -18, -50)
    -- Left: what this page is for and how to open the window. Right: where the
    -- world map button is, as a picture.
    local LEFT, TOP = 27, -72
    local intro = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", LEFT, TOP - 10) -- a little below the frame's top, so the block sits centered beside it
    intro:SetText("All settings are in Forever Nodes' own window.")
    local open = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    open:SetSize(180, 26)
    open:SetPoint("TOP", intro, "BOTTOM", 0, -34) -- centered under the line above, with room above it
    open:SetText("Open Forever Nodes")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        FN:OpenFromCommand()
    end)
    -- Straight to the window's Settings page.
    local openSettings = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    openSettings:SetSize(180, 26)
    openSettings:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -6)
    openSettings:SetText("Show Settings")
    openSettings:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        FN:OpenToSettings()
    end)
    local also = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    also:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 22, -125) -- indented a little, clear of the buttons
    also:SetText("It also opens from:")
    local ways = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ways:SetPoint("TOPLEFT", also, "BOTTOMLEFT", 8, -8)
    ways:SetJustifyH("LEFT")
    ways:SetSpacing(5)
    ways:SetText("-  the world map button (pictured)\n-  the minimap button\n-  typing |cffffd100/fn|r")

    -- One picture per look (EllesmereUI or stock), with everything in it: the map's
    -- bottom-right corner with a soft spotlight on the button, a caption, what its
    -- two mouse buttons do, and a thin gold line from the button to those directions.
    -- Picked each time the page is shown, as the look can change.
    local PICTURES = {
        eui = { file = "where_eui", w = 349, h = 292 },   -- pixels used in a 512 x 512 image
        stock = { file = "where_stock", w = 353, h = 292 },
    }
    local SCALE = 0.837 -- screenshot pixels to page units, so the text in it matches the page's
    -- The picture sits on its own layer inside the frame below, so it always draws on top of the frame's fill.
    local art = CreateFrame("Frame", nil, page)
    art:SetPoint("TOPLEFT", page, "TOPLEFT", 335, TOP - 1) -- the frame top lines up with the first line of text
    art:SetSize(1, 1)
    local picture

    -- A frame around the whole graphic (map, caption and mouse rows), 8 units clear of
    -- what the picture shows (it starts 4 in and 9 down, and ends at 286 x 238).
    local box = CreateFrame("Frame", nil, page)
    box:SetPoint("TOPLEFT", art, "TOPLEFT", -4, -1)
    box:SetPoint("BOTTOMRIGHT", art, "TOPLEFT", 294, -243)
    art:SetParent(box) -- a child of the frame, so drawn above it
    picture = art:CreateTexture(nil, "ARTWORK")
    picture:SetPoint("TOPLEFT", art, "TOPLEFT")
    local boxFill = box:CreateTexture(nil, "BACKGROUND")
    boxFill:SetAllPoints()
    local boxEdges = {}
    for _, edge in ipairs({
        { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
        { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true },
    }) do
        local t = box:CreateTexture(nil, "BORDER")
        t:SetPoint(edge[1])
        t:SetPoint(edge[2])
        if edge[3] then t:SetWidth(1) else t:SetHeight(1) end
        boxEdges[#boxEdges + 1] = t
    end

    local function ShowPicture()
        local eui = FN.UsesEllesmereLook and FN:UsesEllesmereLook()
        local look = PICTURES[eui and "eui" or "stock"]
        picture:SetTexture(FN.MEDIA .. look.file)
        picture:SetTexCoord(0, look.w / 512, 0, look.h / 512)
        picture:SetSize(math.floor(look.w * SCALE + 0.5), math.floor(look.h * SCALE + 0.5))
        -- EllesmereUI: a faint dark panel with a thin light edge. Stock: a dark panel
        -- with the muted gold edge of the game's own frames.
        if eui then
            boxFill:SetColorTexture(0, 0, 0, 0.25)
            for _, t in ipairs(boxEdges) do t:SetColorTexture(1, 1, 1, 0.14) end
        else
            boxFill:SetColorTexture(0, 0, 0, 0.30)
            for _, t in ipairs(boxEdges) do t:SetColorTexture(0.77, 0.59, 0.28, 0.75) end
        end
    end
    ShowPicture()
    page:HookScript("OnShow", ShowPicture)

    -- Options, under their own heading as on the game's pages.
    local heading = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    heading:SetPoint("TOPLEFT", page, "TOPLEFT", 20, TOP - 262) -- under the framed picture
    heading:SetText("Miscellaneous")

    local function Tick(text, anchor, y)
        local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
        local label = box.Text or box.text
        if label then
            label:SetFontObject("GameFontNormal") -- the size the game's own pages use for options
            label:SetText(text)
        end
        return box
    end

    local mini = Tick("Show the minimap button", heading, -10)
    mini:ClearAllPoints()
    mini:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", LEFT - 20 - 4, -10)
    mini:SetScript("OnShow", function(self) self:SetChecked(FN:MinimapButtonShown()) end)
    mini:SetScript("OnClick", function(self)
        FN:SetMinimapButtonShown(self:GetChecked() and true or false)
        if FN.RefreshOptions then FN:RefreshOptions() end
    end)

    -- A way out if another addon's map makes docking impossible: the floating window.
    -- The opposite of "Dock to the world map" in the window (the same saved setting).
    local float = Tick("Use a floating window instead of docking", mini, -4)
    float:SetScript("OnShow", function(self) self:SetChecked(not FN.db.dock) end)
    float:SetScript("OnClick", function(self)
        FN.db.dock = not self:GetChecked()
        FN:DockSettingChanged()
        if FN.RefreshOptions then FN:RefreshOptions() end
    end)
    local floatNote = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    floatNote:SetPoint("TOPLEFT", float, "BOTTOMLEFT", 30, 2)
    floatNote:SetJustifyH("LEFT")
    floatNote:SetSpacing(3)
    floatNote:SetText("Recommended: |cffff4040Disabled|r\n"
        .. "Only enable if another addon stops the docked window from showing correctly.")

    -- Plain: the list turns the selected entry white, which it cannot do to colored letters.
    local category = Settings.RegisterCanvasLayoutCategory(page, TITLE)
    Settings.RegisterAddOnCategory(category)
end

function FN:SetupButtons()
    SetupWorldMapButton()
    FN:SetupMapPanel()
    SetupMinimapButton()
    SetupSettingsPage()
end

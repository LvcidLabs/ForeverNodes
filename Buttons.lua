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
    tip.owner = owner
    tip:Show()
end

function FN.HideTip()
    if tip then tip:Hide() end
end

-- Hides the label only if it is this frame's own (the quest log's two arrow buttons swap places
-- as the panel opens or closes, and must not take the map button's label with them).
local function HideOwnTip(owner)
    if tip and tip.owner == owner then tip:Hide() end
end

-- World map button -----------------------------------------------------------------
-- Sits on the map itself, so it is there with and without the quest log panel.

local function SetupWorldMapButton()
    local map = WorldMapFrame
    if not map then return end
    local viewport = map.ScrollContainer or map

    local dragging = false -- the button is being dragged to a new place
    local dragEnd          -- when the last drag ended (the mouse let go over the button is not a click)

    -- OpenMap keeps its own buttons above the quest log's arrow (where ours goes by default), and
    -- asks a new install to choose its map style the first time the map opens.
    local function OpenMapOn()
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
        return loaded and loaded("OpenMap") or false
    end
    local function OpenMapAsking()
        local settings = OpenMapOn() and type(OpenMapDB) == "table" and OpenMapDB.worldmap
        return type(settings) == "table" and settings.enabled ~= false and settings.presetAsked == false
    end
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
        if dragging then return end
        local line = (mouseAtlas and "" or "RMB: ") .. "Map icons <%s>"
        FN.ShowTipLeftOf(self, TITLE,
            line:format(FN.db.worldmap and "|cff33ff33ON|r" or "|cffff4040OFF|r"),
            line:format("OFF"), -- sized for the longer state, so ON and OFF take the same space
            mouseAtlas)
    end
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if dragging or (dragEnd and GetTime() - dragEnd < 0.3) then return end
        if button == "RightButton" then
            FN:ToggleWorldMapIcons()
            ShowTip(self) -- same tooltip, new state
        else
            FN:ToggleMapPanel()
            -- The map lays itself out again as the panel comes or goes: the label back once it has.
            C_Timer.After(0, function()
                if self:IsVisible() and self:IsMouseOver() and not dragging then ShowTip(self) end
            end)
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
                button:HookScript("OnLeave", HideOwnTip)
                button:HookScript("OnHide", HideOwnTip)
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

    -- Where the button may go: anywhere on the map's side of the window, from the window's left
    -- edge to the map area's right edge (where the quest log or the panel starts), and from the
    -- bottom up to the top of the zone menus' row. As left, bottom, right, top, in the map area's
    -- units from its bottom left corner.
    local function Bounds()
        local vl, vb, vw, vh = viewport:GetLeft(), viewport:GetBottom(), viewport:GetWidth(), viewport:GetHeight()
        if not (vl and vb and vw and vh) or vw <= 0 or vh <= 0 then return nil end
        local vs = viewport:GetEffectiveScale()
        local left, top = 0, vh
        local ml = map:GetLeft()
        if ml then left = math.min(0, ml * map:GetEffectiveScale() / vs - vl + 4) end
        local row = map.NavBar or map.TitleCanvasSpacerFrame
        local rowTop = row and row:GetTop()
        if rowTop then top = math.max(vh, rowTop * row:GetEffectiveScale() / vs - vb) end
        return left, 0, vw, top
    end

    -- Where the button sits: where the player put it (saved as a share of the map area's width and
    -- height, kept inside Bounds), or above the quest log's arrow (with OpenMap, whose buttons are
    -- there, in the map's top right corner).
    local function Anchor()
        btn:ClearAllPoints()
        local pos = FN.db.mapButtonPos
        local ratio = viewport:GetEffectiveScale() / btn:GetEffectiveScale()
        local left, bottom, right, top = Bounds()
        if pos and left then
            local w, h = viewport:GetWidth() * ratio, viewport:GetHeight() * ratio
            local halfW, halfH = btn:GetWidth() / 2, btn:GetHeight() / 2
            btn:SetPoint("CENTER", viewport, "BOTTOMLEFT",
                math.max(left * ratio + halfW, math.min(right * ratio - halfW, pos.x * w)),
                math.max(bottom * ratio + halfH, math.min(top * ratio - halfH, pos.y * h)))
        elseif OpenMapOn() then
            -- The quest log button's gaps from the map's bottom right corner, mirrored at the top.
            local side, bottom = 8, 8
            local aRight, aBottom = arrow and arrow:GetRight(), arrow and arrow:GetBottom()
            local vRight, vBottom = viewport:GetRight(), viewport:GetBottom()
            if aRight and aBottom and vRight and vBottom then
                local toBtn = arrow:GetEffectiveScale() / btn:GetEffectiveScale()
                local vToBtn = viewport:GetEffectiveScale() / btn:GetEffectiveScale()
                local gapSide = vRight * vToBtn - aRight * toBtn
                local gapBottom = aBottom * toBtn - vBottom * vToBtn
                if gapSide >= 0 and gapSide < 60 and gapBottom >= 0 and gapBottom < 60 then
                    side, bottom = gapSide, gapBottom
                end
            end
            btn:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", -side, -bottom)
        elseif not arrow then
            btn:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -8, 48)
        else
            -- Always above the arrow: both buttons' labels open to the left.
            btn:SetPoint("BOTTOM", arrow, "TOP", 0, 0)
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

        Anchor()
        btn:SetShown(FN.db.mapButtonShown)
    end
    Place()
    map:HookScript("OnShow", Place)

    -- First install: the first time the map opens it dims, except for a circle around this
    -- button, with a note beside it. "Quick Tutorial" walks through the panel step by step.
    -- The tour ends back on this note, so a step can be seen again; only "Okay" ends it for good
    -- (closing the map just brings the note back next time). Other clicks on the dimmed map do
    -- nothing, except on what a step invites the player to try. It is drawn on its own top layer,
    -- above the map and everything in the panel. The circle and the note follow the button wherever it is.
    local TOUR_STEPS = 6
    local spot, dim, hole, ring, mapDim, focus, tourClick
    local note, noteArrow, noteHead, noteText, noteCount, noteLeft, noteRight
    local tourStep -- nil on the opening note
    local GoToStep

    local function Glyph(atlases)
        for _, atlas in ipairs(atlases) do
            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
                return "|A:" .. atlas .. ":16:16|a "
            end
        end
        return ""
    end
    local LMB = Glyph({ "NPE_LeftClick", "newplayertutorial-icon-mouse-leftbutton" })
    local RMB = Glyph({ "NPE_RightClick", "newplayertutorial-icon-mouse-rightbutton" })
    local OPENING_TEXT = LMB .. "Open\n" .. RMB .. "Quick-hide icons"
    local STEP_TEXT = {
        LMB .. "Switch between professions",
        LMB .. "Toggle gathering nodes",
        LMB .. "|cff808080(skill bar)|r Reveals the trainer list",
        LMB .. "Pins a trainer to your map\n\nSort by distance or price. Prices include this character's reputation discounts.",
        LMB .. "Sorts gather nodes by level or alphabetically",
        "All the settings for this addon can be accessed directly inside the panel.",
    }

    local function CloseSpotlight()
        tourStep = nil
        if spot then spot:Hide() end
        if FN.TourFinish then FN:TourFinish() end
    end
    local function EndSpotlight()
        FN.db.spotlightDue = nil
        CloseSpotlight()
    end
    local BackToOpening
    local function FadeIn(self, elapsed)
        self.faded = self.faded + elapsed
        self:SetAlpha(math.min(self.faded / 0.3, 1))
        if self.faded >= 0.3 then self:SetScript("OnUpdate", nil) end
    end

    local function NoteButton(onSide)
        local b = CreateFrame("Button", nil, note, "UIPanelButtonTemplate")
        b:SetHeight(22)
        b:SetPoint(onSide, onSide == "BOTTOMLEFT" and 12 or -12, 12)
        return b
    end
    local function BuildSpotlight()
        spot = CreateFrame("Frame", nil, UIParent)
        spot:SetFrameStrata("TOOLTIP")
        spot:SetFrameLevel(100)
        spot:SetAllPoints(map)
        spot:EnableMouse(true)
        -- The panel's steps dim only the map beside the panel; the gold highlight does the rest.
        mapDim = spot:CreateTexture(nil, "BACKGROUND")
        mapDim:SetColorTexture(0, 0, 0, 0.75)
        mapDim:SetPoint("TOPLEFT")
        mapDim:SetPoint("BOTTOMLEFT")
        dim = spot:CreateTexture(nil, "BACKGROUND")
        dim:SetAllPoints()
        dim:SetTexture("Interface\\Buttons\\WHITE8X8")
        dim:SetVertexColor(0, 0, 0, 0.75)
        -- Clear in the middle; everything beyond the picture's edge stays dimmed.
        hole = spot:CreateMaskTexture()
        hole:SetTexture(FN.MEDIA .. "spotlight_mask", "CLAMPTOWHITEADDITIVE", "CLAMPTOWHITEADDITIVE")
        dim:AddMaskTexture(hole)
        ring = spot:CreateTexture(nil, "ARTWORK") -- the gold edge of the circle
        ring:SetTexture(FN.MEDIA .. "spotlight_ring")

        -- The gold edge of a square focus, with a soft glow outside it, like the note's own.
        focus = CreateFrame("Frame", nil, spot)
        focus:SetFrameLevel(102)
        local edge = focus:CreateTexture(nil, "OVERLAY")
        edge:SetTexture(FN.MEDIA .. "spotlight_focus")
        edge:SetTextureSliceMargins(20, 20, 20, 20)
        edge:SetPoint("TOPLEFT", -12, 12)
        edge:SetPoint("BOTTOMRIGHT", 12, -12)

        -- Over what a step invites the player to click: passes the click on to the real thing.
        tourClick = CreateFrame("Button", nil, spot)
        tourClick:SetFrameLevel(105)
        tourClick:RegisterForClicks("LeftButtonUp")
        tourClick:SetScript("OnClick", function()
            if tourStep == 5 then
                FN:TourSort()
            else
                GoToStep(tourStep + 1)
            end
        end)

        -- The note: the game's own gold help box, its arrow pointing at what it is about.
        note = CreateFrame("Frame", nil, spot, "GlowBoxTemplate")
        note:SetFrameLevel(110)
        note:SetWidth(226)
        note:EnableMouse(true)
        noteHead = note:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
        noteHead:SetPoint("TOPLEFT", 15, -15)
        noteHead:SetText("|cffffd100[Forever Nodes]|r |cff707070by Lvcid|r")
        noteText = note:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
        noteText:SetWidth(196)
        noteText:SetJustifyV("TOP")
        noteText:SetSpacing(3)
        noteCount = note:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        noteCount:SetPoint("BOTTOMLEFT", 16, 18)
        noteLeft = NoteButton("BOTTOMLEFT")
        noteLeft:SetWidth(104)
        noteLeft:SetText("Quick Tutorial")
        noteLeft:SetScript("OnClick", function() GoToStep(1) end)
        noteRight = NoteButton("BOTTOMRIGHT")
        noteRight:SetWidth(84)
        noteRight:SetScript("OnClick", function()
            if not tourStep then
                EndSpotlight()
            elseif tourStep < TOUR_STEPS then
                GoToStep(tourStep + 1)
            else
                BackToOpening()
            end
        end)
        noteArrow = CreateFrame("Frame", nil, note, "GlowBoxArrowTemplate")
        noteArrow:SetSize(61, 61)
        noteArrow.Arrow:ClearAllPoints()
        noteArrow.Arrow:SetPoint("CENTER")
    end

    local function PointArrow(onRight, arrowY)
        noteArrow:ClearAllPoints()
        noteArrow.Glow:ClearAllPoints()
        noteArrow:SetPoint("CENTER", note, onRight and "LEFT" or "RIGHT", onRight and -5 or 5, arrowY)
        noteArrow.Glow:SetPoint("CENTER", noteArrow.Arrow, "CENTER", onRight and -4 or 4, 0)
        SetClampedTextureRotation(noteArrow.Arrow, onRight and 90 or 270)
        SetClampedTextureRotation(noteArrow.Glow, onRight and 90 or 270)
    end
    local function ArrowRoom(y)
        local most = note:GetHeight() / 2 - 20
        return math.max(-most, math.min(most, y))
    end

    -- The circle: the note goes on the side of the button with more room, inside the map.
    local function PlaceNote()
        local bx, by = btn:GetCenter()
        local left, right = viewport:GetLeft(), viewport:GetRight()
        local top, bottom = viewport:GetTop(), viewport:GetBottom()
        if not (bx and left and top) then return end
        local ratio = viewport:GetEffectiveScale() / btn:GetEffectiveScale()
        local room = note:GetHeight() / 2 + 8
        local dy = math.max(bottom * ratio + room - by, math.min(top * ratio - room - by, 0))
        local onRight = bx < (left + right) / 2 * ratio
        note:ClearAllPoints()
        if onRight then
            note:SetPoint("LEFT", btn, "RIGHT", 20, dy)
        else
            note:SetPoint("RIGHT", btn, "LEFT", -20, dy)
        end
        PointArrow(onRight, ArrowRoom(-dy))
    end

    -- The gold edge around a focused area, given in screen pixels.
    local function DrawFocus(r)
        local scale = spot:GetEffectiveScale()
        focus:ClearAllPoints()
        focus:SetPoint("BOTTOMLEFT", spot, "BOTTOMLEFT", r.l / scale - spot:GetLeft(), r.b / scale - spot:GetBottom())
        focus:SetSize((r.r - r.l) / scale, (r.t - r.b) / scale)
        focus:Show()
    end

    -- The circle around `target`, its clear middle fitting a thing of about that size.
    local function DrawCircle(target, size)
        mapDim:Hide()
        focus:Hide()
        dim:Show()
        for _, part in ipairs({ hole, ring }) do
            part:ClearAllPoints()
            part:SetPoint("CENTER", target)
            part:SetSize(size, size)
        end
        ring:Hide() -- the map button has the plain spotlight
    end

    -- Puts the dimming and the note where the current step wants them.
    local function Render()
        if not (spot and spot:IsShown()) then return end
        local info = tourStep and FN:TourRects(tourStep)
        if not info then
            tourClick:Hide()
            DrawCircle(btn, 200)
            PlaceNote()
            return
        end
        local scale = spot:GetEffectiveScale()
        dim:Hide()
        mapDim:SetWidth(math.max(1, info.left / scale - spot:GetLeft()))
        mapDim:Show()
        if info.circle then
            focus:Hide()
            tourClick:Hide()
            ring:ClearAllPoints()
            ring:SetPoint("CENTER", info.circle)
            ring:SetSize(84, 84)
            ring:Show()
        else
            ring:Hide()
            local r = info.rects[1]
            DrawFocus(r)
            tourClick:SetShown(info.click)
            tourClick:ClearAllPoints()
            tourClick:SetPoint("BOTTOMLEFT", spot, "BOTTOMLEFT", r.l / scale - spot:GetLeft(), r.b / scale - spot:GetBottom())
            tourClick:SetSize((r.r - r.l) / scale, (r.t - r.b) / scale)
        end
        -- Left of the panel, level with what it is about, and inside the map.
        local y = info.y / scale - spot:GetBottom()
        local room = note:GetHeight() / 2 + 8
        local noteY = math.max(room, math.min(spot:GetHeight() - room, y))
        note:ClearAllPoints()
        note:SetPoint("RIGHT", spot, "BOTTOMLEFT", info.left / scale - spot:GetLeft() - 24, noteY)
        PointArrow(false, ArrowRoom(y - noteY))
    end
    local function RenderSoon()
        Render()
        C_Timer.After(0, Render) -- once the map has finished laying itself out
        C_Timer.After(0.1, Render)
    end

    local function FillNote()
        local opening = tourStep == nil
        noteHead:SetShown(opening)
        noteText:ClearAllPoints()
        noteText:SetPoint("TOPLEFT", 15, opening and -37 or -15)
        noteText:SetWidth(600)
        noteText:SetText(opening and OPENING_TEXT or STEP_TEXT[tourStep])
        -- Wide enough to keep a short line on one row; a long sentence wraps.
        local noteWidth = math.min(320, math.max(226, math.ceil(noteText:GetStringWidth()) + 32))
        note:SetWidth(noteWidth)
        noteText:SetWidth(noteWidth - 30)
        noteCount:SetText(opening and "" or (tourStep .. "/" .. TOUR_STEPS))
        local guide = opening and FN:TourAvailable()
        noteLeft:SetShown(guide)
        -- The opening note's buttons are centered, one to a row; the steps' sits at the right.
        noteRight:ClearAllPoints()
        if opening then
            noteRight:SetWidth(150)
            noteRight:SetPoint("BOTTOM", 0, 12)
            noteLeft:SetWidth(150)
            noteLeft:ClearAllPoints()
            noteLeft:SetPoint("BOTTOM", noteRight, "TOP", 0, 4)
        else
            noteRight:SetWidth(84)
            noteRight:SetPoint("BOTTOMRIGHT", -12, 12)
        end
        noteRight:SetText(opening and "Okay" or (tourStep < TOUR_STEPS and "Next" or "Done"))
        note:SetHeight((opening and 37 or 15) + noteText:GetStringHeight() + 14 + (guide and 26 or 0) + 22 + 12)
    end
    GoToStep = function(step)
        tourStep = step
        -- A step with nothing to show (no trainer to pin at the top rank) is passed over.
        if FN:TourPrepare(step) == false then return GoToStep(step + 1) end
        FillNote()
        RenderSoon()
    end
    BackToOpening = function()
        tourStep = nil
        FN:TourFinish() -- the panel closes and everything is as it was
        FillNote()
        RenderSoon()
    end
    -- While OpenMap's own first question is up, ours waits (it would cover OpenMap's buttons), and
    -- shows on this same opening once it is answered.
    local waitingForOpenMap
    local function ShowSpotlight()
        if not (FN.db.spotlightDue and btn:IsShown()) or tourStep then return end
        if OpenMapAsking() then
            if not waitingForOpenMap then
                waitingForOpenMap = C_Timer.NewTicker(0.25, function(ticker)
                    if map:IsShown() and OpenMapAsking() then return end
                    ticker:Cancel()
                    waitingForOpenMap = nil
                    if map:IsShown() then ShowSpotlight() end
                end)
            end
            return
        end
        if not spot then BuildSpotlight() end
        spot:SetScale(map:GetEffectiveScale() / UIParent:GetEffectiveScale())
        spot.faded = 0
        spot:SetAlpha(0)
        spot:SetScript("OnUpdate", FadeIn)
        spot:Show()
        FillNote()
        RenderSoon()
    end
    map:HookScript("OnShow", ShowSpotlight)
    -- The map can blink while it resizes: only a map that stays closed ends this.
    map:HookScript("OnHide", function()
        C_Timer.After(0, function()
            if spot and spot:IsShown() and not map:IsShown() then CloseSpotlight() end
        end)
    end)
    viewport:HookScript("OnSizeChanged", function()
        Anchor()
        Render()
    end)

    -- Moving the button: a left-button drag takes it anywhere on the map's side of the window
    -- (Bounds), unless it is locked in the settings.
    local function FollowCursor()
        local x, y = GetCursorPosition()
        local scale = viewport:GetEffectiveScale()
        local left, bottom, right, top = Bounds()
        if not left then return end
        local w, h = viewport:GetWidth(), viewport:GetHeight()
        FN.db.mapButtonPos = {
            x = math.max(left, math.min(right, x / scale - viewport:GetLeft())) / w,
            y = math.max(bottom, math.min(top, y / scale - viewport:GetBottom())) / h,
        }
        Anchor()
        Render()
    end
    local function StopDragging()
        if not dragging then return end
        dragging = false
        dragEnd = GetTime()
        btn:SetScript("OnUpdate", nil)
        if FN.RefreshOptions then FN:RefreshOptions() end -- "Reset position" can be used now
    end
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if FN.db.mapButtonLocked or tourStep then return end
        dragging = true
        FN.HideTip()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    btn:SetScript("OnDragStop", StopDragging)
    btn:HookScript("OnHide", StopDragging)

    function FN:MapButtonShown() return FN.db.mapButtonShown end
    function FN:SetMapButtonShown(shown)
        FN.db.mapButtonShown = shown
        if not shown then StopDragging() end
        btn:SetShown(shown)
        if FN.RefreshOptions then FN:RefreshOptions() end
    end
    function FN:MapButtonLocked() return FN.db.mapButtonLocked and true or false end
    function FN:SetMapButtonLocked(locked)
        FN.db.mapButtonLocked = locked and true or nil
        if locked then StopDragging() end
        if FN.RefreshOptions then FN:RefreshOptions() end
    end
    function FN:MapButtonMoved() return FN.db.mapButtonPos ~= nil end
    function FN:ResetMapButton()
        StopDragging()
        FN.db.mapButtonPos = nil
        Anchor()
        Render()
        if FN.RefreshOptions then FN:RefreshOptions() end
    end
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

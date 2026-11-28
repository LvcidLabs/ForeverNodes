local ADDON, FN = ...

local TITLE = "Forever Nodes"

local WIDTH, HEIGHT = 738, 520
local DOCK_WIDTH = 340 -- narrow one-column layout when attached to the world map
local BAR_HEIGHT = 25 -- the title strip (EllesmereUI's window shell draws one this tall)
local NAV_WIDTH = 150
local ROW_HEIGHT, COL_WIDTH, COL_GAP = 22, 262, 10

local floor = math.floor

-- Look ---------------------------------------------------------------------------
-- Two looks, chosen when the window is first opened (see Skin and Stock below):
--   EllesmereUI  its skinning API paints the window shell and supplies the font; the
--                rest is drawn here: dark see-through panes, bronze for selection.
--   Stock        Blizzard's own window frame, red buttons, tick boxes, sliders and
--                inset panels, with the game's gold for selection.

local GOLD = { 1, 0.82, 0 }
local BRONZE = { 0.753, 0.541, 0.243 }
-- Quiet trim for structure (section edges and rules), matching the controls' neutral edges with a
-- touch of the theme's warmth; gold stays for what is active or selected.
local TRIM = { 0.92, 0.86, 0.76, 0.24 }

-- Clicking a panel control takes keyboard focus from the chat box (the typed text stays, but
-- typing stops). The control notes which edit box had focus and hands it back after the click.
local function KeepChatFocus(b)
    local function Note()
        local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if f and f.IsObjectType and f:IsObjectType("EditBox") then b.fnFocus = f end
    end
    local function Restore()
        local f = b.fnFocus
        -- Only a message still being written (an always-shown, empty chat box is left alone).
        if f and f:IsShown() and not f:HasFocus() and (f:GetText() or "") ~= "" then f:SetFocus() end
    end
    b:HookScript("OnEnter", Note)
    b:HookScript("OnMouseDown", Note)
    b:HookScript("OnLeave", function() b.fnFocus = nil end)
    b:HookScript("PostClick", function()
        Restore()
        if C_Timer then C_Timer.After(0, Restore) end
    end)
end
local MUTED = { 0.63, 0.63, 0.63 }

if EllesmereUI and EllesmereUI.RegisterSkin then
    EllesmereUI.RegisterSkin(ADDON, function(skin) FN.skin = skin end)
end

-- EllesmereUI's skinning API, or nil when the window should wear the game's own
-- look. Its look is used only when it is loaded, its add-on skinning is on for
-- us, and the player lets it skin the world map (our panel sits against it).
local function Skin()
    local skin = FN.skin
    if not (skin and skin.IsEnabled()) then return nil end
    local style = EllesmereUI.GetBlizzWindowStyle and EllesmereUI.GetBlizzWindowStyle("worldmap")
    if style == "off" or style == "blizzard" then return nil end
    return skin
end

-- True for the game's stock look: Blizzard's window frame, buttons, tick boxes and sliders.
local function Stock()
    return Skin() == nil
end

function FN:UsesEllesmereLook()
    return Skin() ~= nil
end

-- Gives `button` EllesmereUI's flat button look. `keep` names regions to leave untouched.
-- Returns false when that is not available.
function FN:SkinAsButton(button, keep)
    local skin = Skin()
    if not (skin and skin.Button) then return false end
    skin.Button(button, keep)
    return true
end

-- CreateFrame with a Blizzard template, or nil if this client does not have it.
local function TryTemplate(frameType, name, parent, template)
    local ok, made = pcall(CreateFrame, frameType, name, parent, template)
    return ok and made or nil
end

-- A stock red button. `.text` is its label, as on the drawn buttons.
local function StockButton(parent, text, width, height, onClick)
    local b = TryTemplate("Button", nil, parent, "UIPanelButtonTemplate")
    if not b then return nil end
    b:SetSize(width, height)
    -- The small game font: these sit in tight rows.
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetText(text)
    b.text = b:GetFontString()
    b:SetScript("OnClick", onClick)
    KeepChatFocus(b)
    function b:SetSelected(selected)
        if selected then self:LockHighlight() else self:UnlockHighlight() end
    end
    return b
end

local function Fill(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- A wash of color fading out to the right.
local function Fade(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(1, 1, 1, 1)
    function t:SetFade(fr, fg, fb, fa)
        if self.SetGradient and CreateColor then
            -- `reversed` fades in toward the right instead of out.
            local strong, clear = CreateColor(fr, fg, fb, fa), CreateColor(fr, fg, fb, 0)
            if self.reversed then
                self:SetGradient("HORIZONTAL", clear, strong)
            else
                self:SetGradient("HORIZONTAL", strong, clear)
            end
        else
            self:SetColorTexture(fr, fg, fb, fa * 0.6)
        end
    end
    t:SetFade(r, g, b, a)
    return t
end

-- 1px outline around `region`, drawn by `frame`. Returns the four edges.
local function Outline(frame, region, r, g, b, a)
    local edges = {}
    local function Edge(p1, p2, vertical)
        local t = Fill(frame, "BORDER", r, g, b, a)
        t:SetPoint(p1, region, p1)
        t:SetPoint(p2, region, p2)
        if vertical then t:SetWidth(1) else t:SetHeight(1) end
        edges[#edges + 1] = t
    end
    Edge("TOPLEFT", "TOPRIGHT")
    Edge("BOTTOMLEFT", "BOTTOMRIGHT")
    Edge("TOPLEFT", "BOTTOMLEFT", true)
    Edge("TOPRIGHT", "BOTTOMRIGHT", true)
    return edges
end

-- The panel's colors. The window's frame, buttons and selection follow the interface; these
-- follow the Theme setting and can be swapped live.
local TONE = {
    brown = { back = { 0.10, 0.07, 0.04, 1 }, backHead = { 0.08, 0.055, 0.03, 1 }, strip = { 0.08, 0.05, 0.025, 1 },
        fill = { 0.20, 0.13, 0.07, 0.85 }, line = { 0.20, 0.13, 0.07, 0.85 }, tint = { 0.20, 0.13, 0.07, 0.25 },
        edge = { 0.55, 0.42, 0.20, 0.55 }, swatch = { 0.44, 0.31, 0.17, 1 }, chip = { 0.16, 0.10, 0.05, 0.85 } },
    -- (back / backHead: the panel's own color under an open section / under a header, measured
    -- in game; strip: Preview's darker brown)
    dark = { back = { 0.082, 0.074, 0.063, 1 }, backHead = { 0.059, 0.051, 0.047, 1 },
        strip = { 0.062, 0.050, 0.038, 1 }, fill = { 1, 1, 1, 0.07 }, line = { 1, 1, 1, 0.10 }, tint = { 1, 1, 1, 0.025 },
        edge = { 1, 1, 1, 0.10 }, swatch = { 1, 1, 1, 0.34 }, chip = { 1, 1, 1, 0.08 } },
}
local toneFollowers = {}
local function BrownTone()
    local tone = FN.db.tone
    if tone == "brown" then return true end
    if tone == "dark" then return false end
    return Stock()
end
-- Paints `texture` with one of the theme's colors, now and whenever the theme changes.
local function ToneTexture(texture, part)
    local function Paint()
        local c = TONE[BrownTone() and "brown" or "dark"][part]
        texture:SetColorTexture(c[1], c[2], c[3], c[4])
    end
    toneFollowers[#toneFollowers + 1] = Paint
    Paint()
    return texture
end
local function ToneLine(parent)
    return ToneTexture(parent:CreateTexture(nil, "ARTWORK"), "line")
end

local function Label(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    local skin = Skin()
    if skin and skin.Font then skin.Font(fs) end
    if text then fs:SetText(text) end
    return fs
end

-- A dark see-through pane with a faint edge.
local function Pane(parent)
    local pane = Stock() and TryTemplate("Frame", nil, parent, "InsetFrameTemplate")
    if not pane then
        pane = CreateFrame("Frame", nil, parent)
        local bg = Fill(pane, "BACKGROUND", 0, 0, 0, 0.30)
        bg:SetAllPoints()
        Outline(pane, pane, 1, 1, 1, 0.08)
    end
    -- A wash over the pane when the theme differs from the interface's own colors.
    local wash = pane:CreateTexture(nil, "BACKGROUND", nil, 7)
    wash:SetAllPoints()
    local function Paint()
        local brown = BrownTone()
        wash:SetShown(brown ~= Stock())
        if brown then wash:SetColorTexture(0.20, 0.13, 0.07, 0.40) else wash:SetColorTexture(0, 0, 0, 0.45) end
    end
    toneFollowers[#toneFollowers + 1] = Paint
    Paint()
    return pane
end

-- A mouse-wheel scroll area with a slim position marker. Put content in `.child`,
-- size the child, then call :Update().
local function Scroller(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf.child = child
    -- The marker is a slim bar inside a wider, invisible grip that can be dragged.
    local grip = CreateFrame("Button", nil, sf)
    grip:SetWidth(11)
    grip:SetFrameLevel(sf:GetFrameLevel() + 60) -- (over a settings section's pinned header)
    local thumb = Fill(grip, "OVERLAY", BRONZE[1], BRONZE[2], BRONZE[3], 0.8)
    thumb:SetWidth(3)
    thumb:SetPoint("TOP", grip, "TOP", 0, 0)
    thumb:SetPoint("BOTTOM", grip, "BOTTOM", 0, 0)
    local function Lit(on) -- brighter while hovered or dragged
        local c = on and GOLD or BRONZE
        thumb:SetColorTexture(c[1], c[2], c[3], on and 1 or 0.8)
    end

    -- Stock look: the game's own scroll bar, the one the quest log uses, in place of the slim
    -- marker (when this client has it).
    local bar = Stock() and TryTemplate("EventFrame", nil, sf, "MinimalScrollBar")
    if bar and not (bar.SetScrollPercentage and bar.SetVisibleExtentPercentage and bar.RegisterCallback) then
        bar:Hide()
        bar = nil
    end
    local syncingBar = false
    if bar then
        bar:SetFrameLevel(sf:GetFrameLevel() + 60)
        if bar.SetHideIfUnscrollable then bar:SetHideIfUnscrollable(true) end
        bar:RegisterCallback("OnScroll", function(_, pct)
            if syncingBar or not sf.range or sf.range <= 0 then return end
            sf:SetVerticalScroll(math.max(0, math.min(sf.range, pct * sf.range)))
            sf:Update()
        end, sf)
        sf.stockBar = bar
    end

    -- Rows fade out as they scroll up under the top edge, instead of being cut off there.
    -- Frames marked .noFade (large backgrounds) stay as they are.
    function sf:FadeTop()
        local zone, top = self.fadeTop, self:GetTop()
        if not zone or not top then return end
        for _, f in ipairs({ child:GetChildren() }) do
            if not f.noFade and f:IsShown() then
                local b, t = f:GetBottom(), f:GetTop()
                local a = 1
                if b and t and t > top then
                    local shown = top - b
                    a = shown <= 0 and 0 or math.min(1, shown / math.min(t - b, zone))
                end
                f:SetAlpha(a)
            end
        end
    end

    function sf:Update()
        local view, content = self:GetHeight(), child:GetHeight()
        local range = math.max(0, content - view)
        local offset = math.min(self:GetVerticalScroll(), range)
        self:SetVerticalScroll(offset)
        self:FadeTop()
        if bar then
            grip:Hide()
            self.range = range
            local shown = range > 0 and view > 0
            bar:SetShown(shown)
            if not shown then return end
            -- In the strip outside the list's border, where the quest log's scroll bar sits.
            bar:ClearAllPoints()
            local x = (self.thumbOffset or 0) - 6 - (self.rightBleed or 0)
            -- In the quest log's place: line up with the quest log's own (hidden) scroll bar.
            local qb = self.thumbOffset and self.thumbOffset > 20 and QuestScrollFrame and QuestScrollFrame.ScrollBar
            local qbLeft, right = qb and qb.GetLeft and qb:GetLeft(), self:GetRight()
            local top, bottom = -2, 2
            if qbLeft and right then
                -- The same column and the same full length as the quest log's bar.
                local k = qb:GetEffectiveScale() / self:GetEffectiveScale()
                x = qbLeft * k - right
                local qTop, qBottom, sTop, sBottom = qb:GetTop(), qb:GetBottom(), self:GetTop(), self:GetBottom()
                if qTop and qBottom and sTop and sBottom then
                    top, bottom = qTop * k - sTop, qBottom * k - sBottom
                end
            end
            bar:SetPoint("TOPLEFT", self, "TOPRIGHT", x, top)
            bar:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", x, bottom)
            syncingBar = true
            bar:SetVisibleExtentPercentage(view / content)
            if bar.SetPanExtentPercentage then bar:SetPanExtentPercentage((ROW_HEIGHT * 2) / range) end
            bar:SetScrollPercentage(offset / range)
            syncingBar = false
            return
        end
        if range <= 0 or view <= 0 then
            grip:Hide()
            return
        end
        local size = math.max(20, view * view / content)
        self.range, self.travel = range, view - size
        grip:SetHeight(size)
        grip:ClearAllPoints()
        -- thumbOffset pushes the marker out past the pane's border, like the quest log's scroll bar.
        grip:SetPoint("TOPRIGHT", self, "TOPRIGHT", (self.thumbOffset or 0) + 4 - (self.rightBleed or 0),
            -(view - size) * (offset / range))
        grip:Show()
    end
    -- Dragging: the marker follows the cursor, and the list follows the marker.
    local function CursorY() return select(2, GetCursorPosition()) / grip:GetEffectiveScale() end
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.fromY, self.fromScroll = CursorY(), sf:GetVerticalScroll()
        Lit(true)
        self:SetScript("OnUpdate", function()
            local travel = sf.travel or 0
            if travel <= 0 then return end
            local scroll = self.fromScroll + (self.fromY - CursorY()) * (sf.range / travel)
            sf:SetVerticalScroll(math.max(0, math.min(sf.range, scroll)))
            sf:Update()
        end)
    end)
    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        Lit(self:IsMouseOver())
    end)
    grip:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil); Lit(false) end)
    grip:SetScript("OnEnter", function() Lit(true) end)
    grip:SetScript("OnLeave", function(self) if not self:GetScript("OnUpdate") then Lit(false) end end)

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * ROW_HEIGHT * 2))
        self:Update()
    end)
    sf:SetScript("OnSizeChanged", function(self) self:Update() end)
    return sf
end

-- A rounded-square texture covering `owner`.
local function Rounded(owner, layer, file)
    local t = owner:CreateTexture(nil, layer)
    t:SetTexture(FN.MEDIA .. file)
    t:SetAllPoints()
    -- Keep the corners round at any size (stretches only the middle).
    if t.SetTextureSliceMargins then t:SetTextureSliceMargins(10, 10, 10, 10) end
    return t
end

-- A card-style button: faint fill and edge, bronze when selected.
local function Card(parent, text, width, height, onClick)
    if Stock() then
        local stock = StockButton(parent, text, width, height, onClick)
        if stock then return stock end
    end
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    -- Rounded, like the tabs and the switches, so every control shares one shape.
    b.bg = Rounded(b, "BACKGROUND", "round_fill"); b.bg:SetVertexColor(0, 0, 0, 0.45)
    b.edge = Rounded(b, "BORDER", "round_edge"); b.edge:SetVertexColor(1, 1, 1, 0.22)
    local hl = Rounded(b, "HIGHLIGHT", "round_fill")
    hl:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.18)
    b.text = Label(b, "GameFontNormalSmall", text)
    b.text:SetPoint("CENTER")
    b:SetScript("OnClick", onClick)
    KeepChatFocus(b)
    function b:SetSelected(selected)
        if selected then
            self.bg:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.30)
            self.edge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
        else
            self.bg:SetVertexColor(0, 0, 0, 0.45)
            self.edge:SetVertexColor(1, 1, 1, 0.22)
        end
    end
    return b
end

-- An icon-only tab for the side panel's top row: gold edge when it is the open page.
local function IconTab(parent, icon, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(46, 44)
    -- Lit the way the game lights its own tab and spell buttons: a dark edge at rest, a soft
    -- white glow inside the edge under the mouse, a bright gold edge and glow when open.
    b.bg = Rounded(b, "BACKGROUND", "round_fill")
    b.bg:SetVertexColor(0, 0, 0, 0.6)
    b.edge = Rounded(b, "BORDER", "round_edge")
    local glowFile = FN.MEDIA .. "tab_glow"
    b.glow = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.glow:SetAllPoints()
    b.glow:SetTexture(glowFile)
    b.glow:SetBlendMode("ADD")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(glowFile)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(1, 1, 1, 0.55)
    -- The icon fills the whole tab, cropped to its rounded shape (the icon's own border
    -- trimmed off, and a little more top and bottom to fit the tab's width-to-height).
    b.pic = b:CreateTexture(nil, "ARTWORK")
    b.pic:SetPoint("TOPLEFT", 1, -1)
    b.pic:SetPoint("BOTTOMRIGHT", -1, 1)
    b.pic:SetTexture(icon)
    b.pic:SetTexCoord(0.08, 0.92, 0.10, 0.90)
    local mask = b:CreateMaskTexture()
    mask:SetAllPoints(b)
    mask:SetTexture(FN.MEDIA .. "tab_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.pic:AddMaskTexture(mask)
    -- The edge goes over the picture.
    b.edge:SetDrawLayer("OVERLAY", 1)
    -- The character's skill, in the middle of the picture: the skill bar's font (Friz
    -- Quadrata in the stock look, the number font, Expressway under EllesmereUI), with a soft
    -- shadow rather than an outline. Gold on the open tab, soft white on the others.
    b.level = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    do
        local face = Stock() and GameFontHighlightSmall:GetFont()
            or (_G.Number12FontOutline and _G.Number12FontOutline:GetFont()) or b.level:GetFont()
        local _, size = b.level:GetFont()
        if face and size then b.level:SetFont(face, size + 1, "") end
    end
    b.level:SetDrawLayer("OVERLAY", 2)
    b.level:SetPoint("BOTTOMRIGHT", -4, 3)
    b.level:SetShadowOffset(1, -1)
    b.level:SetShadowColor(0, 0, 0, 1)
    b.level:SetText(" ")
    -- A dark fade up from the bottom edge of the picture, so the number reads over any icon.
    local fade = b:CreateTexture(nil, "ARTWORK", nil, 2)
    fade:SetColorTexture(1, 1, 1, 1)
    fade:SetPoint("BOTTOMLEFT", b.pic, "BOTTOMLEFT")
    fade:SetPoint("BOTTOMRIGHT", b.pic, "BOTTOMRIGHT")
    fade:SetHeight(18)
    if fade.SetGradient and CreateColor then
        fade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0))
    else
        fade:SetColorTexture(0, 0, 0, 0.3)
    end
    fade:AddMaskTexture(mask)
    b:SetScript("OnClick", onClick) -- no tooltip: the page title says which tab is open
    KeepChatFocus(b)
    function b:SetSelected(isSelected)
        self.isSelected = isSelected
        self.glow:SetShown(isSelected)
        if self.dimmed then self.level:SetTextColor(0.6, 0.6, 0.6)
        elseif isSelected then self.level:SetTextColor(1, 0.86, 0.45)
        else self.level:SetTextColor(0.9, 0.88, 0.84) end
        if isSelected then
            self.edge:SetVertexColor(1, 0.86, 0.25, 1)
            self.glow:SetVertexColor(1, 0.80, 0.20, 0.85)
        elseif self.dimmed then -- not learned: a dark, receding edge
            self.edge:SetVertexColor(0, 0, 0, 0.9)
        else
            self.edge:SetVertexColor(0.30, 0.27, 0.22, 1)
        end
    end
    -- A profession the character does not have: greyed and darkened.
    function b:SetDimmed(dimmed)
        self.dimmed = dimmed
        self:SetSelected(self.isSelected or false)
        self.pic:SetDesaturated(dimmed)
        self.pic:SetVertexColor(dimmed and 0.45 or 1, dimmed and 0.45 or 1, dimmed and 0.45 or 1)
    end
    return b
end

-- The Settings tab in the side panel's tab row: a plain flat cog, no frame, kept in from the
-- right edge so a map close button that sits there (some map addons move it) never covers it.
local GEAR_SIZE = 26
local function GearTab(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(GEAR_SIZE, GEAR_SIZE)
    -- The quest log's own flat cog when this client has it, else the game's gear icon.
    b.pic = b:CreateTexture(nil, "ARTWORK")
    b.pic:SetPoint("CENTER")
    local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("questlog-icon-setting")
    if atlas then
        -- Closed: the cog's own art. Open: a flat gold in the cog's shape (the cog used as a
        -- mask), since tinting the cog's grey art gold only gives a dull orange.
        b.pic:SetAtlas("questlog-icon-setting")
        b.pic:SetSize(GEAR_SIZE, GEAR_SIZE)
        b.lit = b:CreateTexture(nil, "ARTWORK", nil, 1)
        b.lit:SetAllPoints(b.pic)
        b.lit:SetColorTexture(0.88, 0.72, 0.40, 1) -- the open tab's edge, as it shows
        local cog = b:CreateMaskTexture()
        cog:SetAllPoints(b.pic)
        cog:SetAtlas("questlog-icon-setting")
        b.lit:AddMaskTexture(cog)
        b.flat = true
    else
        b.pic:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
        b.pic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.pic:SetSize(GEAR_SIZE - 2, GEAR_SIZE - 2)
    end
    -- Brighter under the mouse, gold while Settings is open.
    local function Paint()
        if b.flat then
            b.lit:SetShown(b.isSelected)
            b.pic:SetShown(not b.isSelected)
            local k = b:IsMouseOver() and 1 or 0.75
            b.pic:SetVertexColor(k, k, k)
        else
            local k = (b.isSelected or b:IsMouseOver()) and 1 or 0.8
            b.pic:SetVertexColor(k, k, k)
        end
    end
    b:SetScript("OnEnter", Paint)
    b:SetScript("OnLeave", Paint)
    b:SetScript("OnClick", onClick)
    KeepChatFocus(b)
    function b:SetSelected(isSelected)
        self.isSelected = isSelected
        Paint()
    end
    function b:SetDimmed() end
    b:SetSelected(false)
    return b
end

-- A two-way switch: one button reading "left | right" with the active half lit.
-- :SetRight(true or false) lights a half; a click is left to `onClick` (which flips it).
local function PairToggle(parent, leftText, rightText, onClick)
    -- Drawn the same way in both looks: a red stock button cannot light one half.
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(68, 22)
    local bg = Rounded(b, "BACKGROUND", "round_fill")
    bg:SetVertexColor(0, 0, 0, 0.45)
    b.half = b:CreateTexture(nil, "BORDER") -- the lit half
    b.half:SetTexture(FN.MEDIA .. "round_fill")
    if b.half.SetTextureSliceMargins then b.half:SetTextureSliceMargins(10, 10, 10, 10) end
    b.half:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], Stock() and 0.30 or 0.65) -- plain gold is loud
    -- Grey edge around the whole button, gold edge around the lit half only.
    local edge = Rounded(b, "ARTWORK", "round_edge")
    edge:SetVertexColor(1, 1, 1, 0.25)
    local halfEdge = b:CreateTexture(nil, "OVERLAY")
    halfEdge:SetTexture(FN.MEDIA .. "round_edge")
    if halfEdge.SetTextureSliceMargins then halfEdge:SetTextureSliceMargins(10, 10, 10, 10) end
    halfEdge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
    halfEdge:SetAllPoints(b.half)
    local hl = Rounded(b, "HIGHLIGHT", "round_fill")
    hl:SetVertexColor(1, 1, 1, 0.08)
    -- Each side is as wide as its own label plus the same padding, so both
    -- labels sit centered in their side.
    local PAD = 8
    b.left = Label(b, "GameFontHighlightSmall", leftText)
    b.right = Label(b, "GameFontHighlightSmall", rightText)
    local leftWidth = math.ceil(b.left:GetStringWidth()) + PAD * 2
    local rightWidth = math.ceil(b.right:GetStringWidth()) + PAD * 2
    b:SetWidth(leftWidth + rightWidth)
    b.left:SetPoint("CENTER", b, "LEFT", leftWidth / 2, 0)
    b.right:SetPoint("CENTER", b, "RIGHT", -rightWidth / 2, 0)
    local divider = Fill(b, "ARTWORK", 1, 1, 1, 0.25)
    divider:SetSize(1, 12)
    divider:SetPoint("CENTER", b, "LEFT", leftWidth, 0)
    b:SetScript("OnClick", onClick)
    KeepChatFocus(b)

    function b:SetRight(isRight)
        self.half:ClearAllPoints()
        if isRight then
            self.half:SetPoint("TOPLEFT", self, "TOPLEFT", leftWidth, 0)
            self.half:SetPoint("BOTTOMRIGHT")
        else
            self.half:SetPoint("TOPLEFT")
            self.half:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", leftWidth, 0)
        end
        local lit, dim = isRight and self.right or self.left, isRight and self.left or self.right
        lit:SetTextColor(1, 1, 1)
        dim:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    end
    return b
end

-- The sort control: "Lvl | A-Z". :SetMode("level" or "name") lights a half.
local function SortToggle(parent, onClick)
    local b = PairToggle(parent, "Lvl", "A-Z", onClick)
    function b:SetMode(mode) self:SetRight(mode == "name") end
    return b
end

-- Short lines fading out on either side of a fold's label ("--- Label ---"), like the ones
-- beside "Hide trainers".
local function SideLines(owner, fs)
    local function Line(flip)
        local t = owner:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetSize(26, 1)
        if t.SetGradient and CreateColor then
            local a, b = CreateColor(0.6, 0.6, 0.6, 0), CreateColor(0.6, 0.6, 0.6, 0.8)
            if flip then t:SetGradient("HORIZONTAL", b, a) else t:SetGradient("HORIZONTAL", a, b) end
        else
            t:SetVertexColor(0.6, 0.6, 0.6, 0.5)
        end
        return t
    end
    local l, r = Line(false), Line(true)
    l:SetPoint("RIGHT", fs, "LEFT", -12, 0)
    r:SetPoint("LEFT", fs, "RIGHT", 12, 0)
    return l, r
end

-- The same switch with any number of parts: "World map | Minimap | Overworld".
-- `onPick(i)` gets the part clicked; :SetPick(i) lights a part.
local function MultiToggle(parent, labels, onPick)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(22)
    local bg = Rounded(b, "BACKGROUND", "round_fill")
    bg:SetVertexColor(0, 0, 0, 0.45)
    b.half = b:CreateTexture(nil, "BORDER") -- the lit part
    b.half:SetTexture(FN.MEDIA .. "round_fill")
    if b.half.SetTextureSliceMargins then b.half:SetTextureSliceMargins(10, 10, 10, 10) end
    b.half:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], Stock() and 0.30 or 0.65)
    local edge = Rounded(b, "ARTWORK", "round_edge")
    edge:SetVertexColor(1, 1, 1, 0.25)
    local halfEdge = b:CreateTexture(nil, "OVERLAY")
    halfEdge:SetTexture(FN.MEDIA .. "round_edge")
    if halfEdge.SetTextureSliceMargins then halfEdge:SetTextureSliceMargins(10, 10, 10, 10) end
    halfEdge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
    halfEdge:SetAllPoints(b.half)
    local hl = Rounded(b, "HIGHLIGHT", "round_fill")
    hl:SetVertexColor(1, 1, 1, 0.08)
    local PAD = 8
    local parts, x = {}, 0
    for i, text in ipairs(labels) do
        local fs = Label(b, "GameFontHighlightSmall", text)
        local w = math.ceil(fs:GetStringWidth()) + PAD * 2
        fs:SetPoint("CENTER", b, "LEFT", x + w / 2, 0)
        if i > 1 then
            local divider = Fill(b, "ARTWORK", 1, 1, 1, 0.25)
            divider:SetSize(1, 12)
            divider:SetPoint("CENTER", b, "LEFT", x, 0)
        end
        parts[i] = { fs = fs, x = x, w = w }
        x = x + w
    end
    b:SetWidth(x)
    b:SetScript("OnClick", function(self)
        local cx = GetCursorPosition() / self:GetEffectiveScale() - self:GetLeft()
        for i, p in ipairs(parts) do
            if cx < p.x + p.w or i == #parts then onPick(i); return end
        end
    end)
    KeepChatFocus(b)
    function b:SetPick(n)
        local p = parts[n] or parts[1]
        self.half:ClearAllPoints()
        self.half:SetPoint("TOPLEFT", self, "TOPLEFT", p.x, 0)
        self.half:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", p.x + p.w, 0)
        for i, q in ipairs(parts) do
            if i == n then q.fs:SetTextColor(1, 1, 1) else q.fs:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end
        end
    end
    b:SetPick(1)
    return b
end

-- A tick box drawn on `owner`; returns the box texture and the tick texture.
local function TickBox(owner)
    local box
    local stock = Stock()
    if stock then
        box = owner:CreateTexture(nil, "ARTWORK")
        box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        box:SetSize(22, 22)
    else
        box = Fill(owner, "ARTWORK", 0, 0, 0, 0.75)
        box:SetSize(14, 14)
        Outline(owner, box, 1, 1, 1, 0.38)
    end
    local mark = owner:CreateTexture(nil, "OVERLAY")
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    mark:SetSize(stock and 22 or 20, stock and 22 or 20)
    mark:SetPoint("CENTER", box, "CENTER")
    return box, mark
end

local syncers = {} -- functions that copy saved settings into the widgets

local function Check(parent, text, get, set)
    local c = CreateFrame("Button", nil, parent)
    local box, mark = TickBox(c)
    box:SetPoint("LEFT")
    local label = Label(c, nil, text)
    label:SetPoint("LEFT", box, "RIGHT", 7, 0)
    c:SetSize(label:GetStringWidth() + 24, 20)
    function c:SetLabel(newText) -- for a tick box whose wording follows another control
        label:SetText(newText)
        self:SetWidth(label:GetStringWidth() + 24)
    end
    c:SetScript("OnEnter", function() label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
    -- `c.restColor` ({ r, g, b }) gives the label a color of its own when not hovered.
    local function Rest()
        local rc = c.restColor
        if rc then label:SetTextColor(rc[1], rc[2], rc[3]) else label:SetTextColor(1, 1, 1) end
    end
    c.Rest = Rest
    c:SetScript("OnLeave", Rest)
    local function Sync() mark:SetShown(get() and true or false) end
    c:SetScript("OnClick", function()
        set(not get())
        Sync()
    end)
    syncers[#syncers + 1] = Sync
    return c
end

-- Things that follow the settings sections' width (wider in the docked panel, where the
-- sections stack in one column): each is a function(width) taking the section width.
local sectionWidthFollowers = {}

-- `onRelease`: apply the value when the mouse lets go rather than while dragging.
local function Slider(parent, text, minValue, maxValue, step, fmt, get, set, onRelease)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(234, 34) -- fits inside a settings section's border; see below
    -- As wide as the inside of a section (16 less than the section: 8 each side).
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function(width) holder:SetWidth(width - 16) end
    local label = Label(holder, nil, text)
    label:SetPoint("TOPLEFT")
    holder.label = label
    local value = Label(holder)
    value:SetPoint("TOPRIGHT")
    value:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    -- Stock look: the game's slider groove and knob. Otherwise a flat track and bronze thumb.
    local s = Stock() and BackdropTemplateMixin and TryTemplate("Slider", nil, holder, "BackdropTemplate")
    if s and s.SetBackdrop then
        s:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 },
        })
        s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    else
        s = CreateFrame("Slider", nil, holder)
        local track = Fill(s, "BACKGROUND", 0, 0, 0, 0.55)
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
        track:SetHeight(4)
        Outline(s, track, 1, 1, 1, 0.18)
        local thumb = s:CreateTexture(nil, "OVERLAY")
        thumb:SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3])
        thumb:SetSize(8, 14)
        s:SetThumbTexture(thumb)
        -- The thumb lightens a touch under the mouse, and goes near white while held.
        local hovered, held = false, false
        local function Paint()
            local w = held and 0.7 or hovered and 0.2 or 0
            thumb:SetColorTexture(BRONZE[1] + (1 - BRONZE[1]) * w, BRONZE[2] + (1 - BRONZE[2]) * w,
                BRONZE[3] + (1 - BRONZE[3]) * w)
        end
        s:HookScript("OnEnter", function() hovered = true; Paint() end)
        s:HookScript("OnLeave", function() hovered = false; Paint() end)
        s:HookScript("OnMouseDown", function() held = true; Paint() end)
        s:HookScript("OnMouseUp", function() held = false; Paint() end)
        s:HookScript("OnHide", function() hovered, held = false, false; Paint() end)
    end
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("BOTTOMLEFT")
    s:SetPoint("BOTTOMRIGHT")
    s:SetHeight(16)
    s:EnableMouse(true)
    s:SetMinMaxValues(minValue, maxValue)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

    local function Snapped(v) return floor(v / step + 0.5) * step end
    -- `fmt` is a format string, or a function turning the value into its text.
    local function Text(v) return type(fmt) == "function" and fmt(v) or fmt:format(v) end
    local syncing = false
    s:SetScript("OnValueChanged", function(_, v)
        v = Snapped(v)
        value:SetText(Text(v))
        if not syncing and not onRelease and v ~= get() then set(v) end
    end)
    if onRelease then
        s:SetScript("OnMouseUp", function(self)
            local v = Snapped(self:GetValue())
            if v ~= get() then set(v) end
        end)
    end
    holder.slider, holder.value = s, value -- for callers that lay it out their own way
    holder.Sync = function()
        syncing = true
        s:SetValue(get())
        value:SetText(Text(get()))
        syncing = false
    end
    syncers[#syncers + 1] = holder.Sync
    return holder
end

-- Color picker extras: one hex box (with opacity) and Copy / Paste, in the game's picker.

local function ColorToHex(c)
    local function Byte(v) return floor(v * 255 + 0.5) end
    local hex = ("%02X%02X%02X"):format(Byte(c[1]), Byte(c[2]), Byte(c[3]))
    local alpha = c[4] or 1
    if alpha < 0.995 then hex = hex .. ("%02X"):format(Byte(alpha)) end -- RRGGBBAA when see-through
    return hex
end

-- "RRGGBB" or "RRGGBBAA", with or without a leading #. Returns r, g, b, a (a is nil for six digits).
local function HexToColor(text)
    text = text:gsub("^%s*#?", ""):gsub("%s+$", "")
    if not text:match("^%x+$") or (#text ~= 6 and #text ~= 8) then return nil end
    local function Part(i) return tonumber(text:sub(i, i + 1), 16) / 255 end
    return Part(1), Part(3), Part(5), #text == 8 and Part(7) or nil
end

-- Moves the game's picker to a color.
local function SetPicker(r, g, b, a)
    local wheel = ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker
    if wheel and wheel.SetColorRGB then
        wheel:SetColorRGB(r, g, b)
        if wheel.SetColorAlpha then wheel:SetColorAlpha(a) end
    elseif ColorPickerFrame.SetColorRGB then
        ColorPickerFrame:SetColorRGB(r, g, b)
        if OpacitySliderFrame then OpacitySliderFrame:SetValue(1 - a) end
    end
end

local pickerExtras, copiedColor

local function PickerExtras()
    if pickerExtras then return pickerExtras end
    -- The game's picker has its own six-digit hex box. Ours takes its place in the window: one
    -- box, wide enough for the opacity too (RRGGBBAA), following the picker as it moves and
    -- moving the picker as a valid color is typed. Copy and Paste sit above it.
    local stockHex = ColorPickerFrame.Content and ColorPickerFrame.Content.HexBox
    local f = CreateFrame("Frame", nil, ColorPickerFrame)
    local hash = Label(f, nil, "#")
    local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetMaxLetters(9)
    box:SetScript("OnTextChanged", function(self, typed)
        if not typed then return end
        local r, g, b, a = HexToColor(self:GetText())
        if r then f.set(r, g, b, a) end
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        f.sync()
    end)
    -- Clicking in selects the whole value, ready for Ctrl+C, or to type or Ctrl+V over.
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f.sync()
    end)
    f.box = box

    local copy = Card(f, "Copy", 58, 22, function()
        local c = f.color
        copiedColor = { c[1], c[2], c[3], c[4] or 1 }
    end)
    local paste = Card(f, "Paste", 58, 22, function()
        if copiedColor then f.set(copiedColor[1], copiedColor[2], copiedColor[3], copiedColor[4]) end
    end)
    -- Addons cannot reach the system clipboard: these carry a color between pickers here.
    local function Tip(button, title, text)
        button:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title)
            GameTooltip:AddLine(text, 1, 1, 1, true)
            GameTooltip:AddLine("For the system clipboard, click the hex box and use Ctrl+C / Ctrl+V.", 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    Tip(copy, "Copy color", "Remembers this color, to paste into another color in Forever Nodes.")
    Tip(paste, "Paste color", "Uses the color last copied with Copy.")
    -- Puts back the color's own default (only for colors that have one: f.default).
    local reset = Card(f, "Default", 58, 22, function()
        local c = f.default and f.default()
        if c then f.set(c[1], c[2], c[3], c[4] or 1) end
    end)
    reset:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Default color")
        GameTooltip:AddLine("Puts back this color's own default.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    reset:HookScript("OnLeave", function() GameTooltip:Hide() end)
    f.resetButton = reset

    if stockHex then
        -- Inside the window, where the game's box was. That one steps aside only while our
        -- box is up, so the picker is unchanged when something else opens it.
        f:SetAllPoints(ColorPickerFrame)
        f:SetFrameLevel(stockHex:GetFrameLevel() + 5)
        local function GameBox(on)
            stockHex:SetAlpha(on and 1 or 0)
            stockHex:EnableMouse(on)
            if stockHex.EnableKeyboard then stockHex:EnableKeyboard(on) end
        end
        f:SetScript("OnShow", function() GameBox(false) end)
        f:SetScript("OnHide", function() GameBox(true) end)
        GameBox(false)
        box:SetSize(78, 20)
        box:SetFontObject(GameFontHighlightSmall) -- all eight digits fit
        box:SetPoint("RIGHT", stockHex, "RIGHT", 0, 0)
        hash:SetPoint("RIGHT", box, "LEFT", -5, 0)
        -- Under the picker's color square: Copy | Paste side by side, Default under them,
        -- just over the hex box (a third row would reach up over the square).
        -- (narrow enough to keep clear of the opacity slider at their left)
        reset:SetSize(94, 22)
        reset:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, 8)
        paste:SetSize(45, 22)
        paste:SetPoint("BOTTOMRIGHT", reset, "TOPRIGHT", 0, 4)
        copy:SetSize(45, 22)
        copy:SetPoint("RIGHT", paste, "LEFT", -4, 0)
    else
        -- An older picker with no hex box of its own: a strip under the window.
        f:SetSize(316, 36)
        f:SetPoint("TOP", ColorPickerFrame, "BOTTOM", 0, -2)
        f:EnableMouse(true)
        local bg = Fill(f, "BACKGROUND", 0.07, 0.055, 0.04, 0.96)
        bg:SetAllPoints()
        Outline(f, f, BRONZE[1] * 0.6, BRONZE[2] * 0.6, BRONZE[3] * 0.6, 1)
        hash:SetPoint("LEFT", 12, 0)
        box:SetSize(76, 20)
        box:SetPoint("LEFT", hash, "RIGHT", 9, 0)
        copy:SetPoint("LEFT", box, "RIGHT", 12, 0)
        paste:SetPoint("LEFT", copy, "RIGHT", 4, 0)
        reset:SetPoint("LEFT", paste, "RIGHT", 4, 0)
    end

    ColorPickerFrame:HookScript("OnHide", function() f:Hide() end)
    pickerExtras = f
    return f
end

-- Each opening of the picker is one edit. Opening it for another color while it is still up
-- ends the one before (its color stays as it was picked so far, already saved as it changed):
-- only the newest edit's callbacks may change a color, so the picker setting itself up for the
-- next color can't paint that color onto the one before, or the one before onto the next.
local pickEdit = 0
local function PickColor(color, onChange, getDefault)
    pickEdit = pickEdit + 1
    local edit, ready = pickEdit, false
    local function Current() return edit == pickEdit and ready end
    -- color = { r, g, b, opacity }; opacity is 1 when it was never set.
    local r0, g0, b0, a0 = color[1], color[2], color[3], color[4] or 1
    local extras = PickerExtras()
    extras.color = color
    extras.default = getDefault
    extras.resetButton:SetShown(getDefault ~= nil)
    function extras.sync()
        if not extras.box:HasFocus() then extras.box:SetText(ColorToHex(color)) end
    end
    function extras.set(r, g, b, a) -- from the hex box or Paste; six-digit hex keeps the opacity
        if not Current() then return end
        a = a or color[4] or 1
        SetPicker(r, g, b, a)
        color[1], color[2], color[3], color[4] = r, g, b, a
        onChange()
        extras.sync()
    end
    local modern = ColorPickerFrame.SetupColorPickerAndShow ~= nil
    local function Apply()
        if not Current() then return end
        color[1], color[2], color[3] = ColorPickerFrame:GetColorRGB()
        if ColorPickerFrame.GetColorAlpha then
            color[4] = ColorPickerFrame:GetColorAlpha()
        elseif OpacitySliderFrame then
            color[4] = 1 - OpacitySliderFrame:GetValue() -- the old picker's slider runs the other way
        end
        onChange()
        extras.sync()
    end
    local function Cancel()
        if edit ~= pickEdit then return end -- (an edit already replaced by a newer one is kept)
        color[1], color[2], color[3], color[4] = r0, g0, b0, a0
        onChange()
    end
    if modern then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r0, g = g0, b = b0, hasOpacity = true, opacity = a0,
            swatchFunc = Apply, opacityFunc = Apply, cancelFunc = Cancel,
        })
    else
        ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = Apply, Apply, Cancel
        ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = true, 1 - a0
        ColorPickerFrame:SetColorRGB(r0, g0, b0)
        ColorPickerFrame:Show()
    end
    -- Set up: from here on the picker's changes are this color's. Whatever it reported while
    -- being set up is undone, so this color starts exactly as it was.
    ready = true
    if color[1] ~= r0 or color[2] ~= g0 or color[3] ~= b0 then
        color[1], color[2], color[3], color[4] = r0, g0, b0, a0
        onChange()
    end
    -- Our window sits above a maximized map; keep the picker above our window.
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ColorPickerFrame:Raise()
    extras:Show()
    extras.sync()
end

-- `getColor` returns the saved { r, g, b } table the swatch edits; `getDefault` (optional) its
-- default, for the picker's Default button.
local function Swatch(parent, text, getColor, getDefault)
    local b = CreateFrame("Button", nil, parent)
    local chip = Fill(b, "ARTWORK", 1, 1, 1)
    chip:SetSize(26, 14)
    chip:SetPoint("LEFT")
    -- Edged like the settings' dividing lines, a little lighter: a color that can be clicked.
    for _, edge in ipairs(Outline(b, chip, 1, 1, 1, 1)) do ToneTexture(edge, "swatch") end
    local label = Label(b, nil, text)
    label:SetPoint("LEFT", chip, "RIGHT", 7, 0)
    b:SetSize(label:GetStringWidth() + 36, 20)
    -- Hover: a thin, soft gold edge fades in around the color, to show it can be clicked.
    local glow = CreateFrame("Frame", nil, b)
    glow:SetPoint("TOPLEFT", chip, "TOPLEFT", -1, 1)
    glow:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", 1, -1)
    -- Three faint rings, fading outward, so it reads as a glow and not a frame.
    Outline(glow, glow, GOLD[1], GOLD[2], GOLD[3], 0.38)
    for i, alpha in ipairs({ 0.16, 0.06 }) do
        local halo = CreateFrame("Frame", nil, glow)
        halo:SetPoint("TOPLEFT", -i, i)
        halo:SetPoint("BOTTOMRIGHT", i, -i)
        Outline(halo, halo, GOLD[1], GOLD[2], GOLD[3], alpha)
    end
    glow:SetAlpha(0)
    -- The fade runs only while it moves, so idle swatches cost nothing per frame.
    local target = 0
    local function Fade(self, elapsed)
        local a = self:GetAlpha()
        local step = elapsed / 0.12
        a = target > a and math.min(target, a + step) or math.max(target, a - step)
        self:SetAlpha(a)
        if a == target then self:SetScript("OnUpdate", nil) end
    end
    local function FadeTo(to)
        target = to
        glow:SetScript("OnUpdate", Fade)
    end
    b:SetScript("OnEnter", function()
        label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        FadeTo(1)
    end)
    b:SetScript("OnLeave", function()
        label:SetTextColor(1, 1, 1)
        FadeTo(0)
    end)
    b:HookScript("OnHide", function() target = 0; glow:SetScript("OnUpdate", nil); glow:SetAlpha(0) end)
    local function Sync()
        local c = getColor()
        chip:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
    b:SetScript("OnClick", function()
        PickColor(getColor(), function()
            Sync()
            FN:Restyle()
            if FN.ColorsChanged then FN:ColorsChanged() end -- text shown in a profession's color
        end, getDefault)
    end)
    syncers[#syncers + 1] = Sync
    b.Sync = Sync
    return b
end

-- Nodes page -----------------------------------------------------------------

local frame
local nodesPage = { rows = {}, tabs = {} }

-- Skill-up colors as the game shows them (Forever's bands, see FN:DifficultyColor):
-- r, g, b, and whether the row gets a tinted background (orange, yellow, green only).
local function Difficulty(skill, need)
    if need <= 0 then return MUTED[1], MUTED[2], MUTED[3], false end
    local r, g, b, name = FN:DifficultyColor(skill, need)
    return r, g, b, (name == "orange" or name == "yellow" or name == "green")
end

local LIST_BLEED = 9 -- how far left of the page the pane's border is: row stripes run out to it

local function CreateRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(COL_WIDTH, ROW_HEIGHT)
    -- Rows are divided by a thin line under each, and light up whole on hover;
    -- both run from the pane's border to the row's right edge.
    r.line = Fill(r, "BACKGROUND", 1, 1, 1, 0.07)
    r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT", 0, 0)
    r.line:SetPoint("BOTTOMRIGHT")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 1, 1, 0.08)
    hl:SetPoint("TOPLEFT", 0, 0)
    hl:SetPoint("BOTTOMRIGHT")

    -- Rank cutoff: a slightly stronger line along the row's top edge, where a rank ends.
    -- It runs edge to edge of the pane (past the row on both sides) to read as a tier break.
    -- Drawn as an engraved groove: a dark line, a faint light edge under it, and a soft shadow
    -- falling onto the rows below.
    r.cut = Fill(r, "BORDER", 0, 0, 0, 0.85)
    r.cut:SetHeight(1)
    r.cut:SetPoint("TOPLEFT", -LIST_BLEED, 0)
    r.cut:SetPoint("TOPRIGHT", LIST_BLEED, 0)
    r.cut:Hide()
    r.cutLight = Fill(r, "BORDER", 1, 1, 1, 0.11)
    r.cutLight:SetHeight(1)
    r.cutLight:SetPoint("TOPLEFT", r.cut, "BOTTOMLEFT")
    r.cutLight:SetPoint("TOPRIGHT", r.cut, "BOTTOMRIGHT")
    r.cutLight:Hide()
    r.cutShade = r:CreateTexture(nil, "BORDER")
    r.cutShade:SetColorTexture(1, 1, 1, 1)
    r.cutShade:SetHeight(7)
    r.cutShade:SetPoint("TOPLEFT", r.cutLight, "BOTTOMLEFT")
    r.cutShade:SetPoint("TOPRIGHT", r.cutLight, "BOTTOMRIGHT")
    if r.cutShade.SetGradient and CreateColor then
        r.cutShade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.36))
    else
        r.cutShade:SetColorTexture(0, 0, 0, 0.12)
    end
    r.cutShade:Hide()
    -- A small lock in the middle of the line: what lies below is beyond the current rank.
    -- (The game's own lock art.)
    r.cutLock = r:CreateTexture(nil, "OVERLAY")
    r.cutLock:SetSize(12, 12)
    r.cutLock:SetPoint("CENTER", r.cut, "CENTER", 0, 0)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Monuments-Lock") then
        r.cutLock:SetAtlas("Monuments-Lock")
    else
        r.cutLock:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
    end
    r.cutLock:SetDesaturated(true)
    r.cutLock:SetVertexColor(0.75, 0.75, 0.75, 0.65)
    r.cutLock:Hide()
    -- The cutoff's one-time shimmer (the line the next rank removes), played by the panel.
    r.shimmer = Fade(r, "OVERLAY", GOLD[1], GOLD[2], GOLD[3], 0.55)
    r.shimmer:SetHeight(2)
    r.shimmer:SetPoint("TOPLEFT", -LIST_BLEED, 1)
    r.shimmer:SetPoint("TOPRIGHT", LIST_BLEED, 1)
    r.shimmer:Hide()
    r.box, r.mark = TickBox(r)
    r.box:SetPoint("LEFT", 2, 0)
    -- The skill color starts after the tick box, which sits in its own plain
    -- gutter on the left, and builds toward the right, strongest by the number.
    r.tint = Fade(r, "BORDER", 1, 1, 1, 0)
    r.tint.reversed = true
    r.tint:SetPoint("TOPLEFT", r, "TOPLEFT", 2 + r.box:GetWidth() + 5, 0)
    r.tint:SetPoint("BOTTOMRIGHT", 0, 1) -- stops above the dividing line
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("LEFT", r.box, "RIGHT", 11, 0) -- a little inside the background's left edge
    r.skill = Label(r)
    r.skill:SetPoint("RIGHT", -8, 0)
    r.name = Label(r)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetPoint("RIGHT", r.skill, "LEFT", -4, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)

    r:SetScript("OnClick", function(self)
        local key = self.node.key
        FN.enabled[key] = (not FN.enabled[key]) or nil
        self.mark:SetShown(FN.enabled[key] and true or false)
        if nodesPage.ForgetUndo then nodesPage:ForgetUndo() end
        FN:Refresh()
    end)
    return r
end

local function RefreshNodes()
    local page = nodesPage
    local db = FN.db

    -- The profession picked in the left list. One this character lacks can always be
    -- opened; its nodes can only be ticked while "Allow tracking unlearned professions" is on.
    local skills = {}
    for _, kind in ipairs(FN.kinds) do skills[kind] = FN:GetSkillInfo(kind) end
    local current = page.kind
    local canTick = current ~= nil and (skills[current] ~= nil or db.showAll)

    -- Docked to the map the window is narrow: the controls tighten up to stay on
    -- one row with the title, and the list is a single scrolling column.
    local compact = frame.narrow
    local pageWidth = frame.pageWidth or (compact and (DOCK_WIDTH - 40) or (WIDTH - NAV_WIDTH - 48))
    -- The skill header (card art and bar) sits between the title row and the list.
    local headerH = current and page.header and page.header:Layout(current, skills[current]) or 0
    if not current and page.header then page.header:Hide() end
    local listTop = -36 - headerH
    if page.trainers and page.trainers.open and current then listTop = listTop + 7 end
    page.none:SetWidth(compact and 96 or 104)
    page.all:SetWidth(compact and 68 or 76)
    page.rule:ClearAllPoints()
    page.rule:SetPoint("TOPLEFT", 0, listTop + 7)
    page.rule:SetPoint("TOPRIGHT", 0, listTop + 7)
    page.scroll:ClearAllPoints()
    -- The list's clipping area starts at the pane's border (LIST_BLEED left of the
    -- page) so the row stripes can run out to it; the rows themselves stay put.
    page.scroll:SetPoint("TOPLEFT", -LIST_BLEED, listTop)
    -- Out to the pane's border on the right too, so a rank line (and its end ornament) reaches it.
    page.scroll:SetPoint("BOTTOMRIGHT", LIST_BLEED, 0)
    page.scroll.rightBleed = LIST_BLEED
    page.fishNote:SetShown(current == "fish" and db.onlyPole)
    page.fishLink:SetShown(current == "fish" and db.onlyPole)

    page.title:SetText(current and FN.kindNames[current] or "")
    page.sortToggle:SetMode(db.sort)
    page.sortLabel:SetShown(current ~= nil and not compact) -- the side panel has the toggle in its top row
    page.all:SetShown(current ~= nil)
    page.none:SetShown(current ~= nil)
    -- While the trainer list is open the two buttons sit just above its pins and could be
    -- clicked by mistake (or to close the list): they rest, dimmed, until it closes.
    local resting = page.trainers and page.trainers.open and current ~= nil
    page.undo:SetShown(current ~= nil and page:CanUndo())
    local rest = resting or (current ~= nil and not canTick)
    for _, b in ipairs({ page.all, page.none, page.undo }) do
        if b.SetEnabled then b:SetEnabled(not rest) end
        b:EnableMouse(not rest)
        b:SetAlpha(rest and 0.35 or 1)
    end

    -- The profession's own card art as the list box's background, exactly as the game's recipe
    -- pane uses it: one picture (brown, glow, dark edges and the illustration) filling the box
    -- edge to edge. The EllesmereUI look takes it in grey and a little darker, to suit its
    -- flat, neutral panels.
    do
        if not page.art then
            page.art = page.frame:CreateTexture(nil, "BACKGROUND", nil, 2)
            page.art:SetPoint("TOPLEFT", page.frame, "TOPLEFT", -LIST_BLEED, LIST_BLEED)
            page.art:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT", LIST_BLEED, -LIST_BLEED)
            -- Darkened a little, so the rows stand out from it.
            page.artShade = page.frame:CreateTexture(nil, "BACKGROUND", nil, 3)
            page.artShade:SetAllPoints(page.art)
        end
        local stock = BrownTone()
        page.art:SetDesaturated(not stock)
        page.artShade:SetColorTexture(0, 0, 0, stock and 0.175 or 0.4)
        local NAMES = { herb = "Herbalism", ore = "Mining", fish = "Fishing" }
        local card = current and NAMES[current] and ("Profession-background-card-" .. NAMES[current])
        if card and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(card) then
            page.art:SetAtlas(card)
            page.art:Show()
            page.artShade:Show()
        else
            page.art:Hide()
            page.artShade:Hide()
        end
    end

    local info = current and skills[current]
    local ranked = info and current ~= "fish" -- dimming and rank lines are for herbs and ore
    local cap = info and info.max or 0
    local below300 = ranked and cap < 300

    local list = {}
    if current then
        for _, node in ipairs(FN.nodes) do
            if node.kind == current then
                -- A-Z can't show rank lines, so it can leave out what the rank can't reach.
                local hide = db.sort == "name" and not db.azShowBeyond and below300 and node.skill > cap
                if not hide then list[#list + 1] = node end
            end
        end
        if db.sort == "name" then
            table.sort(list, function(a, b) return a.name < b.name end)
        else
            table.sort(list, function(a, b)
                if a.skill ~= b.skill then return a.skill < b.skill end
                return a.name < b.name
            end)
        end
    end
    page.list = list

    -- Rank lines: after the last node each untrained rank's cap can gather (Lvl sort only).
    local gates = {}
    if below300 and db.cutoffs and db.sort ~= "name" then
        for _, r in ipairs(FN.RANKS) do
            if r.cap >= cap and r.cap < 300 then gates[#gates + 1] = r.cap end
        end
    end
    -- At trained skill 300 (with the mute option) the list drops its difficulty colors.
    local muted = info and current ~= "fish" and info.rank >= 300 and db.muteAtMax
    page.gateRow = nil

    -- The trainer list (when open) sits at the top of the same scroll area and pushes the rows down.
    local trainersH = 0
    if page.trainers then
        -- One bad trainer row must not stop the node list from being placed under it.
        local ok, h = pcall(page.trainers.Layout, page.trainers, current, pageWidth)
        if ok then trainersH = h or 0 else geterrorhandler()(h) end
    end
    -- With the trainer list open, the bronze rule moves from above the list to just under the
    -- trainer section, in the gap before the node rows.
    if trainersH > 0 and not page.trainerRule then
        page.trainerRule = Fill(page.scroll.child, "ARTWORK", BRONZE[1], BRONZE[2], BRONZE[3], 0.35)
        page.trainerRule:SetHeight(1)
    end
    page.rule:SetShown(trainersH <= 0)
    if page.trainerRule then
        page.trainerRule:SetShown(trainersH > 0)
        page.trainerRule:ClearAllPoints()
        page.trainerRule:SetPoint("TOPLEFT", page.scroll.child, "TOPLEFT", LIST_BLEED, -(trainersH - 5))
        page.trainerRule:SetWidth(pageWidth)
    end

    local perCol = compact and #list or math.ceil(#list / 2)
    local rowWidth = compact and pageWidth or COL_WIDTH -- same span as the skill bar
    local skill = info and info.effective
    for i, node in ipairs(list) do
        local row = page.rows[i]
        if not row then
            row = CreateRow(page.scroll.child)
            page.rows[i] = row
        end
        local col = i > perCol and 1 or 0
        local line = (i - 1) % perCol
        row:SetWidth(rowWidth)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", LIST_BLEED + col * (COL_WIDTH + COL_GAP), -line * ROW_HEIGHT - trainersH)
        row.node = node
        row.icon:SetTexture(node.icon)
        row.name:SetText(node.name)
        row.mark:SetShown(FN.enabled[node.key] and true or false)
        row:SetEnabled(canTick)
        row.box:SetAlpha(canTick and 1 or 0.4)
        row.mark:SetAlpha(canTick and 1 or 0.4)
        row.skill:SetText(node.skill > 0 and node.skill or "")

        -- Beyond the current rank, or a profession the character hasn't learned: greyed name,
        -- number and icon, no color wash.
        local dim = (below300 and node.skill > cap) or not info
        if dim then
            row.name:SetTextColor(0.33, 0.33, 0.33)
            row.skill:SetTextColor(0.27, 0.27, 0.27)
            row.icon:SetDesaturated(true)
            row.icon:SetAlpha(0.35)
            row.tint:SetFade(1, 1, 1, 0)
        else
            row.name:SetTextColor(1, 1, 1)
            row.icon:SetDesaturated(false)
            row.icon:SetAlpha(1)
            if muted then
                row.skill:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
                row.tint:SetFade(1, 1, 1, 0)
            else
                local r, g, b, tinted = Difficulty(skill, node.skill)
                row.skill:SetTextColor(r, g, b)
                row.tint:SetFade(r, g, b, tinted and 0.38 or 0)
            end
        end

        local cut = false
        local prev = list[i - 1]
        if prev and line > 0 then
            for _, T in ipairs(gates) do
                if prev.skill <= T and node.skill > T then
                    cut = true
                    if T == cap then page.gateRow = row end -- the line the next rank removes
                end
            end
        end
        row.cut:SetShown(cut)
        row.cutLock:SetShown(cut)
        row.cutLight:SetShown(cut)
        row.cutShade:SetShown(cut)
        row.shimmer:Hide()
        row:Show()
    end
    for i = #list + 1, #page.rows do page.rows[i]:Hide() end

    -- Fishing's one-line note sits centered under the list, 16px below the last row.
    -- It belongs to the list's scroll area (which would cover it otherwise) and scrolls with the rows.
    local note = page.fishNote
    note:SetParent(page.scroll.child)
    note:ClearAllPoints()
    note:SetPoint("TOP", page.scroll.child, "TOPLEFT", LIST_BLEED + pageWidth / 2, -perCol * ROW_HEIGHT - 16 - trainersH)
    page.fishLink:ClearAllPoints()
    page.fishLink:SetPoint("TOP", note, "BOTTOM", 0, -12)
    local listHeight = perCol * ROW_HEIGHT
    if current == "fish" and db.onlyPole then listHeight = listHeight + 16 + math.ceil(note:GetStringHeight()) + 12 + 14 end

    page.scroll.child:SetSize(pageWidth + LIST_BLEED, math.max(1, listHeight + trainersH))
    page.scroll:Update()
    if page.OnListDrawn then page:OnListDrawn() end
end

-- Skill header: the profession's card art, the animated skill bar, and the trainer list ---------
-- Rebuilt from the art the game's Professions pane uses (ProfessionsRankBarTemplate), so it
-- looks and moves the same: the fill art keeps its native size and is cropped (never squished),
-- the frame is drawn in three slices so its ornate ends keep their shape, the fill's flipbook
-- plays once for 2 s whenever the bar is shown or changes, then holds still.

local CARD_ATLAS = { herb = "Profession-overview-Card-Herbalism", ore = "Profession-overview-Card-Mining",
    fish = "Profession-overview-card-generic-fishing" }
local KIT = { herb = "Herbalism", ore = "Mining", fish = "Fishing" }
-- The fishing card is a tall portrait card whose picture sits in its lower half; start lower.
-- How far down each card's crop starts: the illustrations sit mid-card, below the empty top edge.
local ART_DOWN = { herb = 40, ore = 40, fish = 150 }
local GLOW = { herb = { 0.35, 1, 0.6 }, ore = { 0.69, 0.8, 0.92 }, fish = { 0.35, 0.86, 1 } }
local GLOW_STRENGTH = { herb = 1.3, ore = 1.3, fish = 0.93 } -- evens out how bright each color reads
local BAR_H = 24        -- hit area; the fill itself is the native 18px tall
local FILL_H = 18
local HEADER_H = 34       -- space the header adds above the list (bar plus breathing room)
local LMB = "|TInterface\\TutorialFrame\\UI-Tutorial-Frame:12:12:0:0:512:512:10:65:228:283|t"

-- Small tween helper: fades a region's alpha to `to` over `dur` seconds, then calls `done`.
local tweener = CreateFrame("Frame")
local tweens = {}
tweener:SetScript("OnUpdate", function(_, elapsed)
    for region, tw in pairs(tweens) do
        tw.t = tw.t + elapsed
        local k = tw.dur > 0 and math.min(tw.t / tw.dur, 1) or 1
        local e = k < 0.5 and 2 * k * k or 1 - (-2 * k + 2) ^ 2 / 2 -- ease in-out
        region:SetAlpha(tw.from + (tw.to - tw.from) * e)
        if k >= 1 then
            tweens[region] = nil
            if tw.done then tw.done() end
        end
    end
    if not next(tweens) then tweener:Hide() end -- nothing fading: no per-frame work
end)
tweener:Hide()
local function FadeTo(region, to, dur, done)
    if dur <= 0 then tweens[region] = nil; region:SetAlpha(to); if done then done() end return end
    tweens[region] = { from = region:GetAlpha(), to = to, dur = dur, t = 0, done = done }
    tweener:Show()
end

-- Draws an atlas cropped to its top-right `w` x `h` pixels (pinned top-right, never scaled).
-- `inset` skips that many pixels of the art's own top and right edge (the card's border).
-- `down` starts the crop that many pixels lower (for art whose picture sits low on the card).
local function CropAtlas(tex, atlas, w, h, inset, down)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if not info then tex:Hide() return end
    local W, H = info.width, info.height
    inset = inset or 0
    -- When the area is bigger than the picture, the picture scales up to fill it (never squished).
    local zoom = math.max(1, w / (W - inset), h / (H - inset))
    local sw, sh = w / zoom, h / zoom
    down = math.max(0, math.min(down or 0, H - inset - sh))
    tex:SetTexture(info.file)
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local px, py = (r - l) / W, (b - t) / H
    local right, top = r - px * inset, t + py * (inset + down)
    tex:SetTexCoord(right - px * sw, right, top, top + py * sh)
    tex:SetSize(w, h)
    tex:Show()
end

local COIN = {
    "|TInterface\\MoneyFrame\\UI-GoldIcon:13:13:2:0|t",
    "|TInterface\\MoneyFrame\\UI-SilverIcon:13:13:2:0|t",
    "|TInterface\\MoneyFrame\\UI-CopperIcon:13:13:2:0|t",
}
-- In place of a price for a rank taught by a quest: "Quest" and the game's quest-giver mark
-- for where the player is with it: gold "!" to pick up, silver "?" in progress, gold "?" to hand in.
local QUEST_MARK = {
    available = "Interface\\GossipFrame\\AvailableQuestIcon",
    active = "Interface\\GossipFrame\\IncompleteQuestIcon",
    ready = "Interface\\GossipFrame\\ActiveQuestIcon",
}
local function QuestPrice(t)
    local mark = QUEST_MARK[FN:TeachQuestState(t) or "available"]
    return "|cff9d9d9dQuest|r|T" .. mark .. ":14:14:0:0|t"
end
-- Coins: each number sits snug against its icon, with a clear gap before the next coin.
local function Money(copper)
    if copper == 0 then return "|cff9d9d9dfree|r" end
    local parts = { math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100 }
    local out = {}
    for i = 1, 3 do
        if parts[i] > 0 then out[#out + 1] = parts[i] .. COIN[i] end
    end
    return table.concat(out, "  ")
end

-- Under 1000 yards it counts every yard; above that it rounds to thousands ("14k yd").
local function Yards(y)
    if y < 1000 then return y .. " yd" end
    return math.floor(y / 1000 + 0.5) .. "k yd"
end

-- The cheapest price among `list`.
local function Cheapest(list)
    local low
    for _, t in ipairs(list) do if not low or t.cost < low then low = t.cost end end
    return low
end
local function Affordable(cost) return GetMoney() >= cost end

local REACTION = { friendly = "|cff4cd44c", neutral = "|cffe8cc3a", hostile = "|cffff4040" }

local function BuildHeader(page)
    local H = {}
    page.header = H

    -- Card art, top-right, cropped to the header area. Drawn on the page's background layer.
    local pf = page.frame -- the page's frame (page itself is the node page's state table)
    H.art = pf:CreateTexture(nil, "BACKGROUND", nil, 1)
    -- The page sits 10px inside the pane on each side and at the top; the art covers that margin
    -- too (1px short of the pane's edge line), so it fills the whole fixed area above the list.
    local ART_PAD = 9
    H.art:SetPoint("TOPRIGHT", pf, "TOPRIGHT", ART_PAD, ART_PAD)
    -- The picture's bottom fades out toward the list. A texture takes one gradient only (the
    -- left-to-right one), so the last FADE_H px are drawn as thin strips of the same picture,
    -- each a little fainter than the one above.
    local FADE_H, FADE_STEPS = 18, 9
    H.fade = {}
    function H:FadeBottom(strength, desat)
        local art = H.art
        if not art:IsShown() then
            for _, t in ipairs(H.fade) do t:Hide() end
            return
        end
        local w, h = art:GetSize()
        local ulx, uly, llx, lly, urx = art:GetTexCoord()
        local keep = math.max(1, h - FADE_H)
        local v = (lly - uly) / h -- texture coordinate per pixel, vertically
        art:SetHeight(keep)
        art:SetTexCoord(ulx, urx, uly, uly + v * keep)
        local step = FADE_H / FADE_STEPS
        for i = 1, FADE_STEPS do
            local t = H.fade[i]
            if not t then
                t = pf:CreateTexture(nil, "BACKGROUND", nil, 1)
                H.fade[i] = t
            end
            t:SetTexture(art:GetTexture())
            t:SetDesaturated(desat)
            t:ClearAllPoints()
            t:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT", 0, -(i - 1) * step)
            t:SetSize(w, step)
            local top = uly + v * (keep + (i - 1) * step)
            t:SetTexCoord(ulx, urx, top, top + v * step)
            local a = strength * (1 - (i - 0.5) / FADE_STEPS)
            if t.SetGradient and CreateColor then
                t:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, a))
            else
                t:SetAlpha(a)
            end
            t:Show()
        end
    end
    H.art:SetAlpha(0.55)

    -- The bar.
    local bar = CreateFrame("Button", nil, pf)
    H.bar = bar
    bar:SetHeight(BAR_H)
    bar:RegisterForClicks("LeftButtonUp")
    -- Background and frame are stretched to width exactly as the game's own bar does it.
    bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    bar.bg:SetColorTexture(0, 0, 0, 0.92)
    bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -3)
    bar.bg:SetHeight(FILL_H)
    bar.clip = CreateFrame("Frame", nil, bar)
    bar.clip:SetClipsChildren(true)
    -- As in the native bar: fill 2px in from the left and 3px down, at its full 441x18 size.
    bar.clip:SetPoint("TOPLEFT", 2, -3)
    bar.clip:SetHeight(FILL_H)
    bar.fill = bar.clip:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT")
    bar.fill:SetSize(441, FILL_H)
    bar.flare = bar.clip:CreateTexture(nil, "ARTWORK", nil, 2)
    bar.flare:SetBlendMode("ADD")
    bar.flare:SetSize(53, 16)
    bar.flare:SetPoint("RIGHT", bar.clip, "RIGHT", 0, 0)
    -- Everything drawn over the fill lives on a frame above the fill's clip frame.
    bar.over = CreateFrame("Frame", nil, bar)
    bar.over:SetAllPoints()
    bar.over:SetFrameLevel(bar.clip:GetFrameLevel() + 2) -- room between them for the cap glow
    bar.frame = bar.over:CreateTexture(nil, "ARTWORK")
    bar.frame:SetPoint("TOPLEFT")

    -- Flipbook: plays once (2 s), then holds its last frame.
    bar.anim = bar.fill:CreateAnimationGroup()
    bar.anim:SetToFinalAlpha(true)
    bar.flip = bar.anim:CreateAnimation("FlipBook")
    bar.flip:SetDuration(2)
    bar.flip:SetFlipBookColumns(2)

    -- Text: the level, and the cue line (View trainers, ...) with short fading lines either side.
    bar.text = bar.over:CreateFontString(nil, "OVERLAY", _G.Number12FontOutline and "Number12FontOutline" or "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", bar, "TOPLEFT", 0, 0) -- placed in Layout: centered on the whole bar
    bar.text:SetShadowOffset(1, -1)
    -- The same size as the cue line (View trainers, ...) and the other text on the bar.
    -- Stock look: the cue's own font (Friz Quadrata), so the two read alike; the number font
    -- looks small and thin there.
    do
        local font, _, flags = bar.text:GetFont()
        local small, size = GameFontHighlightSmall:GetFont()
        if Stock() and small then font = small end
        if font and size then bar.text:SetFont(font, size, flags) end
    end
    bar.cue = CreateFrame("Frame", nil, bar)
    bar.cue:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -3)
    bar.cue:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -2, -3 - FILL_H)
    bar.cue:SetFrameLevel(bar.over:GetFrameLevel() + 1)
    bar.cue:SetAlpha(0)
    bar.cueText = bar.cue:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.cueText:SetPoint("CENTER")
    bar.cueText:SetShadowOffset(1, -1)
    local function CueLine(flip)
        local t = bar.cue:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetSize(22, 1)
        if t.SetGradient and CreateColor then
            local a, b = CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.9)
            if flip then t:SetGradient("HORIZONTAL", b, a) else t:SetGradient("HORIZONTAL", a, b) end
        end
        return t
    end
    bar.cueL, bar.cueR = CueLine(false), CueLine(true)
    bar.cueL:SetPoint("RIGHT", bar.cueText, "LEFT", -8, 0)
    bar.cueR:SetPoint("LEFT", bar.cueText, "RIGHT", 8, 0)

    -- Hover glow: a faint colored edge around the bar.
    -- Hover glow: the bar's own ornate frame drawn again on top, additive and tinted in the
    -- profession's color, so the light follows the frame's shape instead of a hard box.
    bar.glow = CreateFrame("Frame", nil, bar)
    bar.glow:SetAllPoints()
    bar.glow:SetFrameLevel(bar.over:GetFrameLevel() + 2)
    bar.glow:SetAlpha(0)
    -- A soft line with a tight halo, following the frame's rounded shape. The 64 x 64 picture
    -- shows a 20 tall rounded box, 22 in from every edge: it is cut into a left end, a stretched
    -- middle and a right end, so the line lands on the middle of the bar's frame at any scale.
    -- Drawn twice, so the line stands out on the frame.
    bar.glowParts = {}
    local function GlowPart(l, r)
        local t = bar.glow:CreateTexture(nil, "OVERLAY")
        t:SetTexture(FN.MEDIA .. "bar_glow")
        t:SetTexCoord(l, r, 0, 1)
        t:SetBlendMode("ADD")
        bar.glowParts[#bar.glowParts + 1] = t
        return t
    end
    for _ = 1, 2 do
        local left, right, middle = GlowPart(0, 0.5), GlowPart(0.5, 1), GlowPart(0.49, 0.51)
        left:SetSize(32, 64)
        left:SetPoint("TOPLEFT", bar, "TOPLEFT", 1 - 22, -2 + 22)
        right:SetSize(32, 64)
        right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1 + 22, -2 + 22)
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    end

    -- Ready-to-train pulse at a cap: the bar's right end and top line swell softly.
    -- They live on their own frame, and the frame is what fades and pulses (gradient
    -- textures in this client don't reliably follow their own alpha). It sits under the bar's
    -- frame art, which covers its ends.
    bar.capF = CreateFrame("Frame", nil, bar)
    bar.capF:SetAllPoints()
    bar.capF:SetFrameLevel(bar.clip:GetFrameLevel() + 1)
    bar.capF:Hide()
    bar.capEdge = bar.capF:CreateTexture(nil, "OVERLAY", nil, 3)
    bar.capEdge:SetBlendMode("ADD")
    bar.capEdge:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -3, -4)
    bar.capEdge:SetHeight(FILL_H - 2)
    bar.capEdge:SetWidth(34)
    bar.capLine = bar.capF:CreateTexture(nil, "OVERLAY", nil, 3)
    bar.capLine:SetBlendMode("ADD")
    bar.capLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 3, -4)
    bar.capLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -3, -4)
    bar.capLine:SetHeight(1)
    bar.capPulse = bar.capF:CreateAnimationGroup()
    bar.capPulse:SetLooping("REPEAT")
    local up = bar.capPulse:CreateAnimation("Alpha")
    up:SetFromAlpha(0.12); up:SetToAlpha(0.95); up:SetDuration(1.17); up:SetSmoothing("IN_OUT"); up:SetOrder(1)
    local down = bar.capPulse:CreateAnimation("Alpha")
    down:SetFromAlpha(0.95); down:SetToAlpha(0.12); down:SetDuration(1.43); down:SetSmoothing("IN_OUT"); down:SetOrder(2)

    -- One-time gold flash when the panel opens and the next rank can be trained.
    bar.flash = bar.over:CreateTexture(nil, "OVERLAY", nil, 4)
    bar.flash:SetPoint("TOPLEFT", -4, 4)
    bar.flash:SetPoint("BOTTOMRIGHT", 4, -4)
    bar.flash:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
    bar.flash:SetBlendMode("ADD")
    bar.flash:SetAlpha(0)

    -- State ----------------------------------------------------------------------------
    local kind, info, lastKind, lastRank
    local flashed = {}      -- professions whose flash played this panel opening
    local shimmerArmed = {} -- professions whose rank-line shimmer is waiting to be seen
    local notice = false    -- the locked "Click again to hide" sequence is running
    local timers = {}
    local function Later(t, fn) timers[#timers + 1] = C_Timer.NewTimer(t, fn) end
    local function CancelAll() for _, t in ipairs(timers) do t:Cancel() end timers = {} end

    -- Instant swap to the cue text; or (text nil) fade the cue out fully, then the level is back at once.
    local function ShowCue(text, outDur)
        if text then
            tweens[bar.text] = nil; tweens[bar.cue] = nil
            bar.cueText:SetText(text)
            bar.text:SetAlpha(0); bar.cue:SetAlpha(1)
        else
            FadeTo(bar.cue, 0, outDur or 0, function() bar.text:SetAlpha(1) end)
        end
    end
    local function HoverText() return page.trainers and page.trainers.open and "Hide trainers" or "View trainers" end

    -- Failsafe: stop everything and snap to the plain level text.
    function H:Reset()
        CancelAll()
        notice = false
        tweens[bar.cue] = nil; tweens[bar.text] = nil
        bar.cue:SetAlpha(0); bar.text:SetAlpha(1)
    end

    -- Places the header for profession `k` and returns the height it takes.
    function H:Layout(k, skillInfo)
        local width = (frame.pageWidth or 300)
        kind, info = k, skillInfo
        local learned = skillInfo ~= nil

        -- Art: the card's top-right corner, as tall as the header area.
        CropAtlas(H.art, CARD_ATLAS[k], width + 2 * ART_PAD, ART_PAD + 36 + HEADER_H, 14, ART_DOWN[k])
        H.art:SetDesaturated(not learned)
        -- Fade in from the left; the strength is in the gradient itself (texture alpha isn't
        -- reliable on gradient textures here).
        local strength = learned and 1 or 0.6
        H.art:SetAlpha(1)
        if H.art.SetGradient and CreateColor then
            -- Softer at the left (behind the title), full strength at the right.
            -- Fully clear at its left edge, so the picture never shows a hard boundary (the panel is
            -- see-through, so any edge shows up against the moving world behind it).
            H.art:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, strength))
        else
            H.art:SetAlpha(strength)
        end
        H:FadeBottom(strength, not learned)

        -- Bar.
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", pf, "TOPLEFT", 0, -32)
        bar:SetWidth(width)
        bar.bg:SetWidth(width - 5)
        bar.text:ClearAllPoints()
        bar.text:SetPoint("CENTER", bar, "TOPLEFT", width / 2, -3 - FILL_H / 2)
        bar.frame:SetAtlas("Profession-ProgressBar-frame", true); bar.frame:SetWidth(width)
        local v = learned and 1 or 0.7
        bar.frame:SetVertexColor(v, v, v)

        local fillAtlas = "Skillbar_Fill_Flipbook_" .. KIT[k]
        local finfo = C_Texture.GetAtlasInfo(fillAtlas)
        if finfo and bar.fillAtlas ~= fillAtlas then
            bar.fillAtlas = fillAtlas
            bar.fill:SetAtlas(fillAtlas, false)
            local rows = math.max(1, math.floor(finfo.height / 34 + 0.5))
            bar.flip:SetFlipBookRows(rows)
            bar.flip:SetFlipBookFrames(rows * 2)
            -- Show the flipbook's first frame straight away, so the bar is never blank (or the
            -- whole sheet) for a frame before the animation takes over.
            local l, r, t, b = finfo.leftTexCoord, finfo.rightTexCoord, finfo.topTexCoord, finfo.bottomTexCoord
            bar.fill:SetTexCoord(l, l + (r - l) / 2, t, t + (b - t) / rows)
        end
        local flareAtlas = "Skillbar_Flare_" .. KIT[k]
        if C_Texture.GetAtlasInfo(flareAtlas) then bar.flare:SetAtlas(flareAtlas, false); bar.flare:Show() else bar.flare:Hide() end

        local inner = width - 5 -- stops inside the frame's rounded right end
        local ratio = learned and info.max > 0 and math.min(info.rank / info.max, 1) or 0
        local target = math.max(1, inner * ratio)
        local full = learned and info.rank >= info.max
        local sameKind = lastKind == k
        -- A skill-up while shown slides the fill (0.5 s ease-out) and, if it fills up, fades the
        -- flare out over 1 s. Anything else (opening, switching) draws it in place at once.
        if sameKind and lastRank and learned and info.rank > lastRank then
            local from = bar.clip:GetWidth()
            local t0 = GetTime()
            bar:SetScript("OnUpdate", function(self)
                local p = math.min((GetTime() - t0) / 0.5, 1)
                local e = 1 - (1 - p) ^ 3
                self.clip:SetWidth(from + (target - from) * e)
                if p >= 1 then self:SetScript("OnUpdate", nil) end
            end)
            if full then FadeTo(bar.flare, 0, 1) else bar.flare:SetAlpha(1) end
            bar.anim:Restart()
        else
            bar:SetScript("OnUpdate", nil)
            bar.clip:SetWidth(target)
            bar.flare:SetAlpha(full and 0 or 1)
            if not sameKind then bar.anim:Restart() end
        end
        bar.clip:SetShown(learned)
        lastKind, lastRank = k, learned and info.rank or nil

        if learned then
            bar.text:SetText(("%s %d/%d"):format(FN.kindNames[k], info.rank, info.max))
            bar.text:SetTextColor(1, 1, 1)
        else
            bar.text:SetText(FN.kindNames[k] .. " \194\183 Not learned")
            bar.text:SetTextColor(0.85, 0.83, 0.8)
        end

        local c = GLOW[k]
        for i, t in ipairs(bar.glowParts) do
            local strength = i <= 3 and 0.8 or 0.45 -- the first pass, then the second on top of it
            t:SetVertexColor(c[1], c[2], c[3], strength * GLOW_STRENGTH[k] * (learned and 1 or 0.55))
        end
        bar.capEdge:SetColorTexture(1, 1, 1, 1)
        bar.capLine:SetColorTexture(1, 1, 1, 1)
        if bar.capEdge.SetGradient and CreateColor then
            bar.capEdge:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], 0), CreateColor(1, 1, 1, 0.95))
            bar.capLine:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], 0), CreateColor(1, 1, 1, 0.9))
        end

        -- At a cap: pulse when the next rank can be trained, a steady dim glow when it can't yet.
        local capped = learned and FN:IsCapped(k)
        if capped and FN:CanTrain(k) then
            bar.capF:Show(); bar.capLine:Show()
            if not bar.capPulse:IsPlaying() then bar.capPulse:Play() end
        else
            bar.capPulse:Stop()
            -- Can't train yet: a steady dim glow at the end only. Not capped: nothing.
            bar.capF:SetShown(capped)
            bar.capF:SetAlpha(0.22)
            bar.capLine:Hide()
        end
        bar:Show()
        return HEADER_H
    end

    -- Called when a profession's page is shown (panel opened or tab switched): replays the
    -- fill and, once per profession per opening, the gold flash and the rank-line shimmer.
    function H:Shown(k)
        bar.anim:Restart()
        if FN:GetSkillInfo(k) and FN:CanTrain(k) and not flashed[k] then
            flashed[k] = true
            shimmerArmed[k] = true
            bar.flash:SetAlpha(1)
            FadeTo(bar.flash, 0, 1.2)
        end
    end
    function H:PanelOpened() flashed = {}; shimmerArmed = {} end
    function H:Hide()
        bar:Hide(); H.art:Hide(); bar.capPulse:Stop()
        for _, t in ipairs(H.fade or {}) do t:Hide() end
    end

    -- The rank line the next rank removes shimmers once, the first time it is on screen.
    function H:CheckShimmer()
        local row = page.gateRow
        if not (kind and shimmerArmed[kind] and row and row:IsShown()) then return end
        local sf = page.scroll
        local top, bottom = sf:GetTop(), sf:GetBottom()
        local rt = row:GetTop()
        if top and bottom and rt and rt <= top and rt >= bottom then
            shimmerArmed[kind] = nil
            row.shimmer:SetAlpha(0)
            row.shimmer:Show()
            FadeTo(row.shimmer, 1, 0.35, function() FadeTo(row.shimmer, 0, 1.05, function() row.shimmer:Hide() end) end)
        end
    end

    -- Hover: instant swap to the cue; after leaving it holds 1 s, fades out 0.5 s, then the
    -- level is back at once. Re-entering before that keeps it. After a click the cue stays away
    -- while the mouse stays on the bar (the glow stays, so the skill can be watched going up);
    -- leaving the bar and coming back brings it back.
    local spent = false
    local leaveTimer
    bar:SetScript("OnEnter", function(self)
        self.hovered = true
        FadeTo(self.glow, 1, 0.2)
        if leaveTimer then leaveTimer:Cancel(); leaveTimer = nil end
        if not notice and not spent then ShowCue(HoverText()) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        H:FillTooltip(GameTooltip)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function(self)
        self.hovered = false
        spent = false
        FadeTo(self.glow, 0, 0.6)
        GameTooltip:Hide()
        if notice then return end
        leaveTimer = C_Timer.NewTimer(1.0, function()
            leaveTimer = nil
            if not self.hovered and not notice then ShowCue(nil, 0.5) end
        end)
    end)

    -- The first launch tour shows the bar as if the mouse were on it.
    function H:TourHover(on)
        FadeTo(bar.glow, on and 1 or 0, 0.2)
        if on then ShowCue("View trainers") else H:Reset() end
    end

    -- Click: open or close the trainer list. Opening plays a locked notice, one text at a time:
    -- current text out 0.2 s, "Click again to hide" in 0.5 s, hold 1 s, out 0.5 s, then at once
    -- "Hide trainers" if the mouse left and came back during it, otherwise the level. Clicking
    -- during it closes the list.
    bar:SetScript("OnClick", function(self)
        local T = page.trainers
        if not (T and kind) then return end
        if notice or T.open then
            T:Close(); H:Reset()
            spent = self.hovered
            return
        end
        T:Open()
        CancelAll()
        notice = true
        spent = self.hovered
        FadeTo(bar.cue, 0, 0.2); FadeTo(bar.text, 0, 0.2)
        Later(0.2, function()
            bar.cueText:SetText("Click again to hide")
            FadeTo(bar.cue, 1, 0.5)
        end)
        Later(1.7, function() FadeTo(bar.cue, 0, 0.5) end)
        Later(2.2, function()
            notice = false
            if self.hovered and not spent and T.open then ShowCue("Hide trainers") else bar.text:SetAlpha(1) end
        end)
    end)

    -- Tooltip ----------------------------------------------------------------------------
    function H:FillTooltip(tip)
        if not kind then return end
        local learnedInfo = FN:GetSkillInfo(kind)
        local list, nxt = FN:TrainersFor(kind)
        if not nxt then
            tip:AddLine(FN.kindNames[kind] .. " \226\128\148 Artisan", 1, 1, 1)
            tip:AddLine("Fully trained. Nothing left to learn.", 0.6, 0.6, 0.6)
            return
        end
        tip:AddLine((learnedInfo and "Next: " or "Learn: ") .. nxt.name .. " " .. FN.kindNames[kind], 1, 1, 1)
        if learnedInfo then
            local ok = learnedInfo.rank >= nxt.skill
            tip:AddDoubleLine("Requires " .. FN.kindNames[kind], tostring(nxt.skill), 0.6, 0.6, 0.6,
                ok and 0.13 or 1, ok and 1 or 0.13, 0.13)
        else
            tip:AddDoubleLine("Requirements", "none", 0.6, 0.6, 0.6, 1, 1, 1)
        end
        if nxt.level > 0 then
            local ok = UnitLevel("player") >= nxt.level
            tip:AddDoubleLine("Requires level", tostring(nxt.level), 0.6, 0.6, 0.6, ok and 0.13 or 1, ok and 1 or 0.13, 0.13)
        end
        tip:AddDoubleLine("Your gold", Money(GetMoney()), 0.6, 0.6, 0.6, 1, 1, 1)
        if #list > 0 then
            tip:AddLine(" ")
            local closest = list[1]
            local low = Cheapest(list)
            local cheapest
            for _, t in ipairs(list) do
                if t.cost == low and (not cheapest or (t.yards or 1e9) < (cheapest.yards or 1e9)) then cheapest = t end
            end
            local function Line(label, t)
                local name = (REACTION[t.reaction] or "|cffffffff") .. t.name .. "|r"
                local where = t.town ~= "" and t.town or t.zone
                local price = t.teach == "quest" and QuestPrice(t) or Money(t.cost)
                if t.cost > 0 and not Affordable(t.cost) then price = "|cffff2020" .. price .. "|r" end
                tip:AddDoubleLine(label .. name .. " |cff9d9d9d\194\183 " .. where .. (t.yards and (" \194\183 " .. Yards(t.yards)) or "") .. "|r",
                    price, 0.6, 0.6, 0.6, 1, 1, 1)
            end
            if closest == cheapest then Line("Closest & cheapest: ", closest)
            else Line("Closest: ", closest); Line("Cheapest: ", cheapest) end
            tip:AddLine(" ")
            tip:AddLine(LMB .. " " .. (page.trainers and page.trainers.open and "Click the bar to hide the trainers"
                or ("Click the bar for all " .. #list .. (#list == 1 and " trainer" or " trainers"))), 1, 0.82, 0)
        end
    end

    function FN:OnRankTrained()
        if page.trainers then page.trainers:Close() end
        H:Reset()
    end
    return H
end

-- Trainer list --------------------------------------------------------------------------------
-- Opens at the top of the node list's scroll area (pushing the nodes down). Columns:
-- Trainer, Dist, Location, Price; sortable; Trainer and Dist widths drag-resizable and saved
-- account-wide. Clicking a row pins that trainer on the map (click again to unpin).

local TR_ROW = 22  -- fold lines
local TR_ROW2 = 56 -- trainer cards (two lines plus a small gap)
-- The trainer table is dense data, so it reads a size smaller than the node list.
local function Smaller(fs, by)
    local file, size, flags = fs:GetFont()
    if file and size then fs:SetFont(file, math.max(8, size - (by or 1)), flags) end
end
local trainerSort = { by = "dist", dir = 1 } -- this session only (resets on reload)
local LOC_DIM = "|cff8d8b86"

-- Text that fits stays still; text that doesn't fades at its right edge and scrolls on hover.
local function ScrollBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    box:SetClipsChildren(true)
    box.fs = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.fs:SetPoint("LEFT", 0, 0)
    box.fs:SetWordWrap(false)
    box.fs:SetJustifyH("LEFT")
    Smaller(box.fs)
    box.offset = 0
    function box:SetText(t)
        self.fs:SetText(t)
        self:SetOffset(0)
    end
    function box:Overflow()
        local w = self.fs.GetUnboundedStringWidth and self.fs:GetUnboundedStringWidth() or self.fs:GetStringWidth()
        return math.max(0, w - self:GetWidth())
    end
    function box:Edge()
        if not self.fs.SetAlphaGradient then return end
        if self:Overflow() > 2 then
            self.fs:SetAlphaGradient(math.max(0, math.floor(self.offset + self:GetWidth() - 18)), 18)
        else
            -- No fade: start it far past the end of any text (length must be above 0).
            self.fs:SetAlphaGradient(4096, 1)
        end
    end
    function box:SetOffset(x)
        self.offset = x
        self.fs:ClearAllPoints()
        self.fs:SetPoint("LEFT", -x, 0)
        self:Edge()
    end
    return box
end

-- One shared scroll timeline per row so the name and location move in sync: same start, same
-- reading speed (42 px/s, cosine ease in 0.35 s / out 0.65 s), the shorter one waits, then
-- both hold 0.85 s, fade out 0.26 s, return, fade in 0.26 s, pause 0.5 s, repeat.
local MQ = { speed = 42, rampIn = 0.35, rampOut = 0.65, wait = 0.4, hold = 1.0, rest = 0.9, fade = 0.26, back = 0.25 }
local function MqPos(t, dist)
    local ti, to, v = MQ.rampIn, MQ.rampOut, MQ.speed
    if v * (ti + to) / 2 > dist then v = dist / ((ti + to) / 2) end
    local dIn, dOut = v * ti / 2, v * to / 2
    local cruise = (dist - dIn - dOut) / v
    local T = ti + cruise + to
    if t <= ti then return v * (t / 2 - ti / (2 * math.pi) * math.sin(math.pi * t / ti)), T end
    if t <= ti + cruise then return dIn + v * (t - ti), T end
    local r = math.min(t - ti - cruise, to)
    return math.min(dist, dIn + v * cruise + v * (r / 2 + to / (2 * math.pi) * math.sin(math.pi * r / to))), T
end

-- Hovered text that doesn't fit glides to its end, holds, glides back, rests, and repeats; it
-- never fades out, so a name is always readable. Leaving glides it home.
local function Glide(box, from, dur)
    local t0 = GetTime()
    box:SetScript("OnUpdate", function(self)
        local k = math.min((GetTime() - t0) / dur, 1)
        local e = 1 - (1 - k) * (1 - k)
        self:SetOffset(from * (1 - e))
        if k >= 1 then self:SetScript("OnUpdate", nil) end
    end)
end
local function StartMarquee(row)
    local items = {}
    for _, box in ipairs({ row.nameBox, row.distBox, row.locBox }) do
        -- Only text that doesn't fit is touched (text that fits keeps its alignment).
        local d = box:IsShown() and box:Overflow() or 0
        box:SetScript("OnUpdate", nil)
        tweens[box.fs] = nil
        box.fs:SetAlpha(1)
        if d > 2 then
            items[#items + 1] = { box = box, dist = d + 6, from = box.offset or 0 }
        end
    end
    if #items == 0 then return end
    local T = 0
    for _, it in ipairs(items) do local _, t = MqPos(0, it.dist); T = math.max(T, t) end
    local plan = { { "wait", MQ.wait }, { "scroll", T }, { "hold", MQ.hold }, { "back", T }, { "rest", MQ.rest } }
    local i, t0 = 1, GetTime()
    row:SetScript("OnUpdate", function()
        local ph, dur = plan[i][1], plan[i][2]
        local el = GetTime() - t0
        local k = dur > 0 and math.min(el / dur, 1) or 1
        for _, it in ipairs(items) do
            if ph == "wait" then it.box:SetOffset(it.from * (1 - k))
            elseif ph == "scroll" then it.box:SetOffset((MqPos(el, it.dist)))
            elseif ph == "back" then it.box:SetOffset(it.dist - (MqPos(el, it.dist))) end
        end
        if k >= 1 then
            i = i + 1; t0 = GetTime()
            if i > #plan then i = 2; for _, it in ipairs(items) do it.from = 0 end end
        end
    end)
end
local function StopMarquee(row)
    row:SetScript("OnUpdate", nil)
    for _, box in ipairs({ row.nameBox, row.distBox, row.locBox }) do
        tweens[box.fs] = nil
        box.fs:SetAlpha(1)
        if (box.offset or 0) ~= 0 then Glide(box, box.offset, MQ.back) end
    end
end

local function BuildTrainers(page)
    local L = { open = false, rows = {} }
    page.trainers = L
    local child = page.scroll.child

    -- The whole trainer block sits in its own darker inset card with a bronze edge, so it
    -- reads as a separate panel on top of the node list.
    local card = CreateFrame("Frame", nil, child)
    -- Nearly solid, so the moving world behind the see-through panel doesn't show through the
    -- trainer list; the cards inside then need only light shading of their own.
    card.bg = Rounded(card, "BACKGROUND", "round_fill"); card.bg:SetVertexColor(0.02, 0.02, 0.025, 0.88)
    -- The edge is drawn on its own frame above the rows, so the row bands never cover it.
    card.edgeF = CreateFrame("Frame", nil, card)
    card.edgeF:SetAllPoints()
    card.edgeF:SetFrameLevel(child:GetFrameLevel() + 20)
    card.edge = Rounded(card.edgeF, "ARTWORK", "round_edge"); card.edge:SetVertexColor(TRIM[1], TRIM[2], TRIM[3], TRIM[4]) -- the same trim as the controls' edges
    card.noFade = true -- the section's background stays; its rows fade
    card:Hide()

    -- Header: "Next rank:" small, the rank itself large in gold with the trainer count dim beside
    -- it, a small "Pin to map" hint at the top, and the Dist | Price switch on the right.
    -- A warmer panel up top with round top corners (a rounded fill, clipped at the bottom).
    local HEAD_H, HEAD_LINE, HEAD_ROW3 = 56, 55, 53
    local head = CreateFrame("Frame", nil, child)
    head:SetHeight(HEAD_H)
    head.clip = CreateFrame("Frame", nil, head)
    head.clip:SetPoint("TOPLEFT", 0, 0); head.clip:SetPoint("BOTTOMRIGHT", head, "TOPRIGHT", 0, -HEAD_LINE)
    head.clip:SetClipsChildren(true)
    head.bg = head.clip:CreateTexture(nil, "BACKGROUND")
    head.bg:SetTexture(FN.MEDIA .. "round_fill")
    if head.bg.SetTextureSliceMargins then head.bg:SetTextureSliceMargins(10, 10, 10, 10) end
    head.bg:SetPoint("TOPLEFT", 0, 0); head.bg:SetPoint("BOTTOMRIGHT", head.clip, "BOTTOMRIGHT", 0, -20)
    head.bg:SetVertexColor(0.15, 0.125, 0.1, 0.92)
    head.label = Label(head, "GameFontDisableSmall"); head.label:SetPoint("TOPLEFT", LIST_BLEED - 2, -6)
    head.rank = Label(head, "GameFontNormalLarge"); head.rank:SetPoint("TOPLEFT", LIST_BLEED + 10, -20)
    -- Third line: the trainer count and the pin hint sit on the header's bottom rule, which
    -- breaks around them; the hint is centered.
    head.count = Label(head, "GameFontDisableSmall"); head.count:SetPoint("LEFT", head, "TOPLEFT", LIST_BLEED + 11, -HEAD_ROW3)
    head.hint = Label(head, "GameFontHighlightSmall", LMB .. " Pin to map"); head.hint:SetPoint("CENTER", head, "TOP", 0, -HEAD_ROW3)
    head.hint:SetTextColor(0.6, 0.58, 0.55)
    local function Rule()
        local t = Fill(head, "BORDER", TRIM[1], TRIM[2], TRIM[3], TRIM[4]); t:SetHeight(1)
        return t
    end
    local dy = HEAD_ROW3 - HEAD_LINE -- the rule sits just under the text's middle
    head.ruleA, head.ruleB, head.ruleC = Rule(), Rule(), Rule()
    head.ruleA:SetPoint("LEFT", head, "TOPLEFT", 1, -HEAD_LINE); head.ruleA:SetPoint("RIGHT", head.count, "LEFT", -5, dy)
    head.ruleB:SetPoint("LEFT", head.count, "RIGHT", 5, dy); head.ruleB:SetPoint("RIGHT", head.hint, "LEFT", -5, dy)
    head.ruleC:SetPoint("LEFT", head.hint, "RIGHT", 5, dy); head.ruleC:SetPoint("RIGHT", head, "TOPRIGHT", -1, -HEAD_LINE)
    -- The rounded fill lives on a child frame (for the clipping), which would draw over the
    -- header's own text: the text and rules move to a frame above it.
    head.txt = CreateFrame("Frame", nil, head)
    head.txt:SetAllPoints()
    head.txt:SetFrameLevel(head:GetFrameLevel() + 2)
    for _, rg in ipairs({ head.label, head.rank, head.count, head.hint, head.ruleA, head.ruleB, head.ruleC }) do
        rg:SetParent(head.txt)
    end
    head.title = head.rank -- older code sets the title; the rank line carries it now
    head.sort = PairToggle(head, "Dist", "Price", function()
        trainerSort.by = trainerSort.by == "price" and "dist" or "price"
        trainerSort.dir = 1
        RefreshNodes()
    end)
    head.sort:SetPoint("TOPRIGHT", head, "TOPRIGHT", -(LIST_BLEED + 4 + 12), -17) -- centered on the rank's line
    head.sort:SetFrameLevel(head:GetFrameLevel() + 3)

    -- Sort bar: "SORT  Distance  Price  Name  Zone"; the active one is gold with an arrow.
    local cols = CreateFrame("Frame", nil, child)
    cols:SetHeight(16)
    cols.bg = Fill(cols, "BACKGROUND", 0, 0, 0, 0.25); cols.bg:SetAllPoints()
    cols.label = cols:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); Smaller(cols.label, 2)
    cols.label:SetText("SORT")
    local colButtons, colOrder = {}, {}
    local function ColButton(key, text)
        local b = CreateFrame("Button", nil, cols)
        b:SetHeight(16)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        Smaller(b.fs, 1)
        b.fs:SetPoint("LEFT", 0, 0)
        b.label = text
        b:SetScript("OnClick", function()
            if trainerSort.by == key then trainerSort.dir = -trainerSort.dir else trainerSort.by, trainerSort.dir = key, 1 end
            RefreshNodes()
        end)
        b:SetScript("OnEnter", function(self) if trainerSort.by ~= key then self.fs:SetTextColor(1, 1, 1) end end)
        b:SetScript("OnLeave", function(self) if trainerSort.by ~= key then self.fs:SetTextColor(0.55, 0.55, 0.55) end end)
        colButtons[key] = b
        colOrder[#colOrder + 1] = key
        return b
    end
    ColButton("dist", "Distance"); ColButton("price", "Price"); ColButton("name", "Name"); ColButton("zone", "Zone")

    local hide = CreateFrame("Button", nil, child)
    hide:SetHeight(28)
    hide.clip = CreateFrame("Frame", nil, hide); hide.clip:SetAllPoints(); hide.clip:SetClipsChildren(true)
    hide.bg = hide.clip:CreateTexture(nil, "BACKGROUND")
    hide.bg:SetTexture(FN.MEDIA .. "round_fill")
    if hide.bg.SetTextureSliceMargins then hide.bg:SetTextureSliceMargins(10, 10, 10, 10) end
    hide.bg:SetPoint("TOPLEFT", hide, "TOPLEFT", 0, 20); hide.bg:SetPoint("BOTTOMRIGHT", 0, 0)
    hide.bg:SetVertexColor(0, 0, 0, 0.6)
    hide.top = Fill(hide, "BORDER", 1, 1, 1, 0.1); hide.top:SetHeight(1)
    hide.top:SetPoint("TOPLEFT", 1, 0); hide.top:SetPoint("TOPRIGHT", -1, 0)
    -- The text and its lines sit on a frame above the dark background's, which would cover them.
    hide.front = CreateFrame("Frame", nil, hide)
    hide.front:SetAllPoints()
    hide.front:SetFrameLevel(hide.clip:GetFrameLevel() + 1)
    hide.fs = Label(hide.front, "GameFontDisableSmall", "Hide trainers"); hide.fs:SetPoint("CENTER", 0, 1)
    hide.fs:SetTextColor(0.30, 0.30, 0.30)
    local function SideLine(flip)
        local t = hide.front:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 1); t:SetSize(26, 1)
        if t.SetGradient and CreateColor then
            local a, b = CreateColor(0.6, 0.6, 0.6, 0), CreateColor(0.6, 0.6, 0.6, 0.4)
            if flip then t:SetGradient("HORIZONTAL", b, a) else t:SetGradient("HORIZONTAL", a, b) end
        end
        return t
    end
    hide.l, hide.r = SideLine(false), SideLine(true)
    -- (The card's own edge closes the block off under this row.)
    hide.l:SetPoint("RIGHT", hide.fs, "LEFT", -12, 0); hide.r:SetPoint("LEFT", hide.fs, "RIGHT", 12, 0)
    hide:SetScript("OnEnter", function(self) self.fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
    hide:SetScript("OnLeave", function(self) self.fs:SetTextColor(0.30, 0.30, 0.30) end)
    hide:SetScript("OnClick", function() L:Close(); if page.header then page.header:Reset() end end)

    L.folds, L.collapsed = {}, {}
    function L:NewFold(i)
        local f = CreateFrame("Button", nil, child)
        f:SetHeight(TR_ROW)
        f.bg = Fill(f, "BACKGROUND", 1, 1, 1, 0.025); f.bg:SetAllPoints()
        f.hl = f:CreateTexture(nil, "HIGHLIGHT"); f.hl:SetAllPoints(); f.hl:SetColorTexture(1, 1, 1, 0.06)
        f.arrow = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.arrow:SetPoint("LEFT", LIST_BLEED + 8, 0)
        f.top = Fill(f, "BORDER", 1, 1, 1, 0.08); f.top:SetHeight(1)
        f.top:SetPoint("TOPLEFT", 1, 0); f.top:SetPoint("TOPRIGHT", -1, 0)
        f.fs = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f.fs:SetPoint("LEFT", LIST_BLEED + 18, 0); Smaller(f.fs)
        f.fs:SetTextColor(0.7, 0.68, 0.64)
        f:SetScript("OnClick", function(self)
            L.collapsed[self.group] = not L.collapsed[self.group] or nil
            RefreshNodes()
        end)
        L.folds[i] = f
        return f
    end

    -- A trainer as its own small card: name (with its distance) on top, location in a dim strip
    -- underneath, and the price in a box on the right, vertically centered.
    local CARD_L, CARD_R = LIST_BLEED + 4, LIST_BLEED + 4 -- card inset from the list's left edge / right edge
    local function Row(i)
        local r = L.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, child)
        r:SetHeight(TR_ROW2)
        local function Inset(t)
            t:SetPoint("TOPLEFT", r, "TOPLEFT", CARD_L, -2)
            t:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -CARD_R, 2)
            return t
        end
        -- The profession's card art inside each trainer card (under the card's tint).
        r.art = r:CreateTexture(nil, "BACKGROUND", nil, -2)
        r.art:SetPoint("TOPRIGHT", r, "TOPRIGHT", -CARD_R, -2)
        r.bg = Inset(r:CreateTexture(nil, "BACKGROUND"))
        r.near = Inset(r:CreateTexture(nil, "BACKGROUND", nil, 1))
        -- A raised face: a soft sheen on the upper half, a shade on the lower one.
        r.sheen = r:CreateTexture(nil, "BACKGROUND", nil, 2)
        r.sheen:SetPoint("TOPLEFT", r, "TOPLEFT", CARD_L, -2)
        r.sheen:SetPoint("TOPRIGHT", r, "TOPRIGHT", -CARD_R, -2)
        r.sheen:SetHeight((TR_ROW2 - 4) * 0.5)
        r.sheen:SetColorTexture(1, 1, 1, 1)
        r.shade = r:CreateTexture(nil, "BACKGROUND", nil, 2)
        r.shade:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", CARD_L, 2)
        r.shade:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -CARD_R, 2)
        r.shade:SetHeight((TR_ROW2 - 4) * 0.45)
        r.shade:SetColorTexture(1, 1, 1, 1)
        if CreateColor and r.sheen.SetGradient then
            r.sheen:SetGradient("VERTICAL", CreateColor(1, 0.95, 0.85, 0), CreateColor(1, 0.95, 0.85, 0.07))
            r.shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.32), CreateColor(0, 0, 0, 0))
        else
            r.sheen:Hide(); r.shade:Hide()
        end
        -- Hover: a warm glow over the face (added light, so the picture brightens under it).
        r.hl = Inset(r:CreateTexture(nil, "HIGHLIGHT"))
        r.hl:SetColorTexture(1, 1, 1, 1)
        r.hl:SetBlendMode("ADD")
        if r.hl.SetGradient and CreateColor then
            r.hl:SetGradient("HORIZONTAL", CreateColor(1, 0.8, 0.45, 0.05), CreateColor(1, 0.8, 0.45, 0.14))
        else
            r.hl:SetVertexColor(1, 0.8, 0.45, 0.1)
        end
        -- Pressed: the face dips a little.
        r.press = Inset(r:CreateTexture(nil, "BACKGROUND", nil, 3))
        r.press:SetColorTexture(0, 0, 0, 0.22)
        r.press:Hide()
        r.edges = Outline(r, r.bg, BRONZE[1], BRONZE[2], BRONZE[3], 0) -- kept hidden; the ornate frame below is the edge
        -- The card's edge is the skill bar's own ornate frame, sliced so its corners keep their
        -- shape at the card's height (stretched as a whole where slicing isn't available).
        r.frameF = CreateFrame("Frame", nil, r)
        r.frameF:SetPoint("TOPLEFT", r.bg, "TOPLEFT", -2, 2)
        r.frameF:SetPoint("BOTTOMRIGHT", r.bg, "BOTTOMRIGHT", 2, -2)
        r.frameF:SetFrameLevel(r:GetFrameLevel() + 2)
        r.frame = r.frameF:CreateTexture(nil, "ARTWORK")
        r.frame:SetAllPoints()
        r.frame:SetAtlas("Profession-ProgressBar-frame", false)
        if r.frame.SetTextureSliceMargins then
            r.frame:SetTextureSliceMargins(18, 10, 18, 10)
            if r.frame.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
                r.frame:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            end
        end
        -- The pinned trainer's card gets a gold edge on its left.
        r.pinEdge = Fill(r, "ARTWORK", GOLD[1], GOLD[2], GOLD[3], 0.9)
        r.pinEdge:SetWidth(2)
        r.pinEdge:SetPoint("TOPLEFT", r.bg, "TOPLEFT", 0, 0); r.pinEdge:SetPoint("BOTTOMLEFT", r.bg, "BOTTOMLEFT", 0, 0)
        r.pinEdge:Hide()
        r.line = Fill(r, "BORDER", 1, 1, 1, 0); r.line:SetHeight(1)
        r.line:SetPoint("TOPLEFT"); r.line:SetPoint("TOPRIGHT")
        -- The pinned trainer: the game's map pin sitting on the card's left edge, drawn on its
        -- own layer above the card so it overlaps the border.
        r.pinF = CreateFrame("Frame", nil, r)
        r.pinF:SetSize(18, 18)
        r.pinF:SetFrameLevel(r:GetFrameLevel() + 5)
        r.pin = r.pinF:CreateTexture(nil, "OVERLAY")
        r.pin:SetAllPoints()
        if r.pin.SetAtlas then r.pin:SetAtlas("Waypoint-MapPin-Tracked") end
        r.pin:Hide()

        r.nameBox = ScrollBox(r)
        r.nameBox.fs:SetFontObject("GameFontNormal") -- the name reads a size up
        do local f, sz, fl = r.nameBox.fs:GetFont(); if f then r.nameBox.fs:SetFont(f, sz + 4.5, fl) end end
        -- Location strip.
        r.locBg = r:CreateTexture(nil, "BORDER"); r.locBg:Hide() -- no inner boxes inside the card
        r.locBg:SetColorTexture(0, 0, 0, 0.28)
        r.locBox = ScrollBox(r)
        r.locBox.fs:SetFontObject("GameFontHighlight") -- a touch over normal size, a step under the name
        do local f, sz, fl = r.locBox.fs:GetFont(); if f then r.locBox.fs:SetFont(f, sz + 0.5, fl) end end
        -- Kept for older layouts; unused in the card rows.
        r.distBox = ScrollBox(r); r.distBox:Hide()
        -- The distance: its own smaller, dim text just after the name.
        r.distF = CreateFrame("Frame", nil, r); r.distF:SetSize(1, 1)
        r.dist = r.distF:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.dist:SetTextColor(0.55, 0.54, 0.51); r.dist:SetWordWrap(false); Smaller(r.dist)

        -- Price box.
        r.priceBox = CreateFrame("Frame", nil, r)
        r.priceBox:SetHeight(24)
        -- (No box drawn around the price: just the coins, right-aligned and centered.)
        r.price = r.priceBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.price:SetPoint("RIGHT", 0, 0)
        -- Text and the price box sit above the ornate frame.
        for _, f in ipairs({ r.nameBox, r.locBox, r.priceBox, r.distF }) do f:SetFrameLevel(r:GetFrameLevel() + 3) end

        -- The frame lights up while hovered, back to its own tint after.
        local function FrameTint(self, lit)
            local c = self.frameTint or { 0.8, 0.8, 0.8 }
            local m = lit and 1.25 or 1
            self.frame:SetVertexColor(math.min(1, c[1] * m), math.min(1, c[2] * m), math.min(1, c[3] * m))
        end
        -- A vendor who sells the rank as an item (fishing's Expert book): the item's tooltip.
        local function ItemTip(self)
            local id = self.t and FN.TEACH_ITEM[self.t.teach]
            if not id or not GameTooltip.SetItemByID then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetItemByID(id)
            GameTooltip:Show()
        end
        r:SetScript("OnEnter", function(self) FrameTint(self, true); StartMarquee(self); ItemTip(self) end)
        r:SetScript("OnLeave", function(self)
            FrameTint(self, false); self.press:Hide(); StopMarquee(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        r:SetScript("OnMouseDown", function(self) self.press:Show() end)
        r:SetScript("OnMouseUp", function(self) self.press:Hide() end)
        r:SetScript("OnClick", function(self) FN:TogglePin(self.t, L.kind) end)
        L.rows[i] = r
        return r
    end

    function L:Place()
        local w = L.width or 300
        local innerL = CARD_L + 14
        local right = w + LIST_BLEED - CARD_R - 12
        for _, r in ipairs(L.rows) do
            local pw = math.ceil(r.price:GetStringWidth()) + 6
            r.priceBox:SetWidth(pw)
            r.priceBox:ClearAllPoints(); r.priceBox:SetPoint("RIGHT", r, "LEFT", right, 0)
            r.pinF:ClearAllPoints(); r.pinF:SetPoint("CENTER", r, "LEFT", CARD_L, 0) -- centered on the card's left edge
            local textRight = right - pw - 10
            -- Name, then its distance right after it; a long name gives way to the distance.
            local fs = r.nameBox.fs
            local nw = math.ceil(fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth())
            local dw = (r.dist:GetText() or "") ~= "" and math.ceil(r.dist:GetStringWidth()) + 6 or 0
            local avail = textRight - innerL
            local boxW = math.max(20, math.min(nw + 2, avail - dw))
            r.nameBox:ClearAllPoints(); r.nameBox:SetPoint("TOPLEFT", r, "TOPLEFT", innerL, -8)
            r.nameBox:SetSize(boxW, 21)
            r.distF:ClearAllPoints(); r.distF:SetPoint("TOPLEFT", r, "TOPLEFT", innerL + math.min(nw, boxW) + 6, -8)
            r.dist:ClearAllPoints(); r.dist:SetPoint("BOTTOMLEFT", r.distF, "TOPLEFT", 0, -18)
            local locX = innerL + 8
            r.locBox:ClearAllPoints(); r.locBox:SetPoint("TOPLEFT", r, "TOPLEFT", locX, -30)
            r.locBox:SetSize(math.max(20, textRight - locX), 17)
            r.locBg:ClearAllPoints()
            r.locBg:SetPoint("TOPLEFT", r, "TOPLEFT", locX - 4, -26)
            r.locBg:SetPoint("BOTTOMRIGHT", r, "TOPLEFT", textRight + 2, -42)
            -- Art: the card picture's top-right corner, sized to this card, fading in from the left.
            local cw, ch = w + LIST_BLEED - CARD_R - CARD_L, TR_ROW2 - 4
            if L.kind then
                CropAtlas(r.art, CARD_ATLAS[L.kind], cw, ch, 14, ART_DOWN[L.kind])
                r.art:SetAlpha(1)
                if r.art.SetGradient and CreateColor then
                    r.art:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.22), CreateColor(1, 1, 1, 0.95))
                end
            end
            r.nameBox:Edge(); r.locBox:Edge()
        end
    end

    -- While open, distances follow you: twice a second, and a row's text only changes when its
    -- shown value does (every yard under 1000, every 1000 above). Hovered rows wait, so their
    -- scrolling text isn't reset.
    local function NameText(r, yards)
        local t = r.t
        return (REACTION[t.reaction] or "|cffffffff") .. t.name .. "|r"
    end
    local function DistText(r, yards)
        local where = yards and Yards(yards) or r.where
        return where and ("(" .. where .. ")") or ""
    end
    L.DistText = DistText
    L.NameText = NameText
    local function Tick()
        if not L.open then return end
        for _, r in ipairs(L.rows) do
            if r:IsShown() and r.t and r.t.wx and not r:IsMouseOver() then
                local yards = FN:TrainerYards(r.t)
                local text = DistText(r, yards)
                if text ~= r.distText then
                    r.distText = text; r.dist:SetText(text)
                    L:Place()
                end
            end
        end
    end
    function L:Open()
        L.open = true
        if not L.ticker then L.ticker = C_Timer.NewTicker(0.5, Tick) end
        RefreshNodes()
    end
    -- A quest giver's mark follows the quest: redraw when picking it up or finishing it
    -- changes it (the quest log updates often, so only on a change).
    local questWatch, questWas = CreateFrame("Frame"), nil
    questWatch:RegisterEvent("QUEST_LOG_UPDATE")
    questWatch:SetScript("OnEvent", function()
        local state = FN:TeachQuestState({ teach = "quest" })
        if state == questWas then return end
        questWas = state
        if L.open and L.kind == "fish" then RefreshNodes() end
    end)
    function L:Close()
        if not L.open then return end
        L.open = false
        if L.ticker then L.ticker:Cancel(); L.ticker = nil end
        for _, r in ipairs(L.rows) do r:SetScript("OnUpdate", nil) end
        RefreshNodes()
    end

    -- Draws the list for `kind` at the top of the scroll area; returns its height (0 when closed).
    function L:Layout(kind, width)
        -- The section spans exactly what the skill bar does (the page's own width), starting at
        -- the page's left edge; inner offsets stay measured from the section's own left edge.
        width = (width or 300) - LIST_BLEED
        local shown = L.open and kind ~= nil
        local list, nxt
        if shown then list, nxt = FN:TrainersFor(kind) end
        if shown and not nxt then L.open = false; shown = false end
        -- No sort bar: two-line rows have no columns to sort, so the list is always nearest first.
        head:SetShown(shown); cols:Hide(); hide:SetShown(shown); card:SetShown(shown)
        if not shown then
            for _, r in ipairs(L.rows) do r:Hide() end
            for _, f in ipairs(L.folds) do f:Hide() end -- the continent lines go with the list
            return 0
        end
        L.kind, L.width = kind, width
        local learnedInfo = FN:GetSkillInfo(kind)
        head.label:SetText(learnedInfo and "Next rank:" or "Learn:")
        head.rank:SetText(nxt.name)
        head.count:SetText(#list .. (#list == 1 and " trainer" or " trainers"))

        -- Highlights: every trainer at the lowest price (green row and price), the closest one
        -- (soft white row); both get brighter location and distance text.
        local low = Cheapest(list)
        local closest = list[1]
        if trainerSort.by ~= "dist" or trainerSort.dir ~= 1 then
            local key = trainerSort.by
            table.sort(list, function(a, b)
                local x, y
                if key == "name" then x, y = a.name, b.name
                elseif key == "zone" then x, y = a.zone .. a.town, b.zone .. b.town
                elseif key == "price" then x, y = a.cost, b.cost
                else x, y = a.yards or 1e9, b.yards or 1e9 end
                if x == y then return a.name < b.name end
                if trainerSort.dir > 0 then return x < y else return x > y end
            end)
        end

        local y = 0
        -- Every band (title, columns, rows, Hide) spans the same width: pane border to the right edge.
        head:ClearAllPoints(); head:SetPoint("TOPLEFT", child, "TOPLEFT", LIST_BLEED, -y); head:SetWidth(width + LIST_BLEED); y = y + 65
        head.sort:SetRight(trainerSort.by == "price")
        local pinned = FN:PinnedTrainer()
        -- Distance sort: trainers on other continents fold away under one line per continent
        -- ("Kalimdor · 5 trainers"), open by default, and each can be folded away.
        local fold = trainerSort.by == "dist" and trainerSort.dir == 1
        local n, nf, zebra = 0, 0, false
        local lastGroup
        for _, t in ipairs(list) do
            local group = t.yards and "here" or t.continent
            if fold and t.yards == nil and group ~= lastGroup then
                nf = nf + 1
                local f = L.folds[nf] or L:NewFold(nf)
                local count = 0
                for _, o in ipairs(list) do if o.yards == nil and o.continent == group then count = count + 1 end end
                f.group = group
                f:ClearAllPoints(); f:SetPoint("TOPLEFT", child, "TOPLEFT", LIST_BLEED, -y); f:SetWidth(width + LIST_BLEED)
                local open = not L.collapsed[group]
                f.fs:SetText(group .. "  |cff6f6d68\194\183  " .. count .. (count == 1 and " trainer" or " trainers") .. "|r")
                f.arrow:SetText(open and "\226\128\147" or "+")
                f:Show()
                y = y + TR_ROW
                zebra = false
            end
            lastGroup = group
            if not (fold and t.yards == nil and L.collapsed[group]) then
                n = n + 1
                local r = Row(n)
                r.t = t
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", child, "TOPLEFT", LIST_BLEED, -y); r:SetWidth(width + LIST_BLEED)
                local cheap, near = t.cost == low, t == closest
                -- Card fill: green-tinted for the cheapest, otherwise dark.
                r.bg:SetColorTexture(1, 1, 1, 1)
                if r.bg.SetGradient and CreateColor then
                    if cheap then
                        r.bg:SetGradient("HORIZONTAL", CreateColor(0.18, 0.55, 0.18, 0.22), CreateColor(0.25, 0.75, 0.25, 0.22))
                    else
                        r.bg:SetGradient("HORIZONTAL", CreateColor(0.05, 0.04, 0.03, 0.30), CreateColor(0, 0, 0, 0))
                    end
                end
                r.near:SetColorTexture(1, 1, 1, 1)
                if r.near.SetGradient and CreateColor then
                    r.near:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, near and 0.03 or 0), CreateColor(1, 1, 1, near and 0.08 or 0))
                end
                -- Frame tint: green for the cheapest, a touch brighter for the closest.
                r.frameTint = cheap and { 0.55, 1, 0.55 } or near and { 1, 1, 1 } or { 0.8, 0.8, 0.8 }
                local lit = r:IsMouseOver() and 1.25 or 1
                r.frame:SetVertexColor(math.min(1, r.frameTint[1] * lit), math.min(1, r.frameTint[2] * lit), math.min(1, r.frameTint[3] * lit))
                r.line:SetColorTexture(1, 1, 1, 0)
                zebra = not zebra

                r.pin:SetShown(pinned == t.name)
                r.pinEdge:Hide() -- the pin icon on the edge marks it now
                -- Name (reaction color) with its distance, or its continent when far away, dim after it.
                r.where = (not t.yards and not fold) and t.continent or nil
                r.nameText = L.NameText(r, t.yards)
                r.nameBox:SetText(r.nameText)
                r.distText = L.DistText(r, t.yards); r.dist:SetText(r.distText)
                local bright = cheap or near
                r.locBox:SetText(t.zone .. (t.town ~= "" and (" " .. LOC_DIM .. "(" .. t.town .. ")|r") or ""))
                if bright then r.locBox.fs:SetTextColor(0.86, 0.85, 0.82) else r.locBox.fs:SetTextColor(0.62, 0.6, 0.56) end
                -- The game's coin icons, in their box. Red when you can't afford it, green for the cheapest.
                -- Fishing's Artisan rank is a quest, not a purchase.
                local price = t.teach == "quest" and QuestPrice(t) or Money(t.cost)
                if t.cost > 0 and not Affordable(t.cost) then price = "|cffff3030" .. price .. "|r"
                elseif t.cost > 0 and cheap then price = "|cff40ff40" .. price .. "|r" end
                r.price:SetText(price)
                r:Show()
                y = y + TR_ROW2
            end
        end
        for i = nf + 1, #L.folds do L.folds[i]:Hide() end
        for i = n + 1, #L.rows do L.rows[i]:Hide() end
        hide:ClearAllPoints(); hide:SetPoint("TOPLEFT", child, "TOPLEFT", LIST_BLEED, -y); hide:SetWidth(width + LIST_BLEED); y = y + 28
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", child, "TOPLEFT", LIST_BLEED, 0)
        card:SetSize(width + LIST_BLEED, y)
        L:Place()
        return y + 10 -- a little air before the node list starts
    end
    return L
end

local function BuildNodesPage(page)
    nodesPage.frame = page

    nodesPage.title = Label(page, "GameFontNormalLarge")
    nodesPage.title:SetPoint("TOPLEFT", 2, -3)

    -- Undo for Clear Selection / Select All only. The first of those clicks remembers what was
    -- ticked; more of them keep that first memory; Undo puts it back. Ticking a node by hand
    -- (or a reload) forgets it. { [node key] = was ticked }, for the nodes those clicks changed.
    local undo = nil
    local function SetAll(state)
        for _, node in ipairs(nodesPage.list or {}) do
            undo = undo or {}
            if undo[node.key] == nil then undo[node.key] = FN.enabled[node.key] and true or false end
            FN.enabled[node.key] = state or nil
        end
        FN:Refresh()
        RefreshNodes()
    end
    function nodesPage:ForgetUndo()
        if undo then undo = nil; RefreshNodes() end
    end
    -- True when the open list has something to undo.
    function nodesPage:CanUndo()
        if not undo then return false end
        for _, node in ipairs(self.list or {}) do
            if undo[node.key] ~= nil then return true end
        end
        return false
    end
    nodesPage.none = Card(page, "Clear Selection", 104, 24, function() SetAll(false) end)
    nodesPage.all = Card(page, "Select All", 76, 24, function() SetAll(true) end)
    nodesPage.all:SetPoint("TOPRIGHT")
    nodesPage.none:SetPoint("RIGHT", nodesPage.all, "LEFT", -4, 0)
    -- Undo: a small square with a back arrow, left of Clear Selection.
    local undoButton = Card(page, "", 24, 24, function()
        if not undo then return end
        for key, was in pairs(undo) do FN.enabled[key] = was or nil end
        undo = nil
        FN:Refresh()
        RefreshNodes()
    end)
    undoButton:SetPoint("RIGHT", nodesPage.none, "LEFT", -4, 0)
    if undoButton.text then undoButton.text:SetText("") end
    if undoButton.SetText then undoButton:SetText("") end
    local arrow = undoButton:CreateTexture(nil, "OVERLAY")
    arrow:SetPoint("CENTER")
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-icon-undo") then
        arrow:SetAtlas("common-icon-undo")
        arrow:SetSize(14, 14)
    else
        arrow:SetTexture("Interface\\Buttons\\UI-RefreshButton")
        arrow:SetSize(14, 14)
    end
    undoButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Undo")
        GameTooltip:AddLine("Puts back the ticks from before Clear Selection / Select All.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    undoButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    undoButton:Hide()
    nodesPage.undo = undoButton

    -- Sort: one button showing both choices, the active one lit; a click flips it.
    -- (PlaceSortToggle moves it to the side panel's top row when docked.)
    nodesPage.sortToggle = SortToggle(page, function()
        FN.db.sort = FN.db.sort == "name" and "level" or "name"
        RefreshNodes()
    end)
    nodesPage.sortLabel = Label(page, "GameFontDisableSmall", "Sort")
    nodesPage.sortLabel:SetPoint("RIGHT", nodesPage.sortToggle, "LEFT", -7, 0)

    nodesPage.rule = Fill(page, "ARTWORK", BRONZE[1], BRONZE[2], BRONZE[3], 0.35)
    nodesPage.rule:SetHeight(1)
    nodesPage.scroll = Scroller(page)
    nodesPage.scroll.fadeTop = 16

    nodesPage.fishNote = Label(page, "GameFontDisableSmall",
        "")
    -- "equipped" is green while a pole is in hand, red otherwise: a quick check that the addon sees it.
    function FN:UpdatePoleNote()
        local on = FN:PoleEquipped()
        nodesPage.fishNote:SetText("(Only shows when a |cffffffffFishing Pole|r is "
            .. (on and "|cff33ff33equipped|r" or "|cffff4040equipped|r") .. ")")
    end
    FN:UpdatePoleNote()
    -- placed under the list each time the list is drawn
    nodesPage.fishNote:SetJustifyH("CENTER")
    -- Under the note: a shortcut to the setting it is about.
    do
        local link = CreateFrame("Frame", nil, nodesPage.scroll.child)
        link:SetHeight(14)
        -- One line of text, so its spacing is the font's own; the button lies over the two words.
        local WORDS = "Settings > Behavior Tweaks"
        local line = Label(link, "GameFontDisableSmall")
        line:SetPoint("CENTER")
        line:SetTextColor(0.33, 0.33, 0.33)
        local function Paint(lit)
            line:SetText("(" .. (lit and ("|cffffd100" .. WORDS .. "|r") or WORDS) .. " to change this)")
        end
        Paint(false)
        local measure = Label(link, "GameFontDisableSmall")
        measure:SetAlpha(0)
        local go = CreateFrame("Button", nil, link)
        local function Fit()
            link:SetWidth(line:GetStringWidth())
            measure:SetText("(")
            local x = measure:GetStringWidth()
            measure:SetText(WORDS)
            go:ClearAllPoints()
            go:SetPoint("LEFT", line, "LEFT", x, 0)
            go:SetSize(measure:GetStringWidth(), 14)
        end
        Fit()
        link:SetScript("OnShow", Fit) -- the font may only be ready once it is on screen
        go:SetScript("OnEnter", function() Paint(true) end)
        go:SetScript("OnLeave", function() Paint(false) end)
        go:SetScript("OnClick", function() FN:ShowProfessionSettings() end)
        KeepChatFocus(go)
        nodesPage.fishLink = link
    end

    BuildHeader(nodesPage)
    BuildTrainers(nodesPage)
    -- The rank-line shimmer plays the first time its line scrolls into view.
    nodesPage.scroll:HookScript("OnMouseWheel", function() nodesPage.header:CheckShimmer() end)
    function nodesPage:OnListDrawn() self.header:CheckShimmer() end
end

-- Settings page ----------------------------------------------------------------

-- Two blocks of settings: side by side in the floating window, stacked when docked.
-- Each block is a stack of collapsible sections, so both heights change as
-- sections are opened and closed (and with which marker options are showing).
local COLUMN_A_HEIGHT, COLUMN_B_HEIGHT = 288, 472

local SECTION_WIDTH, SECTION_HEADER, SECTION_GAP = 250, 24, 8
local SECTION_PAD = 10 -- space inside an open section, above and below its contents
local SECTION_INSET = 8 -- space inside an open section's border, left and right of its contents

-- A collapsible section: a header bar in the style of the quest log's zone
-- headers (title on the left, + or - on the right) and a content frame under it.
-- Which sections are collapsed is remembered in the saved settings.
local function Section(column, key, title, height, onToggle)
    local section = { key = key, height = height }
    local stock = Stock()

    local header = CreateFrame("Button", nil, column)
    header:SetSize(SECTION_WIDTH, SECTION_HEADER)
    local fill = header:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    local hover = header:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.07)
    local text = Label(header, stock and "GameFontNormal" or "GameFontHighlight", title)
    text:SetPoint("LEFT", 8, 0)

    local sign -- the + / - on the right
    if stock then
        -- The quest log's brown bar with a thin gold edge, and its plain bright-yellow
        -- + / - (not a round button), as on the quest log's zone headers.
        for _, edge in ipairs(Outline(header, header, 1, 1, 1, 1)) do ToneTexture(edge, "edge") end
        text:SetTextColor(0.85, 0.82, 0.75)
        -- Hover as on the quest log: the title turns bright white, the bar stays as it is.
        hover:SetAlpha(0)
        header:SetScript("OnEnter", function() text:SetTextColor(1, 1, 1) end)
        header:SetScript("OnLeave", function() text:SetTextColor(0.85, 0.82, 0.75) end)
        -- The + / - are drawn as solid bars, bold like the quest log's (the font's
        -- own are thin, and its hyphen shorter than its plus): a crossbar, plus an
        -- upright for the +.
        local function Bar(width, height)
            local t = header:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(1, 0.82, 0)
            t:SetSize(width, height)
            t:SetPoint("CENTER", header, "RIGHT", -14, 0)
            return t
        end
        section.crossbar = Bar(11, 3)
        section.upright = Bar(3, 11)
        sign = header:CreateFontString(nil, "OVERLAY") -- unused in this look; kept so Paint stays simple
    else
        sign = Label(header, "GameFontNormalLarge")
        sign:SetPoint("RIGHT", -9, 0)
        sign:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    end

    ToneTexture(fill, "fill")

    local content = CreateFrame("Frame", nil, column)
    content:SetSize(SECTION_WIDTH - 2 * SECTION_INSET, height)
    section.header, section.content = header, content
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function(width)
        header:SetWidth(width)
        content:SetWidth(width - 2 * SECTION_INSET)
    end

    -- What stays at the top of the list with the header while the open section scrolls
    -- under it (Look & Feel's tabs): hung from the header, so it moves with it. Empty (and
    -- hidden) unless a section fills it and sets `pinHeight`.
    local pin = CreateFrame("Frame", nil, column)
    pin:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    pin:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
    pin:SetHeight(1)
    section.pin, section.pinHeight, section.pinned = pin, 0, 0
    -- Behind the header and its strip while they are held at the top, so the settings
    -- scrolling under them don't show through.
    local back = CreateFrame("Frame", nil, column)
    back:SetPoint("TOPLEFT", header, "TOPLEFT")
    back:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT")
    local backHead = ToneTexture(back:CreateTexture(nil, "BACKGROUND"), "backHead")
    backHead:SetPoint("TOPLEFT", header, "TOPLEFT")
    backHead:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT")
    local backStrip = ToneTexture(back:CreateTexture(nil, "BACKGROUND"), "back")
    backStrip:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 1, 0)
    backStrip:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", -1, 0)
    back:EnableMouse(true) -- (the settings hidden under it can't be clicked through it)
    back:Hide()
    -- Over the section's contents: the backing, then the strip, then the header. (Set again
    -- whenever it pins: the panel moving between layers can flatten these.)
    local function Raise()
        local base = column:GetFrameLevel()
        back:SetFrameLevel(base + 40)
        pin:SetFrameLevel(base + 41)
        header:SetFrameLevel(base + 42)
    end
    Raise()

    -- A thin border in the header bar's color around an open section's contents,
    -- under the header (which is its top). Placed by StackSections.
    local box = CreateFrame("Frame", nil, column)
    box:SetWidth(SECTION_WIDTH)
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function(width) box:SetWidth(width) end
    local edges = Outline(box, box, 1, 1, 1, 1)
    for _, edge in ipairs(edges) do ToneTexture(edge, "line") end
    edges[1]:Hide() -- the header is the top edge
    -- A very faint tint inside, so the open section reads as one block.
    local tint = ToneTexture(box:CreateTexture(nil, "BACKGROUND"), "tint")
    tint:SetAllPoints()
    section.box = box

    function section:IsCollapsed()
        return FN.db.collapsed[key] == true
    end
    function section:Paint()
        local collapsed = self:IsCollapsed()
        content:SetShown(not collapsed)
        box:SetShown(not collapsed)
        pin:SetShown(not collapsed and self.pinHeight > 0)
        if self.crossbar then
            -- Stock: drawn bars; the upright only on the +.
            self.crossbar:Show()
            self.upright:SetShown(collapsed)
        else
            sign:SetText(collapsed and "+" or "-")
        end
    end
    header:SetScript("OnClick", function()
        FN.db.collapsed[key] = (not section:IsCollapsed()) or nil
        onToggle(section)
    end)
    -- Holds the header (and its strip) `delta` lower than its place in the list: at the top of
    -- the list's view while the open section scrolls under it.
    function section:Pin(delta)
        delta = math.max(0, math.floor((delta or 0) + 0.5))
        if delta > 0 and back:GetFrameLevel() < column:GetFrameLevel() + 40 then Raise() end
        if delta == self.pinned then return end
        self.pinned = delta
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", column, "TOPLEFT", 0, (self.headerY or 0) - delta)
        back:SetShown(delta > 0)
    end
    return section
end

-- Stacks sections down `column`; returns the height they take. Each remembers where its
-- header is (headerY) and where it ends (bottomY), for pinning while the list scrolls. An open
-- section gets a little more room under it, unless it is the very last one (`lastColumn`).
local OPEN_GAP = 8
local function StackSections(column, sections, lastColumn)
    local y = 0
    for i, section in ipairs(sections) do
        section.pinned = nil -- (set again by the next pin update, which also hides the backing)
        section.headerY = y
        section.header:ClearAllPoints()
        section.header:SetPoint("TOPLEFT", column, "TOPLEFT", 0, y)
        section:Paint()
        y = y - SECTION_HEADER
        if not section:IsCollapsed() then
            -- Its pinned strip (if any) under the header, then the same padding above and below
            -- its contents, all inside its border.
            local pinH = section.pinHeight or 0
            section.pin:SetHeight(math.max(pinH, 0.1))
            section.box:ClearAllPoints()
            section.box:SetPoint("TOPLEFT", column, "TOPLEFT", 0, y)
            section.box:SetHeight(pinH + SECTION_PAD + section.height + SECTION_PAD)
            section.content:ClearAllPoints()
            section.content:SetPoint("TOPLEFT", column, "TOPLEFT", SECTION_INSET, y - pinH - SECTION_PAD)
            section.content:SetHeight(section.height)
            y = y - pinH - SECTION_PAD - section.height - SECTION_PAD
        end
        section.bottomY = y
        y = y - SECTION_GAP -- the same gap between every pair of headers
        if not section:IsCollapsed() and not (lastColumn and i == #sections) then y = y - OPEN_GAP end
    end
    return math.max(1, -y)
end

local function BuildSettingsPage(columnA, columnB)
    local db = FN.db
    -- Look & Feel's spacing, built on one unit (LOOK_PAD): a gold title sits that far from the
    -- section's edge and from the line above it, the last setting of a part ends that far above the
    -- next line, and the settings under a title sit twice that far in from both edges. Settings in
    -- a part are LOOK_GAP apart. (Positions inside the section's contents, which start SECTION_INSET
    -- in from its border.)
    local LOOK_PAD, LOOK_GAP = 12, 10
    local LOOK_TITLE_H = 14 -- a gold title's line of text
    local LOOK_TITLE_X = LOOK_PAD - SECTION_INSET
    local LOOK_IND = 2 * LOOK_PAD - SECTION_INSET
    -- Every section starts closed at each login or reload, so the whole list shows at a glance;
    -- while playing, the one left open stays open (closing and reopening the map keeps it).
    db.collapsed = { look = true, colors = true, tooltips = true, window = true }
    db.sectionsClosed122, db.tooltipsFolded = nil, nil -- no longer needed

    local function Bool(key, refresh)
        return function() return db[key] end, function(v)
            db[key] = v and true or false
            refresh()
        end
    end
    local function Number(key)
        return function() return db[key] end, function(v)
            db[key] = v
            FN:Restyle()
        end
    end
    local function ResyncAll()
        for i = 1, #syncers do syncers[i]() end
    end

    -- The three profession color swatches on one line, spread out evenly. Several sets show
    -- in different places; all edit the same colors and repaint together (FN:ColorsChanged).
    local profSwatchSets = {}
    local KIND_WORD = { herb = "Herbs", ore = "Mining", fish = "Fishing" }
    local function ProfSwatches(parent)
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetHeight(20)
        local list = {}
        for i, kind in ipairs(FN.kinds) do
            list[i] = Swatch(holder, KIND_WORD[kind], function() return db.colors[kind] end,
                function() return FN.defaults.colors[kind] end)
        end
        -- Where the first swatch starts across `width`, and the gap between them.
        function holder.FirstX(width)
            local total = 0
            for _, sw in ipairs(list) do total = total + sw:GetWidth() end
            local gap = math.max(8, math.floor((width - total) / (#list + 1)))
            return math.max(0, math.floor((width - total - gap * (#list - 1)) / 2)), gap
        end
        -- Places the line at `y` across `width`; returns where what follows it starts.
        function holder.Place(y, width, shown, x)
            holder:SetShown(shown ~= false)
            if shown == false then return y end
            holder:ClearAllPoints()
            holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, -y)
            holder:SetWidth(width)
            local x, gap = holder.FirstX(width)
            for _, sw in ipairs(list) do
                sw:ClearAllPoints()
                sw:SetPoint("LEFT", holder, "LEFT", x, 0)
                x = x + sw:GetWidth() + gap
            end
            return y + 20 + LOOK_GAP
        end
        function holder.Sync()
            for _, sw in ipairs(list) do sw.Sync() end
        end
        profSwatchSets[#profSwatchSets + 1] = holder
        return holder
    end
    -- The difficulty colors, as a key: each color and what it means for a skill-up, from grey
    -- down to red. Shown only (not changeable yet); the same colors FN:DifficultyColor gives.
    -- They look like the profession swatches and line up with the first of them (`profSet`), so
    -- switching between the two choices doesn't move the first box or where the words start.
    local DIFF_KEY = {
        { 0.5, 0.5, 0.5, "No skill-up" }, { 0.25, 0.75, 0.25, "Rarely a skill-up" },
        { 1, 1, 0, "Usually a skill-up" }, { 1, 0.5, 0.25, "Always a skill-up" },
        { 1, 0.13, 0.13, "Too low to gather" },
    }
    local DIFF_ROW = 22
    local function DiffSwatches(parent, profSet)
        local holder = CreateFrame("Frame", nil, parent)
        local chips = {}
        for i, d in ipairs(DIFF_KEY) do
            local chip = Fill(holder, "ARTWORK", d[1], d[2], d[3], 1)
            chip:SetSize(26, 14)
            for _, edge in ipairs(Outline(holder, chip, 1, 1, 1, 1)) do ToneTexture(edge, "swatch") end
            local label = Label(holder, nil, d[4])
            label:SetPoint("LEFT", chip, "RIGHT", 7, 0)
            chips[i] = chip
        end
        -- One under another; returns where what follows it starts.
        function holder.Place(y, width, shown, x)
            holder:SetShown(shown ~= false)
            if shown == false then return y end
            holder:ClearAllPoints()
            holder:SetPoint("TOPLEFT", parent, "TOPLEFT", (x or 0) + profSet.FirstX(width), -y)
            holder:SetSize(width, #chips * DIFF_ROW)
            for i, chip in ipairs(chips) do
                chip:ClearAllPoints()
                -- (centered in its row, as a swatch is in its 20px button)
                chip:SetPoint("LEFT", holder, "TOPLEFT", 0, -((i - 1) * DIFF_ROW + 10))
            end
            return y + (#chips - 1) * DIFF_ROW + 20 + LOOK_GAP
        end
        return holder
    end
    -- Three choices in one row, splitting `width` evenly: Mode, and the color pickers.
    local function PlaceRow(cards, keys, y, width, selected, shown, x, gap)
        gap = gap or 4
        local w = math.floor((width - gap * (#keys - 1)) / #keys)
        for i, key in ipairs(keys) do
            local card = cards[key]
            card:SetShown(shown)
            if shown then
                card:SetWidth(w)
                card:SetSelected(selected == key)
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", (x or 0) + (i - 1) * (w + gap), -y)
            end
        end
    end

    -- Sections, top to bottom in each block. `Relayout(true)` also re-fits the window.
    local sectionsA, sectionsB = {}, {}
    local relayouting = false
    local function Relayout(refit)
        if relayouting then return end -- a fold closing while sections are restacked
        relayouting = true
        COLUMN_A_HEIGHT = StackSections(columnA, sectionsA, false)
        COLUMN_B_HEIGHT = StackSections(columnB, sectionsB, true)
        columnA:SetHeight(COLUMN_A_HEIGHT)
        columnB:SetHeight(COLUMN_B_HEIGHT)
        relayouting = false
        if refit and frame and frame:IsShown() then FN:UpdateDock() end
        FN:UpdateSettingsPins()
    end
    -- The open section's header (and its pinned strip) stays at the top of the list's view
    -- once it is scrolled up to there, until the section's own end comes up under it.
    function FN:UpdateSettingsPins()
        local child = columnA:GetParent()
        local sf = child and child:GetParent()
        local scroll = sf and sf.GetVerticalScroll and sf:GetVerticalScroll() or 0
        local childTop = child and child:GetTop()
        for _, set in ipairs({ { columnA, sectionsA }, { columnB, sectionsB } }) do
            local column, list = set[1], set[2]
            local columnTop = column:GetTop()
            local offset = (childTop and columnTop) and (childTop - columnTop) or 0 -- the column, down the list
            for _, section in ipairs(list) do
                local delta = 0
                if not section:IsCollapsed() and section.bottomY then
                    local top = offset - section.headerY
                    local room = (section.headerY - section.bottomY) - SECTION_HEADER - (section.pinHeight or 0)
                    delta = math.min(math.max(0, scroll - top), math.max(0, room))
                end
                section:Pin(delta)
            end
        end
    end
    -- One section open at a time: opening one closes the rest.
    local function Toggled(opened)
        if opened and not opened:IsCollapsed() then
            for _, list in ipairs({ sectionsA, sectionsB }) do
                for _, other in ipairs(list) do
                    if other ~= opened then db.collapsed[other.key] = true end
                end
            end
        end
        Relayout(true)
    end
    -- Opens one section from elsewhere in the panel. Older names lead to where their settings
    -- went; a part inside a section can ask to be opened too (sectionOpeners).
    local sectionOpeners = {}
    local MOVED = { maps = "look", nearby = "look", lists = "colors" }
    function FN:OpenSettingsSection(key)
        if sectionOpeners[key] then sectionOpeners[key]() end
        key = MOVED[key] or key
        for _, list in ipairs({ sectionsA, sectionsB }) do
            for _, section in ipairs(list) do
                db.collapsed[section.key] = section.key ~= key or nil
            end
        end
        Relayout(true)
    end
    local function Add(list, column, key, title, height)
        local section = Section(column, key, title, height, Toggled)
        list[#list + 1] = section
        return section, section.content
    end

    -- Look & Feel ---------------------------------------------------------------
    -- (In its own block: the settings page has more parts than one function may name. What the
    -- Nearby nodes part below needs from it is named out here.)
    -- A gold title over a line across its whole section: the parts of a section. Every section
    -- lays its parts out on the same spacing (LOOK_PAD, LOOK_GAP).
    local function SubHead(parent, text, shift)
        shift = shift or 0
        local line = ToneLine(parent)
        line:SetHeight(1)
        local fs = Label(parent, "GameFontNormal", text)
        local head = {}
        -- Places it at `y` (or hides it); returns where what follows it starts.
        function head.Place(y, shown, first)
            line:SetShown(shown and not first)
            fs:SetShown(shown)
            if not shown then return y end
            if first then -- the first title in a tab: `y` is already a unit under the tabs
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", LOOK_TITLE_X - shift, -y)
                head.text = fs
                return y + LOOK_TITLE_H + LOOK_PAD
            end
            -- The line a unit under the last setting, the title a unit under the line, and the
            -- first setting a unit under the title.
            local lineY = y - LOOK_GAP + LOOK_PAD
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", parent, "TOPLEFT", -SECTION_INSET - shift, -lineY)
            line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", SECTION_INSET + shift, -lineY)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", LOOK_TITLE_X - shift, -(lineY + LOOK_PAD))
            head.text = fs
            return lineY + LOOK_PAD + LOOK_TITLE_H + LOOK_PAD
        end
        return head
    end
    -- A section's own width inside its border, following the section (wider when docked).
    local sectionInner = SECTION_WIDTH - 2 * SECTION_INSET
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function(width)
        sectionInner = width - 2 * SECTION_INSET
    end
    -- Where a section's first title goes: a unit under its header (the section itself leaves
    -- SECTION_PAD above its contents), and how tall a section is that ends at `y`.
    local SECTION_TOP = LOOK_PAD - SECTION_PAD
    local function SectionHeight(y) return math.max(1, y - LOOK_GAP + LOOK_PAD - SECTION_PAD) end

    local look, lookPage, PlaceLook, nearbyPage, nearby, PlacePreview, rangePage, PlaceRange
    do
    -- How nodes are drawn, in two folds: World Map and Minimap. Both start closed and only one is
    -- open at a time; the open one is the map the icon controls below edit. The minimap's fold
    -- also holds the nearby node marker. A node colors list follows whichever map uses it.
    look, lookPage = Add(sectionsA, columnA, "look", "Look & Feel", 60)
    local openPane = "world" -- the tab showing: "world", "minimap" or "nearby"
    local editing = "world" -- the map the icon controls edit: follows the tab
    local lookWidth = SECTION_WIDTH - 2 * SECTION_INSET -- follows the section (wider when docked)
    local function Look() return db.icons[editing] end
    local function LookNumber(key)
        return function() return Look()[key] end, function(v)
            Look()[key] = v
            FN:Restyle()
        end
    end

    -- One switch at the top picks what the section shows: World Map, Minimap or Colors (the
    -- profession colors). The map tabs set which map the shared icon controls edit.
    -- Folder tabs across the top of the section: the picked one is outlined and open at the
    -- bottom, running into what it holds; a line runs under the others.
    local PANES = { "world", "minimap", "nearby" }
    local TAB_NAMES = { "World Map", "Minimap", "Nearby" }
    local TAB_H = 26
    local TAB_GAP = 4 -- a little room between the section's header and its tabs
    local TAB_EDGE = { GOLD[1], GOLD[2], GOLD[3], 0.45 }
    local lookTabs = {}
    for i, pane in ipairs(PANES) do
        local t = CreateFrame("Button", nil, look.pin)
        t:SetHeight(TAB_H)
        t.bg = t:CreateTexture(nil, "BACKGROUND")
        t.bg:SetAllPoints()
        local hover = t:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.05)
        t.edges = Outline(t, t, TAB_EDGE[1], TAB_EDGE[2], TAB_EDGE[3], TAB_EDGE[4])
        t.edges[2]:Hide() -- no bottom: it opens into its settings
        t.text = Label(t, "GameFontNormal", TAB_NAMES[i])
        t.text:SetPoint("CENTER", 0, -1)
        t:SetScript("OnEnter", function()
            if openPane ~= pane then t.text:SetTextColor(1, 1, 1) end
        end)
        t:SetScript("OnLeave", function()
            if openPane ~= pane then t.text:SetTextColor(0.55, 0.55, 0.55) end
        end)
        t:SetScript("OnClick", function()
            openPane = pane
            if pane == "world" or pane == "minimap" then editing = pane end
            ResyncAll()
            Relayout(true)
        end)
        lookTabs[i] = t
    end
    local tabBaseL = Fill(look.pin, "BORDER", TAB_EDGE[1], TAB_EDGE[2], TAB_EDGE[3], TAB_EDGE[4])
    local tabBaseR = Fill(look.pin, "BORDER", TAB_EDGE[1], TAB_EDGE[2], TAB_EDGE[3], TAB_EDGE[4])
    tabBaseL:SetHeight(1)
    tabBaseR:SetHeight(1)
    -- The style picker's "Custom" opens the settings at the nearby node marker.
    sectionOpeners.nearby = function()
        openPane = "nearby"
        ResyncAll()
    end

    -- A gold heading inside a fold, under a line across the whole section.

    -- The icon controls, shared by both maps: shown under whichever fold is open.
    page = CreateFrame("Frame", nil, lookPage)
    local iconsPage = page
    local maps = { height = 1 }
    local LayoutMaps -- set below

    -- Whether nodes show on the open map at all; its wording names that map.
    local show = Check(page, "Enable minimap icons",
        function() return db[editing == "minimap" and "minimap" or "worldmap"] end,
        function(v)
            db[editing == "minimap" and "minimap" or "worldmap"] = v and true or false
            FN:Refresh()
        end)
    syncers[#syncers + 1] = function()
        show:SetLabel(editing == "minimap" and "Enable |cffffd100minimap|r icons"
            or "Enable |cffffd100world map|r icons")
    end

    -- World map: Normal (icons), Dot (small colored dots) or Dynamic (dots zoomed out, growing
    -- into icons as the map is zoomed in).
    local modeHead = SubHead(page, "Mode")
    local MODES = { "normal", "dot", "dynamic" }
    local modeCards = {}
    for _, choice in ipairs({ { "normal", "Normal" }, { "dot", "Dot" }, { "dynamic", "Dynamic" } }) do
        local card = Card(page, choice[2], 60, 22, function()
            if FN.openMapOn and db.openMapDynamic then return end -- set by OpenMap (see its tick box)
            db[FN:WorldModeKey()] = choice[1] -- with OpenMap and without are kept apart
            ResyncAll()
            Relayout(true)
            FN:Restyle()
        end)
        modeCards[choice[1]] = card
    end
    local MODE_HINT = {
        normal = "Node icons at a fixed size",
        dot = "Small dots, colored below",
        dynamic = "Dots zoomed out, icons zoomed in",
    }
    local modeHint = Label(page, "GameFontDisableSmall", "")
    modeHint:SetJustifyH("CENTER")
    if modeHint.SetWordWrap then modeHint:SetWordWrap(true) end
    -- With OpenMap: Dynamic by default (its zoomable map suits it); unticked, the mode above is used.
    local integrations = Label(page, "GameFontDisableSmall", "Integrations")
    local openMapCheck = Check(page, "|cffffd100OpenMap:|r Auto-enable |cffffd100Dynamic|r",
        function() return db.openMapDynamic end,
        function(v)
            db.openMapDynamic = v and true or false
            ResyncAll()
            Relayout(true)
            FN:Restyle()
        end)

    local generalHead = SubHead(page, "General")
    local shapeHead = SubHead(page, "Shape & Size")
    local roundCheck = Check(page, "Circular icons (crop to look cleaner)",
        function() return Look().round end,
        function(v)
            Look().round = v and true or false
            LayoutMaps()
            Relayout(true)
            FN:Restyle()
        end)
    local sizeSlider = Slider(page, "Icon size", 1, 32, 1, "%d", LookNumber("size"))
    local zoom = Slider(page, "Circular icon zoom", 1, 2.5, 0.05, "%.2fx", LookNumber("zoom"))
    local dotSize = Slider(page, "Dot size", 1, 16, 1, "%d", Number("worldDotSize"))
    local dotBorder = Check(page, "Dark border",
        function() return db.worldDotBorder end,
        function(v)
            db.worldDotBorder = v and true or false
            FN:Restyle()
        end)
    local dynHint = Label(page, "GameFontDisableSmall", "Dots and icons are sized from the map's zoom.")
    dynHint:SetJustifyH("LEFT")
    if dynHint.SetWordWrap then dynHint:SetWordWrap(true) end

    -- Minimap only: how far out icons draw, and its shape (where icons stop at the edge).
    local edge = Slider(page, "Draw range", 50, 125, 1, "%d%%", Number("minimapEdge"))
    local minimapShapeHead = SubHead(page, "Minimap Shape")
    local SHAPES = { "auto", "round", "square" }
    local shapeCards = {}
    for i, choice in ipairs({ "auto", "round", "square" }) do
        local card = Card(page, choice == "auto" and "Auto" or choice == "round" and "Round" or "Square", 54, 22,
            function()
                db.minimapShape = choice
                ResyncAll()
                Relayout(true)
            end)
        shapeCards[choice] = card
    end
    local detected = Label(page, "GameFontDisableSmall", "")

    -- World map dots (Dot mode, and Dynamic's zoomed-out dots): what colors them.
    local colorHead = SubHead(page, "Colors")
    local DOT_COLORS = { { "prof", "Profession" }, { "difficulty", "Difficulty" }, { "node", "Node type" },
        { "custom", "Custom" } }
    local dotColorCards = {}
    for _, choice in ipairs(DOT_COLORS) do
        dotColorCards[choice[1]] = Card(page, choice[2], 74, 22, function()
            db.worldDotColor = choice[1]
            ResyncAll()
            Relayout(true)
            FN:Restyle()
        end)
    end
    local DOT_KEYS = { "prof", "difficulty", "node", "custom" }
    local worldProfHead = SubHead(page, "Profession Colors")
    local worldProfColors = ProfSwatches(page)
    local worldDiffHead = SubHead(page, "Difficulty Colors")
    local worldDiffColors = DiffSwatches(page, worldProfColors)
    local worldCustomHead = SubHead(page, "Custom Color")
    local worldCustom = Swatch(page, "Custom color for |cffffd100world map|r dots",
        function() return db.worldDotCustom end, function() return FN.defaults.worldDotCustom end)
    local DOT_HINT = {
        prof = "Each profession's own color",
        difficulty = "Colored by your skill, like recipes",
        node = "Each node type's own color",
        custom = "One color for every dot",
    }
    local dotHint = Label(page, "GameFontDisableSmall", "")
    dotHint:SetJustifyH("CENTER")
    if dotHint.SetWordWrap then dotHint:SetWordWrap(true) end

    -- Lays out what the open map shows: no empty space for hidden controls.
    LayoutMaps = function()
        local width = lookWidth - 2 * LOOK_IND -- (in from both sides)
        local IND, GAP = LOOK_IND, LOOK_GAP
        local world = editing == "world"
        local mini = not world
        local mode = world and FN:WorldMode() or "normal"
        local dots, dynamicMode = mode == "dot", mode == "dynamic"
        local y
        -- Places a setting `height` tall at the current spot; the next one goes a gap under it.
        local function At(f, height, x)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", x or IND, -y)
            y = y + height + GAP
        end
        local function Text(fs, text)
            fs:SetText(text)
            fs:SetWidth(width)
            At(fs, math.ceil(fs:GetStringHeight()))
        end
        local function Sized(slider)
            slider:SetWidth(width)
            At(slider, 34)
        end

        y = generalHead.Place(0, true, true)
        At(show, 20)

        -- World map: the mode, then OpenMap's say in it.
        local openMap = world and FN.openMapOn
        local auto = openMap and db.openMapDynamic
        modeHint:SetShown(world)
        y = modeHead.Place(y, world)
        PlaceRow(modeCards, MODES, y, width, mode, world, IND, 6)
        if world then
            for _, card in pairs(modeCards) do
                card:SetAlpha(auto and 0.4 or 1)
                card:EnableMouse(not auto)
            end
            y = y + 22 + GAP
            Text(modeHint, auto and "Set by OpenMap (untick it below to choose)" or MODE_HINT[mode])
        end
        integrations:SetShown(openMap)
        openMapCheck:SetShown(openMap)
        if openMap then
            -- (its label sits close over its tick box)
            integrations:ClearAllPoints()
            integrations:SetPoint("TOPLEFT", IND, -y)
            y = y + math.ceil(integrations:GetStringHeight()) + 6
            At(openMapCheck, 20, IND + 12)
        end

        -- Shape & Size: icons (Normal, Dynamic's icons, the minimap), or Dot mode's dots.
        y = shapeHead.Place(y, true)
        dynHint:SetShown(dynamicMode)
        if dynamicMode then Text(dynHint, dynHint:GetText()) end
        dotSize:SetShown(dots)
        dotBorder:SetShown(dots)
        if dots then
            Sized(dotSize)
            At(dotBorder, 20)
        end
        roundCheck:SetShown(not dots)
        sizeSlider:SetShown(not dots and not dynamicMode)
        if not dots then
            At(roundCheck, 20)
            if not dynamicMode then Sized(sizeSlider) end
        end
        local round = not dots and Look().round
        zoom:SetShown(round) -- only meaningful for circular icons
        if round then Sized(zoom) end
        edge:SetShown(mini)
        detected:SetShown(mini)
        if mini then Sized(edge) end

        -- Minimap Shape: where icons stop at the minimap's edge.
        y = minimapShapeHead.Place(y, mini)
        PlaceRow(shapeCards, SHAPES, y, width, db.minimapShape, mini, IND, 6)
        if mini then
            -- What was found, at the right on its title's line.
            local name = FN:DetectedMinimapShape()
            detected:SetText("Detected: " .. (name == "ROUND" and "round" or name == "SQUARE" and "square" or name:lower()))
            detected:ClearAllPoints()
            detected:SetPoint("TOPRIGHT", iconsPage, "TOPRIGHT", -IND, -(y - LOOK_PAD - LOOK_TITLE_H + 2))
            y = y + 22 + GAP
        end

        -- Colors: world map dots only (Normal mode draws icons).
        local colored = world and not (mode == "normal")
        y = colorHead.Place(y, colored)
        dotHint:SetShown(colored)
        PlaceRow(dotColorCards, DOT_KEYS, y, width, db.worldDotColor, colored, IND, 6)
        if colored then
            y = y + 22 + GAP
            Text(dotHint, DOT_HINT[db.worldDotColor] or DOT_HINT.prof)
        end
        -- The chosen color's own section (Node type's list is placed after this, by PlaceLook).
        local pick = colored and db.worldDotColor
        y = worldProfHead.Place(y, pick == "prof")
        y = worldProfColors.Place(y, width, pick == "prof", IND)
        y = worldDiffHead.Place(y, pick == "difficulty")
        y = worldDiffColors.Place(y, width, pick == "difficulty", IND)
        y = worldCustomHead.Place(y, pick == "custom")
        worldCustom:SetShown(pick == "custom")
        if pick == "custom" then
            -- (lined up with the first profession swatch, like the difficulty key)
            worldCustom:ClearAllPoints()
            worldCustom:SetPoint("TOPLEFT", iconsPage, "TOPLEFT", IND + worldProfColors.FirstX(width), -y)
            y = y + 20 + GAP
        end
        maps.height = y
        if PlaceLook then PlaceLook() end
    end
    syncers[#syncers + 1] = LayoutMaps

    -- Node colors: every herb, ore and pool with its color, in one fold per profession. Shown
    -- under the world map's Colors when dots are colored by node type, and under the nearby
    -- marker when a part of it is. Picking a color saves it (Reset forgets every pick).
    local nodeList = CreateFrame("Frame", nil, lookPage)
    nodeList.height = 1
    local KIND_TITLE = { herb = "Herbs", ore = "Ores", fish = "Fish Pools" }
    local NODE_ROW = 17
    local groupOpen = {}
    local groupHeads, nodeSwatches = {}, {}
    local function GroupHead(kind)
        local b = CreateFrame("Button", nil, nodeList)
        b:SetHeight(20)
        local hover = b:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.05)
        b.name = Label(b, "GameFontHighlight", KIND_TITLE[kind] or kind)
        b.name:SetPoint("LEFT", 2, 0)
        b.count = Label(b, "GameFontDisableSmall", "")
        b.count:SetPoint("RIGHT", -2, 0)
        local under = ToneLine(b)
        under:SetHeight(1)
        under:SetPoint("BOTTOMLEFT")
        under:SetPoint("BOTTOMRIGHT")
        b:SetScript("OnClick", function()
            groupOpen[kind] = not groupOpen[kind] or nil
            ResyncAll()
            Relayout(true)
        end)
        return b
    end
    -- A name cut short by its column shows in full while hovered: the same text, in the same
    -- place and font, in a box just big enough for it, over whatever is beside it.
    local nameTip = CreateFrame("Frame", nil, nodeList)
    nameTip:SetFrameLevel(nodeList:GetFrameLevel() + 30)
    ToneTexture(nameTip:CreateTexture(nil, "BACKGROUND"), "back"):SetAllPoints()
    Outline(nameTip, nameTip, GOLD[1], GOLD[2], GOLD[3], 0.35)
    local nameTipText = nameTip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameTip:Hide()
    local function RevealName(fs, text)
        local full = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
        if full <= fs:GetWidth() + 0.5 then return end -- (it all fits)
        nameTipText:SetText(text)
        nameTipText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        nameTipText:ClearAllPoints()
        nameTipText:SetPoint("LEFT", fs, "LEFT", 0, 0)
        nameTip:ClearAllPoints()
        nameTip:SetPoint("TOPLEFT", nameTipText, "TOPLEFT", -3, 2)
        nameTip:SetPoint("BOTTOMRIGHT", nameTipText, "BOTTOMRIGHT", 3, -2)
        nameTip:SetFrameLevel(nodeList:GetFrameLevel() + 30) -- (over the names beside it)
        nameTip:Show()
    end
    local pickedNode -- the node whose color the picker is open on
    -- A node left at its own default (Default clicked) forgets its saved pick, so it follows the
    -- default again (a later update may change it). Done as its edit ends.
    local function ForgetIfDefault(node)
        local saved, own = node and db.nodeColors[node.key], node and FN.NODE_COLORS[node.key]
        if saved and own and math.abs(saved[1] - own[1]) < 0.002 and math.abs(saved[2] - own[2]) < 0.002
            and math.abs(saved[3] - own[3]) < 0.002 then
            db.nodeColors[node.key] = nil
        end
    end
    local function NodeSwatch(node)
        local b = CreateFrame("Button", nil, nodeList)
        b:SetHeight(NODE_ROW)
        local chip = Fill(b, "ARTWORK", 1, 1, 1)
        chip:SetSize(10, 10)
        chip:SetPoint("LEFT", 1, 0)
        for _, e in ipairs(Outline(b, chip, 1, 1, 1, 1)) do ToneTexture(e, "swatch") end
        local fs = Label(b, "GameFontHighlightSmall", node.name)
        fs:SetPoint("LEFT", chip, "RIGHT", 6, 0)
        fs:SetPoint("RIGHT", b, "RIGHT", -2, 0)
        fs:SetJustifyH("LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        function b.Sync()
            local c = FN:NodeColor(node)
            chip:SetColorTexture(c[1], c[2], c[3], 1)
        end
        b:SetScript("OnEnter", function()
            fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            RevealName(fs, node.name)
        end)
        b:SetScript("OnLeave", function()
            fs:SetTextColor(1, 1, 1)
            nameTip:Hide()
        end)
        b:HookScript("OnHide", function() nameTip:Hide() end)
        b:SetScript("OnClick", function()
            ForgetIfDefault(pickedNode) -- (the edit before, if the picker was still open on it)
            pickedNode = node
            PickColor(FN:EditNodeColor(node), function()
                b.Sync()
                FN:Restyle()
                if FN.MarkerPreview then FN:MarkerPreview() end
            end, function() return FN.NODE_COLORS[node.key] or db.colors[node.kind] end)
        end)
        return b
    end
    ColorPickerFrame:HookScript("OnHide", function()
        ForgetIfDefault(pickedNode)
        pickedNode = nil
    end)
    -- Reset asks first, in a small box of its own over the button (not the game's popups,
    -- which an addon can leave tainted for the game's own uses).
    -- (on the panel, so it shares its scale; over everything in it)
    local confirm = CreateFrame("Frame", nil, frame or UIParent)
    confirm:SetFrameStrata("FULLSCREEN_DIALOG")
    confirm:SetSize(250, 96)
    confirm:EnableMouse(true)
    confirm:Hide()
    -- (the darker brown, so it stands apart from the section under it)
    ToneTexture(confirm:CreateTexture(nil, "BACKGROUND"), "strip"):SetAllPoints()
    Outline(confirm, confirm, GOLD[1], GOLD[2], GOLD[3], 0.45)
    local ask = Label(confirm, "GameFontHighlight", "")
    ask:SetPoint("TOP", 0, -LOOK_PAD)
    local askNote = Label(confirm, "GameFontDisableSmall", "The colors you picked go back to their defaults.")
    askNote:SetJustifyH("CENTER")
    if askNote.SetWordWrap then askNote:SetWordWrap(true) end
    askNote:SetPoint("TOP", ask, "BOTTOM", 0, -4)
    local resetColors
    local resetKind -- what the box is asking about: "herb", "ore", "fish" or "all"
    -- The question, with what is being reset in its profession's color (ALL in red).
    local function Question(kind)
        local function Hex(c) return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
        if kind == "all" then return "Reset |cffff4040ALL|r node colors?" end
        local word = kind == "herb" and "herb" or kind == "ore" and "ore" or "fish pool"
        return "Reset all " .. Hex(db.colors[kind]) .. word .. "|r colors?"
    end
    local yes = Card(confirm, "Reset", 100, 22, function()
        confirm:Hide()
        -- Forgets the picks for that profession's nodes (or all of them).
        local kindOf = {}
        for _, node in ipairs(FN.nodes) do kindOf[node.key] = node.kind end
        for key in pairs(db.nodeColors) do
            if resetKind == "all" or kindOf[key] == resetKind then db.nodeColors[key] = nil end
        end
        ResyncAll()
        FN:Restyle()
        if FN.MarkerPreview then FN:MarkerPreview() end
    end)
    yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -4, LOOK_PAD)
    local no = Card(confirm, "Cancel", 100, 22, function() confirm:Hide() end)
    no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 4, LOOK_PAD)
    local function Ask(kind)
        resetKind = kind
        ask:SetText(Question(kind))
        -- Sized to its words with a unit of room around them and the buttons, but never wider
        -- than the section (the note wraps instead), and centered over the list.
        local maxW = lookWidth + 2 * SECTION_INSET - 8
        local noteW = askNote.GetUnboundedStringWidth and askNote:GetUnboundedStringWidth() or askNote:GetStringWidth()
        local textW = math.min(math.max(ask:GetStringWidth(), noteW, 2 * 100 + 8), maxW - 2 * LOOK_PAD)
        askNote:SetWidth(textW)
        confirm:SetSize(math.ceil(textW) + 2 * LOOK_PAD,
            LOOK_PAD + math.ceil(ask:GetStringHeight()) + 4 + math.ceil(askNote:GetStringHeight())
            + LOOK_PAD + 22 + LOOK_PAD)
        local listX, buttonX = nodeList:GetCenter(), resetColors:GetCenter()
        confirm:ClearAllPoints()
        confirm:SetPoint("BOTTOM", resetColors, "TOP", (listX and buttonX) and (listX - buttonX) or 0, 6)
        -- Over everything in the panel (its layer can be reset when the panel moves layers).
        confirm:SetFrameStrata("FULLSCREEN_DIALOG")
        confirm:SetFrameLevel(math.min((frame and frame:GetFrameLevel() or 0) + 200, 9900))
        confirm:Show()
        confirm:Raise()
        yes:SetFrameLevel(confirm:GetFrameLevel() + 2)
        no:SetFrameLevel(confirm:GetFrameLevel() + 2)
    end
    -- "Reset node colors >": a short menu of what to reset, each in its profession's color
    -- (All Nodes in red), then the box above asks to be sure.
    -- What to reset: a small menu of its own under the button (the game's menus leave extra
    -- room at the bottom), even padding all round, each choice in its profession's color (ALL
    -- in red). A click anywhere else, or on the button again, closes it.
    local MENU_PAD, MENU_ROW = 6, 20
    local resetMenu = CreateFrame("Frame", nil, frame or UIParent)
    resetMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    resetMenu:EnableMouse(true)
    resetMenu:Hide()
    ToneTexture(resetMenu:CreateTexture(nil, "BACKGROUND"), "strip"):SetAllPoints()
    Outline(resetMenu, resetMenu, GOLD[1], GOLD[2], GOLD[3], 0.35)
    -- (catches a click anywhere else, under the menu, to close it)
    local menuCatcher = CreateFrame("Button", nil, UIParent)
    menuCatcher:SetAllPoints(UIParent)
    menuCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    menuCatcher:RegisterForClicks("AnyUp")
    menuCatcher:Hide()
    menuCatcher:SetScript("OnClick", function() resetMenu:Hide() end)
    resetMenu:SetScript("OnHide", function() menuCatcher:Hide() end)
    local menuRows = {}
    local function MenuRow(i, onClick)
        local row = CreateFrame("Button", nil, resetMenu)
        row:SetHeight(MENU_ROW)
        row:SetPoint("TOPLEFT", 1, -(MENU_PAD + (i - 1) * MENU_ROW))
        row:SetPoint("TOPRIGHT", -1, -(MENU_PAD + (i - 1) * MENU_ROW))
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.08)
        row.text = Label(row, "GameFontHighlight", "")
        row.text:SetPoint("LEFT", MENU_PAD + 4, 0)
        row:SetScript("OnClick", function()
            resetMenu:Hide()
            onClick()
        end)
        menuRows[i] = row
        return row
    end
    local MENU = { { "herb", "herbs" }, { "ore", "ores" }, { "fish", "fish pools" } }
    for i, entry in ipairs(MENU) do MenuRow(i, function() Ask(entry[1]) end) end
    MenuRow(#MENU + 1, function() Ask("all") end)
    local function ShowResetMenu()
        local function Hex(c) return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
        local widest = 0
        for i, entry in ipairs(MENU) do
            menuRows[i].text:SetText("Reset all " .. Hex(db.colors[entry[1]]) .. entry[2] .. "|r")
        end
        menuRows[#MENU + 1].text:SetText("Reset |cffff4040ALL nodes|r")
        for _, row in ipairs(menuRows) do widest = math.max(widest, row.text:GetStringWidth()) end
        resetMenu:SetSize(math.max(resetColors:GetWidth(), math.ceil(widest) + 2 * (MENU_PAD + 4) + 2),
            MENU_PAD + #menuRows * MENU_ROW + MENU_PAD)
        resetMenu:ClearAllPoints()
        resetMenu:SetPoint("TOPLEFT", resetColors, "BOTTOMLEFT", 0, -2)
        local level = math.min((frame and frame:GetFrameLevel() or 0) + 200, 9900)
        menuCatcher:SetFrameLevel(level)
        resetMenu:SetFrameLevel(level + 5)
        for _, row in ipairs(menuRows) do row:SetFrameLevel(level + 7) end
        menuCatcher:Show()
        resetMenu:Show()
    end
    resetColors = Card(nodeList, "Reset node colors", 144, 22, function()
        if confirm:IsShown() then confirm:Hide() return end
        if resetMenu:IsShown() then resetMenu:Hide() return end
        ShowResetMenu()
    end)
    -- (gone with the list, the tab or the panel)
    nodeList:HookScript("OnHide", function() resetMenu:Hide() end)
    -- Grey words (white on hover): a rarely needed button that shouldn't draw the eye. The words
    -- stay centered in the button; its ">" sits at the right end on its own, a little darker.
    if resetColors.SetNormalFontObject and resetColors.GetFontString and resetColors:GetFontString() then
        resetColors:SetNormalFontObject("GameFontDisableSmall")
    elseif resetColors.text then
        resetColors.text:SetTextColor(0.6, 0.6, 0.6)
    end
    local resetArrow = resetColors:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    resetArrow:SetText(">")
    resetArrow:SetTextColor(0.32, 0.32, 0.32)
    resetArrow:SetPoint("RIGHT", -6, 0)
    -- (gone with the list, the tab or the panel)
    nodeList:HookScript("OnHide", function() confirm:Hide() end)
    -- Types that are the same thing in better versions stay together, one under another in
    -- the same column (in the list's own order); the rest stand alone.
    local FAMILY = {
        chunk_of_amber = "amber", large_chunk_of_amber = "amber",
        silver_vein = "silver", truesilver_deposit = "silver", starsilver_vein = "silver",
        iron_deposit = "iron", cold_iron_deposit = "iron", dark_iron_deposit = "iron",
        gold_vein = "gold", fools_gold_vein = "gold",
        small_thorium_vein = "thorium", rich_thorium_vein = "thorium", heavy_thorium_vein = "thorium",
        small_obsidian_chunk = "obsidian", large_obsidian_chunk = "obsidian",
        sagefish_school = "sagefish", greater_sagefish_school = "sagefish",
        floating_debris = "floating", floating_wreckage = "floating", pool_floating_debris_wreckage = "floating",
    }
    -- Ores and fish pools are laid out by hand: ores with the usual progression down the left and
    -- the extras down the right; pools with the schools left and the floating ones right.
    local PLACE = {}
    for _, layout in ipairs({ {
        left = { "copper_vein", "tin_vein", "silver_vein", "truesilver_deposit", "starsilver_vein",
            "iron_deposit", "cold_iron_deposit", "dark_iron_deposit", "mithril_deposit",
            "small_thorium_vein", "rich_thorium_vein", "heavy_thorium_vein" },
        right = { "gold_vein", "fools_gold_vein", "chunk_of_amber", "large_chunk_of_amber",
            "incendicite_mineral_vein", "lesser_bloodstone_deposit", "greater_moonstone_formation",
            "small_obsidian_chunk", "large_obsidian_chunk" },
    }, {
        left = { "firefin_snapper_school", "oily_blackmouth_school", "sagefish_school", "greater_sagefish_school" },
        right = { "floating_debris", "floating_wreckage", "pool_floating_debris_wreckage" },
    } }) do
        for side, keys in pairs(layout) do
            for rank, key in ipairs(keys) do PLACE[key] = { side, rank } end
        end
    end
    -- Two columns: types laid out by hand (PLACE) in their places first; the rest split into
    -- their families (each in order), each family to the shorter column at the time.
    local function Columns(list)
        local left, right = {}, {}
        -- Herbs: in the list's own order (by skill), down the left column then down the right
        -- (the left one longer when it doesn't split evenly).
        if list[1] and list[1].kind == "herb" then
            local half = math.ceil(#list / 2)
            for i, node in ipairs(list) do
                local column = i <= half and left or right
                column[#column + 1] = node
            end
            return left, right
        end
        local placed = {}
        for _, node in ipairs(list) do
            if PLACE[node.key] then placed[#placed + 1] = node end
        end
        table.sort(placed, function(a, b) return PLACE[a.key][2] < PLACE[b.key][2] end)
        for _, node in ipairs(placed) do
            local column = PLACE[node.key][1] == "left" and left or right
            column[#column + 1] = node
        end
        local groups, byFamily = {}, {}
        for _, node in ipairs(list) do
            if not PLACE[node.key] then
                local family = FAMILY[node.key]
                local group = family and byFamily[family]
                if not group then
                    group = {}
                    groups[#groups + 1] = group
                    if family then byFamily[family] = group end
                end
                group[#group + 1] = node
            end
        end
        for _, group in ipairs(groups) do
            local column = #right < #left and right or left
            for _, node in ipairs(group) do column[#column + 1] = node end
        end
        return left, right
    end
    local function LayoutNodeList()
        local width = lookWidth - 2 * LOOK_IND
        local colW = math.floor((width - 10) / 2)
        local y = 0
        for _, kind in ipairs(FN.kinds) do
            local head = groupHeads[kind] or GroupHead(kind)
            groupHeads[kind] = head
            local c = db.colors[kind]
            head.name:SetTextColor(c[1], c[2], c[3])
            local list = {}
            for _, node in ipairs(FN.nodes) do
                if node.kind == kind then list[#list + 1] = node end
            end
            local open = groupOpen[kind]
            head.count:SetText(#list .. "   " .. (open and "-" or "+"))
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", 0, -y)
            head:SetWidth(width)
            y = y + 22
            -- An open group's list has room above it (under its line) and a touch more below it.
            local LIST_PAD = 6
            if open then y = y + LIST_PAD - 2 end
            local columns = { Columns(list) }
            for c, column in ipairs(columns) do
                for row, node in ipairs(column) do
                    local sw = nodeSwatches[node.key] or NodeSwatch(node)
                    nodeSwatches[node.key] = sw
                    sw:SetShown(open)
                    if open then
                        sw:ClearAllPoints()
                        sw:SetPoint("TOPLEFT", (c - 1) * (colW + 10), -(y + (row - 1) * NODE_ROW))
                        sw:SetWidth(colW)
                        sw.Sync()
                    end
                end
            end
            local rows = math.max(#columns[1], #columns[2])
            if open then y = y + rows * NODE_ROW + LIST_PAD + 3 end -- (a touch more below)
        end
        -- A unit of room above it, the same as under it to the section's edge (clear of the last
        -- group's row; each group's line ends 2px above `y`).
        resetColors:ClearAllPoints()
        resetColors:SetPoint("TOPRIGHT", 0, -(y + LOOK_PAD - 2))
        nodeList.height = y + LOOK_PAD - 2 + 22 + LOOK_GAP
    end
    local nodeHead = SubHead(lookPage, "Node Colors")
    -- Whether a part of the nearby marker takes the node type's color.
    local function MarkerUsesNode()
        return db.dotColorMode == "node" or db.dotEdgeColorMode == "node"
            or db.circleColorMode == "node" or db.circleEdgeColorMode == "node"
    end

    PlaceLook = function()
        local world, mini = openPane == "world", openPane == "minimap"
        local near = openPane == "nearby"
        -- The tabs sit flush under the section's header, border to border, in its pinned strip.
        local full = lookWidth + 2 * SECTION_INSET
        local tabW = full / #PANES
        local picked
        for i, t in ipairs(lookTabs) do
            local on = PANES[i] == openPane
            if on then picked = t end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", look.pin, "TOPLEFT", (i - 1) * tabW, -TAB_GAP)
            t:SetWidth(tabW)
            t.edges[1]:SetShown(on)
            t.edges[3]:SetShown(on and i > 1) -- (the section's own border is the outer side)
            t.edges[4]:SetShown(on and i < #PANES)
            if on then
                t.bg:SetColorTexture(1, 1, 1, 0.04)
                t.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else
                t.bg:SetColorTexture(0, 0, 0, 0.30)
                t.text:SetTextColor(0.55, 0.55, 0.55)
            end
        end
        tabBaseL:ClearAllPoints()
        tabBaseL:SetPoint("TOPLEFT", look.pin, "TOPLEFT", 0, -(TAB_GAP + TAB_H))
        tabBaseL:SetPoint("TOPRIGHT", picked, "BOTTOMLEFT", 0, 0)
        tabBaseL:SetShown(picked ~= lookTabs[1])
        tabBaseR:ClearAllPoints()
        tabBaseR:SetPoint("TOPLEFT", picked, "BOTTOMRIGHT", 0, 0)
        tabBaseR:SetPoint("TOPRIGHT", look.pin, "TOPRIGHT", 0, -(TAB_GAP + TAB_H))
        tabBaseR:SetShown(picked ~= lookTabs[#lookTabs])
        -- Pinned with the tabs: on Nearby, its preview too.
        local pinH = TAB_GAP + TAB_H
        if PlacePreview then pinH = PlacePreview(near and pinH or nil) or pinH end
        look.pinHeight = pinH
        -- (the first title a unit under the strip)
        local y = SECTION_TOP
        -- `inset`: in from both sides (the parts under a heading), or flush.
        local function Put(f, height, inset)
            local x = inset and LOOK_IND or 0
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", lookPage, "TOPLEFT", x, -y)
            f:SetPoint("TOPRIGHT", lookPage, "TOPRIGHT", -x, -y)
            f:SetHeight(math.max(1, height))
            y = y + height
        end
        iconsPage:SetShown(world or mini)
        if nearbyPage then nearbyPage:SetShown(near) end
        local listShown, nodeHeadShown = false, false
        if world then
            Put(iconsPage, maps.height)
            if db.worldDotColor == "node" and FN:WorldMode() ~= "normal" then
                LayoutNodeList()
                y = y + 4
                Put(nodeList, nodeList.height, true)
                listShown = true
            end
        elseif mini then
            Put(iconsPage, maps.height)
        elseif near then
            if nearbyPage then Put(nearbyPage, nearby.height, true) end
            if MarkerUsesNode() then
                y = nodeHead.Place(y, true)
                nodeHeadShown = true
                LayoutNodeList()
                Put(nodeList, nodeList.height, true)
                listShown = true
            end
        end
        if not nodeHeadShown then nodeHead.Place(y, false) end
        nodeList:SetShown(listShown)
        -- (the section adds SECTION_PAD under its contents)
        look.height = math.max(1, y - LOOK_GAP + LOOK_PAD - SECTION_PAD)
    end
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function(width)
        lookWidth = width - 2 * SECTION_INSET
        LayoutMaps()
    end
    end -- Look & Feel

    -- Behavior Tweaks -----------------------------------------------------------
    -- Which nodes show when, how the panel's list behaves, and which new spots are recorded.
    -- (The profession colors are in Look & Feel. Saved under the old "colors" key, so the
    -- shortcuts still open it.)
    local profSection
    profSection, page = Add(sectionsB, columnB, "colors", "Behavior Tweaks", 124)
    local profPage = page
    -- Labels that name a profession in its own color, repainted when a swatch changes.
    local recordLabels = {}
    local function Hex(kind)
        local c = db.colors[kind]
        local function Byte(v) return math.floor((v or 1) * 255 + 0.5) end
        return ("%02x%02x%02x"):format(Byte(c[1]), Byte(c[2]), Byte(c[3]))
    end
    local DIM = "|cff8d8b86"

    -- Showing: herbs need Find Herbs on and ore Find Minerals (characters without the spell see
    -- them anyway); pools only show while a fishing pole is equipped (off: always); nodes of
    -- professions the character lacks can be ticked and shown on the maps.
    local showingTitle = SubHead(profPage, "Showing")
    local tracked = Check(page, "(Herbs/Ore) Only while tracking",
        function() return db.onlyTracked end,
        function(v)
            db.onlyTracked = v and true or false
            FN:Refresh()
        end)
    local pole = Check(page, "(Fish pools) Only while pole equipped",
        function() return db.onlyPole end,
        function(v)
            db.onlyPole = v and true or false
            FN:Refresh()
            RefreshNodes()
        end)
    local unlearned = Check(page, "Allow tracking unlearned professions",
        function() return db.showAll end,
        function(v)
            db.showAll = v and true or false
            FN:Refresh()
            FN:RefreshOptions()
        end)
    local function PaintProf()
        tracked:SetLabel(DIM .. "(|r|cff" .. Hex("herb") .. "Herbs|r" .. DIM .. "/|r|cff" .. Hex("ore") .. "Ore|r" .. DIM .. ")|r Only while tracking")
        pole:SetLabel(DIM .. "(|r|cff" .. Hex("fish") .. "Fish pools|r" .. DIM .. ")|r Only while pole equipped")
    end
    syncers[#syncers + 1] = PaintProf
    recordLabels[#recordLabels + 1] = PaintProf

    -- Panel list: how the profession pages' node lists are sorted and colored.
    -- The gradient on "difficulty coloring": grey, green, yellow, orange, red, letter by letter.
    local function Gradient(text)
        local stops = { { 0.62, 0.62, 0.62 }, { 0.25, 0.75, 0.25 }, { 1, 1, 0 }, { 1, 0.5, 0.25 }, { 1, 0.13, 0.13 } }
        local out, n = {}, #text
        for i = 1, n do
            local p = (n > 1) and (i - 1) / (n - 1) * (#stops - 1) or 0
            local a = math.floor(p) + 1
            local b = math.min(a + 1, #stops)
            local f = p - (a - 1)
            local c = {}
            for j = 1, 3 do c[j] = stops[a][j] + (stops[b][j] - stops[a][j]) * f end
            out[#out + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), text:sub(i, i))
        end
        return table.concat(out)
    end
    local listTitle = SubHead(profPage, "Panel List")
    local listChecks = {
        Check(page, DIM .. "(Lvl sort)|r Separate nodes by profession tier",
            function() return db.cutoffs end,
            function(v) db.cutoffs = v and true or false; RefreshNodes() end),
        Check(page, DIM .. "(A-Z sort)|r Show nodes beyond my tier",
            function() return db.azShowBeyond end,
            function(v) db.azShowBeyond = v and true or false; RefreshNodes() end),
        Check(page, DIM .. "(|r|cffffd100Skill 300|r" .. DIM .. ")|r Mute " .. Gradient("difficulty coloring"),
            function() return db.muteAtMax end,
            function(v) db.muteAtMax = v and true or false; RefreshNodes() end),
    }
    -- Its own line under the Skill 300 option, which has no room for it beside the label.
    local muteHint = Label(page, "GameFontDisableSmall", "(doesn't affect tooltips)")
    muteHint:SetTextColor(0.42, 0.42, 0.42)

    -- Discovery: recording, one setting per profession. Each saves where a node was found (a
    -- herb or vein when it is gathered, a pool when loot comes out of it). The profession's word
    -- is in that profession's own color, and follows it when it changes.
    local discoveryTitle = SubHead(profPage, "Discovery")
    local recordChecks = {}
    for _, rec in ipairs({
        { key = "recordHerb", kind = "herb", before = "Record new ", word = "herb", after = " locations" },
        { key = "recordOre", kind = "ore", before = "Record new ", word = "mining", after = " locations" },
        { key = "record", kind = "fish", before = "Record new ", word = "fishing", after = " spots" },
    }) do
        local box = Check(page, rec.before .. rec.word .. rec.after, Bool(rec.key, function() end))
        recordChecks[#recordChecks + 1] = box
        local function Paint()
            box:SetLabel(rec.before .. "|cff" .. Hex(rec.kind) .. rec.word .. "|r" .. rec.after)
        end
        syncers[#syncers + 1] = Paint
        recordLabels[#recordLabels + 1] = Paint
    end
    -- While a color is being picked, the words follow it straight away.
    function FN:ColorsChanged()
        for i = 1, #recordLabels do recordLabels[i]() end
        for i = 1, #profSwatchSets do profSwatchSets[i].Sync() end
    end

    local function LayoutProf()
        local IND, GAP = LOOK_IND, LOOK_GAP
        local y
        local function At(f, height)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", IND, -y)
            y = y + height + GAP
        end
        y = showingTitle.Place(SECTION_TOP, true, true)
        At(tracked, 20)
        At(pole, 20)
        At(unlearned, 20)
        -- Nearby Range (made with the nearby marker's settings).
        if rangePage and PlaceRange then
            rangePage:ClearAllPoints()
            rangePage:SetPoint("TOPLEFT", profPage, "TOPLEFT", IND, -y)
            rangePage:SetPoint("TOPRIGHT", profPage, "TOPRIGHT", -IND, -y)
            local height = PlaceRange()
            rangePage:SetHeight(height)
            y = y + height
        end
        y = listTitle.Place(y, true)
        At(listChecks[1], 20)
        At(listChecks[2], 20)
        At(listChecks[3], 20)
        -- Its note right under the Skill 300 box's label.
        muteHint:ClearAllPoints()
        muteHint:SetPoint("TOPLEFT", IND + (Stock() and 29 or 21), -(y - GAP - 2))
        y = y + 8
        y = discoveryTitle.Place(y, true)
        for _, c in ipairs(recordChecks) do At(c, 20) end
        profSection.height = SectionHeight(y)
    end
    syncers[#syncers + 1] = LayoutProf
    LayoutProf()
    -- Tooltips -----------------------------------------------------------------
    -- Show Levels: which tooltips show levels at all. Customization: a switch picks which
    -- tooltip is being set up (world map, minimap or overworld), each with its own settings,
    -- and a sample tooltip follows every choice (hovering a menu entry previews it).
    -- (In its own block: the settings page has more parts than one function may name.)
    do
    local tipSection
    tipSection, page = Add(sectionsB, columnB, "tooltips", "Tooltips", 200)
    local tipPage = page
    local UpdateTips, LayoutTips -- set below; the controls call them
    local editingTip = "overworld"
    local hover -- { key, value } while a menu entry is hovered: shown in the preview only
    local function Cfg() return FN:TipCfg(editingTip) end

    -- Which tooltips show levels: one tick box each, for all of them at once.
    local TIP_CHECKS = { { "world", "World map tooltips" }, { "minimap", "Minimap tooltips" },
        { "overworld", "Overworld tooltips" } }
    local tipChecks = {}
    for i, t in ipairs(TIP_CHECKS) do
        local box = Check(page, t[2],
            function() return FN:TipCfg(t[1]).on end,
            function(v)
                FN:TipCfg(t[1]).on = v and true or false
                if t[1] == "world" then FN:Refresh() end
                UpdateTips()
            end)
        tipChecks[t[1]] = box
    end
    -- The minimap's herb is worked out from where the cursor is (the game hides its name).
    local miniTag = Label(tipChecks.minimap, "GameFontNormalSmall", "EXPERIMENTAL")
    miniTag:SetTextColor(1, 0.25, 0.25)
    do
        local font, size, flags = miniTag:GetFont()
        if font and size then miniTag:SetFont(font, math.max(size - 2, 8), flags) end
    end
    miniTag:SetPoint("LEFT", tipChecks.minimap, "RIGHT", 2, 0)
    local showTitle = SubHead(page, "Show Levels")
    local customTitle = SubHead(page, "Customization")
    local gatherParts = {} -- (the customization's parts)

    -- Which tooltip: one switch with three parts.
    local TARGETS = { "world", "minimap", "overworld" }
    local targetToggle = MultiToggle(page, { "World map", "Minimap", "Overworld" }, function(i)
        editingTip = TARGETS[i]
        hover = nil
        ResyncAll()
        LayoutTips()
        Relayout(true)
    end)

    -- A dropdown for one setting of the tooltip being edited. `entries` is a list of
    -- { value, text } or a function returning one (for wording that follows other choices).
    local function Dropdown(width, entries, key)
        local b = Card(page, "", width, 22, nil)
        local function List() return type(entries) == "function" and entries() or entries end
        local function Refresh()
            local v = Cfg()[key]
            local list = List()
            local text = list[1][2]
            for _, e in ipairs(list) do if e[1] == v then text = e[2] end end
            b.text:SetText(text)
        end
        local function Choose(v) Cfg()[key] = v; hover = nil; ResyncAll(); LayoutTips() end
        b:SetScript("OnClick", function(self)
            -- Clicking the button while its menu is open just closes it. (The click itself can
            -- already have closed the menu by the time we get here: a menu that closed a moment
            -- ago counts as "was open".)
            if self.menu and self.menu:IsShown() then
                self.menu:Hide()
                self.menu = nil
                return
            end
            if self.menuClosedAt and GetTime() - self.menuClosedAt < 0.25 then
                self.menuClosedAt = nil
                return
            end
            if MenuUtil and MenuUtil.CreateContextMenu then
                self.menu = MenuUtil.CreateContextMenu(self, function(_, root)
                    if root.SetMinimumWidth then root:SetMinimumWidth(self:GetWidth()) end
                    for _, e in ipairs(List()) do
                        local item = root:CreateRadio(e[2], function() return Cfg()[key] == e[1] end,
                            function() Choose(e[1]) end)
                        -- Hovering an entry shows it in the preview.
                        if item and item.SetOnEnter then
                            item:SetOnEnter(function() hover = { key, e[1] }; UpdateTips() end)
                            item:SetOnLeave(function() hover = nil; UpdateTips() end)
                        end
                    end
                end)
                local menu = self.menu
                -- Opened under the button, as wide as it, rather than wherever the cursor is.
                if menu and menu.ClearAllPoints then
                    menu:ClearAllPoints()
                    menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
                end
                if menu and menu.HookScript then
                    menu:HookScript("OnHide", function()
                        hover = nil
                        UpdateTips()
                        if self.menu == menu then self.menu = nil; self.menuClosedAt = GetTime() end
                    end)
                end
            else
                -- No menu system: step through the choices.
                local list, i = List(), 1
                for n, e in ipairs(list) do if e[1] == Cfg()[key] then i = n end end
                Choose(list[i % #list + 1][1])
            end
        end)
        syncers[#syncers + 1] = Refresh
        return b
    end

    -- Labelled rows: the label on the left, the dropdowns lined up in one column.
    local DD_X, DD_W = 84, 150
    local rows = {}
    local function Row(key, text, entries)
        local row = { key = key }
        row.label = Label(page, nil, text)
        row.dd = Dropdown(DD_W, entries, key)
        rows[#rows + 1] = row
        gatherParts[#gatherParts + 1] = row.label
        gatherParts[#gatherParts + 1] = row.dd
        return row
    end
    local attachRow = Row("attach", "Attach to", { { "name", "The node's name" }, { "skill", "The skill's name" } })
    local placeRow = Row("place", "Placement", { { "before", "Before" }, { "after", "After" } })
    Row("style", "Style", function()
        local after = Cfg().place == "after" or (editingTip == "minimap" and Cfg().attach ~= "skill")
        return {
            { "none", "Simple:  150" },
            { "round", "Rounded:  (150)" },
            { "square", "Squared:  [150]" },
            { "separator", after and "Separator:  Name | 150" or "Separator:  150 | Name" },
        }
    end)
    Row("color", "Color", function()
        return {
            { "level", "The level" },
            { "brackets", Cfg().style == "separator" and "Level and separator"
                or (Cfg().style == "none" and "The level" or "Level and brackets") },
            { "name", "The name" },
            { "line", "The whole line" },
            { "none", "No color" },
        }
    end)

    -- Text size: the world map tooltip is our own, so all of its lines can be set larger or
    -- smaller together.
    local sizeRow = Slider(page, "Text size", 8, 20, 1, "%d",
        function() return Cfg().size or 11 end,
        function(v) Cfg().size = v; LayoutTips(); Relayout(true) end) -- the preview grows with it
    sizeRow:SetHeight(20)
    sizeRow.label:ClearAllPoints(); sizeRow.label:SetPoint("LEFT")
    sizeRow.value:ClearAllPoints(); sizeRow.value:SetPoint("RIGHT")
    sizeRow.slider:ClearAllPoints()
    sizeRow.slider:SetPoint("LEFT", sizeRow, "LEFT", DD_X, 0)
    sizeRow.slider:SetPoint("RIGHT", sizeRow, "RIGHT", -30, 0)
    gatherParts[#gatherParts + 1] = sizeRow

    -- Preview: a sample tooltip for the one being edited.
    local box = CreateFrame("Frame", nil, page)
    box:SetSize(234, 52)
    local bg = Fill(box, "BACKGROUND", 0.03, 0.035, 0.055, 0.96); bg:SetAllPoints()
    Outline(box, box, 0.29, 0.3, 0.34, 1)
    local cap = Label(box, "GameFontDisableSmall", "PREVIEW"); cap:SetPoint("TOPRIGHT", -8, -6)
    local line1 = box:CreateFontString(nil, "OVERLAY", GameTooltipHeaderText and "GameTooltipHeaderText" or "GameFontNormal")
    line1:SetPoint("TOPLEFT", 10, -10)
    local line2 = box:CreateFontString(nil, "OVERLAY", GameTooltipText and "GameTooltipText" or "GameFontHighlightSmall")
    line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -3)
    gatherParts[#gatherParts + 1] = box

    local NAME_HEX = "|cffffd100"  -- the game's gold name
    local LEVEL_HEX = "|cffff8040" -- a sample difficulty color (orange)
    local SAMPLE = { name = "Liferoot", skill = 150, kind = "herb" }
    local SAMPLE2 = { name = "Kingsblood", skill = 125, kind = "herb" } -- the world map's second line
    local headerFont = GameTooltipHeaderText and GameTooltipHeaderText or GameFontNormal
    local textFont = GameTooltipText and GameTooltipText or GameFontHighlightSmall

    function UpdateTips()
        -- The settings being edited, with a hovered menu entry swapped in.
        local cfg = {}
        for k, v in pairs(Cfg()) do cfg[k] = v end
        if hover then cfg[hover[1]] = hover[2] end
        if editingTip == "minimap" and cfg.attach ~= "skill" then cfg.place = "after" end
        local skill = editingTip ~= "world" and cfg.attach == "skill"
        -- The world map's lines all take its text size; the others look like the game's.
        if editingTip == "world" then
            local path, _, flags = textFont:GetFont()
            line1:SetFont(path, cfg.size or 11, flags)
            line2:SetFont(path, cfg.size or 11, flags)
        else
            -- Explicit sizes stick over a font object, so set the game's sizes back explicitly.
            line1:SetFont(headerFont:GetFont())
            line2:SetFont(textFont:GetFont())
        end
        if not cfg.on then
            line1:SetText(NAME_HEX .. "Liferoot|r")
            line2:SetText(editingTip == "world" and "" or (LEVEL_HEX .. "Herbalism|r"))
        elseif editingTip == "world" then
            -- Two nodes under the cursor, one line each.
            line1:SetText(FN:FormatTipLine(SAMPLE2, "|cffffffffKingsblood|r", cfg, 1, 1, 0))
            line2:SetText(FN:FormatTipLine(SAMPLE, "|cffffffffLiferoot|r", cfg, 1, 0.5, 0.25))
        elseif skill then
            line1:SetText(NAME_HEX .. "Liferoot|r")
            line2:SetText(LEVEL_HEX .. FN:FormatSkillText(cfg, "150", "Herbalism") .. "|r")
        else
            -- The world map tooltip is our own (white text); the others keep the game's gold name.
            local name = editingTip == "world" and "|cffffffffLiferoot|r" or (NAME_HEX .. "Liferoot|r")
            line1:SetText(FN:FormatTipLine(SAMPLE, name, cfg, 1, 0.5, 0.25))
            line2:SetText(editingTip == "minimap" and "" or editingTip == "overworld" and (LEVEL_HEX .. "Herbalism|r") or "")
        end
        -- Tall enough for its lines at any text size (never less than it was).
        local h = 10 + line1:GetStringHeight() + 10
        if (line2:GetText() or "") ~= "" then h = h + 3 + line2:GetStringHeight() end
        box:SetHeight(math.max(52, math.ceil(h)))
    end

    function LayoutTips()
        local IND, GAP = LOOK_IND, LOOK_GAP
        local width = sectionInner - 2 * IND
        local y
        local function At(f, height, x)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", x or IND, -y)
            y = y + height + GAP
        end
        y = showTitle.Place(SECTION_TOP, true, true)
        for _, t in ipairs(TIP_CHECKS) do At(tipChecks[t[1]], 20) end

        -- Customization: the switch, the settings in rows, then the preview.
        y = customTitle.Place(y, true)
        for i, key in ipairs(TARGETS) do if key == editingTip then targetToggle:SetPick(i) end end
        targetToggle:ClearAllPoints()
        targetToggle:SetPoint("TOP", tipPage, "TOP", 0, -y)
        y = y + 22 + GAP
        local cfg = Cfg()
        local ROW_GAP = 6 -- rows of one list sit a little closer
        for _, row in ipairs(rows) do
            -- The world map tooltip is our own one-line list: nothing to attach to.
            local shown = not (row == attachRow and editingTip == "world")
            row.label:SetShown(shown)
            row.dd:SetShown(shown)
            if shown then
                row.label:ClearAllPoints()
                row.label:SetPoint("TOPLEFT", IND, -(y + 5))
                row.dd:SetWidth(width - DD_X)
                row.dd:ClearAllPoints()
                row.dd:SetPoint("TOPLEFT", IND + DD_X, -y)
                -- On the minimap's name line the level can only follow the name.
                local fixed = row == placeRow and editingTip == "minimap" and cfg.attach ~= "skill"
                row.label:SetAlpha(fixed and 0.4 or 1)
                row.dd:SetAlpha(fixed and 0.4 or 1)
                row.dd:EnableMouse(not fixed)
                y = y + 22 + ROW_GAP
            end
        end
        y = y - ROW_GAP + GAP
        sizeRow:SetShown(editingTip == "world")
        if editingTip == "world" then
            sizeRow:SetWidth(width)
            At(sizeRow, 20)
        end
        UpdateTips()
        box:SetWidth(width)
        At(box, box:GetHeight())
        tipSection.height = SectionHeight(y)
    end
    syncers[#syncers + 1] = function() LayoutTips() end
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function() LayoutTips() end
    LayoutTips()
    end -- Tooltips

    -- Nearby nodes -------------------------------------------------------------
    -- Inside Look & Feel's Minimap fold, under the icon settings (placed by PlaceLook).
    nearby = { height = 300 }
    page = CreateFrame("Frame", nil, lookPage)
    nearbyPage = page
    -- Range: its own frame, in Behavior Tweaks (placed by LayoutProf, after Showing).
    rangePage = CreateFrame("Frame", nil, profPage)
    page = rangePage
    local rangeLabel = Label(page, nil, "Range")
    rangeLabel:SetPoint("TOPLEFT", 0, -6)
    local range = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    range:SetSize(36, 20)
    range:SetPoint("LEFT", rangeLabel, "RIGHT", 12, 0)
    range:SetAutoFocus(false)
    range:SetNumeric(true)
    range:SetMaxLetters(3)
    local skin = Skin()
    if skin and skin.EditBox then skin.EditBox(range) end
    local function ApplyRange(self)
        local value = math.min(math.max(tonumber(self:GetText()) or FN.DEFAULT_RANGE, 0), 250)
        self:SetText(value)
        self:ClearFocus()
        if value ~= db.range then
            db.range = value
            FN:Refresh()
        end
    end
    range:SetScript("OnEnterPressed", ApplyRange)
    range:SetScript("OnEditFocusLost", ApplyRange)
    range:SetScript("OnEscapePressed", function(self)
        self:SetText(db.range)
        self:ClearFocus()
    end)
    syncers[#syncers + 1] = function() range:SetText(db.range) end
    local yards = Label(page, nil, "yds")
    yards:SetPoint("LEFT", range, "RIGHT", 6, 0)
    local hint = Label(page, "GameFontDisableSmall",
        "Within this range a node's minimap icon turns into the nearby marker. "
        .. "The game itself shows nodes from about 185-190 yds.")
    hint:SetJustifyH("CENTER")
    if hint.SetWordWrap then hint:SetWordWrap(true) end
    hint:SetPoint("TOPLEFT", 0, -29)
    page = nearbyPage

    -- Marker parts. A "Dot | Circle" switch picks which one is being set up. Each side shows a
    -- sample of the whole marker on a piece of map, the shape's own settings beside it, and its
    -- border's settings under a line, with the border's on/off box on the left.
    local LayoutMarkers -- set below; the controls call it
    local innerWidth = SECTION_WIDTH - 2 * SECTION_INSET - 2 * LOOK_IND -- follows the section (wider when docked; indented in Look & Feel)
    local ROW = 24     -- one settings row
    local LABEL_W = 56 -- row labels, then the control
    local VALUE_W = 34 -- a slider's value, at the right
    -- "Profession" color means each node's own profession's: the sample cycles through them.
    local previewColor = { 1, 1, 1 }
    local function Small(fs) fs:SetFontObject(GameFontHighlightSmall) end
    local function Refit()
        if LayoutMarkers then LayoutMarkers() end
        Relayout(true)
        FN:Restyle()
    end
    local function Line()
        local t = ToneLine(nearbyPage)
        t:SetHeight(1)
        return t
    end
    -- 2.25, 2.5, 3: no trailing zeros.
    local function Trim(v) return (("%.2f"):format(v):gsub("0+$", ""):gsub("%.$", "")) end

    -- A button that opens a short menu under itself. `entries` are { value, menu text,
    -- button text (optional), shorter button text for a narrow button (optional) }.
    local function MenuButton(entries, get, set)
        local b = Card(nearbyPage, "", 100, 22, nil)
        local function Refresh()
            local pick = entries[1]
            for _, e in ipairs(entries) do if e[1] == get() then pick = e end end
            local wide = b:GetWidth() >= 120
            b.text:SetText((wide and pick[3]) or pick[4] or pick[3] or pick[2])
        end
        b.Refresh = Refresh
        b:SetScript("OnClick", function(self)
            -- A click while the menu is open (or just closed by this click) only closes it.
            if self.menu and self.menu:IsShown() then
                self.menu:Hide()
                self.menu = nil
                return
            end
            if self.menuClosedAt and GetTime() - self.menuClosedAt < 0.25 then
                self.menuClosedAt = nil
                return
            end
            if MenuUtil and MenuUtil.CreateContextMenu then
                self.menu = MenuUtil.CreateContextMenu(self, function(_, root)
                    if root.SetMinimumWidth then root:SetMinimumWidth(self:GetWidth()) end
                    for _, e in ipairs(entries) do
                        root:CreateRadio(e[2], function() return get() == e[1] end, function()
                            set(e[1])
                            ResyncAll()
                            Refit()
                        end)
                    end
                end)
                local menu = self.menu
                if menu and menu.ClearAllPoints then
                    menu:ClearAllPoints()
                    menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
                end
                if menu and menu.HookScript then
                    menu:HookScript("OnHide", function()
                        if self.menu == menu then self.menu = nil; self.menuClosedAt = GetTime() end
                    end)
                end
            else
                -- No menu system: step through the choices.
                local i = 1
                for n, e in ipairs(entries) do if e[1] == get() then i = n end end
                set(entries[i % #entries + 1][1])
                ResyncAll()
                Refit()
            end
        end)
        syncers[#syncers + 1] = Refresh
        return b
    end

    -- Rows. Each is { label = fontstring or nil, frame, kind } placed by LayoutMarkers.
    local function SliderRow(text, minValue, maxValue, step, fmt, key)
        local holder = Slider(nearbyPage, text, minValue, maxValue, step, fmt, Number(key))
        holder:SetHeight(20)
        Small(holder.label)
        holder.label:ClearAllPoints(); holder.label:SetPoint("LEFT")
        holder.value:ClearAllPoints(); holder.value:SetPoint("RIGHT")
        holder.slider:ClearAllPoints()
        holder.slider:SetPoint("LEFT", holder, "LEFT", LABEL_W, 0)
        holder.slider:SetPoint("RIGHT", holder, "RIGHT", -VALUE_W, 0)
        return { frame = holder, kind = "slider" }
    end
    local function LabelFor(text)
        local fs = Label(nearbyPage, nil, text)
        Small(fs)
        return fs
    end
    -- On / off words: green while the part is on, red while it is off.
    local ON_COLOR, OFF_COLOR = { 0.35, 0.85, 0.35 }, { 0.9, 0.32, 0.32 }
    -- A part's on/off box, at the left of its block: "Dot", "Circle", "Border".
    local function OnOffBox(title, key)
        local box
        local function Paint()
            box.restColor = db[key] and ON_COLOR or OFF_COLOR
            if not box:IsMouseOver() then box.Rest() end
        end
        box = Check(nearbyPage, title, function() return db[key] end, function(v)
            db[key] = v and true or false
            Paint()
            Refit()
        end)
        syncers[#syncers + 1] = Paint
        Paint()
        box.key = key
        return box
    end
    -- One node type per profession, standing in for "node type" colors in the chip and sample.
    local SAMPLE_NODE = { herb = "peacebloom", ore = "copper_vein", fish = "sagefish_school" }
    local function SampleNodeColor(kind)
        return FN:NodeColor({ key = SAMPLE_NODE[kind], kind = kind })
    end
    -- Color: "Linked to Profession", "Linked to Node type" or "Custom", and a chip of the color in use beside it
    -- (the profession's, or the custom one to click and change).
    local function ColorRow(prefix)
        local modeKey, colorKey = prefix .. "ColorMode", prefix .. "Color"
        local button = MenuButton({
            { "prof", "Profession color", "|cff9d9d9dLinked to|r Profession", "Profession" },
            { "node", "Node type color", "|cff9d9d9dLinked to|r Node type", "Node type" },
            { "custom", "Custom color", "Custom" },
        }, function() return db[modeKey] end, function(v) db[modeKey] = v end)
        local swatch = Swatch(nearbyPage, "", function() return db[colorKey] end)
        swatch:SetPoint("LEFT", button, "RIGHT", 8, 0)
        local chip = CreateFrame("Frame", nil, nearbyPage)
        chip:SetSize(26, 14)
        chip:SetPoint("LEFT", button, "RIGHT", 8, 0)
        -- The profession colors side by side: every one a linked part can take.
        local stripes = {}
        local stripeW = 26 / #FN.kinds
        for i, kind in ipairs(FN.kinds) do
            local t = Fill(chip, "ARTWORK", 1, 1, 1)
            t:SetPoint("TOPLEFT", (i - 1) * stripeW, 0)
            t:SetSize(stripeW, 14)
            stripes[kind] = t
        end
        -- Edged like the dividing lines, darker than a clickable swatch's: this one is locked.
        local chipEdge = ToneTexture(chip:CreateTexture(nil, "BACKGROUND"), "chip")
        chipEdge:SetPoint("TOPLEFT", -1, 1)
        chipEdge:SetPoint("BOTTOMRIGHT", 1, -1)
        local row = { label = LabelFor("Color"), frame = button, kind = "menu", chipped = true }
        function row.SyncColor(visible)
            local custom = db[modeKey] == "custom"
            swatch:SetShown(visible and custom)
            chip:SetShown(visible and not custom)
            for kind, t in pairs(stripes) do
                local c = db[modeKey] == "node" and SampleNodeColor(kind) or db.colors[kind]
                t:SetColorTexture(c[1], c[2], c[3], 1)
            end
        end
        return row
    end

    -- The marker's four parts, top to bottom: each its on/off box, with its settings under it.
    local parts = {
        { box = OnOffBox("Circle", "circleOn"), rows = {
            SliderRow("Width", 0.5, 8, 0.5, "%.1f", "circleWidth"),
            SliderRow("Radius", 2, 20, 0.25, Trim, "circleRadius"),
        } },
        { box = OnOffBox("Circle Border", "circleEdgeOn"), rows = {
            ColorRow("circleEdge"),
            SliderRow("Width", 0.5, 4, 0.5, "%.1f", "circleEdgeWidth"),
            SliderRow("Radius", 0.5, 24, 0.25, Trim, "circleEdgeRadius"),
        } },
        { box = OnOffBox("Dot", "dotOn"), rows = {
            SliderRow("Size", 0, 12, 1, "%d", "dotSize"),
        } },
        { box = OnOffBox("Dot Border", "dotEdgeOn"), rows = {
            ColorRow("dotEdge"),
            SliderRow("Width", 0.5, 4, 0.5, "%.1f", "dotEdgeWidth"),
            SliderRow("Radius", 0.5, 15, 0.25, Trim, "dotEdgeRadius"),
        } },
    }

    -- The sample: a piece of map with the whole marker on it (dot, circle and both borders),
    -- drawn larger, but never so large that part of it is cut off.
    local PREVIEW_ZOOM = 2
    local preview = CreateFrame("Frame", nil, look.pin)
    local previewMap = preview:CreateTexture(nil, "BACKGROUND")
    previewMap:SetTexture(FN.MEDIA .. "preview_map")
    previewMap:SetAllPoints()
    Outline(preview, previewMap, 0, 0, 0, 1)
    local sample = CreateFrame("Frame", nil, preview)
    sample:SetPoint("CENTER")
    FN:MarkerTextures(sample)
    FN:MarkerGoldDot(sample) -- the game's own node dot, under the marker
    -- Each profession's color holds a moment, then blends into the next.
    local HOLD, BLEND = 1.2, 0.4
    local cycleAt, cycleIndex = 0, 1
    -- What the sample cycles through: the colors the part being set up can take.
    local SKILL_COLORS = { { 1, 0.5, 0.25 }, { 1, 1, 0 }, { 0.25, 0.75, 0.25 }, { 0.5, 0.5, 0.5 } }
    local function CycleList()
        local mode = db.dotColorMode
        if mode == "difficulty" then return SKILL_COLORS end
        local list = {}
        for i, kind in ipairs(FN.kinds) do
            list[i] = mode == "node" and SampleNodeColor(kind) or db.colors[kind]
        end
        return list
    end
    local function CycleColor()
        local list = CycleList()
        if cycleIndex > #list then cycleIndex = 1 end
        local a = list[cycleIndex]
        local b = list[cycleIndex % #list + 1]
        local t = math.max(0, cycleAt - HOLD) / BLEND
        for i = 1, 3 do previewColor[i] = a[i] + (b[i] - a[i]) * t end
    end
    preview:SetScript("OnUpdate", function(_, elapsed)
        local wasBlending = cycleAt > HOLD
        cycleAt = cycleAt + elapsed
        if cycleAt >= HOLD + BLEND then
            cycleAt = 0
            cycleIndex = cycleIndex % #CycleList() + 1
        elseif not wasBlending and cycleAt <= HOLD then
            return -- holding: nothing changes
        end
        FN:MarkerPreview()
    end)
    function FN:MarkerPreview()
        CycleColor()
        FN:DrawMarker(sample, previewColor, nil, previewColor, previewColor)
        local room = (preview:GetWidth() or 72) - 8
        local whole = math.max(sample:GetWidth(), 1)
        sample:SetScale(math.max(math.min(PREVIEW_ZOOM, room / whole), 0.5))
    end

    -- Color: one choice for the circle and the dot together (their borders keep their own), the
    -- world map's choices plus a custom color, under its own gold heading.
    local markerHead = SubHead(nearbyPage, "Marker", LOOK_IND)
    local rangeHead = SubHead(rangePage, "Nearby Range", LOOK_IND)
    local colorHead = SubHead(nearbyPage, "Color", LOOK_IND)
    local MARK_KEYS = { "prof", "difficulty", "node", "custom" }
    local markCards = {}
    for _, choice in ipairs({ { "prof", "Profession" }, { "difficulty", "Difficulty" }, { "node", "Node type" },
        { "custom", "Custom" } }) do
        markCards[choice[1]] = Card(nearbyPage, choice[2], 74, 22, function()
            db.dotColorMode, db.circleColorMode = choice[1], choice[1]
            -- Custom: one color for both (the circle takes the dot's).
            if choice[1] == "custom" then db.circleColor = db.dotColor end
            ResyncAll()
            Refit()
        end)
    end
    local markCustom = Swatch(nearbyPage, "Custom color for |cffffd100minimap|r circles/dots", function() return db.dotColor end)
    local MARK_HINT = {
        prof = "Each profession's own color",
        difficulty = "Colored by your skill, like recipes",
        node = "Each node type's own color",
        custom = "One color for every node",
    }
    local markHint = Label(nearbyPage, "GameFontDisableSmall", "")
    markHint:SetJustifyH("CENTER")
    if markHint.SetWordWrap then markHint:SetWordWrap(true) end
    local markProfHead = SubHead(nearbyPage, "Profession Colors", LOOK_IND)
    local markProfColors = ProfSwatches(nearbyPage)
    local markDiffHead = SubHead(nearbyPage, "Difficulty Colors", LOOK_IND)
    local markDiffColors = DiffSwatches(nearbyPage, markProfColors)
    local markCustomHead = SubHead(nearbyPage, "Custom Color", LOOK_IND)

    -- What the marker is, beside the sample.
    local previewTitle = Label(look.pin, "GameFontNormal", "Preview")
    local previewLine = ToneLine(look.pin) -- under the preview: what scrolls stops here
    previewLine:SetHeight(1)
    -- Its own darker strip, so it reads as apart from the settings (1px in, for the borders).
    local previewBg = ToneTexture(look.pin:CreateTexture(nil, "BACKGROUND"), "strip")
    local about = Label(look.pin, "GameFontDisableSmall",
        "Within range, a node's minimap icon fades and this marker shows instead, so the game's own "
        .. "node dot stays easy to see.")
    about:SetJustifyH("LEFT")
    about:SetJustifyV("TOP")
    if about.SetWordWrap then about:SetWordWrap(true) end

    -- Places one block of rows in the right-hand column, starting at `y`; returns its height.
    local function PlaceRows(rows, x, width, y, visible)
        for i, row in ipairs(rows) do
            local f, mid = row.frame, -(y + (i - 1) * ROW + ROW / 2)
            f:SetShown(visible)
            if row.label then row.label:SetShown(visible) end
            if row.SyncColor then row.SyncColor(visible) end
            if visible then
                f:ClearAllPoints()
                if row.label then
                    row.label:ClearAllPoints()
                    row.label:SetPoint("LEFT", nearbyPage, "TOPLEFT", x, mid)
                end
                if row.kind == "slider" then
                    f:SetPoint("LEFT", nearbyPage, "TOPLEFT", x, mid)
                    f:SetWidth(width)
                else
                    f:SetPoint("LEFT", nearbyPage, "TOPLEFT", x + LABEL_W, mid)
                    f:SetWidth(width - LABEL_W - (row.chipped and 34 or 0))
                    if f.Refresh then f.Refresh() end -- its wording can follow its width
                end
            end
        end
        return #rows * ROW
    end

    -- On top, a short description at the left and the sample at the right. Under them the four
    -- parts, each its on/off box with its settings under it (a line between the circle's and the
    -- dot's), then the range. Last, the Color heading and its choices.
    local ROWS_X = 24 -- the settings, in under their on/off box
    function LayoutMarkers()
        local GAP, PAD = LOOK_GAP, LOOK_PAD
        local y = 0

        -- Marker: the four parts, each its on/off box with its settings under it, the same
        -- room between each (no lines: the spacing parts them).
        y = markerHead.Place(y, true, true) -- (the preview's line is above it)
        for i, part in ipairs(parts) do
            if i > 1 then y = y + 8 end
            part.box:ClearAllPoints()
            part.box:SetPoint("TOPLEFT", 0, -y)
            y = y + 20 + GAP
            -- Its settings only while it is on: an unticked part is just its name.
            local on = db[part.box.key] and true or false
            local rowsHeight = PlaceRows(part.rows, ROWS_X, innerWidth - ROWS_X, y - 4, on)
            if on then y = y + rowsHeight - 4 + GAP end
        end

        -- Color: one choice for the circle and the dot.
        y = colorHead.Place(y, true)
        local mode = db.dotColorMode
        PlaceRow(markCards, MARK_KEYS, y, innerWidth, mode, true, 0, 6)
        y = y + 22 + GAP
        markHint:SetText(MARK_HINT[mode] or MARK_HINT.prof)
        markHint:SetWidth(innerWidth)
        markHint:ClearAllPoints()
        markHint:SetPoint("TOPLEFT", 0, -y)
        y = y + math.ceil(markHint:GetStringHeight()) + GAP
        -- The chosen color's own section (Node type's list is placed after this, by PlaceLook).
        y = markProfHead.Place(y, mode == "prof")
        y = markProfColors.Place(y, innerWidth, mode == "prof")
        y = markDiffHead.Place(y, mode == "difficulty")
        y = markDiffColors.Place(y, innerWidth, mode == "difficulty")
        y = markCustomHead.Place(y, mode == "custom")
        markCustom:SetShown(mode == "custom")
        if mode == "custom" then
            -- (lined up with the first profession swatch, like the difficulty key)
            markCustom:ClearAllPoints()
            markCustom:SetPoint("TOPLEFT", nearbyPage, "TOPLEFT", markProfColors.FirstX(innerWidth), -y)
            y = y + 20 + GAP
        end
        nearby.height = y
        if PlaceLook then PlaceLook() end
    end
    -- Preview, in Look & Feel's pinned strip under the tabs (from `top` down): its title, the
    -- sample at the left and what the marker is beside it (larger when the section has the
    -- room, docked). Returns where the strip ends; `top` nil hides it (other tabs).
    -- Range, in its own frame (placed by PlaceLook last in the tab): the game's own range,
    -- centered, then the box we switch at, "Range" before it and "yds" after. Returns its height.
    PlaceRange = function()
        local y = rangeHead.Place(0, true)
        hint:SetWidth(sectionInner - 2 * LOOK_IND)
        hint:ClearAllPoints()
        hint:SetPoint("TOP", rangePage, "TOP", 0, -y)
        local boxY = y + math.ceil(hint:GetStringHeight()) + 6
        range:ClearAllPoints()
        range:SetPoint("TOP", rangePage, "TOP", 0, -boxY)
        rangeLabel:ClearAllPoints()
        rangeLabel:SetPoint("RIGHT", range, "LEFT", -12, 0)
        return boxY + 20 + LOOK_GAP
    end
    PlacePreview = function(top)
        local shown = top ~= nil
        preview:SetShown(shown)
        about:SetShown(shown)
        previewTitle:SetShown(shown)
        previewLine:SetShown(shown)
        previewBg:SetShown(shown)
        if not shown then return nil end
        previewTitle:ClearAllPoints()
        previewTitle:SetPoint("TOPLEFT", look.pin, "TOPLEFT", LOOK_PAD, -(top + LOOK_PAD))
        local y = top + LOOK_PAD + LOOK_TITLE_H + LOOK_PAD
        local x = SECTION_INSET + LOOK_IND
        local size = innerWidth >= 300 and 80 or 64
        preview:SetSize(size, size)
        FN:MarkerPreview() -- fits the sample to the new size
        preview:ClearAllPoints()
        preview:SetPoint("TOPLEFT", look.pin, "TOPLEFT", x, -y)
        about:ClearAllPoints()
        about:SetPoint("TOPLEFT", look.pin, "TOPLEFT", x + size + 12, -(y + 2))
        about:SetWidth(innerWidth - size - 12)
        local bottom = y + math.max(size, math.ceil(about:GetStringHeight()) + 2) + LOOK_PAD
        previewLine:ClearAllPoints()
        previewLine:SetPoint("TOPLEFT", look.pin, "TOPLEFT", 0, -bottom)
        previewLine:SetPoint("TOPRIGHT", look.pin, "TOPRIGHT", 0, -bottom)
        previewBg:ClearAllPoints()
        previewBg:SetPoint("TOPLEFT", look.pin, "TOPLEFT", 1, -top)
        previewBg:SetPoint("BOTTOMRIGHT", look.pin, "TOPRIGHT", -1, -bottom)
        return bottom + 1
    end
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function(width)
        innerWidth = width - 2 * SECTION_INSET - 2 * LOOK_IND
        if LayoutMarkers then LayoutMarkers() end
    end
    syncers[#syncers + 1] = function()
        LayoutMarkers()
        FN:MarkerPreview()
    end
    recordLabels[#recordLabels + 1] = function() FN:MarkerPreview(); LayoutMarkers() end -- profession colors changed
    LayoutMarkers()

    -- Interface ----------------------------------------------------------------
    do
    local uiSection
    uiSection, page = Add(sectionsB, columnB, "window", "Interface", 368)
    local uiPage = page

    local panelTitle = SubHead(page, "Panel")
    local dockBox = Check(page, "Panel docked to world map", Bool("dock", function()
        FN:DockSettingChanged()
    end))
    local dockHint = Label(page, "GameFontDisableSmall", "(Uncheck for floating panel)")
    dockHint:SetTextColor(0.42, 0.42, 0.42)

    local themeTitle = SubHead(page, "Theme")
    -- Three buttons splitting the row, like Mode's.
    local TONES = { "auto", "brown", "dark" }
    local themeCards = {}
    for i, label in ipairs({ "Auto", "Native", "Dark" }) do
        themeCards[TONES[i]] = Card(page, label, 74, 22, function()
            db.tone = TONES[i]
            for n = 1, #toneFollowers do toneFollowers[n]() end
            FN:RefreshOptions()
        end)
    end

    -- The floating window and the docked panel each keep their own scale (scale and
    -- dockScale), so a size chosen for one never carries into the other. Both show; only the
    -- one in use can be changed. Scaling the docked panel's contents can spill them past it.
    local scaleTitle = SubHead(page, "Scale")
    local experimental = Label(page, "GameFontNormalSmall", "EXPERIMENTAL")
    experimental:SetTextColor(1, 0.25, 0.25)
    local font, size, flags = experimental:GetFont()
    if font and size then experimental:SetFont(font, math.max(size - 2, 8), flags) end -- a step smaller than the label
    local function ScaleSlider(text, key)
        return Slider(page, text, 0.7, 1.5, 0.05, "%.2fx",
            function() return db[key] end,
            function(v)
                db[key] = v
                frame:SetScale(v)
                FN:UpdateDock()
            end, true)
    end
    local dockedScale = ScaleSlider("Docked Panel", "dockScale")
    local floatingScale = ScaleSlider("Floating Panel", "scale")
    local function ScaleInUse()
        local docked = frame and frame.docked or false
        for holder, active in pairs({ [dockedScale] = docked, [floatingScale] = not docked }) do
            holder.slider:EnableMouse(active)
            holder:SetAlpha(active and 1 or 0.4)
            holder.Sync()
        end
    end
    syncers[#syncers + 1] = ScaleInUse
    local resetScale = Card(page, "Reset scaling", 110, 22, function()
        db.dockScale, db.scale = FN.defaults.dockScale, FN.defaults.scale
        frame:SetScale(frame.docked and db.dockScale or db.scale)
        FN:UpdateDock()
        ResyncAll()
    end)

    local buttonsTitle = SubHead(page, "Addon Buttons")
    local miniButton = Check(page, "Show the |cffffd100minimap|r button",
        function() return FN:MinimapButtonShown() end,
        function(v) FN:SetMinimapButtonShown(v and true or false) end)
    local mapButton = Check(page, "Show the |cffffd100world map|r button",
        function() return FN:MapButtonShown() end,
        function(v) FN:SetMapButtonShown(v and true or false) end)
    -- The button can always be dragged around the map; locked, it stays where it is.
    local lockButton = Check(page, "Lock the |cffffd100world map|r button",
        function() return FN:MapButtonLocked() end,
        function(v) FN:SetMapButtonLocked(v and true or false) end)
    -- Back to its place above the quest log's arrow; rests until the button has been moved.
    local resetButton = Card(page, "Reset position", 104, 22, function() FN:ResetMapButton() end)
    syncers[#syncers + 1] = function()
        local shown = FN:MapButtonShown()
        lockButton:SetEnabled(shown)
        lockButton:SetAlpha(shown and 1 or 0.4)
        local moved = FN:MapButtonMoved()
        resetButton:SetEnabled(moved)
        resetButton:SetAlpha(moved and 1 or 0.4)
    end

    local function LayoutInterface()
        local IND, GAP = LOOK_IND, LOOK_GAP
        local width = sectionInner - 2 * IND
        local y
        local function At(f, height, x)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", x or IND, -y)
            y = y + height + GAP
        end
        y = panelTitle.Place(SECTION_TOP, true, true)
        At(dockBox, 20)
        -- Its note right under the box's label.
        dockHint:ClearAllPoints()
        dockHint:SetPoint("TOPLEFT", IND + (Stock() and 29 or 21), -(y - GAP - 2))
        y = y + 8

        y = themeTitle.Place(y, true)
        PlaceRow(themeCards, TONES, y, width, db.tone, true, IND, 6)
        y = y + 22 + GAP

        y = scaleTitle.Place(y, true)
        experimental:ClearAllPoints()
        experimental:SetPoint("BOTTOMLEFT", scaleTitle.text, "BOTTOMRIGHT", 6, 0)
        dockedScale:SetWidth(width)
        At(dockedScale, 34)
        floatingScale:SetWidth(width)
        At(floatingScale, 34)
        resetScale:ClearAllPoints()
        resetScale:SetPoint("TOP", uiPage, "TOP", 0, -y)
        y = y + 22 + GAP

        y = buttonsTitle.Place(y, true)
        At(miniButton, 20)
        At(mapButton, 20)
        At(lockButton, 20)
        resetButton:ClearAllPoints()
        resetButton:SetPoint("TOP", uiPage, "TOP", 0, -y)
        y = y + 22 + GAP
        uiSection.height = SectionHeight(y)
    end
    syncers[#syncers + 1] = LayoutInterface
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function()
        LayoutInterface()
        ScaleInUse()
    end
    LayoutInterface()
    end -- Interface

    -- Last of all on every sync: stack the sections at their current sizes.
    syncers[#syncers + 1] = function() Relayout(false) end
end

-- Window -------------------------------------------------------------------------

-- The left list: one row per profession, then Settings. `selected` is a
-- profession kind ("herb", "ore", "fish") or SETTINGS.
local SETTINGS = "settings"
local pages, navRows = {}, {}
local navTabs = {} -- the same entries as icon tabs, for the narrow side panel
local selected
local nav, navSeparator, body, settingsScroll, columnA, columnB
local navGap -- the empty stretch of the tab row between the last profession icon and Settings

-- The sort toggle lives beside All / None in the window. In the side panel it
-- moves up into the tab row, between the profession icons and Settings.
local function PlaceSortToggle()
    local toggle = nodesPage.sortToggle
    toggle:ClearAllPoints()
    if frame.narrow then
        toggle:SetParent(nav)
        toggle:SetPoint("CENTER", navGap, "CENTER") -- midway between the last icon and Settings
        toggle:Show() -- kept in the row on the Settings tab too, so the row does not change
    else
        toggle:SetParent(pages.Nodes)
        toggle:SetPoint("RIGHT", nodesPage.none, "LEFT", -12, 0)
        toggle:Show()
    end
    -- On the Settings page there is no list to sort: it rests, dimmed, like Clear Selection
    -- and Select All while the trainer list is open.
    local resting = selected == SETTINGS
    if toggle.SetEnabled then toggle:SetEnabled(not resting) end
    toggle:EnableMouse(not resting)
    toggle:SetAlpha(resting and 0.35 or 1)
end

local function ShowPage(key)
    if key ~= selected and nodesPage.trainers then
        nodesPage.trainers.open = false
        if nodesPage.header then nodesPage.header:Reset() end
    end
    local switched = key ~= selected
    selected = key
    if key ~= SETTINGS then nodesPage.kind = key end
    pages.Nodes:SetShown(key ~= SETTINGS)
    pages.Settings:SetShown(key == SETTINGS)
    for rowKey, row in pairs(navRows) do
        row:SetSelected(rowKey == key)
        navTabs[rowKey]:SetSelected(rowKey == key)
    end
    PlaceSortToggle()
    if key ~= SETTINGS then
        RefreshNodes()
        if switched and nodesPage.header and nodesPage.kind then nodesPage.header:Shown(nodesPage.kind) end
    end
end

-- The game's own icon for a profession: the character's if known, else the skill's.
local PROFESSION_SPELLS = { herb = 2366, ore = 2575, fish = 7620 }
local PROFESSION_ICONS = {
    herb = "Interface\\Icons\\Trade_Herbalism",
    ore = "Interface\\Icons\\Trade_Mining",
    fish = "Interface\\Icons\\Trade_Fishing",
}
local function ProfessionIcon(kind)
    local _, icon = FN:GetSkill(kind)
    if not icon and C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(PROFESSION_SPELLS[kind])
    end
    return icon or PROFESSION_ICONS[kind]
end

-- A row in the left list: lights up with a bronze wash when selected.
local function NavRow(parent, text, icon, onClick)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(30)
    r.wash = Fade(r, "BACKGROUND", BRONZE[1], BRONZE[2], BRONZE[3], 0.55)
    r.wash:SetAllPoints()
    r.bar = Fill(r, "ARTWORK", GOLD[1], GOLD[2], GOLD[3], 0.9)
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.bar:SetWidth(2)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 1, 1, 0.08)
    hl:SetAllPoints()
    r.pic = r:CreateTexture(nil, "ARTWORK")
    r.pic:SetSize(20, 20)
    r.pic:SetPoint("LEFT", 9, 0)
    r.pic:SetTexture(icon)
    r.pic:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trim the icon's baked-in border
    r.text = Label(r, "GameFontNormal", text)
    r.text:SetPoint("LEFT", r.pic, "RIGHT", 8, 0)
    r.tag = Label(r, "GameFontHighlightSmall") -- skill level, on the right
    r.tag:SetPoint("RIGHT", -8, 0)
    r:SetScript("OnClick", onClick)

    local function Paint(self)
        if self.dimmed then
            self.text:SetTextColor(0.45, 0.45, 0.45)
        elseif self.isSelected then
            self.text:SetTextColor(1, 1, 1)
        else
            self.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        end
    end
    function r:SetSelected(isSelected)
        self.isSelected = isSelected
        self.wash:SetShown(isSelected)
        self.bar:SetShown(isSelected)
        Paint(self)
    end
    -- A profession the character does not have: greyed and darkened.
    function r:SetDimmed(dimmed)
        self.dimmed = dimmed
        self.pic:SetDesaturated(dimmed)
        self.pic:SetVertexColor(dimmed and 0.5 or 1, dimmed and 0.5 or 1, dimmed and 0.5 or 1)
        Paint(self)
    end
    return r
end

-- Side panel -----------------------------------------------------------------------
-- Opened from the world map, the window becomes a narrow panel on the map's right
-- edge, in the quest log's place. The two take turns: opening one closes the other,
-- and closing one with its own button brings back the one it had replaced.

local wantPanel = false -- opened from the world map button (rather than /fn or the Esc menu)
local internal = false  -- the quest log is being opened or closed by us, not by the player
local peeking = false   -- the quest log is up where the node panel usually is (L, or a quest was
                        -- opened); the panel is back the next time the map opens

-- The game's "quest log open" setting: the map's quest log arrow sets it, and M opens the map
-- with the quest log or without by it. It is the player's: the panel only borrows it while the
-- panel is in use (see SyncQuestLogSetting) and always hands it back.
local GetCV = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCV = (C_CVar and C_CVar.SetCVar) or SetCVar

-- Kept per character, so it survives closing the map and reloading:
--   open         the node panel is the map's side panel
--   questLogWas  the player's quest log setting, while the panel is borrowing it
local function State()
    return ForeverNodesCharDB.panel
end

local function QuestLogShown()
    local log = WorldMapFrame and WorldMapFrame.QuestLog
    return log and log:IsShown() or false
end

local function SetEscCloses(enabled)
    local name = "ForeverNodesOptions"
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then
            if enabled then return end
            table.remove(UISpecialFrames, i)
        end
    end
    if enabled then tinsert(UISpecialFrames, name) end
end

local function MapIsFullScreen()
    local map = WorldMapFrame
    return map and map.IsMaximized and map:IsMaximized() or false
end

-- Gives this character's quest log setting back, as it was before the panel borrowed it.
local function ReleaseQuestLogSetting()
    local state = State()
    local was = state.questLogWas
    if was == nil then return end
    state.questLogWas = nil
    if SetCV and GetCV("questLogOpen") ~= was then SetCV("questLogOpen", was) end
end

-- While the panel is in use the setting is kept on, so the game itself opens the map with the
-- quest log (the panel's place) on every M, and M closes it outright. Addons are not allowed to
-- open the quest log or close the map in combat; the game is. Should the quest log still be
-- missing with the map open (the panel was turned on mid-fight), the setting says "off" until it
-- is there, so M still agrees with what is on screen. Handed back when the panel is turned off.
local function SyncQuestLogSetting()
    if internal or not (GetCV and SetCV) then return end
    local state = State()
    if not (state.open and FN.db.dock) then
        ReleaseQuestLogSetting()
        return
    end
    local now = GetCV("questLogOpen")
    if state.questLogWas == nil then state.questLogWas = now end
    local map = WorldMapFrame
    local missing = map and map:IsShown() and not MapIsFullScreen() and not QuestLogShown()
    local want = missing and "0" or "1"
    if now ~= want then SetCV("questLogOpen", want) end
end

local function ShouldDock()
    local map = WorldMapFrame
    return wantPanel and FN.db.dock and map and map:IsShown() and not MapIsFullScreen() or false
end

local function SetQuestLog(show)
    local map = WorldMapFrame
    if not map.QuestLog or QuestLogShown() == show then return end
    -- Not in combat: what the map does next would count as ours, and part of it is not allowed then.
    if InCombatLockdown() then return end
    internal = true
    -- The game's own toggle also saves the quest log setting; put it back as it was.
    local keep = GetCV and GetCV("questLogOpen")
    if map.HandleUserActionToggleSidePanel then
        map:HandleUserActionToggleSidePanel()
    elseif show and QuestMapFrame_Open then
        QuestMapFrame_Open()
    elseif not show and QuestMapFrame_Close then
        QuestMapFrame_Close()
    end
    if keep ~= nil and SetCV and GetCV("questLogOpen") ~= keep then SetCV("questLogOpen", keep) end
    internal = false
end

-- The docked panel takes the quest log's own place: the quest log is opened as usual (so the
-- game and every map addon lay the window out exactly as they do for it), made invisible, and
-- the panel sits in its space. `covering` is true while the quest log is hidden like that.
local covering = false
local function Cover(on)
    local log = WorldMapFrame and WorldMapFrame.QuestLog
    covering = (on and log) and true or false
    if log then log:SetAlpha(covering and 0 or 1) end
    -- The map's quest log arrow follows (see SetupMapPanel: it reads "closed" while covered).
    local toggle = WorldMapFrame and WorldMapFrame.SidePanelToggle
    if toggle and toggle.Refresh and not InCombatLockdown() then toggle:Refresh() end
end

local floating = false -- the floating window has been placed (keeps where the player dragged it)

-- The quest log's ornate border ------------------------------------------------------
-- Stock look only: when the node panel is merged into the map, its list wears a
-- copy of the border the quest log's list has. The copy is made from the quest
-- log's own border frame at run time (same art, same layout), so nothing is
-- bundled and it follows whatever this client draws there.

-- Recreates every visible texture of `source` (and of its direct children) on `target`.
-- Returns how many were placed. `flip` turns the copy upside down (top pieces at the bottom).
local FLIPPED = { TOP = "BOTTOM", BOTTOM = "TOP", TOPLEFT = "BOTTOMLEFT", BOTTOMLEFT = "TOPLEFT",
    TOPRIGHT = "BOTTOMRIGHT", BOTTOMRIGHT = "TOPRIGHT" }
local function CloneArt(source, target, flip, skipFill, onlyCenter)
    local copies, owners = {}, { [source] = true }
    -- A piece that covers the whole frame (anchored on all four sides): the shaded fill.
    local function IsFill(region)
        local sides = {}
        for i = 1, region:GetNumPoints() do
            local point = region:GetPoint(i)
            if point then
                for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
                    if point:find(side) then sides[side] = true end
                end
            end
        end
        return sides.TOP and sides.BOTTOM and sides.LEFT and sides.RIGHT
    end
    -- A centered ornament (the crest): hung from the frame's middle top or bottom only.
    local function IsCenter(region)
        if region:GetNumPoints() ~= 1 then return false end
        local point = region:GetPoint(1)
        return point == "TOP" or point == "BOTTOM" or point == "CENTER"
    end
    local function CopyRegions(owner)
        for _, region in ipairs({ owner:GetRegions() }) do
            if region:IsObjectType("Texture") and region:IsShown() and not (skipFill and IsFill(region))
                and not (onlyCenter and not IsCenter(region)) then
                local layer, sublevel = region:GetDrawLayer()
                local copy = target:CreateTexture(nil, layer, nil, sublevel)
                local atlas = region.GetAtlas and region:GetAtlas()
                if atlas and atlas ~= "" then
                    copy:SetAtlas(atlas)
                else
                    copy:SetTexture(region:GetTexture())
                    copy:SetTexCoord(region:GetTexCoord())
                end
                copy:SetSize(region:GetSize())
                copy:SetVertexColor(region:GetVertexColor())
                copy:SetAlpha(region:GetAlpha())
                copy:SetBlendMode(region:GetBlendMode())
                if flip then
                    -- The same picture, its top and bottom swapped. Pieces that run the
                    -- full height (the shaded fill, the side edges) are left as they are:
                    -- flipping the fill moves its lighter end to the top.
                    local top, bottom = false, false
                    for i = 1, region:GetNumPoints() do
                        local point = region:GetPoint(i)
                        if point and point:find("TOP") then top = true end
                        if point and point:find("BOTTOM") then bottom = true end
                    end
                    if not (top and bottom) then
                        local ulx, uly, llx, lly, urx, ury, lrx, lry = copy:GetTexCoord()
                        copy:SetTexCoord(llx, lly, ulx, uly, lrx, lry, urx, ury)
                    end
                end
                copies[region] = copy
            end
        end
    end
    CopyRegions(source)
    for _, child in ipairs({ source:GetChildren() }) do
        if child:IsShown() then
            owners[child] = true
            CopyRegions(child)
        end
    end

    -- Anchor each copy the way its original is anchored: to the frame, or to another piece.
    local placed = 0
    for region, copy in pairs(copies) do
        local anchored = false
        for i = 1, region:GetNumPoints() do
            local point, relative, relativePoint, x, y = region:GetPoint(i)
            local to = (relative == nil or owners[relative]) and target or copies[relative]
            if to then
                if flip then
                    point, relativePoint, y = FLIPPED[point] or point, FLIPPED[relativePoint] or relativePoint, -(y or 0)
                end
                copy:SetPoint(point, to, relativePoint, x, y)
                anchored = true
            end
        end
        if anchored then placed = placed + 1 else copy:Hide() end
    end
    return placed
end

local ornates = {} -- [pane] = the copied border frame, or false when copying was not possible

-- Shows the quest log's border around `pane` (`on`), or the pane's plain inset edge.
-- `flip`: upside down, for a pane at the top (its crest then points down at the rest).
local function UseQuestBorder(pane, on, flip)
    if on and ornates[pane] == nil then
        ornates[pane] = false
        local log = WorldMapFrame and WorldMapFrame.QuestLog
        local scroll = QuestScrollFrame or (log and log.QuestsFrame)
        local source = (scroll and scroll.BorderFrame) or (log and log.BorderFrame)
        if source then
            local made = CreateFrame("Frame", nil, pane)
            made:SetPoint("TOPLEFT", -3, 4)
            made:SetPoint("BOTTOMRIGHT", 3, -4)
            made:SetFrameLevel(pane:GetFrameLevel() + 20)
            made:EnableMouse(false)
            -- The tab row (flipped) keeps only the ornate border's crest, at its bottom; its edge
            -- is the quest log search box's border (below).
            -- The tab row keeps only the ornate border's crest, at its bottom; its edge is our own
            -- rounded frame, colored after the quest log's search box (a dark well with a muted
            -- bronze-grey rim and a faint light top edge), so the corners keep their shape.
            local hasEdge = flip and true or false
            local ok, placed = pcall(CloneArt, source, made, flip, flip, hasEdge)
            if ok and placed and placed > 0 then ornates[pane] = made else made:Hide() end
            if hasEdge and ornates[pane] then
                local edge = CreateFrame("Frame", nil, pane)
                edge:SetAllPoints(pane)
                edge:SetFrameLevel(pane:GetFrameLevel()) -- under the tabs and switch
                edge:EnableMouse(false)
                local well = Rounded(edge, "BACKGROUND", "round_fill")
                well:SetVertexColor(0, 0, 0, 0.35)
                local rim = Rounded(edge, "BORDER", "round_edge")
                rim:SetVertexColor(0.31, 0.27, 0.21, 0.9)
                local inner = Rounded(edge, "BORDER", "round_edge")
                inner:ClearAllPoints()
                inner:SetPoint("TOPLEFT", 1, -1)
                inner:SetPoint("BOTTOMRIGHT", -1, 1)
                inner:SetVertexColor(0, 0, 0, 0.6)
                local shine = edge:CreateTexture(nil, "ARTWORK")
                shine:SetColorTexture(1, 1, 1, 1)
                shine:SetHeight(1)
                shine:SetPoint("TOPLEFT", 6, -1)
                shine:SetPoint("TOPRIGHT", -6, -1)
                if shine.SetGradient and CreateColor then
                    local c, z = CreateColor(1, 0.95, 0.85, 0.06), CreateColor(1, 0.95, 0.85, 0)
                    shine:SetGradient("VERTICAL", z, c)
                else
                    shine:SetVertexColor(1, 0.95, 0.85, 0.08)
                end
                made.rowEdge = edge
            end
        end
    end
    local ornate = ornates[pane]
    if not ornate then return end
    ornate:SetShown(on)
    if ornate.rowEdge then ornate.rowEdge:SetShown(on) end
    if pane.NineSlice then pane.NineSlice:SetShown(not on) end -- not both edges at once
end

-- Merging into the map window -------------------------------------------------------
-- The quest log is part of the map window: the window grows wider and the map
-- area stops short of the log. The node panel does the same: it widens the map
-- window by its own width and pulls the map area's right edge back by as much,
-- then sits in the space that opens up, with no frame of its own.
--
-- The game puts the window back to its own size whenever the quest log is toggled
-- or the map goes full screen, so the merge is re-checked after every map change.

local MERGED_WIDTH = DOCK_WIDTH - 16 -- the panel's width inside the map window (its own units)
local MERGED_TOP = 28                -- below the map window's title bar

local merge = nil       -- { widen, shift, width, anchors = { frame, point, relative, relativePoint, x, y } }
local mergeRetries, mergeRetryAt = 0, 0
local mergeGaveUp = false -- the game kept undoing it: use the attached window instead
local mergeCounting = false -- true while the once-a-frame safety net is repairing the merge

-- The frame whose right edge decides where the map area ends, and its right-hand anchors.
local function MapAreaAnchors()
    local map = WorldMapFrame
    local targets = {}
    if map.TitleCanvasSpacerFrame then targets[#targets + 1] = map.TitleCanvasSpacerFrame end
    if map.ScrollContainer then targets[#targets + 1] = map.ScrollContainer end
    for _, target in ipairs(targets) do
        local anchors = {}
        for i = 1, target:GetNumPoints() do
            local point, relative, relativePoint, x, y = target:GetPoint(i)
            -- Only edges hung off the window itself move with its width.
            if point and point:find("RIGHT", 1, true) and (relative == nil or relative == map) then
                anchors[#anchors + 1] = { target, point, relative or map, relativePoint, x or 0, y or 0 }
            end
        end
        if #anchors > 0 then return anchors end
    end
    return nil
end

local function AnchorOffset(target, wanted)
    for i = 1, target:GetNumPoints() do
        local point, _, _, x = target:GetPoint(i)
        if point == wanted then return x or 0 end
    end
    return nil
end

local function MapOwnsItsSize()
    return QuestLogShown() or MapIsFullScreen()
end

-- How far the map area's right edge is from the window's right edge.
local function MapAreaGap()
    local map = WorldMapFrame
    local viewport = map.ScrollContainer
    local right, areaRight = map:GetRight(), viewport and viewport:GetRight()
    if right and areaRight then return right - areaRight end
    return nil
end

-- Remembers the window as the quest log lays it out, so the merged panel can
-- take exactly the same room and the map area stays the same size in both.
local function MeasureQuestLayout()
    if not QuestLogShown() or MapIsFullScreen() or merge then return end
    local gap = MapAreaGap()
    if gap and gap > 50 then
        FN.db.questLayout = { width = WorldMapFrame:GetWidth(), gap = gap }
    end
end

-- True while the map window is still the way the merge left it.
local function MergeIntact()
    if not merge or MapOwnsItsSize() then return false end
    if math.abs(WorldMapFrame:GetWidth() - merge.width) > 0.5 then return false end
    for _, a in ipairs(merge.anchors) do
        local x = AnchorOffset(a[1], a[2])
        if not x or math.abs(x - (a[5] - merge.shift)) > 0.5 then return false end
    end
    return true
end

local function RefitMap()
    local map = WorldMapFrame
    if map.OnFrameSizeChanged then map:OnFrameSizeChanged() end
end

-- Puts the map window back. Anything the game has already reset is left alone.
local function UndoMerge()
    local state = merge
    if not state then return end
    merge = nil
    local map = WorldMapFrame
    if MapOwnsItsSize() or InCombatLockdown() then return end
    for _, a in ipairs(state.anchors) do
        local x = AnchorOffset(a[1], a[2])
        if x and math.abs(x - (a[5] - state.shift)) <= 0.5 then
            a[1]:SetPoint(a[2], a[3], a[4], a[5], a[6])
        end
    end
    if math.abs(map:GetWidth() - state.width) <= 0.5 then
        map:SetWidth(state.width - state.widen)
    end
    RefitMap()
end

-- Makes room in the map window: widens it and pulls the map area's right edge
-- back. `fallback` (map units) is used until the quest log's own layout has been
-- seen. Returns true when the panel can sit inside; merge.shift is its room.
local function MergeIntoMap(fallback)
    local map = WorldMapFrame
    if mergeGaveUp or MapOwnsItsSize() or InCombatLockdown() then
        UndoMerge()
        return false
    end
    if merge and MergeIntact() then return true end

    -- The game undid it, or the panel changed size: start again from the map as it is now.
    -- Only repairs made a frame late count: those are the ones that could loop.
    if merge and mergeCounting then
        local now = GetTime()
        if now - mergeRetryAt > 2 then mergeRetries = 0 end
        mergeRetryAt = now
        mergeRetries = mergeRetries + 1
        if mergeRetries > 4 then -- fighting the game every frame: stop
            mergeGaveUp = true
            UndoMerge()
            return false
        end
    end
    UndoMerge()

    local anchors = MapAreaAnchors()
    if not anchors then return false end

    -- Take exactly the room the quest log takes, when that has been measured.
    local widen, shift = fallback, fallback
    local quest, gap = FN.db.questLayout, MapAreaGap()
    if quest and gap then
        local questWiden, questShift = quest.width - map:GetWidth(), quest.gap - gap
        if questWiden > 50 and questShift > 50 then widen, shift = questWiden, questShift end
    end

    local width = map:GetWidth() + widen
    map:SetWidth(width)
    for _, a in ipairs(anchors) do
        a[1]:SetPoint(a[2], a[3], a[4], a[5] - shift, a[6])
    end
    merge = { widen = widen, shift = shift, width = width, anchors = anchors }
    RefitMap()
    return true
end

-- How much bigger or smaller the map window is drawn than the rest of the UI. Map addons
-- (MapUtils' corner drag, for one) scale the map window, and the quest log, being part of
-- it, grows with it; the docked panel follows the same scale so it matches the map.
local function MapScale()
    local map, ui = WorldMapFrame, UIParent
    local m, u = map and map:GetEffectiveScale(), ui and ui:GetEffectiveScale()
    if m and u and m > 0 and u > 0 then return m / u end
    return 1
end

-- Docked, the panel goes on the map window's layer, or its border frame's when that is higher
-- (the border frame, the window's background and edges, can sit a layer above the map), just
-- above the window's own pieces (the quest log, the border, the buttons) the way the quest
-- log itself is, so another addon's window shown over the map also shows over the panel.
-- The map's contents (the zoomable canvas with its pins) are left out: they sit beside the
-- panel and can go very high. Kept in step every frame, since clicking the map brings it
-- to the front.
local STRATA_ORDER = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
    FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local rise, riseAt, riseTop = 1, -1, nil
local function Rise(top, skip)
    -- How far above `top` its highest piece sits. Measured at most once a second.
    local now = GetTime()
    if top == riseTop and now - riseAt < 1 then return rise end
    riseAt, riseTop = now, top
    local base, high = top:GetFrameLevel(), top:GetFrameLevel()
    local strata = top:GetFrameStrata()
    local function Walk(depth, ...)
        for i = 1, select("#", ...) do
            local c = select(i, ...)
            if c ~= skip and c ~= frame and c.GetFrameLevel then
                if c:GetFrameStrata() == strata and c:GetFrameLevel() > high then high = c:GetFrameLevel() end
                if depth < 15 then Walk(depth + 1, c:GetChildren()) end
            end
        end
    end
    Walk(1, top:GetChildren())
    rise = high - base + 1
    return rise
end
local function DockPlace()
    local map = WorldMapFrame
    local top = map
    local border = map.BorderFrame
    if border and border.GetFrameStrata then
        local a, b = STRATA_ORDER[map:GetFrameStrata()] or 0, STRATA_ORDER[border:GetFrameStrata()] or 0
        if b > a then top = border end
    end
    return top:GetFrameStrata(), math.min(top:GetFrameLevel() + Rise(top, map.ScrollContainer), 9000)
end

local function ApplyLayout()
    local docked = ShouldDock()
    frame.docked = docked
    -- The floating window is the same narrow panel as the docked one, just free to move
    -- (and its Scale slider scales all of it). So the layout is always the narrow one.
    local narrow = true
    frame.narrow = narrow
    -- Each mode has its own scale; docked, it also follows the map window's.
    frame:SetScale(docked and (FN.db.dockScale * MapScale()) or FN.db.scale)
    -- Layering. Docked, the panel is part of the map window: it takes the map's own layer,
    -- just above the map's contents, so whatever shows over the map (popups, other windows)
    -- shows over the panel too, and nothing slips in between the panel's own pieces.
    -- Floating, it is a dialog, above the map; over a maximized map it has to go higher.
    if docked then
        local strata, level = DockPlace()
        frame:SetFrameStrata(strata)
        frame:SetFrameLevel(level)
    else
        frame:SetAlpha(1) -- floating: never faded with the map
        local overMap = WorldMapFrame and WorldMapFrame:IsShown() and MapIsFullScreen()
        frame:SetFrameStrata(overMap and "FULLSCREEN_DIALOG" or "DIALOG")
    end
    -- Esc closes the floating window. The side panel instead follows the map, so
    -- that closing the map with Esc does not count as closing the panel.
    SetEscCloses(not docked)

    -- Three shapes: merged into the map window (no frame of its own), attached
    -- beside it as a narrow window (when merging is not possible), or floating.
    local merged, mergedWidth = false, MERGED_WIDTH
    local log = WorldMapFrame and WorldMapFrame.QuestLog
    -- (While the quest log is being closed it stays the place to be: the hooks decide what comes next.)
    if docked and covering and log then
        -- In the quest log's space. The right, top and bottom margins are the ones the panel
        -- always had inside the map window; the left edge follows the quest log's own.
        local map = WorldMapFrame
        floating = false
        UndoMerge()
        frame:SetClampedToScreen(false)
        frame:ClearAllPoints()
        local stock = Stock()
        -- Stock: the list box runs as far right as the quest log's own, with its scroll bar
        -- strip outside it (the strip the scroll marker uses).
        local side, margins = stock and 25 or 6, stock and 25 or 14 -- stock: flush with the quest log's left edge
        local inset = margins - side -- from the quest log's left edge
        local fs = frame:GetEffectiveScale()
        local mapRight, logLeft = map:GetRight(), log:GetLeft()
        if mapRight and logLeft then
            mergedWidth = math.max(200, (mapRight * map:GetEffectiveScale() - logLeft * log:GetEffectiveScale()) / fs
                - side - inset)
        end
        frame:SetPoint("TOPRIGHT", map, "TOPRIGHT", -side, -(stock and 33 or MERGED_TOP))
        frame:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -side, stock and 9 or side)
        frame:SetPoint("LEFT", log, "LEFT", inset, 0)
        merged = true
    elseif docked then
        -- The quest log could not be opened (in combat): make room in the map window instead.
        local map = WorldMapFrame
        local ratio = frame:GetEffectiveScale() / map:GetEffectiveScale()
        floating = false
        frame:SetClampedToScreen(false)
        frame:ClearAllPoints()
        merged = MergeIntoMap(MERGED_WIDTH * ratio + 6)
        if merged then
            -- Fill the room that was made, less a small margin on each side.
            -- Margins inside the room that was made. The stock map frame has a
            -- heavier title bar and the list wears the quest log's border, which
            -- hangs a few pixels outside it, so it gets a little more air.
            local stock = Stock()
            -- Stock numbers are measured against the quest log's own list box, which
            -- stops well short of the window edge to leave its scroll bar outside.
            local side, margins = stock and 29 or 6, stock and 30 or 14
            mergedWidth = math.max(200, merge.shift / ratio - margins)
            frame:SetWidth(mergedWidth)
            frame:SetPoint("TOPRIGHT", map, "TOPRIGHT", -side, -(stock and 33 or MERGED_TOP))
            frame:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -side, stock and 9 or side)
        else
            frame:SetSize(DOCK_WIDTH, math.max(360, map:GetHeight() / ratio))
            frame:SetPoint("TOPLEFT", map, "TOPRIGHT", 2, 0)
        end
    else
        UndoMerge()
        if covering then -- floating now: give the side back to the quest log, closed
            Cover(false)
            SetQuestLog(false)
        end
        if not floating then
            floating = true
            frame:SetClampedToScreen(true)
            frame:ClearAllPoints()
            -- Same size as the docked panel: the map's height when known.
            local mapH = WorldMapFrame and WorldMapFrame:GetHeight() or 0
            frame:SetSize(DOCK_WIDTH, math.max(460, math.min(640, mapH > 0 and mapH or 560)))
            frame:SetPoint("CENTER")
        end
    end
    frame.shell:SetShown(not merged) -- merged, the map window is the frame
    UseQuestBorder(body, merged and Stock())
    UseQuestBorder(nav, merged and Stock(), true) -- the tab row is on top: its crest goes at the bottom
    -- With the ornate border the scroll marker sits outside the box, in the strip
    -- the quest log uses for its scroll bar.
    nodesPage.scroll.thumbOffset = (merged and Stock()) and 33 or 6
    -- (the settings' marker lines up with the node list's: the list's area bleeds out further,
    -- so the settings one goes 7px further out to sit the same distance from the border)
    settingsScroll.thumbOffset = (merged and Stock()) and 33 or 7
    frame.pageWidth = (merged and (mergedWidth - 20)) or (narrow and (DOCK_WIDTH - 40))
        or (WIDTH - NAV_WIDTH - 48)

    -- Page list: a column on the left, or a strip across the top in the side panel.
    local top = -(BAR_HEIGHT + 10)
    nav:ClearAllPoints()
    body:ClearAllPoints()
    if merged then
        nav:SetPoint("TOPLEFT", 0, 0)
        nav:SetPoint("TOPRIGHT", 0, 0)
        nav:SetHeight(Stock() and 56 or 52) -- a little taller under the ornate border
        body:SetPoint("TOPLEFT", nav, "BOTTOMLEFT", 0, Stock() and -12 or -6) -- room for the border's ornaments
        body:SetPoint("BOTTOMRIGHT", 0, 0)
    elseif narrow then
        nav:SetPoint("TOPLEFT", 10, top)
        nav:SetPoint("TOPRIGHT", -10, top)
        nav:SetHeight(52)
        body:SetPoint("TOPLEFT", nav, "BOTTOMLEFT", 0, -6)
        body:SetPoint("BOTTOMRIGHT", -10, 10)
    else
        nav:SetPoint("TOPLEFT", 10, top)
        nav:SetPoint("BOTTOMLEFT", 10, 10)
        nav:SetWidth(NAV_WIDTH)
        body:SetPoint("TOPLEFT", nav, "TOPRIGHT", 8, 0)
        body:SetPoint("BOTTOMRIGHT", -10, 10)
    end

    -- Professions the character has come first, then the rest greyed out; A-Z within each.
    local skills, order = {}, {}
    for _, kind in ipairs(FN.kinds) do
        skills[kind] = FN:GetSkill(kind)
        order[#order + 1] = kind
    end
    -- Known before unknown, then primary professions before Fishing, then A-Z.
    table.sort(order, function(a, b)
        local knownA, knownB = skills[a] ~= nil, skills[b] ~= nil
        if knownA ~= knownB then return knownA end
        local primaryA, primaryB = a ~= "fish", b ~= "fish"
        if primaryA ~= primaryB then return primaryA end
        return FN.kindNames[a] < FN.kindNames[b]
    end)
    order[#order + 1] = SETTINGS

    local firstProfession
    for i, key in ipairs(order) do
        local row, tab = navRows[key], navTabs[key]
        if key ~= SETTINGS then
            local known = skills[key] ~= nil
            local icon = ProfessionIcon(key)
            row.pic:SetTexture(icon)
            row.tag:SetText(known and skills[key] or "")
            row:SetDimmed(not known)
            tab.pic:SetTexture(icon)
            tab.level:SetText(known and skills[key] or "")
            tab:SetDimmed(not known)
            firstProfession = firstProfession or key
        end
        -- Side panel: icon tabs in one row, Settings at the far right. Window: a list down the left.
        row:SetShown(not narrow)
        tab:SetShown(narrow)
        tab:ClearAllPoints()
        if key == SETTINGS then
            -- In from the right edge, centered on the row of profession tabs (44 tall, 4 down).
            tab:SetPoint("TOPRIGHT", -26, -(4 + (44 - GEAR_SIZE) / 2))
        else
            tab:SetPoint("TOPLEFT", 4 + (i - 1) * 50, -4)
        end
        row:ClearAllPoints()
        row:SetSize(NAV_WIDTH - 2, 30)
        row:SetPoint("TOPLEFT", 1, -6 - (i - 1) * 32 - (key == SETTINGS and 13 or 0))
    end
    navGap:ClearAllPoints()
    navGap:SetPoint("LEFT", navTabs[order[#order - 1]], "RIGHT")
    navGap:SetPoint("RIGHT", navTabs[SETTINGS], "LEFT")
    navSeparator:SetShown(not narrow)
    navSeparator:ClearAllPoints()
    navSeparator:SetPoint("TOPLEFT", 10, -6 - (#order - 1) * 32 - 6)
    navSeparator:SetPoint("TOPRIGHT", -10, -6 - (#order - 1) * 32 - 6)

    if not selected then selected = firstProfession or SETTINGS end
    ShowPage(selected)

    -- Settings: two blocks side by side, or stacked (and scrolling) in the side panel.
    local pageWidth = frame.pageWidth
    -- Stacked in the side panel, the sections run the panel's full width; side by side
    -- in the window they keep their fixed width.
    -- (Exactly the list's width: a pixel more put the sections' right border lines just past the
    -- list's edge, where they were cut off.)
    local sectionWidth = narrow and math.floor(pageWidth) or SECTION_WIDTH
    for i = 1, #sectionWidthFollowers do sectionWidthFollowers[i](sectionWidth) end
    columnB:ClearAllPoints()
    if narrow then
        -- Each block's height already ends with one section gap, so the second
        -- block follows straight on and every header is the same distance apart.
        columnB:SetPoint("TOPLEFT", 0, -COLUMN_A_HEIGHT)
        settingsScroll.child:SetSize(pageWidth, COLUMN_A_HEIGHT + COLUMN_B_HEIGHT)
    else
        columnB:SetPoint("TOPLEFT", 278, 0)
        settingsScroll.child:SetSize(pageWidth, math.max(COLUMN_A_HEIGHT, COLUMN_B_HEIGHT))
    end
    settingsScroll:Update()

    RefreshNodes()
end

local function SyncAll()
    -- One widget failing to sync must not stop the window from being laid out
    -- (that left the panel drawn over the map); its error is still reported.
    for i = 1, #syncers do
        local ok, err = pcall(syncers[i])
        if not ok then geterrorhandler()(err) end
    end
    ApplyLayout()
end

local function CreateOptions()
    -- Stock look: selection and rules use the game's gold rather than EllesmereUI's bronze,
    -- and the window is Blizzard's own framed window.
    local stock = Stock()
    if stock then
        BRONZE[1], BRONZE[2], BRONZE[3] = GOLD[1], GOLD[2], GOLD[3]
    end

    -- `frame` holds the contents. Its border, backdrop, title and close button
    -- live on a separate `shell`, hidden while the panel is merged into the map
    -- window (the map window is the frame then).
    frame = CreateFrame("Frame", "ForeverNodesOptions", UIParent)
    -- OpenMap's tray button shows whether this is open: told as it opens or closes.
    local function OpenChanged() if FN.RefreshOpenMapTray then FN:RefreshOpenMapTray() end end
    frame:HookScript("OnShow", OpenChanged)
    frame:HookScript("OnHide", OpenChanged)
    local shell = stock and TryTemplate("Frame", nil, frame, "BasicFrameTemplate")
    local framed = shell ~= nil -- Blizzard's template supplied the border, title bar and close button
    shell = shell or CreateFrame("Frame", nil, frame)
    shell:SetAllPoints()
    shell:SetFrameLevel(frame:GetFrameLevel())
    shell:EnableMouse(false) -- dragging goes to `frame`
    frame.shell = shell

    frame:SetSize(WIDTH, HEIGHT)
    frame:SetScale(FN.db.scale)
    frame:SetFrameStrata("FULLSCREEN_DIALOG") -- stays above a maximized world map
    frame:SetToplevel(true) -- a click brings it in front of other windows on its layer
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not self.docked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local close = framed and shell.CloseButton
    if not close then
        close = CreateFrame("Button", nil, shell, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
    end
    close:SetScript("OnClick", function() FN:CloseWindow() end)

    local skin = Skin()
    if skin then
        skin.Shell(shell) -- themed backdrop, title strip and window border
        if skin.CloseButton then skin.CloseButton(close) end
    elseif not framed then
        local bg = Fill(shell, "BACKGROUND", 0.07, 0.055, 0.04, 0.96)
        bg:SetAllPoints()
        local bar = Fill(shell, "BORDER", 0, 0, 0, 0.5)
        bar:SetPoint("TOPLEFT")
        bar:SetPoint("TOPRIGHT")
        bar:SetHeight(BAR_HEIGHT)
        Outline(shell, shell, BRONZE[1] * 0.6, BRONZE[2] * 0.6, BRONZE[3] * 0.6, 1)
    end

    -- Title, centered in the strip like the game's own windows.
    local stockTitle = framed and (shell.TitleText or (shell.TitleContainer and shell.TitleContainer.TitleText))
    if stockTitle then
        stockTitle:SetText(TITLE)
    else
        local title = Label(shell, "GameFontNormal", TITLE)
        title:SetPoint("TOP", 10, -6)
        local logo = shell:CreateTexture(nil, "OVERLAY")
        logo:SetSize(16, 16)
        logo:SetPoint("RIGHT", title, "LEFT", -5, 0)
        logo:SetTexture(FN.MEDIA .. "icon")
    end

    -- Contents sit above the shell's backdrop.
    nav = Pane(frame)
    body = Pane(frame)
    nav:SetFrameLevel(frame:GetFrameLevel() + 2)
    body:SetFrameLevel(frame:GetFrameLevel() + 2)

    for _, name in ipairs({ "Nodes", "Settings" }) do
        local page = CreateFrame("Frame", nil, body)
        page:SetPoint("TOPLEFT", 10, -10)
        page:SetPoint("BOTTOMRIGHT", -10, 8)
        pages[name] = page
    end
    for _, kind in ipairs(FN.kinds) do
        local function Open() ShowPage(kind) end
        navRows[kind] = NavRow(nav, FN.kindNames[kind], ProfessionIcon(kind), Open)
        navTabs[kind] = IconTab(nav, ProfessionIcon(kind), Open)
    end
    local gear = "Interface\\Icons\\INV_Misc_Gear_01"
    local function OpenSettings() ShowPage(SETTINGS) end
    navRows[SETTINGS] = NavRow(nav, "Settings", gear, OpenSettings)
    -- The cog toggles: on Settings, a second click goes back to the profession tab that was
    -- open (when it can still be opened).
    navTabs[SETTINGS] = GearTab(nav, function()
        local back = nodesPage.kind
        if selected == SETTINGS and back and navTabs[back] and navTabs[back]:IsEnabled() then
            ShowPage(back)
        else
            ShowPage(SETTINGS)
        end
    end)
    navSeparator = Fill(nav, "ARTWORK", BRONZE[1], BRONZE[2], BRONZE[3], 0.35)
    navSeparator:SetHeight(1)
    navGap = CreateFrame("Frame", nil, nav)
    navGap:SetHeight(1)

    BuildNodesPage(pages.Nodes)

    settingsScroll = Scroller(pages.Settings)
    settingsScroll:SetAllPoints()
    columnA = CreateFrame("Frame", nil, settingsScroll.child)
    columnA:SetSize(256, COLUMN_A_HEIGHT)
    columnA:SetPoint("TOPLEFT")
    columnB = CreateFrame("Frame", nil, settingsScroll.child)
    columnB:SetSize(256, COLUMN_B_HEIGHT)
    BuildSettingsPage(columnA, columnB)
    -- The open section's header stays at the top while its settings scroll under it.
    settingsScroll:HookScript("OnVerticalScroll", function() FN:UpdateSettingsPins() end)

    frame:SetScript("OnShow", function()
        -- A fresh opening: the gold flash and rank-line shimmer may play again.
        if nodesPage.header then nodesPage.header:PanelOpened() end
        SyncAll()
        if nodesPage.header and nodesPage.kind and selected ~= SETTINGS then nodesPage.header:Shown(nodesPage.kind) end
    end)
    frame:SetScript("OnHide", function()
        -- Hiding the panel (map closed, quest log shown, window closed) folds the trainer list away.
        if nodesPage.trainers then nodesPage.trainers.open = false end
        if nodesPage.header then nodesPage.header:Reset() end
        UndoMerge() -- hand the map window back at its own size
    end)
    frame:Hide()
end

-- Opening and closing the side panel ----------------------------------------------

local function OpenPanel()
    if not frame then CreateOptions() end
    wantPanel = true
    peeking = false
    State().open = true
    MeasureQuestLayout() -- while the quest log is still up, note the room it takes
    -- Take the quest log's place: open it (if it is not already) and hide it under the panel.
    SetQuestLog(true)
    if QuestLogShown() then Cover(true) end
    SyncQuestLogSetting()
    if frame:IsShown() then
        ApplyLayout() -- was floating: attach it
    else
        frame:Show()
    end
    frame:Raise()
end

-- why: "button" (the node button), "x" (the panel's close button) or "peek" (L, the quest log
-- arrow, or a quest was opened: the quest log is shown over the panel for now, and the panel
-- comes back with the arrow or the next map opening).
local function ClosePanel(why)
    local state = State()
    if why ~= "peek" then state.open = false end
    peeking = (why == "peek" and state.open) and true or false
    frame:Hide()
    SyncQuestLogSetting() -- turned off: the player's own setting is back
    if covering then
        Cover(false)
        -- The quest log was asked for, or the player's map always shows it: it stays, now seen.
        -- Otherwise the side closes (in combat it can't, so the quest log stays then too).
        SetQuestLog(why == "peek" or (GetCV and GetCV("questLogOpen") == "1") or false)
    end
end

-- Re-opens the side panel when the map comes back (or after a reload) if it was
-- open when the map was last closed.
local function RestorePanel()
    local map = WorldMapFrame
    if not (map and map:IsShown()) then return end
    if MapIsFullScreen() or not FN.db.dock then
        if covering and not (frame and frame:IsShown()) then Cover(false) end
        return
    end
    local state = State()
    if not state.open or peeking then
        -- Left hidden when the map was last closed but not wanted now: let it be seen.
        if covering and not (frame and frame:IsShown()) then Cover(false) end
        return
    end
    if frame and frame:IsShown() and frame.docked then return end
    OpenPanel()
end

-- Re-fits the window after its scale or the map changes. A side panel closes with
-- the map, and when the map goes full screen (it is remembered, not forgotten).
function FN:UpdateDock()
    if not (frame and frame:IsShown()) then return end
    if frame.docked and not ShouldDock() then
        frame:Hide()
        -- Map still up (it went full screen): the quest log is let go of, closed, and is taken
        -- again when the panel comes back. Map closed: it stays hidden, so reopening the map
        -- never flashes it.
        if covering and WorldMapFrame:IsShown() then
            Cover(false)
            SetQuestLog(false)
        end
        return
    end
    ApplyLayout()
end

-- Map icons in combat -----------------------------------------------------------------------------
-- On this client, once an addon has run any of the map's own code (the panel opening or closing the
-- quest log, /fn opening the map, a trainer pin switching its zone), the map icons' mouse setup
-- (which clicks pass through them to the map) is refused in combat for the rest of the session, and
-- every map refresh in combat shows "Interface action failed". So in combat that setup waits, and is
-- done as soon as combat ends; until then a right click on an icon added mid-fight doesn't zoom the
-- map out. OpenMap does the same for every addon: with it loaded, this is left to it.
local function SetupCombatPins(map)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded and loaded("OpenMap") then return end
    local passthrough = MapCanvasPinMixin and MapCanvasPinMixin.CheckMouseButtonPassthrough
    if type(passthrough) ~= "function" then return end
    local propagation = SuperTrackablePinMixin and SuperTrackablePinMixin.UpdateMousePropagation
    if type(propagation) ~= "function" then propagation = nil end

    local waiting = setmetatable({}, { __mode = "k" }) -- icon -> { passthrough = args, propagation = args }
    local function Wait(pin, key, ...)
        local w = waiting[pin] or {}
        waiting[pin] = w
        w[key] = { n = select("#", ...), ... }
    end
    local function Done(pin, key)
        local w = waiting[pin]
        if not w then return end
        w[key] = nil
        if not (w.passthrough or w.propagation) then waiting[pin] = nil end
    end
    local function Passthrough(pin, ...)
        if InCombatLockdown() then return Wait(pin, "passthrough", ...) end
        Done(pin, "passthrough")
        return passthrough(pin, ...)
    end
    local function Propagation(pin, ...)
        if InCombatLockdown() then return Wait(pin, "propagation", ...) end
        Done(pin, "propagation")
        return propagation(pin, ...)
    end

    -- Mixins copy their functions, so every table holding Blizzard's (the mixins made from it, and
    -- the icons already made) is pointed at ours. A forbidden table is left alone.
    local function Methods(t) return rawget(t, "CheckMouseButtonPassthrough"), rawget(t, "UpdateMousePropagation") end
    local function Point(t)
        if type(t) ~= "table" then return end
        local ok, a, b = pcall(Methods, t)
        if not ok then return end
        if a == passthrough then t.CheckMouseButtonPassthrough = Passthrough end
        if propagation and b == propagation then t.UpdateMousePropagation = Propagation end
    end
    local seenPool = setmetatable({}, { __mode = "k" })
    local function PointPools(all)
        for _, pool in pairs(map.pinPools or {}) do
            if all or not seenPool[pool] then
                seenPool[pool] = true
                for _, how in ipairs({ "EnumerateActive", "EnumerateInactive" }) do
                    if type(pool[how]) == "function" then
                        local ok, iter, state, start = pcall(pool[how], pool)
                        if ok and iter then
                            for pin in iter, state, start do Point(pin) end
                        end
                    end
                end
            end
        end
    end
    -- Each global table is looked at once; later sweeps (an addon loaded later) only see new ones.
    local checked = setmetatable({}, { __mode = "k" })
    local function Sweep()
        for _, value in pairs(_G) do
            if type(value) == "table" and not checked[value] then
                checked[value] = true
                Point(value)
            end
        end
        PointPools(true)
    end
    Sweep()
    map:HookScript("OnShow", function() PointPools(true) end)
    local scroll = map.ScrollContainer
    if scroll and scroll.MarkCanvasDirty then
        hooksecurefunc(scroll, "MarkCanvasDirty", function() PointPools(false) end) -- a new kind of icon
    end
    local events, sweepQueued = CreateFrame("Frame"), false
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then
            if not sweepQueued then
                sweepQueued = true
                C_Timer.After(0, function()
                    sweepQueued = false
                    Sweep()
                end)
            end
            return
        end
        -- Combat is over: what waited is done now (an icon let go meanwhile is skipped).
        for pin, w in pairs(waiting) do
            waiting[pin] = nil
            if pin.IsForbidden and not pin:IsForbidden() and (not pin.GetMap or pin:GetMap()) then
                if w.passthrough then pcall(passthrough, pin, unpack(w.passthrough, 1, w.passthrough.n)) end
                if w.propagation then pcall(propagation, pin, unpack(w.propagation, 1, w.propagation.n)) end
            end
        end
    end)
end

-- Called once at login: keeps the side panel in step with the map and the quest log.
function FN:SetupMapPanel()
    local map = WorldMapFrame
    -- Borrowed again for a panel left in use (it was handed back at logout), or handed back
    -- after a crash.
    SyncQuestLogSetting()
    local logout = CreateFrame("Frame")
    logout:RegisterEvent("PLAYER_LOGOUT")
    logout:SetScript("OnEvent", function()
        -- Kept on record too, in case the game does not save the change this late.
        local was = State().questLogWas
        if was ~= nil and SetCV then SetCV("questLogOpen", was) end
    end)
    if not map then return end
    SetupCombatPins(map)

    -- The map's quest log arrow while the node panel is in use: it only moves the quest log in
    -- over the panel and out again (the panel stays on; only the node button turns it off), and
    -- leaves the game's quest log setting as it was. All before the next frame is drawn.
    -- (Hooked before the layout hooks below, so they see the result.)
    local arrowSetting -- the quest log setting just before the arrow was clicked
    if type(map.HandleUserActionToggleSidePanel) == "function" then
        hooksecurefunc(map, "HandleUserActionToggleSidePanel", function()
            local keep = arrowSetting
            arrowSetting = nil
            if internal or MapIsFullScreen() or not FN.db.dock or not State().open then return end
            if covering and frame and frame:IsShown() and frame.docked then
                -- The panel was showing (the quest log under it, which the game just closed):
                -- the quest log comes in over the panel.
                ClosePanel("peek")
            elseif not QuestLogShown() then
                OpenPanel() -- the quest log went out: the panel is back
            else
                peeking = true -- the quest log came in where the panel usually is
            end
            if keep ~= nil and SetCV and GetCV("questLogOpen") ~= keep then SetCV("questLogOpen", keep) end
        end)
    end
    -- Its arrow: "closed" while the panel covers the quest log, since to the player the quest
    -- log is not open.
    local toggle = map.SidePanelToggle
    if toggle then
        for _, button in ipairs({ toggle.OpenButton, toggle.CloseButton }) do
            if button and button.HookScript then
                button:HookScript("PreClick", function() arrowSetting = GetCV and GetCV("questLogOpen") end)
            end
        end
    end
    if toggle and type(toggle.Refresh) == "function" then
        hooksecurefunc(toggle, "Refresh", function(self)
            if not covering then return end
            if self.OpenButton then self.OpenButton:Show() end
            if self.CloseButton then self.CloseButton:Hide() end
        end)
    end

    -- Runs straight after each step of the map's own resizing, in the same frame,
    -- so the window is never drawn half-way (which showed as a flash).
    local settling = false
    local function Settle()
        if settling or internal then return end
        settling = true
        if frame and frame:IsShown() and frame.docked and ShouldDock() then
            ApplyLayout()
        end
        settling = false
    end
    for _, method in ipairs({ "SynchronizeDisplayState", "UpdateSpacerFrameAnchoring", "SetDisplayState",
        "HandleUserActionToggleSidePanel" }) do
        if type(map[method]) == "function" then hooksecurefunc(map, method, Settle) end
    end

    -- The slower safety net, a frame later: catches anything the hooks above missed.
    -- Only repairs made here count toward giving up on the merge.
    local queued = false
    local function Queue()
        if queued then return end
        queued = true
        C_Timer.After(0, function()
            queued = false
            MeasureQuestLayout()
            mergeCounting = true
            FN:UpdateDock()
            mergeCounting = false
            RestorePanel()
        end)
    end
    map:HookScript("OnShow", Queue)
    map:HookScript("OnHide", Queue)
    map:HookScript("OnSizeChanged", Queue)
    -- A map addon may rescale the map window (or something it sits in) at any time,
    -- which no size event reports: while the map is open, refit when its scale changes.
    local lastScale = MapScale()
    map:HookScript("OnUpdate", function()
        SyncQuestLogSetting()
        -- The map came to the front (it was clicked): stay above it.
        if frame and frame:IsShown() and frame.docked then
            -- The map fades while the player moves (an option of the game's): fade with it.
            local a = map:GetAlpha()
            if math.abs(frame:GetAlpha() - a) > 0.001 then frame:SetAlpha(a) end
            local strata, level = DockPlace()
            if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
            if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
        end
        -- Something showed the hidden quest log again: keep it out of sight under the panel.
        if covering and map.QuestLog and map.QuestLog:GetAlpha() ~= 0 then map.QuestLog:SetAlpha(0) end
        local now = MapScale()
        if math.abs(now - lastScale) > 0.0001 then
            lastScale = now
            if frame and frame:IsShown() and frame.docked then Queue() end
        end
    end)

    local log = map.QuestLog
    if not log then return end
    -- The quest log was opened some other way: it comes in over the node panel.
    log:HookScript("OnShow", function()
        if internal then return end
        if frame and frame:IsShown() and frame.docked then ClosePanel("peek") end
        C_Timer.After(0, MeasureQuestLayout) -- once the window has laid itself out
    end)
    -- A quest was opened (from the tracker, a map pin, ...): show the quest log.
    for _, name in ipairs({ "QuestMapFrame_ShowQuestDetails", "QuestMapFrame_OpenToQuestDetails" }) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, function()
                if covering and frame and frame:IsShown() and frame.docked then
                    ClosePanel("peek")
                elseif State().open and map:IsShown() then
                    -- The map was opened for the quest (from the tracker): the quest log stays in
                    -- front, and the panel doesn't take its place this time (it is back the next
                    -- time the map opens).
                    peeking = true
                    if covering and not (frame and frame:IsShown()) then Cover(false) end
                end
            end)
        end
    end

    -- The M and L keys, while the node panel is in use (otherwise the game's own way is left
    -- alone). M opens the map as it was left (with the panel) and closes it, whatever is at the
    -- side. L is the game's as ever: the quest log (in the panel's place), and again closes the map.
    local settled = false -- the map has been open for at least a frame (not opened just now)
    map:HookScript("OnUpdate", function() settled = true end)
    map:HookScript("OnHide", function()
        settled = false
        peeking = false
        SyncQuestLogSetting()
    end)
    local busy = false
    local function CanAct() return not InCombatLockdown() end -- addons cannot open or close the map in combat
    local function DockedShown() return frame and frame:IsShown() and frame.docked end
    local function SettingOn() return GetCV and GetCV("questLogOpen") == "1" end

    if type(map.HandleUserActionToggleSelf) == "function" then
        hooksecurefunc(map, "HandleUserActionToggleSelf", function()
            if busy or not map:IsShown() or MapIsFullScreen() or not FN.db.dock then return end
            if not settled then
                RestorePanel() -- just opened: the panel straight away if it is the usual view
            elseif covering then
                -- The panel was up with the setting off: the game only hid the quest log under
                -- it. M closes the map.
                if not log:IsShown() and not SettingOn() and CanAct() then HideUIPanel(map) end
            elseif (peeking or State().open) and CanAct() then
                -- The quest log was up in the panel's place and the setting is off: the game only
                -- hid the quest log. M closes the map (the panel is back the next time it opens).
                HideUIPanel(map)
            elseif not log:IsShown() and not DockedShown() and SettingOn() and CanAct() then
                -- Nothing at the side with the setting on (the panel was closed): the game leaves
                -- the map as it is. M closes it.
                HideUIPanel(map)
            end
        end)
    end

    if type(map.HandleUserActionToggleQuestLog) == "function" then
        hooksecurefunc(map, "HandleUserActionToggleQuestLog", function()
            if busy then return end
            if not map:IsShown() then
                -- The panel was up (the quest log under it), so the game closed the map. L asks
                -- for the quest log: the map opens again with it, in this same frame.
                if covering and CanAct() and type(map.HandleUserActionOpenQuestLog) == "function" then
                    busy = true
                    map:HandleUserActionOpenQuestLog()
                    busy = false
                else
                    return
                end
            end
            if not (map:IsShown() and log:IsShown()) then return end
            -- The quest log is up, in the panel's place if the panel is in use.
            if DockedShown() then
                ClosePanel("peek")
            else
                if covering then Cover(false) end
                peeking = State().open and true or false
            end
        end)
    end
end

-- The docking setting was switched: a side panel that is open floats free at once.
function FN:DockSettingChanged()
    if frame and frame:IsShown() and frame.docked and not FN.db.dock then
        wantPanel = false
        State().open = false
        SyncQuestLogSetting()
        ApplyLayout()
    end
end

function FN:RefreshOptions()
    if frame and frame:IsShown() then SyncAll() end
end

-- The window's own close button.
function FN:CloseWindow()
    if frame.docked then
        ClosePanel("x")
    else
        frame:Hide()
    end
end

-- The floating window (/fn, Esc menu).
function FN:ToggleOptions()
    if not frame then CreateOptions() end
    if frame:IsShown() and not frame.docked then
        frame:Hide()
        return
    end
    wantPanel = false
    if frame:IsShown() then
        State().open = false
        SyncQuestLogSetting()
        ApplyLayout() -- was the side panel: let go of the map
    else
        frame:Show()
    end
    frame:Raise()
end

-- /fn: with docking on, open the world map with the node panel in it; otherwise the window.
function FN:OpenFromCommand()
    local map = WorldMapFrame
    if not (FN.db.dock and map) or InCombatLockdown() then
        FN:ToggleOptions() -- docking is off, or the map cannot be opened from here in combat
        return
    end
    if map:IsShown() then
        FN:ToggleMapPanel()
        return
    end
    if ToggleWorldMap then ToggleWorldMap() else ShowUIPanel(map) end
    if not map:IsShown() or MapIsFullScreen() then
        FN:ToggleOptions() -- no map side to sit in
        return
    end
    OpenPanel()
end

-- Opens Forever Nodes (docked or floating, as set) with its Settings page showing.
-- Already open: just switches to Settings rather than closing it.
function FN:OpenToSettings()
    selected = SETTINGS -- the layout keeps this selection when the window first shows
    if frame and frame:IsShown() then
        ShowPage(SETTINGS)
        frame:Raise()
        return
    end
    FN:OpenFromCommand()
    if frame and frame:IsShown() then ShowPage(SETTINGS) end
end

-- The fishing list's shortcut: Settings, with the Professions section open.
function FN:ShowProfessionSettings()
    ShowPage(SETTINGS)
    FN:OpenSettingsSection("colors")
    settingsScroll:SetVerticalScroll(0)
    settingsScroll:Update()
end

-- Whether Forever Nodes is open (the side panel, or the window with docking off).
function FN:MapPanelOpen()
    return frame and frame:IsShown() or false
end

-- The world map button: the side panel, swapping places with the quest log.
function FN:ToggleMapPanel()
    if not FN.db.dock or MapIsFullScreen() then -- docking is off, or there is no side to attach to
        FN:ToggleOptions()
        return
    end
    if frame and frame:IsShown() and frame.docked then
        ClosePanel("button")
        return
    end
    OpenPanel()
end

-- The first launch tour (Buttons.lua draws it; these set the panel up for each step) -------------

local touring, tourPanel, tourSaved = false, false, nil

-- The tour needs the docked panel, which cannot be opened full screen or (often) in combat.
function FN:TourAvailable()
    return FN.db.dock and not MapIsFullScreen() and not InCombatLockdown()
end

-- The first gathering profession the character has, for the tour only.
local function TourProfession()
    for _, kind in ipairs({ "herb", "ore" }) do
        if FN:GetSkillInfo(kind) then return kind end
    end
    return FN.kindNames.herb and "herb" or FN.kinds[1]
end

-- The nearest trainer's row in the open trainer list.
local function TourTrainer()
    for _, row in ipairs(nodesPage.trainers.rows) do
        if row:IsShown() and row.t then return row end
    end
    return nil
end

-- Returns false when the step has nothing to show.
function FN:TourPrepare(step)
    if not touring then
        touring = true
        tourSaved = { page = selected, sort = FN.db.sort }
    end
    local page = step == 6 and SETTINGS or TourProfession()
    selected = page
    if not (frame and frame:IsShown() and frame.docked) then OpenPanel() end
    tourPanel = true
    if not frame then return true end
    ShowPage(page)
    -- The sort step's gold highlight should be the only one in the tab row.
    if step == 5 then navTabs[page]:SetSelected(false) end
    local trainers, header = nodesPage.trainers, nodesPage.header
    if header and page ~= SETTINGS then header:TourHover(step == 3) end
    if step == 4 then
        if not trainers.open then trainers:Open() end
        local row = TourTrainer()
        if row then row.pin:Show() end -- only the picture: no pin is placed
        return row ~= nil
    end
    if trainers.open then trainers:Close() end
    return true
end

-- The sort switch can be tried as much as the player likes; it is put back afterwards.
function FN:TourSort()
    nodesPage.sortToggle:Click()
    navTabs[selected]:SetSelected(false)
end

local function ScreenRect(region, pad)
    local left, top = region:GetLeft(), region:GetTop()
    if not (left and top) then return nil end
    local scale = region:GetEffectiveScale()
    pad = pad or 0
    return { l = left * scale - pad, r = region:GetRight() * scale + pad,
        t = top * scale + pad, b = region:GetBottom() * scale - pad }
end

-- What stays lit in a step, in screen pixels.
function FN:TourRects(step)
    if not (frame and frame:IsShown()) then return nil end
    local rect, circle
    if step == 1 then
        -- The profession tabs.
        for _, kind in ipairs(FN.kinds) do
            local tab = ScreenRect(navTabs[kind], 3)
            if tab and rect then
                rect.l, rect.r = math.min(rect.l, tab.l), math.max(rect.r, tab.r)
                rect.t, rect.b = math.max(rect.t, tab.t), math.min(rect.b, tab.b)
            elseif tab then
                rect = tab
            end
        end
    elseif step == 2 then
        -- The node rows, however many there are.
        rect = ScreenRect(nodesPage.scroll)
        local first, last = nodesPage.rows[1], nodesPage.rows[#(nodesPage.list or {})]
        local top, bottom = first and ScreenRect(first), last and ScreenRect(last)
        if rect and top and bottom then
            rect.t = top.t + 2
            rect.b = math.max(rect.b, bottom.b - 2)
        end
    elseif step == 3 then
        rect = ScreenRect(nodesPage.header.bar, 3)
    elseif step == 4 then
        local row = TourTrainer()
        rect = row and ScreenRect(row, 2)
    elseif step == 5 then
        rect = ScreenRect(nodesPage.sortToggle, 4)
    else
        circle = navTabs[SETTINGS]
    end
    local lit = circle and ScreenRect(circle) or rect
    local panel = ScreenRect(frame)
    if not (lit and panel) then return nil end
    return { rects = { rect }, circle = circle, click = step >= 3 and step <= 5, left = panel.l,
        y = (lit.t + lit.b) / 2 }
end

-- Over, or the map was closed part way: the panel closes and everything is as it was.
function FN:TourFinish()
    if not touring then return end
    touring = false
    local saved = tourSaved
    tourSaved = nil
    if nodesPage.trainers and nodesPage.trainers.open then nodesPage.trainers:Close() end
    if nodesPage.header then nodesPage.header:TourHover(false) end
    FN.db.sort = saved.sort
    if tourPanel then
        tourPanel = false
        if WorldMapFrame:IsShown() and frame and frame:IsShown() then
            ClosePanel("x")
        else
            State().open = false
            SyncQuestLogSetting()
        end
    end
    if frame and frame:IsShown() then ShowPage(saved.page or selected) else selected = saved.page end
    if frame then RefreshNodes() end
    if FN.RefreshOptions then FN:RefreshOptions() end
end

-- The nearby node style picker ---------------------------------------------------------------
-- Offered once, after the first launch note's Okay (and any time with /fn style): how a node in
-- range looks on the minimap. Circle and Dot put the marker back to its defaults with that shape
-- on and the other off (Circle keeps both borders, Dot only its own). Custom mix keeps the settings as they are and
-- opens them beside the picker. A choice shows on the minimap straight away.

local MARKER_KEYS = { "dotOn", "dotColorMode", "dotColor", "dotSize", "dotEdgeOn", "dotEdgeColorMode",
    "dotEdgeColor", "dotEdgeRadius", "dotEdgeWidth", "circleOn", "circleColorMode", "circleColor",
    "circleRadius", "circleWidth", "circleEdgeOn", "circleEdgeColorMode", "circleEdgeColor",
    "circleEdgeRadius", "circleEdgeWidth" }

local function CopyValue(v)
    if type(v) ~= "table" then return v end
    return { v[1], v[2], v[3], v[4] }
end

-- The marker settings of the Circle or Dot style.
local function StyleValues(shape)
    local s = {}
    for _, key in ipairs(MARKER_KEYS) do s[key] = CopyValue(FN.defaults[key]) end
    s.dotOn, s.circleOn = shape == "dot", shape == "circle"
    s.dotEdgeOn, s.circleEdgeOn = true, shape == "circle"
    return s
end

local function SameValue(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do
            if math.abs((a[i] or 1) - (b[i] or 1)) > 0.001 then return false end
        end
        return true
    end
    if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 0.001 end
    return a == b
end

-- "circle" or "dot" while the saved settings are exactly that style; "custom" otherwise.
local function CurrentStyle()
    for _, shape in ipairs({ "circle", "dot" }) do
        local s, same = StyleValues(shape), true
        for _, key in ipairs(MARKER_KEYS) do
            if not SameValue(FN.db[key], s[key]) then
                same = false
                break
            end
        end
        if same then return shape end
    end
    return "custom"
end

local picker
local PREVIEW = 76    -- each choice's sample of map
local CHOICE_W = 92
local STYLES = { { "circle", "Circle" }, { "dot", "Dot" }, { "custom", "Custom mix" } }

-- The profession color the samples are drawn in: the first one the character has.
local function SampleColor()
    for _, kind in ipairs(FN.kinds) do
        if FN:GetSkill(kind) then return FN.db.colors[kind] end
    end
    return FN.db.colors[FN.kinds[1]]
end

local function DrawSample(choice)
    local values = choice.key ~= "custom" and StyleValues(choice.key) or nil
    FN:DrawMarker(choice.sample, SampleColor(), values)
    local room = PREVIEW - 8
    local whole = math.max(choice.sample:GetWidth(), 1)
    choice.sample:SetScale(math.max(math.min(2, room / whole), 0.5))
end

local function PaintChoices()
    for _, choice in ipairs(picker.choices) do
        local on = picker.selected == choice.key
        for _, edge in ipairs(choice.edges) do
            if on then
                edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
            else
                edge:SetColorTexture(0, 0, 0, 1)
            end
        end
        choice.label:SetTextColor(on and GOLD[1] or 0.85, on and GOLD[2] or 0.85, on and GOLD[3] or 0.85)
        DrawSample(choice)
    end
end

local function Choose(key)
    picker.selected = key
    if key == "custom" then
        -- The settings as they are, open beside the picker to be changed.
        FN:OpenToSettings()
        if FN.OpenSettingsSection then FN:OpenSettingsSection("nearby") end
    else
        local values = StyleValues(key)
        for _, k in ipairs(MARKER_KEYS) do FN.db[k] = values[k] end
        if FN.Restyle then FN:Restyle() end
        FN:RefreshOptions()
    end
    PaintChoices()
end

local function BuildPicker()
    picker = CreateFrame("Frame", "ForeverNodesStylePicker", UIParent)
    picker:SetSize(3 * CHOICE_W + 2 * 12 + 40, 232)
    picker:SetPoint("CENTER", 0, 120)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetToplevel(true)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    picker:SetMovable(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverNodesStylePicker") -- Esc closes it

    -- The same window frame as the panel's floating window.
    local shell = Stock() and TryTemplate("Frame", nil, picker, "BasicFrameTemplate")
    local framed = shell ~= nil
    shell = shell or CreateFrame("Frame", nil, picker)
    shell:SetAllPoints()
    shell:SetFrameLevel(picker:GetFrameLevel())
    shell:EnableMouse(false)
    local skin = Skin()
    if skin then
        skin.Shell(shell)
    elseif not framed then
        local bg = Fill(shell, "BACKGROUND", 0.07, 0.055, 0.04, 0.96)
        bg:SetAllPoints()
        Outline(shell, shell, BRONZE[1] * 0.6, BRONZE[2] * 0.6, BRONZE[3] * 0.6, 1)
    end
    local close = framed and shell.CloseButton
    if not close then
        close = CreateFrame("Button", nil, shell, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        if skin and skin.CloseButton then skin.CloseButton(close) end
    end
    close:SetScript("OnClick", function() picker:Hide() end)
    local TITLE_TEXT = "Nearby Node Style"
    local stockTitle = framed and (shell.TitleText or (shell.TitleContainer and shell.TitleContainer.TitleText))
    if stockTitle then
        stockTitle:SetText(TITLE_TEXT)
    else
        local title = Label(shell, "GameFontNormal", TITLE_TEXT)
        title:SetPoint("TOP", 0, -6)
    end

    local about = Label(picker, "GameFontHighlightSmall",
        "How nodes in range show on your minimap, beside the game's own node dot. "
        .. "You can change it anytime in Settings > Look & Feel > Nearby.")
    about:SetWidth(picker:GetWidth() - 36)
    about:SetJustifyH("CENTER")
    if about.SetWordWrap then about:SetWordWrap(true) end
    about:SetPoint("TOP", 0, -32)

    picker.choices = {}
    local left = -(3 * CHOICE_W + 2 * 12) / 2
    for i, style in ipairs(STYLES) do
        local choice = CreateFrame("Button", nil, picker)
        choice.key = style[1]
        choice:SetSize(CHOICE_W, PREVIEW + 24)
        choice:SetPoint("TOPLEFT", picker, "TOP", left + (i - 1) * (CHOICE_W + 12), -72)
        local map = CreateFrame("Frame", nil, choice)
        map:SetSize(PREVIEW, PREVIEW)
        map:SetPoint("TOP")
        local ground = map:CreateTexture(nil, "BACKGROUND")
        ground:SetTexture(FN.MEDIA .. "preview_map")
        ground:SetAllPoints()
        choice.edges = Outline(map, ground, 0, 0, 0, 1)
        for _, edge in ipairs(choice.edges) do edge:SetDrawLayer("OVERLAY") end
        local glow = choice:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(ground)
        glow:SetColorTexture(1, 1, 1, 0.08)
        choice.sample = CreateFrame("Frame", nil, map)
        choice.sample:SetPoint("CENTER")
        FN:MarkerTextures(choice.sample)
        FN:MarkerGoldDot(choice.sample)
        choice.label = Label(choice, "GameFontNormal", style[2])
        choice.label:SetPoint("TOP", map, "BOTTOM", 0, -6)
        choice:SetScript("OnClick", function() Choose(choice.key) end)
        picker.choices[i] = choice
    end

    local done = Card(picker, "Done", 110, 22, function() picker:Hide() end)
    done:SetPoint("BOTTOM", 0, 14)

    -- Custom mix's sample follows the settings while they are changed beside it.
    local since = 0
    picker:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since < 0.2 then return end
        since = 0
        DrawSample(picker.choices[3])
    end)
    picker:Hide()
    picker:SetScript("OnHide", function() FN.db.styleOffered = true end) -- seen and closed
end

-- `overMap`: centered on the open world map's map area (after the first launch note); otherwise
-- (/fn style) a little above the middle of the screen.
function FN:ShowStylePicker(overMap)
    if not picker then BuildPicker() end
    picker:ClearAllPoints()
    local map = WorldMapFrame
    if overMap and map and map:IsShown() then
        picker:SetPoint("CENTER", map.ScrollContainer or map, "CENTER")
    else
        picker:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    picker.selected = CurrentStyle()
    PaintChoices()
    picker:Show()
    picker:Raise()
end

-- After the first launch note's Okay: offered once.
function FN:OfferStylePicker()
    if FN.db.styleOffered then return end
    FN:ShowStylePicker(true)
end

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

local function Label(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    local skin = Skin()
    if skin and skin.Font then skin.Font(fs) end
    if text then fs:SetText(text) end
    return fs
end

-- A dark see-through pane with a faint edge.
local function Pane(parent)
    if Stock() then
        local inset = TryTemplate("Frame", nil, parent, "InsetFrameTemplate")
        if inset then return inset end
    end
    local pane = CreateFrame("Frame", nil, parent)
    local bg = Fill(pane, "BACKGROUND", 0, 0, 0, 0.30)
    bg:SetAllPoints()
    Outline(pane, pane, 1, 1, 1, 0.08)
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
    local thumb = Fill(sf, "OVERLAY", BRONZE[1], BRONZE[2], BRONZE[3], 0.8)
    thumb:SetWidth(3)

    function sf:Update()
        local view, content = self:GetHeight(), child:GetHeight()
        local range = math.max(0, content - view)
        local offset = math.min(self:GetVerticalScroll(), range)
        self:SetVerticalScroll(offset)
        if range <= 0 or view <= 0 then
            thumb:Hide()
            return
        end
        local size = math.max(20, view * view / content)
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        -- thumbOffset pushes the marker out past the pane's border, like the quest log's scroll bar.
        thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", self.thumbOffset or 0, -(view - size) * (offset / range))
        thumb:Show()
    end
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * ROW_HEIGHT * 2))
        self:Update()
    end)
    sf:SetScript("OnSizeChanged", function(self) self:Update() end)
    return sf
end

-- A card-style button: faint fill and edge, bronze when selected.
local function Card(parent, text, width, height, onClick)
    if Stock() then
        local stock = StockButton(parent, text, width, height, onClick)
        if stock then return stock end
    end
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.bg = Fill(b, "BACKGROUND", 1, 1, 1, 0.04)
    b.bg:SetAllPoints()
    b.edges = Outline(b, b, 1, 1, 1, 0.20)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3], 0.12)
    hl:SetAllPoints()
    b.text = Label(b, "GameFontNormalSmall", text)
    b.text:SetPoint("CENTER")
    b:SetScript("OnClick", onClick)
    function b:SetSelected(selected)
        if selected then
            self.bg:SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3], 0.18)
            for _, edge in ipairs(self.edges) do edge:SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3], 0.70) end
        else
            self.bg:SetColorTexture(1, 1, 1, 0.04)
            for _, edge in ipairs(self.edges) do edge:SetColorTexture(1, 1, 1, 0.20) end
        end
    end
    return b
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

-- An icon-only tab for the side panel's top row: gold edge when it is the open page.
local function IconTab(parent, icon, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(46, 44)
    local stock = Stock()
    if stock then
        -- No plate around an unselected tab, so the icon can be larger. The open tab
        -- gets the same rounded gold edge as the lit half of the Lvl / A-Z switch,
        -- over the whole tab (icon and skill), like the EllesmereUI look's selector.
        b.bg = Rounded(b, "BACKGROUND", "round_fill")
        b.edge = Rounded(b, "BORDER", "round_edge")
        local hl = Rounded(b, "HIGHLIGHT", "round_fill")
        hl:SetVertexColor(1, 1, 1, 0.08)
        b.stockPlate = true
    else
        b.bg = Rounded(b, "BACKGROUND", "round_fill")
        b.edge = Rounded(b, "BORDER", "round_edge")
        local hl = Rounded(b, "HIGHLIGHT", "round_fill")
        hl:SetVertexColor(1, 1, 1, 0.10)
    end
    b.pic = b:CreateTexture(nil, "ARTWORK")
    -- Padded inside the tab's edge (the open tab's frame), the skill number underneath.
    b.pic:SetSize(stock and 24 or 20, stock and 24 or 20)
    b.pic:SetPoint("TOP", 0, stock and -4 or -5)
    b.pic:SetTexture(icon)
    b.pic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.level = Label(b, "GameFontHighlightSmall") -- the character's skill, under the icon
    b.level:SetPoint("BOTTOM", 0, stock and 4 or 5)
    b.level:SetText(" ")
    b:SetScript("OnClick", onClick) -- no tooltip: the page title says which tab is open
    function b:SetSelected(isSelected)
        self.isSelected = isSelected
        if self.stockPlate then
            -- Only the open tab shows a plate: the switch's lit-half colors.
            self.bg:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], isSelected and 0.30 or 0)
            self.edge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], isSelected and 0.85 or 0)
        elseif isSelected then
            self.bg:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.45)
            self.edge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.95)
        elseif self.locked then -- cannot be opened: a dark, receding edge
            self.bg:SetVertexColor(0, 0, 0, 0.45)
            self.edge:SetVertexColor(1, 1, 1, 0.07)
        else
            self.bg:SetVertexColor(0, 0, 0, 0.45)
            self.edge:SetVertexColor(1, 1, 1, 0.22)
        end
    end
    -- A profession the character does not have: greyed and darkened.
    function b:SetDimmed(dimmed)
        self.pic:SetDesaturated(dimmed)
        self.pic:SetVertexColor(dimmed and 0.45 or 1, dimmed and 0.45 or 1, dimmed and 0.45 or 1)
    end
    -- A tab that cannot be clicked gets a darker edge than one that can.
    function b:SetLocked(locked)
        self.locked = locked
        self:SetEnabled(not locked)
        self:SetSelected(self.isSelected or false)
    end
    return b
end

-- One choice of a pick-one control: a rounded square, lit when it is the active choice.
local function Segment(parent, text, width, onClick)
    if Stock() then
        local stock = StockButton(parent, text, width, 22, onClick)
        if stock then return stock end
    end
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 22)
    b.bg = Rounded(b, "BACKGROUND", "round_fill")
    b.edge = Rounded(b, "BORDER", "round_edge")
    local hl = Rounded(b, "HIGHLIGHT", "round_fill")
    hl:SetVertexColor(1, 1, 1, 0.10)
    b.text = Label(b, "GameFontHighlightSmall", text)
    b.text:SetPoint("CENTER")
    b:SetScript("OnClick", onClick)
    function b:SetSelected(selected)
        if selected then
            self.bg:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.60)
            self.edge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.90)
            self.text:SetTextColor(1, 1, 1)
        else
            self.bg:SetVertexColor(1, 1, 1, 0.05)
            self.edge:SetVertexColor(1, 1, 1, 0.25)
            self.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
        end
    end
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
    c:SetScript("OnLeave", function() label:SetTextColor(1, 1, 1) end)
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
    local syncing = false
    s:SetScript("OnValueChanged", function(_, v)
        v = Snapped(v)
        value:SetText(fmt:format(v))
        if not syncing and not onRelease and v ~= get() then set(v) end
    end)
    if onRelease then
        s:SetScript("OnMouseUp", function(self)
            local v = Snapped(self:GetValue())
            if v ~= get() then set(v) end
        end)
    end
    holder.Sync = function()
        syncing = true
        s:SetValue(get())
        value:SetText(fmt:format(get()))
        syncing = false
    end
    syncers[#syncers + 1] = holder.Sync
    return holder
end

-- Color picker extras: a hex box and Copy / Paste, attached under the game's picker.

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
    local f = CreateFrame("Frame", nil, ColorPickerFrame)
    f:SetSize(252, 36)
    f:SetPoint("TOP", ColorPickerFrame, "BOTTOM", 0, -2)
    f:EnableMouse(true)
    local bg = Fill(f, "BACKGROUND", 0.07, 0.055, 0.04, 0.96)
    bg:SetAllPoints()
    Outline(f, f, BRONZE[1] * 0.6, BRONZE[2] * 0.6, BRONZE[3] * 0.6, 1)

    local hash = Label(f, nil, "#")
    hash:SetPoint("LEFT", 12, 0)
    local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    box:SetSize(76, 20)
    box:SetPoint("LEFT", hash, "RIGHT", 9, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(9)
    box:SetScript("OnEnterPressed", function(self)
        local r, g, b, a = HexToColor(self:GetText())
        self:ClearFocus()
        if r then f.set(r, g, b, a) else f.sync() end
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f.sync()
    end)
    f.box = box

    local copy = Card(f, "Copy", 58, 22, function()
        local c = f.color
        copiedColor = { c[1], c[2], c[3], c[4] or 1 }
    end)
    copy:SetPoint("LEFT", box, "RIGHT", 12, 0)
    local paste = Card(f, "Paste", 58, 22, function()
        if copiedColor then f.set(copiedColor[1], copiedColor[2], copiedColor[3], copiedColor[4]) end
    end)
    paste:SetPoint("LEFT", copy, "RIGHT", 4, 0)

    ColorPickerFrame:HookScript("OnHide", function() f:Hide() end)
    pickerExtras = f
    return f
end

local function PickColor(color, onChange)
    -- color = { r, g, b, opacity }; opacity is 1 when it was never set.
    local r0, g0, b0, a0 = color[1], color[2], color[3], color[4] or 1
    local extras = PickerExtras()
    extras.color = color
    function extras.sync()
        if not extras.box:HasFocus() then extras.box:SetText(ColorToHex(color)) end
    end
    function extras.set(r, g, b, a) -- from the hex box or Paste; six-digit hex keeps the opacity
        a = a or color[4] or 1
        SetPicker(r, g, b, a)
        color[1], color[2], color[3], color[4] = r, g, b, a
        onChange()
        extras.sync()
    end
    local modern = ColorPickerFrame.SetupColorPickerAndShow ~= nil
    local function Apply()
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
    -- Our window sits above a maximized map; keep the picker above our window.
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ColorPickerFrame:Raise()
    extras:Show()
    extras.sync()
end

-- `getColor` returns the saved { r, g, b } table the swatch edits.
local function Swatch(parent, text, getColor)
    local b = CreateFrame("Button", nil, parent)
    local chip = Fill(b, "ARTWORK", 1, 1, 1)
    chip:SetSize(26, 14)
    chip:SetPoint("LEFT")
    Outline(b, chip, 0, 0, 0, 1)
    local label = Label(b, nil, text)
    label:SetPoint("LEFT", chip, "RIGHT", 7, 0)
    b:SetSize(label:GetStringWidth() + 36, 20)
    b:SetScript("OnEnter", function() label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
    b:SetScript("OnLeave", function() label:SetTextColor(1, 1, 1) end)
    local function Sync()
        local c = getColor()
        chip:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
    b:SetScript("OnClick", function()
        PickColor(getColor(), function()
            Sync()
            FN:Restyle()
            if FN.ColorsChanged then FN:ColorsChanged() end -- text shown in a profession's color
        end)
    end)
    syncers[#syncers + 1] = Sync
    return b
end

-- Nodes page -----------------------------------------------------------------

local frame
local nodesPage = { rows = {}, tabs = {} }

-- Skill-up colors as recipes show them: r, g, b, and whether the row gets a tinted background.
local function Difficulty(skill, need)
    if not skill or need <= 0 then return MUTED[1], MUTED[2], MUTED[3], false end
    if skill < need then return 1, 0.13, 0.13, false end -- cannot gather yet
    local over = skill - need
    if over < 25 then return 1, 0.5, 0.25, true end      -- orange
    if over < 50 then return 1, 1, 0, true end           -- yellow
    if over < 100 then return 0.25, 0.75, 0.25, true end -- green
    return 0.5, 0.5, 0.5, false                          -- grey
end

local LIST_BLEED = 9 -- how far left of the page the pane's border is: row stripes run out to it

local function CreateRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(COL_WIDTH, ROW_HEIGHT)
    -- Rows are divided by a thin line under each, and light up whole on hover;
    -- both run from the pane's border to the row's right edge.
    r.line = Fill(r, "BACKGROUND", 1, 1, 1, 0.07)
    r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT", -LIST_BLEED, 0)
    r.line:SetPoint("BOTTOMRIGHT")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 1, 1, 0.08)
    hl:SetPoint("TOPLEFT", -LIST_BLEED, 0)
    hl:SetPoint("BOTTOMRIGHT")

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
        FN:Refresh()
    end)
    return r
end

local function RefreshNodes()
    local page = nodesPage
    local db = FN.db

    -- The profession picked in the left list. One this character lacks is only
    -- opened while "Lock professions I don't have" is off.
    local skills = {}
    for _, kind in ipairs(FN.kinds) do skills[kind] = FN:GetSkill(kind) end
    local current = page.kind
    if current and not (skills[current] or db.showAll) then current = nil end

    -- Docked to the map the window is narrow: the controls tighten up to stay on
    -- one row with the title, and the list is a single scrolling column.
    local compact = frame.docked
    local pageWidth = frame.pageWidth or (compact and (DOCK_WIDTH - 40) or (WIDTH - NAV_WIDTH - 48))
    local listTop = -36
    page.none:SetWidth(compact and 96 or 104)
    page.all:SetWidth(compact and 68 or 76)
    page.rule:ClearAllPoints()
    page.rule:SetPoint("TOPLEFT", 0, listTop + 7)
    page.rule:SetPoint("TOPRIGHT", 0, listTop + 7)
    page.scroll:ClearAllPoints()
    -- The list's clipping area starts at the pane's border (LIST_BLEED left of the
    -- page) so the row stripes can run out to it; the rows themselves stay put.
    page.scroll:SetPoint("TOPLEFT", -LIST_BLEED, listTop)
    page.scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    page.fishNote:SetShown(current == "fish")

    page.title:SetText(current and FN.kindNames[current] or "")
    page.sortToggle:SetMode(db.sort)
    page.sortLabel:SetShown(current ~= nil and not compact) -- the side panel has the toggle in its top row
    page.all:SetShown(current ~= nil)
    page.none:SetShown(current ~= nil)
    page.empty:SetShown(current == nil)

    local list = {}
    if current then
        for _, node in ipairs(FN.nodes) do
            if node.kind == current then list[#list + 1] = node end
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

    local perCol = compact and #list or math.ceil(#list / 2)
    local rowWidth = compact and (pageWidth - 6) or COL_WIDTH
    local skill = current and skills[current]
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
        row:SetPoint("TOPLEFT", LIST_BLEED + col * (COL_WIDTH + COL_GAP), -line * ROW_HEIGHT)
        row.node = node
        row.icon:SetTexture(node.icon)
        row.name:SetText(node.name)
        row.mark:SetShown(FN.enabled[node.key] and true or false)
        local r, g, b, tinted = Difficulty(skill, node.skill)
        row.skill:SetText(node.skill > 0 and node.skill or "")
        row.skill:SetTextColor(r, g, b)
        row.tint:SetFade(r, g, b, tinted and 0.38 or 0)
        row:Show()
    end
    for i = #list + 1, #page.rows do page.rows[i]:Hide() end

    -- Fishing's one-line note sits centered under the list, 16px below the last row.
    -- It belongs to the list's scroll area (which would cover it otherwise) and scrolls with the rows.
    local note = page.fishNote
    note:SetParent(page.scroll.child)
    note:ClearAllPoints()
    note:SetPoint("TOP", page.scroll.child, "TOPLEFT", LIST_BLEED + pageWidth / 2, -perCol * ROW_HEIGHT - 16)
    local listHeight = perCol * ROW_HEIGHT
    if current == "fish" then listHeight = listHeight + 16 + math.ceil(note:GetStringHeight()) end

    page.scroll.child:SetSize(pageWidth + LIST_BLEED, math.max(1, listHeight))
    page.scroll:Update()
end

local function BuildNodesPage(page)
    nodesPage.frame = page

    nodesPage.title = Label(page, "GameFontNormalLarge")
    nodesPage.title:SetPoint("TOPLEFT", 2, -3)

    local function SetAll(state)
        for _, node in ipairs(nodesPage.list or {}) do
            FN.enabled[node.key] = state or nil
        end
        FN:Refresh()
        RefreshNodes()
    end
    nodesPage.none = Card(page, "Clear Selection", 104, 24, function() SetAll(false) end)
    nodesPage.all = Card(page, "Select All", 76, 24, function() SetAll(true) end)
    nodesPage.all:SetPoint("TOPRIGHT")
    nodesPage.none:SetPoint("RIGHT", nodesPage.all, "LEFT", -4, 0)

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

    nodesPage.empty = Label(page, "GameFontDisable",
        "This character has no gathering profession.\n\nTurn off \"Lock professions I don't have\" under Settings > Professions to see every node.")
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
    nodesPage.empty:SetPoint("TOPLEFT", 10, -120)
    nodesPage.empty:SetPoint("TOPRIGHT", -10, -120)

end

-- Settings page ----------------------------------------------------------------

local function Header(page, text, x, y)
    local fs = Label(page, "GameFontNormal", text)
    fs:SetPoint("TOPLEFT", x, y)
    local line = Fill(page, "ARTWORK", BRONZE[1], BRONZE[2], BRONZE[3], 0.35)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", x, y - 18)
    line:SetWidth(250)
end

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
        fill:SetColorTexture(0.20, 0.13, 0.07, 0.85)
        Outline(header, header, 0.55, 0.42, 0.20, 0.55)
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
        fill:SetColorTexture(1, 1, 1, 0.07)
        sign = Label(header, "GameFontNormalLarge")
        sign:SetPoint("RIGHT", -9, 0)
        sign:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    end

    local content = CreateFrame("Frame", nil, column)
    content:SetSize(SECTION_WIDTH - 2 * SECTION_INSET, height)
    section.header, section.content = header, content
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function(width)
        header:SetWidth(width)
        content:SetWidth(width - 2 * SECTION_INSET)
    end

    -- A thin border in the header bar's color around an open section's contents,
    -- hanging from the header (which is its top).
    local box = CreateFrame("Frame", nil, column)
    box:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    box:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
    local edges
    if stock then
        edges = Outline(box, box, 0.20, 0.13, 0.07, 0.85)
    else
        edges = Outline(box, box, 1, 1, 1, 0.10)
    end
    edges[1]:Hide() -- the header is the top edge
    -- A very faint tint inside, so the open section reads as one block.
    local tint = stock and Fill(box, "BACKGROUND", 0.20, 0.13, 0.07, 0.25) or Fill(box, "BACKGROUND", 1, 1, 1, 0.025)
    tint:SetAllPoints()
    section.box = box

    function section:IsCollapsed()
        return FN.db.collapsed[key] == true
    end
    function section:Paint()
        local collapsed = self:IsCollapsed()
        content:SetShown(not collapsed)
        box:SetShown(not collapsed)
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
        onToggle()
    end)
    return section
end

-- Stacks sections down `column`; returns the height they take.
local function StackSections(column, sections)
    local y = 0
    for _, section in ipairs(sections) do
        section.header:ClearAllPoints()
        section.header:SetPoint("TOPLEFT", column, "TOPLEFT", 0, y)
        section:Paint()
        y = y - SECTION_HEADER
        if not section:IsCollapsed() then
            -- An open section gets the same padding above and below its contents.
            section.content:ClearAllPoints()
            section.content:SetPoint("TOPLEFT", column, "TOPLEFT", SECTION_INSET, y - SECTION_PAD)
            section.content:SetHeight(section.height)
            section.box:SetHeight(SECTION_PAD + section.height + SECTION_PAD)
            y = y - SECTION_PAD - section.height - SECTION_PAD
        end
        y = y - SECTION_GAP -- the same gap between every pair of headers
    end
    return math.max(1, -y)
end

local function BuildSettingsPage(columnA, columnB)
    local db = FN.db
    -- On a fresh install only Maps starts open; after that the player's own choices are kept.
    if type(db.collapsed) ~= "table" then
        db.collapsed = { colors = true, nearby = true, lists = true, window = true }
    end

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

    -- Sections, top to bottom in each block. `Relayout(true)` also re-fits the window.
    local sectionsA, sectionsB = {}, {}
    local function Relayout(refit)
        COLUMN_A_HEIGHT = StackSections(columnA, sectionsA)
        COLUMN_B_HEIGHT = StackSections(columnB, sectionsB)
        columnA:SetHeight(COLUMN_A_HEIGHT)
        columnB:SetHeight(COLUMN_B_HEIGHT)
        if refit and frame and frame:IsShown() then FN:UpdateDock() end
    end
    local function Toggled() Relayout(true) end
    local function Add(list, column, key, title, height)
        local section = Section(column, key, title, height, Toggled)
        list[#list + 1] = section
        return section, section.content
    end

    -- Maps ---------------------------------------------------------------------
    -- The minimap and the world map each have their own settings; the switch picks
    -- which map the controls below are showing and editing.
    local maps, page = Add(sectionsA, columnA, "maps", "Maps & Icons", 164)
    local editing = "minimap"
    local function Look() return db.icons[editing] end
    local function LookNumber(key)
        return function() return Look()[key] end, function(v)
            Look()[key] = v
            FN:Restyle()
        end
    end
    -- One switch, like the sort control: "Minimap | World map", the active half lit.
    local mapToggle = PairToggle(page, "Minimap", "World map", function()
        editing = editing == "minimap" and "world" or "minimap"
        ResyncAll()
        Relayout(true) -- the minimap has more settings than the world map
    end)
    mapToggle:SetPoint("TOP", page, "TOP", 0, 0) -- centered in the section

    -- Whether nodes show on the chosen map at all; its wording names that map.
    local show = Check(page, "Show on minimap",
        function() return db[editing == "minimap" and "minimap" or "worldmap"] end,
        function(v)
            db[editing == "minimap" and "minimap" or "worldmap"] = v and true or false
            FN:Refresh()
        end)
    show:SetPoint("TOPLEFT", 0, -30)
    syncers[#syncers + 1] = function()
        mapToggle:SetRight(editing == "world")
        show:SetLabel(editing == "minimap" and "Show on minimap" or "Show on world map")
    end

    local zoom = Slider(page, "Circular icon zoom", 1, 2.5, 0.05, "%.2fx", LookNumber("zoom"))

    -- Minimap only: its shape (where icons stop at the edge) and how far out they draw.
    local shapeLabel = Label(page, nil, "Shape")
    local shapeCards = {}
    for i, choice in ipairs({ "auto", "round", "square" }) do
        local card = Card(page, choice == "auto" and "Auto" or choice == "round" and "Round" or "Square", 54, 22,
            function()
                db.minimapShape = choice
                ResyncAll()
                Relayout(true)
            end)
        card.offset = 62 + (i - 1) * 58
        shapeCards[choice] = card
    end
    local detected = Label(page, "GameFontDisableSmall", "")
    local edge = Slider(page, "Draw range", 50, 125, 1, "%d%%", Number("minimapEdge"))
    -- The minimap-only part: a line across the section in its border's color, and under it
    -- "Advanced", which opens and closes the controls below it (closed by default).
    local miniLine = Stock() and Fill(page, "ARTWORK", 0.20, 0.13, 0.07, 0.85) or Fill(page, "ARTWORK", 1, 1, 1, 0.10)
    miniLine:SetHeight(1)
    local advanced = CreateFrame("Button", nil, page)
    advanced:SetSize(220, 20) -- the clickable area covers the whole label
    local advancedText = Label(advanced, "GameFontDisable", "Advanced Minimap Settings") -- grey; gold on hover
    advancedText:SetPoint("CENTER")
    advanced:SetScript("OnEnter", function() advancedText:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
    advanced:SetScript("OnLeave", function() advancedText:SetTextColor(0.5, 0.5, 0.5) end)
    -- `page` is reused for the sections that follow; the layout below needs this one.
    local iconsPage = page
    -- Open or not is not saved: Advanced starts closed every time the Icons section
    -- (or the window) is shown again, and after a reload.
    local advancedOpen = false
    db.advancedOpen = nil -- briefly saved by an earlier version; no longer used

    -- Lays out what the chosen map shows: no empty space for hidden controls.
    local function LayoutMaps()
        local y = 128 -- under the icon size slider
        local round = Look().round
        zoom:SetShown(round) -- only meaningful for circular icons
        if round then
            zoom:SetPoint("TOPLEFT", 0, -y)
            y = y + 44
        end
        local mini = editing == "minimap"
        local open = mini and advancedOpen
        miniLine:SetShown(mini)
        advanced:SetShown(mini)
        shapeLabel:SetShown(open)
        detected:SetShown(open)
        edge:SetShown(open)
        for _, card in pairs(shapeCards) do card:SetShown(open) end
        if mini then
            -- The line runs border to border (the contents are inset from the section's edge).
            miniLine:ClearAllPoints()
            miniLine:SetPoint("TOPLEFT", iconsPage, "TOPLEFT", -SECTION_INSET, -(y - 2))
            miniLine:SetPoint("TOPRIGHT", iconsPage, "TOPRIGHT", SECTION_INSET, -(y - 2))
            advanced:SetPoint("TOP", iconsPage, "TOP", 0, -(y + 3)) -- centered across, and level between the line and the border
            y = y + (open and 32 or 30)
        end
        if open then
            -- Draw range first, then the shape.
            edge:SetPoint("TOPLEFT", 0, -y)
            y = y + 44
            for choice, card in pairs(shapeCards) do
                card:SetSelected(db.minimapShape == choice)
                card:SetPoint("TOPLEFT", card.offset, -y)
            end
            shapeLabel:SetPoint("TOPLEFT", 0, -(y + 5))
            local name = FN:DetectedMinimapShape()
            detected:SetText("Detected: " .. (name == "ROUND" and "round" or name == "SQUARE" and "square" or name:lower()))
            detected:SetPoint("TOPLEFT", shapeCards.auto, "BOTTOMLEFT", 0, -4)
            y = y + 46
        end
        maps.height = y - 10
    end
    advanced:SetScript("OnClick", function()
        advancedOpen = not advancedOpen
        LayoutMaps()
        Relayout(true)
    end)
    -- Hidden (the Icons section closed, or the window or panel closed): close it again.
    iconsPage:HookScript("OnHide", function()
        if advancedOpen then
            advancedOpen = false
            LayoutMaps()
        end
    end)
    Check(page, "Circular Icons (crop to look cleaner)",
        function() return Look().round end,
        function(v)
            Look().round = v and true or false
            LayoutMaps()
            Relayout(true)
            FN:Restyle()
        end):SetPoint("TOPLEFT", 0, -54)
    syncers[#syncers + 1] = LayoutMaps
    Slider(page, "Icon size", 8, 32, 1, "%d", LookNumber("size")):SetPoint("TOPLEFT", 0, -84)

    -- Colors -------------------------------------------------------------------
    -- Professions: each one's color, and whether ones the character lacks can be opened.
    _, page = Add(sectionsA, columnA, "colors", "Professions", 94)
    local note = Label(page, "GameFontDisableSmall", "Shared by the circle and the dot.")
    note:SetPoint("TOPLEFT", 0, 0)
    Swatch(page, "Herbs", function() return db.colors.herb end):SetPoint("TOPLEFT", 0, -20)
    Swatch(page, "Mining", function() return db.colors.ore end):SetPoint("TOPLEFT", 78, -20)
    Swatch(page, "Fishing", function() return db.colors.fish end):SetPoint("TOPLEFT", 156, -20)
    -- Labels that name a profession in its own color, repainted when a swatch changes.
    local recordLabels = {}
    local function Hex(kind)
        local c = db.colors[kind]
        local function Byte(v) return math.floor((v or 1) * 255 + 0.5) end
        return ("%02x%02x%02x"):format(Byte(c[1]), Byte(c[2]), Byte(c[3]))
    end
    -- Herbs need Find Herbs on and ore Find Minerals (characters without the spell see them anyway).
    local tracked = Check(page, "Only show herbs/ore when tracked",
        function() return db.onlyTracked end,
        function(v)
            db.onlyTracked = v and true or false
            FN:Refresh()
        end)
    tracked:SetPoint("TOPLEFT", 0, -50)
    local function PaintTracked()
        tracked:SetLabel("Only show |cff" .. Hex("herb") .. "herbs|r/|cff" .. Hex("ore") .. "ore|r when tracked")
    end
    syncers[#syncers + 1] = PaintTracked
    recordLabels[#recordLabels + 1] = PaintTracked
    -- Professions the character lacks are always listed, greyed out; ticked (the default)
    -- they cannot be opened. The saved setting is the other way round (showAll).
    Check(page, "Lock professions I don't have",
        function() return not db.showAll end,
        function(v)
            db.showAll = not v
            FN:RefreshOptions()
        end):SetPoint("TOPLEFT", 0, -74)

    -- Nearby nodes -------------------------------------------------------------
    local GROUP_TOP, CIRCLE_HEIGHT, DOT_HEIGHT, RING_HEIGHT = 86, 156, 152, 122
    local nearby
    nearby, page = Add(sectionsB, columnB, "nearby", "Nearby nodes", GROUP_TOP + CIRCLE_HEIGHT)
    local rangeLabel = Label(page, nil, "Switch to a marker within")
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
    local yards = Label(page, nil, "yards")
    yards:SetPoint("LEFT", range, "RIGHT", 6, 0)
    local hint = Label(page, "GameFontDisableSmall",
        "Nodes officially appear at " .. FN.DEFAULT_RANGE .. " yds")
    hint:SetPoint("TOPLEFT", 0, -29)

    -- Marker style, and only the options that belong to the chosen one.
    local styleLabel = Label(page, nil, "Show as")
    styleLabel:SetPoint("TOPLEFT", 0, -57)
    local groups, styleCards = {}, {}
    for i, style in ipairs({ "circle", "dot" }) do
        local card = Card(page, style == "circle" and "Circle" or "Dot", 78, 22, function()
            db.nearStyle = style
            ResyncAll() -- shows this style's options and re-stacks the sections
            Relayout(true)
            FN:Restyle()
        end)
        card:SetPoint("TOPLEFT", 62 + (i - 1) * 82, -52)
        styleCards[style] = card
        local group = CreateFrame("Frame", nil, page)
        group:SetSize(SECTION_WIDTH, CIRCLE_HEIGHT)
        sectionWidthFollowers[#sectionWidthFollowers + 1] = function(width) group:SetWidth(width - 2 * SECTION_INSET) end
        group:SetPoint("TOPLEFT", 0, -GROUP_TOP)
        groups[style] = group
    end

    local circle = groups.circle
    Slider(circle, "Circle size", 8, 40, 1, "%d", Number("circleSize")):SetPoint("TOPLEFT", 0, 0)
    Slider(circle, "Line width", 1, 8, 0.5, "%.1f", Number("circleLine")):SetPoint("TOPLEFT", 0, -44)
    Slider(circle, "Border width", 0, 4, 0.5, "%.1f", Number("circleBorder")):SetPoint("TOPLEFT", 0, -88)
    Swatch(circle, "Border color", function() return db.circleBorderColor end):SetPoint("TOPLEFT", 0, -132)

    local dot = groups.dot
    Slider(dot, "Dot size", 0, 12, 1, "%d", Number("dotSize")):SetPoint("TOPLEFT", 0, 0)
    Slider(dot, "Border width", 0, 4, 0.5, "%.1f", Number("dotBorder")):SetPoint("TOPLEFT", 0, -44)
    Swatch(dot, "Border color", function() return db.dotBorderColor end):SetPoint("TOPLEFT", 0, -88)

    -- A line across the whole section, border to border, above the second border's options.
    local separator = Stock() and Fill(dot, "ARTWORK", 0.20, 0.13, 0.07, 0.85) or Fill(dot, "ARTWORK", 1, 1, 1, 0.10)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", -SECTION_INSET, -120)
    separator:SetPoint("TOPRIGHT", dot, "TOPRIGHT", SECTION_INSET, -120)

    -- The dot's optional second border: a thin ring around it. Its own controls
    -- show only while it is on.
    local ring = CreateFrame("Frame", nil, dot)
    ring:SetSize(SECTION_WIDTH, RING_HEIGHT)
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function(width) ring:SetWidth(width - 2 * SECTION_INSET) end
    ring:SetPoint("TOPLEFT", 0, -162)
    Slider(ring, "Ring size", 4, 30, 1, "%d", Number("dotRingSize")):SetPoint("TOPLEFT", 0, 0)
    Slider(ring, "Ring width", 0.5, 4, 0.5, "%.1f", Number("dotRingWidth")):SetPoint("TOPLEFT", 0, -44)
    Swatch(ring, "Ring color", function() return db.dotRingColor end):SetPoint("TOPLEFT", 0, -88)

    -- Shows the chosen style's options and sizes the section to fit them.
    local function ShowStyle()
        for style, group in pairs(groups) do
            group:SetShown(style == db.nearStyle)
            styleCards[style]:SetSelected(style == db.nearStyle)
        end
        ring:SetShown(db.dotRing)
        local groupHeight = CIRCLE_HEIGHT
        if db.nearStyle == "dot" then
            groupHeight = DOT_HEIGHT + (db.dotRing and RING_HEIGHT or 0)
        end
        nearby.height = GROUP_TOP + groupHeight
    end
    Check(dot, "Add a second ring/circle/border", Bool("dotRing", function()
        ShowStyle()
        Relayout(true)
        FN:Restyle()
    end)):SetPoint("TOPLEFT", 0, -130)
    syncers[#syncers + 1] = ShowStyle

    -- Node lists ---------------------------------------------------------------
    _, page = Add(sectionsB, columnB, "lists", "Discovery", 68)
    -- Recording, one setting per profession. Each saves where a node was found (a herb
    -- or vein when it is gathered, a pool when loot comes out of it); new types join
    -- their list unticked. The profession's word is in that profession's own color
    -- (Colors section), and follows it when it changes.
    for i, rec in ipairs({
        { key = "recordHerb", kind = "herb", before = "Record new ", word = "herb", after = " locations" },
        { key = "recordOre", kind = "ore", before = "Record new ", word = "mining", after = " locations" },
        { key = "record", kind = "fish", before = "Record new ", word = "fishing", after = " spots" },
    }) do
        local box = Check(page, rec.before .. rec.word .. rec.after, Bool(rec.key, function() end))
        box:SetPoint("TOPLEFT", 0, -24 * (i - 1))
        local function Paint()
            box:SetLabel(rec.before .. "|cff" .. Hex(rec.kind) .. rec.word .. "|r" .. rec.after)
        end
        syncers[#syncers + 1] = Paint
        recordLabels[#recordLabels + 1] = Paint
    end
    -- While a color is being picked, the words follow it straight away.
    function FN:ColorsChanged()
        for i = 1, #recordLabels do recordLabels[i]() end
    end

    -- Window -------------------------------------------------------------------
    _, page = Add(sectionsB, columnB, "window", "Window", 88)
    -- The floating window and the docked panel each keep their own scale (scale and
    -- dockScale), so a size chosen for one never carries into the other.
    local function ScaleKey() return (frame and frame.docked) and "dockScale" or "scale" end
    local scale = Slider(page, "Scale", 0.7, 1.5, 0.05, "%.2fx",
        function() return db[ScaleKey()] end,
        function(v)
            db[ScaleKey()] = v
            frame:SetScale(v)
            FN:UpdateDock()
        end, true)
    scale:SetPoint("TOPLEFT", 0, -54) -- last, under the two tick boxes
    -- Docked, scaling the panel's contents can spill them past the panel: flagged there
    -- with a small red tag beside the label, on the same baseline.
    local experimental = Label(scale, "GameFontNormalSmall", "EXPERIMENTAL")
    experimental:SetTextColor(1, 0.25, 0.25)
    local font, size, flags = experimental:GetFont()
    if font and size then experimental:SetFont(font, math.max(size - 2, 8), flags) end -- a step smaller than the label
    experimental:SetPoint("BOTTOMLEFT", scale.label, "BOTTOMRIGHT", 6, 0)
    sectionWidthFollowers[#sectionWidthFollowers + 1] = function()
        experimental:SetShown(frame and frame.docked or false)
        scale.Sync() -- the value of the mode now showing
    end
    Check(page, "Dock to the world map (map button)", Bool("dock", function()
        FN:DockSettingChanged()
    end)):SetPoint("TOPLEFT", 0, -24)
    Check(page, "Show the minimap button",
        function() return FN:MinimapButtonShown() end,
        function(v) FN:SetMinimapButtonShown(v and true or false) end):SetPoint("TOPLEFT", 0, 0)

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
    if frame.docked then
        toggle:SetParent(nav)
        toggle:SetPoint("CENTER", navGap, "CENTER") -- midway between the last icon and Settings
        toggle:Show() -- kept in the row on the Settings tab too, so the row does not change
    else
        toggle:SetParent(pages.Nodes)
        toggle:SetPoint("RIGHT", nodesPage.none, "LEFT", -12, 0)
        toggle:Show()
    end
end

local function ShowPage(key)
    selected = key
    if key ~= SETTINGS then nodesPage.kind = key end
    pages.Nodes:SetShown(key ~= SETTINGS)
    pages.Settings:SetShown(key == SETTINGS)
    for rowKey, row in pairs(navRows) do
        row:SetSelected(rowKey == key)
        navTabs[rowKey]:SetSelected(rowKey == key)
    end
    PlaceSortToggle()
    if key ~= SETTINGS then RefreshNodes() end
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

-- Kept in the saved settings, so it survives closing the map and reloading:
--   open         the node panel is the map's side panel
-- (Older versions also kept questBefore / nodesBefore to swap the two panels
-- back; that was dropped, and ClosePanel clears any left in saved settings.)
local function State()
    local db = FN.db
    if type(db.panel) ~= "table" then db.panel = {} end
    return db.panel
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

local function ShouldDock()
    local map = WorldMapFrame
    return wantPanel and FN.db.dock and map and map:IsShown() and not MapIsFullScreen() or false
end

local function SetQuestLog(show)
    local map = WorldMapFrame
    if not map.QuestLog or QuestLogShown() == show then return end
    if InCombatLockdown() and map:IsProtected() then return end -- the map cannot be resized in combat
    internal = true
    if map.HandleUserActionToggleSidePanel then
        map:HandleUserActionToggleSidePanel()
    elseif show and QuestMapFrame_Open then
        QuestMapFrame_Open()
    elseif not show and QuestMapFrame_Close then
        QuestMapFrame_Close()
    end
    internal = false
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
local function CloneArt(source, target, flip)
    local copies, owners = {}, { [source] = true }
    local function CopyRegions(owner)
        for _, region in ipairs({ owner:GetRegions() }) do
            if region:IsObjectType("Texture") and region:IsShown() then
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
            local ok, placed = pcall(CloneArt, source, made, flip)
            if ok and placed and placed > 0 then ornates[pane] = made else made:Hide() end
        end
    end
    local ornate = ornates[pane]
    if not ornate then return end
    ornate:SetShown(on)
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
    if MapOwnsItsSize() or (InCombatLockdown() and map:IsProtected()) then return end
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
    if mergeGaveUp or MapOwnsItsSize() or (InCombatLockdown() and map:IsProtected()) then
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

local function ApplyLayout()
    local docked = ShouldDock()
    frame.docked = docked
    frame:SetScale(docked and FN.db.dockScale or FN.db.scale) -- each mode has its own scale
    -- Esc closes the floating window. The side panel instead follows the map, so
    -- that closing the map with Esc does not count as closing the panel.
    SetEscCloses(not docked)

    -- Three shapes: merged into the map window (no frame of its own), attached
    -- beside it as a narrow window (when merging is not possible), or floating.
    local merged, mergedWidth = false, MERGED_WIDTH
    if docked then
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
        if not floating then
            floating = true
            frame:SetClampedToScreen(true)
            frame:ClearAllPoints()
            frame:SetSize(WIDTH, HEIGHT)
            frame:SetPoint("CENTER")
        end
    end
    frame.shell:SetShown(not merged) -- merged, the map window is the frame
    UseQuestBorder(body, merged and Stock())
    UseQuestBorder(nav, merged and Stock(), true) -- the tab row is on top: its crest goes at the bottom
    -- With the ornate border the scroll marker sits outside the box, in the strip
    -- the quest log uses for its scroll bar.
    local thumbOffset = (merged and Stock()) and 24 or 0
    nodesPage.scroll.thumbOffset = thumbOffset
    settingsScroll.thumbOffset = thumbOffset
    frame.pageWidth = (merged and (mergedWidth - 20)) or (docked and (DOCK_WIDTH - 40))
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
    elseif docked then
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

    local firstUsable
    for i, key in ipairs(order) do
        local row, tab = navRows[key], navTabs[key]
        if key ~= SETTINGS then
            local known = skills[key] ~= nil
            local usable = known or FN.db.showAll
            local icon = ProfessionIcon(key)
            row.pic:SetTexture(icon)
            row.tag:SetText(known and skills[key] or "")
            row:SetDimmed(not known)
            row:SetEnabled(usable)
            tab.pic:SetTexture(icon)
            tab.level:SetText(known and skills[key] or "")
            tab:SetDimmed(not known)
            tab:SetLocked(not usable)
            if usable and not firstUsable then firstUsable = key end
        end
        -- Side panel: icon tabs in one row, Settings at the far right. Window: a list down the left.
        row:SetShown(not docked)
        tab:SetShown(docked)
        tab:ClearAllPoints()
        if key == SETTINGS then
            tab:SetPoint("TOPRIGHT", -4, -4)
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
    navSeparator:SetShown(not docked)
    navSeparator:ClearAllPoints()
    navSeparator:SetPoint("TOPLEFT", 10, -6 - (#order - 1) * 32 - 6)
    navSeparator:SetPoint("TOPRIGHT", -10, -6 - (#order - 1) * 32 - 6)

    -- Keep the selection on something that can be opened.
    if not selected or (selected ~= SETTINGS and not (skills[selected] or FN.db.showAll)) then
        selected = firstUsable or SETTINGS
    end
    ShowPage(selected)

    -- Settings: two blocks side by side, or stacked (and scrolling) in the side panel.
    local pageWidth = frame.pageWidth
    -- Stacked in the side panel, the sections run the panel's full width; side by side
    -- in the window they keep their fixed width.
    -- (pageWidth + 1 leaves the same margin on the right as the panel leaves on the left.)
    local sectionWidth = docked and math.floor(pageWidth + 1) or SECTION_WIDTH
    for i = 1, #sectionWidthFollowers do sectionWidthFollowers[i](sectionWidth) end
    columnB:ClearAllPoints()
    if docked then
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
    navTabs[SETTINGS] = IconTab(nav, gear, OpenSettings)
    navTabs[SETTINGS].pic:ClearAllPoints() -- no skill number under it, so center the gear
    navTabs[SETTINGS].pic:SetPoint("CENTER")
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

    frame:SetScript("OnShow", SyncAll)
    frame:SetScript("OnHide", UndoMerge) -- hand the map window back at its own size
    frame:Hide()
end

-- Opening and closing the side panel ----------------------------------------------

local function OpenPanel()
    if not frame then CreateOptions() end
    wantPanel = true
    State().open = true
    MeasureQuestLayout() -- while the quest log is still up, note the room it takes
    SetQuestLog(false)
    if frame:IsShown() then
        ApplyLayout() -- was floating: attach it
    else
        frame:Show()
    end
    frame:Raise()
end

-- why: "button" (the node button), "x" (the panel's close button) or "quest"
-- (the player opened the quest log).
local function ClosePanel(why)
    -- One side panel at a time, and closing one leaves none open: neither panel
    -- brings the other back.
    local state = State()
    state.open = false
    state.questBefore, state.nodesBefore = nil, nil
    frame:Hide()
end

-- Re-opens the side panel when the map comes back (or after a reload) if it was
-- open when the map was last closed.
local function RestorePanel()
    local map = WorldMapFrame
    if not (map and map:IsShown()) or MapIsFullScreen() or not FN.db.dock then return end
    local state = State()
    if not state.open then return end
    if frame and frame:IsShown() and frame.docked then return end
    if QuestLogShown() then -- the quest log has the side: go with what is on screen
        state.open = false
        return
    end
    OpenPanel()
end

-- Re-fits the window after its scale or the map changes. A side panel closes with
-- the map, and when the map goes full screen (it is remembered, not forgotten).
function FN:UpdateDock()
    if not (frame and frame:IsShown()) then return end
    if frame.docked and not ShouldDock() then
        frame:Hide()
        return
    end
    ApplyLayout()
end

-- Called once at login: keeps the side panel in step with the map and the quest log.
function FN:SetupMapPanel()
    local map = WorldMapFrame
    if not map then return end

    local reopenPending = false -- the quest log was just closed and the node panel is due back

    -- Runs straight after each step of the map's own resizing, in the same frame,
    -- so the window is never drawn half-way (which showed as a flash).
    local settling = false
    local function Settle()
        if settling or internal then return end
        settling = true
        if reopenPending then
            if map:IsShown() and not QuestLogShown() and not MapIsFullScreen() then
                OpenPanel()
            end
        elseif frame and frame:IsShown() and frame.docked and ShouldDock() then
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
            if reopenPending then
                Settle()
                reopenPending = false
            end
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

    local log = map.QuestLog
    if not log then return end
    -- The player opened the quest log: it takes the side over from the node panel.
    log:HookScript("OnShow", function()
        if internal then return end
        reopenPending = false
        if frame and frame:IsShown() and frame.docked then ClosePanel("quest") end
        C_Timer.After(0, MeasureQuestLayout) -- once the window has laid itself out
    end)
    -- The player closed the quest log: bring the node panel back if it had been
    -- replaced. The map is still mid-resize here, so Settle does it once that is done.
    log:HookScript("OnHide", function()
        reopenPending = false -- closing the quest log leaves the side empty
    end)
end

-- The docking setting was switched: a side panel that is open floats free at once.
function FN:DockSettingChanged()
    if frame and frame:IsShown() and frame.docked and not FN.db.dock then
        wantPanel = false
        State().open = false
        ApplyLayout()
    end
end

function FN:RefreshOptions()
    if frame and frame:IsShown() then SyncAll() end
end

function FN:OptionsShown()
    return frame ~= nil and frame:IsShown()
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
        ApplyLayout() -- was the side panel: let go of the map
    else
        frame:Show()
    end
    frame:Raise()
end

-- /fn: with docking on, open the world map with the node panel in it; otherwise the window.
function FN:OpenFromCommand()
    local map = WorldMapFrame
    if not (FN.db.dock and map) or (InCombatLockdown() and map:IsProtected()) then
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

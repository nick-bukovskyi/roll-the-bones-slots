-- Authored cabinet geometry and artwork shared by native results and editor samples
local ADDON_NAME, ns = ...
local Art = { Width = 400, Height = 246, SymbolSize = 112, Pitch = 99, SpinRows = 12,
    LanePitch = 128, VariantSymbols = { 2, 3, 4 } }
ns.Art = Art
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\media\\"
local CABINET_HEIGHT = 630 / 1024
local WELLS = { { 53, 39, 91, 153 }, { 153, 39, 94, 153 }, { 258, 39, 91, 153 } }
local IDLE_SYMBOLS = { 2, 3, 1 }
local ORDINARY_SYMBOL_COUNT = 4
local LIGHT_LEVEL_OFFSET, SYMBOL_LEVEL_OFFSET = 10, 20
local NORMAL_FLASH = {
    { rise = 0.12, hold = 0.04, fade = 0.24, gap = 0.14, strength = 1 },
    { rise = 0.12, hold = 0.04, fade = 0.26, gap = 0, strength = 1 },
}
local JACKPOT_FLASH = {
    { rise = 0.10, hold = 0.05, fade = 0.20, gap = 0.10, strength = 0.75 },
    { rise = 0.10, hold = 0.05, fade = 0.22, gap = 0.13, strength = 0.90 },
    { rise = 0.12, hold = 0.16, fade = 0.38, gap = 0, strength = 1 },
}
-- Centered crops of the original 512-pixel symbol canvases, preserving visible scale
local SYMBOL_RECTS = {
    { 0, 0, 344, 416 }, { 344, 0, 376, 416 }, { 720, 0, 304, 416 },
    { 0, 416, 512, 416 }, { 512, 416, 512, 416 },
}

local function Texture(parent, file, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(MEDIA .. file, "CLAMP", "CLAMP", "LINEAR")
    return texture
end

function Art.Label(parent, text, font, x, y, width, height)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    label:SetSize(width, height)
    label:SetText(text)
    return label
end

function Art.Cabinet(parent)
    local texture = Texture(parent, "cabinet.tga", "BACKGROUND")
    texture:SetAllPoints(parent)
    texture:SetTexCoord(0, 1, 0, CABINET_HEIGHT)
    Art.Label(parent, "Roll the Bones", "GameFontNormalLarge", 56, 11, 288, 22)
    Art.Label(parent, "Awaiting a result", "GameFontDisable", 56, 207, 288, 22)
end

function Art.Symbol(parent, symbol, size)
    -- Authored IDs only; the native slot decides whether this artwork is visible
    local rect = SYMBOL_RECTS[symbol]
    local texture = Texture(parent, "symbols.tga")
    texture:SetSize(size * rect[3] / 512, size * rect[4] / 512)
    texture:SetTexCoord(rect[1] / 1024, (rect[1] + rect[3]) / 1024,
        rect[2] / 1024, (rect[2] + rect[4]) / 1024)
    return texture
end

local function ReelBacking(parent, index, extended, x)
    local bounds = WELLS[index]
    local left, right = bounds[1] / Art.Width, (bounds[1] + bounds[3]) / Art.Width
    local top = bounds[2] / Art.Height * CABINET_HEIGHT
    local bottom = (bounds[2] + bounds[4]) / Art.Height * CABINET_HEIGHT
    local texture = Texture(parent, "cabinet.tga", "BACKGROUND")
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, 0)
    texture:SetSize(bounds[3], bounds[4])
    texture:SetTexCoord(left, right, top, bottom)
    if extended then
        -- Extend the opaque well with its edge pixels, preserving its settled artwork
        local above = Texture(parent, "cabinet.tga", "BACKGROUND")
        above:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, Art.Pitch)
        above:SetSize(bounds[3], Art.Pitch)
        above:SetTexCoord(left, right, top - 1 / 1024, top)
        local below = Texture(parent, "cabinet.tga", "BACKGROUND")
        below:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, -bounds[4])
        below:SetSize(bounds[3], (Art.SpinRows + 1) * Art.Pitch)
        below:SetTexCoord(left, right, bottom, bottom + 1 / 1024)
    end
end

function Art.Well(parent, index)
    local bounds = WELLS[index]
    local well = CreateFrame("Frame", nil, parent)
    well:SetPoint("TOPLEFT", parent, "TOPLEFT", bounds[1], -bounds[2])
    well:SetSize(bounds[3], bounds[4])
    well:SetClipsChildren(true)
    ReelBacking(well, index)
    return well
end

local function AddFlashTarget(parent, index, peakAlpha)
    local bounds = WELLS[index]
    local target = CreateFrame("Frame", nil, parent)
    target:SetPoint("TOPLEFT", parent, "TOPLEFT", bounds[1], -bounds[2])
    target:SetSize(bounds[3], bounds[4])
    target:SetAlpha(peakAlpha)
    return target
end

local function AddWinLight(parent, index, peakAlpha)
    local bounds = WELLS[index]
    local halfHeight = bounds[4] / 2
    local edge = CreateColor(0.47, 0.24, 0.02, 0.42)
    local center = CreateColor(1, 0.92, 0.65, 1)
    local target = AddFlashTarget(parent, index, peakAlpha)

    local top = target:CreateTexture(nil, "ARTWORK")
    top:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    top:SetSize(bounds[3], halfHeight)
    top:SetColorTexture(1, 1, 1, 1)
    top:SetGradient("VERTICAL", center, edge)
    top:SetBlendMode("ADD")

    local bottom = target:CreateTexture(nil, "ARTWORK")
    bottom:SetPoint("TOPLEFT", target, "TOPLEFT", 0, -halfHeight)
    bottom:SetSize(bounds[3], halfHeight)
    bottom:SetColorTexture(1, 1, 1, 1)
    bottom:SetGradient("VERTICAL", edge, center)
    bottom:SetBlendMode("ADD")
end

-- Prebuilt artwork; Blizzard alone selects the live rank after initialization
function Art.WinResult(parent, definition)
    parent:SetSize(Art.Width, Art.Height)
    local jackpot = definition.symbols[1] == 5
    for reelIndex, symbol in ipairs(definition.symbols) do
        if symbol == 1 or symbol == 5 then
            AddWinLight(parent, reelIndex, jackpot and 0.88 or 0.58)
        end
    end
end

local function AddAlphaPhase(group, target, fromAlpha, toAlpha, duration, order, smoothing, startDelay)
    local animation = group:CreateAnimation("Alpha")
    assert(animation:SetTarget(target), "Win animation target rejected")
    animation:SetFromAlpha(fromAlpha)
    animation:SetToAlpha(toAlpha)
    animation:SetDuration(duration)
    animation:SetOrder(order)
    if smoothing then animation:SetSmoothing(smoothing) end
    if startDelay and startDelay > 0 then animation:SetStartDelay(startDelay) end
end

local function WinAnimation(owner, definition, startDelay)
    local group = owner:CreateAnimationGroup()
    group:SetLooping("NONE")
    group:SetToFinalAlpha(true)
    local order = 1
    local schedule = definition.symbols[1] == 5 and JACKPOT_FLASH or NORMAL_FLASH
    for pulseIndex, pulse in ipairs(schedule) do
        AddAlphaPhase(group, owner, 0, pulse.strength, pulse.rise, order, "IN_OUT",
            pulseIndex == 1 and startDelay or nil)
        order = order + 1
        AddAlphaPhase(group, owner, pulse.strength, pulse.strength, pulse.hold, order)
        order = order + 1
        AddAlphaPhase(group, owner, pulse.strength, 0, pulse.fade, order, "IN_OUT")
        order = order + 1
        if pulse.gap > 0 then
            AddAlphaPhase(group, owner, 0, 0, pulse.gap, order)
            order = order + 1
        end
    end
    return group
end

function Art.WinEffects(parent, definitions, startDelay)
    local effects = {}
    for index, definition in ipairs(definitions) do
        local owner = CreateFrame("Frame", nil, parent)
        owner:SetAllPoints(parent)
        owner:SetFrameLevel(parent:GetFrameLevel() + LIGHT_LEVEL_OFFSET)
        owner:SetAlpha(0)
        local preview = CreateFrame("Frame", nil, owner)
        preview:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
        Art.WinResult(preview, definition)
        preview:Hide()
        effects[index] = { owner = owner, preview = preview,
            animation = WinAnimation(owner, definition, startDelay) }
    end
    return effects
end

-- Only the stationary well clips this continuous strip, never a moving panel edge
function Art.ReelResult(parent, definition, index)
    local bounds = WELLS[index]
    parent:SetSize(bounds[3], bounds[4])
    local opacity = definition and 1 or 0.22
    local foreground = parent
    if definition then
        -- Keep symbols above the separate light branches and their opaque backing below
        foreground = CreateFrame("Frame", nil, parent)
        foreground:SetAllPoints(parent)
        foreground:SetFrameLevel(parent:GetFrameLevel() + SYMBOL_LEVEL_OFFSET)
    end
    -- Prebuild side-by-side variants before native restrictions, never reskin a live slot
    for lane = 1, index == 1 and 1 or #Art.VariantSymbols do
        local x = (lane - 1) * Art.LanePitch
        ReelBacking(parent, index, true, x)
        local symbol = definition and definition.symbols[index] or IDLE_SYMBOLS[index]
        if symbol == 0 then symbol = Art.VariantSymbols[lane] end
        for offset = -1, Art.SpinRows + 1 do
            -- Lead-in rows are identical for every rank, variant and idle
            local leadIn = offset > 1
            -- The exclusive Jackpot chest is never part of decorative or adjacent rows
            local face = leadIn and (offset + index) % ORDINARY_SYMBOL_COUNT + 1
                or offset == 0 and symbol
                or (symbol + offset + ORDINARY_SYMBOL_COUNT - 1) % ORDINARY_SYMBOL_COUNT + 1
            local texture = Art.Symbol(foreground, face, Art.SymbolSize)
            texture:SetPoint("CENTER", foreground, "CENTER", x, -offset * Art.Pitch)
            texture:SetAlpha(leadIn and 1 or opacity * (offset == 0 and 1 or 0.45))
        end
    end
end

function Art.Footer(parent, definition)
    parent:SetSize(Art.Width, Art.Height)
    local backing = Texture(parent, "cabinet.tga", "BACKGROUND")
    backing:SetPoint("TOPLEFT", parent, "TOPLEFT", 53, -205)
    backing:SetSize(292, 26)
    backing:SetTexCoord(53 / Art.Width, 345 / Art.Width,
        205 / Art.Height * CABINET_HEIGHT, 231 / Art.Height * CABINET_HEIGHT)
    local icon
    if definition then
        icon = Art.Symbol(parent, definition.symbols[1], 22)
        icon:SetPoint("CENTER", parent, "TOPLEFT", 71, -218)
    else
        icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
        icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 60, -207)
    end
    local name = Art.Label(parent, "", "GameFontNormal", 88, 207, 198, 22)
    name:SetJustifyH("LEFT")
    local duration = Art.Label(parent, "", "GameFontHighlight", 288, 207, 55, 22)
    duration:SetJustifyH("RIGHT")
    if definition then
        name:SetText(definition.label)
        duration:SetText("26 s")
    end
    return icon, name, duration
end

function Art.NativeFooter(button)
    local icon, name, duration = Art.Footer(button)
    button:SetIcon(icon)
    button:SetSpellName(name)
    button:SetDurationText(duration)
end

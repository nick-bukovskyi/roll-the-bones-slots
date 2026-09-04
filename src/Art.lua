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

function Art.SetSymbol(texture, symbol)
    -- Authored IDs only; the native slot decides whether this artwork is visible
    if symbol == 5 then
        texture:SetTexture(MEDIA .. "jackpot.tga", "CLAMP", "CLAMP", "LINEAR")
        texture:SetTexCoord(0, 1, 0, 1)
        return
    end
    texture:SetTexture(MEDIA .. "symbols.tga", "CLAMP", "CLAMP", "LINEAR")
    local column, row = (symbol - 1) % 2, math.floor((symbol - 1) / 2)
    texture:SetTexCoord(column / 2, (column + 1) / 2, row / 2, (row + 1) / 2)
end

function Art.Symbol(parent, symbol, size)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetSize(size, size)
    Art.SetSymbol(texture, symbol)
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

-- Only the stationary well clips this continuous strip, never a moving panel edge
function Art.ReelResult(parent, definition, index)
    local bounds = WELLS[index]
    parent:SetSize(bounds[3], bounds[4])
    local opacity = definition and 1 or 0.22
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
            local texture = Art.Symbol(parent, face, Art.SymbolSize)
            texture:SetPoint("CENTER", parent, "CENTER", x, -offset * Art.Pitch)
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
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 60, -207)
    local name = Art.Label(parent, "", "GameFontNormal", 88, 207, 198, 22)
    name:SetJustifyH("LEFT")
    local duration = Art.Label(parent, "", "GameFontHighlight", 288, 207, 55, 22)
    duration:SetJustifyH("RIGHT")
    if definition then
        Art.SetSymbol(icon, definition.symbols[1])
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

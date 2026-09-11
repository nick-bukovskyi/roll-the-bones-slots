-- Authored cabinet geometry and artwork shared by native results and editor samples
local ADDON_NAME, ns = ...
local Layouts = ns.Layouts
local Art = {
  ReelHeight = 153,
  SymbolSize = 112,
  Pitch = 99,
  SpinRows = 12,
  LanePitch = 128,
  VariantSymbols = { 2, 3, 4, 6, 7 },
  WinRestAlpha = 0.23,
}
ns.Art = Art
local ART_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\public\\art\\"
local FOOTER = Layouts.Footer
local IDLE_SYMBOLS = { 2, 3, 4 }
local MATCHING_NEIGHBORS = { { 7, 2 }, { 6, 4 }, { 3, 7 } }
local ORDINARY_SYMBOLS = { 1 }
for _, symbol in ipairs(Art.VariantSymbols) do
  ORDINARY_SYMBOLS[#ORDINARY_SYMBOLS + 1] = symbol
end
local REEL_LEVEL_OFFSET, LIGHT_LEVEL_OFFSET, SYMBOL_LEVEL_OFFSET = 4, 10, 20
-- Packed cells share a 384-pixel nominal canvas for consistent display scale
local SYMBOL_RECTS = {
  { 0, 0, 336, 336 },
  { 336, 0, 336, 336 },
  { 672, 0, 336, 336 },
  { 0, 336, 336, 336 },
  { 336, 336, 336, 336 },
  { 672, 336, 336, 336 },
  { 0, 672, 336, 336 },
}

local function Texture(parent, file, layer)
  local texture = parent:CreateTexture(nil, layer or "ARTWORK")
  texture:SetTexture(ART_PATH .. file, "CLAMP", "CLAMP", "LINEAR")
  return texture
end

local function Label(parent, text, font, x, y, width, height)
  local label = parent:CreateFontString(nil, "OVERLAY", font)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
  label:SetSize(width, height)
  label:SetText(text)
  return label
end

function Art.Cabinet(parent, layout)
  local texture = Texture(parent, layout.cabinet, "BACKGROUND")
  texture:SetAllPoints(parent)
  texture:SetTexCoord(0, 1, 0, layout.textureBottom)
  if layout.title then
    local title = layout.title
    local label = Label(parent, "Roll the Bones", "GameFontNormalLarge", title.x, title.y, title.width, title.height)
    label:SetJustifyV("MIDDLE")
  end
end

local function FooterLabel(parent, text, font, x, width, layout)
  local style = layout.footer
  local label = Label(parent, text, font, x, style.y + (style.height - style.textHeight) / 2, width, style.textHeight)
  label:SetJustifyV("MIDDLE")
  label:SetShadowColor(0, 0, 0, 1)
  label:SetShadowOffset(1, -1)
  if style.fontSizeOffset ~= 0 then
    -- Preserve Blizzard's locale-specific face and flags without modifying the shared font
    local file, size, flags = label:GetFont()
    assert(label:SetFont(assert(file, "Footer font is unavailable"), size + style.fontSizeOffset, flags), "Footer font rejected")
  end
  return label
end

function Art.EmptyFooter(parent, layout)
  return FooterLabel(parent, "Try yer luck, matey!", "GameFontDisable", 56, 288, layout)
end

function Art.NativeCabinet(parent, layout)
  parent:SetSize(Layouts.Width, layout.height)
  parent:EnableMouse(false)
  Art.Cabinet(parent, layout)
end

function Art.Symbol(parent, symbol, size)
  -- Authored IDs only; the native slot decides whether this artwork is visible
  local rect = SYMBOL_RECTS[symbol]
  local texture = Texture(parent, "symbols.tga")
  texture:SetSize(size * rect[3] / 384, size * rect[4] / 384)
  texture:SetTexCoord(rect[1] / 1024, (rect[1] + rect[3]) / 1024, rect[2] / 1024, (rect[2] + rect[4]) / 1024)
  return texture
end

function Art.NativeReelCover(button, index, layout)
  local column, reel = Layouts.Columns[index], layout.reels
  button:SetSize(column.width, reel.height)
  button:EnableMouse(false)
  local texture = Texture(button, layout.cabinet, "BACKGROUND")
  texture:SetAllPoints(button)
  texture:SetTexCoord(
    column.x / Layouts.Width,
    (column.x + column.width) / Layouts.Width,
    reel.y / layout.height * layout.textureBottom,
    (reel.y + reel.height) / layout.height * layout.textureBottom
  )
end

function Art.LayoutWell(well, parent, index, layout)
  local column = Layouts.Columns[index]
  well:SetPoint("TOPLEFT", parent, "TOPLEFT", column.x, -layout.reels.y)
  well:SetSize(column.width, layout.reels.height)
end

function Art.Well(parent, index)
  local well = CreateFrame("Frame", nil, parent)
  -- Keep the clipping boundary above the native cabinet's opaque reel panels
  well:SetFrameLevel(parent:GetFrameLevel() + REEL_LEVEL_OFFSET)
  Art.LayoutWell(well, parent, index, Layouts.Full)
  well:SetClipsChildren(true)
  return well
end

-- Each light shares its stationary clipping boundary with the matching reel
function Art.WinResult(parent, definition, reelIndex)
  local width = Layouts.Columns[reelIndex].width
  parent:SetSize(width, Art.ReelHeight)
  local halfHeight = Art.ReelHeight / 2
  local edge = CreateColor(0.40, 0.24, 0.05, 0.05)
  local center = CreateColor(1, 0.90, 0.58, 1)
  local target = CreateFrame("Frame", nil, parent)
  target:SetAllPoints(parent)
  target:SetAlpha(1)

  local top = target:CreateTexture(nil, "ARTWORK")
  top:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
  top:SetSize(width, halfHeight)
  top:SetColorTexture(1, 1, 1, 1)
  top:SetGradient("VERTICAL", center, edge)
  top:SetBlendMode("ADD")

  local bottom = target:CreateTexture(nil, "ARTWORK")
  bottom:SetPoint("TOPLEFT", target, "TOPLEFT", 0, -halfHeight)
  bottom:SetSize(width, halfHeight)
  bottom:SetColorTexture(1, 1, 1, 1)
  bottom:SetGradient("VERTICAL", edge, center)
  bottom:SetBlendMode("ADD")
end

local function AddAlphaPhase(group, targets, fromAlpha, toAlpha, duration, order, smoothing, startDelay)
  for _, target in ipairs(targets) do
    local animation = group:CreateAnimation("Alpha")
    assert(animation:SetTarget(target.owner), "Win animation target rejected")
    animation:SetFromAlpha(fromAlpha)
    animation:SetToAlpha(toAlpha)
    animation:SetDuration(duration)
    animation:SetOrder(order)
    if smoothing then
      animation:SetSmoothing(smoothing)
    end
    if startDelay and startDelay > 0 then
      animation:SetStartDelay(startDelay)
    end
  end
end

local function WinAnimation(parent, targets, definition, startDelay)
  local group = parent:CreateAnimationGroup()
  group:SetLooping("NONE")
  group:SetToFinalAlpha(true)
  local jackpot = definition.symbols[1] == 5
  local peak = jackpot and 0.70 or 0.62
  AddAlphaPhase(group, targets, 0, 0, startDelay, 1)
  AddAlphaPhase(group, targets, 0, peak, jackpot and 0.30 or 0.22, 2, "IN_OUT")
  AddAlphaPhase(group, targets, peak, Art.WinRestAlpha, jackpot and 0.80 or 0.48, 3, "IN_OUT")
  return group
end

function Art.WinEffects(parent, definitions, startDelay, wells)
  local effects = {}
  for index, definition in ipairs(definitions) do
    local targets = {}
    for reelIndex, symbol in ipairs(definition.symbols) do
      if symbol == 1 or symbol == 5 then
        local well = wells[reelIndex]
        local owner = CreateFrame("Frame", nil, well)
        owner:SetSize(Layouts.Columns[reelIndex].width, Art.ReelHeight)
        owner:SetPoint("CENTER", well, "CENTER", 0, 0)
        owner:SetFrameLevel(well:GetFrameLevel() + LIGHT_LEVEL_OFFSET)
        owner:SetAlpha(Art.WinRestAlpha)
        local preview = CreateFrame("Frame", nil, owner)
        preview:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
        Art.WinResult(preview, definition, reelIndex)
        preview:Hide()
        targets[#targets + 1] = { owner = owner, preview = preview, reelIndex = reelIndex }
      end
    end
    effects[index] = {
      targets = targets,
      animation = WinAnimation(parent, targets, definition, startDelay),
      restAlpha = Art.WinRestAlpha,
    }
  end
  return effects
end

-- Only the stationary well clips this continuous strip, never a moving panel edge
function Art.ReelResult(parent, definition, index)
  parent:SetSize(Layouts.Columns[index].width, Art.ReelHeight)
  local opacity = definition and 1 or 0.22
  local neighbors = definition and ORDINARY_SYMBOLS or Art.VariantSymbols
  local matching = definition and definition.symbols[1] == definition.symbols[2] and definition.symbols[2] == definition.symbols[3]
  local fixedNeighbors = matching and MATCHING_NEIGHBORS[index]
  local foreground = parent
  if definition then
    -- Native and preview symbols sit above stationary covers and win lights
    foreground = CreateFrame("Frame", nil, parent)
    foreground:SetAllPoints(parent)
    foreground:SetFrameLevel(parent:GetFrameLevel() + SYMBOL_LEVEL_OFFSET)
  end
  -- Prebuild side-by-side variants before native restrictions, never reskin a live slot
  for lane = 1, index == 1 and 1 or #Art.VariantSymbols do
    local x = (lane - 1) * Art.LanePitch
    local symbol = definition and definition.symbols[index] or IDLE_SYMBOLS[index]
    if symbol == 0 then
      symbol = Art.VariantSymbols[lane]
    end
    local ordinaryIndex = 1
    for position, face in ipairs(neighbors) do
      if face == symbol then
        ordinaryIndex = position
        break
      end
    end
    for offset = -1, Art.SpinRows + 1 do
      -- Lead-in rows are identical for every rank, variant and idle
      local leadIn = offset > 1
      -- The exclusive Jackpot die is never part of decorative or adjacent rows
      local face = leadIn and ORDINARY_SYMBOLS[(offset + index) % #ORDINARY_SYMBOLS + 1]
        or offset == 0 and symbol
        or fixedNeighbors and fixedNeighbors[offset == -1 and 1 or 2]
        or neighbors[(ordinaryIndex + offset - 1) % #neighbors + 1]
      local texture = Art.Symbol(foreground, face, Art.SymbolSize)
      texture:SetPoint("CENTER", foreground, "CENTER", x, -offset * Art.Pitch)
      texture:SetAlpha(leadIn and 1 or opacity * (offset == 0 and 1 or 0.45))
    end
  end
end

local function DurationBar(parent, layout)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetPoint("TOPLEFT", parent, "TOPLEFT", FOOTER.x, -layout.footer.y)
  bar:SetSize(FOOTER.width, layout.footer.height)
  bar:SetFrameLevel(parent:GetFrameLevel() + 1)
  bar:EnableMouse(false)
  bar:SetOrientation("HORIZONTAL")
  bar:SetFillStyle(Enum.StatusBarFillStyle.Standard)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)

  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints(bar)
  track:SetColorTexture(0.035, 0.04, 0.047, 1)
  local fill = bar:CreateTexture(nil, "ARTWORK")
  fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar", "CLAMP", "CLAMP", "LINEAR")
  assert(bar:SetStatusBarTexture(fill), "Duration bar texture rejected")
  bar:SetStatusBarColor(132 / 255, 59 / 255, 51 / 255, 1)
  return bar
end

function Art.NativeDurationBar(button, layout)
  button:SetSize(Layouts.Width, layout.height)
  button:EnableMouse(false)
  button:SetDurationBar(DurationBar(button, layout), {
    direction = Enum.StatusBarTimerDirection.RemainingTime,
    interpolation = Enum.StatusBarInterpolation.Immediate,
  })
end

function Art.Footer(parent, definition, layout)
  parent:SetSize(Layouts.Width, layout.height)
  local backing = Texture(parent, layout.cabinet, "BACKGROUND")
  backing:SetPoint("TOPLEFT", parent, "TOPLEFT", FOOTER.x, -layout.footer.y)
  backing:SetSize(FOOTER.width, layout.footer.height)
  backing:SetTexCoord(
    FOOTER.x / Layouts.Width,
    (FOOTER.x + FOOTER.width) / Layouts.Width,
    layout.footer.y / layout.height * layout.textureBottom,
    (layout.footer.y + layout.footer.height) / layout.height * layout.textureBottom
  )
  -- Text and icon sit above the optional sibling native bar and its preview
  local foreground = CreateFrame("Frame", nil, parent)
  foreground:SetAllPoints(parent)
  foreground:SetFrameLevel(parent:GetFrameLevel() + 2)
  local icon, bar
  local centerY = layout.footer.y + layout.footer.height / 2
  if definition then
    bar = DurationBar(parent, layout)
    bar:SetMinMaxValues(0, 30)
    bar:SetValue(26)
    icon = Art.Symbol(foreground, definition.symbols[1], FOOTER.iconSize)
    icon:SetPoint("CENTER", foreground, "TOPLEFT", 66, -centerY)
  else
    icon = foreground:CreateTexture(nil, "ARTWORK")
    icon:SetSize(FOOTER.iconSize, FOOTER.iconSize)
    icon:SetPoint("TOPLEFT", foreground, "TOPLEFT", 58, -centerY + FOOTER.iconSize / 2)
  end
  local name = FooterLabel(foreground, "", "GameFontNormal", 80, 208, layout)
  name:SetJustifyH("LEFT")
  name:SetTextColor(0.94, 0.91, 0.82, 1)
  local duration = FooterLabel(foreground, "", "GameFontHighlight", 288, 55, layout)
  duration:SetJustifyH("RIGHT")
  if definition then
    name:SetText(definition.label)
    duration:SetText("26 s")
  end
  return icon, name, duration, bar
end

function Art.NativeFooter(button, layout)
  local icon, name, duration = Art.Footer(button, nil, layout)
  button:SetHitRectInsets(
    FOOTER.x,
    Layouts.Width - FOOTER.x - FOOTER.width,
    layout.footer.y,
    layout.height - layout.footer.y - layout.footer.height
  )
  button:SetIcon(icon)
  button:SetSpellName(name)
  button:SetDurationText(duration)
end

-- Ordinary carriers roll native-selected artwork without reading its result
local _, ns = ...
local Machine = {}
ns.Machine = Machine
local frame
local layout = ns.Layouts.Full
local reels, displays, modes = {}, {}, {}
local effects = {}
local previewIndex, presentation = 2, "hidden"
local elapsed = 0
local REEL_COUNT = #ns.Game.Results[1].symbols
local ROLL_START, REEL_STAGGER, ROLL_IN, SETTLE = 0.40, 0.18, 0.44, 0.12
local LAST_STOP = ROLL_START + REEL_COUNT * REEL_STAGGER + ROLL_IN + SETTLE

local function StopWinEffects()
  for _, effect in ipairs(effects) do
    effect.animation:Stop()
    for _, target in ipairs(effect.targets) do
      if target.owner:GetAlpha() ~= effect.restAlpha then
        target.owner:SetAlpha(effect.restAlpha)
      end
    end
  end
end

local function MoveReel(reel, offset)
  -- Never anchor to or query a native container or result child
  local variant = presentation == "preview" and reel.previewVariant or reel.variant
  -- Center anchors keep the selected symbol aligned as the well and carrier scale change
  reel.carrier:SetPoint("CENTER", reel.well, "CENTER", -(variant - 1) * ns.Art.LanePitch, offset)
end

function Machine.GetFrame()
  return frame
end

local function SettleReels()
  if not frame then
    return
  end
  frame:SetScript("OnUpdate", nil)
  elapsed = 0
  for _, reel in ipairs(reels) do
    MoveReel(reel, 0)
  end
end

function Machine.StopSpin()
  SettleReels()
  StopWinEffects()
end

local function Animate(_, delta)
  elapsed = elapsed + delta
  if elapsed >= LAST_STOP then
    SettleReels()
    return
  end
  for _, reel in ipairs(reels) do
    local landingTime = elapsed - reel.rollStart
    if landingTime >= ROLL_IN + SETTLE then
      MoveReel(reel, 0)
    elseif landingTime < 0 then
      MoveReel(reel, ns.Art.SpinRows * ns.Art.Pitch - reel.speed * elapsed)
    elseif landingTime < ROLL_IN then
      -- The cubic starts at the scrolling speed and finishes at rest
      local progress = landingTime / ROLL_IN
      MoveReel(reel, reel.speed * ROLL_IN / 3 * (1 - progress) ^ 3)
    else
      local progress = (landingTime - ROLL_IN) / SETTLE
      MoveReel(reel, -3 * math.sin(math.pi * progress) ^ 2)
    end
  end
end

function Machine.Spin()
  if not frame or not frame:IsVisible() then
    return
  end
  StopWinEffects()
  -- Cosmetic choices are independent of the active aura and cannot add winning symbols
  local first = math.random(1, #ns.Art.VariantSymbols)
  local second = math.random(1, #ns.Art.VariantSymbols - 1)
  if second >= first then
    second = second + 1
  end
  local field = presentation == "preview" and "previewVariant" or "variant"
  reels[2][field], reels[3][field] = first, second
  if not ns.Config.GetAnimationEnabled() then
    Machine.StopSpin()
    return
  end
  -- Start every live timeline without inspecting which native rank is visible
  for index, effect in ipairs(effects) do
    if presentation ~= "preview" or index == previewIndex then
      effect.animation:Play()
    end
  end
  elapsed = 0
  Animate(frame, 0)
  frame:SetScript("OnUpdate", Animate)
end

local function ClampPosition(x, y, scale)
  local halfWidth = math.max(0, (UIParent:GetWidth() / scale - ns.Layouts.Width) / 2)
  local halfHeight = math.max(0, (UIParent:GetHeight() / scale - layout.height) / 2)
  x = math.max(-halfWidth, math.min(halfWidth, x))
  y = math.max(-halfHeight, math.min(halfHeight, y))
  return x, y
end

local function GetFramePosition()
  local x, y = frame:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if x and y and parentX and parentY then
    return x - parentX / frame:GetScale(), y - parentY / frame:GetScale()
  end
end

function Machine.ApplyPosition()
  if not frame then
    return
  end
  -- Convert the saved choice once; renderers receive an explicit mode definition
  local desiredLayout = ns.Config.GetCompactMode() and ns.Layouts.Compact or ns.Layouts.Full
  if layout ~= desiredLayout then
    layout = desiredLayout
    frame:SetSize(ns.Layouts.Width, layout.height)
    -- Only symbol carriers scale; each mode owns stationary covers at the full well size
    for index, reel in ipairs(reels) do
      ns.Art.LayoutWell(reel.well, frame, index, layout)
      reel.carrier:SetScale(layout.reels.symbolScale)
    end
    Machine.StopSpin()
  end
  local scale = ns.Config.GetScale()
  local x, y = ns.Config.GetPosition()
  x, y = ClampPosition(x, y, scale)
  frame:SetScale(scale)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function Machine.NudgePosition(deltaX, deltaY)
  if not frame or not ns.Game.CanConfigure() then
    return false
  end
  -- Native nudges start at the visible position, including after an interrupted drag
  local x, y = GetFramePosition()
  if not x or not y then
    return false
  end
  x, y = ClampPosition(x + deltaX, y + deltaY, ns.Config.GetScale())
  if not ns.Config.SetPosition(x, y) then
    return false
  end
  Machine.ApplyPosition()
  return true
end

function Machine.CapturePosition()
  if not frame or not ns.Game.CanConfigure() then
    return
  end
  local x, y = GetFramePosition()
  if x and y then
    ns.Config.SetPosition(x, y)
  end
  Machine.ApplyPosition()
end

local function SetSampleShown(index, shown)
  for _, mode in ipairs(modes) do
    mode.footer.samples[index]:SetShown(shown and mode.layout == layout)
  end
  for _, target in ipairs(effects[index].targets) do
    target.preview:SetShown(shown)
  end
  for _, reel in ipairs(reels) do
    reel.samples[index]:SetShown(shown)
  end
end

local function RenderPresentation()
  local visible = presentation ~= "hidden"
  local preview = presentation == "preview"
  local activeOnly = presentation == "active"
  local live = presentation == "live" or activeOnly
  -- Native results cover the live empty fallback; previews select one authored state
  local showEmpty = presentation == "live" or (preview and previewIndex > #ns.Game.Results)
  for _, reel in ipairs(reels) do
    reel.idle:SetShown(showEmpty)
  end
  for _, display in ipairs(displays) do
    display:SetEnabled(live)
    display:SetShown(live)
  end
  local showBar = ns.Config.GetDurationBarEnabled()
  for _, mode in ipairs(modes) do
    local current = mode.layout == layout
    mode.cabinet:SetShown(visible and not activeOnly and current)
    mode.nativeCabinet:SetEnabled(activeOnly and current)
    mode.nativeCabinet:SetShown(activeOnly and current)
    for _, cover in ipairs(mode.covers) do
      cover:SetEnabled(live and current)
      cover:SetShown(live and current)
    end
    local footer = mode.footer
    footer.frame:SetShown(visible and current)
    footer.empty:SetShown(showEmpty)
    footer.display:SetEnabled(live and current)
    footer.display:SetShown(live and current)
    footer.duration:SetEnabled(live and current and showBar)
    footer.duration:SetShown(live and current and showBar)
    for _, bar in ipairs(footer.bars) do
      bar:SetShown(showBar)
    end
  end
  for index in ipairs(ns.Game.Results) do
    SetSampleShown(index, preview and index == previewIndex)
  end
  if not visible or not ns.Config.GetAnimationEnabled() then
    Machine.StopSpin()
  end
  frame:SetShown(visible)
end

function Machine.PreviewNext()
  if presentation ~= "preview" or not ns.Game.CanConfigure() then
    return
  end
  -- The extra sample is the dim idle display, with no invented live result
  previewIndex = previewIndex % (#ns.Game.Results + 1) + 1
  RenderPresentation()
  Machine.Spin()
end

function Machine.SetPresentation(mode)
  if not frame then
    return
  end
  assert(mode == "hidden" or mode == "preview" or mode == "live" or mode == "active", "Invalid presentation")
  local previewChanged = (presentation == "preview") ~= (mode == "preview")
  presentation = mode
  if previewChanged then
    Machine.StopSpin()
  end
  RenderPresentation()
end

local function CreateFooter(modeLayout)
  local footer = { samples = {}, bars = {} }
  local owner = CreateFrame("Frame", nil, frame)
  owner:SetSize(ns.Layouts.Width, modeLayout.height)
  owner:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  footer.frame = owner
  footer.empty = ns.Art.EmptyFooter(owner, modeLayout)
  -- Each native layout is authored once before access restrictions are applied
  footer.display = ns.Game.CreateBuffDisplay(owner, function(button)
    ns.Art.NativeFooter(button, modeLayout)
  end)
  footer.duration = ns.Game.CreateBuffDisplay(owner, function(button)
    ns.Art.NativeDurationBar(button, modeLayout)
  end)
  for index, definition in ipairs(ns.Game.Results) do
    local sample = CreateFrame("Frame", nil, owner)
    sample:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
    local _, _, _, bar = ns.Art.Footer(sample, definition, modeLayout)
    footer.bars[index] = bar
    sample:Hide()
    footer.samples[index] = sample
  end
  return footer
end

local function CreateMode(modeLayout)
  local mode = { layout = modeLayout, covers = {} }
  mode.cabinet = CreateFrame("Frame", nil, frame)
  mode.cabinet:SetSize(ns.Layouts.Width, modeLayout.height)
  mode.cabinet:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  ns.Art.Cabinet(mode.cabinet, modeLayout)
  mode.nativeCabinet = ns.Game.CreateBuffDisplay(frame, function(button)
    ns.Art.NativeCabinet(button, modeLayout)
  end)
  mode.footer = CreateFooter(modeLayout)
  return mode
end

local function CreateReelCovers(mode)
  for index, reel in ipairs(reels) do
    local owner = CreateFrame("Frame", nil, reel.well)
    owner:SetSize(ns.Layouts.Columns[index].width, mode.layout.reels.height)
    owner:SetPoint("TOPLEFT", reel.well, "TOPLEFT", 0, 0)
    -- A native opaque cover hides the dim fallback beneath live symbols and win lights
    owner:SetFrameLevel(reel.idle:GetFrameLevel() + 1)
    mode.covers[index] = ns.Game.CreateBuffDisplay(owner, function(button)
      ns.Art.NativeReelCover(button, index, mode.layout)
    end)
  end
end

function Machine.Initialize()
  if frame then
    return
  end
  frame = CreateFrame("Frame", nil, UIParent)
  frame:SetSize(ns.Layouts.Width, ns.Layouts.Full.height)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:SetDontSavePosition(true)
  frame:EnableMouse(false)
  local wells = {}
  for index = 1, REEL_COUNT do
    local well = ns.Art.Well(frame, index)
    wells[index] = well
    local carrier = CreateFrame("Frame", nil, well)
    carrier:SetSize(ns.Layouts.Columns[index].width, ns.Art.ReelHeight)
    local idle = CreateFrame("Frame", nil, carrier)
    idle:SetAllPoints(carrier)
    ns.Art.ReelResult(idle, nil, index)
    displays[#displays + 1] = ns.Game.CreateReelDisplay(carrier, index, ns.Art.ReelResult)
    local rollStart = ROLL_START + index * REEL_STAGGER
    local variant = index == 3 and 2 or 1
    local reel = {
      well = well,
      carrier = carrier,
      idle = idle,
      samples = {},
      rollStart = rollStart,
      variant = variant,
      previewVariant = variant,
      speed = ns.Art.SpinRows * ns.Art.Pitch / (rollStart + ROLL_IN / 3),
    }
    for resultIndex, definition in ipairs(ns.Game.Results) do
      local sample = CreateFrame("Frame", nil, carrier)
      sample:SetPoint("TOPLEFT", carrier, "TOPLEFT", 0, 0)
      ns.Art.ReelResult(sample, definition, index)
      sample:Hide()
      reel.samples[resultIndex] = sample
    end
    reels[index] = reel
    MoveReel(reel, 0)
  end
  modes[1] = CreateMode(ns.Layouts.Full)
  effects = ns.Art.WinEffects(frame, ns.Game.Results, LAST_STOP, wells)
  for index, effect in ipairs(effects) do
    for _, target in ipairs(effect.targets) do
      displays[#displays + 1] = ns.Game.CreateWinDisplay(target.owner, ns.Game.Results[index], target.reelIndex, ns.Art.WinResult)
    end
  end
  modes[2] = CreateMode(ns.Layouts.Compact)
  for _, mode in ipairs(modes) do
    CreateReelCovers(mode)
  end
  frame:SetScript("OnHide", Machine.StopSpin)
  Machine.ApplyPosition()
  frame:Hide()
end

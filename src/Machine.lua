-- Ordinary carriers roll native-selected artwork without reading its result
local _, ns = ...
local Machine = {}
ns.Machine = Machine
local frame, cabinet, emptyFooter, activeCabinet, durationDisplay
local samples, reels, displays = {}, {}, {}
local sampleBars = {}
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
      if target.owner:GetAlpha() ~= 0 then
        target.owner:SetAlpha(0)
      end
    end
  end
end

local function MoveReel(reel, offset)
  -- Never anchor to or query a native container or result child
  local variant = presentation == "preview" and reel.previewVariant or reel.variant
  reel.carrier:SetPoint("TOPLEFT", reel.well, "TOPLEFT", -(variant - 1) * ns.Art.LanePitch, offset)
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

function Machine.ApplyPosition()
  if not frame then
    return
  end
  local scale = ns.Config.GetScale()
  local x, y = ns.Config.GetPosition()
  local halfWidth = math.max(0, (UIParent:GetWidth() / scale - ns.Art.Width) / 2)
  local halfHeight = math.max(0, (UIParent:GetHeight() / scale - ns.Art.Height) / 2)
  x = math.max(-halfWidth, math.min(halfWidth, x))
  y = math.max(-halfHeight, math.min(halfHeight, y))
  frame:SetScale(scale)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function Machine.CapturePosition()
  if not frame or not ns.Game.CanConfigure() then
    return
  end
  local x, y = frame:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if x and y and parentX and parentY then
    ns.Config.SetPosition(x - parentX / frame:GetScale(), y - parentY / frame:GetScale())
  end
  Machine.ApplyPosition()
end

local function SetSampleShown(index, shown)
  samples[index]:SetShown(shown)
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
  local showEmpty = presentation == "live" or (preview and previewIndex > #samples)
  cabinet:SetShown(visible and not activeOnly)
  emptyFooter:SetShown(showEmpty)
  activeCabinet:SetEnabled(activeOnly)
  activeCabinet:SetShown(activeOnly)
  for _, reel in ipairs(reels) do
    reel.idle:SetShown(showEmpty)
    reel.backing:SetShown(showEmpty)
  end
  for _, display in ipairs(displays) do
    display:SetEnabled(live)
    display:SetShown(live)
  end
  local showBar = ns.Config.GetDurationBarEnabled()
  local showLiveBar = live and showBar
  durationDisplay:SetEnabled(showLiveBar)
  durationDisplay:SetShown(showLiveBar)
  for index in ipairs(samples) do
    SetSampleShown(index, preview and index == previewIndex)
    sampleBars[index]:SetShown(showBar)
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
  previewIndex = previewIndex % (#samples + 1) + 1
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

function Machine.Initialize()
  if frame then
    return
  end
  frame = CreateFrame("Frame", nil, UIParent)
  frame:SetSize(ns.Art.Width, ns.Art.Height)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:SetDontSavePosition(true)
  frame:EnableMouse(false)
  cabinet = CreateFrame("Frame", nil, frame)
  cabinet:SetAllPoints(frame)
  ns.Art.Cabinet(cabinet)
  emptyFooter = ns.Art.EmptyFooter(cabinet)
  local wells = {}
  for index = 1, REEL_COUNT do
    local well, backing = ns.Art.Well(frame, index)
    wells[index] = well
    local carrier = CreateFrame("Frame", nil, well)
    carrier:SetSize(well:GetSize())
    carrier:SetPoint("TOPLEFT", well, "TOPLEFT", 0, 0)
    local idle = CreateFrame("Frame", nil, carrier)
    idle:SetAllPoints(carrier)
    ns.Art.ReelResult(idle, nil, index)
    displays[#displays + 1] = ns.Game.CreateReelDisplay(carrier, index, ns.Art.ReelResult)
    local rollStart = ROLL_START + index * REEL_STAGGER
    local variant = index == 3 and 2 or 1
    local reel = {
      well = well,
      backing = backing,
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
  activeCabinet = ns.Game.CreateBuffDisplay(frame, ns.Art.NativeCabinet)
  displays[#displays + 1] = ns.Game.CreateBuffDisplay(frame, ns.Art.NativeFooter)
  effects = ns.Art.WinEffects(frame, ns.Game.Results, LAST_STOP, wells)
  for index, effect in ipairs(effects) do
    for _, target in ipairs(effect.targets) do
      displays[#displays + 1] = ns.Game.CreateWinDisplay(target.owner, ns.Game.Results[index], target.reelIndex, ns.Art.WinResult)
    end
  end
  -- Toggle only the container; never retain or mutate its restricted bar
  durationDisplay = ns.Game.CreateBuffDisplay(frame, ns.Art.NativeDurationBar)
  for index, definition in ipairs(ns.Game.Results) do
    local sample = CreateFrame("Frame", nil, frame)
    sample:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    local _, _, _, bar = ns.Art.Footer(sample, definition)
    sampleBars[index] = bar
    sample:Hide()
    samples[index] = sample
  end
  frame:SetScript("OnHide", Machine.StopSpin)
  Machine.ApplyPosition()
  frame:Hide()
end

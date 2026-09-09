-- Owned Edit Mode dialog; durable preferences remain in Config
local _, ns = ...
local Settings = {}
ns.Settings = Settings

local callbacks, panel, scaleSlider, scaleInput, animation, durationBar, displayMode, visibility, eyeButton
local refreshing, cancelInput = false, false
-- Match Blizzard's Edit Mode rows, section gaps and action-button spacing
local PANEL_WIDTH, PANEL_PADDING, TITLE_TOP = 386, 20, 15
local ROW_HEIGHT, ROW_GAP, SECTION_GAP, BUTTON_HEIGHT = 32, 2, 12, 28
local LABEL_WIDTH, CONTROL_GAP = 100, 5
local MOVEMENT_KEYS = {
  UP = { 0, 1 },
  DOWN = { 0, -1 },
  LEFT = { -1, 0 },
  RIGHT = { 1, 0 },
}
local handledKeys = {}

local function CanEdit()
  return panel and panel:IsShown() and callbacks.canEdit()
end

local function OnKeyDown(self, key)
  if not ns.Game.CanConfigure() then
    self:Hide()
    return
  end
  local direction = MOVEMENT_KEYS[key]
  local handled = false
  if direction and CanEdit() and self:IsVisible() and not GetCurrentKeyBoardFocus() then
    -- Retail 12.1.0.69587 EditModeSystemMixin moves 1 anchor unit, or 10 with Shift
    local step = IsShiftKeyDown() and 10 or 1
    handled = callbacks.nudge(direction[1] * step, direction[2] * step)
  end
  if direction then
    -- A forwarded press still needs its release if a later repeat is consumed
    handledKeys[key] = handled and handledKeys[key] ~= false
  end
  self:SetPropagateKeyboardInput(not handled)
end

local function OnKeyUp(self, key)
  if not ns.Game.CanConfigure() then
    self:Hide()
    return
  end
  -- Match each release to its press, including arrows rejected for missing geometry
  local handled = handledKeys[key]
  handledKeys[key] = nil
  self:SetPropagateKeyboardInput(not handled)
end

local function EyeTooltipText()
  return callbacks.getHighlightsHidden() and "Show highlight" or "Hide highlight"
end

local function HideEyeTooltip()
  if GameTooltip:GetOwner() == eyeButton then
    GameTooltip:Hide()
  end
end

local function RefreshEyeButton()
  local left = callbacks.getHighlightsHidden() and 0.5 or 0
  eyeButton:GetNormalTexture():SetTexCoord(left, left + 0.125, 0, 0.25)
  if GameTooltip:GetOwner() == eyeButton and GameTooltip:IsShown() then
    GameTooltip:SetText(EyeTooltipText())
  end
end

local function RefreshScale()
  refreshing = true
  local scale = ns.Config.GetScale()
  scaleSlider:SetValue(scale)
  scaleInput:SetNumber(math.floor(scale * 100 + 0.5))
  refreshing = false
end

local function CommitScale(value)
  if not CanEdit() or refreshing then
    return
  end
  if ns.Config.SetScale(value) then
    callbacks.changed()
  end
  RefreshScale()
end

local function CommitInput()
  if not CanEdit() then
    return
  end
  local text = scaleInput:GetText()
  if issecretvalue(text) or type(text) ~= "string" then
    RefreshScale()
    return
  end
  local value = tonumber(text)
  if not value or value ~= math.floor(value) then
    RefreshScale()
    return
  end
  CommitScale(value / 100)
end

local function CreateScaleControls(title)
  local scaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  scaleLabel:SetPoint("TOPLEFT", title, "BOTTOM", -(PANEL_WIDTH - 2 * PANEL_PADDING) / 2, -SECTION_GAP)
  scaleLabel:SetSize(LABEL_WIDTH, ROW_HEIGHT)
  scaleLabel:SetJustifyH("LEFT")
  scaleLabel:SetText("Display scale")
  scaleSlider = CreateFrame("Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
  scaleSlider:SetPoint("LEFT", scaleLabel, "RIGHT", CONTROL_GAP, 0)
  scaleSlider:SetSize(155, ROW_HEIGHT)
  local minimum, maximum = ns.Config.GetScaleRange()
  scaleSlider:Init(ns.Config.GetScale(), minimum, maximum, (maximum - minimum) / 0.05, {})
  scaleInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  scaleInput:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
  scaleInput:SetSize(52, 22)
  scaleInput:SetAutoFocus(false)
  scaleInput:SetNumeric(true)
  scaleInput:SetMaxLetters(#tostring(math.floor(maximum * 100)))
  scaleInput:SetJustifyH("CENTER")
  local percent = scaleInput:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  percent:SetPoint("LEFT", scaleInput, "RIGHT", 4, 0)
  percent:SetText("%")
  scaleSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
    if refreshing or issecretvalue(value) or type(value) ~= "number" then
      return
    end
    CommitScale(value)
  end, Settings)
  scaleInput:SetScript("OnEnterPressed", function()
    scaleInput:ClearFocus()
  end)
  scaleInput:SetScript("OnEditFocusLost", function()
    if cancelInput then
      RefreshScale()
    else
      CommitInput()
    end
    EditBox_ClearHighlight(scaleInput)
  end)
  scaleInput:SetScript("OnEscapePressed", function()
    cancelInput = true
    scaleInput:ClearFocus()
    RefreshScale()
    cancelInput = false
  end)
  return scaleLabel
end

local function CreatePanel()
  if panel then
    return
  end
  panel = CreateFrame("Frame", nil, UIParent)
  panel:SetPoint("RIGHT", UIParent, "RIGHT", -80, 0)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel(200)
  panel:SetMovable(true)
  panel:SetClampedToScreen(true)
  panel:SetDontSavePosition(true)
  panel:EnableMouse(true)
  panel:EnableKeyboard(true)
  panel:SetScript("OnKeyDown", OnKeyDown)
  panel:SetScript("OnKeyUp", OnKeyUp)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function()
    if CanEdit() then
      panel:StartMoving()
    end
  end)
  panel:SetScript("OnDragStop", function()
    panel:StopMovingOrSizing()
  end)

  local border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
  border:SetAllPoints(panel)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", panel, "TOP", 0, -TITLE_TOP)
  title:SetText("Roll the Bones Slots")
  local contentHeight = 5 * ROW_HEIGHT + 4 * ROW_GAP + SECTION_GAP + 2 * BUTTON_HEIGHT + ROW_GAP
  panel:SetSize(PANEL_WIDTH, TITLE_TOP + title:GetHeight() + SECTION_GAP + contentHeight + PANEL_PADDING)
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function()
    callbacks.close()
  end)

  eyeButton = CreateFrame("Button", nil, panel)
  eyeButton:SetSize(32, 32)
  eyeButton:SetPoint("RIGHT", close, "LEFT", -4, 0)
  eyeButton:SetNormalTexture("Interface\\LFGFrame\\LFG-Eye")
  eyeButton:SetScript("OnClick", function()
    if CanEdit() then
      callbacks.toggleHighlights()
    end
  end)
  eyeButton:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(EyeTooltipText())
    GameTooltip:Show()
  end)
  eyeButton:SetScript("OnLeave", HideEyeTooltip)

  local scaleLabel = CreateScaleControls(title)

  local visibilityLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  visibilityLabel:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -ROW_GAP)
  visibilityLabel:SetSize(LABEL_WIDTH, ROW_HEIGHT)
  visibilityLabel:SetJustifyH("LEFT")
  visibilityLabel:SetText("Show display")
  visibility = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
  visibility:SetPoint("LEFT", visibilityLabel, "RIGHT", CONTROL_GAP, 0)
  visibility:SetSize(PANEL_WIDTH - 2 * PANEL_PADDING - LABEL_WIDTH - CONTROL_GAP, 25)
  visibility:SetupMenu(function(_, root)
    for _, option in ipairs(ns.Config.GetVisibilityOptions()) do
      root:CreateRadio(option.label, function(value)
        return ns.Config.GetVisibility() == value
      end, function(value)
        if CanEdit() and ns.Config.SetVisibility(value) then
          callbacks.changed()
        end
        Settings.Refresh()
      end, option.value)
    end
  end)

  local modeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  modeLabel:SetPoint("TOPLEFT", visibilityLabel, "BOTTOMLEFT", 0, -ROW_GAP)
  modeLabel:SetSize(LABEL_WIDTH, ROW_HEIGHT)
  modeLabel:SetJustifyH("LEFT")
  modeLabel:SetText("Display mode")
  displayMode = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
  displayMode:SetPoint("LEFT", modeLabel, "RIGHT", CONTROL_GAP, 0)
  displayMode:SetSize(PANEL_WIDTH - 2 * PANEL_PADDING - LABEL_WIDTH - CONTROL_GAP, 25)
  displayMode:SetupMenu(function(_, root)
    for _, option in ipairs(ns.Config.GetDisplayModeOptions()) do
      root:CreateRadio(option.label, function(value)
        return ns.Config.GetCompactMode() == value
      end, function(value)
        if CanEdit() and ns.Config.SetCompactMode(value) then
          callbacks.changed()
        end
        Settings.Refresh()
      end, option.value)
    end
  end)

  animation = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  animation:SetPoint("TOPLEFT", modeLabel, "BOTTOMLEFT", -CONTROL_GAP, -ROW_GAP)
  animation:SetSize(ROW_HEIGHT, ROW_HEIGHT)
  local animationLabel = animation:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  animationLabel:SetPoint("LEFT", animation, "RIGHT", CONTROL_GAP, 0)
  animationLabel:SetText("Animate reels and wins")
  animation:SetScript("OnClick", function()
    if CanEdit() and ns.Config.SetAnimationEnabled(animation:GetChecked()) then
      callbacks.changed()
    end
    Settings.Refresh()
  end)

  durationBar = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  durationBar:SetPoint("TOPLEFT", animation, "BOTTOMLEFT", 0, -ROW_GAP)
  durationBar:SetSize(ROW_HEIGHT, ROW_HEIGHT)
  local durationBarLabel = durationBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  durationBarLabel:SetPoint("LEFT", durationBar, "RIGHT", CONTROL_GAP, 0)
  durationBarLabel:SetText("Show duration bar")
  durationBar:SetScript("OnClick", function()
    if CanEdit() and ns.Config.SetDurationBarEnabled(durationBar:GetChecked()) then
      callbacks.changed()
    end
    Settings.Refresh()
  end)

  local testSpin = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  testSpin:SetPoint("TOPLEFT", durationBar, "BOTTOMLEFT", CONTROL_GAP, -SECTION_GAP)
  testSpin:SetSize(PANEL_WIDTH - 2 * PANEL_PADDING, BUTTON_HEIGHT)
  testSpin:SetText("Test spin")
  testSpin:SetScript("OnClick", function()
    if CanEdit() then
      callbacks.preview()
    end
  end)
  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetPoint("TOPLEFT", testSpin, "BOTTOMLEFT", 0, -ROW_GAP)
  reset:SetSize(PANEL_WIDTH - 2 * PANEL_PADDING, BUTTON_HEIGHT)
  reset:SetText("Reset to Defaults")
  reset:SetScript("OnClick", function()
    if not CanEdit() then
      return
    end
    cancelInput = true
    scaleInput:ClearFocus()
    cancelInput = false
    visibility:CloseMenu()
    displayMode:CloseMenu()
    callbacks.reset()
    Settings.Refresh()
  end)

  panel:SetScript("OnHide", function()
    handledKeys = {}
    visibility:CloseMenu()
    displayMode:CloseMenu()
    HideEyeTooltip()
    cancelInput = true
    scaleInput:ClearFocus()
    cancelInput = false
    panel:StopMovingOrSizing()
  end)
  panel:Hide()
end

function Settings.Initialize(ownerCallbacks)
  callbacks = ownerCallbacks
end

function Settings.Show()
  if not callbacks.canEdit() then
    return
  end
  CreatePanel()
  panel:SetPropagateKeyboardInput(true)
  panel:Show()
  Settings.Refresh()
end

function Settings.Refresh()
  if not panel or not panel:IsShown() then
    return
  end
  if not callbacks.canEdit() then
    Settings.Hide()
    return
  end
  if not scaleInput:HasFocus() then
    RefreshScale()
  end
  animation:SetChecked(ns.Config.GetAnimationEnabled())
  durationBar:SetChecked(ns.Config.GetDurationBarEnabled())
  for _, option in ipairs(ns.Config.GetDisplayModeOptions()) do
    if option.value == ns.Config.GetCompactMode() then
      displayMode:OverrideText(option.label)
    end
  end
  for _, option in ipairs(ns.Config.GetVisibilityOptions()) do
    if option.value == ns.Config.GetVisibility() then
      visibility:OverrideText(option.label)
    end
  end
  RefreshEyeButton()
end

function Settings.Hide()
  if panel then
    panel:Hide()
  end
end

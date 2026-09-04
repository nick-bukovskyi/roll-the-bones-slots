-- Owned Edit Mode dialog; durable preferences remain in Config
local _, ns = ...
local Settings = {}
ns.Settings = Settings

local callbacks, panel, scaleSlider, scaleInput, animation, hint
local refreshing, cancelInput = false, false
local PANEL_WIDTH, PANEL_HEIGHT = 386, 234

local function CanEdit()
    return panel and panel:IsShown() and callbacks.canEdit()
end

local function RefreshScale()
    refreshing = true
    local scale = ns.Config.GetScale()
    scaleSlider:SetValue(scale)
    scaleInput:SetText(string.format("%g", scale * 100))
    refreshing = false
end

local function CommitScale(value)
    if not CanEdit() or refreshing then return end
    if ns.Config.SetScale(value) then
        hint:SetText("Changes saved automatically")
        callbacks.changed()
    else
        local minimum, maximum = ns.Config.GetScaleRange()
        hint:SetText(string.format("Enter a scale from %g%% to %g%%", minimum * 100, maximum * 100))
    end
    RefreshScale()
end

local function CommitInput()
    if not CanEdit() then return end
    local text = scaleInput:GetText()
    if issecretvalue(text) or type(text) ~= "string" then RefreshScale(); return end
    local value = tonumber(text)
    CommitScale(value and value / 100)
end

local function CreatePanel()
    if panel then return end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("RIGHT", UIParent, "RIGHT", -80, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(200)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetDontSavePosition(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function()
        if CanEdit() then panel:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)

    local border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
    border:SetAllPoints(panel)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -16)
    title:SetText("Roll the Bones Slots")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() callbacks.close() end)

    local scaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -57)
    scaleLabel:SetText("Display scale")
    scaleSlider = CreateFrame("Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
    scaleSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 125, -60)
    scaleSlider:SetSize(155, 17)
    local minimum, maximum = ns.Config.GetScaleRange()
    scaleSlider:Init(ns.Config.GetScale(), minimum, maximum, (maximum - minimum) / 0.05, {})
    scaleInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    scaleInput:SetPoint("LEFT", scaleSlider, "RIGHT", 13, 0)
    scaleInput:SetSize(52, 22)
    scaleInput:SetAutoFocus(false)
    scaleInput:SetNumeric(false)
    scaleInput:SetMaxLetters(7)
    scaleInput:SetJustifyH("CENTER")
    local percent = scaleInput:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    percent:SetPoint("LEFT", scaleInput, "RIGHT", 4, 0)
    percent:SetText("%")
    scaleSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if refreshing or issecretvalue(value) or type(value) ~= "number" then return end
        CommitScale(value)
    end, Settings)
    scaleInput:SetScript("OnEnterPressed", function() scaleInput:ClearFocus() end)
    scaleInput:SetScript("OnEditFocusLost", function()
        if cancelInput then RefreshScale() else CommitInput() end
        EditBox_ClearHighlight(scaleInput)
    end)
    scaleInput:SetScript("OnEscapePressed", function()
        cancelInput = true
        scaleInput:ClearFocus()
        RefreshScale()
        cancelInput = false
    end)

    animation = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    animation:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -96)
    animation:SetSize(28, 28)
    local animationLabel = animation:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    animationLabel:SetPoint("LEFT", animation, "RIGHT", 5, 0)
    animationLabel:SetText("Animate reels")
    animation:SetScript("OnClick", function()
        if CanEdit() and ns.Config.SetAnimationEnabled(animation:GetChecked()) then
            callbacks.changed()
        end
        Settings.Refresh()
    end)

    local testSpin = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testSpin:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -139)
    testSpin:SetSize(165, 28)
    testSpin:SetText("Test spin")
    testSpin:SetScript("OnClick", function()
        if CanEdit() then callbacks.preview() end
    end)
    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -139)
    reset:SetSize(165, 28)
    reset:SetText("Reset to Defaults")
    reset:SetScript("OnClick", function()
        if not CanEdit() then return end
        cancelInput = true
        scaleInput:ClearFocus()
        cancelInput = false
        callbacks.reset()
        hint:SetText("Changes saved automatically")
        Settings.Refresh()
    end)
    hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOP", panel, "TOP", 0, -185)
    hint:SetText("Changes saved automatically")
    local guidance = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guidance:SetPoint("TOP", panel, "TOP", 0, -203)
    guidance:SetText("Drag the highlighted display to move it")

    panel:SetScript("OnHide", function()
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
    if not callbacks.canEdit() then return end
    CreatePanel()
    panel:Show()
    Settings.Refresh()
end

function Settings.Refresh()
    if not panel or not panel:IsShown() then return end
    if not callbacks.canEdit() then Settings.Hide(); return end
    if not scaleInput:HasFocus() then RefreshScale() end
    animation:SetChecked(ns.Config.GetAnimationEnabled())
end

function Settings.Hide()
    if panel then panel:Hide() end
end

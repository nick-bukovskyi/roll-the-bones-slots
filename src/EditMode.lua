-- Edit Mode owns selection, dragging and the temporary preview session
local _, ns = ...
local EditMode = {}
ns.EditMode = EditMode

local initialized, available = false, false
local modeActive, selectionsShown, selected, dragging = false, false, false, false
local selection, manager, stateChanged
local observedManagers = setmetatable({}, { __mode = "k" })

local function Notify()
    if stateChanged then stateChanged() end
end

local function CanShowEditor()
    return modeActive and selectionsShown and available
        and not ns.Config.IsReadOnly() and ns.Game.CanConfigure()
end

local function FinishDrag(applySnap)
    if not dragging then return end
    dragging = false
    local frame = ns.Machine.GetFrame()
    frame:StopMovingOrSizing()
    ns.EditModeSnap.Finish(applySnap and CanShowEditor())
    ns.Machine.CapturePosition()
    frame:SetMovable(false)
end

local function Deselect()
    FinishDrag(false)
    selected = false
    ns.Settings.Hide()
    if selection and CanShowEditor() then selection:ShowHighlighted() end
end

local function Select()
    if not CanShowEditor() then return end
    selected = false
    manager:ClearSelectedSystem()
    selected = true
    selection:ShowSelected()
    ns.Settings.Show()
end

local function EnsureSelection()
    if selection then return true end
    if not manager or not EditModeSystemSelectionMixin then return false end
    local frame = ns.Machine.GetFrame()
    selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
    selection:SetAllPoints(frame)
    selection:SetFrameLevel(frame:GetFrameLevel() + 30)
    selection:SetSystem({ GetSystemName = function() return "Roll the Bones Slots" end })
    selection:SetScript("OnMouseDown", Select)
    selection:SetScript("OnDragStart", function()
        if dragging or not CanShowEditor() then return end
        Select()
        frame:SetMovable(true)
        frame:StartMoving()
        dragging = true
        ns.EditModeSnap.Begin(frame, selection)
    end)
    selection:SetScript("OnDragStop", function()
        FinishDrag(true)
        Notify()
    end)
    selection:SetScript("OnHide", function()
        FinishDrag(false)
        selected = false
        ns.Settings.Hide()
    end)
    selection:EnableMouse(false)
    selection:Hide()
    return true
end

function EditMode.CancelInteraction()
    local wasEditing = dragging or selected or (selection and selection:IsShown())
    FinishDrag(false)
    selected = false
    ns.Settings.Hide()
    if wasEditing then ns.Machine.StopSpin() end
    if selection then
        selection:EnableMouse(false)
        selection:Hide()
    end
end

-- Core can call these during a presentation refresh without recursive callbacks
function EditMode.Refresh()
    if not initialized then return end
    if not CanShowEditor() or not EnsureSelection() then
        EditMode.CancelInteraction()
        return
    end
    selection:EnableMouse(true)
    if selected then selection:ShowSelected() else selection:ShowHighlighted() end
    ns.Settings.Refresh()
end

function EditMode.SetAvailable(value)
    available = value == true
    EditMode.Refresh()
end

function EditMode.IsPreviewActive()
    return CanShowEditor() and selection ~= nil and selection:IsShown()
end

function EditMode.IsActive()
    return modeActive
end

function EditMode.TryAttachManager()
    local current = EditModeManagerFrame
    if not current then return false end
    manager = current
    if not observedManagers[current] then
        observedManagers[current] = true
        hooksecurefunc(current, "SelectSystem", function()
            if manager == current and selected then Deselect() end
        end)
        hooksecurefunc(current, "ClearSelectedSystem", function()
            if manager == current and selected then Deselect() end
        end)
        hooksecurefunc(current, "ShowSystemSelections", function()
            if manager ~= current then return end
            modeActive = current:IsEditModeActive()
            selectionsShown = true
            EditMode.Refresh()
            Notify()
        end)
        hooksecurefunc(current, "HideSystemSelections", function()
            if manager ~= current then return end
            selectionsShown = false
            EditMode.Refresh()
            Notify()
        end)
    end
    modeActive = current:IsEditModeActive()
    selectionsShown = modeActive and current:IsShown()
    EditMode.Refresh()
    return true
end

function EditMode.Initialize(onStateChanged)
    if initialized then return end
    stateChanged = onStateChanged
    ns.Settings.Initialize({
        canEdit = EditMode.IsPreviewActive,
        changed = function()
            ns.Machine.ApplyPosition()
            if not ns.Config.GetAnimationEnabled() then ns.Machine.StopSpin() end
            Notify()
        end,
        preview = function()
            if EditMode.IsPreviewActive() then ns.Machine.PreviewNext() end
        end,
        reset = function()
            if not EditMode.IsPreviewActive() then return end
            FinishDrag(false)
            ns.Config.Reset()
            ns.Machine.ApplyPosition()
            ns.Machine.StopSpin()
            Notify()
        end,
        close = Deselect,
    })
    initialized = true
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        EditMode.TryAttachManager()
        modeActive, selectionsShown = true, true
        EditMode.Refresh()
        Notify()
    end, EditMode)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        modeActive, selectionsShown = false, false
        EditMode.Refresh()
        Notify()
    end, EditMode)
    EditMode.TryAttachManager()
end

-- Placement-only adapter for native Retail 12.1.0.69587 Edit Mode magnetism
local _, ns = ...
local Snap = {}
ns.EditModeSnap = Snap

local GEOMETRY_METHODS = {
    "GetScaledSelectionSides",
    "GetScaledSelectionCenter",
    "GetScaledCenter",
    "GetLeftOffset",
    "GetRightOffset",
    "GetTopOffset",
    "GetBottomOffset",
    "GetSelectionOffset",
    "GetCombinedSelectionOffset",
    "GetCombinedCenterOffset",
    "GetSnapOffsets",
}
local PARENT_COORDINATES = {
    "topLevelParentCenterX",
    "topLevelParentCenterY",
    "topLevelParentLeft",
    "topLevelParentRight",
    "topLevelParentBottom",
    "topLevelParentTop",
    "topLevelParentWidth",
    "topLevelParentHeight",
}
local ANCHORS = {
    TOPLEFT = { 0, 1 },
    TOP = { 0.5, 1 },
    TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 },
    CENTER = { 0.5, 0.5 },
    RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 },
    BOTTOM = { 0.5, 0 },
    BOTTOMRIGHT = { 1, 0 },
}
local mover, lines = {}, {}
local previewFrame, active = nil, false
local elapsed = 0

local function IsNumber(value)
    return not issecretvalue(value)
        and type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function IsReadableObject(object)
    if issecretvalue(object) or type(object) ~= "table" or not canaccesstable(object) then
        return false
    end
    local accessible = object:CanBeAccessedInContext()
    return not issecretvalue(accessible) and accessible == true
end

local function HasReadableRect(frame)
    if not IsReadableObject(frame) then
        return false
    end
    local left, bottom, width, height = frame:GetRect()
    local x, y = frame:GetCenter()
    return IsNumber(left)
        and IsNumber(bottom)
        and IsNumber(width)
        and IsNumber(height)
        and width > 0
        and height > 0
        and IsNumber(x)
        and IsNumber(y)
end

local function HasReadableGeometry(frame, selection)
    if not HasReadableRect(frame) or not HasReadableRect(selection) then
        return false
    end
    local scale = frame:GetScale()
    if not IsNumber(scale) or scale <= 0 then
        return false
    end
    for index = 1, 2 do
        local _, _, _, x, y = selection:GetPoint(index)
        if not IsNumber(x) or not IsNumber(y) then
            return false
        end
    end
    return true
end

function mover:GetScale()
    return self.frame:GetScale()
end

function mover:GetCenter()
    return self.frame:GetCenter()
end

function mover:GetFrameMagneticEligibility(candidate)
    if not IsReadableObject(candidate) or candidate == self.frame then
        return false, false
    end
    if
        type(candidate.GetScaledSelectionSides) ~= "function"
        or type(candidate.GetScaledSelectionCenter) ~= "function"
        or type(candidate.GetScaledCenter) ~= "function"
        or type(candidate.GetSelectionOffset) ~= "function"
        or type(candidate.IsToTheLeftOfFrame) ~= "function"
        or type(candidate.IsAboveFrame) ~= "function"
        or not HasReadableGeometry(candidate, candidate.Selection)
    then
        return false, false
    end
    local visible = candidate:IsVisible()
    local selectionVisible = candidate.Selection:IsVisible()
    if
        issecretvalue(visible)
        or issecretvalue(selectionVisible)
        or not visible
        or not selectionVisible
    then
        return false, false
    end
    local left, right, bottom, top = self:GetScaledSelectionSides()
    local otherLeft, otherRight, otherBottom, otherTop = candidate:GetScaledSelectionSides()
    return top >= otherBottom and bottom <= otherTop and (right < otherLeft or left > otherRight),
        right >= otherLeft and left <= otherRight and (bottom > otherTop or top < otherBottom)
end

local function GetSnapInfos()
    if not active or not ns.Game.CanConfigure() then
        return nil
    end
    local manager, magnetism = EditModeManagerFrame, EditModeMagnetismManager
    if
        not manager
        or not magnetism
        or not manager:IsEditModeActive()
        or not manager:IsSnapEnabled()
        or not HasReadableGeometry(mover.frame, mover.Selection)
        or not HasReadableRect(UIParent)
    then
        return nil
    end
    local parentScale = UIParent:GetEffectiveScale()
    if not IsNumber(parentScale) or parentScale <= 0 then
        return nil
    end
    for _, key in ipairs(PARENT_COORDINATES) do
        if not IsNumber(magnetism[key]) then
            return nil
        end
    end
    -- Only Blizzard's registered magnetic systems and its current grid participate
    return magnetism:GetMagneticFrameInfos(mover)
end

local function HideLines()
    for _, line in ipairs(lines) do
        line:Hide()
        line:ClearAllPoints()
    end
end

local function RefreshPreview()
    HideLines()
    local infos = GetSnapInfos()
    if not infos then
        return
    end
    local index = 0
    for _, info in ipairs(infos) do
        for _, anchor in ipairs(EditModeMagnetismManager:GetPreviewLineAnchors(info)) do
            index = index + 1
            if not lines[index] then
                lines[index] =
                    previewFrame:CreateLine(nil, "OVERLAY", "MagnetismPreviewLineTemplate")
            end
            -- The native line resolves endpoints against UIParent, never the target
            lines[index]:Setup(info, anchor)
        end
    end
end

local function ApplyPlacement(infos)
    local frame = mover.frame
    local centerX, centerY = mover:GetScaledCenter()
    local scale = mover:GetScale()
    local width, height = frame:GetSize()
    local parentX, parentY = UIParent:GetCenter()
    for _, info in ipairs(infos) do
        local sourceAnchor, targetAnchor = ANCHORS[info.point], ANCHORS[info.relativePoint]
        local target = info.frame
        local left, bottom, targetWidth, targetHeight = target:GetRect()
        local targetScale = target == UIParent and 1 or target:GetScale()
        local offsetX, offsetY = mover:GetSnapOffsets(info)
        if info.isHorizontal or info.isCornerSnap then
            centerX = (left + targetWidth * targetAnchor[1]) * targetScale
                + offsetX * scale
                - (sourceAnchor[1] - 0.5) * width * scale
        end
        if not info.isHorizontal or info.isCornerSnap then
            centerY = (bottom + targetHeight * targetAnchor[2]) * targetScale
                + offsetY * scale
                - (sourceAnchor[2] - 0.5) * height * scale
        end
    end
    -- Native magnetism uses UIParent coordinates; SetPoint offsets use cabinet scale
    frame:ClearAllPoints()
    frame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        (centerX - parentX) / scale,
        (centerY - parentY) / scale
    )
end

function Snap.Begin(frame, selection)
    Snap.Finish(false)
    if not ns.Game.CanConfigure() then
        return
    end
    mover.frame, mover.Selection = frame, selection
    for _, method in ipairs(GEOMETRY_METHODS) do
        mover[method] = EditModeSystemMixin[method]
    end
    active, elapsed = true, 0
    if not previewFrame then
        previewFrame = CreateFrame("Frame", nil, UIParent)
        previewFrame:SetAllPoints(UIParent)
        previewFrame:SetFrameStrata("HIGH")
        previewFrame:EnableMouse(false)
        previewFrame:SetScript("OnHide", HideLines)
    end
    previewFrame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.05 then
            return
        end
        elapsed = 0
        RefreshPreview()
    end)
    previewFrame:Show()
    RefreshPreview()
end

function Snap.Finish(applySnap)
    if applySnap then
        local infos = GetSnapInfos()
        if infos then
            ApplyPlacement(infos)
        end
    end
    active = false
    HideLines()
    if previewFrame then
        previewFrame:SetScript("OnUpdate", nil)
        previewFrame:Hide()
    end
    mover.frame, mover.Selection = nil, nil
end

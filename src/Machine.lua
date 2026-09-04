-- Ordinary carriers roll native-selected artwork without reading its result
local _, ns = ...
local Machine = {}
ns.Machine = Machine
local frame, previewLabel
local samples, reels, displays = {}, {}, {}
local previewIndex, previewActive = 2, false
local elapsed = 0
local ROLL_IN, SETTLE, LAST_STOP = 0.44, 0.12, 1.50

local function MoveReel(reel, offset)
    -- Never anchor to or query a native container or result child
    local variant = previewActive and reel.previewVariant or reel.variant
    reel.carrier:SetPoint("TOPLEFT", reel.well, "TOPLEFT", -(variant - 1) * ns.Art.LanePitch, offset)
end

function Machine.GetFrame()
    return frame
end

function Machine.StopSpin()
    if not frame then return end
    frame:SetScript("OnUpdate", nil)
    elapsed = 0
    for _, reel in ipairs(reels) do MoveReel(reel, 0) end
end

local function Animate(_, delta)
    elapsed = elapsed + delta
    if elapsed >= LAST_STOP then Machine.StopSpin(); return end
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
    if not frame or not frame:IsVisible() then return end
    -- Cosmetic choices are independent of the active aura and cannot add winning symbols
    local first = math.random(1, #ns.Art.VariantSymbols)
    local second = math.random(1, #ns.Art.VariantSymbols - 1)
    if second >= first then second = second + 1 end
    local field = previewActive and "previewVariant" or "variant"
    reels[2][field], reels[3][field] = first, second
    if not ns.Config.GetAnimationEnabled() then Machine.StopSpin(); return end
    elapsed = 0
    Animate(frame, 0)
    frame:SetScript("OnUpdate", Animate)
end

function Machine.ApplyPosition()
    if not frame then return end
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
    if not frame or not ns.Game.CanConfigure() then return end
    local x, y = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if x and y and parentX and parentY then
        ns.Config.SetPosition(x - parentX / frame:GetScale(), y - parentY / frame:GetScale())
    end
    Machine.ApplyPosition()
end

function Machine.PreviewNext()
    if not previewActive or not ns.Game.CanConfigure() then return end
    -- The extra sample is the dim idle display, with no invented live result
    previewIndex = previewIndex % (#samples + 1) + 1
    for index, sample in ipairs(samples) do
        sample:SetShown(index == previewIndex)
        for _, reel in ipairs(reels) do reel.samples[index]:SetShown(index == previewIndex) end
    end
    Machine.Spin()
end

function Machine.SetPresentation(visible, preview)
    if not frame then return end
    if previewActive ~= preview then
        previewActive = preview
        Machine.StopSpin()
    end
    for _, display in ipairs(displays) do
        display:SetEnabled(visible and not preview)
        display:SetShown(visible and not preview)
    end
    for index, sample in ipairs(samples) do
        local shown = preview and index == previewIndex
        sample:SetShown(shown)
        for _, reel in ipairs(reels) do reel.samples[index]:SetShown(shown) end
    end
    previewLabel:SetShown(preview)
    frame:SetShown(visible)
end

function Machine.Initialize()
    if frame then return end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(ns.Art.Width, ns.Art.Height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetDontSavePosition(true)
    frame:EnableMouse(false)
    ns.Art.Cabinet(frame)
    for index = 1, 3 do
        local well = ns.Art.Well(frame, index)
        local carrier = CreateFrame("Frame", nil, well)
        carrier:SetSize(well:GetSize())
        carrier:SetPoint("TOPLEFT", well, "TOPLEFT", 0, 0)
        ns.Art.ReelResult(carrier, nil, index)
        displays[#displays + 1] = ns.Game.CreateReelDisplay(carrier, index, ns.Art.ReelResult)
        local rollStart = 0.40 + index * 0.18
        local variant = index == 3 and 2 or 1
        local reel = { well = well, carrier = carrier, samples = {}, rollStart = rollStart,
            variant = variant, previewVariant = variant,
            speed = ns.Art.SpinRows * ns.Art.Pitch / (rollStart + ROLL_IN / 3) }
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
    displays[#displays + 1] = ns.Game.CreateFooterDisplay(frame, ns.Art.NativeFooter)
    for index, definition in ipairs(ns.Game.Results) do
        local sample = CreateFrame("Frame", nil, frame)
        sample:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        ns.Art.Footer(sample, definition)
        sample:Hide()
        samples[index] = sample
    end
    previewLabel = ns.Art.Label(frame, "Preview", "GameFontHighlightSmall", 0, ns.Art.Height + 4, ns.Art.Width, 16)
    previewLabel:Hide()
    frame:SetScript("OnHide", Machine.StopSpin)
    Machine.ApplyPosition()
    frame:Hide()
end

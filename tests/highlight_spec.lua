-- Optional provider lifecycle contracts, never control the installed EQOL instance
return function(test, H, loadAddon)
  local eq = H.eq
  local function login()
    local ns = loadAddon()
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.fire("PLAYER_LOGIN")
    return ns
  end
  local function openSettings()
    H.enterEditMode()
    local selection = H.findTemplate("EditModeSystemSelectionTemplate")
    selection.scripts.OnMouseDown(selection)
    for _, button in ipairs(H.frames) do
      if rawget(button, "normalTexture") then
        return button, selection
      end
    end
    error("highlight eye missing")
  end
  local function click(button)
    button.scripts.OnClick(button, "LeftButton")
  end
  local function newEye(hidden)
    local button = CreateFrame("Button", nil, EditModeManagerFrame)
    button.allHidden = hidden
    button:SetScript("OnClick", function(self)
      self.allHidden = not self.allHidden
    end)
    return button
  end
  local function provider(minor, eye)
    local library = { internal = { managerEyeButton = eye }, enter = {}, addCount = 0 }
    function library:RegisterCallback(event, callback, ...)
      eq(select("#", ...), 0)
      eq(event, "enter")
      assert(type(callback) == "function")
      self.enter[#self.enter + 1] = callback
    end
    function library:AddFrame(frame, callback, defaults, ...)
      eq(select("#", ...), 0)
      assert(type(frame) == "table")
      assert(callback == nil or type(callback) == "function")
      assert(defaults == nil or type(defaults) == "table")
      self.addCount = self.addCount + 1
    end
    _G.LibStub = {
      GetLibrary = function(_, name, silent, ...)
        eq(select("#", ...), 0)
        eq(name, "EnhanceQoLEditMode-1.0")
        eq(silent, true)
        return library, minor
      end,
    }
    return library
  end

  test("local eye hides only the highlight and retains settings dragging samples and tooltip ownership", function()
    local ns = login()
    local eye, selection = openSettings()
    selection.scripts.OnDragStart(selection)
    selection.scripts.OnDragStop(selection)
    local frames, hooks = #H.frames, H.hookCount
    eye.scripts.OnEnter(eye)
    eq(GameTooltip:GetText(), "Hide highlight")
    for _ = 1, 3 do
      click(eye)
      eq(selection:GetAlpha(), 0)
      eq(selection:IsShown(), true)
      eq(selection.mouse, true)
      eq(eye.parent:IsShown(), true)
      eq(ns.EditMode.IsPreviewActive(), true)
      eq(eye:GetNormalTexture().texCoords[1], 0.5)
      eq(GameTooltip:GetText(), "Show highlight")
      selection.scripts.OnDragStart(selection)
      eq(ns.Machine.GetFrame().moving, true)
      eq(selection:GetAlpha(), 0)
      selection.scripts.OnDragStop(selection)
      H.button("Test spin").scripts.OnClick()
      eq(ns.Machine.GetFrame():IsVisible(), true)
      click(eye)
      eq(selection:GetAlpha(), 1)
      eq(eye:GetNormalTexture().texCoords[1], 0)
    end
    eye.scripts.OnLeave(eye)
    eq(GameTooltip:IsShown(), false)
    ns.Settings.Refresh()
    eq(GameTooltip:IsShown(), false)
    click(eye)
    local foreign = CreateFrame("Button", nil, UIParent)
    GameTooltip:SetOwner(foreign, "ANCHOR_RIGHT")
    GameTooltip:SetText("Foreign tooltip")
    GameTooltip:Show()
    H.exitEditMode()
    eq(GameTooltip:IsShown(), true)
    eq(GameTooltip:GetOwner(), foreign)
    eye, selection = openSettings()
    eq(selection:GetAlpha(), 1)
    eq(#H.frames, frames + 1)
    eq(H.hookCount, hooks)
  end)

  test("hidden highlights survive native selection suppression and reject restricted local changes", function()
    local ns = login()
    local eye, selection = openSettings()
    click(eye)
    selection.scripts.OnDragStart(selection)
    EditModeManagerFrame:HideSystemSelections()
    eq(selection:IsShown(), false)
    eq(eye.parent:IsShown(), false)
    eq(ns.Machine.GetFrame().moving, false)
    EditModeManagerFrame:ShowSystemSelections()
    eq(selection:IsShown(), true)
    eq(selection:GetAlpha(), 0)
    selection.scripts.OnMouseDown(selection)
    eye.scripts.OnEnter(eye)
    H.combat, H.restricted = true, true
    H.fire("PLAYER_REGEN_DISABLED")
    eq(GameTooltip:IsShown(), false)
    click(eye)
    eq(ns.EditMode.AreHighlightsHidden(), true)
    H.combat, H.restricted = false, false
    H.fire("PLAYER_REGEN_ENABLED")
    eq(selection:GetAlpha(), 0)
    eq(selection.mouse, true)
    H.exitEditMode()
    openSettings()
    eq(selection:GetAlpha(), 1)
  end)

  test("EQOL absent unsupported late and recreated eyes attach once and latest explicit action wins", function()
    local ns = login()
    local eye, selection = openSettings()
    eq(ns.EditMode.AreHighlightsHidden(), false)
    local unsupported = provider(21000000, newEye(true))
    H.fire("ADDON_LOADED", "UnsupportedProvider")
    eq(#unsupported.enter, 0)
    eq(selection:GetAlpha(), 1)
    local library = provider(21000001)
    H.fire("ADDON_LOADED", "SupportedProvider")
    eq(#library.enter, 1)
    library.internal.managerEyeButton = newEye(true)
    library:AddFrame(CreateFrame("Frame", nil, UIParent))
    local globalEye = library.internal.managerEyeButton
    eq(selection:GetAlpha(), 0)
    eq(eye.parent:IsShown(), true)
    eq(ns.EditMode.IsPreviewActive(), true)
    click(eye)
    eq(selection:GetAlpha(), 1)
    eq(globalEye.allHidden, true)
    local hooks = H.hookCount
    for _ = 1, 3 do
      H.fire("PLAYER_ENTERING_WORLD")
      H.fire("ADDON_LOADED", "Unrelated")
      library:AddFrame(UIParent)
      eq(selection:GetAlpha(), 1)
    end
    eq(#library.enter, 1)
    eq(H.hookCount, hooks)
    click(globalEye)
    eq(selection:GetAlpha(), 1)
    click(globalEye)
    eq(selection:GetAlpha(), 0)
    local replacement = newEye(false)
    library.internal.managerEyeButton = replacement
    library:AddFrame(UIParent)
    eq(selection:GetAlpha(), 1)
    click(globalEye)
    click(globalEye)
    eq(selection:GetAlpha(), 1)
    click(replacement)
    eq(selection:GetAlpha(), 0)
    H.exitEditMode()
    openSettings()
    eq(selection:GetAlpha(), 0)
    replacement.allHidden = false
    for _, callback in ipairs(library.enter) do
      callback()
    end
    eq(selection:GetAlpha(), 1)
    eq(ns.EditMode.AreHighlightsHidden(), false)
    eq(library.addCount, 5)
  end)

  test("obsolete providers stop controlling the highlight after supported provider replacement", function()
    login()
    local _, selection = openSettings()
    local old = provider(21000001, newEye(false))
    H.fire("ADDON_LOADED", "FirstProvider")
    local replacement = provider(21000001, newEye(false))
    H.fire("ADDON_LOADED", "ReplacementProvider")
    local hooks = H.hookCount
    click(old.internal.managerEyeButton)
    old:AddFrame(UIParent)
    old.enter[1]()
    eq(selection:GetAlpha(), 1)
    eq(H.hookCount, hooks)
    click(replacement.internal.managerEyeButton)
    eq(selection:GetAlpha(), 0)
    H.fire("ADDON_LOADED", "ReplacementProvider")
    eq(H.hookCount, hooks)
    eq(#replacement.enter, 1)
    local unsupported = provider(21000002, newEye(false))
    H.fire("ADDON_LOADED", "UnsupportedUpgrade")
    click(replacement.internal.managerEyeButton)
    replacement.enter[1]()
    eq(selection:GetAlpha(), 0)
    eq(#unsupported.enter, 0)
  end)
end

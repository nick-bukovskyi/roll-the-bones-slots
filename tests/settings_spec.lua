-- Player settings and authored visibility contracts, not native aura/combat proof
return function(test, H, loadAddon)
  local eq = H.eq
  local function login(saved, combat)
    local ns = loadAddon(saved)
    H.combat = combat == true
    H.playerCombat = combat == true
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
  end
  local function openSettings()
    H.enterEditMode()
    local selection = H.findTemplate("EditModeSystemSelectionTemplate")
    selection.scripts.OnMouseDown(selection)
    return H.findTemplate("WowStyle1DropdownTemplate"), selection
  end
  local function choose(dropdown, value)
    for _, option in ipairs(dropdown.options) do
      if option.value == value then
        option.onSelect(value)
        return
      end
    end
    error("missing visibility choice")
  end
  local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-8, "display center moved")
  end
  local function center(frame)
    local x, y = frame:GetCenter()
    return x * frame:GetEffectiveScale(), y * frame:GetEffectiveScale()
  end
  local function isOrdinaryVisible(widget)
    local ancestor = widget
    while ancestor do
      if ancestor.sealed or not ancestor.shown then
        return false
      end
      ancestor = ancestor.parent
    end
    return true
  end
  local function visibleOrdinaryArtwork(frame)
    local count = 0
    local function visit(widget)
      if (widget.kind == "Texture" or widget.kind == "FontString") and isOrdinaryVisible(widget) then
        count = count + 1
      end
      for _, child in ipairs(widget.children) do
        visit(child)
      end
    end
    visit(frame)
    return count
  end

  test("visibility migration preserves old choices and validates only owned fields", function()
    local ns = loadAddon()
    for _, version in ipairs({ false, 1, 2 }) do
      for _, visibility in ipairs({ false, "always", "active", "combat", "invalid", H.secret }) do
        local saved = {
          schemaVersion = version or nil,
          scale = 1.25,
          x = 80,
          y = -60,
          animationEnabled = false,
          durationBarEnabled = false,
          visibility = visibility,
          extra = "keep",
        }
        ns.Config.Initialize(saved)
        local expected = type(visibility) == "string" and visibility ~= "invalid" and visibility or "always"
        eq(saved.schemaVersion, 3)
        eq(saved.visibility, expected)
        eq(saved.scale, 1.25)
        eq(saved.x, 80)
        eq(saved.y, -60)
        eq(saved.animationEnabled, false)
        eq(saved.durationBarEnabled, false)
        eq(saved.extra, "keep")
        ns.Config.Initialize(saved)
        eq(saved.visibility, expected)
      end
    end
    ns.Config.Initialize(nil)
    for _, invalid in ipairs({ false, true, 3, {}, H.secret, "ACTIVE", "" }) do
      eq(ns.Config.SetVisibility(invalid), false)
      eq(ns.Config.GetVisibility(), "always")
    end
    eq(ns.Config.SetVisibility(nil), false)
    eq(ns.Config.SetVisibility("active"), true)
    ns.Config.Reset()
    eq(ns.Config.GetVisibility(), "always")
    local future = { schemaVersion = 4, visibility = "future choice", extra = "keep" }
    ns.Config.Initialize(future)
    eq(ns.Config.SetVisibility("combat"), false)
    eq(ns.Config.GetVisibility(), "always")
    eq(ns.Config.Reset(), false)
    eq(future.visibility, "future choice")
    eq(future.extra, "keep")
  end)

  test("slider and typed scale preserve a displaced center across repeated resizes and reload", function()
    for _, parentScale in ipairs({ 0.64, 1, 1.2 }) do
      local saved = { schemaVersion = 1, scale = 1.25, x = 160, y = -96 }
      local ns = login(saved)
      UIParent:SetScale(parentScale)
      openSettings()
      local frame, slider = ns.Machine.GetFrame(), H.findTemplate("MinimalSliderWithSteppersTemplate")
      local input = H.findTemplate("InputBoxTemplate")
      local x, y = center(frame)
      for _ = 1, 3 do
        for _, scale in ipairs({ 0.1, 0.6, 1, 1.8, 1.35 }) do
          slider:SetValue(scale)
          local actualX, actualY = center(frame)
          near(actualX, x)
          near(actualY, y)
        end
      end
      input.focused = true
      input:SetText("125")
      input.scripts.OnEnterPressed(input)
      local actualX, actualY = center(frame)
      near(actualX, x)
      near(actualY, y)
      input.focused = true
      input:SetText("181")
      input.scripts.OnEnterPressed(input)
      actualX, actualY = center(frame)
      near(actualX, x)
      near(actualY, y)
      eq(ns.Config.GetScale(), 1.8)
      local savedX, savedY = saved.x, saved.y
      input.focused = true
      input:SetText("70")
      input.scripts.OnEscapePressed(input)
      near(saved.x, savedX)
      near(saved.y, savedY)
      H.exitEditMode()
      ns = login(saved)
      UIParent:SetScale(parentScale)
      actualX, actualY = center(ns.Machine.GetFrame())
      near(actualX, x)
      near(actualY, y)
    end
  end)

  test("percentage input follows numeric limits clamping and cancel semantics without helper text", function()
    local saved = { scale = 1.234, x = 0, y = -180 }
    local ns = login(saved)
    openSettings()
    local input, slider = H.findTemplate("InputBoxTemplate"), H.findTemplate("MinimalSliderWithSteppersTemplate")
    eq(input.numeric, true)
    eq(input.maxLetters, 3)
    eq(ns.Config.GetScale(), 1.234)
    eq(saved.y, -180)
    eq(input:GetText(), "123")
    local x, y = center(ns.Machine.GetFrame())
    for _, entry in ipairs({
      { "0", 0.1, "10" },
      { "9", 0.1, "10" },
      { "10", 0.1, "10" },
      { "59", 0.59, "59" },
      { "181", 1.8, "180" },
      { "999", 1.8, "180" },
      { "127", 1.27, "127" },
    }) do
      input.focused = true
      input:SetText(entry[1])
      input.scripts.OnEnterPressed(input)
      eq(saved.scale, entry[2])
      eq(input:GetText(), entry[3])
      eq(slider.value, entry[2])
      local actualX, actualY = center(ns.Machine.GetFrame())
      near(actualX, x)
      near(actualY, y)
    end
    for _, text in ipairs({ "", "no", "125.5", "60%", "1e999", H.secret }) do
      -- Feed the commit boundary directly; native numeric typing/paste needs client proof
      input.focused = true
      input.text = text
      input:ClearFocus()
      eq(saved.scale, 1.27)
      eq(input:GetText(), "127")
    end
    input.focused = true
    input:SetText("180")
    input.scripts.OnEscapePressed(input)
    eq(saved.scale, 1.27)
    eq(input:GetText(), "127")
    input.focused = true
    input:SetText("135")
    input:ClearFocus()
    eq(saved.scale, 1.35)
    eq(slider.value, 1.35)
    input.focused = true
    input:SetText("70")
    H.button("Reset to Defaults").scripts.OnClick()
    eq(saved.scale, 1)
    eq(saved.x, 0)
    eq(saved.y, 140)
    eq(input:GetText(), "100")
    for _, widget in ipairs(H.widgets) do
      assert(widget.template ~= "GameFontDisableSmall", "scale helper text must not be constructed")
    end
  end)

  test("dragged placement stays centered when resized and edge clamping remains reachable", function()
    local ns = login({ scale = 1.5 })
    local _, selection = openSettings()
    local frame = ns.Machine.GetFrame()
    selection.scripts.OnDragStart(selection)
    frame:SetPoint("CENTER", UIParent, "CENTER", -210, 80)
    selection.scripts.OnDragStop(selection)
    local x, y = center(frame)
    H.findTemplate("MinimalSliderWithSteppersTemplate"):SetValue(0.6)
    local actualX, actualY = center(frame)
    near(actualX, x)
    near(actualY, y)
    ns.Config.SetPosition(1e8, -1e8)
    ns.Machine.ApplyPosition()
    for _, scale in ipairs({ 0.1, 0.6, 1, 1.8 }) do
      H.findTemplate("MinimalSliderWithSteppersTemplate"):SetValue(scale)
      actualX, actualY = center(frame)
      assert(actualX + frame.width * scale / 2 <= UIParent.width + 1e-8)
      assert(actualY - frame.height * scale / 2 >= -1e-8)
    end
  end)

  test("visibility choices persist while preview ignores the live rule and buttons fill separate rows", function()
    local saved = {}
    local ns = login(saved)
    local dropdown = openSettings()
    eq(#dropdown.options, 3)
    for _, option in ipairs(dropdown.options) do
      choose(dropdown, option.value)
      eq(saved.visibility, option.value)
      eq(option.isSelected(option.value), true)
      eq(dropdown:GetText(), option.label)
      eq(ns.EditMode.IsPreviewActive(), true)
      eq(ns.Machine.GetFrame():IsVisible(), true)
      for _, container in ipairs(H.containers()) do
        eq(container.enabled, false)
      end
    end
    local spin, reset = H.button("Test spin"), H.button("Reset to Defaults")
    eq(spin.width, dropdown.parent.width - 40)
    eq(reset.width, spin.width)
    eq(reset.points.TOPLEFT[1], spin)
    eq(reset.points.TOPLEFT[2], "BOTTOMLEFT")
    eq(reset.points.TOPLEFT[3], 0)
    eq(reset.points.TOPLEFT[4], -2)
    eq(spin.height, 28)
    eq(reset.height, 28)
    for _, widget in ipairs(H.widgets) do
      local text = rawget(widget, "text")
      assert(text ~= "Changes saved automatically" and text ~= "Drag the highlighted display to move it")
      assert(text ~= "Preview")
    end
    dropdown.menuOpen = true
    H.exitEditMode()
    eq(dropdown.menuOpen, false)
    eq(ns.Machine.GetFrame():IsVisible(), false)
    ns = login(saved)
    eq(ns.Config.GetVisibility(), "combat")
    eq(ns.Machine.GetFrame():IsVisible(), false)
    dropdown = openSettings()
    eq(dropdown:GetText(), "In combat")
    H.button("Reset to Defaults").scripts.OnClick()
    eq(saved.visibility, "always")
    eq(dropdown:GetText(), "Always")
    H.exitEditMode()
    eq(ns.Machine.GetFrame():IsVisible(), true)
  end)

  test("combat visibility initializes from current state and survives repeated restriction transitions", function()
    for _, initiallyInCombat in ipairs({ false, true }) do
      local ns = login({ visibility = "combat" }, initiallyInCombat)
      local frame = ns.Machine.GetFrame()
      eq(frame:IsVisible(), initiallyInCombat)
      for _ = 1, 3 do
        H.combat, H.playerCombat, H.restricted = true, true, true
        H.fire("PLAYER_REGEN_DISABLED")
        H.fire("ENCOUNTER_START")
        eq(frame:IsVisible(), true)
        H.fire("PLAYER_DEAD")
        eq(frame:IsVisible(), true)
        eq(frame.scripts.OnUpdate, nil)
        H.combat, H.playerCombat = false, false
        H.fire("PLAYER_REGEN_ENABLED")
        eq(frame:IsVisible(), false)
        H.restricted = false
        H.fire("ENCOUNTER_END")
        H.fire("PLAYER_ALIVE")
        eq(frame:IsVisible(), false)
      end
      local dropdown = openSettings()
      dropdown.menuOpen = true
      H.combat, H.playerCombat = true, true
      H.fire("PLAYER_REGEN_DISABLED")
      eq(dropdown.parent:IsShown(), false)
      eq(dropdown.menuOpen, false)
      choose(dropdown, "always")
      eq(ns.Config.GetVisibility(), "combat")
      H.exitEditMode()
      eq(frame:IsVisible(), true)
    end
  end)

  test("combat-only visibility follows player combat independently of lockdown and cast order", function()
    for _, castFirst in ipairs({ false, true }) do
      local ns = login({ visibility = "combat" })
      local frame = ns.Machine.GetFrame()
      local function cast(guid)
        H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, 1214909)
      end
      for attempt = 1, 3 do
        eq(frame:IsVisible(), false)
        if castFirst then
          cast("before" .. attempt)
          eq(frame:IsVisible(), false)
        end
        -- Combat can be observable at event dispatch before lockdown begins
        H.playerCombat = true
        H.fire("PLAYER_REGEN_DISABLED")
        eq(H.combat, false)
        eq(frame:IsVisible(), true)
        H.combat = true
        cast("during" .. attempt)
        eq(frame:IsVisible(), true)
        assert(frame.scripts.OnUpdate)
        H.advance(3.2)
        eq(frame:IsVisible(), true)
        H.fire("PLAYER_LEAVING_WORLD")
        eq(frame:IsVisible(), false)
        H.fire("PLAYER_ENTERING_WORLD", false, false)
        eq(frame:IsVisible(), true)
        H.playerCombat, H.combat = false, false
        H.fire("PLAYER_REGEN_ENABLED")
        eq(frame:IsVisible(), false)
        eq(frame.scripts.OnUpdate, nil)
      end
      H.combat = true
      H.fire("SPELLS_CHANGED")
      eq(frame:IsVisible(), false) -- Lockdown alone does not imply player combat
      eq(#H.timers, 0)
    end
  end)

  test("active-only cabinet never constructs idle text beneath either buff-bar setting", function()
    for _, showBar in ipairs({ false, true }) do
      local ns = login({ visibility = "active", durationBarEnabled = showBar })
      local idle
      for _, widget in ipairs(H.widgets) do
        if
          widget.kind == "FontString"
          and rawget(widget, "text") == "Try yer luck, matey!"
          and widget.parent == H.nativeSlots[14].container.parent
        then
          assert(not idle, "a second idle label would bleed through native buff artwork")
          idle = widget
          local ancestor = widget
          while ancestor do
            eq(ancestor.sealed, false)
            ancestor = ancestor.parent
          end
        end
      end
      assert(idle)
      eq(isOrdinaryVisible(idle), false)
      local dropdown = openSettings()
      choose(dropdown, "always")
      H.exitEditMode()
      eq(isOrdinaryVisible(idle), true)
      dropdown = openSettings()
      choose(dropdown, "active")
      H.exitEditMode()
      eq(isOrdinaryVisible(idle), false)
      eq(visibleOrdinaryArtwork(ns.Machine.GetFrame()), 0)
    end
  end)

  test("buff-only mode leaves all live artwork under native result ownership with no ordinary residue", function()
    local ns = login({ visibility = "active" })
    local frame = ns.Machine.GetFrame()
    eq(visibleOrdinaryArtwork(frame), 0)
    local cabinet = H.nativeSlots[13]
    eq(cabinet.container.enabled, true)
    eq(cabinet.button.mouse, false)
    eq(cabinet.button.width, ns.Layouts.Width)
    eq(cabinet.button.height, ns.Layouts.Full.height)
    eq(cabinet.button.sealed, true)
    eq(next(cabinet.button.scripts), nil)
    for _, result in ipairs(ns.Game.Results) do
      eq(cabinet.filters[result.spellID], true)
    end
    local count = 0
    for _ in pairs(cabinet.filters) do
      count = count + 1
    end
    eq(count, 4)
    assert(cabinet.button.frameLevel <= H.nativeSlots[14].button.frameLevel)
    for _, event in ipairs({
      "UNIT_AURA",
      "SPELLS_CHANGED",
      "TRAIT_CONFIG_UPDATED",
      "PLAYER_ENTERING_WORLD",
    }) do
      if event == "UNIT_AURA" then
        H.fire(event, H.secret, H.secret)
      else
        H.fire(event)
      end
      eq(visibleOrdinaryArtwork(frame), 0)
    end
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "active-spin", 1214909)
    for _ = 1, 12 do
      H.advance(0.2)
      eq(visibleOrdinaryArtwork(frame), 0)
    end
    eq(frame.scripts.OnUpdate, nil)
    local dropdown = openSettings()
    assert(visibleOrdinaryArtwork(frame) > 0)
    eq(cabinet.container.enabled, false)
    choose(dropdown, "always")
    H.exitEditMode()
    assert(visibleOrdinaryArtwork(frame) > 0)
    eq(cabinet.container.enabled, false)
    dropdown = openSettings()
    choose(dropdown, "active")
    H.exitEditMode()
    eq(visibleOrdinaryArtwork(frame), 0)
    eq(cabinet.container.enabled, true)
  end)

  test("all visibility modes recover from eligibility and overlay changes without new frames or hooks", function()
    for _, mode in ipairs({ "always", "active", "combat" }) do
      local ns = login({ visibility = mode })
      openSettings()
      H.exitEditMode()
      local frame, frames, hooks, slots = ns.Machine.GetFrame(), #H.frames, H.hookCount, H.auraSlotCount
      H.combat, H.playerCombat = mode == "combat", mode == "combat"
      H.fire("PLAYER_REGEN_DISABLED")
      for _ = 1, 8 do
        H.spec = 259
        H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        eq(frame:IsVisible(), false)
        H.spec = 260
        H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        eq(frame:IsVisible(), true)
        H.known = false
        H.fire("SPELLS_CHANGED")
        eq(frame:IsVisible(), false)
        H.known = true
        H.fire("TRAIT_CONFIG_UPDATED")
        eq(frame:IsVisible(), true)
        H.cinematic = true
        H.fire("CINEMATIC_START")
        eq(frame:IsVisible(), false)
        H.cinematic = false
        H.fire("CINEMATIC_STOP")
        eq(frame:IsVisible(), true)
        H.fire("PLAY_MOVIE")
        eq(frame:IsVisible(), false)
        H.fire("STOP_MOVIE")
        eq(frame:IsVisible(), true)
        H.petBattle = true
        H.fire("PET_BATTLE_OPENING_START")
        eq(frame:IsVisible(), false)
        H.petBattle = false
        H.fire("PET_BATTLE_CLOSE")
        eq(frame:IsVisible(), true)
        UIParent:Hide()
        eq(frame:IsVisible(), false)
        UIParent:Show()
        eq(frame:IsVisible(), true)
        H.fire("PLAYER_LEAVING_WORLD")
        eq(frame:IsVisible(), false)
        H.fire("PLAYER_ENTERING_WORLD", false, false)
        eq(frame:IsVisible(), true)
      end
      eq(#H.frames, frames)
      eq(H.hookCount, hooks)
      eq(H.auraSlotCount, slots)
      eq(#H.timers, 0)
      if mode == "active" then
        eq(visibleOrdinaryArtwork(frame), 0)
      end
    end
  end)
end

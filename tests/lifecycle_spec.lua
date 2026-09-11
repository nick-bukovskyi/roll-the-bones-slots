return function(test, H, loadAddon)
  local eq = H.eq
  local function login(saved)
    local ns = loadAddon(saved)
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.loggedIn = true
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
  end
  local function selectCabinet()
    H.enterEditMode()
    local selection = assert(H.findTemplate("EditModeSystemSelectionTemplate"))
    selection.scripts.OnMouseDown(selection)
    return selection
  end
  local function samples()
    local found = {}
    for _, frame in ipairs(H.frames) do
      if frame.kind == "Frame" and frame.parent == H.nativeSlots[14].container.parent then
        for _, foreground in ipairs(frame.children) do
          for _, child in ipairs(foreground.children) do
            if child.kind == "FontString" and rawget(child, "text") == "26 s" then
              found[#found + 1] = frame
            end
          end
        end
      end
    end
    eq(#found, 4)
    return found
  end
  local function visibleSamples()
    local count = 0
    for _, sample in ipairs(samples()) do
      if sample:IsVisible() then
        count = count + 1
      end
    end
    return count
  end
  local function spin(guid)
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, 1214909)
  end
  local function nativeEnabled(expected)
    local containers = H.containers()
    eq(#containers, 24)
    for _, container in ipairs(containers) do
      local compactFooter = container.parent == H.nativeSlots[26].container.parent
      eq(
        container.enabled,
        expected
          and not compactFooter
          and H.nativeCabinetFile(container) ~= "cabinet-compact.tga"
          and container ~= H.nativeSlots[13].container
      )
    end
  end
  local function carriers()
    local found = {}
    for _, container in ipairs(H.containers()) do
      local carrier = container.parent
      if container.slots.result1 then
        local viewport = carrier.parent
        if rawget(viewport, "clipsChildren") then
          found[#found + 1] = carrier
        end
      end
    end
    eq(#found, 3)
    return found
  end
  local function assertSettled()
    local moving = carriers()
    for index, carrier in ipairs(moving) do
      local point = carrier.points.CENTER
      eq(point[1], carrier.parent)
      eq(point[2], "CENTER")
      eq(point[4], 0)
      if index == 1 then
        eq(point[3], 0)
      else
        assert(point[3] == 0 or point[3] == -128 or point[3] == -256 or point[3] == -384 or point[3] == -512)
      end
      for _, sibling in ipairs(carrier.parent.children) do
        if sibling.kind == "Frame" and sibling.points.CENTER then
          eq(sibling.points.CENTER[1], carrier.parent) -- Lights stay fixed while the carrier moves
          eq(sibling.points.CENTER[4], 0)
        elseif sibling.kind == "Frame" and sibling ~= carrier then
          eq(sibling.points.TOPLEFT[1], carrier.parent) -- Stationary mode covers fill the clipping boundary
          eq(sibling.points.TOPLEFT[3], 0)
          eq(sibling.points.TOPLEFT[4], 0)
        end
      end
    end
    assert(moving[2].points.CENTER[3] ~= moving[3].points.CENTER[3])
    eq(H.cabinet().scripts.OnUpdate, nil)
  end

  test("TOC bootstrap waits for saved data and creates widgets and hooks once", function()
    local saved = { scale = 1.2 }
    local ns = loadAddon(saved)
    H.fire("ADDON_LOADED", "Unrelated")
    eq(saved.schemaVersion, nil)
    eq(#H.frames, 1)
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    eq(saved.schemaVersion, nil)
    eq(#H.frames, 1)
    H.fire("PLAYER_LOGIN")
    eq(saved.schemaVersion, 3)
    local count, hooks = #H.frames, H.hookCount
    H.fire("PLAYER_LOGIN")
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    ns.Machine.Initialize()
    ns.EditMode.Initialize(function()
      error("duplicate owner installed")
    end)
    ns.EditMode.TryAttachManager()
    eq(#H.frames, count)
    eq(H.hookCount, hooks)
    eq(hooks, 4)
    eq(H.auraSlotCount, 33)
    eq(ns.Machine.GetFrame(), H.cabinet())
    eq(H.cabinet():IsVisible(), true)
    eq(next(SlashCmdList), nil)
    eq(SLASH_ROLLTHEBONESSLOTS1, nil)
  end)

  test("unsupported build or flavor preserves saved data and creates no native display", function()
    for _, mismatch in ipairs({ "build", "version", "flavor" }) do
      local saved = { scale = 1.4 }
      loadAddon(saved)
      if mismatch == "build" then
        H.build = "99999"
      elseif mismatch == "version" then
        H.version = "12.1.1"
      else
        WOW_PROJECT_ID = 2
      end
      H.fire("ADDON_LOADED", "RollTheBonesSlots")
      H.fire("PLAYER_LOGIN")
      eq(saved.schemaVersion, nil)
      eq(saved.scale, 1.4)
      eq(H.auraSlotCount, 0)
      eq(#H.frames, 1)
      eq(next(SlashCmdList), nil)
      eq(next(H.callbacks), nil)
    end
  end)

  test("late addon and late Edit Mode loading attach without duplicating the display", function()
    local ns = loadAddon()
    H.loggedIn = true
    EditModeManagerFrame = nil
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    eq(H.auraSlotCount, 33)
    eq(H.hookCount, 0)
    H.fire("ADDON_LOADED", "Unrelated")
    eq(H.hookCount, 0)
    H.newManager()
    H.fire("ADDON_LOADED", "Blizzard_EditMode")
    eq(H.hookCount, 4)
    H.fire("ADDON_LOADED", "Blizzard_EditMode")
    eq(H.hookCount, 4)
    H.enterEditMode()
    eq(ns.EditMode.IsPreviewActive(), true)
    H.exitEditMode()
    nativeEnabled(true)
  end)

  test("native reels and footer use only the four exact results and no Lua aura event reads", function()
    login()
    nativeEnabled(true)
    for _, container in ipairs(H.containers()) do
      eq(container.unit, "player")
      local count = 0
      for id in pairs(container.filters) do
        assert(id == 1214933 or id == 1214934 or id == 1214935 or id == 1214937)
        count = count + 1
      end
      eq(count, rawget(container.slots, "win") and 1 or 4)
      eq(container.filters[1214936], nil)
    end
    for _, frame in ipairs(H.frames) do
      eq(frame.events.UNIT_AURA, nil)
    end
    H.fire("UNIT_AURA", H.secret, H.secret)
    H.combat, H.restricted = true, true
    H.fire("PLAYER_REGEN_DISABLED")
    nativeEnabled(true)
    eq(H.cabinet():IsVisible(), true)
    H.combat, H.restricted = false, false
    H.fire("PLAYER_REGEN_ENABLED")
    nativeEnabled(true)
    eq(visibleSamples(), 0)
  end)

  test("readable successful casts spin once and all three reels stop without idle updates", function()
    login()
    local cabinet = H.cabinet()
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "other", 1214909)
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "other", 315508)
    H.fire("UNIT_SPELLCAST_SUCCEEDED", H.secret, H.secret, H.secret)
    eq(cabinet.scripts.OnUpdate, nil)
    spin("cast1")
    assert(cabinet.scripts.OnUpdate)
    H.advance(0.7)
    spin("cast1")
    H.advance(0.81)
    eq(cabinet.scripts.OnUpdate, nil)
    spin("cast2")
    H.advance(1.2)
    assert(cabinet.scripts.OnUpdate)
    H.advance(0.31)
    eq(cabinet.scripts.OnUpdate, nil)
    H.advance(100)
    eq(cabinet.scripts.OnUpdate, nil)
    -- An opaque GUID is not inspected; readable unit/spell still permits cosmetic motion
    spin(H.secret)
    assert(cabinet.scripts.OnUpdate)
    H.advance(2)
    eq(cabinet.scripts.OnUpdate, nil)
  end)

  test("continuous ordinary carriers move the same prebuilt artwork without inner clipping or texture updates", function()
    local ns = login()
    local moving = carriers()
    local alphaCount = #H.alphaWrites
    local textureWrites, pointCount, widgetCount = H.textureWrites, #H.pointWrites, #H.widgets
    assertSettled()
    spin("landing")
    for _, carrier in ipairs(moving) do
      eq(carrier.kind, "Frame")
      eq(carrier.parent.kind, "Frame")
      eq(carrier.parent.clipsChildren, true)
      eq(rawget(carrier, "clipsChildren") or false, false)
      eq(carrier.width, carrier.parent.width)
      eq(carrier.height, carrier.parent.height)
      eq(carrier.points.CENTER[4], ns.Art.SpinRows * ns.Art.Pitch)
      eq(carrier:IsShown(), true)
    end
    H.advance(0.9)
    local first, second, third = moving[1].points.CENTER[4], moving[2].points.CENTER[4], moving[3].points.CENTER[4]
    assert(first > 0 and first < second and second < third)
    H.advance(0.2)
    assert(moving[1].points.CENTER[4] < 0)
    H.advance(0.07)
    eq(moving[1].points.CENTER[4], 0)
    H.advance(0.16)
    eq(moving[2].points.CENTER[4], 0)
    assert(moving[3].points.CENTER[4] > 0)
    H.advance(0.2)
    assertSettled()
    nativeEnabled(true)
    eq(#H.alphaWrites, alphaCount)
    eq(H.textureWrites, textureWrites)
    eq(#H.widgets, widgetCount)
    for index = pointCount + 1, #H.pointWrites do
      local widget = H.pointWrites[index]
      assert(widget == moving[1] or widget == moving[2] or widget == moving[3], "animation moved something other than an ordinary carrier")
    end
    for _, carrier in ipairs(moving) do
      eq(carrier:IsShown(), true)
    end
  end)

  test("repeat rolls and interruptions reset every carrier without touching native descendants", function()
    local ns = login()
    spin("first")
    H.advance(0.95)
    spin("second")
    for _, carrier in ipairs(carriers()) do
      eq(carrier.points.CENTER[4], ns.Art.SpinRows * ns.Art.Pitch)
    end
    H.advance(0.9)
    ns.Machine.StopSpin()
    assertSettled()
    spin("hide")
    H.advance(0.9)
    UIParent:Hide()
    assertSettled()
    UIParent:Show()
    spin("death")
    H.advance(0.9)
    H.fire("PLAYER_DEAD")
    assertSettled()
    selectCabinet()
    H.button("Test spin").scripts.OnClick()
    H.advance(0.9)
    local animation = H.checkbox("Animate reels and wins")
    animation:SetChecked(false)
    animation.scripts.OnClick(animation)
    assertSettled()
    H.exitEditMode()
    spin("reduced-motion")
    assertSettled()
    eq(H.auraSlotCount, 33)
  end)

  test("Edit Mode owns the only preview and samples never coexist with native results", function()
    local ns = login()
    local cabinet = H.cabinet()
    eq(visibleSamples(), 0)
    nativeEnabled(true)
    local selection = selectCabinet()
    eq(ns.EditMode.IsPreviewActive(), true)
    eq(selection.mouse, true)
    eq(selection.selectionStyle, "selected")
    eq(visibleSamples(), 1)
    nativeEnabled(false)
    spin("during-editor")
    eq(cabinet.scripts.OnUpdate, nil)
    local testSpin = H.button("Test spin")
    for _, count in ipairs({ 1, 1, 0, 1, 1 }) do
      testSpin.scripts.OnClick(testSpin)
      eq(visibleSamples(), count)
      assert(cabinet.scripts.OnUpdate)
      H.advance(2)
      eq(cabinet.scripts.OnUpdate, nil)
    end
    H.exitEditMode()
    eq(ns.EditMode.IsPreviewActive(), false)
    eq(selection.mouse, false)
    eq(selection:IsShown(), false)
    eq(visibleSamples(), 0)
    nativeEnabled(true)
    eq(H.findTemplate("MinimalSliderWithSteppersTemplate").parent:IsShown(), false)
  end)

  test("hidden Edit Mode selections suppress Blizzard sample data until editing ends", function()
    local ns = login()
    selectCabinet()
    EditModeManagerFrame:HideSystemSelections()
    eq(ns.EditMode.IsPreviewActive(), false)
    eq(H.cabinet():IsVisible(), false)
    nativeEnabled(false)
    eq(visibleSamples(), 0)
    EditModeManagerFrame:ShowSystemSelections()
    eq(ns.EditMode.IsPreviewActive(), true)
    eq(H.cabinet():IsVisible(), true)
    eq(visibleSamples(), 1)
    nativeEnabled(false)
    H.exitEditMode()
    nativeEnabled(true)
  end)

  test("combat and encounter restrictions cancel dragging and prevent editor mutation", function()
    for _, event in ipairs({
      "PLAYER_REGEN_DISABLED",
      "ENCOUNTER_START",
      "CHALLENGE_MODE_START",
      "PVP_MATCH_STATE_CHANGED",
    }) do
      local ns = login()
      local selection = selectCabinet()
      local cabinet = H.cabinet()
      selection.scripts.OnDragStart(selection)
      eq(cabinet.moving, true)
      H.restricted = true
      H.combat = event == "PLAYER_REGEN_DISABLED"
      H.fire(event)
      eq(cabinet.moving, false)
      eq(selection.mouse, false)
      eq(selection:IsShown(), false)
      eq(cabinet.scripts.OnUpdate, nil)
      eq(ns.EditMode.IsPreviewActive(), false)
      nativeEnabled(false)
      eq(cabinet:IsVisible(), false)
      local slider = H.findTemplate("MinimalSliderWithSteppersTemplate")
      slider:SetValue(1.5)
      eq(ns.Config.GetScale(), 1)
      H.combat, H.restricted = false, false
      H.fire("PLAYER_REGEN_ENABLED")
      eq(ns.EditMode.IsPreviewActive(), true)
      eq(visibleSamples(), 1)
      H.exitEditMode()
      nativeEnabled(true)
    end
  end)

  test("animation preference stops preview spins and reset restores live motion", function()
    local ns = login()
    selectCabinet()
    H.button("Test spin").scripts.OnClick()
    assert(H.cabinet().scripts.OnUpdate)
    local animation = H.checkbox("Animate reels and wins")
    animation:SetChecked(false)
    animation.scripts.OnClick(animation)
    eq(ns.Config.GetAnimationEnabled(), false)
    eq(H.cabinet().scripts.OnUpdate, nil)
    H.button("Test spin").scripts.OnClick()
    eq(H.cabinet().scripts.OnUpdate, nil)
    H.button("Reset to Defaults").scripts.OnClick()
    eq(ns.Config.GetAnimationEnabled(), true)
    H.exitEditMode()
    spin("restored-motion")
    assert(H.cabinet().scripts.OnUpdate)
  end)

  test("ordinary editor dragging round-trips scaled position and rejects unreachable saved placement", function()
    local ns = login({ scale = 1.5, x = 1e8, y = -1e8 })
    local cabinet = H.cabinet()
    local point = cabinet.points.CENTER
    assert(math.abs(point[3]) < 1000 and math.abs(point[4]) < 1000)
    ns.Config.SetPosition(100.5, -50.25)
    ns.Machine.ApplyPosition()
    local selection = selectCabinet()
    selection.scripts.OnDragStart(selection)
    eq(cabinet.moving, true)
    selection.scripts.OnDragStop(selection)
    eq(cabinet.moving, false)
    local x, y = ns.Config.GetPosition()
    eq(x, 100.5)
    eq(y, -50.25)
    H.exitEditMode()
    eq(cabinet.mouse, false)
  end)

  test("repeated Edit Mode sessions reuse controls and cancel uncommitted input on deselection", function()
    local ns = login()
    selectCabinet()
    local input = H.findTemplate("InputBoxTemplate")
    local count, hooks = #H.frames, H.hookCount
    for _ = 1, 4 do
      input.focused = true
      input:SetText("175")
      EditModeManagerFrame:SelectSystem({})
      eq(input.focused, false)
      eq(ns.Config.GetScale(), 1)
      eq(input.parent:IsShown(), false)
      H.exitEditMode()
      selectCabinet()
      eq(#H.frames, count)
      eq(H.hookCount, hooks)
      eq(H.auraSlotCount, 33)
    end
    H.exitEditMode()
  end)

  test("death ends cosmetic motion and restricted display-size changes apply after restrictions lift", function()
    local ns = login({ scale = 1.5, x = 400, y = 0 })
    spin("before-death")
    H.fire("PLAYER_DEAD")
    eq(H.cabinet().scripts.OnUpdate, nil)
    H.fire("PLAYER_ALIVE")
    eq(H.cabinet():IsVisible(), true)
    H.combat, H.restricted = true, true
    H.fire("PLAYER_REGEN_DISABLED")
    local original = H.cabinet().points.CENTER[3]
    UIParent.width = 800
    H.fire("DISPLAY_SIZE_CHANGED")
    H.fire("UI_SCALE_CHANGED")
    eq(H.cabinet().points.CENTER[3], original)
    H.combat, H.restricted = false, false
    H.fire("PLAYER_REGEN_ENABLED")
    assert(H.cabinet().points.CENTER[3] < original)
    local x, y = ns.Config.GetPosition()
    eq(x, 400)
    eq(y, 0)
    eq(#H.timers, 0)
  end)

  test("spec, missing spell, overlays and loading clear work and recover without rebuilding", function()
    login()
    local cabinet = H.cabinet()
    local count = #H.frames
    spin("before-spec")
    H.spec = 259
    H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    eq(cabinet:IsVisible(), false)
    eq(cabinet.scripts.OnUpdate, nil)
    H.spec = 260
    H.fire("SPELLS_CHANGED")
    eq(cabinet:IsVisible(), true)
    H.known = false
    H.fire("TRAIT_CONFIG_UPDATED")
    eq(cabinet:IsVisible(), false)
    H.known = true
    H.fire("SPELLS_CHANGED")
    eq(cabinet:IsVisible(), true)
    H.petBattle = true
    H.fire("PET_BATTLE_OPENING_START")
    eq(cabinet:IsVisible(), false)
    H.petBattle = false
    H.fire("PET_BATTLE_CLOSE")
    eq(cabinet:IsVisible(), true)
    H.cinematic = true
    H.fire("CINEMATIC_START")
    eq(cabinet:IsVisible(), false)
    H.cinematic = false
    H.fire("CINEMATIC_STOP")
    eq(cabinet:IsVisible(), true)
    H.fire("PLAY_MOVIE", 1)
    eq(cabinet:IsVisible(), false)
    H.fire("STOP_MOVIE")
    eq(cabinet:IsVisible(), true)
    spin("before-loading")
    H.fire("PLAYER_LEAVING_WORLD")
    eq(cabinet:IsVisible(), false)
    H.fire("SPELLS_CHANGED")
    eq(cabinet:IsVisible(), false)
    H.fire("PLAYER_ENTERING_WORLD", false, false)
    eq(cabinet:IsVisible(), true)
    eq(cabinet.scripts.OnUpdate, nil)
    eq(#H.frames, count)
    spin("before-hidden")
    UIParent:Hide()
    eq(cabinet.scripts.OnUpdate, nil)
    spin("hidden")
    eq(cabinet.scripts.OnUpdate, nil)
    UIParent:Show()
    eq(cabinet:IsVisible(), true)
  end)

  test("future saved schema remains read-only including during Edit Mode", function()
    local saved = { schemaVersion = 4, scale = 1.7, x = "future", extra = "preserved" }
    local ns = login(saved)
    H.enterEditMode()
    eq(ns.Config.IsReadOnly(), true)
    eq(ns.EditMode.IsPreviewActive(), false)
    nativeEnabled(false)
    eq(H.cabinet():IsVisible(), false)
    eq(H.findTemplate("InputBoxTemplate"), nil)
    H.exitEditMode()
    nativeEnabled(true)
    eq(saved.schemaVersion, 4)
    eq(saved.scale, 1.7)
    eq(saved.x, "future")
    eq(saved.extra, "preserved")
  end)
end

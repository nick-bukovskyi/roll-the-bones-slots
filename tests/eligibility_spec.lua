-- Eligibility and lifecycle contracts; native combat, taint and rendering need the client
return function(test, H, loadAddon)
  local eq = H.eq
  local function login(configure, saved, late)
    local ns = loadAddon(saved)
    if configure then
      configure()
    end
    H.loggedIn = late == true
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.loggedIn = true
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
  end
  local function noSetup(ns, saved)
    eq(ns.Machine.GetFrame(), nil)
    eq(_G.RollTheBonesSlotsDB, saved)
    eq(#H.frames, 1)
    eq(H.auraSlotCount, 0)
    eq(H.hookCount, 0)
    eq(next(H.callbacks), nil)
    eq(#H.messages, 0)
    eq(#H.timers, 0)
    eq(H.frames[1].events.UNIT_SPELLCAST_SUCCEEDED, nil)
    eq(H.frames[1].events.PLAYER_REGEN_DISABLED, nil)
    eq(H.frames[1].events.ENCOUNTER_START, nil)
  end
  local function inactive(ns)
    eq(ns.Machine.GetFrame():IsVisible(), false)
    eq(ns.Machine.GetFrame().scripts.OnUpdate, nil)
    eq(ns.EditMode.IsPreviewActive(), false)
    for _, container in ipairs(H.containers()) do
      eq(container.enabled, false)
      eq(container:IsShown(), false)
    end
    for _, group in ipairs(H.animationGroups) do
      eq(group.playing, false)
    end
    eq(H.frames[1].events.UNIT_SPELLCAST_SUCCEEDED, nil)
    eq(H.frames[1].events.DISPLAY_SIZE_CHANGED, nil)
    eq(H.frames[1].events.ENCOUNTER_START, nil)
  end
  local unavailable = {
    { field = "classToken" },
    { field = "classToken", value = H.secret },
    { field = "specIndex" },
    { field = "specIndex", value = 0 },
    { field = "specIndex", value = H.secret },
    { field = "spec" },
    { field = "spec", value = 0 },
    { field = "spec", value = H.secret },
    { field = "known" },
    { field = "known", value = false },
    { field = "known", value = H.secret },
  }

  test("other classes never initialize settings, widgets, hooks or runtime events", function()
    for _, classToken in ipairs({
      "DEATHKNIGHT",
      "DEMONHUNTER",
      "DRUID",
      "EVOKER",
      "HUNTER",
      "MAGE",
      "MONK",
      "PALADIN",
      "PRIEST",
      "SHAMAN",
      "WARLOCK",
      "WARRIOR",
    }) do
      for _, late in ipairs({ false, true }) do
        local saved = { scale = 1.4, x = 31, y = -22 }
        local ns = login(function()
          H.classToken = classToken
          C_SpecializationInfo.GetSpecialization = function()
            error("non-Rogue queried specialization")
          end
        end, saved, late)
        EditModeManagerFrame.active = true
        EditModeManagerFrame:ShowSystemSelections()
        H.fire("ADDON_LOADED", "Blizzard_EditMode")
        H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        H.fire("SPELLS_CHANGED")
        noSetup(ns, saved)
        eq(next(H.frames[1].events), nil)
        eq(saved.schemaVersion, nil)
        eq(saved.scale, 1.4)
        eq(saved.x, 31)
      end
    end
  end)

  test("other Rogue specs defer setup and activate Outlaw without reload", function()
    for _, spec in ipairs({ 259, 261, 0 }) do
      local saved = { scale = 1.2, x = 19, y = -35, animationEnabled = false }
      local ns = login(function()
        H.spec = spec
      end, saved)
      noSetup(ns, saved)
      eq(saved.schemaVersion, nil)
      H.spec = 260
      H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
      eq(ns.Machine.GetFrame():IsVisible(), true)
      eq(ns.Config.GetScale(), 1.2)
      eq(ns.Config.GetAnimationEnabled(), false)
      local x, y = ns.Config.GetPosition()
      eq(x, 19)
      eq(y, -35)
      eq(saved.schemaVersion, 2)
      eq(H.auraSlotCount, 24)
    end
  end)

  test("missing or unreadable eligibility delays setup and recovers on player data events", function()
    for _, case in ipairs(unavailable) do
      local original
      local ns = login(function()
        original = H[case.field]
        H[case.field] = case.value
      end)
      noSetup(ns)
      H[case.field] = original
      H.fire("SPELLS_CHANGED")
      eq(ns.Machine.GetFrame():IsVisible(), true)
      eq(H.auraSlotCount, 24)
    end
  end)

  test("non-player specialization events cannot activate or interrupt the display", function()
    local ns = login(function()
      H.spec = 259
    end)
    H.spec = 260
    H.fire("PLAYER_SPECIALIZATION_CHANGED", "party1")
    H.fire("PLAYER_SPECIALIZATION_CHANGED", H.secret)
    H.fire("PLAYER_SPECIALIZATION_CHANGED")
    noSetup(ns)
    H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "same-roll", 1214909)
    local animation = ns.Machine.GetFrame().scripts.OnUpdate
    assert(animation)
    H.fire("PLAYER_SPECIALIZATION_CHANGED", "party1")
    eq(ns.Machine.GetFrame().scripts.OnUpdate, animation)
  end)

  test("eligibility loss stops native tracking and animation and repeated recovery reuses resources", function()
    local ns = login()
    local frames, hooks, slots = #H.frames, H.hookCount, H.auraSlotCount
    for _, case in ipairs(unavailable) do
      H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "same-roll", 1214909)
      assert(ns.Machine.GetFrame().scripts.OnUpdate)
      local original = H[case.field]
      H[case.field] = case.value
      H.fire("SPELLS_CHANGED")
      inactive(ns)
      H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "ignored", 1214909)
      H.fire("TRAIT_CONFIG_UPDATED", 1)
      inactive(ns)
      H[case.field] = original
      H.fire("SPELLS_CHANGED")
      H.fire("TRAIT_CONFIG_UPDATED", 1)
      eq(ns.Machine.GetFrame():IsVisible(), true)
      eq(#H.frames, frames)
      eq(H.hookCount, hooks)
      eq(H.auraSlotCount, slots)
      eq(#H.timers, 0)
    end
  end)

  test("switching away closes selected Edit Mode controls and returning restores preview", function()
    local ns = login()
    H.enterEditMode()
    local selection = assert(H.findTemplate("EditModeSystemSelectionTemplate"))
    selection.scripts.OnMouseDown(selection)
    local input = H.findTemplate("InputBoxTemplate")
    input.focused = true
    H.button("Test spin").scripts.OnClick()
    selection.scripts.OnDragStart(selection)
    local frames, hooks = #H.frames, H.hookCount
    for _, spec in ipairs({ 259, 261 }) do
      H.spec = spec
      H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
      inactive(ns)
      eq(selection:IsShown(), false)
      eq(input:IsVisible(), false)
      eq(GetCurrentKeyBoardFocus(), nil)
      eq(ns.Machine.GetFrame().moving, false)
      H.exitEditMode()
      H.enterEditMode()
      inactive(ns)
      H.spec = 260
      H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
      eq(ns.EditMode.IsPreviewActive(), true)
      eq(ns.Machine.GetFrame():IsVisible(), true)
      eq(#H.frames, frames)
      eq(H.hookCount, hooks)
    end
    H.exitEditMode()
    eq(ns.Machine.GetFrame():IsVisible(), true)
  end)

  test("first Outlaw activation attaches an already active or late Edit Mode manager once", function()
    for _, lateManager in ipairs({ false, true }) do
      local manager
      local ns = login(function()
        H.spec = 261
        manager = EditModeManagerFrame
        manager.active = true
        if lateManager then
          EditModeManagerFrame = nil
        end
      end, nil, true)
      noSetup(ns)
      H.spec = 260
      H.fire("SPELLS_CHANGED")
      if lateManager then
        EditModeManagerFrame = manager
        H.fire("ADDON_LOADED", "Blizzard_EditMode")
      end
      eq(ns.EditMode.IsPreviewActive(), true)
      local frames, hooks = #H.frames, H.hookCount
      H.fire("ADDON_LOADED", "Blizzard_EditMode")
      H.fire("PLAYER_ENTERING_WORLD", false, false)
      eq(#H.frames, frames)
      eq(H.hookCount, hooks)
    end
  end)

  test("loading and movies that start while inactive still suppress a newly eligible display", function()
    for _, event in ipairs({ "PLAYER_LEAVING_WORLD", "PLAY_MOVIE" }) do
      local ns = login(function()
        H.spec = 259
      end)
      H.fire(event, 1)
      H.spec = 260
      H.fire("SPELLS_CHANGED")
      eq(ns.Machine.GetFrame():IsVisible(), false)
      local frames = #H.frames
      H.fire(event == "PLAY_MOVIE" and "STOP_MOVIE" or "PLAYER_ENTERING_WORLD", false, false)
      eq(ns.Machine.GetFrame():IsVisible(), true)
      eq(#H.frames, frames)
    end
  end)

  test("first activation respects current combat and overlay state after inactive startup", function()
    for _, state in ipairs({ "combat", "restricted", "cinematic", "petBattle", "hiddenUI" }) do
      local ns = login(function()
        H.spec = 259
      end)
      if state == "hiddenUI" then
        UIParent:Hide()
      else
        H[state] = true
      end
      H.spec = 260
      H.fire("SPELLS_CHANGED")
      local live = state == "combat" or state == "restricted"
      eq(ns.Machine.GetFrame():IsVisible(), live)
      eq(ns.EditMode.IsPreviewActive(), false)
      H.spec = 261
      H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
      inactive(ns)
      H[state] = false
      UIParent:Show()
      H.spec = 260
      H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
      eq(ns.Machine.GetFrame():IsVisible(), true)
    end
  end)

  test("returning to Outlaw applies layout changes made while runtime events were suspended", function()
    local ns = login(nil, { scale = 1.5, x = 400, y = 0 })
    H.spec = 261
    H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    local previous = ns.Machine.GetFrame().points.CENTER[3]
    UIParent.width = 800
    H.fire("DISPLAY_SIZE_CHANGED")
    eq(ns.Machine.GetFrame().points.CENTER[3], previous)
    H.spec = 260
    H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    assert(ns.Machine.GetFrame().points.CENTER[3] < previous)
    eq(ns.Config.GetPosition(), 400)
  end)
end

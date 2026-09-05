-- Observable ordinary presentation; native aura selection still requires the client
return function(test, H, loadAddon)
  local eq = H.eq
  local function login(saved, combat)
    local ns = loadAddon(saved)
    H.combat, H.playerCombat = combat == true, combat == true
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
  end
  local function selectCabinet()
    H.enterEditMode()
    local selection = H.findTemplate("EditModeSystemSelectionTemplate")
    selection.scripts.OnMouseDown(selection)
  end
  local function click(label, checked)
    for _, widget in ipairs(H.widgets) do
      if rawget(widget, "text") == label then
        local checkbox = widget.parent
        checkbox:SetChecked(checked)
        checkbox.scripts.OnClick(checkbox)
        return
      end
    end
    error("missing setting " .. label)
  end
  -- Inspect authored metadata only; never ask a native result for visibility
  local function ordinaryShown(widget)
    while widget do
      if widget.sealed or not widget.shown then
        return false
      end
      widget = widget.parent
    end
    return true
  end
  local function footerState(ns, expected, showBar)
    local empty, names, times, bars = 0, 0, 0, 0
    for _, widget in ipairs(H.widgets) do
      if ordinaryShown(widget) then
        local text = rawget(widget, "text")
        if text == "Try yer luck, matey!" then
          empty = empty + 1
        end
        if text == "26 s" then
          times = times + 1
        end
        for _, result in ipairs(ns.Game.Results) do
          if text == result.label then
            eq(text, expected)
            names = names + 1
          end
        end
        if widget.kind == "StatusBar" then
          bars = bars + 1
        end
      end
    end
    eq(empty, expected == "empty" and 1 or 0)
    local result = expected ~= "empty" and expected ~= "hidden"
    eq(names, result and 1 or 0)
    eq(times, names)
    eq(bars, result and showBar and 1 or 0)
  end
  local function reelState(ns, expected)
    for reelIndex = 1, 3 do
      local carrier = H.nativeSlots[(reelIndex - 1) * 4 + 1].container.parent
      local layers = 0
      for _, child in ipairs(carrier.children) do
        if child.kind == "Frame" and ordinaryShown(child) then
          local centers = 0
          for _, texture in ipairs(H.reelRegions(child)) do
            local point = texture.points.CENTER
            if point and point[4] == 0 then
              centers = centers + 1
              eq(texture.alpha, expected == "empty" and 0.22 or 1)
            end
          end
          if centers > 0 then
            eq(centers, reelIndex == 1 and 1 or #ns.Art.VariantSymbols)
            layers = layers + 1
          end
        end
      end
      eq(layers, expected == "hidden" and 0 or 1)
    end
  end
  local function nativeState(live, active, showBar)
    for _, slot in ipairs(H.nativeSlots) do
      local expected = live
      if slot.button.bindings.SetDurationBar then
        expected = live and showBar
      elseif slot == H.nativeSlots[13] then
        expected = live and active
      end
      eq(slot.container.enabled, expected)
      eq(slot.container.shown, expected)
    end
  end

  test("every result preview replaces empty text with either duration setting and every live visibility choice", function()
    for _, mode in ipairs({ "always", "active", "combat" }) do
      for _, animate in ipairs({ false, true }) do
        local ns = login({
          visibility = mode,
          durationBarEnabled = false,
          animationEnabled = animate,
        })
        selectCabinet()
        local index = 2
        for _ = 1, 3 do
          for _ = 1, 5 do
            local expected = ns.Game.Results[index] and ns.Game.Results[index].label or "empty"
            for _, showBar in ipairs({ false, true, false }) do
              click("Show duration bar", showBar)
              footerState(ns, expected, showBar)
              nativeState(false, false, showBar)
            end
            H.button("Test spin").scripts.OnClick()
            index = index % 5 + 1
            expected = ns.Game.Results[index] and ns.Game.Results[index].label or "empty"
            footerState(ns, expected, false)
            H.advance(0.8)
            footerState(ns, expected, false)
            H.advance(3.2)
            footerState(ns, expected, false)
          end
        end
      end
    end
  end)

  test("result and empty reel previews never share a visible symbol layer during cycles spins and resizing", function()
    local ns = login()
    selectCabinet()
    local frames, slots, hooks = #H.frames, H.auraSlotCount, H.hookCount
    local index = 2
    for _, scale in ipairs({ 0.6, 1, 1.8 }) do
      H.findTemplate("MinimalSliderWithSteppersTemplate"):SetValue(scale)
      for _ = 1, 10 do
        reelState(ns, index == 5 and "empty" or "result")
        H.button("Test spin").scripts.OnClick()
        index = index % 5 + 1
        reelState(ns, index == 5 and "empty" or "result")
        H.advance(0.8)
        reelState(ns, index == 5 and "empty" or "result")
        H.advance(3.2)
        reelState(ns, index == 5 and "empty" or "result")
      end
    end
    eq(#H.frames, frames)
    eq(H.auraSlotCount, slots)
    eq(H.hookCount, hooks)
    eq(#H.timers, 0)
  end)

  test("combat live preview and hidden transitions restore one complete presentation without stale samples", function()
    for _, mode in ipairs({ "always", "active", "combat" }) do
      for _, showBar in ipairs({ false, true }) do
        for _, initialCombat in ipairs({ false, true }) do
          local ns = login({ visibility = mode, durationBarEnabled = showBar }, initialCombat)
          local frame = ns.Machine.GetFrame()
          local function liveState(combat)
            local shown = mode ~= "combat" or combat
            local empty = shown and mode ~= "active"
            eq(frame:IsVisible(), shown)
            footerState(ns, empty and "empty" or "hidden", showBar)
            reelState(ns, empty and "empty" or "hidden")
            nativeState(shown, mode == "active", showBar)
          end
          liveState(initialCombat)
          H.combat, H.playerCombat = false, false
          H.fire("PLAYER_REGEN_ENABLED")
          selectCabinet()
          local frames, slots, hooks = #H.frames, H.auraSlotCount, H.hookCount
          for cycle = 1, 5 do
            local index = (cycle % 5) + 1
            local expected = ns.Game.Results[index] and ns.Game.Results[index].label or "empty"
            footerState(ns, expected, showBar)
            reelState(ns, index == 5 and "empty" or "result")
            H.exitEditMode()
            liveState(false)
            H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "before" .. cycle, 1214909)
            H.combat, H.playerCombat, H.restricted = true, true, true
            H.fire("PLAYER_REGEN_DISABLED")
            liveState(true)
            H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "during" .. cycle, 1214909)
            H.advance(0.8)
            liveState(true)
            H.fire("PLAYER_LEAVING_WORLD")
            eq(frame:IsVisible(), false)
            footerState(ns, "hidden", showBar)
            reelState(ns, "hidden")
            nativeState(false, false, showBar)
            eq(frame.scripts.OnUpdate, nil)
            H.fire("PLAYER_ENTERING_WORLD", false, false)
            liveState(true)
            H.combat, H.playerCombat, H.restricted = false, false, false
            H.fire("PLAYER_REGEN_ENABLED")
            liveState(false)
            selectCabinet()
            footerState(ns, expected, showBar)
            H.button("Test spin").scripts.OnClick()
          end
          H.button("Reset to Defaults").scripts.OnClick()
          footerState(ns, ns.Game.Results[2].label, true)
          reelState(ns, "result")
          H.exitEditMode()
          footerState(ns, "empty", true)
          nativeState(true, false, true)
          eq(frame.scripts.OnUpdate, nil)
          eq(#H.frames, frames)
          eq(H.auraSlotCount, slots)
          eq(H.hookCount, hooks)
          eq(#H.timers, 0)
        end
      end
    end
  end)

  test("reported combat sequence stays idempotent with nil or false inactive Edit Mode and no diagnostics", function()
    local sequence = {
      "SPELLS_CHANGED",
      "PLAYER_REGEN_DISABLED",
      "PLAYER_REGEN_ENABLED",
      "PLAYER_REGEN_DISABLED",
      "PLAYER_REGEN_DISABLED",
      "PLAYER_REGEN_ENABLED",
      "PLAYER_REGEN_DISABLED",
      "PLAYER_REGEN_ENABLED",
      "PLAYER_REGEN_DISABLED",
      "PLAYER_REGEN_ENABLED",
      "PLAYER_REGEN_DISABLED",
    }
    for _, inactive in ipairs({ "nil", "false" }) do
      local ns = loadAddon({ visibility = "combat" })
      EditModeManagerFrame.IsEditModeActive = function()
        if inactive == "false" then
          return false
        end
      end
      -- The former opt-in flag must no longer produce chat output
      _G.RollTheBonesSlotsDebug = true
      H.fire("ADDON_LOADED", "RollTheBonesSlots")
      H.fire("PLAYER_LOGIN")
      local frame = ns.Machine.GetFrame()
      local frames, slots, hooks = #H.frames, H.auraSlotCount, H.hookCount
      for cycle = 1, 10 do
        for index, event in ipairs(sequence) do
          H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", cycle .. ":" .. index, 1214909)
          H.combat, H.playerCombat = event == "PLAYER_REGEN_DISABLED", event == "PLAYER_REGEN_DISABLED"
          H.fire(event)
          eq(frame:IsVisible(), H.playerCombat)
          footerState(ns, H.playerCombat and "empty" or "hidden", true)
          reelState(ns, H.playerCombat and "empty" or "hidden")
          nativeState(H.playerCombat, false, true)
          eq(frame.scripts.OnUpdate, nil)
        end
      end
      local messages = #H.messages
      _G.RollTheBonesSlotsDebug = nil
      eq(messages, 0)
      eq(#H.frames, frames)
      eq(H.auraSlotCount, slots)
      eq(H.hookCount, hooks)
      eq(#H.timers, 0)
    end
  end)

  test("loading while Edit Mode is already active selects one sample and exits to the saved visibility rule", function()
    for _, mode in ipairs({ "always", "active", "combat" }) do
      for _, lateManager in ipairs({ false, true }) do
        local ns = loadAddon({ visibility = mode, durationBarEnabled = false })
        local manager = EditModeManagerFrame
        manager.active = true
        if lateManager then
          EditModeManagerFrame = nil
        end
        H.loggedIn = true
        H.fire("ADDON_LOADED", "RollTheBonesSlots")
        if lateManager then
          EditModeManagerFrame = manager
          H.fire("ADDON_LOADED", "Blizzard_EditMode")
        end
        local frame = ns.Machine.GetFrame()
        local frames, slots, hooks = #H.frames, H.auraSlotCount, H.hookCount
        for _ = 1, 3 do
          H.fire("PLAYER_ENTERING_WORLD", false, false)
          H.fire("ADDON_LOADED", "Blizzard_EditMode")
          eq(frame:IsVisible(), true)
          eq(ns.EditMode.IsPreviewActive(), true)
          footerState(ns, ns.Game.Results[2].label, false)
          reelState(ns, "result")
          nativeState(false, false, false)
        end
        H.exitEditMode()
        eq(frame:IsVisible(), mode ~= "combat")
        footerState(ns, mode == "always" and "empty" or "hidden", false)
        reelState(ns, mode == "always" and "empty" or "hidden")
        nativeState(mode ~= "combat", mode == "active", false)
        eq(#H.frames, frames)
        eq(H.auraSlotCount, slots)
        eq(H.hookCount, hooks)
        eq(#H.timers, 0)
      end
    end
  end)

  test("overlapping overlays keep all content hidden until the final cause clears in live and preview states", function()
    local exitOrders = {
      { "STOP_MOVIE", "PLAYER_ENTERING_WORLD", "CINEMATIC_STOP", "PET_BATTLE_CLOSE" },
      { "PLAYER_ENTERING_WORLD", "PET_BATTLE_CLOSE", "CINEMATIC_STOP" },
      { "PET_BATTLE_CLOSE", "CINEMATIC_STOP", "STOP_MOVIE", "PLAYER_ENTERING_WORLD" },
    }
    for _, mode in ipairs({ "always", "active", "combat" }) do
      local ns = login({ visibility = mode })
      selectCabinet()
      local frame = ns.Machine.GetFrame()
      local frames, slots, hooks = #H.frames, H.auraSlotCount, H.hookCount
      for _, preview in ipairs({ true, false }) do
        if not preview then
          H.exitEditMode()
          H.combat, H.playerCombat = true, true
          H.fire("PLAYER_REGEN_DISABLED")
        end
        for _, exitOrder in ipairs(exitOrders) do
          H.cinematic, H.petBattle = true, true
          for _, event in ipairs({
            "CINEMATIC_START",
            "PLAY_MOVIE",
            "PET_BATTLE_OPENING_START",
            "PLAYER_LEAVING_WORLD",
          }) do
            H.fire(event)
            eq(frame:IsVisible(), false)
            footerState(ns, "hidden", true)
            reelState(ns, "hidden")
            nativeState(false, false, true)
            eq(frame.scripts.OnUpdate, nil)
          end
          for index, event in ipairs(exitOrder) do
            if event == "CINEMATIC_STOP" then
              H.cinematic = false
            elseif event == "PET_BATTLE_CLOSE" then
              H.petBattle = false
            end
            H.fire(event)
            H.fire(event)
            if index < #exitOrder then
              eq(frame:IsVisible(), false)
              footerState(ns, "hidden", true)
              reelState(ns, "hidden")
              nativeState(false, false, true)
            end
          end
          eq(frame:IsVisible(), true)
          footerState(ns, preview and ns.Game.Results[2].label or mode == "active" and "hidden" or "empty", true)
          reelState(ns, preview and "result" or mode == "active" and "hidden" or "empty")
          nativeState(not preview, mode == "active", true)
          eq(frame.scripts.OnUpdate, nil)
        end
      end
      eq(#H.frames, frames)
      eq(H.auraSlotCount, slots)
      eq(H.hookCount, hooks)
      eq(#H.timers, 0)
    end
  end)

  test("unavailable or unreadable eligibility clears live artwork and recovers without retaining samples", function()
    for _, mode in ipairs({ "always", "active", "combat" }) do
      local ns = login({ visibility = mode }, true)
      local frame = ns.Machine.GetFrame()
      local frames, slots, hooks = #H.frames, H.auraSlotCount, H.hookCount
      -- Nil/secret entries are defensive fault injection, not claims about normal API returns
      for _, fault in ipairs({
        { "spec", 0 },
        { "spec", 259 },
        { "known", false },
        { "spec" },
        { "known" },
        { "spec", H.secret },
        { "known", H.secret },
      }) do
        H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", fault[1] .. tostring(#H.pointWrites), 1214909)
        H[fault[1]] = fault[2]
        H.fire("SPELLS_CHANGED")
        eq(frame:IsVisible(), false)
        footerState(ns, "hidden", true)
        reelState(ns, "hidden")
        nativeState(false, false, true)
        eq(frame.scripts.OnUpdate, nil)
        H.spec, H.known = 260, true
        H.fire("TRAIT_CONFIG_UPDATED")
        eq(frame:IsVisible(), true)
        footerState(ns, mode == "active" and "hidden" or "empty", true)
        reelState(ns, mode == "active" and "hidden" or "empty")
        nativeState(true, mode == "active", true)
        eq(frame.scripts.OnUpdate, nil)
      end
      eq(#H.frames, frames)
      eq(H.auraSlotCount, slots)
      eq(H.hookCount, hooks)
      eq(#H.timers, 0)
    end
  end)
end

-- Authored geometry and lifecycle checks; native rendering still needs WoW
return function(test, H, loadAddon)
  local eq = H.eq
  local function login(saved)
    local ns = loadAddon(saved)
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
  end
  local function selectCabinet()
    H.enterEditMode()
    local selection = H.findTemplate("EditModeSystemSelectionTemplate")
    selection.scripts.OnMouseDown(selection)
    return H.dropdown("Display mode"), selection
  end
  local function choose(dropdown, value)
    for _, option in ipairs(dropdown.options) do
      if option.value == value then
        option.onSelect(value)
        return
      end
    end
    error("display mode missing")
  end
  local function click(checkbox, checked)
    checkbox:SetChecked(checked)
    checkbox.scripts.OnClick(checkbox)
  end
  local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-8, "unexpected screen geometry")
  end
  local function center(frame)
    local x, y = frame:GetCenter()
    return x * frame:GetEffectiveScale(), y * frame:GetEffectiveScale()
  end
  local function ordinaryShown(widget)
    while widget do
      if widget.sealed or not widget.shown then
        return false
      end
      widget = widget.parent
    end
    return true
  end
  local function centered(inner, outer)
    near(inner.x + inner.width / 2, outer.x + outer.width / 2)
    near(inner.y + inner.height / 2, outer.y + outer.height / 2)
  end

  test("Full and Compact selector preserves choices and centers every native and preview result at both sizes", function()
    for _, parentScale in ipairs({ 0.64, 1, 1.2 }) do
      local saved = { x = 160, y = -96, scale = 1.25 }
      local ns = login(saved)
      UIParent:SetScale(parentScale)
      local dropdown, selection = selectCabinet()
      eq(#dropdown.options, 2)
      eq(dropdown.options[1].label, "Full")
      eq(dropdown.options[2].label, "Compact")
      local frame = ns.Machine.GetFrame()
      local x, y = center(frame)
      local widgets, slots, hooks = #H.widgets, H.auraSlotCount, H.hookCount
      for _ = 1, 3 do
        for _, compact in ipairs({ true, false }) do
          H.button("Test spin").scripts.OnClick()
          H.advance(0.7)
          choose(dropdown, compact)
          eq(saved.compactMode, compact)
          eq(dropdown:GetText(), compact and "Compact" or "Full")
          eq(frame.height, compact and 140 or 246)
          eq(frame.scripts.OnUpdate, nil)
          eq(selection.allPoints, frame)
          local actualX, actualY = center(frame)
          near(actualX, x)
          near(actualY, y)
          for reelIndex = 1, 3 do
            local carrier = H.nativeSlots[(reelIndex - 1) * 4 + 1].container.parent
            local well = H.frameRect(carrier.parent, frame)
            eq(well.height, compact and 80 or 153)
            eq(well.y, compact and 22 or 39)
            eq(carrier.height, 153)
            local inspected = 0
            -- Resolve actual texture rectangles from their complete anchor and scale chains
            local regions = {}
            local function visit(parent)
              for _, child in ipairs(parent.children) do
                if child.kind == "Texture" then
                  regions[#regions + 1] = child
                end
                visit(child)
              end
            end
            visit(carrier)
            for _, texture in ipairs(regions) do
              local point = texture.points.CENTER
              if H.symbolInfo(texture) and point and point[4] == 0 and point[3] + carrier.points.CENTER[3] == 0 then
                local bounds = H.frameRect(texture, frame)
                centered(bounds, well)
                near(bounds.height, compact and 73.5 or 98)
                assert(bounds.y >= well.y and bounds.y + bounds.height <= well.y + well.height)
                if compact then
                  assert(bounds.x >= well.x and bounds.x + bounds.width <= well.x + well.width)
                end
                inspected = inspected + 1
              end
            end
            assert(inspected >= 5, "must inspect idle, previews, and native results")
          end
          for _, group in ipairs(H.animationGroups) do
            eq(group.playing, false)
            for _, animation in ipairs(group.animations) do
              local light = animation.target
              centered(H.frameRect(light, frame), H.frameRect(light.parent, frame))
              eq(light.alpha, 0)
            end
          end
          local titleCount = 0
          for _, widget in ipairs(H.widgets) do
            if rawget(widget, "text") == "Roll the Bones" and ordinaryShown(widget) then
              titleCount = titleCount + 1
            end
          end
          eq(titleCount, compact and 0 or 1)
        end
      end
      eq(#H.widgets, widgets)
      eq(H.auraSlotCount, slots)
      eq(H.hookCount, hooks)
    end
  end)

  test("compact layout and ten percent scale survive reload and reset restores Full and closes its menu", function()
    local saved = { compactMode = true, scale = 0.1, x = 1600, y = -960 }
    for _ = 1, 2 do
      local ns = login(saved)
      local frame = ns.Machine.GetFrame()
      eq(frame.height, 140)
      eq(frame:GetScale(), 0.1)
      local dropdown = selectCabinet()
      eq(dropdown:GetText(), "Compact")
      local x, y = center(frame)
      for _, scale in ipairs({ 1.8, 0.1, 1, 0.1 }) do
        H.findTemplate("MinimalSliderWithSteppersTemplate"):SetValue(scale)
        local actualX, actualY = center(frame)
        near(actualX, x)
        near(actualY, y)
      end
      dropdown.menuOpen = true
      H.exitEditMode()
      eq(dropdown.menuOpen, false)
    end
    local ns = login(saved)
    local dropdown = selectCabinet()
    H.button("Test spin").scripts.OnClick()
    dropdown.menuOpen = true
    H.button("Reset to Defaults").scripts.OnClick()
    eq(saved.compactMode, false)
    eq(dropdown:GetText(), "Full")
    eq(dropdown.menuOpen, false)
    eq(saved.scale, 1)
    eq(ns.Machine.GetFrame().height, 246)
    eq(ns.Machine.GetFrame().scripts.OnUpdate, nil)
  end)

  test("compact clamping follows the shorter frame and expanding stays within screen edges", function()
    local ns = login({ compactMode = true, scale = 0.1 })
    local dropdown = selectCabinet()
    local frame = ns.Machine.GetFrame()
    for _, scale in ipairs({ 0.1, 1, 1.8 }) do
      H.findTemplate("MinimalSliderWithSteppersTemplate"):SetValue(scale)
      for _, compact in ipairs({ true, false }) do
        choose(dropdown, compact)
        ns.Config.SetPosition(1e8, -1e8)
        ns.Machine.ApplyPosition()
        local x, y = center(frame)
        near(x + 400 * scale / 2, UIParent.width)
        near(y - (compact and 140 or 246) * scale / 2, 0)
        choose(dropdown, not compact)
        x, y = center(frame)
        assert(x + frame.width * scale / 2 <= UIParent.width + 1e-8)
        assert(y - frame.height * scale / 2 >= -1e-8)
      end
    end
  end)

  test("both footer layouts keep text and icons centered inside their bar and exact tooltip area", function()
    local ns = login({ compactMode = true })
    local frame = ns.Machine.GetFrame()
    local dropdown = selectCabinet()
    for _, compact in ipairs({ false, true }) do
      choose(dropdown, compact)
      local nativeFooter = H.nativeSlots[compact and 26 or 14].button
      local nativeBar = H.nativeSlots[compact and 27 or 15].button.bindings.SetDurationBar
      local barRect = H.frameRect(nativeBar, frame)
      eq(barRect.y, compact and 110 or 205)
      eq(barRect.height, compact and 18 or 26)
      eq(barRect.width, 312)
      eq(nativeFooter.hitRectInsets[3], barRect.y)
      eq(nativeFooter.height - nativeFooter.hitRectInsets[3] - nativeFooter.hitRectInsets[4], barRect.height)
      for _, region in pairs(nativeFooter.bindings) do
        local bounds = H.frameRect(region, frame)
        near(bounds.y + bounds.height / 2, barRect.y + barRect.height / 2)
        assert(bounds.y >= barRect.y and bounds.y + bounds.height <= barRect.y + barRect.height)
      end
      local icon = nativeFooter.bindings.SetIcon
      eq(icon.width, 16)
      eq(icon.height, 16)
    end
  end)

  test("compact previews retain each result with a thin optional bar and no other layout showing through", function()
    local ns = login({ compactMode = true })
    selectCabinet()
    local index = 2
    for _ = 1, 5 do
      for _, showBar in ipairs({ false, true }) do
        click(H.checkbox("Show duration bar"), showBar)
        local names, times, bars, empty = 0, 0, 0, 0
        for _, widget in ipairs(H.widgets) do
          if ordinaryShown(widget) then
            local text = rawget(widget, "text")
            if index <= #ns.Game.Results and text == ns.Game.Results[index].label then
              names = names + 1
            elseif text == "26 s" then
              times = times + 1
            elseif text == "Try yer luck, matey!" then
              empty = empty + 1
            end
            if widget.kind == "StatusBar" then
              bars = bars + 1
              eq(widget.height, 18)
              eq(widget.width, 312)
            end
          end
        end
        local result = index <= #ns.Game.Results
        eq(names, result and 1 or 0)
        eq(times, names)
        eq(empty, result and 0 or 1)
        eq(bars, result and showBar and 1 or 0)
      end
      H.button("Test spin").scripts.OnClick()
      H.advance(3.2)
      index = index % 5 + 1
    end
  end)

  test("footer text stays vertically centered and only Compact shrinks its inherited font by one pixel", function()
    for _, font in ipairs({
      { file = "Fonts\\FRIZQT__.TTF", size = 12, flags = "" },
      { file = "Fonts\\Localized.ttf", size = 16, flags = "OUTLINE" },
    }) do
      local ns = loadAddon({ compactMode = true })
      H.fontFile, H.fontSize, H.fontFlags = font.file, font.size, font.flags
      H.fire("ADDON_LOADED", "RollTheBonesSlots")
      H.fire("PLAYER_LOGIN")
      local dropdown = selectCabinet()
      local fontWrites = H.fontWrites
      for _, scale in ipairs({ 0.1, 1, 1.8, 1 }) do
        H.findTemplate("MinimalSliderWithSteppersTemplate"):SetValue(scale)
        for _, compact in ipairs({ false, true }) do
          choose(dropdown, compact)
          local footer = H.nativeSlots[compact and 26 or 14]
          local bar = H.nativeSlots[compact and 27 or 15].button.bindings.SetDurationBar
          local barRect = H.frameRect(bar, ns.Machine.GetFrame())
          local count = 0
          local function inspect(parent)
            for _, child in ipairs(parent.children) do
              if child.kind == "FontString" then
                count = count + 1
                eq(child.justifyV, "MIDDLE")
                eq(child.fontSize, font.size - (compact and 1 or 0))
                eq(child.fontFile, font.file)
                eq(child.fontFlags, font.flags)
                local bounds = H.frameRect(child, ns.Machine.GetFrame())
                near(bounds.y + bounds.height / 2, barRect.y + barRect.height / 2)
              end
              inspect(child)
            end
          end
          inspect(footer.container.parent)
          eq(count, 11) -- Empty state, native name/time, and all four preview pairs
          eq(footer.button.bindings.SetSpellName.justify, "LEFT")
          eq(footer.button.bindings.SetDurationText.justify, "RIGHT")
        end
      end
      eq(H.fontWrites, fontWrites)
      eq(H.fontFile, font.file)
      eq(H.fontSize, font.size)
      eq(H.fontFlags, font.flags)
    end
  end)

  test("compact native layouts follow visibility and restrictions reject mode changes without stale menus", function()
    for _, visibility in ipairs({ "always", "active", "combat" }) do
      local saved = { compactMode = true, visibility = visibility }
      local ns = login(saved)
      local frame = ns.Machine.GetFrame()
      local function coversEnabled(expected)
        for _, slot in ipairs(H.reelCovers(false)) do
          eq(slot.container.enabled, false)
          eq(slot.container.shown, false)
        end
        for _, slot in ipairs(H.reelCovers(true)) do
          eq(slot.container.enabled, expected)
          eq(slot.container.shown, expected)
        end
      end
      eq(H.nativeSlots[13].container.enabled, false)
      eq(H.nativeSlots[14].container.enabled, false)
      eq(H.nativeSlots[15].container.enabled, false)
      eq(H.nativeSlots[25].container.enabled, visibility == "active")
      eq(H.nativeSlots[26].container.enabled, visibility ~= "combat")
      eq(H.nativeSlots[27].container.enabled, visibility ~= "combat")
      coversEnabled(visibility ~= "combat")
      local dropdown = selectCabinet()
      coversEnabled(false)
      local widgets, slots = #H.widgets, H.auraSlotCount
      for cycle = 1, 3 do
        dropdown.menuOpen = true
        H.combat, H.playerCombat, H.restricted = true, true, true
        H.fire("PLAYER_REGEN_DISABLED")
        H.fire("ENCOUNTER_START")
        choose(dropdown, false)
        eq(saved.compactMode, true)
        eq(frame.height, 140)
        eq(dropdown.menuOpen, false)
        H.exitEditMode()
        eq(H.nativeSlots[13].container.enabled, false)
        eq(H.nativeSlots[14].container.enabled, false)
        eq(H.nativeSlots[15].container.enabled, false)
        eq(H.nativeSlots[25].container.enabled, visibility == "active")
        eq(H.nativeSlots[26].container.enabled, true)
        eq(H.nativeSlots[27].container.enabled, true)
        coversEnabled(true)
        H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "compact-roll-" .. cycle, 1214909)
        H.advance(3.2)
        H.combat, H.playerCombat, H.restricted = false, false, false
        H.fire("PLAYER_REGEN_ENABLED")
        H.fire("ENCOUNTER_END")
        H.fire("PLAYER_LEAVING_WORLD")
        coversEnabled(false)
        H.fire("PLAYER_ENTERING_WORLD", false, false)
        coversEnabled(visibility ~= "combat")
        dropdown = selectCabinet()
        coversEnabled(false)
        eq(dropdown:GetText(), "Compact")
      end
      eq(#H.widgets, widgets)
      eq(H.auraSlotCount, slots)
    end
  end)
end

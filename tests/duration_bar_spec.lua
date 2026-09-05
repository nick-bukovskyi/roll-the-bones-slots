-- Native binding and player controls, not a simulation of aura timing or secrets
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
  local function durationSlot()
    for _, slot in ipairs(H.nativeSlots) do
      if slot.button.bindings.SetDurationBar then
        return slot
      end
    end
    error("native duration bar is missing")
  end
  local function selectCabinet()
    H.enterEditMode()
    local selection = H.findTemplate("EditModeSystemSelectionTemplate")
    selection.scripts.OnMouseDown(selection)
    for _, widget in ipairs(H.widgets) do
      if rawget(widget, "text") == "Show duration bar" then
        return widget.parent
      end
    end
    error("duration bar checkbox is missing")
  end
  local function previewBars()
    local bars = {}
    for _, widget in ipairs(H.frames) do
      if widget.kind == "StatusBar" and widget.parent.kind ~= "AuraButton" then
        bars[#bars + 1] = widget
      end
    end
    eq(#bars, 4)
    return bars
  end
  local function click(checkbox, checked)
    checkbox:SetChecked(checked)
    checkbox.scripts.OnClick(checkbox)
  end

  test("duration preference adds and repairs only its field while preserving false and future schemas", function()
    local ns = loadAddon()
    local Config = ns.Config
    for _, value in ipairs({ true, false, "false", 0, H.secret }) do
      local saved = {
        schemaVersion = 1,
        scale = 1.3,
        x = 45,
        animationEnabled = false,
        durationBarEnabled = value,
        extra = "keep",
      }
      Config.Initialize(saved)
      eq(Config.GetDurationBarEnabled(), value ~= false)
      eq(saved.scale, 1.3)
      eq(saved.x, 45)
      eq(saved.animationEnabled, false)
      eq(saved.extra, "keep")
    end
    local saved = Config.Initialize({ scale = 0.8, animationEnabled = false })
    eq(saved.durationBarEnabled, true)
    eq(saved.scale, 0.8)
    eq(saved.animationEnabled, false)
    eq(Config.SetDurationBarEnabled(false), true)
    for _, invalid in ipairs({ "true", 1, {}, H.secret }) do
      eq(Config.SetDurationBarEnabled(invalid), false)
      eq(saved.durationBarEnabled, false)
    end
    eq(Config.SetDurationBarEnabled(nil), false)
    Config.Initialize(saved)
    eq(Config.GetDurationBarEnabled(), false)
    eq(Config.Reset(), true)
    eq(saved.durationBarEnabled, true)
    local future = { schemaVersion = 3, durationBarEnabled = "future value" }
    Config.Initialize(future)
    eq(Config.GetDurationBarEnabled(), true)
    eq(Config.SetDurationBarEnabled(false), false)
    eq(Config.Reset(), false)
    eq(future.durationBarEnabled, "future value")
    eq(future.schemaVersion, 3)
  end)

  test("native bar binds remaining duration for the same buffs below the unchanged footer labels", function()
    login()
    local slot = durationSlot()
    local bar = slot.button.bindings.SetDurationBar
    local footer = H.nativeSlots[14]
    for id, included in pairs(footer.filters) do
      eq(slot.filters[id], included)
    end
    for id, included in pairs(slot.filters) do
      eq(footer.filters[id], included)
    end
    eq(slot.button.durationBarOptions.direction, Enum.StatusBarTimerDirection.RemainingTime)
    eq(slot.button.durationBarOptions.interpolation, Enum.StatusBarInterpolation.Immediate)
    eq(bar.orientation, "HORIZONTAL")
    eq(bar.fillStyle, Enum.StatusBarFillStyle.Standard)
    eq(bar.mouse, false)
    eq(slot.button.mouse, false)
    eq(next(bar.scripts), nil)
    eq(next(slot.button.scripts), nil)
    eq(slot.button.sealed, true)
    eq(slot.button.shown, false)
    for _, region in pairs(footer.button.bindings) do
      assert(region.parent.frameLevel > bar.frameLevel, "footer labels must stay above the native fill")
    end
    assert(bar.frameLevel > footer.button.frameLevel, "bar must stay above footer backing")
    eq(bar.fill.texture, "Interface\\AddOns\\RollTheBonesSlots\\public\\art\\duration-fill.tga")
    local backing = footer.button.children[1]
    eq(bar.points.TOPLEFT[3], backing.points.TOPLEFT[3])
    eq(bar.points.TOPLEFT[4], backing.points.TOPLEFT[4])
    eq(bar.width, backing.width)
    eq(bar.height, backing.height)
    eq(bar.points.TOPLEFT[3], 50)
    eq(bar.width, 301)
    local icon = footer.button.bindings.SetIcon
    local iconPoint, barPoint = icon.points.TOPLEFT, bar.points.TOPLEFT
    assert(iconPoint[3] > barPoint[3] and iconPoint[3] + icon.width < barPoint[3] + bar.width)
    assert(-iconPoint[4] > -barPoint[4] and -iconPoint[4] + icon.height < -barPoint[4] + bar.height)
    eq(icon.width, 16)
    eq(icon.height, 16)
    eq(#H.timers, 0)
    eq(H.cabinet().scripts.OnUpdate, nil)
  end)

  test("duration toggle changes only bar visibility and persists independently of reduced motion", function()
    local ns = login({ durationBarEnabled = false, animationEnabled = false })
    local native = durationSlot().container
    eq(native.enabled, false)
    eq(native.shown, false)
    eq(H.nativeSlots[14].container.enabled, true)
    local checkbox = selectCabinet()
    eq(checkbox:GetChecked(), false)
    for _, bar in ipairs(previewBars()) do
      eq(bar.shown, false)
    end
    click(checkbox, true)
    eq(ns.Config.GetDurationBarEnabled(), true)
    eq(ns.Config.GetAnimationEnabled(), false)
    local active
    for _, bar in ipairs(previewBars()) do
      eq(bar.minimum, 0)
      eq(bar.maximum, 30)
      eq(bar.value, 26)
      eq(bar.shown, true)
      if bar:IsVisible() then
        active = bar
      end
    end
    assert(active)
    local labels = {}
    for _, child in ipairs(active.parent.children) do
      if child.kind == "Frame" then
        for _, region in ipairs(child.children) do
          if region.kind == "FontString" then
            labels[#labels + 1] = region
          end
        end
      end
    end
    eq(#labels, 2)
    click(checkbox, false)
    for _, label in ipairs(labels) do
      eq(label:IsVisible(), true)
      assert(label.text ~= "")
    end
    click(checkbox, true)
    eq(native.enabled, false)
    H.exitEditMode()
    eq(native.enabled, true)
    eq(native.shown, true)
    eq(RollTheBonesSlotsDB.durationBarEnabled, true)
    selectCabinet()
    click(checkbox, false)
    H.exitEditMode()
    eq(native.enabled, false)
    eq(H.nativeSlots[14].container.enabled, true)
    local saved = RollTheBonesSlotsDB
    ns = login(saved)
    eq(ns.Config.GetDurationBarEnabled(), false)
    eq(durationSlot().container.enabled, false)
  end)

  test("duration control rejects combat edits and recovers across repeated previews overlays and resets", function()
    local ns = login()
    local checkbox = selectCabinet()
    local bars = previewBars()
    local frames, slots, hooks = #H.frames, #H.nativeSlots, H.hookCount
    H.restricted, H.combat = true, true
    H.fire("PLAYER_REGEN_DISABLED")
    click(checkbox, false)
    eq(ns.Config.GetDurationBarEnabled(), true)
    H.restricted, H.combat = false, false
    H.fire("PLAYER_REGEN_ENABLED")
    for cycle = 1, 15 do
      H.exitEditMode()
      selectCabinet()
      click(checkbox, false)
      for sample = 1, 5 do
        ns.Machine.PreviewNext()
        for _, bar in ipairs(bars) do
          eq(bar:IsVisible(), false)
        end
      end
      H.exitEditMode()
      eq(durationSlot().container.enabled, false)
      H.fire("PLAYER_LEAVING_WORLD")
      H.fire("PLAYER_ENTERING_WORLD", false, false)
      H.petBattle = true
      H.fire("PET_BATTLE_OPENING_START")
      H.petBattle = false
      H.fire("PET_BATTLE_CLOSE")
      eq(durationSlot().container.enabled, false)
      selectCabinet()
      H.button("Reset to Defaults").scripts.OnClick()
      eq(checkbox:GetChecked(), true)
      eq(ns.Config.GetDurationBarEnabled(), true)
      for _, bar in ipairs(bars) do
        eq(bar.shown, true)
      end
    end
    H.exitEditMode()
    eq(durationSlot().container.enabled, true)
    eq(#H.frames, frames)
    eq(#H.nativeSlots, slots)
    eq(H.hookCount, hooks)
    eq(#H.timers, 0)
    eq(H.cabinet().scripts.OnUpdate, nil)
  end)
end

return function(test, H, loadAddon)
  local eq = H.eq
  local styles = { "captains-walnut", "sailors-case", "tavern-oak", "ironbound-case", "oxblood-travel-case" }
  local labels = { "Captain's Walnut", "Sailor's Case", "Tavern Oak", "Ironbound Case", "Oxblood Travel Case" }
  local function login(saved)
    local ns = loadAddon(saved)
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
  end
  local function settings()
    H.enterEditMode()
    local selection = H.findTemplate("EditModeSystemSelectionTemplate")
    selection.scripts.OnMouseDown(selection)
    return H.dropdown("Cabinet style")
  end
  local function choose(dropdown, id)
    for _, option in ipairs(dropdown.options) do
      if option.value == id then
        option.onSelect(id)
        return
      end
    end
    error("missing cabinet selection")
  end
  local function ordinaryCabinet(ns, compact, style)
    local name = "cabinet-" .. style .. (compact and "-compact" or "") .. ".tga"
    for _, child in ipairs(ns.Machine.GetFrame().children) do
      for _, region in ipairs(child.children) do
        local file = rawget(region, "texture")
        if file and file:match("([^\\]+)$") == name then
          return child
        end
      end
    end
    error("ordinary cabinet missing")
  end
  local function selectionState(ns, compact, style, presentation)
    for _, small in ipairs({ false, true }) do
      for _, id in ipairs(styles) do
        local selected = small == compact and id == style
        local slot = H.cabinetSlot(small, id)
        eq(slot.container.enabled, selected and presentation == "active")
        eq(slot.container.shown, selected and presentation == "active")
        eq(ordinaryCabinet(ns, small, id).shown, selected and (presentation == "preview" or presentation == "live"))
        eq(slot.button.sealed, true)
      end
    end
  end

  test("cabinet defaults and migrations preserve other preferences and reject invalid or future choices", function()
    local ns = loadAddon()
    for _, version in ipairs({ false, 1, 2, 3, 4 }) do
      for _, choice in ipairs({ false, "missing", 4, {}, H.secret, "sailors-case" }) do
        local extra = { pack = "future icons" }
        local saved = {
          schemaVersion = version or nil,
          cabinetStyle = choice,
          compactMode = true,
          animationEnabled = false,
          durationBarEnabled = false,
          scale = 0.75,
          x = 20,
          y = -30,
          extra = extra,
        }
        eq(ns.Config.Initialize(saved), saved)
        eq(saved.cabinetStyle, choice == "sailors-case" and choice or styles[1])
        eq(saved.schemaVersion, 4)
        eq(saved.compactMode, true)
        eq(saved.animationEnabled, false)
        eq(saved.durationBarEnabled, false)
        eq(saved.scale, 0.75)
        eq(saved.x, 20)
        eq(saved.y, -30)
        eq(saved.extra, extra)
        for _, invalid in ipairs({ false, 1, {}, H.secret, "Captain's Walnut", "missing" }) do
          eq(ns.Config.SetCabinetStyle(invalid), false)
        end
        eq(ns.Config.SetCabinetStyle(nil), false)
      end
    end
    local future = { schemaVersion = 5, cabinetStyle = "future style" }
    ns.Config.Initialize(future)
    eq(ns.Config.GetCabinetStyle(), styles[1])
    eq(ns.Config.SetCabinetStyle(styles[2]), false)
    eq(ns.Config.Reset(), false)
    eq(future.cabinetStyle, "future style")
    eq(future.schemaVersion, 5)
  end)

  test("Edit Mode offers the five cabinet styles, persists each choice and resets to Captain's Walnut", function()
    for i, style in ipairs(styles) do
      local saved = { compactMode = true, animationEnabled = false, extra = "keep" }
      local ns = login(saved)
      local dropdown = settings()
      eq(#dropdown.options, 5)
      eq(dropdown:GetText(), labels[1])
      for index, option in ipairs(dropdown.options) do
        eq(option.label, labels[index])
        eq(option.value, styles[index])
      end
      choose(dropdown, style)
      eq(saved.cabinetStyle, style)
      eq(dropdown:GetText(), labels[i])
      eq(dropdown.options[i].isSelected(style), true)
      eq(saved.compactMode, true)
      eq(saved.animationEnabled, false)
      selectionState(ns, true, style, "preview")
      dropdown.menuOpen = true
      H.exitEditMode()
      eq(dropdown.menuOpen, false)
      ns = login(saved)
      selectionState(ns, true, style, "live")
      dropdown = settings()
      eq(dropdown:GetText(), labels[i])
      dropdown.menuOpen = true
      H.button("Reset to Defaults").scripts.OnClick()
      eq(dropdown.menuOpen, false)
      eq(dropdown:GetText(), labels[1])
      eq(saved.cabinetStyle, styles[1])
      eq(saved.extra, "keep")
      selectionState(ns, false, styles[1], "preview")
    end
  end)

  test("every cabinet shares unchanged symbol and bar geometry at both layouts and all supported scale bounds", function()
    for _, compact in ipairs({ false, true }) do
      for _, scale in ipairs({ 0.1, 1, 1.8 }) do
        local saved = { compactMode = compact, scale = scale }
        local ns = login(saved)
        local dropdown = settings()
        H.button("Test spin").scripts.OnClick()
        H.advance(0.2)
        local frame = ns.Machine.GetFrame()
        local content = {}
        for _, widget in ipairs(H.widgets) do
          if H.symbolInfo(widget) then
            content[#content + 1] = widget
          end
        end
        for _, small in ipairs({ false, true }) do
          local bindings = H.footerSlot(small).button.bindings
          content[#content + 1] = bindings.SetSpellName
          content[#content + 1] = bindings.SetIcon
          content[#content + 1] = bindings.SetDurationText
          content[#content + 1] = H.durationSlot(small).button.bindings.SetDurationBar
          for _, cover in ipairs(H.reelCovers(small)) do
            content[#content + 1] = cover.button
          end
        end
        local rects = {}
        for index, widget in ipairs(content) do
          rects[index] = H.frameRect(widget, frame)
        end
        local widgets, slots, update = #H.widgets, H.auraSlotCount, frame.scripts.OnUpdate
        local artworkWrites = {}
        for _, widget in ipairs(H.widgets) do
          local owner = widget.parent
          while owner and owner ~= frame do
            owner = owner.parent
          end
          if owner == frame then
            artworkWrites[widget] = rawget(widget, "textureWriteCount") or 0
          end
        end
        local plays = {}
        for index, group in ipairs(H.animationGroups) do
          plays[index] = group.playCalls
        end
        for _, style in ipairs(styles) do
          choose(dropdown, style)
          selectionState(ns, compact, style, "preview")
          for index, widget in ipairs(content) do
            local rect = H.frameRect(widget, frame)
            for key, value in pairs(rects[index]) do
              eq(rect[key], value)
            end
          end
          eq(frame.scripts.OnUpdate, update)
          for index, group in ipairs(H.animationGroups) do
            eq(group.playCalls, plays[index])
          end
          eq(#H.widgets, widgets)
          eq(H.auraSlotCount, slots)
          for widget, count in pairs(artworkWrites) do
            eq(rawget(widget, "textureWriteCount") or 0, count)
          end
        end
      end
    end
  end)

  test("cabinet selection owns exactly one native or ordinary background across presentation transitions", function()
    local ns = loadAddon()
    ns.Config.Initialize(nil)
    ns.Machine.Initialize()
    local widgets, slots, writes = #H.widgets, H.auraSlotCount, H.textureWrites
    for _, compact in ipairs({ false, true }) do
      ns.Config.SetCompactMode(compact)
      ns.Machine.ApplyPosition()
      for _, style in ipairs(styles) do
        ns.Config.SetCabinetStyle(style)
        for _, presentation in ipairs({ "live", "active", "preview", "hidden", "active", "live" }) do
          ns.Machine.SetPresentation(presentation)
          selectionState(ns, compact, style, presentation)
          local live = presentation == "live" or presentation == "active"
          eq(H.footerSlot(compact).container.enabled, live)
          eq(H.durationSlot(compact).container.enabled, live)
          eq(H.footerSlot(not compact).container.enabled, false)
          eq(H.durationSlot(not compact).container.enabled, false)
        end
      end
    end
    eq(#H.widgets, widgets)
    eq(H.auraSlotCount, slots)
    eq(H.textureWrites, writes)
  end)

  test("combat and encounter restrictions close the cabinet menu and reject stale selections until editing resumes", function()
    for _, compact in ipairs({ false, true }) do
      for _, style in ipairs(styles) do
        local saved = { compactMode = compact, cabinetStyle = style, visibility = "active" }
        local ns = login(saved)
        local dropdown = settings()
        dropdown.menuOpen = true
        H.combat, H.playerCombat, H.restricted = true, true, true
        H.fire("PLAYER_REGEN_DISABLED")
        H.fire("ENCOUNTER_START")
        choose(dropdown, styles[2])
        eq(saved.cabinetStyle, style)
        eq(dropdown.menuOpen, false)
        H.exitEditMode()
        selectionState(ns, compact, style, "active")
        H.combat, H.playerCombat, H.restricted = false, false, false
        H.fire("PLAYER_REGEN_ENABLED")
        H.fire("ENCOUNTER_END")
        H.fire("PLAYER_LEAVING_WORLD")
        selectionState(ns, compact, style, "hidden")
        H.fire("PLAYER_ENTERING_WORLD", false, false)
        selectionState(ns, compact, style, "active")
        dropdown = settings()
        choose(dropdown, styles[3])
        eq(saved.cabinetStyle, styles[3])
        selectionState(ns, compact, styles[3], "preview")
      end
    end
  end)

  test("icon atlas packing and celebration artwork are independent of cabinet style and layout", function()
    local ns = loadAddon()
    local icons = ns.Appearance.Icons
    icons.file, icons.width, icons.height, icons.nominalSize = "fixture-icons", 2048, 1024, 192
    for index = 1, 7 do
      icons.symbols[index] = { (index - 1) * 200, 340, 168, 168 }
    end
    icons.coin = { 1500, 700, 144, 144 }
    -- Reload the renderer against this pack's contract before any native objects exist.
    assert(loadfile("src/Art.lua"))("RollTheBonesSlots", ns)
    ns.Config.Initialize(nil)
    ns.Machine.Initialize()
    local symbols, coins = 0, 0
    for _, widget in ipairs(H.widgets) do
      local file = rawget(widget, "texture")
      if file then
        assert(not file:match("symbols%.tga$"), "hard-coded icon atlas escaped the pack contract")
      end
      if file and file:match("fixture%-icons%.tga$") then
        local uv = widget.texCoords
        if uv[1] == 1500 / 2048 then
          eq(uv[2], 1644 / 2048)
          eq(uv[3], 700 / 1024)
          eq(uv[4], 844 / 1024)
          coins = coins + 1
        else
          eq(uv[3], 340 / 1024)
          eq(uv[4], 508 / 1024)
          assert(math.abs((uv[2] - uv[1]) * 2048 - 168) < 1e-8)
          assert(widget.width == 98 or widget.width == 14)
          symbols = symbols + 1
        end
      end
    end
    assert(symbols > 100)
    eq(coins, 30)
    local writes = H.textureWrites
    for _, style in ipairs(styles) do
      ns.Config.SetCabinetStyle(style)
      ns.Machine.SetPresentation("live")
      eq(ns.Appearance.Icons, icons)
      eq(H.textureWrites, writes)
    end
  end)
end

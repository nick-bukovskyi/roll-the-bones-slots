-- Authored texture placement only; native aura visibility still needs client proof
return function(test, H, loadAddon)
  local eq = H.eq
  local function CheckSymbol(texture, jackpot, nominalSize)
    local id, rect = H.symbolInfo(texture)
    assert(id, "slot symbol must use the shared atlas")
    eq(id == 5, jackpot)
    eq(texture.width, nominalSize * rect[3] / 384)
    eq(texture.height, nominalSize * rect[4] / 384)
  end

  local function VisibleSample(widget)
    local ancestor = widget
    while ancestor do
      if ancestor.kind == "AuraContainer" or ancestor.sealed or not ancestor.shown then
        return false
      end
      ancestor = ancestor.parent
    end
    -- All checks run at rest; exclude the prebuilt lanes outside the fixed well
    if widget.kind == "Texture" and widget.points.CENTER and widget.points.CENTER[2] == "CENTER" then
      local carrier = widget.parent
      while carrier and carrier.parent and not rawget(carrier.parent, "clipsChildren") do
        carrier = carrier.parent
      end
      if carrier and carrier.parent and rawget(carrier.parent, "clipsChildren") then
        return widget.points.CENTER[3] + carrier.points.CENTER[3] == 0
      end
    end
    return true
  end

  test("exclusive Jackpot die appears only at native Jackpot centers, never ordinary strip rows", function()
    local ns = loadAddon()
    ns.Config.Initialize(nil)
    ns.Machine.Initialize()
    local centers, ordinaryRows = 0, 0
    eq(#H.nativeSlots, 49)
    for index = 1, 13 do
      local slot = H.nativeSlots[index == 13 and 14 or index]
      local button = slot.button
      -- Read harness construction metadata, without invoking sealed native widgets
      if slot.key == "footer" then
        for _, child in ipairs(button.children) do
          eq(H.symbolInfo(child), nil)
        end
        local icon = button.bindings.SetIcon
        eq(rawget(icon, "texture"), nil)
        eq(icon.width, 16)
        eq(icon.height, 16)
        eq(icon.points.TOPLEFT[2], "TOPLEFT")
        eq(icon.points.TOPLEFT[3], 58)
        eq(icon.points.TOPLEFT[4], -210)
      else
        local count = 0
        for _, texture in ipairs(H.reelRegions(button)) do
          if texture.kind == "Texture" and texture.points.CENTER then
            local row = -texture.points.CENTER[4] / ns.Art.Pitch
            local jackpot = slot.filters[1214937] == true and row == 0
            eq(texture.points.CENTER[2], "CENTER")
            CheckSymbol(texture, jackpot, ns.Art.SymbolSize)
            if jackpot then
              centers = centers + 1
            else
              ordinaryRows = ordinaryRows + 1
            end
            count = count + 1
          end
        end
        eq(count, (index <= 4 and 1 or 5) * (ns.Art.SpinRows + 3))
      end
      eq(button.sealed, true)
    end
    eq(centers, 11)
    eq(ordinaryRows, 4 * 11 * (ns.Art.SpinRows + 3) - 11)

    local idleRows = 0
    for _, container in ipairs(H.containers()) do
      local carrier = container.parent
      if carrier ~= ns.Machine.GetFrame() then
        for _, texture in ipairs(H.reelRegions(carrier)) do
          if texture.kind == "Texture" and texture.points.CENTER then
            CheckSymbol(texture, false, ns.Art.SymbolSize)
            idleRows = idleRows + 1
          end
        end
      end
    end
    eq(idleRows, 11 * (ns.Art.SpinRows + 3))
  end)

  test("empty cabinet centers and visible neighboring rows contain no winning dice in either layout", function()
    local ns = loadAddon()
    ns.Config.Initialize(nil)
    ns.Machine.Initialize()
    for _, compact in ipairs({ false, true }) do
      ns.Config.SetCompactMode(compact)
      ns.Machine.ApplyPosition()
      local checked = 0
      for reel = 1, 3 do
        local carrier = H.nativeSlots[(reel - 1) * 4 + 1].container.parent
        for _, texture in ipairs(H.reelRegions(carrier)) do
          local point = texture.points.CENTER
          if point and math.abs(point[4]) <= ns.Art.Pitch then
            local id = assert(H.symbolInfo(texture))
            assert(id ~= 1 and id ~= 5, "empty reels must not imply a win, even at their edges")
            if point[4] == 0 then
              eq(id, ({ 2, 3, 4 })[reel])
            end
            checked = checked + 1
          end
        end
      end
      eq(checked, 11 * 3)
    end
  end)

  test("Triple Threat and Jackpot neighbors differ across all three reels and match their previews in both layouts", function()
    local ns = loadAddon()
    ns.Config.Initialize(nil)
    ns.Config.SetAnimationEnabled(false)
    ns.Machine.Initialize()
    ns.Machine.SetPresentation("preview")
    local function middleLane(parent)
      local rows = {}
      for _, texture in ipairs(H.reelRegions(parent)) do
        local point = texture.points.CENTER
        if point and point[3] == 0 and math.abs(point[4]) <= ns.Art.Pitch then
          rows[point[4] / ns.Art.Pitch] = assert(H.symbolInfo(texture))
        end
      end
      return rows
    end
    for _, result in ipairs({ { rank = 3, spellID = 1214935, die = 1 }, { rank = 4, spellID = 1214937, die = 5 } }) do
      ns.Machine.PreviewNext()
      for _, compact in ipairs({ false, true }) do
        ns.Config.SetCompactMode(compact)
        ns.Machine.ApplyPosition()
        local seenAbove, seenBelow = {}, {}
        for reel = 1, 3 do
          local slot = H.nativeSlots[(reel - 1) * 4 + result.rank]
          eq(slot.filters[result.spellID], true)
          local native = middleLane(slot.button)
          eq(native[0], result.die)
          assert(native[1] ~= native[-1], "a winning reel must have different neighbors above and below")
          assert(not seenAbove[native[1]] and not seenBelow[native[-1]], "matching columns must not repeat the same neighbors")
          seenAbove[native[1]], seenBelow[native[-1]] = true, true
          for _, row in ipairs({ -1, 1 }) do
            assert(native[row] ~= 1 and native[row] ~= 5, "only the center should show a winning die")
          end
          local checked = 0
          for _, child in ipairs(slot.container.parent.children) do
            if child.kind == "Frame" and child.shown then
              local sample = middleLane(child)
              if sample[0] then
                for row = -1, 1 do
                  eq(sample[row], native[row])
                end
                checked = checked + 1
              end
            end
          end
          eq(checked, 1)
        end
      end
    end
  end)

  test("preview Jackpot die is exclusive to labeled Jackpot centers and footer across every sample", function()
    local ns = loadAddon()
    ns.Config.Initialize(nil)
    ns.Machine.Initialize()
    ns.Machine.SetPresentation("preview")
    local labels = {
      ["One of a Kind"] = true,
      ["Double Trouble"] = true,
      ["Triple Threat"] = true,
      Jackpot = true,
    }
    local seen = {}
    for _ = 1, 5 do
      local name, previewLabel = nil, false
      for _, widget in ipairs(H.widgets) do
        if widget.kind == "FontString" and VisibleSample(widget) then
          local text = rawget(widget, "text")
          if labels[text] then
            assert(not name, "duplicate sample footer")
            name = text
          end
          if text == "Preview" then
            previewLabel = true
          end
        end
      end
      eq(previewLabel, false)
      local key = name or "idle"
      assert(not seen[key], "sample cycle repeated before covering all outcomes")
      seen[key] = true
      local centerCount, footerCount = 0, 0
      for _, texture in ipairs(H.widgets) do
        if texture.kind == "Texture" and VisibleSample(texture) then
          local id = H.symbolInfo(texture)
          if id then
            local point = assert(texture.points.CENTER, "authored symbols retain their visual center")
            local reel = point[2] == "CENTER"
            CheckSymbol(texture, id == 5, reel and ns.Art.SymbolSize or 16)
            if not reel then
              eq(point[2], "TOPLEFT")
              eq(point[3], 66)
              eq(point[4], -218)
            end
            if id == 5 then
              eq(name, "Jackpot")
              if reel then
                eq(point[4], 0)
                centerCount = centerCount + 1
              else
                footerCount = footerCount + 1
              end
            end
          end
        end
      end
      eq(centerCount, name == "Jackpot" and 3 or 0)
      eq(footerCount, name == "Jackpot" and 1 or 0)
      ns.Machine.PreviewNext()
      H.advance(2)
    end
    for label in pairs(labels) do
      eq(seen[label], true)
    end
    eq(seen.idle, true)
    ns.Machine.SetPresentation("live")
    for _, texture in ipairs(H.widgets) do
      if H.symbolInfo(texture) == 5 then
        eq(VisibleSample(texture), false)
      end
    end
  end)
end

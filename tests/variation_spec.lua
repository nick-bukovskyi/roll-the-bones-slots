-- Cosmetic lane choices and construction geometry, not live aura selection
return function(test, H, loadAddon)
  local eq = H.eq
  local function WithDraws(values, run)
    local original, count = math.random, 0
    math.random = function(...)
      eq(select("#", ...), 2)
      local minimum, maximum = ...
      count = count + 1
      eq(minimum, 1)
      eq(maximum, count % 2 == 1 and 5 or 4)
      local value = assert(values[count], "unexpected cosmetic random draw")
      assert(value >= minimum and value <= maximum)
      return value
    end
    local ok, failure = pcall(run, function()
      return count
    end)
    math.random = original
    if not ok then
      error(failure, 0)
    end
    eq(count, #values)
  end

  local function Login(saved)
    local ns = loadAddon(saved)
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.loggedIn = true
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
  end

  local function Carriers(ns)
    local found = {}
    for _, container in ipairs(H.containers()) do
      if container.slots.result1 then
        found[#found + 1] = container.parent
      end
    end
    eq(#found, 3)
    return found
  end

  local function Selection(ns, pair, settled)
    local moving = Carriers(ns)
    for index, carrier in ipairs(moving) do
      local variant = index == 1 and 1 or pair[index - 1]
      local point = carrier.points.CENTER
      eq(point[1], carrier.parent)
      eq(point[2], "CENTER")
      eq(point[3], -(variant - 1) * ns.Art.LanePitch)
      if settled then
        eq(point[4], 0)
      end
    end
    assert(pair[1] ~= pair[2])
    if settled then
      eq(ns.Machine.GetFrame().scripts.OnUpdate, nil)
    end
    return moving
  end

  local function Cast(guid, unit, spell)
    H.fire("UNIT_SPELLCAST_SUCCEEDED", unit or "player", guid, spell or 1214909)
  end

  local function CenterSymbol(parent, x)
    local found
    for _, texture in ipairs(H.reelRegions(parent)) do
      local point = texture.kind == "Texture" and texture.points.CENTER
      if point and point[3] == x and point[4] == 0 then
        assert(not found, "duplicate lane center")
        eq(point[2], "CENTER")
        found = assert(H.symbolInfo(texture), "slot symbol must use the shared atlas")
      end
    end
    return assert(found, "missing lane center")
  end

  test("all seven reel sprites and the celebration coin are centered inside isolated atlas cells", function()
    local ns = loadAddon()
    local file = assert(io.open("public/art/symbols.tga", "rb"))
    local pixels = file:read("*a")
    file:close()
    eq(pixels:sub(1, 3), "\0\0\2")
    eq(pixels:byte(17), 32)
    eq(pixels:byte(18), 40)
    eq(pixels:byte(13) + pixels:byte(14) * 256, 1024)
    eq(pixels:byte(15) + pixels:byte(16) * 256, 1024)
    eq(#pixels, 18 + 1024 * 1024 * 4)
    local parent = CreateFrame("Frame", nil, UIParent)
    for symbol = 1, 8 do
      local rect = { 336, 672, 336, 336 }
      if symbol <= 7 then
        local id
        id, rect = H.symbolInfo(ns.Art.Symbol(parent, symbol, 112))
        eq(id, symbol)
      end
      local left, top = rect[1] + rect[3], rect[2] + rect[4]
      local right, bottom = -1, -1
      for y = rect[2], rect[2] + rect[4] - 1 do
        for x = rect[1], rect[1] + rect[3] - 1 do
          if pixels:byte(18 + (y * 1024 + x) * 4 + 4) > 8 then
            left, top = math.min(left, x), math.min(top, y)
            right, bottom = math.max(right, x), math.max(bottom, y)
          end
        end
      end
      assert(right >= left and bottom >= top, "missing painted sprite " .. symbol)
      assert(left >= rect[1] + 16 and top >= rect[2] + 16, "sprite needs transparent top/left gutters")
      assert(right < rect[1] + rect[3] - 16 and bottom < rect[2] + rect[4] - 16, "sprite needs transparent bottom/right gutters")
      assert(math.abs((left + right + 1) / 2 - (rect[1] + rect[3] / 2)) <= 1, "painted sprite is off-center horizontally")
      assert(math.abs((top + bottom + 1) / 2 - (rect[2] + rect[4] / 2)) <= 1, "painted sprite is off-center vertically")
    end
  end)

  test("all twenty cosmetic pairs preserve exact native rank dice counts without artwork writes", function()
    local draws = {}
    for first = 1, 5 do
      for second = 1, 4 do
        draws[#draws + 1] = first
        draws[#draws + 1] = second
      end
    end
    WithDraws(draws, function(drawCount)
      local ns = Login()
      eq(table.concat(ns.Art.VariantSymbols, ","), "2,3,4,6,7")
      Selection(ns, { 1, 2 }, true)
      eq(drawCount(), 0)
      local alpha, writes, widgets, points = #H.alphaWrites, H.textureWrites, #H.widgets, #H.pointWrites
      local coins = {}
      for _, animation in ipairs(H.animationGroups[5].animations) do
        if animation.kind == "Rotation" then
          coins[animation.target] = true
        end
      end
      local cases = {
        { 1, 2 }, { 1, 3 }, { 1, 4 }, { 1, 5 },
        { 2, 1 }, { 2, 3 }, { 2, 4 }, { 2, 5 },
        { 3, 1 }, { 3, 2 }, { 3, 4 }, { 3, 5 },
        { 4, 1 }, { 4, 2 }, { 4, 3 }, { 4, 5 },
        { 5, 1 }, { 5, 2 }, { 5, 3 }, { 5, 4 },
      }
      for attempt, pair in ipairs(cases) do
        Cast("pair" .. attempt)
        Selection(ns, pair)
        local expected = {
          { 1, ns.Art.VariantSymbols[pair[1]], ns.Art.VariantSymbols[pair[2]] },
          { 1, 1, ns.Art.VariantSymbols[pair[2]] },
          { 1, 1, 1 },
          { 5, 5, 5 },
        }
        for rank = 1, 4 do
          local ordinaryDice, jackpotDice = 0, 0
          for reel = 1, 3 do
            local variant = reel == 1 and 1 or pair[reel - 1]
            local slot = H.nativeSlots[(reel - 1) * 4 + rank]
            eq(slot.button.sealed, true)
            local symbol = CenterSymbol(slot.button, (variant - 1) * ns.Art.LanePitch)
            eq(symbol, expected[rank][reel])
            ordinaryDice = ordinaryDice + (symbol == 1 and 1 or 0)
            jackpotDice = jackpotDice + (symbol == 5 and 1 or 0)
          end
          eq(ordinaryDice, rank == 4 and 0 or rank)
          eq(jackpotDice, rank == 4 and 3 or 0)
        end
        H.advance(0.8)
        H.fire("SPELLS_CHANGED")
        Selection(ns, pair)
        eq(drawCount(), attempt * 2)
        H.advance(0.8)
        Selection(ns, pair, true)
      end
      for index = alpha + 1, #H.alphaWrites do
        assert(coins[H.alphaWrites[index].object], "only ordinary coin carriers may fade during the celebration")
      end
      eq(H.textureWrites, writes)
      eq(#H.widgets, widgets)
      local moving = Carriers(ns)
      for index = points + 1, #H.pointWrites do
        local target = H.pointWrites[index]
        assert(target == moving[1] or target == moving[2] or target == moving[3] or coins[target])
      end
      eq(H.auraSlotCount, 49)
    end)
  end)

  test("reduced motion still chooses variants while duplicate or unreadable casts do not", function()
    WithDraws({ 3, 2, 1, 2, 2, 1 }, function(drawCount)
      local ns = Login({ animationEnabled = false })
      Cast(H.secret, H.secret, H.secret)
      Cast("other-unit", "party1")
      Cast("other-spell", "player", 315508)
      eq(drawCount(), 0)
      Selection(ns, { 1, 2 }, true)
      Cast("first")
      Selection(ns, { 3, 2 }, true)
      eq(drawCount(), 2)
      Cast("first")
      H.fire("SPELLS_CHANGED")
      Selection(ns, { 3, 2 }, true)
      eq(drawCount(), 2)
      -- A secret GUID is opaque, but readable unit/spell still permits cosmetics
      Cast(H.secret)
      Selection(ns, { 1, 3 }, true)
      UIParent:Hide()
      Cast("hidden")
      eq(drawCount(), 4)
      UIParent:Show()
      Selection(ns, { 1, 3 }, true)
      Cast("visible-again")
      Selection(ns, { 2, 1 }, true)
    end)
  end)

  test("repeat spins, stop, hidden UI and restriction recovery preserve the latest live pair", function()
    WithDraws({ 2, 2, 3, 1, 1, 1 }, function(drawCount)
      local ns = Login()
      Cast("first")
      H.advance(0.9)
      Cast("replacement")
      local moving = Selection(ns, { 3, 1 })
      for _, carrier in ipairs(moving) do
        eq(carrier.points.CENTER[4], ns.Art.SpinRows * ns.Art.Pitch)
      end
      H.advance(0.4)
      ns.Machine.StopSpin()
      Selection(ns, { 3, 1 }, true)
      UIParent:Hide()
      Selection(ns, { 3, 1 }, true)
      UIParent:Show()
      H.fire("SPELLS_CHANGED")
      Selection(ns, { 3, 1 }, true)
      H.combat, H.restricted = true, true
      H.fire("PLAYER_REGEN_DISABLED")
      H.fire("ENCOUNTER_START")
      Selection(ns, { 3, 1 }, true)
      eq(drawCount(), 4)
      H.combat, H.restricted = false, false
      H.fire("PLAYER_REGEN_ENABLED")
      Selection(ns, { 3, 1 }, true)
      eq(drawCount(), 4)
      Cast("next")
      H.advance(2)
      Selection(ns, { 1, 2 }, true)
      eq(rawget(RollTheBonesSlotsDB, "variant"), nil)
      eq(rawget(RollTheBonesSlotsDB, "previewVariant"), nil)
    end)
  end)

  test("editor test spins retain a separate pair and restore the live pair on exit", function()
    WithDraws({ 3, 2, 2, 2, 1, 2 }, function(drawCount)
      local ns = Login()
      Cast("live")
      H.advance(2)
      Selection(ns, { 3, 2 }, true)
      H.enterEditMode()
      Selection(ns, { 1, 2 }, true)
      local selection = H.findTemplate("EditModeSystemSelectionTemplate")
      selection.scripts.OnMouseDown(selection)
      H.button("Test spin").scripts.OnClick()
      H.advance(2)
      Selection(ns, { 2, 3 }, true)
      H.exitEditMode()
      Selection(ns, { 3, 2 }, true)
      H.enterEditMode()
      Selection(ns, { 2, 3 }, true)
      eq(drawCount(), 4)
      selection.scripts.OnMouseDown(selection)
      local animation = H.checkbox("Animate reels and wins")
      animation:SetChecked(false)
      animation.scripts.OnClick(animation)
      H.button("Test spin").scripts.OnClick()
      Selection(ns, { 1, 3 }, true)
      H.exitEditMode()
      Selection(ns, { 3, 2 }, true)
    end)
  end)

  test("symbol-only lanes stay outside neighboring selected viewports", function()
    WithDraws({}, function()
      local ns = Login()
      eq(ns.Art.LanePitch, 128)
      eq(ns.Art.SymbolSize, 112)
      local parents = {}
      for index = 1, 12 do
        local slot = H.nativeSlots[index]
        parents[#parents + 1] = { object = slot.button, lanes = index <= 4 and 1 or 5 }
      end
      for index, carrier in ipairs(Carriers(ns)) do
        parents[#parents + 1] = { object = carrier, lanes = index == 1 and 1 or 5 }
      end
      for _, entry in ipairs(parents) do
        local parent, count = entry.object, 0
        for _, region in ipairs(H.reelRegions(parent)) do
          if region.kind == "Texture" then
            local center = assert(region.points.CENTER, "only symbols belong on moving carriers")
            eq(center[2], "CENTER")
            local laneX = center[3]
            local left = parent.width / 2 + laneX - region.width / 2
            local id, rect = H.symbolInfo(region)
            assert(id, "slot symbol must use the shared atlas")
            eq(region.width, ns.Art.SymbolSize * rect[3] / 384)
            eq(region.height, ns.Art.SymbolSize * rect[4] / 384)
            local lane = laneX / ns.Art.LanePitch + 1
            eq(lane, math.floor(lane))
            assert(lane >= 1 and lane <= entry.lanes)
            for selected = 1, entry.lanes do
              if selected ~= lane then
                local shifted = left - (selected - 1) * ns.Art.LanePitch
                assert(
                  shifted + region.width <= 0 or shifted >= parent.width,
                  "neighboring lane texture can bleed through the fixed viewport"
                )
              end
            end
            count = count + 1
          end
        end
        eq(count, entry.lanes * (ns.Art.SpinRows + 3))
      end
    end)
  end)
end

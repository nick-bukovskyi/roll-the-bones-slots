-- Construction and lifecycle contracts, not native aura or combat rendering proof
return function(test, H, loadAddon)
  local eq = H.eq
  local function login()
    local ns = loadAddon()
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.loggedIn = true
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
  end
  local function cast(guid)
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, 1214909)
  end
  local function targets(group)
    local found, seen = {}, {}
    for _, animation in ipairs(group.animations) do
      if not seen[animation.target] then
        seen[animation.target] = true
        found[#found + 1] = animation.target
      end
    end
    return found
  end
  local function clip(widget)
    while widget do
      if rawget(widget, "clipsChildren") then
        return widget
      end
      widget = widget.parent
    end
  end
  local function preview(owner)
    for _, child in ipairs(owner.children) do
      if child.kind == "Frame" then
        return child
      end
    end
    error("missing light preview")
  end
  local function quiet()
    for index, group in ipairs(H.animationGroups) do
      eq(group.playing, false)
      eq(group.parent:GetAlpha(), 1)
      for _, owner in ipairs(targets(group)) do
        eq(owner:GetAlpha(), index <= 4 and 0.23 or 0)
        if index == 5 and owner.points.CENTER then
          eq(owner.parent.scripts.OnUpdate, nil)
          eq(owner.points.CENTER[4], 0)
        end
      end
    end
  end
  local function selectCabinet()
    H.enterEditMode()
    local selection = H.findTemplate("EditModeSystemSelectionTemplate")
    selection.scripts.OnMouseDown(selection)
  end
  local function click(label)
    local button = H.button(label)
    button.scripts.OnClick(button)
  end
  local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-9, "unexpected animation duration")
  end

  test("native and preview glows persist only behind winning columns below the symbols", function()
    local ns = login()
    eq(#H.nativeSlots, 49)
    eq(#H.animationGroups, 5)
    for _, slot in ipairs(H.nativeSlots) do
      eq(next(slot.button.scripts), nil)
      eq(rawget(slot.button, "animationGroups"), nil)
      eq(rawget(slot, "templateNames"), nil)
      eq(slot.button.sealed, true)
    end
    for rank = 1, 4 do
      local group = H.animationGroups[rank]
      eq(group.parent, ns.Machine.GetFrame())
      local owners = targets(group)
      eq(#owners, rank == 4 and 3 or rank)
      for reel, owner in ipairs(owners) do
        local well, slot = owner.parent
        eq(clip(owner), well)
        eq(owner:GetAlpha(), 0.23)
        eq(owner.points.CENTER[1], well)
        eq(owner.points.CENTER[4], 0)
        eq(well.points.TOPLEFT[3], ({ 37, 148, 260 })[reel])
        eq(well.points.TOPLEFT[4], -39)
        for _, candidate in ipairs(H.nativeSlots) do
          if candidate.key == "win" and candidate.container.parent == owner then
            assert(not slot)
            slot = candidate
          end
        end
        assert(slot)
        eq(slot.button.mouse, false)
        local count = 0
        for spellID in pairs(slot.filters) do
          eq(spellID, ns.Game.Results[rank].spellID)
          count = count + 1
        end
        eq(count, 1)
        eq(preview(owner).shown, false)
        for _, artwork in ipairs({ slot.button, preview(owner) }) do
          eq(artwork.width, well.width)
          eq(artwork.height, well.height)
          eq(#artwork.children, 1)
          local light = artwork.children[1]
          eq(clip(light), well)
          eq(light.width, reel == 1 and 104 or 103)
          eq(light.height, 153)
          eq(light.allPoints, artwork)
          near(light.alpha, 1)
          eq(#light.children, 2)
          for _, texture in ipairs(light.children) do
            eq(rawget(texture, "texture"), nil)
            eq(texture.blendMode, "ADD")
            eq(texture.width, light.width)
            eq(texture.height, light.height / 2)
            assert(rawget(texture, "gradient"))
          end
          for index = (reel - 1) * 4 + 1, reel * 4 do
            local button = H.nativeSlots[index].button
            eq(clip(button), well)
            assert(button.frameLevel < light.frameLevel, "backing would hide the light")
            for _, region in ipairs(H.reelRegions(button)) do
              if region.drawLayer == "ARTWORK" then
                assert(region.parent.frameLevel > light.frameLevel, "a flash would cover a result symbol")
                eq(region.parent.parent, button)
                if region.points.CENTER[4] == 0 then
                  eq(region.alpha, 1)
                end
              end
            end
          end
          local sampleSymbols = 0
          for _, widget in ipairs(H.widgets) do
            if
              widget.kind == "Texture"
              and widget.points.CENTER
              and widget.points.CENTER[4] == 0
              and rawget(widget, "alpha") == 1
              and clip(widget) == well
              and not widget.parent.parent.sealed
            then
              assert(widget.parent.frameLevel > light.frameLevel, "a flash would cover a preview symbol")
              sampleSymbols = sampleSymbols + 1
            end
          end
          assert(sampleSymbols > 0)
        end
      end
      eq(next(group.scripts), nil)
      eq(rawget(group, "template"), nil)
      eq(group.looping, "NONE")
      eq(group.toFinalAlpha, true)
      for _, owner in ipairs(owners) do
        eq(owner.kind, "Frame")
        eq(owner.sealed, false)
      end
    end
  end)

  test("winning columns bloom once at landing and settle into a steady highlight", function()
    login()
    for rank = 1, 4 do
      local group = H.animationGroups[rank]
      for _, owner in ipairs(targets(group)) do
        local duration, rises, holds, order = 0, {}, {}, 0
        local finalAlpha
        for _, animation in ipairs(group.animations) do
          if animation.target == owner then
            order = order + 1
            eq(animation.order, order)
            near(animation.startDelay, 0)
            if order == 1 then
              near(animation.duration, 1.5)
              eq(animation.fromAlpha, 0)
              eq(animation.toAlpha, 0)
            end
            duration = duration + animation.startDelay + animation.duration
            finalAlpha = animation.toAlpha
            if animation.toAlpha > animation.fromAlpha then
              rises[#rises + 1] = animation
            elseif animation.toAlpha == animation.fromAlpha and animation.toAlpha > 0 then
              holds[#holds + 1] = animation
            end
          end
        end
        eq(#rises, 1)
        eq(#holds, 0)
        near(duration, rank == 4 and 2.6 or 2.2)
        eq(finalAlpha, 0.23)
      end
    end
  end)

  test("Jackpot coins launch across the title or compact top rail through native-only result filters", function()
    local ns = login()
    local group = H.animationGroups[5]
    local owners = targets(group)
    eq(#owners, 16)
    assert(group.scripts.OnPlay and group.scripts.OnStop and group.scripts.OnFinished)
    for _, compact in ipairs({ false, true }) do
      ns.Config.SetCompactMode(compact)
      ns.Machine.ApplyPosition()
      local coins, banners, minimumX, maximumX, seenX = 0, 0, math.huge, -math.huge, {}
      for _, owner in ipairs(owners) do
        eq(clip(owner), nil)
        eq(owner:GetAlpha(), 0)
        local slot
        for _, candidate in ipairs(H.nativeSlots) do
          if candidate.container.parent == owner then
            assert(not slot)
            slot = candidate
          end
        end
        assert(slot)
        eq(slot.button.sealed, true)
        eq(slot.button.mouse, false)
        eq(slot.filters[1214937], true)
        local count = 0
        for _ in pairs(slot.filters) do
          count = count + 1
        end
        eq(count, 1)
        local artwork = slot.button.children[1]
        if artwork.kind == "Texture" then
          coins = coins + 1
          eq(H.symbolInfo(artwork), nil)
          local uv = artwork.texCoords
          eq(uv[1] * 1024, 336)
          eq(uv[2] * 1024, 672)
          eq(uv[3] * 1024, 672)
          eq(uv[4] * 1024, 1008)
          local rect = H.frameRect(owner, ns.Machine.GetFrame())
          local cx, cy = rect.x + rect.width / 2, rect.y + rect.height / 2
          near(cy, compact and 11 or 20)
          assert(not seenX[cx], "coins should launch from distinct places across the title")
          seenX[cx] = true
          minimumX, maximumX = math.min(minimumX, cx), math.max(maximumX, cx)
          local rotation
          for _, animation in ipairs(group.animations) do
            if animation.target == owner then
              eq(animation.kind, "Rotation")
              rotation = animation
            end
          end
          assert(rotation)
          eq(rotation.order, 3)
          eq(rotation.smoothing, "NONE")
          assert(rotation.degrees ~= 0)
        else
          banners = banners + 1
          eq(artwork.kind, "FontString")
          eq(artwork.text, "JACKPOT")
          local rect = H.frameRect(owner, ns.Machine.GetFrame())
          near(rect.x + rect.width / 2, 200)
          assert(rect.y + rect.height < 0, "Jackpot label belongs above the whole board")
        end
      end
      eq(coins, 15)
      eq(banners, 1)
      assert(minimumX <= 70 and maximumX >= 330, "launch points must span the title row")
    end
    cast("plunder")
    near(group.finishAt, H.clock + 3.382)
    H.advance(3.4)
    quiet()
  end)

  test("coin flight has constant gravity, varied launches and no fade at its apex", function()
    local ns = login()
    local owners = targets(H.animationGroups[5])
    for _, compact in ipairs({ false, true }) do
      ns.Config.SetCompactMode(compact)
      ns.Machine.ApplyPosition()
      cast("gravity" .. tostring(compact))
      H.advance(1.56)
      for index = 1, 15 do
        eq(owners[index]:GetAlpha(), 0)
        near(owners[index].points.CENTER[4], 0)
      end
      H.advance(0.08)
      local launched = 0
      for index = 1, 15 do
        launched = launched + (owners[index]:GetAlpha() > 0 and 1 or 0)
      end
      assert(launched > 0 and launched < 15, "coins should leave in a short staggered burst")
      H.advance(0.18)
      local samples = {}
      for step = 1, 3 do
        samples[step] = {}
        for index = 1, 15 do
          local owner = owners[index]
          samples[step][index] = { owner.points.CENTER[3], owner.points.CENTER[4] }
          near(owner:GetAlpha(), 1)
        end
        H.advance(0.1)
      end
      local acceleration, rises = nil, {}
      for index = 1, 15 do
        local a, b, c = samples[1][index], samples[2][index], samples[3][index]
        near(c[1] - b[1], b[1] - a[1])
        local ay = c[2] - 2 * b[2] + a[2]
        assert(ay < 0 and b[2] > a[2], "gravity must slow an initially upward flight")
        acceleration = acceleration or ay
        near(ay, acceleration)
        rises[b[2] - a[2]] = true
      end
      local unique = 0
      for _ in pairs(rises) do
        unique = unique + 1
      end
      assert(unique >= 10, "coins must not move as one uniform sheet")
      H.advance(0.85)
      local faded = 0
      for index = 1, 15 do
        local owner = owners[index]
        local rect = H.frameRect(owner, ns.Machine.GetFrame())
        local y = rect.y + rect.height / 2
        if y <= (compact and 140 or 246) then
          near(owner:GetAlpha(), 1)
        end
        faded = faded + (owner:GetAlpha() < 1 and 1 or 0)
        assert(owner.points.CENTER[4] < 0, "coins must fall below their launch row")
      end
      assert(faded > 0, "coins should fade as they leave below the cabinet")
      H.advance(0.45)
      quiet()
    end
  end)

  test("coin positions are independent of frame rate and restart cleanly", function()
    local ns = login()
    local owners = targets(H.animationGroups[5])
    local expected = {}
    for run, delta in ipairs({ 1 / 30, 1 / 144, 2.5 }) do
      cast("frame-rate" .. run)
      local remaining = 2.5
      while remaining > 1e-10 do
        local step = math.min(delta, remaining)
        H.advance(step)
        remaining = remaining - step
      end
      for index = 1, 15 do
        local point = owners[index].points.CENTER
        if run == 1 then
          expected[index] = { point[3], point[4] }
        else
          near(point[3], expected[index][1])
          near(point[4], expected[index][2])
        end
      end
      ns.Machine.StopSpin()
      quiet()
    end
  end)

  test("animations-off preserves only the selected steady preview glow and keeps coins hidden", function()
    local ns = login()
    ns.Config.SetAnimationEnabled(false)
    ns.Machine.SetPresentation("preview")
    for _, expected in ipairs({ 3, 4, 5, 1, 2 }) do
      ns.Machine.PreviewNext()
      for index, group in ipairs(H.animationGroups) do
        eq(group.playCalls, 0)
        for _, owner in ipairs(targets(group)) do
          local shown = preview(owner).shown
          eq(shown, (index <= 4 and index or 4) == expected)
          eq(owner:GetAlpha(), index <= 4 and 0.23 or 0)
        end
      end
      eq(ns.Machine.GetFrame().scripts.OnUpdate, nil)
    end
    ns.Config.SetAnimationEnabled(true)
    ns.Machine.PreviewNext() -- Triple Threat
    eq(H.animationGroups[3].playing, true)
    eq(H.animationGroups[5].playing, false)
    ns.Machine.PreviewNext() -- Jackpot
    eq(H.animationGroups[4].playing, true)
    eq(H.animationGroups[5].playing, true)
    H.advance(0.4)
    ns.Machine.PreviewNext() -- Empty
    quiet()
    for _, owner in ipairs(targets(H.animationGroups[5])) do
      eq(preview(owner).shown, false)
    end
    ns.Machine.SetPresentation("live")
    quiet()
  end)

  test("each readable Roll starts all native timelines once without result or refresh detection", function()
    local ns = login()
    quiet()
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "other", 1214909)
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "extension", 381989)
    H.fire("UNIT_SPELLCAST_FAILED", "player", "failed", 1214909)
    H.fire("UNIT_SPELLCAST_SUCCEEDED", H.secret, H.secret, H.secret)
    H.fire("UNIT_AURA", "player", H.secret)
    for _, group in ipairs(H.animationGroups) do
      eq(group.playCalls, 0)
    end
    cast("first")
    H.advance(0.7)
    cast("first")
    for _, group in ipairs(H.animationGroups) do
      eq(group.playCalls, 1)
    end
    H.advance(0.81)
    eq(ns.Machine.GetFrame().scripts.OnUpdate, nil)
    for _, group in ipairs(H.animationGroups) do
      eq(group.playing, true)
    end
    H.fire("UNIT_AURA", "player", H.secret)
    H.fire("SPELLS_CHANGED")
    H.fire("TRAIT_CONFIG_UPDATED")
    for _, group in ipairs(H.animationGroups) do
      eq(group.playCalls, 1)
      eq(group.playing, true)
    end
    -- No aura transition is needed, so a same-rank reroll follows the same cast path
    cast("reroll")
    for rank, group in ipairs(H.animationGroups) do
      eq(group.playCalls, 2)
      near(group.finishAt, H.clock + ({ 2.2, 2.2, 2.2, 2.6, 3.382 })[rank])
    end
    H.advance(3.4)
    quiet()
    local widgets, textures, hooks = #H.widgets, H.textureWrites, H.hookCount
    for index = 1, 20 do
      cast("repeat" .. index)
      H.advance(3.4)
    end
    eq(#H.widgets, widgets)
    eq(H.textureWrites, textures)
    eq(H.hookCount, hooks)
    eq(#H.timers, 0)
    eq(#H.nativeSlots, 49)
    quiet()
  end)

  test("preview picks one timeline and reset or reduced motion cancels pending lights", function()
    local ns = login()
    selectCabinet()
    quiet()
    click("Test spin")
    for index, group in ipairs(H.animationGroups) do
      eq(group.playing, index == 3)
    end
    H.advance(0.2)
    click("Reset to Defaults")
    quiet()
    eq(ns.Machine.GetFrame().scripts.OnUpdate, nil)
    click("Test spin")
    H.advance(1.7)
    for _, owner in ipairs(targets(H.animationGroups[4])) do
      owner:SetAlpha(0.8)
    end
    local animation = H.checkbox("Animate reels and wins")
    animation:SetChecked(false)
    animation.scripts.OnClick(animation)
    quiet()
    animation:SetChecked(true)
    animation.scripts.OnClick(animation)
    quiet()
    click("Test spin")
    quiet() -- Idle sample has no winning artwork or timeline
    click("Test spin")
    assert(H.animationGroups[1].playing)
    H.exitEditMode()
    quiet()
    eq(ns.Config.GetAnimationEnabled(), true)
  end)

  test("interruption cancels every light and restoration does not replay it", function()
    local cases = {
      {
        function()
          UIParent:Hide()
        end,
        function()
          UIParent:Show()
        end,
      },
      {
        function()
          H.fire("PLAYER_LEAVING_WORLD")
        end,
        function()
          H.fire("PLAYER_ENTERING_WORLD")
        end,
      },
      {
        function()
          H.fire("PLAYER_DEAD")
        end,
        function()
          H.fire("PLAYER_ALIVE")
        end,
      },
      {
        function()
          H.combat = true
          H.fire("PLAYER_REGEN_DISABLED")
        end,
        function()
          H.combat = false
          H.fire("PLAYER_REGEN_ENABLED")
        end,
      },
      {
        function()
          H.fire("PLAY_MOVIE")
        end,
        function()
          H.fire("STOP_MOVIE")
        end,
      },
      {
        function()
          H.cinematic = true
          H.fire("CINEMATIC_START")
        end,
        function()
          H.cinematic = false
          H.fire("CINEMATIC_STOP")
        end,
      },
      {
        function()
          H.petBattle = true
          H.fire("PET_BATTLE_OPENING_START")
        end,
        function()
          H.petBattle = false
          H.fire("PET_BATTLE_CLOSE")
        end,
      },
      {
        function()
          H.spec = 259
          H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        end,
        function()
          H.spec = 260
          H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        end,
      },
      {
        function()
          H.known = false
          H.fire("SPELLS_CHANGED")
        end,
        function()
          H.known = true
          H.fire("SPELLS_CHANGED")
        end,
      },
      { H.enterEditMode, H.exitEditMode },
    }
    for _, transition in ipairs(cases) do
      login()
      cast("before")
      H.advance(1.7)
      for _, group in ipairs(H.animationGroups) do
        for _, owner in ipairs(targets(group)) do
          owner:SetAlpha(0.7)
        end
      end
      transition[1]()
      quiet()
      transition[2]()
      quiet()
      for _, group in ipairs(H.animationGroups) do
        eq(group.playCalls, 1)
      end
      cast("after")
      for _, group in ipairs(H.animationGroups) do
        eq(group.playCalls, 2)
      end
    end
  end)
end

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
    for _, group in ipairs(H.animationGroups) do
      eq(group.playing, false)
      eq(group.parent:GetAlpha(), 1)
      for _, owner in ipairs(targets(group)) do
        eq(owner:GetAlpha(), 0)
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

  test("native and preview flashes light only winning columns below the symbols", function()
    local ns = login()
    eq(#H.nativeSlots, 33)
    eq(#H.animationGroups, 4)
    for _, slot in ipairs(H.nativeSlots) do
      eq(next(slot.button.scripts), nil)
      eq(rawget(slot.button, "animationGroups"), nil)
      eq(rawget(slot, "templateNames"), nil)
      eq(slot.button.sealed, true)
    end
    for rank, group in ipairs(H.animationGroups) do
      eq(group.parent, ns.Machine.GetFrame())
      local owners = targets(group)
      eq(#owners, rank == 4 and 3 or rank)
      for reel, owner in ipairs(owners) do
        local well, slot = owner.parent
        eq(clip(owner), well)
        eq(owner:GetAlpha(), 0)
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
          near(light.alpha, rank == 4 and 0.88 or 0.58)
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

  test("normal and Jackpot pulse schedules begin at landing and finish transparent", function()
    login()
    for rank, group in ipairs(H.animationGroups) do
      for _, owner in ipairs(targets(group)) do
        local duration, rises, holds, order = 0, {}, {}, 0
        local finalAlpha
        for _, animation in ipairs(group.animations) do
          if animation.target == owner then
            order = order + 1
            eq(animation.order, order)
            near(animation.startDelay, order == 1 and 1.5 or 0)
            duration = duration + animation.startDelay + animation.duration
            finalAlpha = animation.toAlpha
            if animation.toAlpha > animation.fromAlpha then
              rises[#rises + 1] = animation
            elseif animation.toAlpha == animation.fromAlpha and animation.toAlpha > 0 then
              holds[#holds + 1] = animation
            end
          end
        end
        eq(#rises, rank == 4 and 3 or 2)
        eq(#holds, #rises)
        near(duration, rank == 4 and 3.11 or 2.46)
        eq(finalAlpha, 0)
        if rank == 4 then
          assert(rises[1].toAlpha < rises[2].toAlpha and rises[2].toAlpha < rises[3].toAlpha)
          assert(holds[3].duration > holds[1].duration and holds[3].duration > holds[2].duration)
        end
      end
    end
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
      near(group.finishAt, H.clock + (rank == 4 and 3.11 or 2.46))
    end
    H.advance(3.2)
    quiet()
    local widgets, textures, hooks = #H.widgets, H.textureWrites, H.hookCount
    for index = 1, 20 do
      cast("repeat" .. index)
      H.advance(3.2)
    end
    eq(#H.widgets, widgets)
    eq(H.textureWrites, textures)
    eq(H.hookCount, hooks)
    eq(#H.timers, 0)
    eq(#H.nativeSlots, 33)
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

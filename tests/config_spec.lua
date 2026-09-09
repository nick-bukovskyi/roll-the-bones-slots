return function(test, ns, harness)
  local Config = ns.Config
  local eq = harness.eq

  test("first load creates conservative account-wide defaults", function()
    local root = Config.Initialize(nil)
    eq(_G.RollTheBonesSlotsDB, root)
    eq(root.schemaVersion, 3)
    eq(Config.GetScale(), 1)
    local x, y = Config.GetPosition()
    eq(x, 0)
    eq(y, 140)
    eq(Config.GetAnimationEnabled(), true)
    eq(Config.GetCompactMode(), false)
    eq(Config.IsReadOnly(), false)
  end)

  test("initialization preserves player choices and unrelated saved data", function()
    local unknown = { retained = true }
    local root = {
      schemaVersion = 1,
      scale = 1.25,
      x = -73.5,
      y = 40.75,
      animationEnabled = false,
      extra = unknown,
    }
    eq(Config.Initialize(root), root)
    eq(Config.GetScale(), 1.25)
    local x, y = Config.GetPosition()
    eq(x, -73.5)
    eq(y, 40.75)
    eq(Config.GetAnimationEnabled(), false)
    eq(root.extra, unknown)
    eq(Config.Initialize(root), root)
    eq(root.extra, unknown)
    eq(root.animationEnabled, false)
  end)

  test("unversioned preferences gain missing fields without replacing valid fields", function()
    local root = { scale = 0.75, x = 85, animationEnabled = false, extra = "preserved" }
    Config.Initialize(root)
    eq(root.schemaVersion, 3)
    eq(root.scale, 0.75)
    eq(root.x, 85)
    eq(root.y, 140)
    eq(root.animationEnabled, false)
    eq(root.extra, "preserved")
  end)

  test("corrupt fields recover individually", function()
    local root = {
      schemaVersion = "invalid",
      scale = 9,
      x = 90.25,
      y = math.huge,
      animationEnabled = "false",
      extra = "preserved",
    }
    Config.Initialize(root)
    eq(root.schemaVersion, 3)
    eq(root.scale, 1)
    eq(root.x, 90.25)
    eq(root.y, 140)
    eq(root.animationEnabled, true)
    eq(root.extra, "preserved")
  end)

  test("invalid roots and secret fields never become persisted preferences", function()
    for _, invalid in ipairs({ false, 42, "invalid", harness.secret }) do
      local root = Config.Initialize(invalid)
      eq(type(root), "table")
      eq(root.scale, 1)
      eq(root.schemaVersion, 3)
    end
    local root = Config.Initialize({
      schemaVersion = harness.secret,
      scale = harness.secret,
      x = harness.secret,
      y = 12,
      animationEnabled = harness.secret,
    })
    eq(root.schemaVersion, 3)
    eq(root.scale, 1)
    eq(root.x, 0)
    eq(root.y, 12)
    eq(root.animationEnabled, true)
  end)

  test("scale edits clamp to the supported bounds and reject invalid input without mutation", function()
    local root = Config.Initialize(nil)
    eq(Config.SetScale(0.1), true)
    eq(Config.GetScale(), 0.1)
    eq(Config.SetScale(1.8), true)
    eq(Config.GetScale(), 1.8)
    for _, entry in ipairs({ { 0.09, 0.1 }, { 0.59, 0.59 }, { 1.81, 1.8 }, { -100, 0.1 }, { 999, 1.8 } }) do
      eq(Config.SetScale(entry[1]), true)
      eq(root.scale, entry[2])
    end
    for _, invalid in ipairs({
      0 / 0,
      math.huge,
      -math.huge,
      "1",
      false,
      {},
      harness.secret,
    }) do
      eq(Config.SetScale(invalid), false)
      eq(root.scale, 1.8)
    end
    eq(Config.SetScale(nil), false)
    eq(root.scale, 1.8)
  end)

  test("position updates preserve fractions and reject a partial invalid move atomically", function()
    local root = Config.Initialize(nil)
    eq(Config.SetPosition(-12.25, 37.5), true)
    for _, invalid in ipairs({
      0 / 0,
      math.huge,
      -math.huge,
      "3",
      false,
      {},
      harness.secret,
    }) do
      eq(Config.SetPosition(invalid, 1), false)
      eq(Config.SetPosition(1, invalid), false)
      eq(root.x, -12.25)
      eq(root.y, 37.5)
    end
    eq(Config.SetPosition(nil, 1), false)
    eq(Config.SetPosition(1, nil), false)
    local x, y = Config.GetPosition()
    eq(x, -12.25)
    eq(y, 37.5)
  end)

  test("compact migration preserves existing preferences and validates the new field independently", function()
    for _, version in ipairs({ 1, 2, 3 }) do
      for _, value in ipairs({ true, false, "true", 0, {}, harness.secret }) do
        local root = {
          schemaVersion = version,
          scale = 0.1,
          x = 80,
          y = -60,
          animationEnabled = false,
          durationBarEnabled = false,
          visibility = "active",
          compactMode = value,
          extra = "preserved",
        }
        Config.Initialize(root)
        eq(Config.GetCompactMode(), value == true)
        eq(root.schemaVersion, 3)
        eq(root.scale, 0.1)
        eq(root.x, 80)
        eq(root.y, -60)
        eq(root.animationEnabled, false)
        eq(root.durationBarEnabled, false)
        eq(root.visibility, "active")
        eq(root.extra, "preserved")
      end
    end
    local root = Config.Initialize({ schemaVersion = 2, scale = 0.1 })
    eq(root.compactMode, false)
    eq(Config.SetCompactMode(true), true)
    for _, invalid in ipairs({ "false", 0, {}, harness.secret }) do
      eq(Config.SetCompactMode(invalid), false)
      eq(root.compactMode, true)
    end
    eq(Config.SetCompactMode(nil), false)
    Config.Initialize(root)
    eq(Config.GetCompactMode(), true)
    eq(Config.GetScale(), 0.1)
    Config.Reset()
    eq(root.compactMode, false)
    local future = { schemaVersion = 4, compactMode = "future layout" }
    Config.Initialize(future)
    eq(Config.GetCompactMode(), false)
    eq(Config.SetCompactMode(true), false)
    eq(future.compactMode, "future layout")
  end)

  test("animation changes require actual boolean preferences", function()
    local root = Config.Initialize(nil)
    eq(Config.SetAnimationEnabled(false), true)
    eq(Config.GetAnimationEnabled(), false)
    for _, invalid in ipairs({ "false", 0, {}, harness.secret }) do
      eq(Config.SetAnimationEnabled(invalid), false)
      eq(root.animationEnabled, false)
    end
    eq(Config.SetAnimationEnabled(nil), false)
    eq(Config.SetAnimationEnabled(true), true)
    eq(root.animationEnabled, true)
  end)

  test("reset changes only owned fields and the same saved root", function()
    local unknown = { retained = true }
    local root = Config.Initialize({
      scale = 1.5,
      x = 35,
      y = -87,
      animationEnabled = false,
      extra = unknown,
    })
    eq(Config.Reset(), true)
    eq(_G.RollTheBonesSlotsDB, root)
    eq(root.schemaVersion, 3)
    eq(root.scale, 1)
    eq(root.x, 0)
    eq(root.y, 140)
    eq(root.animationEnabled, true)
    eq(root.extra, unknown)
  end)

  test("a newer schema stays untouched and cannot be changed by older settings controls", function()
    local unknown = { retained = true }
    local root = {
      schemaVersion = 4,
      scale = 1.7,
      x = "future position",
      y = false,
      animationEnabled = "future mode",
      extra = unknown,
    }
    eq(Config.Initialize(root), root)
    eq(_G.RollTheBonesSlotsDB, root)
    eq(Config.IsReadOnly(), true)
    eq(Config.GetScale(), 1)
    local x, y = Config.GetPosition()
    eq(x, 0)
    eq(y, 140)
    eq(Config.GetAnimationEnabled(), true)
    eq(Config.SetScale(1.5), false)
    eq(Config.SetPosition(2, 3), false)
    eq(Config.SetAnimationEnabled(false), false)
    eq(Config.Reset(), false)
    eq(root.schemaVersion, 4)
    eq(root.scale, 1.7)
    eq(root.x, "future position")
    eq(root.y, false)
    eq(root.animationEnabled, "future mode")
    eq(root.extra, unknown)
    Config.Initialize(nil)
    eq(Config.IsReadOnly(), false)
    eq(Config.SetScale(1.5), true)
  end)
end

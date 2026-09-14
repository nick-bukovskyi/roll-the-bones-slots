-- Slash-command recovery and placement contracts; real chat dispatch needs the client
return function(test, H, loadAddon)
  local eq = H.eq
  local function login(saved, configure)
    local ns = loadAddon(saved)
    if configure then
      configure()
    end
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.loggedIn = true
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
  end
  local function command(message)
    eq(SLASH_ROLLTHEBONESSLOTS1, "/rtbs")
    assert(SlashCmdList.ROLLTHEBONESSLOTS)(message)
  end
  local function defaults(saved)
    eq(saved.scale, 1)
    eq(saved.x, 0)
    eq(saved.y, 140)
    eq(saved.visibility, "always")
    eq(saved.compactMode, false)
    eq(saved.animationEnabled, true)
    eq(saved.durationBarEnabled, true)
  end

  test("slash input other than reset is ignored without messages or saved changes", function()
    local saved = { scale = 0.8, x = 20, y = -60, visibility = "combat" }
    local ns = login(saved)
    for _, message in ipairs({ "", "help", "reset extra", "res", "settings" }) do
      command(message)
      eq(#H.messages, 0)
      eq(saved.scale, 0.8)
      eq(saved.x, 20)
      eq(saved.y, -60)
      eq(saved.visibility, "combat")
      eq(ns.Machine.GetFrame():IsVisible(), false)
    end
    for _, value in ipairs({ false, {}, H.secret }) do
      command(value)
    end
    command(nil)
    eq(#H.messages, 0)
  end)

  test("slash reset restores every owned setting and the hidden display without rebuilding", function()
    local extra = { keep = true }
    local saved = {
      scale = 0.1,
      x = 1e8,
      y = -1e8,
      visibility = "combat",
      compactMode = true,
      animationEnabled = false,
      durationBarEnabled = false,
      extra = extra,
    }
    local ns = login(saved)
    local frame = ns.Machine.GetFrame()
    eq(frame:IsVisible(), false)
    local frames, hooks, slots = #H.frames, H.hookCount, H.auraSlotCount
    for _, message in ipairs({ "  ReSeT \t", "reset" }) do
      command(message)
      defaults(saved)
      eq(_G.RollTheBonesSlotsDB, saved)
      eq(saved.extra, extra)
      eq(frame:IsVisible(), true)
      eq(frame:GetScale(), 1)
      eq(frame.height, ns.Layouts.Full.height)
      eq(frame.points.CENTER[1], UIParent)
      eq(frame.points.CENTER[2], "CENTER")
      eq(frame.points.CENTER[3], 0)
      eq(frame.points.CENTER[4], 140)
      eq(#H.frames, frames)
      eq(H.hookCount, hooks)
      eq(H.auraSlotCount, slots)
      assert(H.messages[#H.messages]:find("reset to defaults", 1, true))
    end
    ns = login(saved)
    defaults(saved)
    eq(ns.Machine.GetFrame():IsVisible(), true)
    eq(ns.Machine.GetFrame().points.CENTER[4], 140)
  end)

  test("slash reset cancels dragging and pending editor input before restoring defaults", function()
    local saved = { scale = 1.3, x = 90, y = -80, visibility = "active", compactMode = true }
    local ns = login(saved)
    H.enterEditMode()
    local selection = assert(H.findTemplate("EditModeSystemSelectionTemplate"))
    selection.scripts.OnMouseDown(selection)
    H.button("Test spin").scripts.OnClick()
    selection.scripts.OnDragStart(selection)
    local frame = ns.Machine.GetFrame()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 200, -200)
    local input = H.findTemplate("InputBoxTemplate")
    input.focused = true
    input:SetText("175")
    command("reset")
    selection.scripts.OnDragStop(selection)
    H.exitEditMode()
    defaults(saved)
    eq(frame.moving, false)
    eq(GetCurrentKeyBoardFocus(), nil)
    eq(input:IsVisible(), false)
    eq(frame.scripts.OnUpdate, nil)
    eq(frame:IsVisible(), true)
    eq(frame.points.CENTER[3], 0)
    eq(frame.points.CENTER[4], 140)
    H.enterEditMode()
    selection.scripts.OnMouseDown(selection)
    eq(H.findTemplate("WowStyle1DropdownTemplate"):GetText(), "Always")
    eq(input:GetText(), "100")
  end)

  test("slash reset remains available on inactive characters without constructing the display", function()
    for _, classToken in ipairs({ "MAGE", "ROGUE" }) do
      local ns = login(nil, function()
        H.classToken, H.spec = classToken, 259
      end)
      eq(_G.RollTheBonesSlotsDB, nil)
      command("")
      eq(_G.RollTheBonesSlotsDB, nil)
      command("reset")
      defaults(_G.RollTheBonesSlotsDB)
      eq(ns.Machine.GetFrame(), nil)
      eq(#H.frames, 1)
      eq(H.auraSlotCount, 0)
      eq(H.hookCount, 0)
      if classToken == "ROGUE" then
        H.spec = 260
        H.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        eq(ns.Machine.GetFrame():IsVisible(), true)
        eq(ns.Machine.GetFrame().points.CENTER[4], 140)
      end
    end
  end)

  test("slash reset refuses restricted changes without queuing a later reset", function()
    for _, restriction in ipairs({ "combat", "restricted" }) do
      local saved = { scale = 0.8, x = 40, y = -20, visibility = "combat" }
      local ns = login(saved)
      local points = #H.pointWrites
      H[restriction] = true
      command("reset")
      eq(saved.scale, 0.8)
      eq(saved.x, 40)
      eq(saved.y, -20)
      eq(saved.visibility, "combat")
      eq(#H.pointWrites, points)
      assert(H.messages[#H.messages]:find("unavailable", 1, true))
      H[restriction] = false
      H.fire("PLAYER_REGEN_ENABLED")
      H.fire("ENCOUNTER_END")
      eq(saved.scale, 0.8)
      eq(saved.visibility, "combat")
      eq(ns.Machine.GetFrame():IsVisible(), false)
      eq(#H.timers, 0)
      command("reset")
      defaults(saved)
      eq(ns.Machine.GetFrame():IsVisible(), true)
    end
  end)

  test("slash reset preserves newer settings on active and inactive characters", function()
    for _, spec in ipairs({ 259, 260 }) do
      local saved = { schemaVersion = 4, scale = 1.7, x = "future", extra = "keep" }
      login(saved, function()
        H.spec = spec
      end)
      command("reset")
      eq(_G.RollTheBonesSlotsDB, saved)
      eq(saved.schemaVersion, 4)
      eq(saved.scale, 1.7)
      eq(saved.x, "future")
      eq(saved.extra, "keep")
      assert(H.messages[#H.messages]:find("Newer saved settings preserved", 1, true))
    end
  end)

  test("fresh and reset positions stay centered above mid-screen within small and scaled screen bounds", function()
    for _, screen in ipairs({ { 1920, 1080, 1 }, { 1280, 720, 0.8 }, { 640, 480, 1 }, { 512, 320, 1 } }) do
      local function checkPosition(frame)
        local x, y = frame:GetCenter()
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        eq(frame.points.CENTER[1], UIParent)
        eq(frame.points.CENTER[2], "CENTER")
        eq(x, width / 2)
        assert(y > height / 2 and y <= height / 2 + 140)
        assert(x - frame.width / 2 >= 0 and x + frame.width / 2 <= width)
        assert(y - frame.height / 2 >= 0 and y + frame.height / 2 <= height)
      end
      local ns = login(nil, function()
        UIParent:SetScale(screen[3])
        UIParent:SetSize(screen[1] / screen[3], screen[2] / screen[3])
      end)
      local frame = ns.Machine.GetFrame()
      checkPosition(frame)
      ns.Config.SetScale(1.8)
      ns.Config.SetPosition(10000, -10000)
      ns.Machine.ApplyPosition()
      command("reset")
      checkPosition(frame)
      defaults(_G.RollTheBonesSlotsDB)
      UIParent:SetSize(1920, 1080)
      H.fire("DISPLAY_SIZE_CHANGED")
      checkPosition(frame)
      eq(frame.points.CENTER[4], 140)
      UIParent:SetSize(screen[1] / screen[3], screen[2] / screen[3])
      H.fire("UI_SCALE_CHANGED")
      checkPosition(frame)
    end
  end)
end

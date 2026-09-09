-- Keyboard delivery and taint need Retail client proof; these exercise the owned input/state boundary
-- Native reference: Gethe/wow-ui-source live 8ea15b61e45c0ed4eba01439c90757f86eb78d34, 12.1.0.69587
-- Blizzard_EditMode/Shared/EditModeSystemTemplates.lua: ProcessMovementKey and BreakFrameSnap
return function(test, H, loadAddon)
  local eq = H.eq
  local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-7, "unexpected position")
  end
  local function login(saved)
    local ns = loadAddon(saved)
    H.fire("ADDON_LOADED", "RollTheBonesSlots")
    H.fire("PLAYER_LOGIN")
    H.enterEditMode()
    return ns
  end
  local function selectChest()
    local selection = assert(H.findTemplate("EditModeSystemSelectionTemplate"))
    selection.scripts.OnMouseDown(selection)
    return H.findTemplate("WowStyle1DropdownTemplate").parent, selection
  end
  local function tap(panel, key, propagate)
    panel.scripts.OnKeyDown(panel, key)
    eq(panel.propagateKeyboard, propagate)
    panel.scripts.OnKeyUp(panel, key)
    eq(panel.propagateKeyboard, propagate)
  end
  local function position(ns, x, y)
    local actualX, actualY = ns.Config.GetPosition()
    near(actualX, x)
    near(actualY, y)
    local _, relative, point, frameX, frameY = ns.Machine.GetFrame():GetPoint(1)
    eq(relative, UIParent)
    eq(point, "CENTER")
    near(frameX, x)
    near(frameY, y)
  end

  test("all arrows move by native anchor units at every display and UI scale and survive reload", function()
    for _, scale in ipairs({ 0.1, 0.6, 1, 1.8 }) do
      for _, parentScale in ipairs({ 0.64, 1, 1.2 }) do
        local saved = { schemaVersion = 1, scale = scale, x = 100.25, y = -40.75, extra = "keep" }
        local ns = login(saved)
        UIParent:SetScale(parentScale)
        local panel = selectChest()
        eq(panel.keyboard, true)
        local frame = ns.Machine.GetFrame()
        local x, y = saved.x, saved.y
        for _, move in ipairs({ { "UP", 0, 1 }, { "DOWN", 0, -1 }, { "LEFT", -1, 0 }, { "RIGHT", 1, 0 } }) do
          local beforeX, beforeY = frame:GetCenter()
          tap(panel, move[1], false)
          x, y = x + move[2], y + move[3]
          position(ns, x, y)
          local afterX, afterY = frame:GetCenter()
          near((afterX - beforeX) * frame:GetEffectiveScale(), move[2] * scale * parentScale)
          near((afterY - beforeY) * frame:GetEffectiveScale(), move[3] * scale * parentScale)
        end
        tap(panel, "LEFT", false)
        tap(panel, "UP", false)
        H.exitEditMode()
        ns = login(saved)
        position(ns, 99.25, -39.75)
        eq(saved.extra, "keep")
        eq(saved.schemaVersion, 3)
      end
    end
  end)

  test("Shift uses ten-unit steps and repeated key events do not leave stale movement or idle work", function()
    local ns = login()
    local panel = selectChest()
    local frames, timers = #H.frames, #H.timers
    H.shift = true
    tap(panel, "UP", false)
    position(ns, 0, 150)
    tap(panel, "LEFT", false)
    position(ns, -10, 150)
    tap(panel, "DOWN", false)
    tap(panel, "RIGHT", false)
    position(ns, 0, 140)
    H.shift = false
    for _ = 1, 6 do
      panel.scripts.OnKeyDown(panel, "RIGHT")
    end
    position(ns, 6, 140)
    H.shift = true
    panel.scripts.OnKeyDown(panel, "RIGHT")
    panel.scripts.OnKeyUp(panel, "RIGHT")
    position(ns, 16, 140)
    H.shift = false
    H.advance(10)
    position(ns, 16, 140)
    eq(#H.frames, frames)
    eq(#H.timers, timers)
    eq(panel.scripts.OnUpdate, nil)
    eq(ns.Machine.GetFrame().scripts.OnUpdate, nil)
  end)

  test("text focus and unrelated press or release events keep their normal keyboard input", function()
    local ns = login()
    local panel = selectChest()
    for _, key in ipairs({ "W", "ESCAPE", "PRINTSCREEN", "LSHIFT", "RSHIFT", "LCTRL", "LALT", "PAD1" }) do
      tap(panel, key, true)
      position(ns, 0, 140)
    end
    panel.scripts.OnKeyDown(panel, "W")
    panel.scripts.OnKeyDown(panel, "RIGHT")
    eq(panel.propagateKeyboard, false)
    panel.scripts.OnKeyUp(panel, "W")
    eq(panel.propagateKeyboard, true)
    position(ns, 1, 140)
    local input = H.findTemplate("InputBoxTemplate")
    local externalInput = CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
    for _, box in ipairs({ input, externalInput }) do
      box.focused = true
      box:SetText("125")
      for _, key in ipairs({ "UP", "DOWN", "LEFT", "RIGHT" }) do
        tap(panel, key, true)
      end
      position(ns, 1, 140)
      eq(ns.Config.GetScale(), 1)
      eq(box:GetText(), "125")
      eq(box.focused, true)
      box.focused = false
    end
    tap(panel, "LEFT", false)
    position(ns, 0, 140)
    input.focused = true
    panel.scripts.OnKeyDown(panel, "UP")
    eq(panel.propagateKeyboard, true)
    input.focused = false
    panel.scripts.OnKeyDown(panel, "UP")
    eq(panel.propagateKeyboard, false)
    panel.scripts.OnKeyUp(panel, "UP")
    eq(panel.propagateKeyboard, true)
    position(ns, 0, 141)
    tap(panel, "DOWN", false)
    position(ns, 0, 140)
  end)

  test("nudges clamp saved coordinates at each edge and immediately move inward from unreachable saves", function()
    for _, edge in ipairs({
      { 1e8, 0, "RIGHT", "LEFT", -1, 0 },
      { -1e8, 0, "LEFT", "RIGHT", 1, 0 },
      { 0, 1e8, "UP", "DOWN", 0, -1 },
      { 0, -1e8, "DOWN", "UP", 0, 1 },
    }) do
      local ns = login({ scale = 1.8, x = edge[1], y = edge[2] })
      local panel = selectChest()
      local _, _, _, edgeX, edgeY = ns.Machine.GetFrame():GetPoint(1)
      tap(panel, edge[4], false)
      position(ns, edgeX + edge[5], edgeY + edge[6])
      H.shift = true
      for _ = 1, 3 do
        tap(panel, edge[3], false)
        position(ns, edgeX, edgeY)
      end
      H.shift = false
      tap(panel, edge[4], false)
      position(ns, edgeX + edge[5], edgeY + edge[6])
      UIParent:SetSize(100, 80)
      H.fire("DISPLAY_SIZE_CHANGED")
      tap(panel, edge[4], false)
      position(ns, 0, 0)
    end
  end)

  test("an arrow ends the current drag without snapping and mouse release cannot undo the nudge", function()
    local ns = login({ scale = 1.5 })
    local panel, selection = selectChest()
    EditModeManagerFrame.snap = true
    local snapCalls, finish = {}, ns.EditModeSnap.Finish
    ns.EditModeSnap.Finish = function(applySnap)
      snapCalls[#snapCalls + 1] = applySnap
      finish(applySnap)
    end
    ns.EditMode.ToggleHighlights()
    eq(selection:GetAlpha(), 0)
    selection.scripts.OnDragStart(selection)
    snapCalls = {}
    local frame = ns.Machine.GetFrame()
    frame:SetPoint("CENTER", UIParent, "CENTER", 42, -80)
    tap(panel, "RIGHT", false)
    eq(frame.moving, false)
    eq(frame.movable, false)
    eq(#snapCalls, 1)
    eq(snapCalls[1], false)
    position(ns, 43, -80)
    selection.scripts.OnDragStop(selection)
    position(ns, 43, -80)
    eq(#snapCalls, 1)
    H.findTemplate("MinimalSliderWithSteppersTemplate"):SetValue(0.6)
    position(ns, 107.5, -200)
    selection.scripts.OnDragStart(selection)
    snapCalls = {}
    selection.scripts.OnDragStop(selection)
    eq(#snapCalls, 1)
    eq(snapCalls[1], true)
  end)

  test("native selection and dialog close release the keyboard across repeated Edit Mode sessions", function()
    local ns = login()
    local panel = selectChest()
    local frames, hooks = #H.frames, H.hookCount
    for _ = 1, 8 do
      for _, deselect in ipairs({
        function()
          EditModeManagerFrame:SelectSystem({})
        end,
        function()
          EditModeManagerFrame:ClearSelectedSystem()
        end,
        function()
          H.findTemplate("UIPanelCloseButton").scripts.OnClick()
        end,
      }) do
        tap(panel, "UP", false)
        deselect()
        eq(panel:IsShown(), false)
        tap(panel, "LEFT", true) -- Deliberately deliver a stale callback
        position(ns, 0, 141)
        selectChest()
        eq(panel.propagateKeyboard, true)
        tap(panel, "DOWN", false)
      end
      H.exitEditMode()
      tap(panel, "RIGHT", true)
      H.enterEditMode()
      tap(panel, "RIGHT", true)
      selectChest()
      position(ns, 0, 140)
    end
    eq(#H.frames, frames)
    eq(H.hookCount, hooks)
    eq(#H.timers, 0)
  end)

  test("nudging after an interrupted drag starts at the visible position and saves it for reload", function()
    local saved = { scale = 1.5, x = 0, y = 140 }
    local ns = login(saved)
    local panel, selection = selectChest()
    selection.scripts.OnDragStart(selection)
    ns.Machine.GetFrame():SetPoint("CENTER", UIParent, "CENTER", 42, -80)
    H.combat = true
    H.fire("PLAYER_REGEN_DISABLED")
    eq(saved.x, 0)
    eq(saved.y, 140)
    H.combat = false
    H.fire("PLAYER_REGEN_ENABLED")
    selectChest()
    tap(panel, "RIGHT", false)
    position(ns, 43, -80)
    H.exitEditMode()
    ns = login(saved)
    position(ns, 43, -80)
  end)

  test("missing geometry rejects a nudge without replacing saved position and recovers when available", function()
    local saved = { x = 80, y = -40 }
    local ns = login(saved)
    local panel = selectChest()
    local frame = ns.Machine.GetFrame()
    for _, source in ipairs({ frame, UIParent }) do
      local getCenter = source.GetCenter
      source.GetCenter = function()
        return nil, nil
      end
      local pointWrites = #H.pointWrites
      tap(panel, "UP", true)
      eq(#H.pointWrites, pointWrites)
      eq(saved.x, 80)
      eq(saved.y, -40)
      source.GetCenter = getCenter
    end
    tap(panel, "LEFT", false)
    position(ns, 79, -40)
  end)

  test("combat and encounter locks reject keys before lifecycle delivery and recover without stale movement", function()
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "ENCOUNTER_START", "CHALLENGE_MODE_START", "PVP_MATCH_STATE_CHANGED" }) do
      local ns = login()
      local panel = selectChest()
      tap(panel, "RIGHT", false)
      local pointWrites = #H.pointWrites
      H.combat = event == "PLAYER_REGEN_DISABLED"
      H.restricted = not H.combat
      panel.scripts.OnKeyDown(panel, "UP")
      panel.scripts.OnKeyUp(panel, "UP")
      eq(panel:IsShown(), false)
      eq(#H.pointWrites, pointWrites)
      position(ns, 1, 140)
      H.fire(event)
      panel.scripts.OnKeyDown(panel, "LEFT")
      position(ns, 1, 140)
      H.combat, H.restricted = false, false
      H.fire("PLAYER_REGEN_ENABLED")
      tap(panel, "RIGHT", true)
      selectChest()
      tap(panel, "LEFT", false)
      position(ns, 0, 140)
    end
  end)

  test("overlays loading death spec changes and hidden UI require reselection before further nudges", function()
    local transitions = {
      { "CINEMATIC_START", "CINEMATIC_STOP", "cinematic" },
      { "PLAY_MOVIE", "STOP_MOVIE" },
      { "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "petBattle" },
      { "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD" },
      { "PLAYER_DEAD", "PLAYER_ALIVE" },
      { "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_SPECIALIZATION_CHANGED" },
      { "hidden UI" },
      { "hidden selections" },
    }
    for _, transition in ipairs(transitions) do
      local ns = login()
      local panel = selectChest()
      tap(panel, "RIGHT", false)
      if transition[3] then
        H[transition[3]] = true
      end
      if transition[1] == "hidden UI" then
        UIParent:Hide()
      elseif transition[1] == "hidden selections" then
        EditModeManagerFrame:HideSystemSelections()
      else
        H.fire(transition[1], "player")
      end
      eq(panel:IsShown(), false)
      tap(panel, "UP", true)
      position(ns, 1, 140)
      if transition[3] then
        H[transition[3]] = false
      end
      if transition[1] == "hidden UI" then
        UIParent:Show()
      elseif transition[1] == "hidden selections" then
        EditModeManagerFrame:ShowSystemSelections()
      else
        H.fire(transition[2], "player")
      end
      tap(panel, "UP", true)
      position(ns, 1, 140)
      selectChest()
      tap(panel, "LEFT", false)
      position(ns, 0, 140)
    end
  end)
end

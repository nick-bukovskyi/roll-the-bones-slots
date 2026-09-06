-- Lifecycle owns presentation availability; Edit Mode owns the preview session
local ADDON_NAME, ns = ...
local loaded, initialized, active = false, false, false
local inWorld, moviePlaying, layoutDirty = true, false, false
local lastCastGUID
local eventFrame = CreateFrame("Frame")
local RUNTIME_EVENTS = {
  "PLAYER_DEAD",
  "PLAYER_ALIVE",
  "CINEMATIC_START",
  "CINEMATIC_STOP",
  "PET_BATTLE_OPENING_START",
  "PET_BATTLE_CLOSE",
  "UI_SCALE_CHANGED",
  "DISPLAY_SIZE_CHANGED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "ENCOUNTER_START",
  "ENCOUNTER_END",
  "CHALLENGE_MODE_START",
  "CHALLENGE_MODE_COMPLETED",
  "CHALLENGE_MODE_RESET",
  "PVP_MATCH_STATE_CHANGED",
}

local function Refresh()
  local eligible = ns.Game.IsOutlaw()
  if not eligible and not active then
    return
  end
  if not initialized then
    ns.Config.Initialize(_G.RollTheBonesSlotsDB)
    ns.Machine.Initialize()
    ns.EditMode.Initialize(Refresh)
    initialized = true
    if ns.Config.IsReadOnly() then
      print("Roll the Bones Slots: Newer saved settings preserved; using read-only defaults")
    end
  end
  if active ~= eligible then
    active = eligible
    lastCastGUID = nil
    if active then
      layoutDirty = true
      eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
      for _, event in ipairs(RUNTIME_EVENTS) do
        eventFrame:RegisterEvent(event)
      end
      ns.EditMode.TryAttachManager()
      ns.EditMode.TryAttachOverlayToggle()
    else
      eventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
      for _, event in ipairs(RUNTIME_EVENTS) do
        eventFrame:UnregisterEvent(event)
      end
    end
  end
  local available = active and inWorld and not InCinematic() and not moviePlaying and not C_PetBattles.IsInBattle()
  ns.EditMode.SetAvailable(available)
  if layoutDirty and ns.Game.CanConfigure() then
    ns.Machine.ApplyPosition()
    layoutDirty = false
  end
  local preview = ns.EditMode.IsPreviewActive()
  local visibility = ns.Config.GetVisibility()
  local presentation = "hidden"
  if available then
    if preview then
      presentation = "preview"
      -- Blizzard substitutes its own fake aura provider throughout Edit Mode
    elseif not ns.EditMode.IsActive() and (visibility ~= "combat" or UnitAffectingCombat("player")) then
      presentation = visibility == "active" and "active" or "live"
    end
  end
  ns.Machine.SetPresentation(presentation)
end

local function StopInteraction()
  if not initialized then
    return
  end
  ns.EditMode.CancelInteraction()
  ns.Machine.StopSpin()
end

local function Start()
  eventFrame:UnregisterEvent("PLAYER_LOGIN")
  if not ns.Game.IsSupportedClient() then
    eventFrame:UnregisterEvent("ADDON_LOADED")
    print("Roll the Bones Slots: Inactive on this client; this build targets " .. ns.Game.ClientLabel)
    return
  end
  if ns.Game.IsRogue() == false then
    eventFrame:UnregisterEvent("ADDON_LOADED")
    return
  end
  -- Keep only eligibility and world/overlay state while another spec is active
  for _, event in ipairs({
    "PLAYER_LEAVING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
    "TRAIT_CONFIG_UPDATED",
    "PLAY_MOVIE",
    "STOP_MOVIE",
    "PLAYER_ENTERING_WORLD",
  }) do
    eventFrame:RegisterEvent(event)
  end
  Refresh()
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if issecretvalue(name) then
      return
    end
    if name == ADDON_NAME and not loaded then
      loaded = true
      if IsLoggedIn() then
        Start()
      else
        eventFrame:RegisterEvent("PLAYER_LOGIN")
      end
    elseif active then
      -- Optional Edit Mode providers can load or replace their eye after login
      ns.EditMode.TryAttachOverlayToggle()
      if name == "Blizzard_EditMode" then
        ns.EditMode.TryAttachManager()
        Refresh()
      end
    end
    return
  elseif event == "PLAYER_LOGIN" then
    Start()
    return
  end
  if not loaded then
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, castGUID, spellID = ...
    if ns.EditMode.IsActive() or not ns.Game.IsRollCast(unit, spellID) or not ns.Game.IsOutlaw() then
      return
    end
    if not issecretvalue(castGUID) and type(castGUID) == "string" then
      if castGUID == lastCastGUID then
        return
      end
      lastCastGUID = castGUID
    end
    ns.Machine.Spin()
    return
  elseif event == "PLAYER_LEAVING_WORLD" then
    inWorld = false
    StopInteraction()
    lastCastGUID = nil
  elseif event == "PLAYER_ENTERING_WORLD" then
    inWorld, moviePlaying, layoutDirty = true, false, true
    StopInteraction()
    lastCastGUID = nil
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD" then
    StopInteraction()
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unit = ...
    if issecretvalue(unit) or unit ~= "player" then
      return
    end
    StopInteraction()
    lastCastGUID = nil
  elseif event == "PLAY_MOVIE" then
    moviePlaying = true
    StopInteraction()
  elseif event == "STOP_MOVIE" then
    moviePlaying = false
  elseif event == "CINEMATIC_START" or event == "PET_BATTLE_OPENING_START" then
    StopInteraction()
  elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
    layoutDirty = true
  end
  Refresh()
end)
eventFrame:RegisterEvent("ADDON_LOADED")

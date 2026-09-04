-- Lifecycle owns presentation availability; Edit Mode owns the preview session
local ADDON_NAME, ns = ...
local loaded, initialized = false, false
local inWorld, moviePlaying, layoutDirty = true, false, false
local lastCastGUID
local eventFrame = CreateFrame("Frame")

local function Refresh()
    if not initialized then return end
    local available = inWorld and not InCinematic() and not moviePlaying and not C_PetBattles.IsInBattle()
    ns.EditMode.SetAvailable(available)
    if layoutDirty and ns.Game.CanConfigure() then
        ns.Machine.ApplyPosition()
        layoutDirty = false
    end
    local preview = ns.EditMode.IsPreviewActive()
    -- Blizzard substitutes its own fake aura provider throughout Edit Mode
    local visible = available and (preview or (not ns.EditMode.IsActive() and ns.Game.IsOutlaw()))
    ns.Machine.SetPresentation(visible, preview)
end

local function StopInteraction()
    ns.EditMode.CancelInteraction()
    ns.Machine.StopSpin()
end

local function Initialize()
    if initialized then return end
    eventFrame:UnregisterEvent("PLAYER_LOGIN")
    if not ns.Game.IsSupportedClient() then
        eventFrame:UnregisterEvent("ADDON_LOADED")
        print("Roll the Bones Slots: Inactive on this client; this development build targets Retail 12.1.0.69587")
        return
    end
    ns.Machine.Initialize()
    ns.EditMode.Initialize(Refresh)
    initialized = true
    if ns.EditMode.TryAttachManager() then eventFrame:UnregisterEvent("ADDON_LOADED") end
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    for _, event in ipairs({
        "PLAYER_LEAVING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED", "TRAIT_CONFIG_UPDATED",
        "PLAYER_DEAD", "PLAYER_ALIVE", "CINEMATIC_START", "CINEMATIC_STOP", "PLAY_MOVIE", "STOP_MOVIE",
        "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
    }) do eventFrame:RegisterEvent(event) end
    for _, event in ipairs(ns.Game.RestrictionEvents) do eventFrame:RegisterEvent(event) end
    Refresh()
    if ns.Config.IsReadOnly() then
        print("Roll the Bones Slots: Newer saved settings preserved; using read-only defaults")
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if issecretvalue(name) then return end
        if name == ADDON_NAME and not loaded then
            loaded = true
            if ns.Game.IsSupportedClient() then ns.Config.Initialize(_G.RollTheBonesSlotsDB) end
            if IsLoggedIn() then Initialize() else eventFrame:RegisterEvent("PLAYER_LOGIN") end
        elseif initialized and name == "Blizzard_EditMode" then
            if ns.EditMode.TryAttachManager() then eventFrame:UnregisterEvent("ADDON_LOADED") end
            Refresh()
        end
        return
    elseif event == "PLAYER_LOGIN" then Initialize(); return end
    if not initialized then return end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if ns.EditMode.IsActive() or not ns.Game.IsRollCast(unit, spellID) or not ns.Game.IsOutlaw() then return end
        if not issecretvalue(castGUID) and type(castGUID) == "string" then
            if castGUID == lastCastGUID then return end
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
        if issecretvalue(unit) or unit ~= "player" then return end
        StopInteraction()
        lastCastGUID = nil
    elseif event == "PLAY_MOVIE" then moviePlaying = true; StopInteraction()
    elseif event == "STOP_MOVIE" then moviePlaying = false
    elseif event == "CINEMATIC_START" or event == "PET_BATTLE_OPENING_START" then StopInteraction()
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then layoutDirty = true end
    Refresh()
end)
eventFrame:RegisterEvent("ADDON_LOADED")

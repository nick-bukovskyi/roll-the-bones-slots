-- Public EQOL dialog handoff contracts, not control of the installed provider
return function(test, H, loadAddon)
    local eq = H.eq
    local function prepare()
        local ns = loadAddon({ scale = 1.25 })
        H.fire("ADDON_LOADED", "RollTheBonesSlots")
        H.fire("PLAYER_LOGIN")
        H.enterEditMode()
        return ns, H.findTemplate("EditModeSystemSelectionTemplate")
    end
    local function selectChest(selection)
        selection.scripts.OnMouseDown(selection)
        return H.findTemplate("WowStyle1DropdownTemplate").parent
    end
    local function provider()
        local library = {}
        local state =
            { dialog = CreateFrame("Frame", nil, UIParent), selected = false, closeCalls = 0 }
        state.dialog:SetScript("OnHide", function()
            state.selected = false
        end)
        state.dialog:Hide()
        function library:HideSettingsDialog(...)
            eq(self, library)
            eq(select("#", ...), 0)
            state.closeCalls = state.closeCalls + 1
            if not state.dialog:IsShown() then
                return false
            end
            state.dialog:Hide()
            return true
        end
        _G.LibStub = {
            GetLibrary = function(_, name, silent, ...)
                eq(name, "EnhanceQoLEditMode-1.0")
                eq(silent, true)
                eq(select("#", ...), 0)
                return library, 21000001
            end,
        }
        local function selectProvider()
            -- Installed EQOL clears the native selection before opening its dialog
            if H.combat then
                return
            end
            EditModeManagerFrame:ClearSelectedSystem()
            local dropdown = H.findTemplate("WowStyle1DropdownTemplate")
            if dropdown then
                eq(dropdown.parent:IsShown(), false)
            end
            state.selected = true
            state.dialog:Show()
        end
        return library, state, selectProvider
    end

    test(
        "EQOL and chest settings hand off in both directions without stale edits or duplicate work",
        function()
            local ns, selection = prepare()
            local _, state, selectProvider = provider()
            selectProvider()
            local panel = selectChest(selection)
            eq(state.dialog:IsShown(), false)
            eq(state.selected, false)
            eq(state.closeCalls, 1)
            eq(panel:IsShown(), true)
            eq(ns.EditMode.IsPreviewActive(), true)
            ns.EditMode.ToggleHighlights()
            selection.scripts.OnDragStart(selection)
            selection.scripts.OnDragStop(selection)
            local frames, hooks, slots = #H.frames, H.hookCount, H.auraSlotCount
            local input, dropdown =
                H.findTemplate("InputBoxTemplate"), H.findTemplate("WowStyle1DropdownTemplate")
            for _ = 1, 8 do
                input.focused = true
                input:SetText("170")
                dropdown.menuOpen = true
                selectProvider()
                eq(panel:IsShown(), false)
                eq(state.dialog:IsShown(), true)
                eq(input.focused, false)
                eq(dropdown.menuOpen, false)
                eq(ns.Config.GetScale(), 1.25)
                ns.Settings.Refresh()
                eq(panel:IsShown(), false)
                selectChest(selection)
                eq(panel:IsShown(), true)
                eq(state.dialog:IsShown(), false)
                eq(state.selected, false)
                eq(selection:GetAlpha(), 0)
                eq(input:GetText(), "125")
                eq(ns.EditMode.IsPreviewActive(), true)
                local calls = state.closeCalls
                selectChest(selection)
                eq(state.closeCalls, calls + 1)
                eq(state.dialog:IsShown(), false)
            end
            selection.scripts.OnDragStart(selection)
            eq(ns.Machine.GetFrame().moving, true)
            selectProvider()
            eq(ns.Machine.GetFrame().moving, false)
            eq(panel:IsShown(), false)
            selectChest(selection)
            EditModeManagerFrame:SelectSystem({})
            eq(panel:IsShown(), false)
            eq(state.dialog:IsShown(), false)
            selectChest(selection)
            H.exitEditMode()
            eq(panel:IsShown(), false)
            eq(ns.EditMode.IsPreviewActive(), false)
            eq(#H.frames, frames)
            eq(H.hookCount, hooks)
            eq(H.auraSlotCount, slots)
            eq(#H.timers, 0)
        end
    )

    test(
        "optional public dialog close is discovered when it appears and after provider replacement",
        function()
            local _, selection = prepare()
            eq(LibStub, nil)
            local panel = selectChest(selection)
            eq(panel:IsShown(), true)
            local library, old, selectProvider = provider()
            local close = library.HideSettingsDialog
            library.HideSettingsDialog = nil
            H.fire("ADDON_LOADED", "EnhanceQoL")
            selectChest(selection)
            eq(panel:IsShown(), true)
            eq(old.closeCalls, 0)
            library.HideSettingsDialog = close
            selectProvider()
            selectChest(selection)
            eq(old.closeCalls, 1)
            eq(old.dialog:IsShown(), false)
            local _, replacement, selectReplacement = provider()
            selectReplacement()
            selectChest(selection)
            eq(replacement.closeCalls, 1)
            eq(replacement.dialog:IsShown(), false)
            eq(old.closeCalls, 1)
            eq(panel:IsShown(), true)
            H.exitEditMode()
        end
    )

    test(
        "restricted editor suspension cancels input and defers EQOL handoff until editing is available",
        function()
            local ns, selection = prepare()
            local _, state, selectProvider = provider()
            local panel = selectChest(selection)
            local input = H.findTemplate("InputBoxTemplate")
            input.focused = true
            input:SetText("180")
            H.combat, H.restricted = true, true
            H.fire("PLAYER_REGEN_DISABLED")
            eq(panel:IsShown(), false)
            eq(input.focused, false)
            eq(ns.Config.GetScale(), 1.25)
            local calls = state.closeCalls
            selection.scripts.OnMouseDown(selection)
            eq(state.closeCalls, calls)
            eq(ns.EditMode.IsPreviewActive(), false)
            H.combat = false
            H.fire("PLAYER_REGEN_ENABLED")
            selectProvider()
            selection.scripts.OnMouseDown(selection)
            eq(state.dialog:IsShown(), true)
            eq(state.closeCalls, calls)
            eq(panel:IsShown(), false)
            H.restricted = false
            H.fire("ENCOUNTER_END")
            selectChest(selection)
            eq(state.dialog:IsShown(), false)
            eq(state.closeCalls, calls + 1)
            eq(panel:IsShown(), true)
            eq(input:GetText(), "125")
            eq(ns.EditMode.IsPreviewActive(), true)
            H.exitEditMode()
        end
    )
end

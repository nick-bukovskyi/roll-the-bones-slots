-- Cosmetic lane choices and construction geometry, not live aura selection
return function(test, H, loadAddon)
    local eq = H.eq
    local MEDIA = "Interface\\AddOns\\RollTheBonesSlots\\media\\"
    local SYMBOL_RECTS = {
        { 0, 0, 344, 416 }, { 344, 0, 376, 416 }, { 720, 0, 304, 416 },
        { 0, 416, 512, 416 }, { 512, 416, 512, 416 },
    }

    local function SymbolID(texture)
        eq(texture.texture, MEDIA .. "symbols.tga")
        local uv = texture.texCoords
        for id, rect in ipairs(SYMBOL_RECTS) do
            if uv[1] * 1024 == rect[1] and uv[2] * 1024 == rect[1] + rect[3]
                and uv[3] * 1024 == rect[2] and uv[4] * 1024 == rect[2] + rect[4] then
                return id
            end
        end
        error("symbol outside an authored atlas region")
    end

    local function WithDraws(values, run)
        local original, count = math.random, 0
        math.random = function(...)
            eq(select("#", ...), 2)
            local minimum, maximum = ...
            count = count + 1
            eq(minimum, 1); eq(maximum, count % 2 == 1 and 3 or 2)
            local value = assert(values[count], "unexpected cosmetic random draw")
            assert(value >= minimum and value <= maximum)
            return value
        end
        local ok, failure = pcall(run, function() return count end)
        math.random = original
        if not ok then error(failure, 0) end
        eq(count, #values)
    end

    local function Login(saved)
        local ns = loadAddon(saved)
        H.fire("ADDON_LOADED", "RollTheBonesSlots"); H.loggedIn = true
        H.fire("PLAYER_LOGIN"); H.fire("PLAYER_ENTERING_WORLD", true, false)
        return ns
    end

    local function Carriers(ns)
        local found = {}
        for _, container in ipairs(H.containers()) do
            if rawget(container.parent.parent, "clipsChildren") then found[#found + 1] = container.parent end
        end
        eq(#found, 3)
        return found
    end

    local function Selection(ns, pair, settled)
        local moving = Carriers(ns)
        for index, carrier in ipairs(moving) do
            local variant = index == 1 and 1 or pair[index - 1]
            local point = carrier.points.TOPLEFT
            eq(point[1], carrier.parent); eq(point[2], "TOPLEFT")
            eq(point[3], -(variant - 1) * ns.Art.LanePitch)
            if settled then eq(point[4], 0) end
        end
        assert(pair[1] ~= pair[2])
        if settled then eq(ns.Machine.GetFrame().scripts.OnUpdate, nil) end
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
                found = SymbolID(texture)
            end
        end
        return assert(found, "missing lane center")
    end

    test("all six cosmetic pairs preserve exact native rank dice counts without artwork writes", function()
        WithDraws({ 1, 1, 1, 2, 2, 1, 2, 2, 3, 1, 3, 2 }, function(drawCount)
            local ns = Login()
            eq(table.concat(ns.Art.VariantSymbols, ","), "2,3,4")
            Selection(ns, { 1, 2 }, true); eq(drawCount(), 0)
            local alpha, writes, widgets, points = #H.alphaWrites, H.textureWrites, #H.widgets, #H.pointWrites
            local cases = { { 1, 2 }, { 1, 3 }, { 2, 1 }, { 2, 3 }, { 3, 1 }, { 3, 2 } }
            for attempt, pair in ipairs(cases) do
                Cast("pair" .. attempt); Selection(ns, pair)
                local expected = {
                    { 1, ns.Art.VariantSymbols[pair[1]], ns.Art.VariantSymbols[pair[2]] },
                    { 1, 1, ns.Art.VariantSymbols[pair[2]] }, { 1, 1, 1 }, { 5, 5, 5 },
                }
                for rank = 1, 4 do
                    local dice, chests = 0, 0
                    for reel = 1, 3 do
                        local variant = reel == 1 and 1 or pair[reel - 1]
                        local slot = H.nativeSlots[(reel - 1) * 4 + rank]
                        eq(slot.button.sealed, true)
                        local symbol = CenterSymbol(slot.button, (variant - 1) * ns.Art.LanePitch)
                        eq(symbol, expected[rank][reel])
                        dice = dice + (symbol == 1 and 1 or 0); chests = chests + (symbol == 5 and 1 or 0)
                    end
                    eq(dice, rank == 4 and 0 or rank); eq(chests, rank == 4 and 3 or 0)
                end
                H.advance(0.8); H.fire("SPELLS_CHANGED"); Selection(ns, pair)
                eq(drawCount(), attempt * 2)
                H.advance(0.8); Selection(ns, pair, true)
            end
            eq(#H.alphaWrites, alpha); eq(H.textureWrites, writes); eq(#H.widgets, widgets)
            local moving = Carriers(ns)
            for index = points + 1, #H.pointWrites do
                local target = H.pointWrites[index]
                assert(target == moving[1] or target == moving[2] or target == moving[3])
            end
            eq(H.auraSlotCount, 18)
        end)
    end)

    test("reduced motion still chooses variants while duplicate or unreadable casts do not", function()
        WithDraws({ 3, 2, 1, 2, 2, 1 }, function(drawCount)
            local ns = Login({ animationEnabled = false })
            Cast(H.secret, H.secret, H.secret); Cast("other-unit", "party1"); Cast("other-spell", "player", 315508)
            eq(drawCount(), 0); Selection(ns, { 1, 2 }, true)
            Cast("first"); Selection(ns, { 3, 2 }, true); eq(drawCount(), 2)
            Cast("first"); H.fire("SPELLS_CHANGED"); Selection(ns, { 3, 2 }, true); eq(drawCount(), 2)
            -- A secret GUID is opaque, but readable unit/spell still permits cosmetics
            Cast(H.secret); Selection(ns, { 1, 3 }, true)
            UIParent:Hide(); Cast("hidden"); eq(drawCount(), 4)
            UIParent:Show(); Selection(ns, { 1, 3 }, true)
            Cast("visible-again"); Selection(ns, { 2, 1 }, true)
        end)
    end)

    test("repeat spins, stop, hidden UI and restriction recovery preserve the latest live pair", function()
        WithDraws({ 2, 2, 3, 1, 1, 1 }, function(drawCount)
            local ns = Login()
            Cast("first"); H.advance(0.9); Cast("replacement")
            local moving = Selection(ns, { 3, 1 })
            for _, carrier in ipairs(moving) do eq(carrier.points.TOPLEFT[4], ns.Art.SpinRows * ns.Art.Pitch) end
            H.advance(0.4); ns.Machine.StopSpin(); Selection(ns, { 3, 1 }, true)
            UIParent:Hide(); Selection(ns, { 3, 1 }, true)
            UIParent:Show(); H.fire("SPELLS_CHANGED"); Selection(ns, { 3, 1 }, true)
            H.combat, H.restricted = true, true; H.fire("PLAYER_REGEN_DISABLED"); H.fire("ENCOUNTER_START")
            Selection(ns, { 3, 1 }, true); eq(drawCount(), 4)
            H.combat, H.restricted = false, false; H.fire("PLAYER_REGEN_ENABLED")
            Selection(ns, { 3, 1 }, true); eq(drawCount(), 4)
            Cast("next"); H.advance(2); Selection(ns, { 1, 2 }, true)
            eq(rawget(RollTheBonesSlotsDB, "variant"), nil); eq(rawget(RollTheBonesSlotsDB, "previewVariant"), nil)
        end)
    end)

    test("editor test spins retain a separate pair and restore the live pair on exit", function()
        WithDraws({ 3, 2, 2, 2, 1, 2 }, function(drawCount)
            local ns = Login()
            Cast("live"); H.advance(2); Selection(ns, { 3, 2 }, true)
            H.enterEditMode(); Selection(ns, { 1, 2 }, true)
            local selection = H.findTemplate("EditModeSystemSelectionTemplate")
            selection.scripts.OnMouseDown(selection)
            H.button("Test spin").scripts.OnClick(); H.advance(2); Selection(ns, { 2, 3 }, true)
            H.exitEditMode(); Selection(ns, { 3, 2 }, true)
            H.enterEditMode(); Selection(ns, { 2, 3 }, true); eq(drawCount(), 4)
            selection.scripts.OnMouseDown(selection)
            local animation = H.findTemplate("UICheckButtonTemplate")
            animation:SetChecked(false); animation.scripts.OnClick(animation)
            H.button("Test spin").scripts.OnClick(); Selection(ns, { 1, 3 }, true)
            H.exitEditMode(); Selection(ns, { 3, 2 }, true)
        end)
    end)

    test("lane glyphs and opaque backing stay outside neighboring selected viewports", function()
        WithDraws({}, function()
            local ns = Login()
            eq(ns.Art.LanePitch, 128); eq(ns.Art.SymbolSize, 112)
            local parents = {}
            for index = 1, 12 do
                local slot = H.nativeSlots[index]
                parents[#parents + 1] = { object = slot.button, lanes = index <= 4 and 1 or 3 }
            end
            for index, carrier in ipairs(Carriers(ns)) do
                parents[#parents + 1] = { object = carrier, lanes = index == 1 and 1 or 3 }
            end
            for _, entry in ipairs(parents) do
                local parent, count = entry.object, 0
                for _, region in ipairs(H.reelRegions(parent)) do
                    if region.kind == "Texture" then
                        local center, left, laneX = region.points.CENTER
                        if center then
                            eq(center[2], "CENTER")
                            laneX = center[3]
                            left = parent.width / 2 + laneX - region.width / 2
                            local rect = SYMBOL_RECTS[SymbolID(region)]
                            eq(region.width, ns.Art.SymbolSize * rect[3] / 512)
                            eq(region.height, ns.Art.SymbolSize * rect[4] / 512)
                        else
                            eq(region.drawLayer, "BACKGROUND")
                            laneX = assert(region.points.TOPLEFT)[3]; left = laneX
                        end
                        local lane = laneX / ns.Art.LanePitch + 1
                        eq(lane, math.floor(lane)); assert(lane >= 1 and lane <= entry.lanes)
                        for selected = 1, entry.lanes do
                            if selected ~= lane then
                                local shifted = left - (selected - 1) * ns.Art.LanePitch
                                assert(shifted + region.width <= 0 or shifted >= parent.width,
                                    "neighboring lane texture can bleed through the fixed viewport")
                            end
                        end
                        count = count + 1
                    end
                end
                eq(count, entry.lanes * (ns.Art.SpinRows + 6))
            end
        end)
    end)
end

-- Construction contracts only; Blizzard's native aura selection needs in-game proof
return function(test, H, loadAddon)
    local eq = H.eq
    local expected = {
        { 1214933, "One of a Kind", "1,0,0" },
        { 1214934, "Double Trouble", "1,1,0" },
        { 1214935, "Triple Threat", "1,1,1" },
        { 1214937, "Jackpot", "5,5,5" },
    }
    local anchors = { TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 },
        LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
        BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 } }
    local function rectangle(region)
        local point = region.pointOrder[1]
        local binding = region.points[point]
        eq(binding[1], region.parent)
        local source, target = anchors[point], anchors[binding[2]]
        local left = target[1] * region.parent.width + binding[3] - source[1] * region.width
        local top = target[2] * region.parent.height - binding[4] - source[2] * region.height
        return { left = left, top = top, right = left + region.width, bottom = top + region.height }
    end
    local function strip(parent, pitch, laneX)
        laneX = laneX or 0
        local rows, backgrounds = {}, {}
        for _, region in ipairs(H.reelRegions(parent)) do
            if region.kind == "Texture" then
                if region.drawLayer == "BACKGROUND" then
                    local background = rectangle(region)
                    if background.left == laneX then
                        background.uv = region.texCoords
                        backgrounds[#backgrounds + 1] = background
                    end
                    eq(rawget(region, "alpha") or 1, 1)
                    eq(region.texture, "Interface\\AddOns\\RollTheBonesSlots\\media\\cabinet.tga")
                elseif region.points.CENTER and region.points.CENTER[3] == laneX then
                    local row = -region.points.CENTER[4] / pitch
                    eq(row, math.floor(row)); assert(not rows[row], "duplicate strip row")
                    rows[row] = region
                end
            end
        end
        table.sort(backgrounds, function(a, b) return a.top < b.top end)
        return rows, backgrounds
    end
    local function covers(backgrounds, top, bottom, width, left)
        left = left or 0
        local covered = top
        for _, rect in ipairs(backgrounds) do
            assert(rect.left <= left and rect.right >= left + width)
            if rect.top <= covered and rect.bottom >= covered then covered = rect.bottom end
        end
        assert(covered >= bottom, "opaque strip backing leaves an uncovered interval")
    end
    test("native reel and footer construction has thirteen slots without result readback", function()
        local ns = loadAddon()
        local originalCreateFrame = CreateFrame
        local totalSlots = 0
        for displayIndex = 1, 4 do
            local footer = displayIndex == 4
            local calls, initialized = {}, 0
            local container, parent, methods = {}, {}, {}
            setmetatable(container, { __index = function(_, key)
                assert(methods[key], "unexpected native container access: " .. key)
                return methods[key]
            end })
            function methods:SetPoint(point, relative, relativePoint, x, y)
                eq(self, container); eq(point, "TOPLEFT"); eq(relative, parent)
                eq(relativePoint, "TOPLEFT"); eq(x, 0); eq(y, 0); calls.anchored = true
            end
            function methods:SetUnit(unit) eq(self, container); eq(unit, "player"); calls.unit = true end
            function methods:AddAuraSlot(key, filter, options)
                eq(self, container); eq(filter, "HELPFUL")
                eq(options.templateNames, nil)
                local resultIndex = initialized + 1
                eq(key, footer and "footer" or "result" .. resultIndex)
                local map, count = options.candidateFilters.includeSpellIDs, 0
                for id, included in pairs(map) do
                    eq(included, true); count = count + 1
                    if not footer then eq(id, expected[resultIndex][1]) end
                end
                eq(count, footer and 4 or 1)
                if footer then for _, definition in ipairs(expected) do eq(map[definition[1]], true) end end
                local sealed, prepared = false, {}
                local buttonMethods = {}
                local button = setmetatable({}, { __index = function(_, name)
                    assert(not sealed, "native result accessed after initialization")
                    assert(buttonMethods[name], "unexpected native button access: " .. name)
                    return buttonMethods[name]
                end })
                function buttonMethods:SetPoint(point, relative, relativePoint, x, y)
                    eq(point, "TOPLEFT"); eq(relative, container); eq(relativePoint, "TOPLEFT")
                    eq(x, 0); eq(y, 0); prepared.anchor = true
                end
                function buttonMethods:SetCancelAuraButtons(value) eq(value, nil); prepared.cancel = true end
                function buttonMethods:SetHideTooltipInCombat(value) eq(value, true); prepared.tooltip = true end
                function buttonMethods:EnableMouse(value)
                    eq(footer, false); eq(value, false); prepared.mouseDisabled = true
                end
                function buttonMethods:SetSize(width, height)
                    assert(prepared.anchor and prepared.cancel and prepared.tooltip)
                    if not footer then eq(prepared.mouseDisabled, true) end
                    eq(width, 91); eq(height, 153)
                end
                options.initializeFrame(button)
                sealed = true; totalSlots = totalSlots + 1
                return setmetatable({}, { __index = function() error("slot return value inspected") end })
            end
            function methods:SetEnabled(enabled)
                eq(self, container); eq(enabled, true); eq(initialized, footer and 1 or 4); calls.enabled = true
            end
            _G.CreateFrame = function(kind, name, owner, template)
                eq(kind, "AuraContainer"); eq(name, nil); eq(owner, parent)
                eq(template, "CustomAuraContainerTemplate"); return container
            end
            local result
            if footer then
                result = ns.Game.CreateFooterDisplay(parent, function(...)
                    eq(select("#", ...), 1); local button = ...
                    button:SetSize(91, 153); initialized = initialized + 1
                end)
            else
                result = ns.Game.CreateReelDisplay(parent, displayIndex, function(...)
                    eq(select("#", ...), 3); local button, definition, reelIndex = ...
                    local resultIndex = initialized + 1
                    eq(reelIndex, displayIndex); eq(definition, ns.Game.Results[resultIndex])
                    eq(definition.spellID, expected[resultIndex][1]); eq(definition.label, expected[resultIndex][2])
                    eq(table.concat(definition.symbols, ","), expected[resultIndex][3])
                    button:SetSize(91, 153); initialized = initialized + 1
                end)
            end
            eq(result, container); assert(calls.anchored and calls.unit and calls.enabled)
        end
        _G.CreateFrame = originalCreateFrame
        eq(totalSlots, 13); eq(#ns.Game.Results, 4)
    end)

    test("only the live buff row accepts hover with either duration bar preference", function()
        for _, scale in ipairs({ 0.6, 1, 1.8 }) do
            for _, showBar in ipairs({ true, false }) do
                local ns = loadAddon({ scale = scale, durationBarEnabled = showBar })
                H.fire("ADDON_LOADED", "RollTheBonesSlots")
                H.loggedIn = true; H.fire("PLAYER_LOGIN")
                local footer
                for _, slot in ipairs(H.nativeSlots) do
                    local button = slot.button
                    if button.bindings.SetSpellName then
                        assert(not footer, "only one native footer may accept hover")
                        footer = slot
                        eq(button.mouse, true)
                        local row = rectangle(button.children[1])
                        local insets = assert(rawget(button, "hitRectInsets"), "footer hover covers the cabinet")
                        eq(insets[1], row.left); eq(button.width - insets[2], row.right)
                        eq(insets[3], row.top); eq(button.height - insets[4], row.bottom)
                    else
                        eq(button.mouse, false)
                    end
                end
                assert(footer, "live buff row needs its native tooltip")
                eq(footer.container.enabled, true)
                local slots = #H.nativeSlots
                H.enterEditMode(); eq(footer.container.enabled, false)
                H.exitEditMode(); eq(footer.container.enabled, true)
                H.fire("PLAYER_LEAVING_WORLD"); eq(footer.container.enabled, false)
                H.fire("PLAYER_ENTERING_WORLD", false, false); eq(footer.container.enabled, true)
                eq(#H.nativeSlots, slots)
            end
        end
    end)

    test("native result strips cover dim idle artwork and the native footer covers the idle message", function()
        local ns = loadAddon()
        ns.Config.Initialize(nil); ns.Machine.Initialize()
        eq(#H.nativeSlots, 18)
        for index = 1, 13 do
            local slot = H.nativeSlots[index]
            -- Inspect test construction metadata only, never invoke a sealed native object
            local button = slot.button
            if index <= 12 then
                local carrier = slot.container.parent
                eq(button.width, carrier.width); eq(button.height, carrier.height)
                eq(next(button.bindings), nil)
                for lane = 1, index <= 4 and 1 or 3 do
                    local x = (lane - 1) * ns.Art.LanePitch
                    local rows, backgrounds = strip(button, ns.Art.Pitch, x)
                    local idle = strip(carrier, ns.Art.Pitch, x)
                    covers(backgrounds, 0, button.height, button.width, x)
                    eq(assert(rows[0]).alpha, 1); eq(assert(idle[0]).alpha, 0.22)
                end
            else
                local backing = button.children[1]
                local binding = button.bindings
                local foreground = binding.SetSpellName.parent
                eq(foreground.parent, button)
                eq(binding.SetIcon.parent, foreground); eq(binding.SetDurationText.parent, foreground)
                local idleLabel
                for _, child in ipairs(ns.Machine.GetFrame().children) do
                    if rawget(child, "text") == "Try yer luck, matey!" then idleLabel = child end
                end
                assert(idleLabel, "idle footer needs the pirate invitation")
                local coverPoint, labelPoint = backing.points.TOPLEFT, idleLabel.points.TOPLEFT
                assert(coverPoint[3] <= labelPoint[3] and -coverPoint[4] <= -labelPoint[4])
                assert(coverPoint[3] + backing.width >= labelPoint[3] + idleLabel.width)
                assert(-coverPoint[4] + backing.height >= -labelPoint[4] + idleLabel.height)
            end
            eq(button.sealed, true)
        end
    end)

    test("continuous native and idle strips share a full lead-in and retain complete neighboring textures", function()
        local ns = loadAddon()
        ns.Config.Initialize(nil); ns.Machine.Initialize()
        local reference = {}
        for index = 1, 12 do
            local slot = H.nativeSlots[index]
            local button, carrier = slot.button, slot.container.parent
            local reelIndex = math.floor((index - 1) / 4) + 1
            eq(rawget(button, "clipsChildren") or false, false)
            eq(rawget(slot.container, "clipsChildren") or false, false)
            eq(rawget(carrier, "clipsChildren") or false, false)
            eq(carrier.parent.clipsChildren, true)
            for lane = 1, reelIndex == 1 and 1 or 3 do
                local x = (lane - 1) * ns.Art.LanePitch
                local rows, backgrounds = strip(button, ns.Art.Pitch, x)
                local idleRows, idleBackgrounds = strip(carrier, ns.Art.Pitch, x)
                local top = rectangle(rows[-1]).top
                local bottom = rectangle(rows[ns.Art.SpinRows + 1]).bottom
                assert(top < 0 and bottom > carrier.height)
                covers(backgrounds, top, bottom, carrier.width, x)
                covers(idleBackgrounds, top, bottom, carrier.width, x)
                for _, backing in ipairs({ backgrounds, idleBackgrounds }) do
                    eq(#backing, 3)
                    for piece = 2, #backing do
                        local above, below = backing[piece - 1], backing[piece]
                        eq(above.bottom, below.top)
                        eq(above.uv[1], below.uv[1]); eq(above.uv[2], below.uv[2])
                        eq(above.uv[4], below.uv[3])
                    end
                end
                reference[reelIndex] = reference[reelIndex] or rows
                for row = -1, ns.Art.SpinRows + 1 do
                    local texture = assert(rows[row], "missing continuous native row")
                    local idle = assert(idleRows[row], "missing continuous idle row")
                    -- Cropped atlas regions retain the original pixels-per-UI-unit ratio
                    local uv = texture.texCoords
                    eq(texture.width / (uv[2] - uv[1]), ns.Art.SymbolSize * 2)
                    eq(texture.height / (uv[4] - uv[3]), ns.Art.SymbolSize * 2)
                    if row > -1 then
                        eq(texture.points.CENTER[4] - rows[row - 1].points.CENTER[4], -ns.Art.Pitch)
                    end
                    if row >= 2 then
                        eq(texture.alpha, 1); eq(idle.alpha, 1)
                        for uv = 1, 4 do
                            eq(texture.texCoords[uv], reference[reelIndex][row].texCoords[uv])
                            eq(idle.texCoords[uv], texture.texCoords[uv])
                        end
                    else
                        eq(texture.alpha, row == 0 and 1 or 0.45)
                        eq(idle.alpha, 0.22 * (row == 0 and 1 or 0.45))
                    end
                end
            end
        end
    end)

    test("prebuilt strip backing covers every viewport throughout motion and settle", function()
        local ns = loadAddon()
        ns.Config.Initialize(nil); ns.Machine.Initialize(); ns.Machine.SetPresentation(true, true)
        local geometry = {}
        for index = 1, 12 do
            local slot = H.nativeSlots[index]
            local lanes = {}
            for lane = 1, index <= 4 and 1 or 3 do
                local _, backgrounds = strip(slot.button, ns.Art.Pitch, (lane - 1) * ns.Art.LanePitch)
                lanes[lane] = backgrounds
            end
            geometry[index] = { carrier = slot.container.parent, lanes = lanes }
        end
        local alphaCount, textureWrites, widgetCount = #H.alphaWrites, H.textureWrites, #H.widgets
        ns.Machine.Spin()
        for _ = 0, 180 do
            for _, entry in ipairs(geometry) do
                local offset = entry.carrier.points.TOPLEFT[4]
                local x = -entry.carrier.points.TOPLEFT[3]
                local lane = x / ns.Art.LanePitch + 1
                covers(entry.lanes[lane], offset, offset + entry.carrier.parent.height, entry.carrier.width, x)
            end
            H.advance(1 / 120)
        end
        eq(ns.Machine.GetFrame().scripts.OnUpdate, nil)
        eq(#H.alphaWrites, alphaCount); eq(H.textureWrites, textureWrites); eq(#H.widgets, widgetCount)
    end)
end

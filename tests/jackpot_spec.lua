-- Authored texture placement only; native aura visibility still needs client proof
return function(test, H, loadAddon)
    local eq = H.eq
    local MEDIA = "Interface\\AddOns\\RollTheBonesSlots\\media\\"
    local SYMBOL_RECTS = {
        { 0, 0, 344, 416 }, { 344, 0, 376, 416 }, { 720, 0, 304, 416 },
        { 0, 416, 512, 416 }, { 512, 416, 512, 416 },
    }

    local function SymbolID(texture)
        if rawget(texture, "texture") ~= MEDIA .. "symbols.tga" then return nil end
        local uv = assert(rawget(texture, "texCoords"), "symbol needs an atlas region")
        for id, rect in ipairs(SYMBOL_RECTS) do
            if uv[1] * 1024 == rect[1] and uv[2] * 1024 == rect[1] + rect[3]
                and uv[3] * 1024 == rect[2] and uv[4] * 1024 == rect[2] + rect[4] then
                return id
            end
        end
        error("symbol outside an authored atlas region")
    end

    local function CheckSymbol(texture, chest, nominalSize)
        local id = assert(SymbolID(texture), "slot symbol must use the shared atlas")
        eq(id == 5, chest)
        local rect = SYMBOL_RECTS[id]
        eq(texture.width, nominalSize * rect[3] / 512)
        eq(texture.height, nominalSize * rect[4] / 512)
    end

    local function VisibleSample(widget)
        local ancestor = widget
        while ancestor do
            if ancestor.kind == "AuraContainer" or ancestor.sealed or not ancestor.shown then return false end
            ancestor = ancestor.parent
        end
        -- All checks run at rest; exclude the prebuilt lanes outside the fixed well
        if widget.kind == "Texture" and widget.points.CENTER and widget.points.CENTER[2] == "CENTER" then
            local carrier = widget.parent
            while carrier and carrier.parent and not rawget(carrier.parent, "clipsChildren") do
                carrier = carrier.parent
            end
            if carrier and carrier.parent and rawget(carrier.parent, "clipsChildren") then
                return widget.points.CENTER[3] + carrier.points.TOPLEFT[3] == 0
            end
        end
        return true
    end

    test("exclusive chest appears only at native Jackpot centers, never ordinary strip rows", function()
        local ns = loadAddon()
        ns.Config.Initialize(nil); ns.Machine.Initialize()
        local centers, ordinaryRows = 0, 0
        eq(#H.nativeSlots, 18)
        for index = 1, 13 do
            local slot = H.nativeSlots[index]
            local button = slot.button
            -- Read harness construction metadata, without invoking sealed native widgets
            if slot.key == "footer" then
                for _, child in ipairs(button.children) do
                    eq(SymbolID(child), nil)
                end
                local icon = button.bindings.SetIcon
                eq(rawget(icon, "texture"), nil)
                eq(icon.width, 16); eq(icon.height, 16)
                eq(icon.points.TOPLEFT[2], "TOPLEFT")
                eq(icon.points.TOPLEFT[3], 58); eq(icon.points.TOPLEFT[4], -210)
            else
                local count = 0
                for _, texture in ipairs(H.reelRegions(button)) do
                    if texture.kind == "Texture" and texture.points.CENTER then
                        local row = -texture.points.CENTER[4] / ns.Art.Pitch
                        local chest = slot.filters[1214937] == true and row == 0
                        eq(texture.points.CENTER[2], "CENTER")
                        CheckSymbol(texture, chest, ns.Art.SymbolSize)
                        if chest then centers = centers + 1 else ordinaryRows = ordinaryRows + 1 end
                        count = count + 1
                    end
                end
                eq(count, (index <= 4 and 1 or 3) * (ns.Art.SpinRows + 3))
            end
            eq(button.sealed, true)
        end
        eq(centers, 7); eq(ordinaryRows, 4 * 7 * (ns.Art.SpinRows + 3) - 7)

        local idleRows = 0
        for _, container in ipairs(H.containers()) do
            local carrier = container.parent
            if carrier ~= ns.Machine.GetFrame() then
                for _, texture in ipairs(carrier.children) do
                    if texture.kind == "Texture" and texture.points.CENTER then
                        CheckSymbol(texture, false, ns.Art.SymbolSize); idleRows = idleRows + 1
                    end
                end
            end
        end
        eq(idleRows, 7 * (ns.Art.SpinRows + 3))
    end)

    test("preview chest is exclusive to labeled Jackpot centers and footer across every sample", function()
        local ns = loadAddon()
        ns.Config.Initialize(nil); ns.Machine.Initialize(); ns.Machine.SetPresentation(true, true)
        local labels = { ["One of a Kind"] = true, ["Double Trouble"] = true,
            ["Triple Threat"] = true, Jackpot = true }
        local seen = {}
        for _ = 1, 5 do
            local name, previewLabel = nil, false
            for _, widget in ipairs(H.widgets) do
                if widget.kind == "FontString" and VisibleSample(widget) then
                    local text = rawget(widget, "text")
                    if labels[text] then assert(not name, "duplicate sample footer"); name = text end
                    if text == "Preview" then previewLabel = true end
                end
            end
            eq(previewLabel, true)
            local key = name or "idle"
            assert(not seen[key], "sample cycle repeated before covering all outcomes"); seen[key] = true
            local centerCount, footerCount = 0, 0
            for _, texture in ipairs(H.widgets) do
                if texture.kind == "Texture" and VisibleSample(texture) then
                    local id = SymbolID(texture)
                    if id then
                        local point = assert(texture.points.CENTER, "authored symbols retain their visual center")
                        local reel = point[2] == "CENTER"
                        CheckSymbol(texture, id == 5, reel and ns.Art.SymbolSize or 16)
                        if not reel then
                            eq(point[2], "TOPLEFT"); eq(point[3], 66); eq(point[4], -218)
                        end
                        if id == 5 then
                            eq(name, "Jackpot")
                            if reel then
                                eq(point[4], 0); centerCount = centerCount + 1
                            else
                                footerCount = footerCount + 1
                            end
                        end
                    end
                end
            end
            eq(centerCount, name == "Jackpot" and 3 or 0)
            eq(footerCount, name == "Jackpot" and 1 or 0)
            ns.Machine.PreviewNext(); H.advance(2)
        end
        for label in pairs(labels) do eq(seen[label], true) end
        eq(seen.idle, true)
        ns.Machine.SetPresentation(true, false)
        for _, texture in ipairs(H.widgets) do
            if SymbolID(texture) == 5 then
                eq(VisibleSample(texture), false)
            end
        end
    end)
end

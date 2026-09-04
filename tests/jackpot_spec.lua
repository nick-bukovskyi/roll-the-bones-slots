-- Authored texture placement only; native aura visibility still needs client proof
return function(test, H, loadAddon)
    local eq = H.eq
    local MEDIA = "Interface\\AddOns\\RollTheBonesSlots\\media\\"

    local function CheckSymbol(texture, chest)
        eq(texture.texture, MEDIA .. (chest and "jackpot.tga" or "symbols.tga"))
        local uv = texture.texCoords
        if chest then
            eq(table.concat(uv, ","), "0,1,0,1")
        else
            assert(uv[1] == 0 or uv[1] == 0.5, "ordinary symbol outside its atlas cell")
            assert(uv[3] == 0 or uv[3] == 0.5, "ordinary symbol outside its atlas cell")
            eq(uv[2] - uv[1], 0.5); eq(uv[4] - uv[3], 0.5)
        end
    end

    local function VisibleSample(widget)
        local ancestor = widget
        while ancestor do
            if ancestor.kind == "AuraContainer" or ancestor.sealed or not ancestor.shown then return false end
            ancestor = ancestor.parent
        end
        -- All checks run at rest; exclude the prebuilt lanes outside the fixed well
        if widget.kind == "Texture" and widget.points.CENTER then
            local carrier = widget.parent
            if not rawget(carrier.parent, "clipsChildren") then carrier = carrier.parent end
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
        eq(#H.nativeSlots, 13)
        for index, slot in ipairs(H.nativeSlots) do
            local button = slot.button
            -- Read harness construction metadata, without invoking sealed native widgets
            if slot.key == "footer" then
                for _, child in ipairs(button.children) do
                    assert(rawget(child, "texture") ~= MEDIA .. "jackpot.tga")
                end
            else
                local count = 0
                for _, texture in ipairs(button.children) do
                    if texture.kind == "Texture" and texture.points.CENTER then
                        local row = -texture.points.CENTER[4] / ns.Art.Pitch
                        local chest = slot.filters[1214937] == true and row == 0
                        CheckSymbol(texture, chest)
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
                        CheckSymbol(texture, false); idleRows = idleRows + 1
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
                    local path = rawget(texture, "texture")
                    if path == MEDIA .. "jackpot.tga" then
                        eq(name, "Jackpot"); CheckSymbol(texture, true)
                        if texture.points.CENTER then
                            eq(texture.points.CENTER[4], 0); centerCount = centerCount + 1
                        else
                            assert(texture.points.TOPLEFT, "chest outside its preview footer")
                            eq(texture.width, 22); eq(texture.height, 22); footerCount = footerCount + 1
                        end
                    elseif path == MEDIA .. "symbols.tga" then
                        CheckSymbol(texture, false)
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
            if rawget(texture, "texture") == MEDIA .. "jackpot.tga" then
                eq(VisibleSample(texture), false)
            end
        end
    end)
end

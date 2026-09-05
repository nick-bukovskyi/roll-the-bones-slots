-- Strict contract harness, not a simulation of WoW secrets or native rendering
local H = {}
local unpackValues = table.unpack or unpack
local secret = setmetatable({}, {
  __tostring = function()
    error("secret formatted")
  end,
  __index = function()
    error("secret indexed")
  end,
})
H.secret = secret

function H.eq(actual, expected)
  assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

function H.install()
  H.frames, H.widgets, H.timers, H.messages, H.callbacks = {}, {}, {}, {}, {}
  H.animationGroups = {}
  H.nativeSlots, H.alphaWrites, H.pointWrites, H.textureWrites = {}, {}, {}, 0
  H.clock = 0
  H.build, H.version, H.spec, H.known = "69587", "12.1.0", 260, true
  H.combat, H.restricted, H.cinematic, H.petBattle, H.loggedIn = false, false, false, false, false
  H.playerCombat = false
  H.auraSlotCount, H.categoryCount, H.hookCount = 0, 0, 0
  local methods = {}
  local function groupDuration(group)
    local orders, lastOrder = {}, 0
    for _, animation in ipairs(group.animations) do
      local order = animation.order
      orders[order] = math.max(orders[order] or 0, animation.startDelay + animation.duration + animation.endDelay)
      lastOrder = math.max(lastOrder, order)
    end
    local duration = 0
    for order = 1, lastOrder do
      duration = duration + (orders[order] or 0)
    end
    return duration
  end
  local function playGroup(group)
    group.playCalls = group.playCalls + 1
    group.playing = true
    group.finishAt = H.clock + groupDuration(group)
  end
  local function stopGroup(group, finished)
    if not finished then
      group.stopCalls = group.stopCalls + 1
    end
    group.playing, group.finishAt = false, nil
  end
  H._finishAnimationGroup = function(group)
    stopGroup(group, true)
  end
  local function check(value)
    local current = value
    while current do
      assert(not rawget(current, "sealed"), "add-on accessed a restricted aura object after initialization")
      current = rawget(current, "parent")
    end
  end
  local function object(kind, parent, template)
    local value = {
      kind = kind,
      parent = parent or false,
      template = template or false,
      shown = true,
      scripts = {},
      events = {},
      callbacks = {},
      width = 0,
      height = 0,
      scale = 1,
      points = {},
      pointOrder = {},
      children = {},
      sealed = false,
      bindings = {},
      moving = false,
      frameLevel = parent and parent.frameLevel + 1 or 1,
      focused = false,
      accessible = true,
    }
    if parent then
      table.insert(parent.children, value)
    end
    table.insert(H.widgets, value)
    return setmetatable(value, {
      __index = function(_, key)
        assert(methods[key], "unexpected widget API: " .. key)
        return methods[key]
      end,
    })
  end
  function methods:SetSize(w, h)
    check(self)
    assert(type(w) == "number" and type(h) == "number")
    self.width, self.height = w, h
  end
  function methods:GetWidth()
    check(self)
    return self.width
  end
  function methods:GetHeight()
    check(self)
    return self.height
  end
  function methods:GetSize()
    check(self)
    return self.width, self.height
  end
  function methods:SetPoint(point, relative, relativePoint, x, y)
    check(self)
    assert(type(point) == "string" and type(relative) == "table" and type(relativePoint) == "string")
    assert(type(x) == "number" and type(y) == "number")
    if not self.points[point] then
      table.insert(self.pointOrder, point)
    end
    self.points[point] = { relative, relativePoint, x, y }
    H.pointWrites[#H.pointWrites + 1] = self
  end
  function methods:GetPoint(index)
    check(self)
    assert(type(index) == "number")
    local point = self.pointOrder[index]
    if point then
      return point, unpackValues(self.points[point])
    end
  end
  function methods:SetAllPoints(relative)
    check(self)
    assert(type(relative) == "table")
    self.allPoints = relative
    self:SetPoint("TOPLEFT", relative, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0)
    self.width, self.height = relative.width, relative.height
  end
  function methods:ClearAllPoints()
    check(self)
    self.points, self.pointOrder = {}, {}
  end
  function methods:SetScale(value)
    check(self)
    assert(type(value) == "number")
    self.scale = value
  end
  function methods:GetScale()
    check(self)
    return self.scale
  end
  function methods:GetEffectiveScale()
    check(self)
    return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1)
  end
  function methods:GetCenter()
    check(self)
    if self == UIParent then
      return self.width / 2, self.height / 2
    end
    if rawget(self, "allPoints") then
      return self.allPoints:GetCenter()
    end
    local p = self.points.CENTER
    if p then
      return UIParent.width / (2 * self.scale) + p[3], UIParent.height / (2 * self.scale) + p[4]
    end
    return 0, 0
  end
  function methods:GetRect()
    check(self)
    local x, y = self:GetCenter()
    return x - self.width / 2, y - self.height / 2, self.width, self.height
  end
  function methods:CanBeAccessedInContext()
    check(self)
    return self.accessible
  end
  function methods:SetShown(value)
    check(self)
    assert(type(value) == "boolean")
    local changed = self.shown ~= value
    self.shown = value
    if changed then
      local function dispatch(current)
        local event = value and "OnShow" or "OnHide"
        if current.scripts[event] then
          current.scripts[event](current)
        end
        for _, child in ipairs(current.children) do
          if child.shown then
            dispatch(child)
          end
        end
      end
      dispatch(self)
    end
  end
  function methods:Show()
    self:SetShown(true)
  end
  function methods:Hide()
    self:SetShown(false)
  end
  function methods:IsShown()
    check(self)
    return self.shown
  end
  function methods:IsVisible()
    check(self)
    return self.shown and (not self.parent or self.parent:IsVisible())
  end
  function methods:SetScript(event, fn)
    check(self)
    assert(type(event) == "string" and (fn == nil or type(fn) == "function"))
    self.scripts[event] = fn
  end
  function methods:HookScript(event, fn, ...)
    check(self)
    H.eq(select("#", ...), 0)
    assert(type(event) == "string" and type(fn) == "function")
    local original = self.scripts[event]
    H.hookCount = H.hookCount + 1
    self.scripts[event] = function(...)
      if original then
        original(...)
      end
      fn(...)
    end
    return true
  end
  function methods:RegisterEvent(event)
    check(self)
    assert(type(event) == "string")
    self.events[event] = true
    return true
  end
  function methods:UnregisterEvent(event)
    check(self)
    self.events[event] = nil
  end
  function methods:RegisterUnitEvent(event, unit)
    check(self)
    H.eq(unit, "player")
    self.events[event] = unit
    return true
  end
  function methods:CreateTexture(name, layer)
    check(self)
    assert(name == nil and type(layer) == "string")
    local texture = object("Texture", self)
    texture.drawLayer = layer
    return texture
  end
  function methods:CreateFontString(name, layer, template)
    check(self)
    assert(name == nil and layer == "OVERLAY" and type(template) == "string")
    return object("FontString", self, template)
  end
  function methods:SetText(text)
    check(self)
    assert(type(text) == "string")
    self.text = text
  end
  function methods:SetNumber(value, ...)
    check(self)
    H.eq(self.kind, "EditBox")
    H.eq(select("#", ...), 0)
    assert(type(value) == "number" and value == value and math.abs(value) < math.huge)
    self.text = tostring(value)
  end
  function methods:GetText()
    check(self)
    return rawget(self, "text") or ""
  end
  function methods:SetNormalTexture(asset, ...)
    check(self)
    H.eq(self.kind, "Button")
    H.eq(select("#", ...), 0)
    assert(type(asset) == "string")
    self.normalTexture = object("Texture", self)
    self.normalTexture.texture = asset
  end
  function methods:GetNormalTexture()
    check(self)
    H.eq(self.kind, "Button")
    return rawget(self, "normalTexture")
  end
  function methods:SetOwner(owner, anchor, ...)
    check(self)
    H.eq(self.kind, "GameTooltip")
    H.eq(anchor, "ANCHOR_RIGHT")
    H.eq(select("#", ...), 0)
    check(owner)
    self.owner = owner
  end
  function methods:GetOwner()
    check(self)
    H.eq(self.kind, "GameTooltip")
    return rawget(self, "owner")
  end
  function methods:SetupMenu(generator, ...)
    check(self)
    H.eq(self.kind, "DropdownButton")
    H.eq(select("#", ...), 0)
    assert(type(generator) == "function")
    self.menuGenerator = generator
    self.options = {}
    local dropdown = self
    local root = {
      CreateRadio = function(_, text, isSelected, onSelect, data, ...)
        H.eq(select("#", ...), 0)
        assert(type(text) == "string")
        assert(type(isSelected) == "function" and type(onSelect) == "function")
        assert(type(data) == "string")
        dropdown.options[#dropdown.options + 1] = {
          label = text,
          isSelected = isSelected,
          onSelect = onSelect,
          value = data,
        }
      end,
    }
    generator(self, root)
  end
  function methods:OverrideText(text, ...)
    check(self)
    H.eq(self.kind, "DropdownButton")
    H.eq(select("#", ...), 0)
    assert(type(text) == "string")
    self.text = text
  end
  function methods:CloseMenu(...)
    check(self)
    H.eq(self.kind, "DropdownButton")
    H.eq(select("#", ...), 0)
    self.menuOpen = false
  end
  function methods:SetTextColor(r, g, b, a)
    check(self)
    assert(r and g and b and a)
  end
  function methods:SetColorTexture(r, g, b, a)
    check(self)
    assert(r and g and b and a)
    self.color = { r, g, b, a }
    H.textureWrites = H.textureWrites + 1
  end
  function methods:SetBlendMode(value)
    check(self)
    assert(value == "ADD" or value == "BLEND")
    self.blendMode = value
  end
  function methods:SetGradient(orientation, minimumColor, maximumColor)
    check(self)
    H.eq(self.kind, "Texture")
    H.eq(orientation, "VERTICAL")
    assert(type(minimumColor) == "table" and type(minimumColor.GetRGBA) == "function")
    assert(type(maximumColor) == "table" and type(maximumColor.GetRGBA) == "function")
    self.gradient = { minimumColor, maximumColor }
    H.textureWrites = H.textureWrites + 1
  end
  function methods:SetTexture(path, horizontal, vertical, filter)
    check(self)
    assert(type(path) == "string")
    H.eq(horizontal, "CLAMP")
    H.eq(vertical, "CLAMP")
    H.eq(filter, "LINEAR")
    self.texture = path
    H.textureWrites = H.textureWrites + 1
  end
  function methods:SetTexCoord(left, right, top, bottom, ...)
    check(self)
    H.eq(select("#", ...), 0)
    assert(type(left) == "number" and type(right) == "number" and type(top) == "number" and type(bottom) == "number")
    self.texCoords = { left, right, top, bottom }
    H.textureWrites = H.textureWrites + 1
  end
  function methods:SetDrawLayer(layer, sublayer)
    check(self)
    assert(type(layer) == "string" and (sublayer == nil or type(sublayer) == "number"))
    self.drawLayer, self.subLayer = layer, sublayer or 0
  end
  function methods:SetAlpha(alpha)
    check(self)
    assert(type(alpha) == "number" and alpha >= 0 and alpha <= 1)
    self.alpha = alpha
    H.alphaWrites[#H.alphaWrites + 1] = { object = self, value = alpha }
  end
  function methods:GetAlpha()
    check(self)
    return rawget(self, "alpha") or 1
  end
  function methods:SetJustifyH(value)
    check(self)
    assert(value == "LEFT" or value == "CENTER" or value == "RIGHT")
    self.justify = value
  end
  function methods:SetFrameStrata(value)
    check(self)
    assert(value == "MEDIUM" or value == "DIALOG" or value == "HIGH")
    self.strata = value
  end
  function methods:SetFrameLevel(value)
    check(self)
    assert(type(value) == "number")
    self.frameLevel = value
  end
  function methods:GetFrameLevel()
    check(self)
    return self.frameLevel
  end
  function methods:SetClipsChildren(value)
    check(self)
    assert(type(value) == "boolean")
    self.clipsChildren = value
  end
  function methods:SetClampedToScreen(value)
    check(self)
    H.eq(value, true)
  end
  function methods:SetMovable(value)
    check(self)
    assert(type(value) == "boolean")
    self.movable = value
  end
  function methods:SetDontSavePosition(value)
    check(self)
    H.eq(value, true)
  end
  function methods:RegisterForDrag(value)
    check(self)
    H.eq(value, "LeftButton")
  end
  function methods:EnableMouse(value)
    check(self)
    assert(type(value) == "boolean")
    self.mouse = value
  end
  function methods:SetHitRectInsets(left, right, top, bottom, ...)
    check(self)
    H.eq(select("#", ...), 0)
    assert(type(left) == "number" and type(right) == "number" and type(top) == "number" and type(bottom) == "number")
    self.hitRectInsets = { left, right, top, bottom }
  end
  function methods:StartMoving()
    check(self)
    H.eq(self.movable, true)
    self.moving = true
  end
  function methods:StopMovingOrSizing()
    check(self)
    self.moving = false
  end
  function methods:SetAutoFocus(value)
    check(self)
    H.eq(value, false)
  end
  function methods:SetNumeric(value, ...)
    check(self)
    H.eq(self.kind, "EditBox")
    H.eq(select("#", ...), 0)
    assert(type(value) == "boolean")
    self.numeric = value
  end
  function methods:SetMaxLetters(value, ...)
    check(self)
    H.eq(self.kind, "EditBox")
    H.eq(select("#", ...), 0)
    assert(type(value) == "number" and value >= 0 and value == math.floor(value))
    self.maxLetters = value
  end
  function methods:HasFocus()
    check(self)
    return self.focused
  end
  function methods:ClearFocus()
    check(self)
    local previous = self.focused
    self.focused = false
    if previous and self.scripts.OnEditFocusLost then
      self.scripts.OnEditFocusLost(self)
    end
  end
  function methods:SetChecked(value)
    check(self)
    assert(type(value) == "boolean")
    self.checked = value
  end
  function methods:GetChecked()
    check(self)
    return self.checked
  end
  function methods:Init(value, minimum, maximum, steps, formatters)
    check(self)
    H.eq(self.template, "MinimalSliderWithSteppersTemplate")
    H.eq(minimum, 0.6)
    H.eq(maximum, 1.8)
    assert(math.abs(steps - 24) < 1e-9 and type(formatters) == "table")
    self.value = value
  end
  function methods:SetValue(value)
    check(self)
    assert(type(value) == "number")
    self.value = value
    local callback = self.callbacks.OnValueChanged
    if callback then
      callback.fn(callback.owner, value)
    end
  end
  function methods:SetMinMaxValues(minimum, maximum, ...)
    check(self)
    H.eq(self.kind, "StatusBar")
    H.eq(select("#", ...), 0)
    assert(type(minimum) == "number" and type(maximum) == "number" and maximum >= minimum)
    self.minimum, self.maximum = minimum, maximum
  end
  function methods:SetOrientation(value)
    check(self)
    H.eq(self.kind, "StatusBar")
    H.eq(value, "HORIZONTAL")
    self.orientation = value
  end
  function methods:SetFillStyle(value)
    check(self)
    H.eq(self.kind, "StatusBar")
    H.eq(value, Enum.StatusBarFillStyle.Standard)
    self.fillStyle = value
  end
  function methods:SetStatusBarTexture(texture, ...)
    check(self)
    H.eq(self.kind, "StatusBar")
    H.eq(select("#", ...), 0)
    check(texture)
    H.eq(texture.kind, "Texture")
    H.eq(texture.parent, self)
    self.fill = texture
    return true
  end
  function methods:SetStatusBarColor(r, g, b, a, ...)
    check(self)
    H.eq(self.kind, "StatusBar")
    H.eq(select("#", ...), 0)
    assert(type(r) == "number" and type(g) == "number" and type(b) == "number")
    assert(a == nil or type(a) == "number")
    self.statusBarColor = { r, g, b, a or 1 }
  end
  function methods:RegisterCallback(event, fn, owner)
    check(self)
    H.eq(event, "OnValueChanged")
    assert(type(fn) == "function" and type(owner) == "table")
    assert(not self.callbacks[event], "duplicate widget callback")
    self.callbacks[event] = { fn = fn, owner = owner }
  end
  function methods:SetSystem(system)
    check(self)
    H.eq(self.template, "EditModeSystemSelectionTemplate")
    H.eq(system:GetSystemName(), "Roll the Bones Slots")
  end
  function methods:ShowHighlighted()
    check(self)
    self.selectionStyle = "highlighted"
    self:Show()
  end
  function methods:ShowSelected()
    check(self)
    self.selectionStyle = "selected"
    self:Show()
  end
  function methods:SetUnit(unit)
    check(self)
    H.eq(self.kind, "AuraContainer")
    H.eq(unit, "player")
    self.unit = unit
  end
  function methods:SetEnabled(value)
    check(self)
    H.eq(self.kind, "AuraContainer")
    assert(type(value) == "boolean")
    self.enabled = value
  end
  function methods:SetCancelAuraButtons(value)
    check(self)
    assert(value == nil)
  end
  function methods:SetHideTooltipInCombat(value)
    check(self)
    H.eq(value, true)
  end
  function methods:CreateAnimationGroup(name, template)
    check(self)
    assert(name == nil)
    assert(template == nil, "runtime animation-group templates are not supported")
    local group = setmetatable({
      kind = "AnimationGroup",
      parent = self,
      animations = {},
      scripts = {},
      playCalls = 0,
      stopCalls = 0,
      playing = false,
      template = template,
    }, {
      __index = function(_, key)
        assert(methods[key], "unexpected animation group API: " .. key)
        return methods[key]
      end,
    })
    self.animationGroups = rawget(self, "animationGroups") or {}
    self.animationGroups[#self.animationGroups + 1] = group
    H.animationGroups[#H.animationGroups + 1] = group
    return group
  end
  function methods:CreateAnimation(kind)
    check(self)
    H.eq(self.kind, "AnimationGroup")
    H.eq(kind, "Alpha")
    local animation = setmetatable({ kind = kind, parent = self, order = 1, duration = 0, startDelay = 0, endDelay = 0 }, {
      __index = function(_, key)
        assert(methods[key], "unexpected animation API: " .. key)
        return methods[key]
      end,
    })
    self.animations[#self.animations + 1] = animation
    return animation
  end
  function methods:SetTarget(target)
    check(self)
    H.eq(self.kind, "Alpha")
    assert(type(target) == "table")
    check(target)
    self.target = target
    return true
  end
  function methods:SetOrder(value)
    check(self)
    H.eq(self.kind, "Alpha")
    assert(type(value) == "number" and value >= 1 and value == math.floor(value))
    self.order = value
  end
  function methods:SetDuration(value)
    check(self)
    H.eq(self.kind, "Alpha")
    assert(type(value) == "number" and value >= 0)
    self.duration = value
  end
  function methods:SetStartDelay(value)
    check(self)
    H.eq(self.kind, "Alpha")
    assert(type(value) == "number" and value >= 0)
    self.startDelay = value
  end
  function methods:SetEndDelay(value)
    check(self)
    H.eq(self.kind, "Alpha")
    assert(type(value) == "number" and value >= 0)
    self.endDelay = value
  end
  function methods:SetFromAlpha(value)
    check(self)
    H.eq(self.kind, "Alpha")
    assert(type(value) == "number" and value >= 0 and value <= 1)
    self.fromAlpha = value
  end
  function methods:SetToAlpha(value)
    check(self)
    H.eq(self.kind, "Alpha")
    assert(type(value) == "number" and value >= 0 and value <= 1)
    self.toAlpha = value
  end
  function methods:SetSmoothing(value)
    check(self)
    H.eq(self.kind, "Alpha")
    assert(value == "IN" or value == "OUT" or value == "IN_OUT" or value == "NONE")
    self.smoothing = value
  end
  function methods:SetLooping(value)
    check(self)
    H.eq(self.kind, "AnimationGroup")
    assert(value == "NONE")
    self.looping = value
  end
  function methods:SetToFinalAlpha(value)
    check(self)
    H.eq(self.kind, "AnimationGroup")
    H.eq(value, true)
    self.toFinalAlpha = value
  end
  function methods:Play()
    check(self)
    H.eq(self.kind, "AnimationGroup")
    playGroup(self)
  end
  function methods:Stop()
    check(self)
    H.eq(self.kind, "AnimationGroup")
    stopGroup(self, false)
  end
  local function bindRegion(button, region, kind)
    check(button)
    check(region)
    H.eq(button.kind, "AuraButton")
    H.eq(region.kind, kind)
    local ancestor = region.parent
    while ancestor and ancestor ~= button do
      ancestor = ancestor.parent
    end
    H.eq(ancestor, button)
  end
  for method, kind in pairs({
    SetIcon = "Texture",
    SetSpellName = "FontString",
    SetDurationText = "FontString",
  }) do
    methods[method] = function(self, region, ...)
      H.eq(select("#", ...), 0)
      bindRegion(self, region, kind)
      self.bindings[method] = region
    end
  end
  function methods:SetDurationBar(bar, options, ...)
    H.eq(select("#", ...), 0)
    bindRegion(self, bar, "StatusBar")
    H.eq(options.direction, Enum.StatusBarTimerDirection.RemainingTime)
    H.eq(options.interpolation, Enum.StatusBarInterpolation.Immediate)
    for key in pairs(options) do
      assert(key == "direction" or key == "interpolation")
    end
    H.eq(next(bar.scripts), nil)
    self.bindings.SetDurationBar = bar
    self.durationBarOptions = { direction = options.direction, interpolation = options.interpolation }
  end
  function methods:AddAuraSlot(key, filter, options)
    check(self)
    assert(type(key) == "string")
    H.eq(filter, "HELPFUL")
    self.slots = rawget(self, "slots") or {}
    assert(not self.slots[key], "duplicate native slot")
    self.filters = rawget(self, "filters") or {}
    local filters = options.candidateFilters.includeSpellIDs
    assert(options.templateNames == nil, "native aura slots must not install script templates")
    assert(type(filters) == "table" and next(filters), "native slot needs explicit spell filters")
    for id, included in pairs(filters) do
      assert(id == 1214933 or id == 1214934 or id == 1214935 or id == 1214937)
      H.eq(included, true)
      self.filters[id] = true
    end
    H.auraSlotCount = H.auraSlotCount + 1
    local button = object("AuraButton", self)
    button.mouse = true
    options.initializeFrame(button)
    assert(next(button.scripts) == nil, "native aura buttons must not gain script handlers")
    assert(rawget(button, "animationGroups") == nil, "native aura buttons must not own add-on animations")
    local slot = { container = self, key = key, filters = filters, button = button }
    self.slots[key] = slot
    H.nativeSlots[#H.nativeSlots + 1] = slot
    button.shown = false
    button.sealed = true
    return button
  end
  local templates = {
    DialogBorderTranslucentTemplate = "Frame",
    UIPanelCloseButton = "Button",
    MinimalSliderWithSteppersTemplate = "Frame",
    InputBoxTemplate = "EditBox",
    UICheckButtonTemplate = "CheckButton",
    UIPanelButtonTemplate = "Button",
    WowStyle1DropdownTemplate = "DropdownButton",
    EditModeSystemSelectionTemplate = "Frame",
    CustomAuraContainerTemplate = "AuraContainer",
  }
  _G.CreateFrame = function(kind, name, parent, template)
    assert(name == nil and (parent == nil or type(parent) == "table"))
    if parent then
      check(parent)
    end
    if template then
      H.eq(templates[template], kind)
    else
      assert(kind == "Frame" or kind == "StatusBar" or kind == "Button")
    end
    local value = object(kind, parent, template)
    table.insert(H.frames, value)
    return value
  end
  _G.UIParent = object("Frame", nil)
  UIParent.width, UIParent.height = 1920, 1080
  _G.GameTooltip = object("GameTooltip", UIParent)
  GameTooltip.shown = false
  _G.LibStub = nil
  _G.CreateColor = function(r, g, b, a)
    assert(type(r) == "number" and type(g) == "number" and type(b) == "number" and type(a) == "number")
    return {
      GetRGBA = function()
        return r, g, b, a
      end,
    }
  end
  _G.Enum = {
    StatusBarFillStyle = { Standard = 0 },
    StatusBarTimerDirection = { RemainingTime = 1 },
    StatusBarInterpolation = { Immediate = 0 },
  }
  _G.issecretvalue = function(...)
    H.eq(select("#", ...), 1)
    return rawequal((...), secret)
  end
  _G.canaccesstable = function(...)
    H.eq(select("#", ...), 1)
    return not rawequal((...), secret)
  end
  _G.GetBuildInfo = function()
    return H.version, H.build, "Sep 3 2026", 120100
  end
  _G.IsLoggedIn = function()
    return H.loggedIn
  end
  _G.InCombatLockdown = function()
    return H.combat
  end
  _G.UnitAffectingCombat = function(unit, ...)
    H.eq(select("#", ...), 0)
    H.eq(unit, "player")
    return H.playerCombat
  end
  _G.InCinematic = function()
    return H.cinematic
  end
  _G.C_PetBattles = {
    IsInBattle = function()
      return H.petBattle
    end,
  }
  _G.C_Secrets = {
    ShouldAurasBeSecret = function()
      return H.restricted
    end,
  }
  _G.C_SpecializationInfo = {
    GetSpecialization = function()
      return 2
    end,
    GetSpecializationInfo = function(index)
      H.eq(index, 2)
      return H.spec
    end,
  }
  _G.C_SpellBook = {
    IsSpellKnown = function(id)
      H.eq(id, 1214909)
      return H.known
    end,
  }
  _G.C_AddOns = {
    GetAddOnMetadata = function(addon, key)
      H.eq(addon, "RollTheBonesSlots")
      H.eq(key, "Version")
      return "dev"
    end,
  }
  _G.C_UnitAuras = setmetatable({}, {
    __index = function()
      error("add-on must never read live aura data")
    end,
  })
  _G.C_Timer = {
    After = function(delay, fn)
      H.eq(delay, 0)
      assert(type(fn) == "function")
      table.insert(H.timers, fn)
    end,
  }
  _G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE = 1, 1
  _G.SlashCmdList, _G.SLASH_ROLLTHEBONESSLOTS1 = {}, nil
  _G.print = function(message)
    table.insert(H.messages, message)
  end
  _G.Settings = setmetatable({}, {
    __index = function()
      error("obsolete Blizzard Settings category used")
    end,
  })
  _G.MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = "OnValueChanged" } }
  _G.EditBox_ClearHighlight = function(box)
    H.eq(box.kind, "EditBox")
  end
  _G.EditModeSystemSelectionMixin, _G.EditModeSystemMixin = {}, {}
  _G.EditModeMagnetismManager = nil
  _G.EventRegistry = {
    RegisterCallback = function(_, event, fn, owner)
      assert(event == "EditMode.Enter" or event == "EditMode.Exit")
      assert(type(fn) == "function" and type(owner) == "table")
      assert(not H.callbacks[event], "duplicate Edit Mode callback")
      H.callbacks[event] = { fn = fn, owner = owner }
    end,
  }
  _G.hooksecurefunc = function(target, name, callback)
    assert(type(target) == "table" and type(target[name]) == "function" and type(callback) == "function")
    H.hookCount = H.hookCount + 1
    local original = target[name]
    target[name] = function(...)
      original(...)
      callback(...)
    end
  end
  function H.newManager()
    local manager = object("Frame", UIParent)
    manager.active, manager.snap = false, false
    function manager:IsEditModeActive()
      return self.active
    end
    function manager:IsSnapEnabled()
      return self.snap
    end
    function manager:SelectSystem(system)
      assert(type(system) == "table")
    end
    function manager:ClearSelectedSystem() end
    function manager:ShowSystemSelections() end
    function manager:HideSystemSelections() end
    _G.EditModeManagerFrame = manager
    return manager
  end
  H.newManager()
end

function H.fire(event, ...)
  -- Snapshot frame count, as real event delivery does not replay on new frames
  for index = 1, #H.frames do
    local frame = H.frames[index]
    if frame.events[event] then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

function H.enterEditMode()
  EditModeManagerFrame.active = true
  EditModeManagerFrame:Show()
  local callback = assert(H.callbacks["EditMode.Enter"])
  callback.fn(callback.owner)
end

function H.exitEditMode()
  EditModeManagerFrame.active = false
  local callback = assert(H.callbacks["EditMode.Exit"])
  callback.fn(callback.owner)
end

function H.advance(delta)
  assert(type(delta) == "number" and delta >= 0)
  H.clock = H.clock + delta
  for _, frame in ipairs(H.frames) do
    if frame.scripts.OnUpdate and frame:IsVisible() then
      frame.scripts.OnUpdate(frame, delta)
    end
  end
  for _, group in ipairs(H.animationGroups) do
    if group.playing and group.finishAt <= H.clock then
      H._finishAnimationGroup(group)
    end
  end
end

function H.flushTimers()
  local pending = H.timers
  H.timers = {}
  for _, fn in ipairs(pending) do
    fn()
  end
end

function H.findTemplate(template)
  for _, frame in ipairs(H.frames) do
    if frame.template == template then
      return frame
    end
  end
end

function H.button(text)
  for _, frame in ipairs(H.frames) do
    if frame.kind == "Button" and rawget(frame, "text") == text then
      return frame
    end
  end
  error("button missing: " .. text)
end

function H.cabinet()
  for _, frame in ipairs(H.frames) do
    if frame.width == 400 and frame.height == 246 then
      return frame
    end
  end
  error("cabinet missing")
end

function H.containers()
  local containers = {}
  for _, frame in ipairs(H.frames) do
    if frame.kind == "AuraContainer" then
      containers[#containers + 1] = frame
    end
  end
  return containers
end

-- Inspect authored strip regions without invoking any restricted native object
function H.reelRegions(parent)
  local regions = {}
  for _, child in ipairs(parent.children) do
    if child.kind == "Texture" then
      regions[#regions + 1] = child
    elseif child.kind == "Frame" and rawget(child, "allPoints") == parent then
      for _, region in ipairs(child.children) do
        if region.kind == "Texture" then
          regions[#regions + 1] = region
        end
      end
    end
  end
  return regions
end

return H

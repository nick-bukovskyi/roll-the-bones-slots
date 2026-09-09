-- Test the placement boundary with native-signature stubs, not native snap selection
return function(test, H, loadAddon)
  local function WithWorld(run)
    local ns = loadAddon()
    local names = {
      "UIParent",
      "CreateFrame",
      "EditModeManagerFrame",
      "EditModeMagnetismManager",
      "EditModeSystemMixin",
    }
    local saved = {}
    for _, name in ipairs(names) do
      saved[name] = _G[name]
    end
    local oldCanConfigure = ns.Game.CanConfigure
    local world = { allowed = true, queries = 0 }
    local function Rect(left, bottom, width, height, scale)
      local object = { left = left, bottom = bottom, width = width, height = height, scale = scale }
      function object:CanBeAccessedInContext()
        return true
      end
      function object:GetRect()
        return self.left, self.bottom, self.width, self.height
      end
      function object:GetCenter()
        return self.left + self.width / 2, self.bottom + self.height / 2
      end
      function object:GetScale()
        return self.scale
      end
      function object:GetEffectiveScale()
        return self.scale
      end
      function object:GetSize()
        return self.width, self.height
      end
      function object:GetPoint(index)
        assert(index == 1 or index == 2)
        return index == 1 and "TOPLEFT" or "BOTTOMRIGHT", self, "CENTER", 0, 0
      end
      function object:ClearAllPoints() end
      function object:SetPoint(point, relative, relativePoint, x, y)
        H.eq(point, "CENTER")
        H.eq(relative, UIParent)
        H.eq(relativePoint, "CENTER")
        self.savedX, self.savedY = x, y
      end
      return object
    end
    UIParent = Rect(0, 0, 1920, 1080, 1)
    world.frame = Rect(510, 330, 300, 180, 1.5)
    world.selection = world.frame
    ns.Game.CanConfigure = function()
      return world.allowed
    end
    EditModeManagerFrame = {
      IsEditModeActive = function()
        return true
      end,
      IsSnapEnabled = function()
        return true
      end,
    }
    EditModeSystemMixin = {
      GetScaledCenter = function(mover)
        local x, y = mover:GetCenter()
        return x * mover:GetScale(), y * mover:GetScale()
      end,
      GetSnapOffsets = function(_, info)
        return info.testOffsetX or 0, info.testOffsetY or 0
      end,
    }
    EditModeMagnetismManager = {
      topLevelParentCenterX = 960,
      topLevelParentCenterY = 540,
      topLevelParentLeft = 0,
      topLevelParentRight = 1920,
      topLevelParentBottom = 0,
      topLevelParentTop = 1080,
      topLevelParentWidth = 1920,
      topLevelParentHeight = 1080,
      GetMagneticFrameInfos = function(_, mover)
        H.eq(mover.frame, world.frame)
        world.queries = world.queries + 1
        return world.infos
      end,
      GetPreviewLineAnchors = function(_, info)
        assert(info.frame)
        return { "CenterVertical" }
      end,
    }
    CreateFrame = function(kind, name, parent)
      H.eq(kind, "Frame")
      H.eq(name, nil)
      H.eq(parent, UIParent)
      local preview = { scripts = {} }
      function preview:SetAllPoints(relative)
        H.eq(relative, UIParent)
      end
      function preview:SetFrameStrata(strata)
        H.eq(strata, "HIGH")
      end
      function preview:EnableMouse(value)
        H.eq(value, false)
      end
      function preview:SetScript(event, fn)
        self.scripts[event] = fn
      end
      function preview:Show()
        self.shown = true
      end
      function preview:Hide()
        self.shown = false
        if self.scripts.OnHide then
          self.scripts.OnHide(self)
        end
      end
      function preview:CreateLine(name, layer, template)
        H.eq(name, nil)
        H.eq(layer, "OVERLAY")
        H.eq(template, "MagnetismPreviewLineTemplate")
        return {
          Hide = function() end,
          ClearAllPoints = function() end,
          Setup = function(_, info, anchor)
            assert(info.frame)
            H.eq(anchor, "CenterVertical")
          end,
        }
      end
      world.preview = preview
      return preview
    end
    world.Rect = Rect
    local ok, failure = pcall(run, ns.EditModeSnap, world)
    ns.EditModeSnap.Finish(false)
    ns.Game.CanConfigure = oldCanConfigure
    for _, name in ipairs(names) do
      _G[name] = saved[name]
    end
    if not ok then
      error(failure, 0)
    end
  end

  test("grid placement converts screen displacement to saved cabinet scale on both axes", function()
    WithWorld(function(Snap, world)
      for _, scale in ipairs({ 0.1, 0.6, 1, 1.8 }) do
        world.frame.scale = scale
        world.infos = {
          {
            frame = UIParent,
            point = "CENTER",
            relativePoint = "CENTER",
            isHorizontal = true,
            testOffsetX = 240 / scale,
          },
          {
            frame = UIParent,
            point = "CENTER",
            relativePoint = "CENTER",
            isHorizontal = false,
            testOffsetY = -90 / scale,
          },
        }
        Snap.Begin(world.frame, world.selection)
        Snap.Finish(true)
        assert(math.abs(world.frame.savedX - 240 / scale) < 0.00001)
        assert(math.abs(world.frame.savedY + 90 / scale) < 0.00001)
        H.eq(world.preview.shown, false)
        H.eq(world.preview.scripts.OnUpdate, nil)
      end
    end)
  end)

  test("element corner snaps resolve to UIParent instead of anchoring to the target", function()
    WithWorld(function(Snap, world)
      local target = world.Rect(1500, 875, 200, 100, 0.8)
      target.SetPoint = function()
        error("must not mutate snap target")
      end
      world.infos = {
        {
          frame = target,
          point = "TOPLEFT",
          relativePoint = "TOPRIGHT",
          isCornerSnap = true,
        },
      }
      Snap.Begin(world.frame, world.selection)
      Snap.Finish(true)
      assert(math.abs(world.frame.savedX - 625 / 1.5) < 0.00001)
      H.eq(world.frame.savedY, 70)
    end)
  end)

  test("restrictions arriving during drag cancel snapping without another native geometry query", function()
    WithWorld(function(Snap, world)
      world.infos = {
        {
          frame = UIParent,
          point = "CENTER",
          relativePoint = "CENTER",
          isHorizontal = true,
        },
      }
      Snap.Begin(world.frame, world.selection)
      local queries = world.queries
      world.allowed = false
      Snap.Finish(true)
      H.eq(world.queries, queries)
      H.eq(world.frame.savedX, nil)
      H.eq(world.preview.shown, false)
      H.eq(world.preview.scripts.OnUpdate, nil)
    end)
  end)
end

-- Owns account-wide preferences, never active roll or aura state
local _, ns = ...

local Config = {}
ns.Config = Config

local SCHEMA_VERSION = 3
local MIN_SCALE, MAX_SCALE = 0.1, 1.8
local DEFAULTS = {
  scale = 1,
  x = 0,
  y = 140,
  animationEnabled = true,
  durationBarEnabled = true,
  compactMode = false,
  visibility = "always",
}
local VISIBILITY_OPTIONS = {
  { value = "always", label = "Always" },
  { value = "active", label = "When buff is active" },
  { value = "combat", label = "In combat" },
}
local DISPLAY_MODE_OPTIONS = {
  { value = false, label = "Full" },
  { value = true, label = "Compact" },
}
local database
local readOnly = false

local function IsFiniteNumber(value)
  return not issecretvalue(value) and type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function IsScale(value)
  return IsFiniteNumber(value) and value >= MIN_SCALE and value <= MAX_SCALE
end

local function IsVisibility(value)
  if issecretvalue(value) or type(value) ~= "string" then
    return false
  end
  for _, option in ipairs(VISIBILITY_OPTIONS) do
    if option.value == value then
      return true
    end
  end
  return false
end

local function ApplyDefaults(root)
  for key, value in pairs(DEFAULTS) do
    root[key] = value
  end
  root.schemaVersion = SCHEMA_VERSION
end

function Config.Initialize(savedRoot)
  local root = savedRoot
  if issecretvalue(root) or type(root) ~= "table" or not canaccesstable(root) then
    root = {}
  end

  local version = root.schemaVersion
  readOnly = IsFiniteNumber(version) and version > SCHEMA_VERSION
  if readOnly then
    -- Preserve newer data untouched until its matching add-on is restored
    database = {}
    ApplyDefaults(database)
  else
    if not IsScale(root.scale) then
      root.scale = DEFAULTS.scale
    end
    if not IsFiniteNumber(root.x) then
      root.x = DEFAULTS.x
    end
    if not IsFiniteNumber(root.y) then
      root.y = DEFAULTS.y
    end
    if issecretvalue(root.animationEnabled) or type(root.animationEnabled) ~= "boolean" then
      root.animationEnabled = DEFAULTS.animationEnabled
    end
    if issecretvalue(root.durationBarEnabled) or type(root.durationBarEnabled) ~= "boolean" then
      root.durationBarEnabled = DEFAULTS.durationBarEnabled
    end
    -- Schema 2 adds visibility without changing existing position units or choices
    if not IsVisibility(root.visibility) then
      root.visibility = DEFAULTS.visibility
    end
    -- Schema 3 keeps the original layout unless the player enables compact mode
    if issecretvalue(root.compactMode) or type(root.compactMode) ~= "boolean" then
      root.compactMode = DEFAULTS.compactMode
    end
    root.schemaVersion = SCHEMA_VERSION
    database = root
  end

  _G.RollTheBonesSlotsDB = root
  return root
end

function Config.IsReadOnly()
  return readOnly
end

function Config.GetScale()
  return database.scale
end

function Config.GetScaleRange()
  return MIN_SCALE, MAX_SCALE
end

function Config.GetPosition()
  return database.x, database.y
end

function Config.GetAnimationEnabled()
  return database.animationEnabled
end

function Config.GetDurationBarEnabled()
  return database.durationBarEnabled
end

function Config.GetCompactMode()
  return database.compactMode
end

function Config.GetDisplayModeOptions()
  return DISPLAY_MODE_OPTIONS
end

function Config.GetVisibility()
  return database.visibility
end

function Config.GetVisibilityOptions()
  return VISIBILITY_OPTIONS
end

function Config.SetScale(value)
  if not database or readOnly or not IsFiniteNumber(value) then
    return false
  end
  value = math.max(MIN_SCALE, math.min(MAX_SCALE, value))
  -- Anchors use the display's scale; preserve their displacement on the screen
  local ratio = database.scale / value
  local x, y = database.x * ratio, database.y * ratio
  if not IsFiniteNumber(x) or not IsFiniteNumber(y) then
    return false
  end
  database.x, database.y = x, y
  database.scale = value
  return true
end

function Config.SetPosition(x, y)
  if not database or readOnly or not IsFiniteNumber(x) or not IsFiniteNumber(y) then
    return false
  end
  database.x, database.y = x, y
  return true
end

function Config.SetAnimationEnabled(value)
  if not database or readOnly or issecretvalue(value) or type(value) ~= "boolean" then
    return false
  end
  database.animationEnabled = value
  return true
end

function Config.SetDurationBarEnabled(value)
  if not database or readOnly or issecretvalue(value) or type(value) ~= "boolean" then
    return false
  end
  database.durationBarEnabled = value
  return true
end

function Config.SetCompactMode(value)
  if not database or readOnly or issecretvalue(value) or type(value) ~= "boolean" then
    return false
  end
  database.compactMode = value
  return true
end

function Config.SetVisibility(value)
  if not database or readOnly or not IsVisibility(value) then
    return false
  end
  database.visibility = value
  return true
end

function Config.Reset()
  if not database or readOnly then
    return false
  end
  ApplyDefaults(database)
  return true
end

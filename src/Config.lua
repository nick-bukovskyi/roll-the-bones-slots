-- Owns account-wide preferences, never active roll or aura state
local _, ns = ...

local Config = {}
ns.Config = Config

local SCHEMA_VERSION = 1
local MIN_SCALE, MAX_SCALE = 0.6, 1.8
local DEFAULTS = { scale = 1, x = 0, y = -180, animationEnabled = true }
local database
local readOnly = false

local function IsFiniteNumber(value)
    return not issecretvalue(value) and type(value) == "number"
        and value == value and value ~= math.huge and value ~= -math.huge
end

local function IsScale(value)
    return IsFiniteNumber(value) and value >= MIN_SCALE and value <= MAX_SCALE
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
        if not IsScale(root.scale) then root.scale = DEFAULTS.scale end
        if not IsFiniteNumber(root.x) then root.x = DEFAULTS.x end
        if not IsFiniteNumber(root.y) then root.y = DEFAULTS.y end
        if issecretvalue(root.animationEnabled) or type(root.animationEnabled) ~= "boolean" then
            root.animationEnabled = DEFAULTS.animationEnabled
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

function Config.SetScale(value)
    if not database or readOnly or not IsScale(value) then return false end
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

function Config.Reset()
    if not database or readOnly then return false end
    ApplyDefaults(database)
    return true
end

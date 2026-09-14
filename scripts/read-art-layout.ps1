# Read the same asset catalogue and geometry used by the addon. Requires Lua on PATH.
[CmdletBinding()]
param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$metadata = @'
local root = assert(arg[1], "Project root is required")
local ns = {}
for _, file in ipairs({ "Appearance", "Layouts" }) do
  assert(loadfile(root .. "/src/" .. file .. ".lua"))("RollTheBonesSlots", ns)
end
local function json(value)
  if type(value) == "number" then return tostring(value) end
  if type(value) == "string" then return string.format("%q", value) end
  assert(type(value) == "table", "Unsupported artwork metadata")
  local fields = {}
  if #value > 0 then
    for _, child in ipairs(value) do fields[#fields + 1] = json(child) end
    return "[" .. table.concat(fields, ",") .. "]"
  end
  for key, child in pairs(value) do fields[#fields + 1] = json(key) .. ":" .. json(child) end
  return "{" .. table.concat(fields, ",") .. "}"
end
local appearance, layouts = ns.Appearance, ns.Layouts
local cabinets, assets = {}, {}
for _, cabinet in ipairs(appearance.Cabinets) do
  for _, layout in ipairs({ layouts.Full, layouts.Compact }) do
    local sx, sy = layouts.TextureWidth / layouts.Width, layout.textureHeight / layout.height
    local function rect(x, y, width, height)
      return { x * sx, y * sy, (x + width) * sx, (y + height) * sy }
    end
    local wells = {}
    for _, column in ipairs(layouts.Columns) do
      wells[#wells + 1] = rect(column.x, layout.reels.y, column.width, layout.reels.height)
    end
    local asset = {
      name = appearance.CabinetStem(cabinet, layout),
      width = layouts.TextureWidth, height = layout.textureHeight,
      runtimeWidth = layouts.TextureWidth, runtimeHeight = layout.runtimeTextureHeight,
      wells = wells, footer = rect(layouts.Footer.x, layout.footer.y, layouts.Footer.width, layout.footer.height),
      label = cabinet.label, titleColor = cabinet.titleColor,
    }
    if layout.title then
      local title = layout.title
      asset.title = rect(title.x, title.y, title.width, title.height)
    end
    cabinets[#cabinets + 1], assets[#assets + 1] = asset, asset
  end
end
local icons = appearance.Icons
assets[#assets + 1] = {
  name = icons.file, width = icons.width, height = icons.height,
  runtimeWidth = icons.width, runtimeHeight = icons.height,
}
print(json({ cabinets = cabinets, assets = assets, insetColor = appearance.InsetColor, icons = icons }))
'@ | & lua - $ProjectRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not read the addon artwork catalogue using Lua' }
$metadata | ConvertFrom-Json

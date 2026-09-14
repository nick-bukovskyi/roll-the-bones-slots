-- Asset definitions are independent of layout, gameplay results and saved choices
local _, ns = ...
local Appearance = {}
ns.Appearance = Appearance

-- Opaque wells and footer backing are shared by every cabinet and icon pack.
Appearance.InsetColor = { 9 / 255, 10 / 255, 12 / 255, 1 }

Appearance.Cabinets = {
  { value = "captains-walnut", label = "Captain's Walnut", titleColor = { 0.15, 0.09, 0.035, 1 } },
  { value = "sailors-case", label = "Sailor's Case", titleColor = { 1, 0.82, 0.24, 1 } },
  { value = "tavern-oak", label = "Tavern Oak", titleColor = { 0.96, 0.9, 0.72, 1 } },
  { value = "ironbound-case", label = "Ironbound Case", titleColor = { 1, 0.82, 0.24, 1 } },
  { value = "oxblood-travel-case", label = "Oxblood Travel Case", titleColor = { 1, 0.82, 0.24, 1 } },
}
Appearance.DefaultCabinet = Appearance.Cabinets[1].value

function Appearance.GetCabinet(value)
  for _, cabinet in ipairs(Appearance.Cabinets) do
    if cabinet.value == value then
      return cabinet
    end
  end
end

function Appearance.CabinetStem(cabinet, layout)
  return "cabinet-" .. cabinet.value .. layout.cabinetSuffix
end

-- Packs retain these logical roles, regardless of their atlas packing or materials
-- Ivory die, anchor, wheel, rum, Jackpot die, boot, goblin; the coin is celebration-only
Appearance.Icons = {
  file = "symbols",
  width = 1024,
  height = 1024,
  nominalSize = 384,
  symbols = {
    { 0, 0, 336, 336 },
    { 336, 0, 336, 336 },
    { 672, 0, 336, 336 },
    { 0, 336, 336, 336 },
    { 336, 336, 336, 336 },
    { 672, 336, 336, 336 },
    { 0, 672, 336, 336 },
  },
  coin = { 336, 672, 336, 336 },
}

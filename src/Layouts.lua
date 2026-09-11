-- Authored mode definitions; shared columns and footer content keep the same horizontal alignment
local _, ns = ...
local Layouts = {
  Width = 400,
  Columns = { { x = 37, width = 104 }, { x = 148, width = 103 }, { x = 260, width = 103 } },
  Footer = { x = 44, width = 312, iconSize = 16 },
}
ns.Layouts = Layouts

Layouts.Full = {
  height = 246,
  cabinet = "cabinet.tga",
  textureBottom = 630 / 1024,
  title = { x = 56, y = 9, width = 288, height = 22 },
  reels = { y = 39, height = 153, symbolScale = 1 },
  footer = { y = 205, height = 26, textHeight = 22, fontSizeOffset = 0 },
}

Layouts.Compact = {
  height = 140,
  cabinet = "cabinet-compact.tga",
  textureBottom = 360 / 512,
  reels = { y = 22, height = 80, symbolScale = 0.75 },
  footer = { y = 110, height = 18, textHeight = 18, fontSizeOffset = -1 },
}

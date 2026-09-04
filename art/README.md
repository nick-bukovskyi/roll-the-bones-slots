# Machine artwork

Generated with the built-in imagegen tool on 2026-09-04 from the approved wooden Outlaw mockup. Only the cabinet and reel symbols are authored textures. Blizzard supplies fonts, settings controls, selection handles and snap guides.

## Files

- `cabinet-source.png`, `symbols-source.png`: retained original generated sheets
- `rum-source.png`: retained generated edit; only its lower-right bottle cell is used
- `jackpot-source.png`: retained standalone generated open-chest sprite with genuine alpha
- `cabinet.png`, `symbols.png`, `jackpot.png`: generated PNG equivalents, ignored by Git
- `../media/jackpot.tga`: standalone 512x512 uncompressed 32-bit BGRA Jackpot texture
- `../media/cabinet.tga`, `../media/symbols.tga`: packaged 1024x1024 uncompressed 32-bit BGRA textures
- `../scripts/export-art.ps1`: reproducible mechanical extraction and TGA conversion

Rebuild textures from the repository directory with `./scripts/export-art.ps1` on
Windows with PowerShell 7. The original source sheets, exporter and runtime TGAs
are versioned. Generated PNGs and the local browser preview, server, snapshot
exporter and captured frames are deliberately excluded from Git. A clean clone
contains the add-on and regression tests, not that temporary web harness.

The generator produced opaque checkerboard sheets despite the transparency request. The requested texture cutting removes background-connected neutral checkerboard and the two enclosed sword-guard openings. The cabinet is cropped to its silhouette and padded to a power-of-two texture; its 630-pixel used height is mapped in Art.lua. No baked-in label or settings artwork is included. Original source files are preserved.

The rum-bottle replacement also used the built-in imagegen tool. Its source is an
opaque checkerboard edit, so export cuts only its lower-right cell, centers the
bottle at a maximum 370-pixel extent, and replaces only that cell in the original
atlas. The original dice, gold coin and cutlasses are preserved, not regenerated.
Sources with four non-opaque corners retain their alpha, including tiny nonzero
corner alpha. The chest uses genuine generated transparency, centered to the same
maximum 370-pixel extent within a 512-pixel square as the rum bottle. It does not
change the ordinary atlas. Symbol five is exclusive to the Jackpot centers and its
labeled editor sample; ordinary spin, idle and adjacent rows stay within symbols
one through four. The native buff icon is unchanged.

Non-winning randomization reuses these assets without altering pixels. Reel one
has one prebuilt strip; reels two and three each have three side-by-side strips
spaced 128 UI units apart. The ordinary carrier selects a strip while the fixed
window clips its neighbors. The local-only browser validation captured all six distinct filler pairs
from the Lua animation and selects a captured variation for each Test/Slow spin;
random repeats were allowed. No browser-generated symbol layout substituted for
the Lua artwork, and no native aura data is included in the captures.

## Cabinet prompt

Use case: background-extraction / precise-object-edit.
Asset type: production game UI cabinet texture with genuine transparent alpha, not a mockup.
Input image 1 is the approved design edit target. Extract ONLY the large upper wooden slot machine, completely discard the lower examples, settings window, words outside the machine, and background. Preserve exactly its dark weathered treasure chest oak, narrow antique dark gold edges, tiny skull corner patches, modest curved side braces with cutlass engravings, three straight reel wells, and integrated bottom result plaque. No redesign, no new crest or lever.
Remove ALL text, all dice, coins, swords and other reel symbols, and the small footer icon. Keep the top title area and bottom footer plaque as empty dark wooden backgrounds. Keep the THREE reel interiors empty dark subtly textured black vertical wells, with their existing thin brass separators. They must contain NO icons, NO text. They are opaque dark backing for moving separate sprites.
Entire outside silhouette must be genuinely transparent, not black and not a checkerboard painted into the image. Orthographic front view, unchanged proportions, generous small transparent margin about 2 percent only; one machine only filling canvas. High quality sharp painted World of Warcraft UI materials. Intended cropped aspect around 1.65:1, request 1536x1024 if needed, maintain machine proportions rather than stretching. No settings or controls.

## Symbol-sheet prompt

Use case: stylized-concept.
Asset type: production transparent game UI sprite atlas, one square1024x1024 sheet.
Input image1 is visual/material reference ONLY, not a layout to reproduce. Extract the look of its reel symbols into four isolated hand-painted World of Warcraft Outlaw rogue symbols on genuinely transparent alpha. Exactly a perfectly aligned2x2 grid of equal512x512 cells: upperleft ivory bone gambling die with dark red top and bone cross marks; upperright heavy antique gold coin with embossed skull face; lowerleft crossed dark silver cutlasses with brown handles; lowerright ivory skull in a round dark brass medallion, no green glow. Each symbol centered exactly in its cell, max visible bounds360x360, consistent crisp lighting/painted style and scale. All four complete fully visible, generous transparent space around every symbol. No cell borders, no labels or numbers, no slots, no machine, no settings, no background texture, no drop shadow beyond each icon, no checkerboard painted into RGB. This is a sprite sheet for moving reels, not a presentation mockup. Match the approved reference symbols closely.

## Rum-bottle edit prompt

Mode: built-in imagegen. Input: `symbols.png` before replacement. Output source:
`rum-source.png`. This prompt is retained verbatim:

Use case: precise-object-edit.
Asset type: production World of Warcraft Outlaw rogue reel-symbol sprite atlas.
Input image 1 is the EDIT TARGET: the existing transparent 1024x1024 atlas.
Replace ONLY the lower-right skull medallion/coin with a pirate rum bottle. Keep the upper-left bone die, upper-right gold skull coin, and lower-left crossed cutlasses unchanged in appearance, position and scale. Keep the exact 2x2 equal-cell atlas layout.
Bottle: a stout, broad-shouldered amber-brown glass rum bottle, a short neck and cork, worn dark-red wax seal and cloth around the neck, restrained antique-gold accents, and a weathered parchment label with a simple small pirate skull motif but NO lettering. No round coin or round medallion behind it. Slight lively tilt, entire bottle clearly visible. Its compact silhouette should read immediately at small in-game icon size and feel equally substantial to the other symbols.
Match the existing crisp hand-painted Warcraft UI style, weathered materials, warm upper-left highlights and dark outline. Not photorealistic, not flat vector art. Lower-right bottle centered within the 512x512 cell, roughly 370 pixels high and at most 370 pixels wide, with generous clear padding, no cropping and no overlap into other cells.
Genuinely transparent alpha around all symbols. No opaque white/black/checkerboard background, no drop shadow outside the object, no scenery, no frame, no captions, no watermark.
Preserve all other artwork and the square canvas.

## Jackpot chest prompt

Mode: built-in imagegen, new standalone sprite. The existing atlas in the
conversation was a style reference, not an edit target. Source saved as
`jackpot-source.png`; final exports are `jackpot.png` and `../media/jackpot.tga`.
This prompt is retained verbatim:

Use case: stylized-concept
Asset type: one standalone transparent game UI reel-symbol sprite for a World of Warcraft Outlaw Rogue treasure-chest slot-machine addon
Primary request: an open pirate treasure chest overflowing with gold coins and a few rich emerald-green gemstones, the exclusive Jackpot symbol
Style/medium: hand-painted fantasy game inventory icon, matching the existing bone dice, worn gold skull coin, dark steel cutlasses and amber rum bottle artwork in the conversation. Chunky readable shapes, bevelled worn gold fittings, deep carved dark-brown wood, painterly highlights and dark recesses. World of Warcraft UI aesthetic, not photorealistic, not modern casino graphics
Composition/framing: exactly one chest centered, subtle three-quarter view, lid clearly open, compact approximately square silhouette, generous transparent padding on all four sides. Whole object visible. Strong readable shape at 80 pixels. Treasure mostly contained in the chest, no scattered separate props
Lighting/mood: warm restrained gold highlights from upper left, emerald accents, substantial dark edge contrast. No surrounding glow or shadow cloud
Scene/backdrop: genuinely transparent background with clean alpha edges; NOT a painted checkerboard, no ground or scene, no border or badge
Constraints: one standalone chest only, no dice, no bottle, no swords, no coin medallion, no UI cabinet or settings. No letters, words, numbers, logos or watermark. Do not reproduce the reference atlas. Deliver a clean square raster sprite with real transparency

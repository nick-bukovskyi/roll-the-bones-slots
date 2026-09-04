# Machine artwork

## Authoritative assets

- `cabinet.png`: finished transparent 1024x630 cabinet
- `symbols.png`: finished transparent 1024x832 atlas containing all five reel symbols
- `README.md`: this layout and editing guide

Edit these PNGs directly. They are the only artwork inputs. The old generation
sheets and separate icon sources have been removed; they are not needed to build.
Existing tracked originals remain available in Git history. The consolidation
copied the approved pixels without resizing, recoloring or changing visible placement.

`../media/cabinet.tga` and `../media/symbols.tga` are generated runtime files,
not alternative masters. The exporter copies each PNG to the top-left of a
transparent 1024x1024 TGA. This keeps both runtime texture edges at powers of two,
as required by [current custom-texture guidance](https://warcraft.wiki.gg/wiki/API:TextureBase_SetTexture), while leaving unrelated padding
out of the editable artwork. Every source pixel is unchanged and every generated
padding pixel is transparent. The local browser creates the same square runtime
canvas in memory from the canonical PNGs.
Temporary preview HTML and frame snapshots live under `../artifacts/preview/`
and are excluded from Git and the player package.

## Atlas layout

Pixel rectangles use top-left origin and exclusive right/bottom edges.
`src/Art.lua` owns the runtime rectangle mapping.

| ID | Symbol | X | Y | Width | Height |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | Bone die | 0 | 0 | 344 | 416 |
| 2 | Gold skull coin | 344 | 0 | 376 | 416 |
| 3 | Crossed cutlasses | 720 | 0 | 304 | 416 |
| 4 | Rum bottle | 0 | 416 | 512 | 416 |
| 5 | Jackpot chest | 512 | 416 | 512 | 416 |

Each rectangle is a centered crop of its original 512x512 symbol canvas.
Only transparent padding was removed. At nominal size 112, a sprite's actual
rectangle is `112 * width / 512` by `112 * height / 512`; its center stays fixed.
This preserves the exact visible size and position, including the prior centering
fix. Retain the transparent gutters inside each rectangle so linear filtering
cannot sample neighboring artwork. The atlas ends at the bottom edge of those
gutters; it has no unrelated reserve below them.

Jackpot shares the atlas, but remains symbol 5 exclusively for native Jackpot
centers and the labeled sample. Decorative/idle rows use symbols 1 through 4.
The native buff footer continues to use Blizzard's icon.

## Editing and export

1. Edit only the intended symbol rectangle in `symbols.png`, preserving alpha,
   transparent gutters and the other symbols. Do not recreate a source-sheet overlay chain.
2. Run `pwsh -NoProfile -File scripts/export-art.ps1` from the repository root.
   The exporter copies the PNG pixels to an uncompressed BGRA32 TGA with top-left
   origin, then adds transparent bottom rows to reach the required 1024x1024
   runtime size. It does not key backgrounds, crop or resize artwork, relocate
   icons or modify the PNGs.
3. Run `pwsh -NoProfile -File scripts/export-art.ps1 -Check` to reject missing or
   stale runtime exports without changing files.
4. Run the Lua, art-export and package checks, then build the development ZIP.
   Commit the canonical PNGs and their matching runtime exports together when committing is authorized.

All five symbols use one 4 MiB texture instead of the previous 4 MiB atlas plus
1 MiB chest texture. The cabinet stays at 4 MiB. These are uncompressed pixel
payloads, not a measured GPU-memory or frame-rate improvement.

## Artwork provenance

The cabinet and icons were generated with built-in imagegen on 2026-09-04 and
approved through iterative previews. Consolidation performs no new generation.
The original cabinet/symbol/rum/chest prompts are recorded in Git history.
The latest narrower-sword prompt is retained below for reference; future editing
uses the finished atlas, not a separate sword source.

Use case: precise-object-edit
Asset type: one standalone transparent production game UI reel-symbol sprite.
Input image 1 is a style and object reference: the lower-left crossed cutlasses in the existing atlas. Recreate ONLY those two crossed cutlasses as a compact, narrower, more upright X. Do not reproduce the atlas or any other symbols.
Primary request: correct the overly wide crossed-swords silhouette so it fits comfortably in a narrow slot-machine reel beside the existing dice and coin. The complete pair should be slightly taller than wide, visible silhouette width about 90 percent of its height. Bring the blade tips and handle ends inward by making the crossed blades more upright, not by distorting their thickness. Both swords equal in visual weight with balanced left/right edges, pair centered horizontally and vertically.
Keep the reference's distinctive curved dark-steel cutlasses, worn bright silver cutting edges and little blade notches, antique-gold knuckle guards, brown wrapped grips, warm upper-left painterly highlights, dark readable outline, restrained Warcraft Outlaw pirate palette. Preserve the same hand-painted fantasy inventory-icon material style. No glow, no ornate new emblem.
Composition: exactly one crossed pair, entire tips and handles visible, centered on square canvas, generous transparent padding on all sides. It must read crisply when displayed roughly 75 pixels wide.
Background: genuine transparent alpha, including the openings inside both knuckle guards and between the blades. No painted checkerboard, no opaque black or white background, no scenery, no ground or external cast shadow, no frame, no text, no watermark, no dice, coin, bottle or chest.

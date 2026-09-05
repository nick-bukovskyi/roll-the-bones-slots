# Roll the Bones Slots

A treasure-chest slot display for Outlaw Rogue. Three reels show your current
Roll the Bones result, with its native buff icon, name and remaining time below.
An optional gold bar drains as the buff expires. Cast with your normal action buttons.

Targets **Retail live 12.1.0, build 69587, Interface 120100**. Other builds, Classic,
PTR and beta are unsupported. This is a development candidate awaiting final
in-game verification.

## Installation

Extract the package into your Retail `Interface/AddOns` folder so the TOC is at
`Interface/AddOns/RollTheBonesSlots/RollTheBonesSlots.toc`. Restart WoW, enable
**Roll the Bones Slots**, and log into an Outlaw Rogue who knows Roll the Bones.

## Controls

Open Blizzard **Edit Mode** and select the highlighted chest.

- Drag to position it. Blizzard's snapping option enables grid and element snapping.
- Set **Display scale** from 60% to 180% using the slider or percentage field.
  Enter or leaving the field applies it; Escape cancels the edit.
- Choose **Show display**: **Always**, **When buff is active**, or **In combat**.
- Toggle **Animate reels and wins** for reduced motion.
- Toggle **Show duration bar** independently of the buff name and timer.
- Use **Test spin** to cycle through four sample results and an empty sample.
- Use the eye button to hide or show the highlight while keeping the chest draggable.
- **Reset to Defaults** restores position, scale, visibility, animation and the bar.

Preferences save immediately and account-wide. Blizzard's Edit Mode Save and
Cancel buttons do not commit or undo them. Defaults are 100% scale, just above
screen center, Always visibility, animation on and duration bar on.
Editing is suspended during combat and restricted encounters.

EnhanceQoL is optional. Selecting the chest or another element closes the previous
settings window. Highlight syncing supports EnhanceQoLEditMode-1.0 revision
21000001; the next local or global eye click takes precedence for that session.

## Results

| Buff | Center symbols |
| --- | --- |
| One of a Kind | One die and two different coin, cutlass or rum symbols |
| Double Trouble | Two dice and one coin, cutlass or rum symbol |
| Triple Threat | Three dice |
| Jackpot | Three treasure chests |

Only non-winning symbols vary between rolls. Jackpot chests never appear in
decorative spinning rows or the empty display. Without a buff, the display shows
dim symbols and **Try yer luck, matey!**

Identifiable casts start a short cosmetic spin, followed by two pulses behind
winning reels or three for Jackpot. Keep It Rolling and other duration updates
do not start a spin. Hover the bottom buff row for its native tooltip.

## Known limitations

- A drag interrupted by combat or encounter restrictions can leave the chest at
  an unsaved position; a later scale change may move it back. Fixing this is an
  outstanding release requirement.
- Spins and flashes follow fixed timing. Delayed buff updates or rapid rerolls
  can briefly show or highlight the previous result. A flash does not confirm
  the newest cast won Jackpot.
- Combat restrictions may prevent a cosmetic spin. Blizzard still owns the live
  buff selection, duration and expiration; the add-on does not guess hidden results.
- Buff tooltips stay beside the chest and are hidden in combat.
- Preferences are independent of Blizzard layouts. There are no slash commands,
  separate AddOns Settings page, reroll advice, history, chat announcements or sounds.

See [CHANGELOG.md](CHANGELOG.md) for player-facing changes.

## Development

Use PowerShell 7 on Windows for the artwork and package scripts, and a desktop
Lua runner for off-client tests. Run from the repository root:

```powershell
lua tests/runner.lua
./tests/art_export_spec.ps1
./tests/package_spec.ps1
./scripts/package.ps1
```

Packaging derives the version and Lua load list from the TOC, checks the canonical
artwork exports, and verifies every archived path and file hash. Output is
`dist/RollTheBonesSlots-<TOC version>.zip`. It does not install or upload.
Only the TOC, runtime Lua, README, changelog and three TGA textures ship.

`art/` contains the editable PNGs; `media/` contains their committed runtime
exports. See [art/README.md](art/README.md) for editing and export commands.
Lua formatting uses [StyLua](https://github.com/JohnnyMorganz/StyLua) and
`.stylua.toml`: run `stylua --check src tests` to check or
`stylua --verify src tests` to format.

| Code | Responsibility |
| --- | --- |
| `Config.lua` | Saved preferences, validation and schema upgrades |
| `Game.lua` | Client eligibility, authored buff definitions and native aura setup |
| `Art.lua` | Shared geometry, textures and animation construction |
| `Machine.lua` | Presentation, cosmetic motion and positioning |
| `EditModeSnap.lua` | Build-specific Blizzard snapping adapter |
| `Settings.lua` | Editor controls |
| `EditMode.lua` | Editor lifecycle, selection and optional EnhanceQoL integration |
| `Core.lua` | Loading, game events and presentation decisions |

The TOC lists these modules in dependency order. Native aura children are built
once and never read or changed by add-on Lua after initialization. Preview
artwork and cosmetic variants are separate from Blizzard's active buff state.

API evidence is pinned to the `live` mirror commit
[`8ea15b61`](https://github.com/Gethe/wow-ui-source/tree/8ea15b61e45c0ed4eba01439c90757f86eb78d34);
its [version.txt](https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/version.txt)
matches 12.1.0.69587. See Blizzard's
[aura API announcement](https://us.forums.blizzard.com/en/wow/t/addons-and-auras-in-curse-of-ula%E2%80%99tek/2317456/).
Re-audit the native aura and private Edit Mode boundaries before changing support.

Tests load the real TOC with strict API stubs. They cover preferences, migrations,
presentation, lifecycle, motion, controls and package contracts. They cannot prove
native rendering, restricted combat, taint or performance.

Before release, install the exact candidate ZIP and verify all four buffs,
rerolls, extensions and expiration; login/reload and upgrades; combat and
restricted dungeon/raid/PvP encounters; death and recovery; spec/talent changes;
loading screens, hidden UI, cinematics, movies, pet battles and vehicle/override
UI; Edit Mode, snapping and EnhanceQoL; and 60%, 100%, 180% scale with both bar
and animation settings. Repeat transitions and check a long session for stale
output, Lua errors, blocked actions and accumulating work. Current-package
in-game proof remains outstanding. Choose a release version in the TOC only
when the release is confirmed.

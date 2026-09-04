# Roll the Bones Slots

A small treasure-chest slot machine for Outlaw Rogue. Its three reels show your
Roll the Bones rank, with the real buff name, icon and remaining time below them.
Cast using your normal action buttons.

## Development build for testing

Targets **Retail live 12.1.0.69587, Interface 120100 only**. The user confirmed this
client with GetBuildInfo. Classic, PTR, beta and other builds are not supported.

The previous landing prototype received positive user feedback, but a screenshot
showed an internal edge cutting a lower symbol in the third reel. This continuous-strip
fix, exclusive Jackpot chest and randomized non-winning symbols still need in-game verification. Earlier
feedback is not full combat proof.

1. Exit WoW and extract `dist/RollTheBonesSlots-dev.zip` into your Retail
   `Interface/AddOns` folder. The resulting path must be
   `Interface/AddOns/RollTheBonesSlots/RollTheBonesSlots.toc`.
2. Start WoW and enable **Roll the Bones Slots** in the AddOns list.
3. Log into an Outlaw Rogue who knows Roll the Bones.
4. Open Blizzard **Edit Mode**, then click the highlighted **Roll the Bones Slots**
   display to open its controls.

The corrected Interface metadata replaces the initial package that appeared as
Incompatible. Load out of date AddOns is not needed on the target client. The
project does not install itself, change CVars or edit your existing player data.

## Edit Mode controls

- Drag the highlighted chest to position it. Enable Blizzard's snapping option
  to align with its grid and eligible Blizzard UI elements.
- Adjust **Display scale** with the slider or percentage field, from 60% to 180%.
- Turn off **Animate reels** for reduced motion.
- Use **Test spin** to cycle through the four labeled sample results and an idle sample.
- Use **Reset to Defaults** to restore position, scale and animation preferences.

Changes save immediately and apply account-wide. They are not tied to a Blizzard
layout, and Blizzard's Save or Cancel buttons do not commit or undo these choices.
The default is 100% scale below screen center, with animation enabled. There are
no add-on slash commands or AddOns Settings category.

Editing is unavailable during combat and restricted encounters. A restriction
interrupts dragging and closes the controls. Edit Mode shows samples only; the
live display returns after Edit Mode ends. No keyboard bindings are changed.

## What the reels mean

| Result | Center symbols |
| --- | --- |
| One of a Kind | One die, then two different random symbols from coin, cutlasses and rum |
| Double Trouble | Two dice, then one random coin, cutlasses or rum |
| Triple Threat | Dice, dice, dice |
| Jackpot | Treasure chest ×3 |

Rum bottles remain ordinary reel symbols. The treasure chest is reserved for the
native Jackpot result and its clearly labeled preview, never decorative spinning
rows, neighboring symbols, idle or another result.

Each identifiable cast while the display is visible chooses a cosmetic variation,
even with Animate reels turned off. The dice positions stay fixed, and the choice
stays in place after landing until another accepted roll. Random choices may repeat.
Edit Mode previews have separate choices and restore the live variation on exit.
Variations are not saved: login or reload starts from a valid default without a
false spin. Loading screens, hide/show and other in-session interruptions preserve
the current choice. The real buff, not the cosmetic random choice, decides the rank.

An identifiable successful cast starts a cosmetic spin lasting up to 1.5 seconds.
Each reel finishes by rolling the native-selected result symbol into place,
stopping one after another. A continuous strip carries the decorative spin into the
final result, with clipping only at the fixed reel window.
The live name and countdown remain separate from the spinning reels. Settled without an
active result, the chest shows fixed dim coin, swords and dice symbols with
**Awaiting a result**, not a random or winning combination.

The add-on does not read hidden aura values or calculate the result from the cast.
When restrictions hide the cast, the cosmetic spin may be skipped. Buff changes,
extensions and expiration are handled by the native display. The animation uses
fixed timing and cannot wait for confirmation that a new buff has arrived. A delayed
aura update or rapid reroll during landing can still change the symbol during or
after the landing; this prototype does not guarantee removal of every blink.
An old Jackpot can remain visible until Blizzard updates the buff after a reroll;
the chest does not confirm that the newest cast won.
Jackpot-specific sounds, reroll advice, history and chat messages are not included.

## First gameplay checks

- Compare all four settled results and timers with Blizzard's buff display
- Watch each actual result roll into its final center, with no jump or clipped edge
- Check the third reel's lower symbols throughout landing; no internal moving edge should cut them
- Try repeated same-rank and different-rank rolls, duration extensions and expiry
- Repeat One of a Kind and Double Trouble rolls with animation on and off; only non-winning symbols should vary
- Watch that a chosen variation stays put after landing, hide/show and Edit Mode previews
- Try a rapid reroll during landing; note delayed symbol changes or flashes
- Check missing/expired buffs return to dim symbols and Awaiting a result
- Reload or relog with an active buff; check that it returns without a false spin
- Test sustained combat and a restricted instance, then leave and check recovery
- Try Edit Mode selection, Test spin, reset, dragging and snapping at 60%, 100% and 180%
- Check entering combat while editing, hiding Edit Mode selections and leaving Edit Mode
- Check texture transparency, clipped reel edges and readability at your UI scale
- Check every variation for symbols leaking in from the sides at 60%, 100% and 180%
- Check that the chest appears only in Jackpot or its labeled preview, never ordinary rows or idle
- Check chest transparency and readability at 60%, 100% and 180%; rum remains in ordinary rows
- Disable animation or hide the UI mid-spin; check that the result returns fully settled
- Report missing results, incorrect timers, Lua errors, taint or blocked-action errors

Include the package name, client build, context and screenshots with feedback.
Do not dump secret aura tables. The full matrix and source evidence are in
[docs/VALIDATION.md](docs/VALIDATION.md).

## Local development

Run from the repository directory:

```powershell
lua tests/runner.lua
./tests/package_spec.ps1
./scripts/package.ps1
```

Tests load files in TOC order with add-on varargs and strict API stubs. They do not
establish real-client rendering or combat safety. Packaging verifies its explicit
runtime allowlist, path casing and archive hashes, requires valid Interface
metadata, and validates the TGA exports before writing output. Tests, source-art
references, instructions and validation notes are excluded from the player ZIP.

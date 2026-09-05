# Changelog

## [0.1.0] - 2026-09-04

### Added

- A Roll the Bones Slots logo in the AddOns list.
- A treasure-chest slot machine for Outlaw Rogues, with recognizable symbols for each Roll the Bones result.
- Your current buff's icon, name, and remaining time beneath the reels.
- An optional gold bar that shows how much buff time remains.
- Spinning reels and winning lights, with an extra flash for Jackpot.
- Coins, cutlasses, and rum bottles that vary between rolls, with treasure chests reserved for Jackpot.
- An empty display with dimmed symbols and "Try yer luck, matey!" between buffs.
- Edit Mode controls to move and resize the chest, with grid and nearby element snapping.
- Options to show the display all the time, only with an active buff, or only in combat.
- Separate options to turn animations and the duration bar on or off.
- A Test spin button to preview every result and the empty display.
- An eye button that hides the Edit Mode highlight while keeping the chest draggable.
- Support for hiding the chest's highlight alongside EnhanceQoL's Edit Mode highlights.
- Settings shared across characters, with a Reset to Defaults button.

### Changed

- New setups place the chest just above the center of the screen. Existing positions are kept.
- Display size can be set from 60% to 180%. Press Escape to cancel a percentage you are typing.
- Test spin and Reset to Defaults each have their own row in the settings window.
- The gold duration bar fills the row below the reels, with the buff icon positioned inside it for clearer reading.

### Fixed

- Resizing keeps the chest centered on its saved position and within the screen edges.
- Test spin changes the preview's text and symbols together, including when the duration bar is hidden.
- When buff is active now hides the entire empty display between buffs.
- Selecting the chest or an EnhanceQoL element closes the previous settings window.
- Reel symbols stay visible after changing when the display appears.
- Winning lights stay behind the symbols and leave the other reels at their normal brightness.
- Symbols roll into place without being cut off by a moving edge.
- Reset to Defaults stops any spin or winning flash already in progress.
- Buff tooltips open only when hovering over the row below the reels.

### Known Issues

- Entering combat or an encounter while dragging can leave the chest in a position that is not saved. Resizing it later may move it back.
- Rapid rerolls or delayed buff updates can briefly show or highlight the previous result. A Jackpot flash may belong to the previous roll.
- Some combat situations can prevent a reel spin or winning flash.
- Buff tooltips appear beside the chest and are hidden during combat.
- Settings save immediately. Blizzard's Edit Mode Cancel button does not undo them.

# Changelog

## Unreleased

### Added

- A treasure-chest slot display for Outlaw Rogue, with distinct symbols for all four Roll the Bones results
- The current buff's icon, name, remaining time and optional gold duration bar
- Short reel spins, two pulses behind ordinary winning reels and three stronger pulses for Jackpot
- Random non-winning coin, cutlass and rum symbols; treasure chests are exclusive to Jackpot
- Dim symbols and "Try yer luck, matey!" when no buff is active
- Edit Mode controls for position, scale, animation, duration bar and visibility
- Always, When buff is active and In combat visibility choices
- Test spin samples for all four results and the empty display
- An eye button to hide the Edit Mode highlight while keeping the display draggable
- Optional EnhanceQoL highlight syncing and settings-window handoff
- Snapping to Blizzard's grid and eligible nearby UI elements
- Account-wide preferences that save immediately, with Reset to Defaults

### Changed

- Fresh installs and Reset to Defaults place the chest just above screen center; existing positions are preserved
- Scale entry accepts three numeric digits, clamps to 60% through 180%, and supports Escape to cancel
- Test spin and Reset to Defaults each fill a separate row in the settings panel
- The gold duration bar fills the footer row, with its buff icon inset for readability

### Fixed

- Changing scale resizes the chest around its saved center, with screen-edge clamping
- Result previews replace the empty text and symbols together, including when the duration bar is hidden
- When buff is active leaves no idle message or decoration without a result
- Switching between the chest and EnhanceQoL elements keeps only the selected settings window open
- Reel symbols remain visible after changing display visibility
- Winning lights stay behind their symbols, and non-winning reels retain their normal brightness
- Reel symbols roll into place without a moving edge cutting through them
- Reset to Defaults cancels pending spins and win flashes
- Buff tooltips open only over the bottom row

### Known Issues

- A drag interrupted by combat or encounter restrictions can leave the chest at an unsaved position; a later scale change may move it back
- Delayed buff updates and rapid rerolls can briefly show or highlight the previous result
- Combat restrictions may skip a cosmetic spin or flash
- Buff tooltips stay beside the chest and are hidden in combat
- EnhanceQoL highlight syncing supports EnhanceQoLEditMode-1.0 revision 21000001
- Preferences save immediately and are not undone by Blizzard's Edit Mode Cancel button

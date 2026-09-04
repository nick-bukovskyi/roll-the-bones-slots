# Changelog

## Unreleased

### Added

- A treasure-chest slot display with distinct symbols for each Roll the Bones result, plus its name, icon and remaining time
- Short reel spins that finish by rolling the actual result symbols into place one after another
- Dim, varied symbols and an Awaiting a result message when no buff is active
- Edit Mode controls for position, scale, reduced motion, sample spins and an idle preview
- Snapping to Blizzard's grid and nearby eligible UI elements
- Account-wide preferences that save immediately, with a reset-to-defaults button

### Changed

- One of a Kind and Double Trouble now vary their non-winning symbols between rolls, including when animation is disabled; winning dice and Jackpot chests stay unchanged
- Jackpot now shows three exclusive treasure chests; rum bottles remain ordinary reel symbols

### Removed

- Add-on chat commands, separate position-lock controls and the AddOns Settings category; configuration is now entirely in Edit Mode

### Fixed

- Removed the moving cut through lower reel symbols as they settle into place
- Buff details stay inside the chest instead of drifting beside it
- Corrected missing compatibility metadata that made the initial package appear as Incompatible on Retail 12.1.0; replace the package and restart WoW

### Known Issues

- Randomized non-winning symbols, the exclusive Jackpot chest, continuous-strip clipping fix and full result, idle and Edit Mode checks still need in-game verification on Retail 12.1.0.69587
- Combat restrictions may skip a cosmetic spin; settled results never come from a guessed roll
- Delayed buff updates or rapid rerolls can still change symbols during or after landing; the animation cannot guarantee a blink-free transition
- Buff expiration and recovery in restricted encounters remain unverified
- Preferences save immediately and are not undone by Blizzard's Edit Mode Cancel button
- Jackpot sounds are not included

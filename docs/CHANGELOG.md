# Changelog

## Unreleased

### Added

- A gold duration bar behind the buff name and countdown drains as the buff expires; toggle Show duration bar in Edit Mode
- A treasure-chest slot display with distinct symbols for each Roll the Bones result, plus its name, icon and remaining time
- Short reel spins that finish by rolling the actual result symbols into place one after another
- Roll the Bones casts now flash the displayed winning reels twice after landing, with three stronger pulses for Jackpot; Test spin previews the same effect
- Dim, varied symbols and an idle message when no buff is active
- Edit Mode controls for position, scale, reduced motion, sample spins and an idle preview
- Snapping to Blizzard's grid and nearby eligible UI elements
- Account-wide preferences that save immediately, with a reset-to-defaults button

### Changed

- Idle slots now say "Try yer luck, matey!" instead of implying a result is pending
- The duration bar now fills the entire footer row with brighter worn-gold artwork, and its smaller buff icon sits inside with padding
- Only winning reels flash, with the light behind their symbols; non-winning reels keep their normal brightness
- One of a Kind and Double Trouble now vary their non-winning symbols between rolls, including when animation is disabled; winning dice and Jackpot chests stay unchanged
- Jackpot now shows three exclusive treasure chests; rum bottles remain ordinary reel symbols

### Removed

- Add-on chat commands, separate position-lock controls and the AddOns Settings category; configuration is now entirely in Edit Mode

### Fixed

- Buff tooltips now open only over the bottom row, preventing jumps between reel and cabinet hover areas
- Dice and coins sit evenly between the reel edges, and narrower crossed swords leave more space on both sides
- Removed the moving cut through lower reel symbols as they settle into place
- Fixed the display failing to initialize with a secret-value error and repeated animation warnings
- Reset to Defaults now cancels pending win flashes along with the reel spin
- Buff details stay inside the chest instead of drifting beside it
- Corrected missing compatibility metadata that made the initial package appear as Incompatible on Retail 12.1.0; replace the package and restart WoW

### Known Issues

- Buff tooltips retain their position beside the chest; the system's configured tooltip position is unavailable for native aura tooltips on the target build
- Footer-only tooltip hover, leaving the row and tooltip recovery still need in-game verification on Retail 12.1.0.69587
- Duration-bar timing, refreshes and readability still need in-game verification on Retail 12.1.0.69587
- Live win lighting, its placement behind symbols and the existing full result, idle and Edit Mode checks still need in-game verification on Retail 12.1.0.69587
- Same-rank rerolls also flash; Keep It Rolling and other duration updates do not start a celebration
- Win flashes follow a fixed cast schedule; a delayed buff update may briefly highlight the previous result or change the lighting during a pulse
- Combat restrictions may skip a cosmetic spin and flash; settled results never come from a guessed roll
- Delayed buff updates or rapid rerolls can still change symbols during or after landing; the animation cannot guarantee a blink-free transition
- Buff expiration and recovery in restricted encounters remain unverified
- Preferences save immediately and are not undone by Blizzard's Edit Mode Cancel button
- Jackpot sounds are not included

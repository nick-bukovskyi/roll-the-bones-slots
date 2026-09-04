# Development validation

Status: **Implemented, Unverified** for the pirate idle message, footer-only tooltip hover, the optional duration bar and cast-timed lighting behind the result symbols.
The requested system tooltip position is **Blocked** by the target build's native aura tooltip boundary.
The user confirmed no in-game errors with the preceding preview-only repair.
Source and off-client checks do not establish release readiness. No live-client
installation, game control, CVar changes or real SavedVariables edits were performed
for this feature.

## Target and evidence

- Retail live **12.1.0.69587**, Interface **120100**
- User GetBuildInfo screenshot: 12.1.0, 69587, Aug 27 2026, 120100, with empty fifth/sixth strings
- Installed Wow.exe and .build.info corroborate the version/build
- Source: Gethe/wow-ui-source live, commit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`; version.txt matches 12.1.0.69587
- No Classic, PTR, beta or other-build compatibility is claimed
- IronfurTracker informed the native-styled editor, ownership and packaging patterns; its dependencies, Interface declaration and optional third-party integrations were not copied

## Behavior and ownership

### Pirate idle message, footer tooltip hover and system-position limitation

The idle footer says "Try yer luck, matey!" using the existing font and geometry.
This invitation does not report a pending cast, cooldown readiness or a live
result. The dim idle artwork and native footer occlusion remain unchanged.

The reel buttons stop accepting mouse input. The live text footer keeps its
native hover behavior, with hit insets derived from the existing 301-by-26 buff
row. Its icon, name, countdown and full row remain hoverable with the duration
bar enabled or disabled. The separate duration bar and win lights remain
noninteractive. No input scripts, hooks, timers, aura reads or new frames are
added, and the existing native hide-in-combat policy remains in force.

The source audit uses the recorded Retail live 12.1.0.69587 / Interface 120100
GetBuildInfo evidence and rechecks the pinned mirror's version.txt.
[EnableMouse][regionapi] and [SetHitRectInsets][frameapi] take non-secret authored
values and are protected methods; they are configured only in the existing
[frame-provider initialization callback][provider], before access restrictions
and aura assignment. No restricted result button is read or changed afterward.

[AuraButton][aurabutton] exposes SetTooltipAnchorPoint with a fixed anchor name
and optional numeric offsets relative to the aura button. Its hover path uses
the private AuraButtonTooltip. The [tooltip definition][auratooltip] is forbidden
and hidden from the global environment; it inherits SharedTooltipArtTemplate,
which has no default-anchor handler. The [public inbound API][aurainbound]
exports tooltip styling but no positioning callback or tooltip replacement.
[GameTooltip_SetDefaultAnchor][sharedtooltip] uses the configured HUD tooltip
container, but this add-on cannot pass the private aura tooltip to that function.
ANCHOR_NONE and ANCHOR_PRESERVE do not select the system position. The footer
therefore retains its existing native ANCHOR_BOTTOMLEFT anchor. System-position
support is blocked; no substitute spell tooltip or private-frame workaround is
introduced. Blizzard's [aura announcement][announcement] and linked PTR notes
were rechecked without expanding the supported build.

| Context or transition | Applicability | Expected behavior and proof boundary |
| --- | --- | --- |
| Four ranks; pointer enters, crosses and leaves icon/name/timer and filled/unfilled row; reels idle/spinning/settled; bar on/off | Required | Only the live buff row accepts hover; construction geometry is checked off-client, actual input routing and tooltip appearance remain unverified |
| Empty to active to expired; delayed/partial data; login/reload/relog with existing aura; late creation and zone/instance loading | Evidence-gated | Idle invitation is covered while a buff is present and returns at expiry; native assignment owns tooltip contents and visibility; expiry or hiding clears the tooltip and reacquisition recovers without reload; exact-client proof required |
| Enter/sustain/leave combat, repeated rolls, restricted dungeon/raid/delve/scenario/PvP encounters, death/resurrection | Evidence-gated | Existing native combat suppression remains; no new restricted mutations; tooltip disappearance and recovery require the exact client |
| 60%, 100%, 180%, UI scale/resolution; Edit Mode selection/dragging, bar toggle and exit | Required | Hit area matches the buff row after scaling/moving; preview has no live aura tooltip; construction and existing lifecycle regressions cover add-on state, native routing remains unverified |
| Spec/talent/loadout/spellbook eligibility; hidden UI, cinematic/movie, pet battle, loading; vehicle/taxi/override UI and dialogue overlays | Evidence-gated | Inactive or covered display does not leave stale tooltips; restoration and input overlap need client proof, with existing off-client availability regressions retained |
| Repeated hover/leave, hide/show and preview cycles; representative long session | Required | No added frames, hooks, timers or queued work; off-client lifecycle coverage plus exact-client endurance check |
| System HUD tooltip position or later changes to that position | Required | Blocked: no supported native aura-tooltip system-anchor API on the target build |
| Target/focus/mouseover/other-unit changes, group roster/role, charges/cooldowns, equipment/form/pet data; settings migration | Not applicable | The hover change introduces no such inputs or persistence changes; player aura and availability transitions above remain applicable |

### Optional duration bar contract and proof matrix

The user's follow-up screenshot shows One of a Kind with 47 seconds and a partial
fill, and identifies an oversized icon, inset bar edges and a flat-looking fill.
It proves that the previous footer rendered in that pictured state, not continuous
timing, extensions or restricted-context safety. The refinement uses a 16-unit
icon inside the 26-unit row, the cabinet's full inner width (x=50 through 351),
and a bundled generated worn-brass fill. The native timing and toggle paths stay
unchanged. SetStatusBarColor and the existing texture/anchor methods were checked
against the same pinned 12.1.0.69587 source; all styling occurs before binding.

The next user screenshot shows the refined footer at 24 seconds and confirms
the layout is better, but the gold is too dark. The follow-up changes only the
authored SetStatusBarColor multiplier from 0.62 to 1 for all RGB channels, keeping
alpha at 1. The generated PNG, exported TGA, row geometry, timing and settings
are unchanged. The same appearance matrix applies: verify full/partial fill and
text contrast at supported scales off-client, then verify native rendering in
Retail 12.1.0.69587. This static construction-color change introduces no new
combat, lifecycle or persistence path; existing native proof gaps remain.

| Appearance refinement | Applicability | Proof required |
| --- | --- | --- |
| Live icon/name/time, every rank, bar on/off, full/partial/empty fill | Required | Icon remains inside the row with padding; bar meets both inner edges and text stays above it; construction regression and authored preview, exact client unverified |
| 60%, 100%, 180%, UI scale/resolution and native tooltip | Required | Smaller icon remains recognizable, worn-gold texture fits the cabinet, edges do not cover trim, input remains available; authored preview plus client check |
| PNG-to-TGA conversion and final ZIP | Required | Compact power-of-two fill texture, deterministic export, no asset dependency on another add-on, runtime texture included and source art excluded |
| Login/reload, existing active buff, refresh/extension/expiry, combat/restrictions and overlays | Evidence-gated | Existing native duration and container-only toggle behavior is preserved; focused off-client regressions, actual client behavior still unverified |

The footer gains a worn-gold bar behind the existing icon, name and countdown.
It drains from full to empty using Blizzard's remaining-duration binding. The
account-wide Show duration bar preference defaults on; turning it off retains
the name and timer. Existing scale, position and animation choices are preserved.
Edit Mode uses the existing labeled 26-second sample, with a matching 26/30 fill.

The text footer and optional bar use the same four-ID native filter. One extra
native slot keeps the toggle on its container, outside restricted children.
Blizzard owns the duration, refresh, expiry and no-aura visibility. Add-on code
does not read aura data, bar values or native visibility, and adds no clock,
timer, event or OnUpdate handler. Footer text sits above the bar in an explicitly
ordered foreground frame. The cabinet and symbol artwork, TOC, version and
interfaces stay unchanged; the new fill is bundled with the add-on.

Build-matched evidence: [CustomAuraButton][button] exposes SetDurationBar and
passes its opaque duration to SetTimerDuration. [Bar options][baroptions] and
[bar constants][barconstants] define RemainingTime and Immediate; [status bar
API][statusbar] defines the widget and styling methods. [Inbound validation][aurautil]
permits direct children and indirect descendants, so the existing text bindings
can use the foreground. [Frame providers][provider] initialize artwork before
applying access restrictions. The installed Wow.exe and .build.info were rechecked
at 12.1.0.69587; the pinned source version.txt matches the recorded GetBuildInfo.
Blizzard's [aura announcement][announcement] and linked PTR development notes were
checked; no later or additional client support is inferred.

| Context or transition | Applicability | Expected behavior and proof boundary |
| --- | --- | --- |
| Fresh, existing, corrupt and future SavedVariables; reset and reload | Required | Add/validate only the new boolean, preserve false and unrelated choices, honor read-only future schemas; off-client persistence checks, actual reload unverified |
| All four ranks, new/renewed buff, same-rank reroll, Keep It Rolling, expiry | Evidence-gated | Full new duration drains leftward; native refresh/extension updates fill with the text; expiry hides the bar; exact-client check required |
| Login/reload/relog, late load, loading screen or instance/zone change with an already active buff | Evidence-gated | Show the actual remaining fraction, never reset a surviving buff to full or start a cosmetic spin; off-client lifecycle checks plus native client proof |
| Missing, nil, partial, delayed, stale or replaced aura; bursty updates and recovery | Evidence-gated | Native binding owns newest data; no retained timer or stale fill survives missing buff; exact-client check required |
| Toggle while editing an active buff, all samples plus idle, repeated open/close, reset | Required | Only the bar changes; name/time remain above it; idle stays empty; exit restores the native bar according to preference; strict off-client and artwork checks, game UI unverified |
| Animation off, normal animation, changing settings mid-spin | Required | Duration preference is independent of reel motion; no additional OnUpdate or timers; off-client checks and client countdown unverified |
| Combat entry/sustained/exit, restricted encounter, death/resurrection | Evidence-gated | Native bar continues or clears with native aura; controls close and cannot mutate settings; no restricted-child access, taint or blocked actions; exact client unverified |
| Spec/talent/loadout/spellbook eligibility, solo/party/raid and open world/dungeon/raid/delve/scenario/PvP | Evidence-gated | Existing eligibility and native aura ownership govern availability; returns without reload or invented duration; off-client eligibility checks, gameplay unverified |
| Vehicle/taxi/override/possess, hidden UI, pet battle, cinematic/movie/cutscene | Evidence-gated | Existing hide/recovery behavior preserved; no protected action integration or stale countdown on return; off-client supported overlay events, exact client unverified |
| Quest dialogue/talking head/Settings overlapping the footer | Evidence-gated | Decorative bar accepts no mouse input; existing tooltip and controls remain usable; native layering/input check required |
| 60%, 100%, 180%, UI scale/resolution, manager/frame readiness and recreation | Required | Name and timer remain legible above full/partial/empty fill; no duplicate widgets or editor controls; authored preview and construction checks, native rendering unverified |
| Repeated transitions and representative long session | Required | Stable frame/slot/event/timer counts; no work from a disabled bar container; off-client bounds plus native endurance unverified |
| Charges, cooldown resets, target/focus/mouseover/boss/arena/nameplate/pet units, equipment/stance/form | Not applicable as separate inputs | Bar consumes only the existing player aura filter and eligibility; no charge, cooldown, other-unit, equipment, stance or form queries |

### Cast-timed lighting contract and proof matrix

The approved change flashes the currently displayed rank after a readable Roll the
Bones cast, including same-rank rerolls. It does not confirm result arrival. Keep It
Rolling, aura updates alone and UI restoration do not start a celebration. Normal
ranks use two pulses and Jackpot three stronger pulses. Only winning reels receive
lighting, above the opaque backing and below the unchanged symbol textures.
Non-winning reels keep their normal brightness throughout the flash.

| Context / transition | Applicability | Expected behavior and proof boundary |
| --- | --- | --- |
| Retail live 12.1.0.69587 / 120100, login/reload/relog with or without an aura | Evidence-gated | Native slots initialize without visibility scripts; existing buffs return without a flash; exact-package client check |
| All four ranks, same-rank rerolls, Keep It Rolling, failure, unreadable cast and duplicate cast GUID | Required | Every accepted Roll starts one fixed timeline; no other input starts it; strict off-client event tests plus client rank selection |
| Ordinary / Jackpot timings, under-symbol lighting, idle, every cosmetic lane and 60%/100%/180% scale | Required | Two / three pulses begin after the 1.5-second landing; icons keep their original alpha above every light region; no-buff native glow stays absent; construction and authored preview checks plus in-game rendering |
| One of a Kind, Double Trouble, Triple Threat and Jackpot in live and preview layouts | Required | Only columns 1, 1+2, all three and all three respectively contain flash artwork; non-winning columns have no lighting or darkening overlay; strict construction checks cover both layouts, actual brightness remains an in-game check |
| Delayed, replaced, partial or expired aura during a flash; rapid rolls and event bursts | Evidence-gated | Blizzard selects current artwork independently; late changes may highlight the previous result or switch mid-flash; newest cast replaces the old timeline without queued timers |
| Animation off, reset, preview switch, Edit Mode exit, hidden UI, cinematic/movie/pet battle and loading screen | Required | Cancel spin and all lights, reset ordinary alpha and resume quietly; lifecycle tests and exact-client transitions |
| Combat entry, sustained combat, exit, restricted encounter, death/resurrection, vehicle/taxi/override UI | Evidence-gated | Only readable cast input drives ordinary animation parents; no native child read/mutation after setup; verify clipping, taint/errors and recovery in target client |
| Spec/talent/loadout/spellbook changes, solo/party/raid and relevant dungeon/raid/delve/PvP content | Evidence-gated | Existing availability/native aura ownership remains authoritative; presentation refreshes do not replay flashes; restored availability stays quiet |
| Cooldown/charge resets, target/focus/mouseover/pet/equipment changes | Not applicable as independent triggers | No cooldown, charge or other-unit input controls lighting; only an accepted player Roll cast starts it, with existing specialization/spell-known availability |
| Repeated editing/rolls and representative long session, scale/resolution changes | Required | Reuse all groups/slots, no timers or per-roll construction; stop cleanly and preserve settings; off-client bounds plus native endurance |


Each of three reels has four native singleton aura slots filtering the rank spell
IDs independently. One footer slot accepts all four IDs and binds the actual icon,
localized name and duration text. Four additional singleton slots select prebuilt
win underlays. The optional duration bar adds a slot, for 18 across nine containers.
Blizzard selects both the symbols and the matching lighting. Add-on Lua never reads the active rank, aura values,
slot visibility or restricted child widgets.

Each rank has an ordinary animation owner containing its native underlay display
and a separate Edit Mode sample. A readable Roll cast starts all four finite
timelines, regardless of the native selection. Only Blizzard's selected artwork
can appear. Preview starts only the selected sample timeline. There are no aura
callbacks, new cast events, timers, native animation groups or visibility handlers.

The normal timeline starts after 1.50 seconds and finishes after 2.46 seconds;
Jackpot finishes after 3.11 seconds. Alpha phases target only each ordinary owner,
never the native slots or their descendants. One of a Kind, Double Trouble and
Triple Threat pulse twice, with non-winning reels left unchanged. Jackpot
pulses three times with increasing strength and a longer final hold. All timelines
end at zero alpha. Cancellation stops the groups and explicitly resets owner alpha;
natural reel settlement leaves the pending lighting running. Reset to Defaults,
reduced motion and display/preview interruption use the cancellation path.

At construction, rank symbol textures move into a script-free foreground child
above the lighting branches. Their texture, UVs, position and opacity are unchanged.
Native opaque backing stays below the lighting and still covers the dim idle art.
Every native/preview light region is below the rank foregrounds. All levels
are assigned during setup; no native child is queried or modified afterward.
The decorative light buttons disable mouse input so they cannot cover existing
tooltips or intercept clicks while their outer alpha is zero.

All 18 native slots use only CustomAuraButtonTemplate. The rejected prototype's
AnimateWhileShownTemplate and visibility animation-group templates remain absent.
Those paths caused the reported secret-visibility error and unknown Show/Hide
method warnings. The user subsequently reported no errors with the preview-only
repair. That is evidence for the preceding repair, not this new native underlay path.

Cast timing intentionally replaces the former confirmed-arrival requirement.
Same-rank rerolls now flash; Keep It Rolling and aura updates alone do not.
If Blizzard updates the buff late, the previous rank can be highlighted or the
visible pattern can change mid-flash. No result-arrival guarantee is claimed.

All slot artwork is created inside the provider's `initializeFrame` callback,
before access restrictions are applied. Each result is anchored TOPLEFT to its
container, and each container TOPLEFT to its ordinary parent. This is intentional:
native slot-only flow can reduce the container to zero size, so centering artwork
on that container would shift it. Three fixed-size, ordinary clipped viewports
contain ordinary carrier frames. The reel containers sit inside those carriers;
only the ordinary carriers move, relative to ordinary geometry. Only the fixed
outer wells clip the reels. The carriers and native result artwork have no inner
clip, and the separate outgoing panel is removed. Post-initialization code never
reads or moves the native result children or uses their dimensions.

Each result uses a prebuilt long strip with decorative lead-in rows identical
across all four ranks, variants and the ordinary idle strip. Rank-specific final rows occupy
the settled portion. A readable successful cast moves the carrier through that
single continuous strip until its native-selected result rolls into the center;
there is no handover between two moving panels. Landing is staggered
at 1.14, 1.32 and 1.50 seconds on a fixed cosmetic schedule, without inferring the
outcome. Each final phase includes 0.44 seconds of roll-in and 0.12 seconds of
settling after the fast spin. The footer remains stationary. All carriers reset
their vertical offset to rest when animation ends, is disabled or the display hides,
while retaining their selected horizontal variant.
Restricted cast payloads can skip the animation.

Each strip starts 1,188 UI units above rest and contains symbol rows -1 through 13.
Its opaque backing covers local coordinates -99 through 1,440; the visible interval
throughout scrolling and settling stays inside -3 through 1,341. Backing pieces
meet at matching geometry and UV endpoints, preserving the original settled well.
These bounds are authored constants, never measured from native aura widgets.

The final idle rows contain fixed coin/swords/dice symbols at 0.22 central opacity
with faded neighbors. The idle strip and a Try yer luck, matey! footer sit beneath
opaque native result artwork. This is not randomized win state. When no aura is
present, including after expiry, the native artwork disappears and exposes idle
without a Lua aura-presence check. Its opacity, clipping and recovery require
exact-client verification.

The approved fix removes the moving internal clipping boundary, not every possible
late-update transition. Fixed animation timing cannot confirm that a new aura has arrived.
Delayed aura updates or another cast during landing can change native symbols
mid-animation or afterward. Tests must record that behavior rather than treat a
cosmetic schedule as buff synchronization or claim a universal blink fix.
An existing Jackpot can remain visible until its native aura is replaced or expires;
the chest is not confirmation that the latest cast produced a new Jackpot.

The artwork uses one five-symbol `media/symbols.tga` atlas, with Jackpot's
authored mapping {5,5,5}. Symbol 5 appears
in the three visible native Jackpot centers and the labeled Jackpot preview's centers
and footer. Native footer icon binding is unchanged. All decorative lead-in,
neighbor and idle rows remain in ordinary symbols 1–4, including rum.

The current asset consolidation keeps only two authoritative finished PNGs:
the 1024x630 `art/cabinet.png` and 1024x832 `art/symbols.png`. Their unrelated
bottom reserve was removed. Export copies every source pixel to the top-left of
two transparent 1024x1024 TGAs, with no background keying, resizing or artwork
relocation. Generated padding keeps both runtime dimensions at powers of two;
the build-matched SetTexture documentation does not define decoder dimensions,
while current custom-texture guidance requires power-of-two edges. Exact-build
non-power-of-two loading has not been proven, so the runtime layout remains unchanged.
The old generation sheets, separate icon sources and standalone Jackpot texture
were removed. Local preview HTML and captures moved to `artifacts/preview`.

The atlas uses centered crops of the approved 512-pixel symbol canvases. Dice,
coin and swords occupy 344x416, 376x416 and 304x416 rectangles across the top;
rum and Jackpot each occupy 512x416 below. Only transparent padding was removed.
Art.lua owns the five UV rectangles and scales each texture rectangle by its
crop width/512 and height/512, preserving visible pixels, size and center. The
previous dice/coin centering and narrower swords remain intact. No symbol is
resized in the PNG. Linear filtering has at least five transparent texels at
the tightest shared edge. The source layout is documented in art/README.md.

Texture path, authored UVs and rectangle sizes change only during construction,
before the native provider applies access restrictions. The atlas consolidation
preserved the native footer icon, events, TOC, settings and SavedVariables. Lighting
now adds the four native underlay slots described above. The sample footer uses the same atlas at nominal size 22;
its cropped rectangle retains the same visible center at (71,218). Existing
client compatibility and combat proof gaps remain explicit.

Non-winning positions are authored as zero in Game.Results: {1,0,0} and {1,1,0}.
Art resolves zero during initialization to a prebuilt coin, cutlasses or rum lane.
Reel one has one lane; reels two and three each have three lanes, spaced 128 units
apart with independent opaque backing and no inner clip. Thus seven authored
Jackpot center textures exist across lanes, but only three fit the selected wells.
Lane spacing leaves at least 25 units of horizontal clearance even using the full
112-unit symbol rectangle, not just its opaque pixels.

Machine owns separate transient live and preview variant indices. Each visible
Spin call chooses two distinct indices using bounded math.random, independently
of aura data. This gives six ordered pairs for One of a Kind and three choices
for Double Trouble, without adding dice or Jackpot chests. Choosing a variation
precedes the reduced-motion check. The horizontal offset is retained through stop,
hide and recovery; only new accepted rolls change it. Preview changes restore
the previous live indices on exit. Initial indices are 1,1,2; reload does not
persist cosmetic randomness or start a false spin. Random repeats are allowed.

The target build, TOC, schema and vertical motion timings are unchanged.
The display now has 18 native slots/nine containers, including the optional duration bar. All symbol foregrounds and
native/sample underlays are prebuilt. Four finite groups use 32 alpha phases on
ordinary owners, with no per-spin construction or per-frame randomization. Their actual client memory/rendering
cost remains a profiling gate. Consolidation reduces the runtime TGAs from three to
two and slot pixel payload from 5 MiB to 4 MiB, without claiming measured GPU-memory
or frame-rate gains. No new artwork was generated. Existing combat/restriction proof
gates still apply; artwork is not combat evidence.

Core owns display availability, EditMode owns its selection/drag/preview session,
Machine owns cosmetic animation, and Config owns account-wide durable choices.
The editor uses native selection and guide templates with an owned floating
settings panel. Scale, position, animation and duration-bar preference save immediately. No native layout
registration, Save/Cancel persistence, slash commands or AddOns Settings category
is used. Future saved schemas remain untouched and use read-only runtime defaults.

Blizzard switches to a fake aura provider throughout Edit Mode. The add-on disables
its live display during editor previews and also hides it when Edit Mode remains
active but selections are hidden. Only labeled samples may appear until Edit Mode
ends. Editor setup and native snap-target geometry reads require unrestricted,
out-of-combat configuration. Snapping uses native registered targets, never a
global frame scan, and resolves the cabinet's final anchor to UIParent with its
own scale applied. It never anchors the cabinet to a protected target.

## Gameplay-context matrix

Client rows remain evidence-gated for this revision. Off-client tests prove only
the tested contracts, not native rendering, secret behavior, taint or protection.
The random non-winning reel checks below were recorded before implementation. Existing
continuous-strip, landing, idle and restricted-context checks remain applicable.

### Prior preview-only win-lighting error repair (superseded)

| Context / transition | Applicability | Expected result / proof boundary |
| --- | --- | --- |
| Login, reload and relog with or without an active result | Evidence-gated | All 13 native result buttons initialize without `SetShown` secret-value errors; exact rebuilt-package client retest is required |
| Native result assignment, update, replacement and expiry | Evidence-gated | Blizzard alone controls slot visibility; no add-on template, handler or animation group runs on a native button; live result lighting remains absent by design |
| One of a Kind, Double Trouble and Triple Threat Test spin | Required | The labeled Edit Mode sample waits for reel settlement, then winning dice wells pulse twice while ordinary wells briefly dim; off-client construction/lifecycle checks pass and exact-client appearance remains unverified |
| Jackpot Test spin | Required | All three sample chest wells pulse three times with increasing strength and a longer final hold; no inset border, symbol motion or indefinite loop; off-client schedule checks pass and exact-client appearance remains unverified |
| Animation disabled, preview hidden, deselection and Edit Mode exit | Required | No preview group starts while disabled; interruption stops every group, resets target alpha to zero and hides the ordinary effect layer; off-client lifecycle checks pass |
| Same-rank Roll, Keep It Rolling, delayed result and restoration | Required | No live celebration occurs, so these transitions remain quiet without reading or inferring rank state; native rank and duration rendering remain unchanged |
| Combat and aura-secret restricted contexts | Evidence-gated | No new aura event, timer, native-child access or script callback exists in the live path; exact-client taint, blocked-action and recovery checks remain required |
| Repeated Test spins and representative long session | Evidence-gated | Four prebuilt groups are reused, stale alpha is reset on interruption and no frames or timers accumulate; endurance and actual rendering require exact-client observation |

### Asset consolidation revision

| Context / transition | Applicability | Expected result / proof boundary |
| --- | --- | --- |
| Canonical PNGs, conversion and stale exports | Required | Two tightly bounded PNG inputs; every source RGBA pixel copied exactly; generated bottom rows transparent; deterministic export and read-only -Check rejects stale output; fixture and actual-asset checks |
| Five symbols and prior spacing | Required | Every retained pixel equals the pre-consolidation artwork; discarded pixels are transparent; cropped texture geometry preserves visible size and center |
| Four ranks, six cosmetic pairs, dim idle, preview footer | Required | Exact UV identities, Jackpot-only chest and fixed dice counts; all constructed native/editor lanes use the shared atlas; off-client tests plus browser inspection |
| Spin start, scrolling, landing, interruption, reduced motion | Required | Shared atlas retains continuous strips, correct neighboring symbols and lane isolation; no post-initialization native edits; regression tests and selected browser frames |
| 60%, 100%, 180%, native TGA load, login/reload, Edit Mode and restricted encounters | Evidence-gated | Runtime TGAs are byte-identical to the prior 1024x1024 exports, so no texture-loading or UV change was introduced; source/browser checks still cannot prove target-client rendering; native cases remain unverified |
| Package and asset cleanup | Required | Two TGAs in the 13-file ZIP; no separate Jackpot, obsolete generation sheet, PNG master, test or local preview; validate archive names and hashes |
| Persistence, combat logic, units/groups, timers and endurance | No new behavior introduced | No change to authoritative gameplay state, settings, events or scheduling; existing applicable client proof gaps remain below |

### Prior symbol spacing revision

The matrix below scopes verification of the changed pixels. Local asset and
browser checks are recorded under Local verification. Every native
rendering check remains unverified on Retail live 12.1.0.69587, Interface 120100.

| Context / transition | Applicability | Expected result / proof boundary |
| --- | --- | --- |
| Dice and coin atlas export | Required | Horizontal visible margins differ by at most one atlas pixel; translated RGBA pixels, size and vertical placement match the previous artwork |
| Sword alpha, silhouette and spacing | Required | Complete blades and handles, transparent guard openings and clean edges; centered narrower silhouette remains readable against the dark well; record actual exported bounds |
| Settled results, dim idle and all three reel columns | Required | Dice, coin and swords have balanced horizontal gaps; unchanged rum and Jackpot remain controls; inspect browser and native client at 60%, 100% and 180% scale |
| Spin start, scrolling, staggered landing and adjacent rows | Required | Changed symbols retain their full horizontal silhouette without side bleed; vertical clipping occurs only at the fixed well edges; check each affected symbol entering, crossing and leaving each reel window, including reduced motion and repeated preview spins |
| Native texture loading after restart, reload and Edit Mode entry/exit | Evidence-gated | Exact packaged textures load with correct alpha and orientation; samples and native results use the same corrected artwork; capture target build, scale and inspected errors |
| PNG/TGA parity, repeat export and package | Required | Every RGBA pixel matches across formats; deterministic re-export; rum cell, cabinet and Jackpot preserved; same 14-file runtime allowlist with source artwork excluded |
| API, combat restrictions, persistence, group/unit inputs and endurance | No new behavior introduced | Texture pixels add no game calls, protected operations, frames, events, timers or saved state; existing applicable client checks below remain unverified and are not replaced by browser evidence |

### Existing behavior and client proof gaps

| Context / transition | Applicability | Expected result / proof boundary |
| --- | --- | --- |
| All six non-winning pairs across all four ranks | Required | One die plus two distinct coin/cutlasses/rum symbols; two dice plus one of those; three dice and Jackpot chests unchanged; exhaustive authored-lane tests, native slot filters stay authoritative |
| Readable cast, repeated/burst/duplicate/secret cast, animation disabled | Required | One cosmetic choice per accepted visible cast, including reduced motion; no choice from hidden cast data; no new timer/frame/texture work; test real event boundary off-client and combat in game |
| Landing, stop, hide/show, death, loading and spec recovery | Evidence-gated | Selected horizontal lane persists while vertical motion resets, with no return to a preset or false result; preview choices do not replace live choices; stale native aura caveat unchanged |
| Adjacent-lane clipping and every lane through all landing frames | Required | 128-unit lane spacing keeps 112-unit symbols outside neighboring 91/94-unit windows; opaque backing covers selected strip; geometric/snapshot proof plus 60%/100%/180% client checks |
| Reduced-motion and repeated Edit Mode previews, exit/re-entry | Required | Each Test spin chooses a valid sample variation even without motion; leaving previews restores the prior live variation and native result; no settings/schema changes |
| Construction cost and endurance | Evidence-gated | Finite prebuilt regions only, unchanged native slot/frame counts, no per-spin construction or per-frame randomization; profile added static artwork and repeated restricted-combat rolls in target client |
| Jackpot-only center symbol and labeled preview | Required | Symbol 5 uses a standalone chest texture only in Jackpot center rows across authored lanes, with three visible centers and its labeled preview footer; native filters, 13 slots and vertical timing unchanged; exact-client proof pending |
| Ordinary spin, idle and adjacent rows | Required | All decorative rows remain within symbols 1-4, including rum; no chest in non-Jackpot result strips, idle or Jackpot neighbors; the symbol-spacing revision preserves the rum cell while updating dice, coin and swords |
| Jackpot entry, same/different reroll, expiry and reload with buff active | Evidence-gated | Chest follows the native Jackpot aura, rolls into place without an end-of-spin texture write, and disappears with the aura; delayed updates may preserve an old Jackpot temporarily; no claim of per-cast confirmation |
| Chest alpha, scale and archive | Required | Shared-atlas chest has preserved alpha, complete silhouette and transparent padding; inspect at 60%, 100%, 180%; source artwork and obsolete standalone texture excluded; actual game loading remains unverified |
| Target build, corrected metadata, package installation | Required | Identity confirmed by user; revised ZIP loading and dependency readiness need client proof |
| Clean install, valid settings, corrupt fields, previous MVP settings | Required | Preserve valid account-wide choices and repair only invalid fields; off-client checks plus reload/relog |
| Future schema, including entering Edit Mode | Required | Leave original data unchanged; runtime defaults read-only; no editor mutation |
| Login, reload, relog, buff already active, loading screen | Evidence-gated | Native current result returns without a false spin or duplicate frames |
| Four ranks, same-rank and different-rank rerolls | Evidence-gated | Matching symbols, localized name/icon and real timer; no overlapping rank panels; repeated readable casts animate once each |
| Duration extension, expiry, failed or interrupted cast | Evidence-gated | Native timer follows extension; absent/expired result reveals dim varied symbols and Try yer luck, matey!; extension/failed cast does not fabricate a spin |
| Staggered rolling landing, all four ranks at supported scales | Evidence-gated | Actual native-selected symbols visibly roll into their final centers one reel at a time; no wrong direction, clipping, drift or remaining carrier offset |
| Reported third-reel lower-edge cut; start through settle at 60%, 100%, 180% | Evidence-gated | No moving internal boundary cuts a symbol or backing; one continuous strip passes behind only the fixed outer-well clip; check every reel and all four results plus idle |
| Common decorative lead-in and rank-specific final rows | Required | Prebuilt strips have identical lead-in artwork across all four ranks and idle; native-selected final rows remain distinct; source/off-client checks plus client capture through the transition |
| Delayed/missing aura and a rapid reroll during landing | Evidence-gated | Fixed animation never invents a result; newest native output or idle remains authoritative; record any late change or blink rather than claiming timing guarantees |
| Ordinary viewports/carriers versus sealed native children | Required | Three fixed outer wells are the only reel clips; ordinary carriers move whole prebuilt strips, with no separate outgoing panel; 12 native singleton reel slots plus one footer stay unread/unmodified after initialization; native restriction behavior requires client proof |
| Animation disabled or display hidden mid-landing | Evidence-gated | Stop update work, reset every continuous-strip carrier, and restore static native result or dim idle without a false win or exposed strip edge |
| Combat entry, sustained combat, exit and rapid repeated casts | Evidence-gated | Live display remains native; secret casts ignored; editor/drag ends; no restricted child access; recovery without reload |
| Dungeon, active M+, raid encounter, delve/scenario | Evidence-gated | Exercise actual restricted contexts, not only a dummy; rank/timer and recovery stay correct |
| Solo, party/raid roster and role changes | Evidence-gated | Player remains the sole source; transitions do not duplicate work |
| Battleground/arena, match start/end | Evidence-gated | Result stays correct or unsupported restriction is reported; no PvP claim before testing |
| Spec, talent, loadout and spellbook changes | Evidence-gated | Live display requires eligible Outlaw; returns when eligible; editor samples remain distinguishable |
| Death/resurrection, loss/return of control | Evidence-gated | Native aura existence wins; obsolete cosmetics stop and return does not fabricate a win |
| Vehicle, taxi, override/possess bar, pet battle | Evidence-gated | No protected action/bar integration; pet battle hides display and exit recovers |
| Hidden UI, cinematic/movie, cutscene, dialogue/talking head | Evidence-gated | Hidden UI/cinematics suppress cosmetics; return refreshes current state; ordinary dialogue does not capture focus |
| Edit Mode entry/exit; selecting this or a Blizzard element | Evidence-gated | Exactly one owned editor; native selection styling; dialog follows selection; preview landing and native restoration leave carriers at rest; live result and sample never coexist |
| Edit Mode hides/reopens selections without exiting | Evidence-gated | No native fake-provider aura is presented as live; reopening restores labeled sample; exit restores actual aura |
| Slider, percentage input, Escape, checkbox, Test spin, reset | Evidence-gated | Validated 60–180% values, canceled input preserved correctly, reduced motion stops spins, samples cycle through four ranks plus idle, reset affects only owned fields |
| Native Save/Cancel, layout switch, reload after edit | Evidence-gated | Changes remain immediate/account-wide rather than per-layout; cancel does not undo them |
| Drag/grid/element snapping at 60%, 100%, 180% | Evidence-gated | Guides agree with final placement; scaled offsets round-trip; final anchor is UIParent, never a protected element |
| Restrictions/overlays arriving during drag or focused input | Evidence-gated | End interaction and guide updates; reject mutation/target geometry while restricted; recover without reload |
| UI scale/resolution, clamping, parent visibility | Evidence-gated | Chest remains reachable; saved choices preserved; scaled snapping and labels remain correct |
| Ordinary rum bottle in lead-in, neighbors and idle | Evidence-gated | Existing amber glass/red seal/gold artwork remains readable with clean margins; it is an ordinary symbol, not the Jackpot center; actual scale/clipping checks remain required |
| TGA loading, alpha, reel clipping, frame layering | Evidence-gated | Existing textures load without atlas bleed; symbols remain complete inside fixed well boundaries, with no moving internal clip; opaque native strips conceal dim idle only while active; editor receives clicks |
| Missing/delayed aura, bursts, late Blizzard UI readiness | Evidence-gated | No stale copied aura; newest native state wins; no expanding callback queue or duplicate manager hooks |
| Repeated transitions and representative long session | Evidence-gated | No accumulated frames/events/timers; animation and guide updates stop when idle |
| Target/focus/mouseover/boss/nameplate/pet aura changes | Not applicable | No such units or aura scans; player is the sole source |
| Charges, cooldown start/reset, equipment stats | Not applicable | No charge/cooldown/stat model; only the successful cast and actual buff display are inputs |
| Schema migration | Not applicable | Schema remains version 1; previous preferences, corruption and future-version handling remain applicable |

## User test record

On 2026-09-04, the initial package appeared **Incompatible**. Its installed TOC
matched the project TOC and both omitted Interface. The subsequent GetBuildInfo
screenshot established 120100 directly; the correction did not borrow another
add-on's compatibility declaration.

A later user screenshot of the **prior MVP** shows Double Trouble and a 26-second
countdown during combat. This provides limited evidence that the earlier package
loaded and displayed that buff in the pictured state. It does not establish
continuous timer behavior, all four ranks, restricted-instance safety, or the
revised native rank artwork, textured reels and Edit Mode implementation.

A subsequent user report said the landing prototype was "working great", while
the attached screenshot showed a moving bottom edge cutting the lower texture in
the third reel. This is positive feedback plus concrete evidence of the clipping
defect, not complete rank/combat/restriction coverage and not proof of the new fix.

On 2026-09-04, the user tested the first live win-lighting package on Retail
12.1.0.69587. Initialization failed at `Game.CreateReelDisplay` with
`Button:SetShown(): Cannot be called with secrets due to existing script handlers`
and explicitly reported `No Lua Taint`. The client also reported unknown `Hide` and
`Show` methods from animation-group OnLoad, OnPlay, OnStop and OnFinished scripts.
This is exact-client evidence that the inherited native-button visibility handlers
and dynamically instantiated visibility animation template are invalid. It is not
proof of the corrected package, which still needs a reload/relog retest.

No user proof has yet been recorded for the continuous-strip seam correction.
The prior rum-bottle replacement has local export/preview evidence below, not in-game
proof. The corrected symbol spacing, randomized non-winning reels, exclusive Jackpot
chest and ordinary Edit Mode win-lighting preview still need native rendering,
readability and restricted-context verification. Record client build,
package identity, specialization/loadout, context, entry/exit transitions, screenshots
and Lua/taint/blocked-action errors. Do not dump secret aura tables or widget contents.

## Build-matched source audit

Links below pin the audited commit. Secure Blizzard execution is contract evidence,
not permission to reproduce its restricted operations in add-on Lua.

| Boundary | Evidence and implementation consequence |
| --- | --- |
| Client identity/load | [Build documentation][build], [AddOnList][addonlist]: exact GetBuildInfo gate; Interface is required, not a compatibility bypass |
| Eligibility/cast | [Specialization API][spec], [spellbook API][spellbook], [Unit API][unit]: current namespaces; UNIT_SPELLCAST_SUCCEEDED payload guarded before use |
| Aura filtering | [CustomAuraContainer][container], [filter rules][filters]: four HELPFUL singleton includeSpellIDs slots per reel, one four-ID footer and four singleton underlay slots; filtering and visibility stay native |
| Aura presentation | [CustomAuraButton][button]: SetIcon, SetSpellName and SetDurationText bind regions without an add-on countdown or rank readback |
| Initialization/flow | [Frame providers][provider], [AuraButton intrinsic][intrinsic], [AuraContainer][lifecycle], [CustomAuraContainer][container]: construct complete script-free native strips before restrictions; TOPLEFT anchors tolerate zero-size containers; ordinary carriers provide animation geometry |
| Win-lighting boundary | [CustomAuraContainer][container], [frame providers][provider], [CustomAuraButton][button], [AuraButton intrinsic][intrinsic], [animation templates][animationtemplates], [UNIT_AURA documentation][unitaura]: slot options expose construction but no public assignment/update callback; secret visibility rejects added native-button handlers; secret aura updates cannot identify a confirmed rank. The approved cast-timed design runs every authored timeline and lets native filtering select the visible underlay without reading it |
| Cast and preview animation | [animation-group API][animgroup], [animation API][anim], [texture API][textureapi]: four prebuilt finite plain groups target ordinary parents above native underlays; SetTarget returns a checked boolean. GetAlpha/SetAlpha read/write only ordinary authored alpha; all final phases end at zero and interruption resets each owner. SetFrameLevel is configured only during construction, with all symbol foregrounds above all light artwork; native alpha inheritance and frame ordering still require target-client proof |
| Secrets/access | [FrameScript][framescript], [C_Secrets][secrets], [script object API][object]: issecretvalue/canaccesstable before value/table use; CanBeAccessedInContext and plain finite geometry before snap calculations |
| Edit Mode lifecycle | [EditModeManager][manager]: Enter/Exit callbacks and isolated selection post-hooks; SwitchAuraDataProvider remains active even while selections are hidden |
| Selection/snapping | [system templates Lua][systems], [system templates XML][systemxml], [magnetism][magnetism], [guide templates][guides]: native selection/guides; placement-only adapter, no native layout registration or target anchoring |
| Editor controls | [MinimalSlider][slider], [dialog templates][dialog]: native slider/steppers, input and translucent dialog styling; owned injected settings callbacks, no Settings category |
| Frames/textures | [Frame API][frameapi], [region API][regionapi], [anchor/size API][resizeapi], [texture API][textureapi]: fixed outer wells alone clip continuous strips; ordinary carriers alone move; common lead-in and dim final idle rows are prebuilt; no native-child mutation after setup |
| Consolidated symbol atlas | Build-matched SetTexture accepts the authored path and CLAMP/CLAMP/LINEAR strings but does not specify file dimensions; current [custom-texture guidance][texturefiles] requires power-of-two edges, so canonical PNGs are transparently padded to 1024x1024 at export. SetTexCoord accepts the authored rectangle UVs, with left/right/top/bottom order confirmed by Blizzard_SharedXML/NineSlice.lua. SetSize takes ordinary authored uiUnits during initialization, before native access restrictions. Provider initialization precedes DenyTaintedAccessWhenAurasAreSecret. Jackpot filtering, native footer binding and ordinary carrier movement are unchanged |
| Cosmetic lane selection | [Scripted effects][random] uses bounded two-argument math.random. Both choices use authored integer bounds, never aura data, and the add-on does not reseed the shared generator. [Anchor API][resizeapi] SetPoint receives authored offsets on ordinary carriers only; native children remain untouched after provider initialization. Combat movement still requires exact-client proof |
| Overlays | [Cinematic API][cinematic], [ActionBarController][actionbar]: cinematic/movie and pet-battle lifecycle inputs |
| Blizzard direction | [June aura announcement][announcement]: custom filtered displays without exposing combat aura data |

[build]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/BuildDocumentation.lua
[addonlist]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AddOnList/AddonList.lua
[spec]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua
[spellbook]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua
[unit]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua
[container]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua
[filters]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua
[button]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua
[baroptions]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/AuraContainerUtilDocumentation.lua
[barconstants]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarConstantsDocumentation.lua
[statusbar]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua
[aurautil]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua
[provider]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua
[intrinsic]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.xml
[aurabutton]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.lua
[auratooltip]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Mainline/Blizzard_AuraButtonTooltip.xml
[aurainbound]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerInbound.lua
[sharedtooltip]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua
[lifecycle]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainer.lua
[animationtemplates]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_SharedXML/AnimationTemplates.xml
[animgroup]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleAnimGroupAPIDocumentation.lua
[anim]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleAnimAPIDocumentation.lua
[unitaura]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua
[framescript]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua
[secrets]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua
[object]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameScriptObjectAPIDocumentation.lua
[manager]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_EditMode/Shared/EditModeManager.lua
[systems]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua
[systemxml]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.xml
[magnetism]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_EditMode/Shared/EditModeUtil.lua
[guides]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_EditMode/Shared/EditModeTemplates.lua
[slider]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua
[dialog]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml
[frameapi]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua
[regionapi]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua
[resizeapi]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua
[textureapi]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua
[texturefiles]: https://warcraft.wiki.gg/wiki/API:TextureBase_SetTexture
[random]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_SharedXML/ScriptedAnimations/ScriptedAnimationEffects.lua
[cinematic]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_APIDocumentationGenerated/CinematicDocumentation.lua
[actionbar]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_ActionBarController/ActionBarController.lua
[announcement]: https://us.forums.blizzard.com/en/wow/t/addons-and-auras-in-curse-of-ula%E2%80%99tek/2317456/

The mirror's live branch, version.txt and commit were rechecked for the randomized reel
revision and this cast-timed lighting change on 2026-09-04. The official [12.1 update notes](https://news.blizzard.com/en-us/article/24293281/curse-of-ula-tek-content-update-notes)
and June aura announcement were also checked; they do not replace exact-client proof.

### Static spell data

Build-specific client DB2 exports corroborate the authored identifiers, not live
aura behavior or secrecy exceptions.

| Meaning | ID | Build-pinned name record |
| --- | --- | --- |
| Roll the Bones cast | 1214909 | [SpellName](https://wago.tools/db2/SpellName/csv?build=12.1.0.69587&filter%5BID%5D=1214909) |
| One of a Kind | 1214933 | [SpellName](https://wago.tools/db2/SpellName/csv?build=12.1.0.69587&filter%5BID%5D=1214933) |
| Double Trouble | 1214934 | [SpellName](https://wago.tools/db2/SpellName/csv?build=12.1.0.69587&filter%5BID%5D=1214934) |
| Triple Threat | 1214935 | [SpellName](https://wago.tools/db2/SpellName/csv?build=12.1.0.69587&filter%5BID%5D=1214935) |
| Jackpot | 1214937 | [SpellName](https://wago.tools/db2/SpellName/csv?build=12.1.0.69587&filter%5BID%5D=1214937) |

Benefits are cumulative ranks, not independent set counts. 1214936 is not Jackpot.
Base-duration data is not used to time live buffs.

## Local verification

- Pirate idle text and footer-only hover on 2026-09-04: 50 off-client Lua tests passed. The new construction regression checks that only the live text footer accepts mouse input, its hit rectangle matches the buff row at 60%/100%/180% with the bar on/off, and Edit Mode/loading transitions disable and restore its container without new slots. Existing coverage checks the native footer covers the idle invitation. All eight TOC Lua files and both changed test files passed syntax checks; canonical texture verification and git diff --check passed. This does not simulate native hover, tooltip dismissal, combat/taint or secret data; the exact-client matrix above remains unverified. System-position anchoring is blocked by the audited API boundary
- Current pirate-idle/footer-hover ZIP: 14 allowlisted files under RollTheBonesSlots/, with archived paths, casing and source hashes verified by the local packager. SHA256 1C8581D467321BBA9C47B78484416253855C514198D49CDD6797DF1A54C685CC. Version dev, Interface 120100 and settings schema 1 are unchanged. Built without installation, upload or publication; native tooltip and idle appearance checks remain unverified on Retail live 12.1.0.69587
- Original-gold follow-up on 2026-09-04: removed the 0.62 RGB darkening multiplier. All 49 off-client Lua tests, Art.lua syntax and git diff --check pass. Browser inspection covered Double Trouble at 100% and One of a Kind at 60%/180%, including full, partial, empty and disabled compositions across the views; original gold is brighter and overlaid text remains readable with substitute browser fonts. Browser warnings/errors were empty. PNG/TGA hashes remain unchanged. The rebuilt 14-file ZIP passed archive path and source-hash verification, SHA256 C8F80DE91979E8D79FB504DAE4B38DFEF4C88E564210515A07807C23CA1173A0. Native appearance and existing timing/restricted-context cases remain unverified on Retail live 12.1.0.69587 / Interface 120100
- Prior appearance-refinement ZIP before removing the darkening tint: 14 allowlisted files under RollTheBonesSlots/, with archived source hashes verified and all three runtime textures included. SHA256 3A8094BB605128750D5DE2CDB27A91E76E79DCEF95C8840D9B4F339C661E794F. That revision passed 49 off-client Lua tests, 11 art export checks, 28 isolated package checks, all eight TOC Lua syntax checks, canonical export verification and git diff --check. Built without installation or upload; exact-package client checks remain unverified on Retail live 12.1.0.69587 / Interface 120100
- Appearance refinement on 2026-09-04: the built-in imagegen tool produced a 1774x887 opaque worn-gold source, retained unmodified as art/duration-fill.png. The exporter fits it to a 1024x128, top-left BGRA32 runtime strip. Eleven isolated art checks verify both old atlases pixel-for-pixel, the compact fill dimensions, opaque edges and retained quadrants, and read-only rejection of altered or missing exports. The cabinet and symbols remain byte-identical to the prior runtime assets
- The updated actual-Lua browser preview used the exported fill pixels and authored tint. Inspected Double Trouble and Triple Threat at 100%, One of a Kind at 180% and Jackpot at 60%, plus idle. Full, half, low, zero and disabled sample compositions were covered across these views; the icon stays inside the row, the fill reaches its inner edges, labels remain above it and idle has no bar. Browser warnings/errors were empty. These are authored samples using substitute browser fonts/icons, not native aura timing or exact-client proof
- Prior duration-bar development ZIP before the appearance refinement: 13 allowlisted files under RollTheBonesSlots/, with every archived source hash verified. SHA256 6E8F15BD660FB8606DFA94C304740DEFB70A3890A2AFE1F9389E87C14002EF53. Built locally without game installation or publication
- Optional duration bar: 49 off-client tests pass. Coverage checks existing/missing/corrupt/future preferences, persistent false, reset, independence from reduced motion, same-filter RemainingTime binding, text above the bar, noninteractive bundled fill, restricted edit rejection and 15 repeated preview/loading/pet-battle/reset cycles without new frames, slots, hooks or timers. The appearance regression checks the 16-unit icon stays strictly inside the full 301-by-26 row and the backing aligns with the bar. Native aura timing and secret behavior are not emulated
- Browser artwork checks inspected all four ranks plus idle, with full/half/low/empty/disabled fill compositions, and representative 60%/100%/180% scales. Names and countdowns stayed above the fill; disabling retained the labels; idle had no bar. Browser warnings/errors were empty. Game fonts, real aura selection and native frame layering remain unverified
- The initial duration-bar revision passed all eight TOC Lua syntax checks, canonical texture export verification, 27 isolated package checks and git diff --check. It introduced no texture; the subsequent appearance refinement adds the bundled fill
- Cast-timed under-symbol lighting: 45 off-client tests pass, including native filter/ordinary animation separation, normal/Jackpot schedules, layer order, preserved symbol alpha, same-rank cast replay, duplicate/unreadable input filtering, interruption, reset, reduced motion and bounded repeated rolls. The updated construction test verifies that only winning columns contain flash artwork in both native and preview layouts. The native selection and rendering are not emulated
- Canonical artwork export verification and 27 isolated package checks passed; the lighting change does not change texture pixels or TOC metadata
- All eight TOC Lua files passed syntax checks; git diff --check passed
- Previous cast-timed lighting ZIP without non-winning reel darkening: 13 allowlisted runtime/documentation files, with every archived file hash checked against the source. SHA256 B18FE3810AA73ABDE86986136801E0BA2077B8D491727671848A5DB15934437C. Superseded by the duration-bar build; no game installation, upload or publication was performed
- Before removing non-winning reel darkening, an authored browser visual check covered all four result samples plus idle, comparing no light with maximum light. Symbols remained above the glow/dim artwork and retained their color; idle remained unchanged. Browser warning/error logs were empty. This checks the exported sample composition, not native aura selection, alpha inheritance or combat rendering

Browser evidence below was collected with a local-only web harness. Its page,
server, snapshot exporter and captured frames are not versioned. It reads the
cabinet and symbol PNGs into transparent 1024x1024 canvases in memory, matching
the runtime UV space. The duration refinement decodes the exported 1024x128 TGA
to an ignored PNG for browser inspection, preserving every runtime pixel.
The automated regression suite, art export tests and package checks are retained.

- Prior preview-only error repair: 42 off-client Lua tests, 8 art export checks, 27 package checks and all 8 TOC Lua syntax checks passed
- Prior regression checks verified all 13 native aura buttons have no add-on script handlers, runtime animation templates or animation groups. Four plain animation groups are confined to ordinary Edit Mode preview frames
- The art export fixtures compare every source pixel and generated padding pixel against independent RGBA patterns covering all alpha values; fresh -Check is read-only, stale pixel rejection leaves outputs untouched, and missing/wrong-size sources fail
- Independent asset comparison verified all 851,968 retained RGBA pixels match the pre-consolidation baseline; all 458,752 discarded pixels and 196,608 unused atlas pixels have alpha zero. Minimum per-region transparent padding is 5/7/7/23/24 pixels. Every retained pixel's position matches the baseline at nominal sizes 112 and 22
- Canonical cabinet.png is 1024x630 and symbols.png is 1024x832. Their retained RGBA pixels match the 1024x1024 predecessors exactly, and every discarded pixel was transparent. Export restores transparent rows through height 1024; both TGAs are byte-identical to the pre-trim runtime files, including headers, orientation and every RGBA pixel. At consolidation, these were the only two sources and runtime TGAs; the duration appearance refinement adds duration-fill.png and duration-fill.tga
- Browser inspection covered shared-atlas ordinary results and Jackpot, the sample footer, dim idle, 60%/100%/180% display widths and the 1.23-second landing frame. No sampled horizontal cuts, atlas bleed or changed visible scale were observed; browser warning/error logs were empty. This does not prove native filtering or restricted-client behavior
- Prior preview-only consolidated-atlas ZIP contains 13 expected files, with every archived source hash verified and all source/obsolete/preview assets excluded. SHA256 40BCEDD6140EFED0CD0A86A4E39796369BF293BBAF8BA2B8248436A00DF66CB6. Built without installation or upload

- Prior symbol-spacing revision on 2026-09-04: 40 off-client Lua tests and 28 isolated package checks passed; runtime Lua, TOC, settings and saved-state schema were unchanged
- Dice moved 22 atlas pixels left and coin 14 right; every RGBA pixel matches its translated baseline, including translucent edge colors. Their sizes and vertical positions are unchanged. Dice bounds are x89..422/y62..428 (334x367), with 89/89 side margins; coin bounds are x75..435/y68..428 (361x361), with 75/76 margins
- The prior spacing revision used built-in imagegen for more upright swords, then removed the generated checkerboard and guard backgrounds. Its original 512-pixel cell bounds were x111..400/y71..440 (290x370), with 111/111 side margins. Those visible pixels now live only in the canonical atlas; width remains 63.44 UI units instead of 91.22
- The complete 1024x1024 PNG and uncompressed BGRA32 TGA match every RGBA pixel, with top-left origin 0x28 and transparent guard openings. The rum cell and cabinet/Jackpot runtime textures remain byte-identical to the baseline; a repeated export reproduced all six PNG/TGA files byte-for-byte
- Browser inspection covered the corrected dice/coin/swords together at 60%, 100% and 180%, three-die Triple Threat, dim coin/swords/dice idle, the unchanged Jackpot control, slow playback and the 1.23-second landing frame. Inspected silhouettes have balanced side gaps without horizontal cuts. Repeated Test spin, result selection, timeline scrubbing and the local-only scale selector worked; browser warning/error logs were empty
- The local preview scale selector changes only CSS display width; it neither changes exported Lua geometry nor simulates native scale, alpha, filtering or combat. Native TGA loading, 60%/100%/180% readability, restart/reload, Edit Mode transitions and restricted-context rendering remain unverified on Retail 12.1.0.69587
- Prior symbol-spacing archive: 14 correctly named entries with all archived source hashes verified; SHA256 A3EA39FA758F6D0EEF961EAE9169A5BFEF6BF14559C77D0D60E8AD26697AD0A0. This is not the current consolidated-atlas package
- Prior randomized non-winning reel revision: 40 off-client Lua tests and 28 isolated package checks passed; all 17 Lua files passed syntax checks
- Randomized reel regressions cover all six ordered pairs across all four ranks, common lead-in art across every lane, reduced motion, duplicate/secret/unrelated cast payloads, visibility and restriction recovery, preview/live separation, retained landing offsets and full-symbol adjacent-lane clearance
- The exporter captured 47 actual-Lua snapshots for each of six variants across four ranks and idle: 30 sequences total. Every final tree matches its own settled tree. Two exports were byte-identical, SHA256 075F0FC761326B75DFCAF6313AA72A9B53269F0723C4879EE2C29AA58D151E23
- Export checks found 58,674 nodes with finite geometry, alpha and UV values and no native aura nodes. Forty focused non-browser DOM/canvas checks covered sample/variation choices, repeat randomness, normal/slow/restarted playback, scrubbing and reduced motion; these do not prove browser or game rendering
- Browser inspection on 2026-09-04 showed different One of a Kind combinations rolling into their final symbols, two dice plus a coin for Double Trouble, unchanged three-die Triple Threat, unchanged three-chest Jackpot and chest-free dim idle. No adjacent-lane bleed or moving internal cut was observed in the inspected samples, and browser warning/error logs were empty
- For the prior randomization revision, all six PNG/TGA exports and the TOC were byte-identical to its baseline. That revision introduced no texture generation, schema change or native aura-slot/frame increase
- Prior randomization archive: 14 correctly named entries with every archived source hash verified; SHA256 358CC70AB162598EB3BF1050E8670064837C20480F08D8AFE0C5273D32BA90C5. Built without upload or installation; this hash does not identify the symbol-spacing revision
- Prior exclusive Jackpot chest revision: 35 off-client Lua tests and 28 isolated package checks passed
- Prior construction/preview checks restricted the chest to three native Jackpot center rows and the labeled Jackpot preview centers/footer; the new lane-aware checks cover all seven authored chest centers with three visible at once
- Historical third-texture fixtures covered the former standalone Jackpot; current fixtures require only cabinet/symbols and prove stale jackpot.tga is excluded
- Preview server/inline-script syntax checks pass; a local route check served exact jackpot.png bytes as image/png and rejected an unlisted asset
- The historical 1254x1254 RGBA chest generation used built-in imagegen with real alpha; its prompt and former export process remain in Git history. The canonical atlas retains its approved exported pixels
- Chest PNG and uncompressed 32-bit TGA are 512x512 and match every RGBA pixel; nonzero-alpha bounds are (98,72)-(435,436), with fully transparent outer 32-pixel padding. Twenty-one isolated pixels at alpha 1/255 are preserved and visually negligible
- For the prior chest revision, all four ordinary atlas cells and cabinet PNG/TGA were byte-identical to its baseline; repeating export produced byte-identical output for all six PNG/TGA files
- Prior chest revision: all 16 Lua files passed syntax checks; the Lua preview exporter captured 47 snapshots for each of four ranks and idle, with every final tree matching its settled tree
- Prior browser inspection covered the three-chest Jackpot at rest and its staggered rolling landing, ordinary Double Trouble playback and chest-free dim idle; no browser warnings or errors were recorded. Actual native texture loading and 60%/100%/180% readability remain in-game proof gates
- Prior chest archive: 14 correctly named entries with source hashes verified; SHA256 F605A662C38E9A3341C12DF76BDF7667DC7AC545F49EE866889A633967AC6981, not the current symbol-spacing build
- Prior rum-bottle revision on 2026-09-04 passed 33 Lua tests and 26 package checks, with a verified 13-file archive; these are historical, not current chest results
- That prior atlas edit preserved the other three cells, cabinet and original source sheets; its 1024x1024 PNG/TGA matched pixel-for-pixel, and repeat export was byte-identical
- The prior bottle had a 245x370 visible extent, clear padding and one connected alpha component; browser inspection covered scrolling and the then-three-bottle Jackpot without reported browser errors
- Prior seam-fix evidence covered 47 snapshots per rank/idle, matching final/resting geometry, inspected lower-symbol transitions and 120 Hz backing coverage; it did not establish native client rendering
- The earlier 31-test landing prototype still produced the user-reported internal cut despite its ordinary-frame preview checks
- Ordinary sample captures are not native aura rendering: combat carrier movement, real clipping/layering, expiry and delayed/rapid-reroll behavior remain unverified
- Tests load the actual TOC order and add-on varargs; strict stubs reject unexpected calls, direct aura reads and result-child access after initialization
- Focused snapping checks cover scale conversion, UIParent-only final anchors and restriction interruption; they do not emulate native target selection
- Packaging checks Interface metadata, exact allowlisted paths/casing, texture headers/dimensions/pixel length and archived source hashes before replacing the generated ZIP
- Expected current archive: 14 files under RollTheBonesSlots/, comprising eight Lua sources, TOC, README, changelog and three runtime TGA textures
- Source artwork, tests, screenshots, repository instructions and this validation record are excluded
- No live-client rendering, taint, restricted encounters or exact-package installation is proven by these checks
- Version remains dev, schema remains 1; no remote, push, tag, installation or publication

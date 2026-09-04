# Development validation

Status: **Implemented, Unverified**. Source and off-client checks do not establish
release readiness. No live-client installation, game control, CVar changes or real
SavedVariables edits were performed for this revision.

## Target and evidence

- Retail live **12.1.0.69587**, Interface **120100**
- User GetBuildInfo screenshot: 12.1.0, 69587, Aug 27 2026, 120100, with empty fifth/sixth strings
- Installed Wow.exe and .build.info corroborate the version/build
- Source: Gethe/wow-ui-source live, commit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`; version.txt matches 12.1.0.69587
- No Classic, PTR, beta or other-build compatibility is claimed
- IronfurTracker informed the native-styled editor, ownership and packaging patterns; its dependencies, Interface declaration and optional third-party integrations were not copied

## Behavior and ownership

Each of three reels has four native singleton aura slots filtering the rank spell
IDs independently. One additional footer slot accepts all four IDs and binds the
actual icon, localized name and duration text: 13 slots across four containers.
Blizzard selects which preconfigured rank artwork is visible. Add-on Lua never
reads the active rank, aura values, slot visibility or restricted child widgets.
Native aura updates remain authoritative for rerolls, extensions and expiry.

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
with faded neighbors. The idle strip and an Awaiting a result footer sit beneath
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
before the native provider applies access restrictions. The native footer icon,
13 slots, frames, events, TOC, settings, SavedVariables and cosmetic state flow
remain unchanged. The sample footer uses the same atlas at nominal size 22;
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

The target build, TOC, 13 native slots/four containers, frames, settings, schema and
vertical motion timings are unchanged. Prebuilt lanes add 648 static texture
regions, with no per-spin construction or per-frame randomization. Their actual
client memory/rendering cost remains a profiling gate. Consolidation reduces the
runtime TGAs from three to two and slot pixel payload from 5 MiB to 4 MiB, without
claiming measured GPU-memory or frame-rate gains. No new artwork was generated.
Existing combat/restriction proof gates still apply; artwork is not combat evidence.

Core owns display availability, EditMode owns its selection/drag/preview session,
Machine owns cosmetic animation, and Config owns account-wide durable choices.
The editor uses native selection and guide templates with an owned floating
settings panel. Scale, position and animation save immediately. No native layout
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
| Duration extension, expiry, failed or interrupted cast | Evidence-gated | Native timer follows extension; absent/expired result reveals dim varied symbols and Awaiting a result; extension/failed cast does not fabricate a spin |
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

No user proof has yet been recorded for the continuous-strip seam correction.
The prior rum-bottle replacement has local export/preview evidence below, not in-game
proof. The corrected symbol spacing, randomized non-winning reels and exclusive Jackpot chest still need native rendering,
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
| Aura filtering | [CustomAuraContainer][container], [filter rules][filters]: four HELPFUL singleton includeSpellIDs slots per reel plus one four-ID footer slot; filtering and visibility stay native |
| Aura presentation | [CustomAuraButton][button]: SetIcon, SetSpellName and SetDurationText bind regions without an add-on countdown or rank readback |
| Initialization/flow | [Frame providers][provider], [AuraButton intrinsic][intrinsic], [AuraContainer][lifecycle], [CustomAuraContainer][container]: construct complete native strips before restrictions; TOPLEFT anchors tolerate zero-size containers; ordinary carriers provide animation geometry |
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
[provider]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua
[intrinsic]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.xml
[lifecycle]: https://github.com/Gethe/wow-ui-source/blob/8ea15b61e45c0ed4eba01439c90757f86eb78d34/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainer.lua
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
revision on 2026-09-04. The official [12.1 update notes](https://news.blizzard.com/en-us/article/24293281/curse-of-ula-tek-content-update-notes)
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

Browser evidence below was collected with a local-only web harness. Its page,
server, snapshot exporter and captured frames are not versioned. It reads the
two canonical PNGs into transparent 1024x1024 canvases in memory, matching the
runtime UV space without generating duplicate preview images.
The automated regression suite, art export tests and package checks are retained.

- Current consolidation: 40 off-client Lua tests, 8 art export checks and 27 package checks passed
- The art export fixtures compare every source pixel and generated padding pixel against independent RGBA patterns covering all alpha values; fresh -Check is read-only, stale pixel rejection leaves outputs untouched, and missing/wrong-size sources fail
- Independent asset comparison verified all 851,968 retained RGBA pixels match the pre-consolidation baseline; all 458,752 discarded pixels and 196,608 unused atlas pixels have alpha zero. Minimum per-region transparent padding is 5/7/7/23/24 pixels. Every retained pixel's position matches the baseline at nominal sizes 112 and 22
- Canonical cabinet.png is 1024x630 and symbols.png is 1024x832. Their retained RGBA pixels match the 1024x1024 predecessors exactly, and every discarded pixel was transparent. Export restores transparent rows through height 1024; both TGAs are byte-identical to the pre-trim runtime files, including headers, orientation and every RGBA pixel. The art directory contains only README.md, cabinet.png and symbols.png; media contains only the two runtime TGAs
- Browser inspection covered shared-atlas ordinary results and Jackpot, the sample footer, dim idle, 60%/100%/180% display widths and the 1.23-second landing frame. No sampled horizontal cuts, atlas bleed or changed visible scale were observed; browser warning/error logs were empty. This does not prove native filtering or restricted-client behavior
- Current consolidated-atlas ZIP contains 13 expected files, with every archived source hash verified and all source/obsolete/preview assets excluded. SHA256 F34AE15114A52B9375580C2BB81F2C1F9242BA69F0330CCCE64F3B9D757126FD. Built without installation or upload

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
- Expected current archive: 13 files under RollTheBonesSlots/, comprising eight Lua sources, TOC, README, changelog and two runtime TGA textures
- Source artwork, tests, screenshots, repository instructions and this validation record are excluded
- No live-client rendering, taint, restricted encounters or exact-package installation is proven by these checks
- Version remains dev, schema remains 1; no remote, push, tag, installation or publication

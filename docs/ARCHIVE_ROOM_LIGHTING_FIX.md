# Archive Room lighting / floor-overlay correction — PR #17

Base: `77ec39b86dd904b3ced5b6fa1ca021bb56b4a39b`.
Branch: `codex/archive-room-lighting-fix`. Visual correction only; do not merge automatically.

## Cyan-bounce correction pass

The Art Director accepted the corrected work-light cones, warm floor pools and
service-marking balance, but blocked the residual Scanner/Intake cyan ellipses.
The follow-up package
`ARCHIVE_ZERO_CyanBounceFix_v1_PRODUCTION_REVIEW.zip` has SHA-256
`1e75eacea2136d56f22218793c7f3fca8e313386033ec4da59975eb3eb011b76`.
Its supplied deterministic verifier ran unchanged and passed **31/31** checks.

Exactly one runtime PNG was supplied and integrated. The previous 320×88 RGBA
asset (`05c75ea2c12069f82c4c97382c5c3d3be084fd2b23c05b68d20f3e60aadf815f`)
is replaced by the corrected byte-exact asset
`3bea037b1ac1d97223e90b3d01fb846adedc5a7dbea2f88267a24838abd35df3`.
It uses irregular horizontal fragments, full-transparent gaps and asymmetric
falloff rather than a closed oval. Source files and offline composites were not
copied into runtime, and the PNG bytes were not regenerated or modified.

The existing shared-texture contract is unchanged:

| Instance | Position before/after | Scale before/after |
| --- | --- | --- |
| Scanner | (548,886) / (548,886) | (1,1) / (1,1) |
| Intake | (1508,886) / (1508,886) | (1,1) / (1,1) |

No alpha trim was justified by the real renderer, so the established values stay
exactly: Scanner **0.52** in Scanner Online, **0.68** in Sorter Online and
**1.00** in Full Line; Intake **1.00** only in Full Line. Visibility remains
Scanner hidden/visible/visible/visible and Intake hidden/hidden/hidden/visible
across Manual/Scanner/Sorter/Full-Line. Commissioning thresholds and manager
code are unchanged.

## Option C and verified provenance

The Art Director's Option C is a mixed fix: replace only the cone/pool overlays,
lower their runtime intensity, and lower the locked service-marking overlay's
alpha instead of repainting it. No new gameplay or room architecture.

Original `ARCHIVE_ZERO_ArchiveRoom_LightingFix_v1_PRODUCTION_REVIEW.zip` SHA-256:

`20f4818f6c66b9e8bf28bd03f4f1e9c0650117f1bb6c010477e6baa18cdf3c53`

The supplied read-only deterministic verifier ran unchanged: **31/31 PASS**,
including full package integrity, native-source correspondence, transparency and
exactly two runtime PNGs. No builder/regenerator ran; sources and offline previews
remain outside runtime.

| Runtime file | Geometry | Integrated SHA-256 |
| --- | --- | --- |
| `AZ4I_FX_worklight_cone_300x360.png` | 300×360 RGBA | `38d2e668c0d1f9bc7503b0b714be7f242997e71300c8b27235f56458822bd74f` |
| `AZ4I_FX_floor_pool_430x100.png` | 430×100 RGBA | `a1f5e02af860245f8a8585c9df59f9a84a466df0da822ad3ad9da35f1bda7492` |
| `AZ4I_FX_cyan_bounce_320x88.png` | 320×88 RGBA | `3bea037b1ac1d97223e90b3d01fb846adedc5a7dbea2f88267a24838abd35df3` |

Locked service marking remains byte-identical:
`145c7827f70219e677bad590ecd4f9889544748f3281b1af641669d15c5b0f3b`.

There are still **88** runtime PNGs. Relative to the original base there are the
two approved lighting replacements plus the single approved cyan replacement;
the other **85** images are byte-identical. Relative to the previous PR #17 head,
all **87 unrelated PNGs** remain byte-identical. Existing import files/policy are
unchanged: lossless, mipmaps off, alpha preserved, linear environment filtering.
Decoded/resident texture dimensions do not change.

## Exact-base diagnostic, before tuning

The exact base was rendered before asset replacement at phase zero. Its Full-Line
PNG still has historical SHA
`6ed570b59127ce23bd1cb74716cbea750537cb630e108e1471bf2077100294e6`.

A temporary, uncommitted capture modification then hid the four FloorReflections,
set ServiceMarkings effective alpha to **0.25**, and left old cones active.
The capture script was restored before implementation; its final bytes/diff are
unchanged. Only the observation/evidence is retained:
[diagnostic screenshot](screenshots/archive-room-lighting-fix/diagnostic/pools-hidden-markings-025.png).

Observation: removing the warm pools removes the repeated warm ellipses and
reducing markings quiets the lower screen, while old geometric cones remain.
That diagnostic also isolated the separate Scanner/Intake cyan ellipses. The
subsequent ART Director correction pass described above now replaces precisely
that one shared cyan texture; the diagnostic remains historical evidence, not the
final runtime result.

## Final runtime values and geometry

Values are the conservative suggested ART values; actual GPU inspection did not
justify amplification, arbitrary scaling or positional correction. Every active
value is inside its package range.

| Stage | Active cones | Cone alpha | Active pool alpha | Service-marking alpha |
| --- | --- | ---: | ---: | ---: |
| MANUAL_SHIFT | Receiving | 0.76 | 0.52 | 0.18 |
| SCANNER_ONLINE | Receiving + Scanner | 0.76 | 0.52 | 0.23 |
| SORTER_ONLINE | Receiving + Scanner + Sorter | 0.82 | 0.58 | 0.28 |
| FULL_LINE_ONLINE | all four | 0.88 | 0.64 | 0.35 |

Inactive cones/pools retain exactly their old hidden/zero-alpha state. Existing
RGB modulation and visibility thresholds remain unchanged. All other **20**
matrix entries are untouched, including FloorWear, pendant housings, haze,
cyan-bounce state values, architecture and shadows. No per-frame controller was
added.

| Cone pair | Before top-left | After top-left | Y delta |
| --- | --- | --- | ---: |
| Receiving | (95,245) | (95,245) | 0 |
| Scanner | (566,245) | (566,245) | 0 |
| Sorter | (1056,245) | (1056,245) | 0 |
| Intake | (1502,245) | (1502,245) | 0 |

Cone scale remains (1,1). Pendant positions remain
(195,145), (666,145), (1156,145), (1602,145). Pool positions remain
(30,876), (501,876), (991,876), (1437,876), scale (1,1).
Machine pivots, room framing, conveyor, parcel dimensions and all Z ordering are
unchanged. The focused test compares the complete actual environment geometry
snapshot with the exact-base snapshot, not a few selected coordinates.

At Full HD, temporarily hiding only cones for a second GPU readback isolates
their actual rendered contribution. In **all four pairs**, last bright bulb
pixel is Y=275, first changed cone pixel beneath it is Y=276: **0-pixel gap**.
This is the first nonzero 8-bit render difference, not a perceptual brightness
threshold. Close-up inspection separately confirms a very soft origin, gradual
spread, no old horizontal cap/trapezoid and a clean lower fade. No Y shift needed.

## Actual graphical review evidence

Official **Godot 4.7.2.stable.official.ed1daf0bf**, compatibility/OpenGL3.3,
NVIDIA RTX 3060 Ti on Windows. The original fifty lighting proof PNGs remain,
and the focused cyan correction adds twelve actual runtime PNGs plus three
metadata files:
15 exact-base state/Manual-Case references, 18 corrected room/Case captures,
16 raw before/after bulb/work-zone crops and one temporary diagnostic.

All are actual GPU captures or unscaled, unaltered crops of those GPU pixels.
No offline ART composite is used as runtime evidence. Camera/world transforms
are unchanged; phases and conveyor time are frozen at zero only in QA.

- [Full HD](screenshots/archive-room-lighting-fix/1920x1080/):
  four states, Manual/Full-Line CASE_0001, four bulb and four work-zone close-ups
  with matching exact-base crops.
- [1280×720](screenshots/archive-room-lighting-fix/1280x720/):
  four states plus both Case Panel coexistence captures.
- [960×540](screenshots/archive-room-lighting-fix/960x540/):
  same six captures; no new crop/overlap problem.
- [Exact-base references](screenshots/archive-room-lighting-fix/base/).
- [Cyan correction Full HD](screenshots/archive-room-lighting-fix/cyan-correction/1920x1080/):
  Scanner, Sorter and Full-Line rooms; requested Scanner/Intake close-ups; and
  Full-Line+CASE_0001.
- [Cyan correction 1280×720](screenshots/archive-room-lighting-fix/cyan-correction/1280x720/)
  and [960×540](screenshots/archive-room-lighting-fix/cyan-correction/960x540/):
  Scanner Online and Full Line at each size.

| Review | Observation |
| --- | --- |
| Manual Shift | Warm Receiving bulb/local response over a cool readable room; installed downstream machines remain dormant. Warm oval/ring and dominant floor-arrow presentation removed. |
| Scanner Online | Scanner activation remains clear. At alpha 0.52 its cyan response is visible but restrained, fragmented and open; no ellipse, closed oval, ring or uniform disc. |
| Sorter Online | Scanner response at 0.68 remains broken into floor catches while the Sorter bottleneck outline stays visually dominant. |
| Full Line | Scanner and Intake both show local irregular catches, not matching decals. Their different surrounding floor/machine context avoids distracting repetition; warm practical lighting remains dominant. |
| Scanner / Intake close-ups | Raw unscaled GPU crops retain transparent gaps and asymmetric falloff. Linear filtering does not reconnect the fragments into an oval or introduce a hard edge. |
| 720p / 540p | The fragmented silhouette survives fractional scaling with no cyan blob, objectionable aliasing or visual noise. No compensating alpha increase was applied at 540p. |
| Case Panel | FULL_LINE_ONLINE+CASE_0001 at Full HD is unchanged and readable; the floor-only correction does not compete with the panel or introduce a contrast issue. |

The actual room qualitatively follows the supplied Option-C preview. The native
HUD, existing bottleneck outline and exact frozen parcel phase differ from offline
composites; these are preserved gameplay presentation, not lighting regressions.
Repeated warm and cyan ellipse/decal appearance is removed in the actual Godot
output. This is technical/runtime validation only: the new evidence is awaiting
ART Director re-review and does not claim final artistic approval.

## Intentional historical-baseline exception

The PR16 Full-Line PNG and original ART/state/hash fixtures are **not overwritten**.
The old pixel hash is no longer the acceptance target for the nine approved alpha
entries/two textures. Corrected screenshots are **review candidates**, not a newly
approved golden baseline. A new approved golden should be adopted only after
independent visual approval, with an explicit follow-up decision.

The graphical guard instead checks every pixel outside actual visible corrected
cone/pool/marking bounds against the exact-base render. Engine canvas/camera
transforms and [viewport stretch](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-get-stretch-transform)
map bounds to physical GPU pixels; a one-physical-pixel filter-edge guard is used.
Inactive overlays are not excluded from comparison. These are conservative
drawing bounds, not a per-alpha-pixel segmentation. Locked asset/geometry tests
independently guard unrelated content inside those bounds.

For the correction pass, **outside-region changed pixels: 0** for all four states
and both Case frames at all three resolutions. Full-HD cyan deltas are 13,840
pixels in Scanner Online, 13,926 in Sorter Online and 28,043 in Full Line; 720p
Scanner/Full-Line deltas are 6,235/12,681; 540p values are 3,556/7,174. Manual
Shift changes zero pixels because both cyan instances are hidden. All reported
values and region bounds are in each resolution's metadata.
The existing generic progressive capture uses the same documented guard against
its retained PR16 Full-Line reference.

The correction comparison uses the current PR #17 runtime captures as its direct
reference, including Full-Line+Case. That frame changes only inside the two cyan
texture bounds; the panel and every pixel outside permitted overlay bounds remain
identical.

## Regression / authority / saves

All eight existing required local commands plus the focused lighting suite
exited **0** with official Godot 4.7.2:

| Validation | Result |
| --- | --- |
| Editor import | PASS |
| Case foundation | **477 checks PASS** |
| Manual Case UI | **1873 checks PASS** |
| Commissioning domain | **293 checks PASS**, unchanged manager |
| Progressive room states | **2503 checks PASS**, all 29×4 entries and dormant/true-disabled/caching/belt rules |
| Focused lighting | **583 checks PASS**, corrected cone/pool/cyan hashes and dimensions/import, locked marking, explicit cyan position/scale/visibility/alpha contract, complete geometry, authority isolation and pixel-guard negative controls |
| Production/upgrades/save/legacy migrations | PASS |
| Existing visual foundation | PASS at all three sizes; transformed gate/parcel overlap remains 0 at ±16°/0° and 13 coupled phases |
| Main 120-frame smoke | PASS |

All-state room/no-room 100-second result: **75 items, 150 Credits, 0.75/s,
fraction 0.00000**. Pending purchase: **balance 1, owned true, multiplier 2.00,
fraction 0.05000, pending 0.00**.

Lighting application leaves money/earned totals/items/fraction/pending/throughput,
flags/upgrades/full production save, playtime/full Case state and commissioning
state unchanged in running/stopped fixtures. Commissioning order, normal Full-Line
startup, dormant versus actual-disabled distinction, animation, single belt clock
and decorative parcels remain as PR16. Simulation/Economy/Case/Save/Commissioning
authority and all machine/conveyor/HUD/room scenes/scripts are unchanged.

Save contracts remain **Global v3 / Case v1 / Commissioning v1**, with no migration
or new live commissioning save integration. CI retains all existing steps and
adds only the focused lighting suite.

## Performance

Same unchanged `archive_room_polish_capture.tscn`, exact phase zero, same GPU:

| Full Line | Draw calls | Primitives | Texture bytes |
| --- | ---: | ---: | ---: |
| Previous PR #17 head | 81 | 1728 | 87,861,046 |
| Cyan correction | 81 | 1728 | 87,861,046 |
| Delta | **0** | **0** | **0** |

Both video-memory snapshots are 94,325,246 bytes. There remain 19 Phase4I textures,
41 polish static instances, four cones and four pools; no new room/overlay/large
texture instances. These are renderer counter snapshots, not sustained FPS tests.
[Base](screenshots/archive-room-lighting-fix/performance/exact-base.json) /
[corrected](screenshots/archive-room-lighting-fix/performance/corrected.json) metadata.

## Reproduce

Run the headless commands in `VALIDATION.md`. For real graphics:

```bash
godot --path . tests/archive_room_lighting_visual_test.tscn -- --capture=true --size=1920x1080 --out=C:/temp/pr17-review --base=res://docs/screenshots/archive-room-lighting-fix/base/1920x1080
```

Repeat for 1280x720 and 960x540 with matching reference folders. Without capture
arguments, inherited QA buttons/hotkeys switch stages and explicitly open
CASE_0001; no debug controls are added to main. Neither fixture loads/writes a
live save. Screenshots and human visual judgment complement, not replace, tests.

## Remaining scope / limitations

- The cyan ellipse blocker is superseded by this correction pass. Runtime and
  automated validation pass, but final ART Director re-review is still pending;
  the correction captures are review evidence, not a newly approved golden.
- Cones/floor response intentionally remain subtle, especially at 540p; no
  overbright compensation. Locked UI secondary text remains 9 physical pixels
  there; this PR does not redesign it.
- Final ART approval/new approved golden remain pending. No FPS benchmark or
  additional OS-driven manual-input study is claimed.
- No First Shift, Case rewards, automatic Cases, commissioning costs, new-game
  sequencing, save v4, production rebalance, machine redesign or Issue #13 fix.
  Historical PR16 notes anticipating First Shift in PR17 are superseded by this
  explicitly scoped lighting correction; that gameplay milestone is still deferred.

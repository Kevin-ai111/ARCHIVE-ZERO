# Progressive room commissioning states — Phase 5D / PR #16

Base: `4714f71f912e718818b5db4871bfe2eee18d05fb`.
Branch: `codex/progressive-room-states`. This milestone does not merge itself.

## Provenance and unchanged art

The original `ARCHIVE_ZERO_Phase5D_B_Progressive_Room_States_v1_PRODUCTION_REVIEW.zip`
was verified before implementation:

- ZIP SHA-256: `817263a7d30c1e3019d07edf3022d325a6a545a1e5d34012c8553a2b0454df0a`.
- Original read-only package verifier: **32/32 PASS**, including manifest hashes.
- State-4 offline reference SHA-256:
  `d6b1076a556e3d6be3998da015aa3e01a4d16a4335ff72981d3f709e7f7ede6e`.
- Zero supplied/new runtime PNGs. No artwork rebuilt, altered or imported from
  the offline previews; no alternate full-room textures.

`tests/fixtures/phase5d_base_asset_hashes.json` locks all **88** base PNGs by
individual SHA-256: 19 Phase-4I environment; 18 other environment/conveyor
(including unused legacy references); 5 Receiving, 5 Scanner, 6 Sorter,
4 Intake, 21 Case Panel, and 10 Case items. All bytes and the runtime asset count
are unchanged. Screenshots under `docs/` are validation evidence, not room art.

## Domain and startup boundary

`CommissioningManager` is a small Autoload owning only stage and ordered forward
progression. It never writes money, Case queue/progress, MachineRuntime flags,
upgrade ownership, pending time, throughput, production totals or rewards.

| Enum / stable save label | Public forward operation | Commissioned machines |
| --- | --- | --- |
| 0 `MANUAL_SHIFT` | explicit `reset_to_manual_shift()` | Receiving |
| 1 `SCANNER_ONLINE` | `commission_scanner()` from 0 | Receiving + Scanner |
| 2 `SORTER_ONLINE` | `commission_sorter()` from 1 | Receiving + Scanner + Sorter |
| 3 `FULL_LINE_ONLINE` | `commission_intake()` from 2 | all four |

Ordinary boot defaults to **FULL_LINE_ONLINE**. Main never resets the stage or
enqueues a Case. The existing HUD, upgrades, hidden Case Panel and aggregate
production remain backward compatible. Unknown machine IDs are not commissioned.
Wrong-order, duplicate and unsupported mutations return false without changes or
signals. A real change commits before emitting `commissioning_stage_changed`
exactly once. Reentrant mutations during signal publication reject, preventing
observers from seeing different stages for the same event.

The independent save-v1 payload has **exactly two String keys**:

```json
{"commissioning_save_version": 1, "stage": "FULL_LINE_ONLINE"}
```

`get_commissioning_save_data()`, `get_default_commissioning_save_data()`,
`is_valid_commissioning_save_data(data)` and `restore_commissioning_save_data(data)`
provide detached data, strict validation and atomic restore. Version 1 or JSON
numeric 1.0 is accepted; booleans, string versions, fractions, nonfinite numbers,
unknown labels, non-String keys/labels and missing/extra keys reject. A valid
same-stage restore succeeds silently. Valid changed-stage restore emits once.
The invalid corpus has 37 cases; all are silent and atomic.

**Global SaveManager remains v3; Case save remains v1; Commissioning save is v1
but is not added to live save/load.** First Shift startup and migration are
deliberately deferred.

## Persistent presentation composition

ArchiveRoom refreshes from production, simulation, upgrades, restored GameState
and commissioning signals. Each refresh reads both authorities. It never writes
either. Scanner/Sorter/Intake adapters accept an optional, backward-compatible
`commissioned` parameter; the Receiving adapter and generic placeholders are
unchanged.

- Uncommissioned: casing `(0.62,0.68,0.72,1)`, physical silhouette retained,
  idle/active emissives and Motor-I overlay hidden, animation frozen, bottleneck
  and red fault drawings suppressed. Actual runtime flags are preserved.
- Commissioned + enabled: existing active/idle/runtime presentation.
- Commissioned + genuinely disabled: original `(0.42,0.48,0.52,1)` casing,
  red status dot and diagonal fault line, original disabled upgrade behavior.

The package's legacy machine-matrix wording refers to an existing disabled
presentation. The explicit PR requirement takes precedence: **dormant is not
disabled/fault**. No red fault is repurposed as a commissioning cue.

`ProgressiveRoomStateMatrix` translates all 29 approved `STATE_MATRIX.json`
entries into static values, without runtime JSON parsing. Cached explicit named
NodePaths map existing groups/sprites: background, shelving, haze, bays, door,
cables, signage, floor wear, markings, four pendant/cone/shadow/pool sets, two
cyan bounces, optional sconces and foreground. No incidental child index lookup,
scene duplication or position/texture/scale/Z/filter changes occur.

The final alpha is approved modulation alpha × approved alpha multiplier.
Parent modulation reaches absolute-Z children too. The snapshot reports actual
effective modulation along the CanvasItem ancestry, visibility and each approved
alpha multiplier. Independent test JSON retains the complete original matrix.
Every entry is checked in every state, including after repeated runtime signals.
Environment application is event-driven and skipped for unchanged stage; no
environment `_process` or continuous redraw controller was added. Optional sconces
remain hidden with zero alpha, including Full Line.

## One continuous conveyor

| Stage | Existing slat/parcel presentation clock | Decorative parcels |
| --- | --- | --- |
| Manual Shift | frozen | hidden |
| Scanner Online | frozen | hidden |
| Sorter Online | runs only if actual throughput > 0 | hidden |
| Full Line Online | exact existing runtime behavior | existing behavior |

No segmented belt, second clock or per-parcel authority is introduced. Geometry
stays X=436..1668, parcel centreline Y=688, contact Y=703, baseline Y=920,
parcel size 42×30, with the same wrap endpoint. Issue #13 is untouched.

## Actual renderer evidence

Official `4.7.2.stable.official.ed1daf0bf`, compatibility/OpenGL renderer,
NVIDIA RTX 3060 Ti, Windows. All listed PNGs are **Godot GPU viewport readbacks**,
not offline ART composites or edited mockups. Machine phases and conveyor time
are zero/frozen for deterministic comparison; production processing is frozen
only in this explicit QA scene. Normal presentation animation is unchanged.

The QA scene offers stage buttons / keys 1–4 and explicit CASE_0001 / key C.
No such controls or initialization enter main. The capture route additionally
checks that stage selection does not mutate production or an already open Case.

| State | Runtime inspection at all three physical resolutions |
| --- | --- |
| Manual Shift | Receiving cone/pool dominate; downstream silhouettes and blue depth remain readable, no red faults or parcels. |
| Scanner Online | Scanner beam, local cone/pool and restrained cyan response clearly activate; downstream remain dormant. |
| Sorter Online | Central cone/pool and Sorter lighting activate, clearly distinct from state 2; Intake remains dormant. Existing real Sorter bottleneck outline is retained. |
| Full Line Online | Existing full-line scene restored; deterministic Full-HD pixels exactly match the pre-PR in-engine baseline. |
| Manual + Case Panel | CASE_0001 fully contained; Receiving cue remains visible outside the right-side panel. |
| Scanner + Case Panel | Scanner activation and worklight remain visible to the left of the panel; all panel controls/text retain layout. |

Evidence folders:

- [1920×1080](screenshots/progressive-room-states/1920x1080/): all six required
  captures plus the same actual-disabled Scanner in dormant/full-line stages,
  proving no fault in dormant and preserved red fault when commissioned.
- [1280×720](screenshots/progressive-room-states/1280x720/): all four states and
  both Case Panel coexistence captures.
- [960×540](screenshots/progressive-room-states/960x540/): the same six captures;
  state progression, machine silhouettes, HUD and panel bounds remain clear.
- [Pre-PR Full Line](screenshots/progressive-room-states/base-full-line.png) and
  [its renderer metadata](screenshots/progressive-room-states/base-full-line-metadata.json).
  The baseline was rendered at the exact base before presentation modifications,
  using the unchanged `tests/archive_room_polish_capture.tscn` at phase 0.

Full-HD baseline and Full-Line PNG SHA-256 both:
`6ed570b59127ce23bd1cb74716cbea750537cb630e108e1471bf2077100294e6`.
The visual fixture compares decoded pixels and fails on differences at Full HD.
This exact comparison is reproducible on the same renderer/font environment;
cross-platform pixel identity is not guaranteed and is not a CI requirement.

Qualitative comparison with the supplied offline four-state preview confirms
left-to-right activation, preserved blue room depth and distinct local work
zones. Offline previews feather composite masks and omit native HUD, the actual
production bottleneck drawing and live animation phases. Those differences are
not hidden or reproduced with new textures; actual nodes use the exact numerical
matrix. Pixel identity is asserted against **the pre-PR Godot baseline**, not
against the offline artwork. Final artistic approval remains independent.

At 960×540 the locked Case Panel's smallest secondary text remains **9 physical
pixels** (18 logical). It fits without clipping but is small; no readability
redesign is claimed or made. Full HD is the primary target, 720p is practical.
These are renderer/layout inspections, not a new OS-driven manual-input study.

## Reproduction and regression results

Import, then run the eight commands in `VALIDATION.md`; all exited **0** locally:

| Validation | Result |
| --- | --- |
| Editor import | PASS, no parser/script errors |
| Case foundation | **477 checks PASS** |
| Manual Case Processing | **1873 checks PASS**, including ten Cases / three resolutions and FOUND negative control |
| Commissioning domain | **293 checks PASS**, order, signals, strict save, 37 invalid payloads and authority isolation |
| Progressive room presentation | **2503 checks PASS**, complete 29×4 matrix, true-disabled distinction, cached refresh, 88 asset hashes |
| Production/upgrade/save/migrations | PASS; pending purchase: balance **1**, owned **true**, multiplier **2.00**, fraction **0.05000**, pending **0.00** |
| Existing visual foundation | PASS at all three resolutions; transformed Sorter gate overlap **0** at ±16°/0° and 13 coupled phases; Intake terminal occlusion preserved |
| Main-scene 120-frame smoke | PASS |

Every commissioning operation and repeated room refresh leaves money, earned
money, processed totals, fractional progress, pending time, throughput, enabled
flags, upgrades, production save, playtime and full Case queue/progress unchanged
in both running and stopped fixtures. With and without ArchiveRoom, **all four
stages** produce the same 100-second result: **75 items, 150 Credits, 0.75/s,
fraction 0.00000**. Production/Economy/SaveManager/Case authority code is untouched.
CI adds only the two new suites and retains every existing validation step.

Graphical reproduction (choose each of 1920x1080, 1280x720, 960x540):

```bash
godot --path . tests/progressive_room_states_visual_test.tscn -- --capture=true --size=1920x1080 --out=C:/temp/phase5d-1920x1080
```

The graphical runs passed at all three sizes. For live stage switching, launch
the same scene without capture arguments; visuals animate from existing
presentation information, not numerical production. No actual save file is
loaded or overwritten by the fixture.

## Full-line performance delta

Same official engine/GPU, deterministic phase 0 and unchanged baseline capture
fixture; renderer counters, not a sustained FPS benchmark:

| Snapshot | Draw calls | Primitives | Texture residency bytes |
| --- | ---: | ---: | ---: |
| Exact base Full Line | 81 | 1728 | 87,861,046 |
| New Full Line | 81 | 1728 | 87,861,046 |
| Delta | **0** | **0** | **0** |
| Manual Shift | 61 | 1634 | 87,861,046 |
| Scanner Online | 64 | 1644 | 87,861,046 |
| Sorter Online | 67 | 1660 | 87,861,046 |

Case-panel captures add existing UI draw/texture load and are not mixed into
the room-only comparison. Full metadata records accompany each resolution.
No new large runtime textures, machine/conveyor instances or duplicate room
scenes; environment state is not applied every frame.

## Deliberately deferred / limitations

The room can look dormant while aggregate production and the unchanged HUD still
report normal throughput/bottleneck. This separation is deliberate in PR #16,
not a gameplay lock. PR #17 owns First Shift initialization/sequencing, explicit
Manual-Shift new-game startup, costs/rewards and later live-save migration.
No automatic Cases, tutorial timing, anomaly/story triggers, penalties, research,
containment, global save v4, artwork edits or Issue #13 changes are included.

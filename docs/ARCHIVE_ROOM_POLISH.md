# Archive Room unified visual polish — Phase 4I-C

## Provenance and base

Branch: `codex/archive-room-polish`; base `c6d861b5f2e77d1d51b235a20da0a9a98a5671e3`.
PR #11 is merged into that exact base. The integration uses only the supplied
Phase 4I-B package and the retained Phase 4E environment assets.

ZIP: `ARCHIVE_ZERO_Phase4I_B_Archive_Room_Unified_Polish_v1_PRODUCTION_REVIEW.zip`.
SHA-256: `c78ba59b56edd1919847bfd735a96d759ae11a940512774cc5fa8a6509d57bcf`.

Independent inspection passed ZIP CRC, 57 entries, all 56 manifest hashes,
19 runtime images with documented RGB/RGBA modes and transparency, native/runtime
correspondence, all three exact nearest-neighbour 2× signage exports, and all
seven editable layers of the 1920×1080 OpenRaster source. Runtime contains
only environment PNGs, no machine/conveyor/parcel/HUD art or gameplay data.
The supplied `source/verify_phase4i_b.py` returned 146/146 PASS.

The supplied `validation_report.json` has the acknowledged pre-packaging
`zip_pending=true` and 56-entry metadata. No supplied file was changed to
correct that metadata. Source scripts, ORA, and offline previews stay outside
the Godot project.

## Integration boundary and draw order

Only `scenes/world/archive_room_environment.tscn` and its presentation adapter
change the runtime. ArchiveRoom, the camera, HUD, machine scenes/scripts/assets,
the conveyor/parcel renderer, and all authoritative gameplay systems are
byte-identical to the base.

The nineteen textures assemble into 41 Sprite2D instances, sharing one resource
for repeats. Nine existing base textures remain referenced (28 total).
The rear wall, catwalk, roof, three core pillars, pipes, pinboard, base floor,
and existing ceiling cables retain their placements.

All transforms are checked against the packaged manifest represented in
`tests/fixtures/archive_room_polish_contract.json`:

- distant background at (0,0), absolute Z −100, replacing the old sprite;
- shelving −84, haze −80, bays −78/−77, service door −76;
- two new cable runs −68 and A1/A2/TRANSFER signage −62 at the specified
  positions; signage keeps 0.5 scale and exact 2× textures;
- four pendant top-centres (245,145), (716,145), (1206,145), (1652,145), Z −50;
- four matching cone top-centres at Y245, Z −52;
- floor wear at Y920, Z −8; four scaled machine shadows at Y866, Z −2;
- service markings at Y900, warm pools at Y876, cyan bounce at Y886, all Z −1;
- lower rails at (0,970) and (1560,970), absolute Z20.

The old three pendant/cone/pool instances are replaced, not retained as a
second lighting stack. Their textures and the old distant background are
not referenced by the new scene.

Legacy wall sconces remain optional development nodes at their original
positions, behind signage at Z −63, and hidden by default. Actual Godot review
showed their glow could show through the transparent A1/A2 artwork. Keeping
them off restores the supplied four-worklight composition without changing
the PNGs; `set_wall_sconces_visible()` still allows explicit inspection.
The housing control now controls the four new pendants only.
Cones, floor reflections (including cyan bounce), haze, and sconces are
independently controllable. No environment processing callback, Light2D,
material effect, or new animation clock is introduced.

Ground overlays remain below conveyor Z4 and machine art Z5–12. Rail bounds
start at Y970, below the locked Y920 machine footprints and parcel path.
The unchanged HUD is in CanvasLayer1 above the world canvas, so world Z20
cannot obscure it. Environment nodes are not Controls and cannot intercept input.

## Immutable assets and geometry

All 25 machine/conveyor PNGs remain SHA-256-identical to the recorded base.
Exact paths and hashes are in
`tests/fixtures/phase4i_locked_asset_hashes.json` and are asserted in CI.
Godot integration preserves all four layer contracts, including Scanner and
Sorter Motor I, the Sorter gate pivot/child offset, and Intake carrier geometry.
There is exactly one DecorativeParcelVisual. X436..1668, centre Y688,
42×30 parcels, belt contact Y703, baseline Y920, camera (960,540), and the
1920×1080 logical canvas are unchanged.

## Actual graphical evidence and filtering

Captured using official Godot `4.7.2.stable.official.ed1daf0bf`,
Compatibility/OpenGL 3.3, NVIDIA GeForce RTX 3060 Ti. These images are Godot
viewport captures, not offline composites:

- [1920×1080 room and HUD](screenshots/archive-room-polish-1920x1080.png)
- [1280×720 room and HUD / selected linear](screenshots/archive-room-polish-1280x720.png)
- [960×540 room and HUD](screenshots/archive-room-polish-960x540.png)
- [1920×1080 environment alone](screenshots/archive-room-polish-environment-only-1920x1080.png)
- [1280×720 nearest comparison](screenshots/archive-room-polish-nearest-1280x720.png)
- [filter detail comparison](screenshots/archive-room-polish-filter-detail-1280x720.png)
- [960×540 upgrade shop](screenshots/archive-room-polish-upgrade-shop-960x540.png)
- [base environment comparison in the same room](screenshots/archive-room-polish-base-comparison-1920x1080.png)
- [121-frame parcel-passages proof](screenshots/archive-room-polish-parcel-passages-1280x720.gif)
- [twelve representative rendered passage phases](screenshots/archive-room-polish-parcel-contact-sheet.png)

Linear filtering is retained on the environment. At 2/3 physical scale it
reduces uneven pixel cadence on cable diagonals, pendant edges, and signage;
nearest retains hard edges but makes repeated thin lines and floor markings
more uneven. At half scale small distant texture detail inevitably loses
resolution. Signage source pixel grids, scene scale, and all supplied pixels
are unchanged; imports are lossless with no mipmaps. The existing Intake
front-mask nearest override remains unchanged.

Direct review confirms four warm work-light positions, a cool/dark rear plane,
visible grounding, dominant machine silhouettes, legible primary HUD and both
shop cards, unobstructed bottom controls, and no new environment over the
parcel path. The 121-frame proof advances the existing presentation animation
in 0.15-second steps over 18 seconds. It shows repeated outlet, Scanner, Sorter,
and terminal Intake passages, with no new gap or visibility pop.

## Comparison with the ART offline composite

The integration was compared directly to
`previews/AZ4I_gameplay_offline_1920x1080.png`, the authoritative package
reference. Camera composition, machine bounds, four-light rhythm, A1/A2 and
TRANSFER signage, cool depth, sparse rails, warm floor pools, and restrained
cyan bounce agree. No new art or effects were added to emulate the external
presentation board.

Expected visible differences are the real HUD and live bottleneck border,
actual slat/parcel/scan/gate/carrier phases, retained Phase 4E cable modules,
and engine filtering/rasterization. The offline builder composites whole
categories over the base; Godot follows the explicit absolute-Z manifest,
which can make shelving/haze and rear architectural intersections more subdued.
The Intake covers part of the TRANSFER sign as it does in the offline reference.
The package is deliberately restrained; no neon amplification or global
darkening was added. Final artistic approval is not claimed.

## Performance and residency

Source decoded memory (RGB uses three channels, RGBA four):

| Scope | Textures | Bytes | MiB |
| --- | ---: | ---: | ---: |
| New Phase 4I package | 19 | 9,894,208 | 9.436 |
| Referenced complete environment | 28 | 11,397,016 | 10.869 |

Actual renderer monitors at the captured Full-HD phase:

| View | Draw calls | Primitives |
| --- | ---: | ---: |
| Base environment in the same room | 67 | 1,672 |
| Polished room and HUD | 81 | 1,728 |
| Polished environment alone | 27 | 178 |

The actual batched draw increase is 14, not the offline unbatched estimate.
The motion proof reports 81 draw calls throughout its 121 frames.

At Full HD the renderer reports total process video memory 78,778,306 bytes
(75.129 MiB) and texture memory 72,314,106 bytes (68.964 MiB).
Those global monitors include machines, UI/font resources, and render targets;
they are not environment-only residency. The source decoded totals above
are the exact environment accounting before GPU alignment/compression.
Baseline capture swaps only the scene for draw-count comparison; new textures
were preloaded, so its memory is not an isolated old-build benchmark.
No FPS/capture duration is reported as isolated GPU render cost.

Metrics and capture parameters are recorded in
`docs/ARCHIVE_ROOM_POLISH_RENDER_METRICS.json`. Every environment node is
checked to have no continuous process or physics callback. Static sprites
are retained by Godot; only the existing machine/conveyor animation redraws.

## Automated validation and reproduction

All requested commands exit 0 with Godot 4.7.2:

```bash
godot --headless --editor --path . --quit
godot --headless --path . tests/production_pipeline_test.tscn
godot --headless --path . tests/visual_foundation_test.tscn
godot --headless --path . --quit-after 120
```

Actual numerical results:

- pending purchase: balance=1, owned=true, multiplier=2.00,
  fraction=0.05000, pending=0.00;
- 100-second room/no-room invariance: items=75, credits=150,
  throughput=0.75, fraction=0.00000;
- environment controls/inspection preserve an additional snapshot with
  pending=0.20 and fraction=0.60000;
- Sorter gate: zero visible parcel-alpha intersections at −16°, 0°, +16°
  and all 13 coupled conveyor phases;
- Intake terminal: zero visible parcel samples at X1665,1666,1668;
- all existing production, upgrade, save/load, migration, machine-state,
  occlusion, conveyor-contact, and HUD-purchase tests pass.

New tests independently inspect real scene texture resources, counts,
positions, scales, effective Z (including inheritance), image hashes, no
mipmaps, static behavior, ground/rail geometry, and HUD canvas ordering.
No numerical gameplay file or save schema is changed.

The opt-in graphical capture scene is reproducible and absent from the
normal game/test execution:

```bash
godot --path . tests/archive_room_polish_capture.tscn -- --size=1920x1080 --out=/absolute/proof/fullhd
godot --path . tests/archive_room_polish_capture.tscn -- --size=1280x720 --out=/absolute/proof/linear
godot --path . tests/archive_room_polish_capture.tscn -- --size=1280x720 --filter=nearest --out=/absolute/proof/nearest
godot --path . tests/archive_room_polish_capture.tscn -- --size=960x540 --out=/absolute/proof/half
godot --path . tests/archive_room_polish_capture.tscn -- --size=1920x1080 --variant=environment --out=/absolute/proof/environment
godot --path . tests/archive_room_polish_capture.tscn -- --size=960x540 --variant=shop --out=/absolute/proof/shop
godot --path . tests/archive_room_polish_capture.tscn -- --size=1280x720 --frames=121 --out=/absolute/proof/passages
```

For the base draw-count comparison, obtain the environment scene at the exact
base SHA, omit its presentation script resource/binding (the adapter now targets
the polished groups), and pass its absolute path using `--baseline=...`.
The proof utility freezes automatic production and animation, then advances
only existing visual methods; it does not affect normal gameplay behavior.

## Imported runtime SHA-256

| Path under assets/environment/phase4i | SHA-256 |
| --- | --- |
| `background/AZ4I_BG_distant_archive_1920x792.png` | `f56c4491abcd455247ec87df4b15068c74c42f35fbc3cd103c9d2a0b53a17979` |
| `midground/AZ4I_MG_bay_recess_A_420x330.png` | `e14187c4f5b4e888e6d0ca7e5c10fd2fafddd3f96d9e9f1675e9f739b13d10dd` |
| `midground/AZ4I_MG_bay_recess_B_440x330.png` | `ac03ac853ae513d4bf974e8bed79b5320377380316734b481c06ead5843afece` |
| `midground/AZ4I_MG_service_door_176x290.png` | `bc451bc07f1a5634be24a765d0637c54e00d16476b2b13802db855714c4e62e9` |
| `midground/AZ4I_MG_archive_shelving_320x230.png` | `f49b2e1043047c00030813d4e80b6c10b8ba07ea81919d2fca5495804d444328` |
| `overhead/AZ4I_OV_cable_run_1_560x180.png` | `e8b451fdc67e2ca6d39095ff17b4e6a5ab573dc0775c553fa80134dd2edc7348` |
| `overhead/AZ4I_OV_cable_run_2_560x180.png` | `93903a109cf4340d5d9984e01fc939a31206cc0e1c0645c89f6b346d55ead14d` |
| `overhead/AZ4I_OV_pendant_100x148.png` | `13d32642e7ff82f2ab7c1c8713880f71f74aefe334caf20c133b9985439e44ba` |
| `lighting/AZ4I_FX_worklight_cone_300x360.png` | `981031e370c72df1e2fdf6bd6dfb42f5b2d4495df2e3067fc837d9a8f27cad49` |
| `lighting/AZ4I_FX_haze_strip_640x240.png` | `8a192ac1ea79af74ed0e8de690cf769a4a813fe69545a5118cc1daba4cc44ee4` |
| `ground/AZ4I_GR_floor_wear_512x160.png` | `5845f62303bd955c52c668b8e2f0b896b997e0d331dee8228a9b65c81ee6b7dd` |
| `ground/AZ4I_GR_machine_shadow_512x96.png` | `75f817049070145abe89aea7326fa0eb7cd9c6b7d79f72fb8fdf83a230a873ab` |
| `ground/AZ4I_GR_service_markings_512x128.png` | `145c7827f70219e677bad590ecd4f9889544748f3281b1af641669d15c5b0f3b` |
| `lighting/AZ4I_FX_floor_pool_430x100.png` | `cba3892f763c06c64a0b297f897e7395d1c908b56871d7c8856237b066ebfd4b` |
| `lighting/AZ4I_FX_cyan_bounce_320x88.png` | `05c75ea2c12069f82c4c97382c5c3d3be084fd2b23c05b68d20f3e60aadf815f` |
| `signage/AZ4I_SG_sector_A1_96x128_2x.png` | `2d762f76ac5e9c1f3126f15ca4478cd03044f96ceaf689dbe3326c858922d96f` |
| `signage/AZ4I_SG_sector_A2_96x128_2x.png` | `dcb2f072745c60d00cdfd319c76c942788fadad5616e95e916be55a45610132c` |
| `signage/AZ4I_SG_transfer_160x64_2x.png` | `29459f72b5dfcecaa624eafece6dca7bd20ec9e8d621505b9c369f15b733e3a4` |
| `foreground/AZ4I_FG_lower_rail_360x110.png` | `8de580e1172b2ab01333affa76486f25d3dd3827c0740f19dcc58c5b6ead63b2` |


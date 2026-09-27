# Receiving Desk art configuration

## Accepted runtime package

The Phase 4F integration uses the five runtime PNGs from
`ARCHIVE_ZERO_Phase4F_Receiving_Desk_v1_PRODUCTION_REVIEW.zip`. The received
ZIP has SHA-256
`E5F4690D0ADCBD758DC793561E2BB7039F3A3A52471597D380DDB6D4CA7D6380`.

The original package was independently checked before integration:

- all 21 files covered by `SHA256_MANIFEST.txt` match their recorded hashes;
- `asset_manifest.json`, `docs/CODEX_HANDOFF.md`, and
  `validation_report.json` agree on pivot, bounds, layer offsets, and Z order;
- all five runtime files decode as RGBA with real transparency and the exact
  manifest dimensions;
- every runtime export retains the documented exact 2× pixel grid;
- the editable OpenRaster source is a valid five-layer archive;
- the referenced Scanner and Phase 4E environment packages match their
  recorded hashes.

Only the five byte-identical runtime PNGs were copied into
`assets/machines/receiving_desk/`. Editable sources, build tools, reports, and
offline proofs remain outside the game project.

| Runtime layer | Export size | SHA-256 |
| --- | ---: | --- |
| `AZ_RCV_back_idle_2x.png` | 672×704 | `9c6ad96b6f4447a3b7f8fd6a2076c02914bac0894b12dc11a4e552e70635570e` |
| `AZ_RCV_decor_receipts_2x.png` | 384×100 | `84c61402c0d9e112a3ec1b1003893b3eab45069c6371bad508026e85c1e81252` |
| `AZ_RCV_emissive_idle_2x.png` | 576×162 | `8e7ddd9ce0d3e72893acad1d9c8c6074f6bf554e76c757f3d234d406c548dc8a` |
| `AZ_RCV_feed_wheel_2x.png` | 96×96 | `f0b53f8e9d199f99103bcf1f76fb51ff84babab4f6dd85046d5ed512fb9478d5` |
| `AZ_RCV_front_mask_2x.png` | 672×704 | `77cf32c80a8a0602a4182d66872cfa393d29ef64f00b27fe4053888b1c373488` |

## Runtime assembly

`receiving_desk_visual.tscn` replaces only the Receiving Desk greybox. Its root
keeps the existing state interface but overrides the procedural draw routine,
so the generic machine body is not duplicated behind the new artwork. Basic
Sorter and Archive Intake continue to use the unchanged generic placeholder.

The scene is instanced at world pivot `(268, 920)`. Every texture uses scale
`(0.5, 0.5)`, producing the approved 336×352 logical footprint and world bounds
X=100..436, Y=568..920.

| Layer | Local top-left / pivot | Absolute Z |
| --- | --- | ---: |
| Rear casing | `(-168, -352)` | 5 |
| Static paperwork | `(-136, -244)` | 5 |
| Idle lighting | `(-120, -280)` | 7 |
| Feed-wheel pivot | `(116, -173)` | 8 |
| Front occlusion mask | `(-168, -352)` | 10 |

All five presentation layers disable relative Z inheritance. The feed-wheel
texture is centered under its documented pivot Node2D, so rotation never uses a
texture corner.

## Conveyor hand-off and visual states

The existing conveyor and its single decorative parcel renderer are unchanged.
The first parcel path point is X=436, the centreline is Y=688, and parcel bottoms
meet the belt surface at Y=703. Rear casing Z=5, parcels Z=6, lighting Z=7,
wheel Z=8, and front mask Z=10 let parcels pass over the rear intake channel and
under the outlet guard. Alpha sampling verifies that the front guard is clear on
the approach and becomes opaque exactly at the outlet edge.

- **Enabled:** casing and paperwork use their authored colour; idle lighting is
  independently visible.
- **Active:** the optional feed wheel rotates from presentation time only.
- **Line stopped:** the wheel process callback is disabled and its angle freezes,
  even when the desk itself remains enabled.
- **Disabled:** the static layers dim, idle light switches off, and the existing
  stopped marker appears.
- **Bottleneck:** the established amber outline is retained.

The visual reads `SimulationManager` state through `archive_room.gd`. It cannot
create items, award Credits, affect throughput, or install an upgrade. No
Receiving Desk upgrade was added.

## Filtering, rendering, and performance

The scene uses linear filtering, matching the Basic Scanner. At Full HD, the 2×
exports resolve exactly to their 336×352 logical design. At 1280×720, nearest
filtering produced slightly harder but uneven fractional pixel cadence on the
desk's diagonals, paperwork, and wheel. Linear filtering introduces mild
softness but keeps those details and the Scanner visually consistent. In the
desk crop, the two rendered 1280×720 captures differ by mean absolute RGB values
of only `0.094`, `0.072`, and `0.048`, but the linear result is more stable at
the 2/3 canvas transform. The 960×540 half-scale render remains readable.

Actual Godot 4.7.2 Compatibility/OpenGL 3.3 captures were made in fullscreen at
1920×1080 and in windows at 1280×720 and 960×540 on an NVIDIA GeForce RTX 3060
Ti. A 120-frame Full-HD observation after 30 warm-up frames measured 833.259 ms
wall time, or 6.944 ms/frame, with 68 reported draw calls. Godot reported 54.14
MiB total video memory for that process. These are development-machine
observations, not a shipping performance guarantee.

The five decoded RGBA textures total 4,348,416 bytes (4.147 MiB) before GPU
alignment, render targets, driver formats, or other game assets. Static layers
have no process callback. Only the active wheel adds continuous desk work, and
it stops with the production line.

## Godot render evidence

- [1920×1080 active room](screenshots/receiving-desk-art-1920x1080.png)
- [1280×720 active room](screenshots/receiving-desk-art-1280x720.png)
- [960×540 active room](screenshots/receiving-desk-art-960x540.png)
- [1280×720 disabled desk](screenshots/receiving-desk-disabled-1280x720.png)
- [1280×720 Receiving Desk bottleneck](screenshots/receiving-desk-bottleneck-1280x720.png)
- [1280×720 linear filter](screenshots/receiving-desk-filter-linear-1280x720.png)
- [1280×720 nearest filter](screenshots/receiving-desk-filter-nearest-1280x720.png)
- [960×540 wheel, parcel, and scan motion](screenshots/receiving-desk-wheel-motion-960x540.gif)

## Comparison and review limits

The Full-HD Godot render was compared with the supplied offline Full-HD proof.
The desk-region mean absolute RGB difference is `0.544`, `0.419`, and `0.270`
levels per channel. Visible differences are expected runtime state: the Godot
capture starts at zero Credits, uses a live parcel phase and wheel angle, draws
the established live HUD including its display-mode button, and derives
bottleneck feedback from the simulation.

No supplied artwork was regenerated or modified. The result closely reproduces
the package assembly, including transparency and outlet occlusion, but it is not
a claim of final artistic approval. Full HD remains the primary art-review
target; fractional 1280×720 output is mildly softened, and the 960×540 target is
a supported readability regression rather than a pixel-perfect presentation.

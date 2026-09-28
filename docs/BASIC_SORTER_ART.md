# Basic Sorter art configuration

## Accepted runtime package

The Phase 4G integration uses the six runtime PNGs from
`ARCHIVE_ZERO_Phase4G_Basic_Sorter_v1_PRODUCTION_REVIEW.zip`. The received ZIP
has SHA-256
`2BCF542116573753ADB7F8B4DC0D08321800263F02A235DA8C57D352E96F796C`.

The original package was independently checked before integration:

- all 23 entries in `SHA256_MANIFEST.txt` match their files;
- all six runtime images decode as RGBA with genuine transparency, exact
  manifest dimensions, and exact nearest-neighbour 2× grids;
- every downscaled runtime layer is pixel-identical to its documented crop in
  the six-layer OpenRaster source;
- the default-hidden Motor I source layer and the gate pivot geometry match the
  manifest;
- assembling the five standard runtime layers reproduces the supplied RGBA
  assembly exactly;
- the existing Scanner, Receiving Desk, and original Phase 4E environment
  reference hashes remain unchanged.

Only the six byte-identical runtime PNGs were copied into
`assets/machines/basic_sorter/`. Editable source, build scripts, reports, and
offline previews remain outside the game project.

| Runtime layer | Export size | SHA-256 |
| --- | ---: | --- |
| `AZ_SRT_back_idle_2x.png` | 960×720 | `88a248039ab2662294a6cc4cae43a82cfde85a2fdbf97afa8854d564f5b2d29b` |
| `AZ_SRT_front_mask_2x.png` | 960×720 | `873ddfbff06d46138b23892ab2b2dcbcd257aebcf6d3eb1d6280d0814637e421` |
| `AZ_SRT_emissive_header_2x.png` | 728×104 | `baf13a3068da79802ae4d22f4030b6abaeaa09b37b23740bf80b1d4fab8eea76` |
| `AZ_SRT_emissive_bays_2x.png` | 538×22 | `b87b9fd8aa1b8b0c9ba340a327c6f99dcc2593ba77940f17e01d73cbe5170d7f` |
| `AZ_SRT_sorting_gate_2x.png` | 192×192 | `aef09f9733d9e4a75b1ddae4ac3937c1d6386956107aa373157d874df12bb082` |
| `AZ_SRT_upgrade_motor_2x.png` | 188×260 | `06d5e3b5cdc3c5b0a8b38e41cdf23c1ee98ba7a50ea69d70d5022fc7830524b7` |

## Runtime assembly

`basic_sorter_visual.tscn` replaces only the Basic Sorter greybox. Its adapter
inherits the established machine state API but overrides the procedural draw
routine, so no generic Sorter body remains behind the supplied art. Archive
Intake continues to use the unchanged placeholder.

The scene is instanced at world pivot `(1204, 920)`. Every texture uses scale
`(0.5, 0.5)`, preserving the approved 480×360 logical footprint and world bounds
X=964..1444, Y=560..920.

| Layer | Local top-left / pivot | Absolute Z |
| --- | --- | ---: |
| Rear housing | `(-240, -360)` | 5 |
| Header indicators | `(-178, -288)` | 7 |
| Bay indicators | `(-134, -183)` | 7 |
| Gate pivot | `(18, -266)` | 8 |
| Front mask | `(-240, -360)` | 10 |
| Sorter Motor I | `(125, -150)` | 11 |

The gate child sits at `(-42, -22)` below its pivot. This places exported pixel
`(84,44)` exactly on the documented mechanical pin. Presentation layers use
absolute Z values and do not inherit the parent Machines-node offset. The root
draws only the existing bottleneck and disabled feedback at Z=12.

## Conveyor occlusion and visual states

The modular conveyor and its one decorative parcel renderer are unchanged.
Parcels remain 42×30, travel on Y=688, and touch the belt at Y=703. The rear
housing is below parcels, while the narrow entrance/exit guards and lower rail
of the front mask are above them. Alpha checks confirm an open passage through
the centre and occlusion at both side guards; the lower rail starts below the
approved parcel contact height. The three lower bays remain static presentation
details and do not add production branches.

- **Enabled/active:** both indicator layers are visible and the gate oscillates
  through approximately ±16 degrees.
- **Line stopped:** the Sorter stays lit, while its gate process callback stops
  and the current gate angle freezes.
- **Disabled:** indicators turn off; housing, gate, front frame, and installed
  motor dim; the established stopped marker remains.
- **Bottleneck:** the established amber Z=12 outline remains simulation-driven.
- **Motor I:** `sorter_motor_1` ownership alone controls the separate motor
  layer. It remains installed and dimmed when the Sorter is disabled, including
  after state restoration or a newly instanced ArchiveRoom.

Header and bay indicator groups can be toggled independently. Gate time is
presentation-only and derives from the room's existing effective-throughput
state. It cannot create items, award Credits, or influence processing speed.

## Filtering and graphical validation

Linear filtering remains the runtime default, matching the Basic Scanner and
Receiving Desk. Nearest filtering at the fractional 1280×720 canvas transform
produces uneven cadence along diagonal casing edges, the gate, and small indicator
details. Linear filtering adds mild softness but gives more stable cross-machine
detail. Full HD is the primary art-review target; 960×540 is a supported
readability regression rather than a pixel-perfect target.

Actual Godot 4.7.2 Compatibility/OpenGL 3.3 captures were made in fullscreen at
1920×1080 and in windows at 1280×720 and 960×540 on an NVIDIA GeForce RTX 3060
Ti. The animation proof contains 24 actual Godot frames and advances the existing
conveyor presentation clock by 12 seconds, showing multiple complete parcel
passages through the Sorter together with the independently moving gate.

## Performance observations

The six decoded RGBA textures total 6,222,768 bytes (5.934 MiB) before GPU
alignment, render targets, driver formats, or other game assets. Static layers
have no process callbacks. The gate processes only while effective throughput is
positive and stops with the line or disabled machine.

A 120-frame Full-HD observation after 30 warm-up frames reported 68 draw calls,
1,836 primitives, and 62.09 MiB total process video memory. The observed wall
interval was 6.944 ms per presented frame, exactly consistent with 144 Hz frame
pacing; it is therefore not presented as isolated GPU render cost. The
Compatibility renderer exposed no reliable standalone GPU-time measurement in
this run.

## Godot render evidence

- [1920×1080 standard Sorter](screenshots/basic-sorter-art-1920x1080.png)
- [1280×720 standard Sorter](screenshots/basic-sorter-art-1280x720.png)
- [960×540 standard Sorter](screenshots/basic-sorter-art-960x540.png)
- [1280×720 installed Motor I](screenshots/basic-sorter-motor-i-1280x720.png)
- [1280×720 disabled Sorter](screenshots/basic-sorter-disabled-1280x720.png)
- [1280×720 installed Motor I while disabled](screenshots/basic-sorter-motor-i-disabled-1280x720.png)
- [1280×720 enabled Sorter with stopped line](screenshots/basic-sorter-line-stopped-1280x720.png)
- [1280×720 linear filter](screenshots/basic-sorter-filter-linear-1280x720.png)
- [1280×720 nearest filter](screenshots/basic-sorter-filter-nearest-1280x720.png)
- [960×540 gate and parcel animation](screenshots/basic-sorter-gate-parcels-960x540.gif)

## Comparison and review limits

The actual Full-HD Godot capture closely follows the supplied offline scene
proof in footprint, palette, layer alignment, and conveyor opening. Expected
differences are live runtime state: Godot starts at zero Credits, draws the
actual HUD display-mode control and amber bottleneck outline, and uses live
parcel positions and gate phase rather than the offline composite's fixed ones.

No supplied artwork was regenerated or modified. Fractional resolutions remain
mildly softened, Archive Intake remains an intentional greybox, and the three
inspection bays have no gameplay function. This integration is not a claim of
final artistic approval.

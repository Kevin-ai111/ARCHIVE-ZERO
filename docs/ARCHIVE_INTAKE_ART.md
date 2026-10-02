# Archive Intake art configuration

## Accepted runtime package

The Phase 4H integration uses the four runtime PNGs from
`ARCHIVE_ZERO_Phase4H_Archive_Intake_v1.1_PRODUCTION_REVIEW.zip`. The received
ZIP has SHA-256
`5166547c5f640d40a7484267863a47e99569508ee877bb92645c40590422bf53`.

The original package was independently checked before integration:

- all 21 entries in `SHA256_MANIFEST.txt` match their files;
- all four runtime images decode as RGBA with genuine `(0,255)` alpha ranges,
  exact manifest dimensions, and exact nearest-neighbour 2× grids;
- all four runtime layers match their documented crops in the genuine
  four-layer OpenRaster source;
- the package verifier passes 34/34 independent source, geometry, and contract
  checks;
- the v1.1 front mask has the required corrected hash.

Only these runtime PNGs were copied into `assets/machines/archive_intake/`.
Editable source, scripts, validation tooling, and offline previews remain
outside the game project.

| Runtime layer | Export size | SHA-256 |
| --- | ---: | --- |
| `AZ_INT_back_idle_2x.png` | 608×928 | `f846fa9e081c36d85895d0f199b742ed4252fcaf8bb154cdb09fa7d934433a21` |
| `AZ_INT_emissive_idle_2x.png` | 492×506 | `d924c9ff040bdd0c9c6a88fee2b7cec5c1ec13b35bf076e762e685ca2bf656d5` |
| `AZ_INT_lift_carrier_2x.png` | 142×206 | `4a7f6c1de85eec04bfc7626100a851251d323e620ba3638e3ea2af1be8ab5b97` |
| `AZ_INT_front_mask_2x.png` | 608×928 | `d6ccf5c3c325136c46f6c25f4fa6285c848e9ed720729953e7afc8b3220b097f` |

## Runtime assembly

`archive_intake_visual.tscn` replaces only the final Archive Intake greybox.
Its presentation adapter inherits the established machine state interface but
overrides procedural drawing, so no duplicate greybox body remains. The scene
is instanced at world pivot `(1668,920)` and preserves the 304×464 footprint,
world bounds X=1516..1820 / Y=456..920, parcel centre Y=688, parcel bottom and
belt contact Y=703, and conveyor endpoint X=1668.

| Layer | Local top-left / pivot | Scale | Absolute Z |
| --- | --- | --- | ---: |
| Rear housing | `(-152,-464)` | `(0.5,0.5)` | 5 |
| Idle emissive | `(-115,-413)` | `(0.5,0.5)` | 7 |
| Lift carrier pivot | `(74,-294)` | child `(-35,-54)`, `(0.5,0.5)` | 8 |
| Front mask | `(-152,-464)` | `(0.5,0.5)` | 10 |

All art layers use absolute Z and avoid the Machines parent offset. The one
existing decorative parcel renderer remains at Z6 between the rear housing and
front mask. No Intake-specific parcel, conveyor, upgrade, ownership field, or
save migration was added.

## Parcel terminal occlusion

The automated regression samples the decoded front-mask alpha through the real
Godot Sprite2D transform on a 0.25 logical-pixel grid. It verifies progressive
occlusion without an early disappearance and checks the current 42×30 parcel
rectangle at the locked centre positions:

| Centre X | Visible fraction | Visible samples |
| ---: | ---: | ---: |
| 1640 | 0.5524 | 11,136 |
| 1650 | 0.3143 | 6,336 |
| 1655 | 0.1976 | 3,984 |
| 1660 | 0.0952 | 1,920 |
| 1664 | 0.0183 | 368 |
| 1665 | 0.0000 | 0 |
| 1666 | 0.0000 | 0 |
| 1668 | 0.0000 | 0 |

The carrier's transformed alpha bounds remain 20 logical pixels to the right of
the terminal parcel rectangle at both ±24-pixel travel extremes.

## Animation and states

The carrier performs presentation-only sinusoidal vertical translation through
−24..+24 logical pixels. It processes only while effective throughput is
positive and the Intake is enabled. A stopped line or disabled Intake freezes
the existing phase; activity resumes from that phase without touching items,
Credits, fractional progress, throughput, or parcel positions.

- **Enabled/active:** housing is authored colour, emissive is visible, carrier
  translates.
- **Enabled/line stopped:** emissive remains powered and the carrier freezes.
- **Disabled:** emissive is hidden; housing, mask, and carrier dim; carrier
  remains frozen; the established disabled overlay remains.
- **Bottleneck:** the existing external amber Z12 outline is used.
- **Upgrade:** none. The catalogue remains exactly the existing Scanner and
  Sorter Motor I definitions.

Disabled state restores through the existing production save data and is
reflected by newly instanced ArchiveRoom scenes.

## Filtering decision

Actual Godot 1280×720 captures compared fully linear and fully nearest
filtering. Fully nearest rendering makes diagonal casing and cyan carrier details
visibly harsher than the completed machines. Fully linear rendering is visually
consistent, but the bilinear alpha edge leaves 94 residual samples at X=1665
(`0.0011` visible fraction, maximum residual alpha `0.25`), violating the locked
pre-wrap terminal occlusion.

The selected configuration therefore keeps the Intake root and its visible
rear, emissive, and carrier layers linear, while explicitly sampling only the
front occlusion mask with nearest filtering. This preserves the established
fractional-resolution appearance and produces exact zero terminal visibility
from X=1665 onward without changing texture pixels, geometry, or parcel timing.

## Godot render evidence

All evidence below is actual Godot 4.7.2 Compatibility/OpenGL 3.3 output on an
NVIDIA GeForce RTX 3060 Ti, not the package's offline composites.

- [1920×1080 active room](screenshots/archive-intake-art-1920x1080.png)
- [1280×720 active room](screenshots/archive-intake-art-1280x720.png)
- [960×540 active room](screenshots/archive-intake-art-960x540.png)
- [1280×720 line-stopped state](screenshots/archive-intake-line-stopped-1280x720.png)
- [1280×720 disabled Intake](screenshots/archive-intake-disabled-1280x720.png)
- [1280×720 all-linear comparison](screenshots/archive-intake-filter-linear-1280x720.png)
- [1280×720 all-nearest comparison](screenshots/archive-intake-filter-nearest-1280x720.png)
- [1280×720 selected mixed filtering](screenshots/archive-intake-filter-selected-1280x720.png)
- [121-frame parcel and carrier motion proof](screenshots/archive-intake-parcel-carrier-motion-1280x720.gif)

The motion proof covers 18 presentation seconds and more than six complete
parcel entries. Parcels progressively disappear before wrapping, while the
carrier traverses its loop independently. Two line-stopped Intake crops captured
three seconds apart are pixel-identical, confirming the visual freeze alongside
the state regression.

## Performance and limits

The four decoded RGBA textures total 5,626,608 bytes (5.366 MiB) before GPU
alignment, render targets, driver formats, or other game assets. An active
Full-HD capture reported 67 draw calls, 1,674 primitives, and 74,559,110 bytes
of total process video memory. The carrier owns a continuous process callback
only while active; it stops entirely with the line or disabled Intake. No claim
is made that display refresh pacing represents isolated GPU render time.

The 960×540 target remains readable but is naturally softer and denser than the
Full-HD art-review target. Archive Intake has no gameplay function beyond its
unchanged numerical stage. This integration is not a claim of final artistic
approval.

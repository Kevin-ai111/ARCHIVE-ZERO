# Basic Scanner art configuration

## Accepted runtime package

The first production-art integration uses the five runtime PNGs from
`ARCHIVE_ZERO_Basic_Scanner_Pilot_v1_COMPLETE_VERIFIED.zip` (package SHA-256
`DA35CCAB2CF43CEC730BACAA44E4986D6992553A8128C21ED6453FDDAD5F4BD5`). The
source files and proof images remain outside the game; only these runtime layers
are stored under `assets/machines/basic_scanner/`:

| Runtime layer | Purpose |
| --- | --- |
| `AZ_SCN_back_idle_2x.png` | Rear casing and interior behind parcels |
| `AZ_SCN_emissive_idle_2x.png` | Idle cyan lighting |
| `AZ_SCN_scan_beam_2x.png` | Vertically animated active scan line |
| `AZ_SCN_front_mask_2x.png` | Front frame that occludes parcels |
| `AZ_SCN_upgrade_motor_2x.png` | Independently controlled Motor I attachment |

All five files were independently decoded as 768×832 RGBA images with alpha.
They share the same canvas and bottom-centre pivot. Their exact nearest-neighbour
2× pixel grid also matches the supplied native 384×416 design.

## Runtime geometry

`basic_scanner_visual.tscn` places every layer at local `(0, -208)` with scale
`(0.5, 0.5)`. The scene root therefore remains the bottom-centre pivot and is
instanced at the approved world point `(708, 920)`. This keeps the displayed
scanner at 384×416 without changing the Archive Room geometry.

The presentation-only Z order is:

```text
conveyor surface (4)
scanner rear casing (5)
decorative parcels (6)
idle lighting (7) / scan beam (8)
scanner front frame (10)
Motor I attachment (11)
```

Parcels retain their centreline at Y=688, their 30-pixel height, and exact
contact at the visible conveyor surface Y=703. Their drawing is separated from
the belt drawing so they pass in front of the rear interior but behind the front
frame. Both renderers read the same decorative conveyor clock; neither advances
simulation or awards Credits.

## Visual states

- **Enabled/idle:** full casing and a low-intensity cyan emissive layer.
- **Active production:** the supplied scan beam oscillates 47 logical pixels
  above and below its authored centre while the idle lighting pulses subtly.
- **Disabled:** emissive and scan layers are hidden, the casing is dimmed, and a
  red stopped indicator is drawn.
- **Scanner Motor I:** the supplied motor layer follows upgrade ownership only
  and remains identifiable, dimmed, while the machine is disabled.
- **Bottleneck:** the established amber outline remains presentation feedback.

All state comes from `SimulationManager`; the visual animation is deliberately
one-way and cannot mutate production state.

## Texture filtering experiment

The final scanner scene uses Godot's linear texture filter. At the authored
1920×1080 logical canvas the 768×832 export is reduced exactly to its native
384×416 appearance. At physical 1280×720 and 960×540 the full logical canvas is
scaled by 2/3 and 1/2 respectively. A nearest-filter comparison at 1280×720
produced uneven pixel cadence on diagonals and fine highlights because 2/3 is a
fractional transform. Linear filtering introduces mild softness but preserves
the cinematic detail and stable silhouette more consistently, so it is the
safer runtime default.

The compromise is explicit: fractional window sizes cannot be simultaneously
pixel-perfect and geometrically faithful. Full HD is the primary art-review
target; 1280×720 and 960×540 remain supported readability targets rather than
pixel-perfect targets. No source texture was resampled or replaced.

## Render evidence

- [1920×1080 active scanner](screenshots/scanner-art-1920x1080.png)
- [1280×720 active scanner](screenshots/scanner-art-1280x720.png)
- [960×540 active scanner](screenshots/scanner-art-960x540.png)
- [1280×720 linear filter](screenshots/scanner-filter-linear-1280x720.png)
- [1280×720 nearest filter](screenshots/scanner-filter-nearest-1280x720.png)
- [1280×720 disabled scanner](screenshots/scanner-disabled-1280x720.png)
- [1280×720 Scanner Motor I](screenshots/scanner-motor-i-1280x720.png)
- [960×540 scan animation](screenshots/basic-scanner-scan-animation-960x540.gif)

These captures were rendered by Godot 4.7.2 stable with the Compatibility
renderer on an NVIDIA GeForce RTX 3060 Ti. The other three machines deliberately
remain greyboxes for this milestone.

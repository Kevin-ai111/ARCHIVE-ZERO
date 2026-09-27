# Archive Room environment and modular conveyor

## Package acceptance

The Phase 4E integration uses the 18 runtime PNGs from
`ARCHIVE_ZERO_Phase4E_Environment_Conveyor_v1_PRODUCTION_REVIEW (1).zip`.
The received ZIP has SHA-256
`9B6D5B69C50DB2A3D45B2B354536AECB35ED0BA4AB2AF39E4E379B6EEC4DBD9C`.

The package was independently checked before integration:

- all 36 files covered by `SHA256_MANIFEST.txt` match their recorded hashes;
- all 18 manifest runtime entries match their decoded PNG dimensions and modes;
- both editable OpenRaster sources are valid archives with the required
  `image/openraster` MIME type;
- all five conveyor exports retain an exact nearest-neighbour 2× grid;
- the 11-piece conveyor spans 1232 logical pixels without gaps or overlap;
- all five existing Basic Scanner PNGs remain byte-identical to the recorded
  reference hashes.

Only `runtime/` PNGs were copied into `assets/environment/`. Editable sources,
build scripts, verification files, and offline previews remain outside the game.
The five existing Scanner assets stay in their original directory.

## Environment scene

`archive_room_environment.tscn` is a presentation-only scene. It has no process
callback and uses shared texture resources for every repeated roof, wall,
catwalk, floor, pillar, lamp, and conveyor instance. The former ArchiveRoom
ColorRect artwork was removed so it cannot cover or duplicate the supplied art.

All authored layers use explicit absolute CanvasItem Z values:

| Layer | Z |
| --- | ---: |
| Distant archive | -100 |
| Rear wall | -82 |
| Back catwalk | -79 |
| Roof | -71 |
| Pillars | -70 |
| Ceiling cables | -69 |
| Pinboard / pipes | -65 / -64 |
| Light cones | -52 |
| Lamp housings | -51 |
| Wall sconces | -50 |
| Floor | -10 |
| Floor reflections | -9 |

Lamp housings and sconces, translucent cones, and floor reflections are three
independently toggleable groups. The current integration uses normal CanvasItem
alpha compositing. Additive blending was not introduced because it visibly
over-brightened the already authored amber effects in the package previews.

The camera, HUD CanvasLayer, machine pivots, machine dimensions, and all machine
scripts remain unchanged. Receiving Desk, Basic Sorter, and Archive Intake are
still intentional greyboxes pending their own art milestones.

## Modular conveyor

`modular_conveyor.tscn` replaces the procedural greybox drawing with the supplied
art at the locked world coordinates:

```text
left cap:       X 436..476       (40 px)
9 straights:   X 476..1628      (9 × 128 px)
right cap:     X 1628..1668     (40 px)
surface:       Y 703
parcel centre: Y 688
supports:      Y 770..920
```

All 2× modules share a `(0.5, 0.5)` top-left transform. Eight support instances
reuse one texture. Decorative parcels remain a separate absolute-Z renderer at
Z=6, between the Scanner rear casing (Z=5) and front frame (Z=10).

The 64×44 logical slat tile is clipped to X=476..1628 and Y=716..760. Its offset
is derived from the existing conveyor `_visual_time`; no gameplay clock or
production value was added. Disabling the production line freezes the offset and
disables the conveyor process callback. The slat renderer redraws only when its
offset changes, and parcels are now invalidated by the conveyor's presentation
signal rather than their own continuous process callback.

## Rendering and performance observations

The room was rendered with Godot 4.7.2 stable, Compatibility/OpenGL 3.3, on an
NVIDIA GeForce RTX 3060 Ti. A 120-frame Full-HD observation after warm-up measured
833.26 ms wall time, or 6.944 ms/frame, with 68 reported draw calls per frame.
This is an indicative development-machine measurement, not a platform budget or
shipping performance guarantee.

The 18 unique package textures decode to 6,985,816 bytes (6.662 MiB) before GPU
alignment, driver formats, framebuffers, or other game assets. Godot reported
69.37 MiB total video memory during the observation, which includes the engine,
viewport, Scanner, HUD, and render targets and therefore is not a package-only
residency figure. Repeated Sprite2D instances reuse the same Texture2D resources.

Expected continuous presentation work is limited to the active Scanner scan and
the running conveyor/parcel visuals. The static environment has no continuous
redraw. A stopped conveyor disables its process callback and leaves the slat and
parcel images frozen.

## Godot render evidence

- [1920×1080 gameplay room](screenshots/environment-art-1920x1080.png)
- [1280×720 gameplay room](screenshots/environment-art-1280x720.png)
- [960×540 gameplay room](screenshots/environment-art-960x540.png)
- [1920×1080 environment-only render](screenshots/environment-only-1920x1080.png)
- [1280×720 Scanner Motor I](screenshots/environment-scanner-motor-i-1280x720.png)
- [1280×720 disabled Scanner](screenshots/environment-scanner-disabled-1280x720.png)
- [960×540 conveyor and scan motion](screenshots/environment-conveyor-motion-960x540.gif)

## Comparison and review limits

The environment-only Godot render was compared with the supplied offline
1920×1080 room preview. Above the conveyor, mean absolute RGB differences were
`0.037`, `0.023`, and `0.024` levels per channel. The main visible difference is
the conveyor strip: Godot shows the implemented moving slat phase while the
offline preview is a fixed composite. Gameplay captures also use live Godot HUD
fonts, zero starting Credits, live bottleneck outlines, and actual machine nodes
rather than the preview's diagnostic approximations.

The result reproduces the supplied production package closely, but it is not a
claim of final artistic approval. Compared with the broader approved cinematic
concept, the delivered room uses visibly repeated structural tiles, restrained
2D alpha lighting rather than dynamic illumination, no volumetric fog, and three
remaining greybox machines. Pixel texture density softens at 1280×720 and
960×540 because the Full-HD canvas uses fractional scaling. Creative Director
review remains required before these visuals are considered final.

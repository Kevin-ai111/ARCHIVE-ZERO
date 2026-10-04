# Production and Upgrade Validation

## Automated validation

Use the official Godot 4.7.2 stable binary. From a fresh checkout, run exactly:

```bash
godot --version
godot --headless --editor --path . --quit
godot --headless --path . tests/case_foundation_test.tscn
godot --headless --path . tests/manual_case_processing_test.tscn
godot --headless --path . tests/production_pipeline_test.tscn
godot --headless --path . tests/visual_foundation_test.tscn
godot --headless --path . --quit-after 120
```

The version must report Godot 4.7.2 stable. Every command must exit with code `0`,
and the test scenes must print `Production pipeline tests passed.` and
`Visual foundation tests passed for 1920x1080, 1280x720, and 960x540.`

Case foundation prints 477 passing checks; manual Case integration prints 520.
Run `tests/manual_case_processing_visual_test.tscn` separately for interactive
developer QA (empty startup, explicit CASE_0001/CASE_0010 and Reopen buttons).
Runtime proofs, input coverage and limitations are in
[`MANUAL_CASE_PROCESSING_UI.md`](MANUAL_CASE_PROCESSING_UI.md).

The suite covers:

- starting capacities, throughput, utilization, and bottleneck;
- fixed rewards, disabled stages, and fractional continuity;
- both data-driven upgrade definitions;
- affordability, exact deductions, invalid IDs, and duplicate rejection;
- Sorter → Scanner progression and deterministic tie handling;
- rejection of free overrides for upgrade-managed machines;
- separation of runtime and upgrade multipliers;
- save-v3 round trips with enabled state, fractions, ownership, and unrelated modifiers;
- malformed and duplicated ownership rejection before live-state mutation;
- version 1, version 2 line, and version 2 Scanner-only migrations;
- exact legacy Sorter ×2 mapping without multiplier duplication.

The visual foundation suite covers:

- 1920×1080 logical canvas, `canvas_items`, keep-aspect, and fractional scaling;
- approved machine pivots, dimensions, Y=688 item path, and Y=920 baseline;
- fixed camera and complete room-layer structure;
- HUD values, two-upgrade shop, scroll policy, and physical readability floors;
- 1920×1080, 1280×720, and 960×540 scale factors;
- Scanner enabled, disabled, active, and Scanner Motor I states;
- Scanner layer dimensions, bottom-centre alignment, and world pivot;
- real front-mask transparency and rear-casing visibility through the opening;
- conveyor surface → rear casing → parcel → front-frame occlusion order;
- scan-line travel and independent Motor I visibility;
- Receiving Desk five-layer sizes, manifest offsets, 0.5 scale, and absolute Z;
- Receiving Desk enabled, disabled, active, line-stopped, and bottleneck states;
- independent idle lighting and feed-wheel rotation around `(116, -173)`;
- real front-mask alpha transition at the X=436 conveyor outlet;
- one shared parcel renderer through the Receiving Desk hand-off;
- Basic Sorter six-layer sizes, cropped offsets, 0.5 scale, and absolute Z;
- exact Sorter world pivot, 480×360 footprint, and gate pivot `(18, -266)`;
- Sorter front-mask entrance/interior/exit alpha and lower-rail clearance;
- actual-transform gate/parcel alpha clearance at −16°, 0°, +16°, and 13
  coupled animation phases, including bilinear-filter edge support;
- active gate motion, line-stopped freeze, restart, and disabled freeze;
- independent header/bay indicators and simulation-driven bottleneck feedback;
- Sorter Motor I hidden, installed, disabled-installed, save-restored, and
  newly-instanced scene states;
- Archive Intake four-layer sizes, manifest offsets, 0.5 scale, and absolute Z;
- exact Intake pivot `(1668,920)`, 304×464 footprint, and carrier pivot
  `(74,-294)` with child offset `(-35,-54)`;
- real transformed front-mask alpha at X=1640, 1650, 1655, 1660, 1664, 1665,
  1666, and 1668, including zero parcel visibility before wrap;
- Intake carrier ±24-pixel travel, active processing, stopped/disabled freeze,
  phase resume, dimming, independent emissive, and state restoration;
- Intake bottleneck feedback, absence of an Intake upgrade, and carrier/parcel
  geometric clearance;
- gameplay-HUD purchase wiring;
- decorative conveyor movement without production-state mutation;
- retained Phase 4E architecture and all nineteen Phase 4I environment texture placements;
- 41 static polish instances, exact source hashes, scale, Z, and mipmap policy;
- all 25 locked machine/conveyor asset hashes;
- four-light replacement, optional legacy sconces, and ground/foreground bounds;
- static environment controls preserving fractional and pending simulation time;
- foreground rail separation from machine/parcel bounds and HUD CanvasLayer ordering;
- independent lamp-housing, light-cone, and floor-reflection visibility;
- 40 + 9×128 + 40 modular conveyor assembly without gaps;
- slat clipping, movement, stopped-state freeze, and redraw policy;
- removal of the obsolete ArchiveRoom ColorRect artwork;
- exact 100-second simulation equivalence with and without ArchiveRoom.

The test temporarily uses `user://archive_zero_save.json`. It backs up and
restores an existing file when the process completes normally. A forcibly
terminated process cannot guarantee cleanup.

Pull requests run the import and automated test commands through
`.github/workflows/godot-headless-validation.yml`. The workflow uses the pinned
official Godot 4.7 stable Linux binary.

## Full-HD graphical validation

### Phase 4I unified environment polish

Actual Godot 4.7.2 Compatibility captures:

- [1920×1080 room and HUD](screenshots/archive-room-polish-1920x1080.png)
- [1280×720 room and HUD](screenshots/archive-room-polish-1280x720.png)
- [960×540 room and HUD](screenshots/archive-room-polish-960x540.png)
- [environment-only room](screenshots/archive-room-polish-environment-only-1920x1080.png)
- [960×540 upgrade shop](screenshots/archive-room-polish-upgrade-shop-960x540.png)
- [nearest comparison](screenshots/archive-room-polish-nearest-1280x720.png)
- [filter detail comparison](screenshots/archive-room-polish-filter-detail-1280x720.png)
- [121-frame parcel passage proof](screenshots/archive-room-polish-parcel-passages-1280x720.gif)

The package hashes, geometry, old-lighting replacement, optional sconce policy,
actual filtering review, offline-reference comparison, memory/draw monitors,
and reproducible graphical commands are documented in
[ARCHIVE_ROOM_POLISH.md](ARCHIVE_ROOM_POLISH.md). The final Phase 4I smoke test
uses `--quit-after 120`; the existing CI workflow also runs its smoke step.
Final artistic approval remains pending.

### Phase 4H Archive Intake production art

Actual Godot 4.7.2 Compatibility-renderer evidence:

- [1920×1080 active room](screenshots/archive-intake-art-1920x1080.png)
- [1280×720 active room](screenshots/archive-intake-art-1280x720.png)
- [960×540 active room](screenshots/archive-intake-art-960x540.png)
- [line-stopped Intake](screenshots/archive-intake-line-stopped-1280x720.png)
- [disabled Intake](screenshots/archive-intake-disabled-1280x720.png)
- [121-frame parcel/carrier proof](screenshots/archive-intake-parcel-carrier-motion-1280x720.gif)

The motion proof spans 18 seconds and more than six parcel entries. It confirms
progressive occlusion, complete visual hiding before the X=1668 presentation
wrap, and independent carrier movement. Line-stopped frames three seconds apart
are pixel-identical. Direct 1280×720 [linear](screenshots/archive-intake-filter-linear-1280x720.png),
[nearest](screenshots/archive-intake-filter-nearest-1280x720.png), and
[selected mixed](screenshots/archive-intake-filter-selected-1280x720.png)
captures support the documented filter choice: visible art stays linear while
the front mask alone uses nearest sampling to guarantee zero residual parcel
alpha from X=1665 onward.

Package verification, exact visibility fractions, animation-state results,
memory accounting, and review limits are recorded in
`docs/ARCHIVE_INTAKE_ART.md`. Final artistic approval remains pending.

### Phase 4G Basic Sorter production art

Actual Godot 4.7.2 Compatibility-renderer evidence:

- [v1.1 Full-HD gate-clearance room](screenshots/basic-sorter-gate-v11-1920x1080.png)
- [v1.1 1280×720 gate-clearance room](screenshots/basic-sorter-gate-v11-1280x720.png)
- [v1.1 Full-HD 41-frame passage proof](screenshots/basic-sorter-gate-passages-v11-1920x1080.gif)
- [v1.1 1280×720 41-frame passage proof](screenshots/basic-sorter-gate-passages-v11-1280x720.gif)

- [1920×1080 standard Sorter](screenshots/basic-sorter-art-1920x1080.png)
- [1280×720 standard Sorter](screenshots/basic-sorter-art-1280x720.png)
- [960×540 standard Sorter](screenshots/basic-sorter-art-960x540.png)
- [installed Sorter Motor I](screenshots/basic-sorter-motor-i-1280x720.png)
- [disabled Sorter](screenshots/basic-sorter-disabled-1280x720.png)
- [installed Motor I while disabled](screenshots/basic-sorter-motor-i-disabled-1280x720.png)
- [enabled Sorter with stopped line](screenshots/basic-sorter-line-stopped-1280x720.png)
- [moving gate and multiple parcel passages](screenshots/basic-sorter-gate-parcels-960x540.gif)

The captures confirm unchanged machine bounds and camera framing, correct parcel
contact and front-mask occlusion, gate freeze/resume behavior, installed Motor I
state, and readable HUD presentation at every target. Linear filtering was
retained after direct [linear](screenshots/basic-sorter-filter-linear-1280x720.png)
and [nearest](screenshots/basic-sorter-filter-nearest-1280x720.png) comparison at
1280×720. Package verification, state restoration, performance observations,
and remaining artistic limitations are recorded in `docs/BASIC_SORTER_ART.md`.

The v1.1 blocker proof adds 41 live frames over 12 seconds at each requested
resolution. Five parcel passages remain visibly clear of the gate with no
intersection or pop. The automated alpha regression reports zero overlap at
all fixed angles and coupled phases; running the same test with the replaced
v1.0 asset produces non-zero overlap in every fixed-angle case.

This milestone remains pending final artistic approval.

### Phase 4F Receiving Desk production art

Actual Godot 4.7.2 Compatibility-renderer evidence:

- [1920×1080 active room](screenshots/receiving-desk-art-1920x1080.png)
- [1280×720 active room](screenshots/receiving-desk-art-1280x720.png)
- [960×540 active room](screenshots/receiving-desk-art-960x540.png)
- [disabled Receiving Desk](screenshots/receiving-desk-disabled-1280x720.png)
- [Receiving Desk bottleneck](screenshots/receiving-desk-bottleneck-1280x720.png)
- [feed-wheel and conveyor motion](screenshots/receiving-desk-wheel-motion-960x540.gif)

The captures confirm unchanged machine bounds and camera framing, a readable
HUD at every target, correct X=436 parcel hand-off, Y=703 belt contact, front
guard occlusion, independent idle lighting, stopped/disabled feedback, and a
centered rotating feed wheel. Linear filtering was retained after direct
[linear](screenshots/receiving-desk-filter-linear-1280x720.png) and
[nearest](screenshots/receiving-desk-filter-nearest-1280x720.png) comparison at
1280×720. Package verification, performance observations, and unresolved review
limits are recorded in `docs/RECEIVING_DESK_ART.md`.

This milestone remains pending final artistic approval.

### Phase 4E environment and modular conveyor

Actual Godot 4.7.2 Compatibility-renderer evidence:

- [1920×1080 gameplay room](screenshots/environment-art-1920x1080.png)
- [1280×720 gameplay room](screenshots/environment-art-1280x720.png)
- [960×540 gameplay room](screenshots/environment-art-960x540.png)
- [environment-only Full-HD render](screenshots/environment-only-1920x1080.png)
- [Scanner Motor I](screenshots/environment-scanner-motor-i-1280x720.png)
- [disabled Scanner](screenshots/environment-scanner-disabled-1280x720.png)
- [conveyor and scan motion](screenshots/environment-conveyor-motion-960x540.gif)

The renders confirm unchanged machine footprints, Y=920 floor alignment, an
unbroken X=436..1668 belt, parcel contact at Y=703, preserved Scanner occlusion,
and readable HUD controls at every target. See
`docs/ARCHIVE_ROOM_ENVIRONMENT.md` for package verification, exact placement,
performance observations, offline-preview comparison, and artistic limitations.

This milestone remains pending artistic approval.

### Basic Scanner production art

The production-art Scanner was rendered with Godot 4.7.2 stable and the
Compatibility renderer at all required physical targets:

- [1920×1080 active scanner](screenshots/scanner-art-1920x1080.png)
- [1280×720 active scanner](screenshots/scanner-art-1280x720.png)
- [960×540 active scanner](screenshots/scanner-art-960x540.png)
- [disabled state](screenshots/scanner-disabled-1280x720.png)
- [Scanner Motor I state](screenshots/scanner-motor-i-1280x720.png)
- [active scan animation](screenshots/basic-scanner-scan-animation-960x540.gif)

The captures confirm that packages rest on the Y=703 conveyor surface, cross the
Y=688 centreline through the scanner opening, remain visible over the rear
casing, and are hidden by the front frame where appropriate. Machine pivots,
the HUD, and the other three machines are unchanged.

Linear filtering was retained after comparison with
[nearest filtering at 1280×720](screenshots/scanner-filter-nearest-1280x720.png).
The corresponding [linear capture](screenshots/scanner-filter-linear-1280x720.png)
avoids uneven fractional pixel cadence at the supported 2/3 output scale. See
`docs/BASIC_SCANNER_ART.md` for the exact configuration and compromise.

### Foundation greybox

The original greybox was rendered with the official Godot 4.7.2 stable Windows build and
the Compatibility renderer at all three physical targets:

- [1920×1080 Archive Room](screenshots/archive-room-1920x1080.png)
- [1280×720 Archive Room](screenshots/archive-room-1280x720.png)
- [960×540 Archive Room](screenshots/archive-room-960x540.png)
- [960×540 upgrade shop](screenshots/upgrade-shop-960x540.png)
- [960×540 debug dashboard](screenshots/debug-dashboard-960x540.png)

At 960×540, the minimum intended HUD/shop text resolves to 12 physical pixels,
primary actions remain at least 120×32 pixels, all four machines remain visible,
and the upgrade shop fits without horizontal clipping. The development dashboard
uses Full-HD-sized type and controls so its content stays readable at half scale;
its existing vertical `ScrollContainer` retains wheel access to the lower controls.

Manual window check:

1. Start in the default resizable 1280×720 window.
2. Click **Fullscreen** and confirm the 16:9 scene remains centered without
   horizontal camera movement.
3. Click **Windowed** and confirm the window returns to 1280×720.
4. Resize through 1920×1080, 1280×720, and 960×540. Confirm the HUD, machines,
   conveyor, and bottom actions remain visible.
5. Open **Machine Upgrades**, use the mouse wheel if content overflows, and buy
   each upgrade with sufficient Credits.
6. Open **Debug Dashboard**, scroll to the transaction, Save/Load, and status
   controls, then return to the Archive Room.

## Manual gameplay check

1. Run the project and confirm the initial line reports `0.75 items/sec`,
   `1.50 Credits/sec`, and Basic Sorter as bottleneck.
2. Confirm stage capacities are `1.25`, `1.00`, `0.75`, and `2.00` items/sec.
3. Confirm the shop lists exactly Sorter Motor I and Scanner Motor I with their
   descriptions, prices, ownership state, and purchase buttons.
4. With fewer than 25 Credits, try Sorter Motor I. The purchase must fail with
   meaningful feedback and no Credit or ownership change.
5. Reach 25 Credits and buy Sorter Motor I. Credits decrease by exactly 25,
   Sorter capacity becomes `1.50/s`, throughput becomes `1.00/s`, and Basic
   Scanner becomes the bottleneck.
6. Reach 50 Credits and buy Scanner Motor I. Credits decrease by exactly 50,
   Scanner capacity becomes `1.25/s`, throughput becomes `1.25/s`, and Receiving
   Desk is reported for the Receiving/Scanner tie.
7. Confirm owned upgrades list both motors and owned purchase buttons are disabled.
8. Disable Basic Scanner. Throughput and Credit rate must become zero; enable it
   again and confirm production resumes.
9. Save with both upgrades, a disabled stage, and fractional progress. Change the
   state, load, and confirm ownership, capacities, enabled state, and fraction return.
10. Confirm the former free Sorter x1/x2 buttons are absent from player flow.

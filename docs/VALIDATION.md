# Production and Upgrade Validation

## Automated validation

Use the official Godot 4.7 stable binary. From a fresh checkout, run exactly:

```bash
godot --version
godot --headless --editor --path . --quit
godot --headless --path . tests/production_pipeline_test.tscn
godot --headless --path . tests/visual_foundation_test.tscn
godot --headless --path . --quit-after 2
```

The version must report Godot 4.7 stable. Every command must exit with code `0`,
and the test scenes must print `Production pipeline tests passed.` and
`Visual foundation tests passed for 1920x1080, 1280x720, and 960x540.`

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
- gameplay-HUD purchase wiring;
- decorative conveyor movement without production-state mutation;
- exact 100-second simulation equivalence with and without ArchiveRoom.

The test temporarily uses `user://archive_zero_save.json`. It backs up and
restores an existing file when the process completes normally. A forcibly
terminated process cannot guarantee cleanup.

Pull requests run the import and automated test commands through
`.github/workflows/godot-headless-validation.yml`. The workflow uses the pinned
official Godot 4.7 stable Linux binary.

## Full-HD graphical validation

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

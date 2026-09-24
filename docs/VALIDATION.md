# Production and Upgrade Validation

## Automated validation

Use the official Godot 4.7 stable binary. From a fresh checkout, run exactly:

```bash
godot --version
godot --headless --editor --path . --quit
godot --headless --path . tests/production_pipeline_test.tscn
godot --headless --path . --quit-after 2
```

The version must report Godot 4.7 stable. Every command must exit with code `0`,
and the test scene must print `Production pipeline tests passed.`

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

The test temporarily uses `user://archive_zero_save.json`. It backs up and
restores an existing file when the process completes normally. A forcibly
terminated process cannot guarantee cleanup.

Pull requests run the import and automated test commands through
`.github/workflows/godot-headless-validation.yml`. The workflow uses the pinned
official Godot 4.7 stable Linux binary.

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

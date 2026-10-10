# First Shift

PR #18 turns the existing Case, commissioning, machine and production domains
into the first playable opening shift. It adds orchestration and a small HUD
action surface; it does not add art or a second simulation path.

## Player progression

```text
MANUAL_CASES   CASE_0001..0006   player Inspect + Classify + Archive
SCANNER_READY  commission Scanner for 16 C
SCANNER_CASES  0007, 0008, 0009, 0011   automatic Inspect
SORTER_READY   commission Sorter for 18 C
SORTER_CASES   0012..0015   automatic Inspect + correct Classify
INTAKE_READY   commission Archive Intake for 20 C
COMPLETE       all four runtimes enabled; aggregate line begins at 0.75/s
```

The exact fresh queue is `0001, 0002, 0003, 0004, 0005, 0006, 0007, 0008,
0009, 0011, 0012, 0013, 0014, 0015`. `CASE_0010` remains the unchanged Black
Hotel Keycard in the catalog and is deliberately neither queued nor rewarded.

`FirstShiftManager` is an event-driven Autoload with no `_process` loop. It owns
only phase, the three costs, phase Case groups, one-time reward claims and the
upgrade-unlock gate. Case lifecycle remains in `CaseManager`; ordered machine
commissioning remains in `CommissioningManager`; machine flags and throughput
remain in `SimulationManager → ProductionLine → MachineRuntime`.

Scanner/Sorter assistance calls the normal CaseManager transitions after its
current notification batch completes. This preserves CaseManager's reentrant
mutation protection. Archive remains an explicit player action in every phase.

## Economy and authority

An archived First Shift Case grants 4 Credits plus 1 for a correct final
classification through `Economy`/`GameState`. It never calls
`SimulationManager.process_manual_items()`. Claimed Case IDs are persisted, so
restore notifications or a duplicate archive observation cannot pay twice.

Worst case: `6×4 - 16 + 4×4 - 18 + 4×5 - 20 = 6 Credits`.
Perfect manual/scanner classification: `14×5 - 16 - 18 - 20 = 16 Credits`.
Therefore valid classification mistakes cannot softlock commissioning.

Receiving starts enabled; Scanner, Sorter and Intake start disabled. Because
every production stage is required, aggregate throughput remains authoritative
zero in Manual, Scanner and Sorter stages. Blocked simulation consumes elapsed
time without accumulating a fraction. Intake commissioning enables the last
stage and the existing line naturally reports 0.75 items/s and 1.5 Credits/s.

Normal Motor upgrades return `FIRST_SHIFT_LOCKED` until `COMPLETE`; the shop
mirrors that result with `AVAILABLE AFTER LINE COMMISSIONING`. The guard is in
`SimulationManager.purchase_upgrade()`, not only in presentation.

## Fresh start and saving

Only the configured main ArchiveRoom calls the idempotent fresh-game bootstrap.
It creates the exact queue once, restores zero economy/default production,
selects `MANUAL_SHIFT`, and applies the runtime flags above. Test-instantiated
rooms remain explicitly controlled.

Global Save v4 composes, without duplicating ownership:

- primitive GameState fields;
- Production save v3 under `production_line`;
- unchanged Case save v1 under `case_save`;
- unchanged Commissioning save v1 under `commissioning_save`;
- First Shift save v1 under `first_shift` (`phase`, ordered claimed Case IDs,
  and `completed`).

Restore installs First Shift reward claims before Case progress publishes, so
archived records are idempotent. Global v1, both supported v2 forms, and v3
migrate to First Shift `COMPLETE`, preserving economy and production. Valid
legacy Case/Commissioning payloads are retained; absent payloads receive their
existing compatibility defaults.

## Runtime evidence and performance

All images below are real Godot 4.7.2 Compatibility viewport captures:

- [Full-HD fresh shift](screenshots/first-shift/1920x1080/a-fresh-manual.png)
- [Full-HD manual CASE_0001](screenshots/first-shift/1920x1080/b-case-0001-manual.png)
- [Full-HD Scanner gate](screenshots/first-shift/1920x1080/c-scanner-ready.png)
- [Full-HD Scanner-assisted CASE_0007](screenshots/first-shift/1920x1080/d-scanner-case-0007-inspected.png)
- [Full-HD Sorter gate](screenshots/first-shift/1920x1080/e-sorter-ready.png)
- [Full-HD Sorter-classified CASE_0012](screenshots/first-shift/1920x1080/f-sorter-case-0012-classified.png)
- [Full-HD Intake gate](screenshots/first-shift/1920x1080/g-intake-ready.png)
- [Full-HD completed line](screenshots/first-shift/1920x1080/h-full-line-online.png)
- [1280×720 proof set](screenshots/first-shift/1280x720/)
- [960×540 proof set](screenshots/first-shift/960x540/)

The capture fixture reports 323 nodes. Closed-Case states use 66–86 draw calls;
the unchanged open Case Panel raises this to 113–124. The progression manager
adds no polling, textures, art nodes or runtime-generated images. Metadata for
each resolution records the renderer, adapter, physical/logical sizes, action
text, authoritative phase/stage, throughput, items, draw calls and texture
memory.

## Validation

`tests/first_shift_test.tscn` performs 340 checks covering the exact queue and
gates, both economy paths, automation, reward idempotency, authority isolation,
all commissioning failures, save checkpoints, every legacy migration, the
upgrade guard, dormant/disabled semantics, the 300-second no-backlog case and
the 100-second Full-Line invariant, plus strict/atomic First Shift v1 payload validation.

`tests/first_shift_visual_test.tscn` is an opt-in graphical evidence driver. It
uses public gameplay APIs and captures ArchiveRoom; it is not part of runtime.

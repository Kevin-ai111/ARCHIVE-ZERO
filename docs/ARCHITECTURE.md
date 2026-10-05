# ARCHIVE ZERO Architecture

## Foundation

ARCHIVE ZERO separates authoritative numerical simulation from presentation.
Six session-wide services are Autoloads:

1. `GameState` owns session totals.
2. `Economy` validates currency transactions.
3. `SimulationManager` advances time, owns purchased upgrade IDs, and commits output.
4. `SaveManager` persists and restores supported state.
5. `CaseManager` owns concrete-case queue and progress, independently of output,
   Credits and the live save file. It starts empty and does not advance time.
6. `CommissioningManager` owns only the ordered commissioning stage. It starts
   fully commissioned, never writes production or cases, and has an independent
   save-v1 contract not integrated into live SaveManager v3.

Machine definitions, installed machines, upgrade definitions, and production
lines are domain objects rather than Nodes or additional Autoloads.

## Concrete case domain

`ArchiveItemDefinition`, `CaseCategoryDefinition` and `CaseDefinition` are
validated authored Resources in `data/cases/`. `CaseCatalog` owns detached
definition copies. `CaseProgress` carries only mutable case ID/state/selection;
CaseManager alone advances `QUEUED → ACTIVE → INSPECTED → CLASSIFIED → ARCHIVED`.
Wrong but known classifications are representable and separately evaluable.

A concrete case is not an aggregate ProductionLine item. CaseManager never
calls `SimulationManager.process_manual_items()` or changes production, machine
state, upgrades or money. Its independent case-save v1 contract is not integrated
into global SaveManager v3. Startup enqueues nothing. See `docs/CASE_SYSTEM.md`
for APIs, signal semantics, strict atomic restore, authored cases and the later
First Shift/live-save migration boundary.

The Manual Case Panel is a native-Control CanvasLayer that only reads definitions
and progress and forwards input to CaseManager. Its item texture mapping lives
in presentation, not definitions or authority. Immutable inspection data is not
saved as runtime progress. The main scene starts with an empty, hidden panel;
explicit developer fixtures are separate. See `docs/MANUAL_CASE_PROCESSING_UI.md`.

## Presentation boundary

ArchiveRoom composes CommissioningManager stage with existing runtime production
on every visual refresh. Installed-but-dormant machines are distinct from actual
runtime-disabled/fault machines. The complete 29-element environment matrix is
applied only on stage changes, using cached named NodePaths; there is no new
per-frame controller or JSON parsing. The single continuous conveyor clock is
presentation-gated, never production-gated. See `docs/PROGRESSIVE_ROOM_STATES.md`
for the exact contract and later First Shift boundary.

`scenes/world/archive_room.tscn` is the first player-facing presentation scene.
Its fixed `Camera2D`, machine visuals, conveyor, HUD, foreground, and effects
layer only read authoritative state from the Autoloads. Decorative conveyor
items are derived from presentation time and throughput; they never call
production, Economy, or Credit APIs.

The Basic Scanner is the first layered production-art machine. Its rear casing,
lighting, scan beam, front mask, and Motor I attachment share one bottom-centre
pivot. Conveyor surface and parcel rendering are separate presentation nodes so
parcels can pass between the rear casing and front mask without becoming part of
the production model. The exact asset and Z-order contract is documented in
`docs/BASIC_SCANNER_ART.md`.

The Receiving Desk is a separate five-layer presentation adapter at the
existing `(268, 920)` pivot. Its rear casing, paperwork, idle light, centered
feed-wheel pivot, and front outlet mask use absolute Z ordering around the one
shared decorative parcel renderer. The adapter preserves the generic machine
state API while suppressing only its own greybox drawing. Exact configuration
and evidence are documented in `docs/RECEIVING_DESK_ART.md`.

The Basic Sorter is a six-layer presentation adapter at the existing
`(1204, 920)` pivot. Its independent indicator groups, gate pivot, front mask,
and existing Motor I ownership layer surround the shared parcel renderer with
absolute Z ordering. Gate activity reads the already calculated effective
throughput and is never authoritative production state. The exact layer,
occlusion, animation, and filtering contract is documented in
`docs/BASIC_SORTER_ART.md`.

The Archive Intake completes the current four-machine visual line with a
four-layer presentation adapter at `(1668,920)`. Its translated lift carrier is
presentation-only, while the corrected front mask progressively hides the one
shared parcel before the existing conveyor clock wraps. The selected filtering,
terminal alpha contract, animation states, and evidence are documented in
`docs/ARCHIVE_INTAKE_ART.md`.

The static Phase 4E room is isolated in
`scenes/world/archive_room_environment.tscn`. Repeated architectural Sprite2Ds
share Texture2D resources and use explicit absolute Z layers. Lamp housings,
light cones, and floor reflections remain separate presentation groups. The
modular conveyor preserves the existing presentation clock and public geometry
API while delegating clipped slat drawing to a child CanvasItem. Parcels redraw
from a presentation signal and remain independent of the belt and numerical
simulation. The complete placement and performance record is in
`docs/ARCHIVE_ROOM_ENVIRONMENT.md`.

Phase 4I extends that same environment boundary with nineteen shared textures,
absolute-Z midground, four worklights, signage, floor grounding, and sparse
lower rails. It replaces the distant background and old three-light stack
while retaining the base architecture and all machine/conveyor contracts.
Environment nodes have no processing callbacks. The existing CanvasLayer HUD
stays above the world foreground. Exact provenance, immutable asset hashes,
filtering, captures, and performance are in `docs/ARCHIVE_ROOM_POLISH.md`.

`scenes/ui/gameplay_hud.tscn` exposes Credits, throughput, the current
bottleneck, fullscreen/windowed switching, and the two existing upgrades. The
development dashboard remains a separate scene at
`scenes/debug/debug_dashboard.tscn` and can be opened from the gameplay HUD.

The presentation contract is regression-tested by comparing the exact result
of a 100-second simulation with ArchiveRoom absent and present.

## Production domain

### MachineDefinition and MachineRuntime

`MachineDefinition` is a Godot `Resource` containing static machine data. The
definitions in `data/machines/` provide stable IDs, display metadata, base
processing rates, and purchase costs.

`MachineRuntime` represents one installed stage. It owns enabled state and two
separate multiplier channels:

```text
configured capacity = base rate × runtime multiplier × upgrade multiplier
```

- The runtime multiplier represents unrelated temporary, migrated, or future
  effects. It is serialized.
- The upgrade multiplier is derived from authoritative upgrade ownership. It is
  never serialized as independent state.

This separation prevents an upgrade from being applied twice while still
allowing unrelated runtime modifiers to survive save/load.

### ProductionLine

The initial line is ordered:

```text
Receiving Desk → Basic Scanner → Basic Sorter → Archive Intake
```

Its starting capacities are `1.25`, `1.00`, `0.75`, and `2.00` items per
second. Every stage is required; disabling any stage stops the line. Throughput
is the minimum effective capacity.

Bottleneck ties are deterministic: `get_bottleneck()` scans the ordered stages
and returns the first stage whose capacity equals the calculated minimum. After
both initial motor upgrades, Receiving Desk and Basic Scanner are tied at
`1.25/s`, so Receiving Desk is reported.

`ProductionLine.simulate_elapsed()` keeps one fractional accumulator. Only
complete items are returned, so large and small time steps preserve equivalent
output without spawning item Nodes.

## Generic upgrades

`UpgradeDefinition` is a data Resource with:

- stable ID;
- display name and description;
- target machine ID;
- Credit cost;
- capacity multiplier.

`UpgradeCatalog` loads the definitions from `data/upgrades/`. The current shop
contains exactly:

| ID | Upgrade | Target | Cost | Multiplier |
| --- | --- | --- | ---: | ---: |
| `sorter_motor_1` | Sorter Motor I | `basic_sorter` | 25 | ×2.00 |
| `scanner_motor_1` | Scanner Motor I | `basic_scanner` | 50 | ×1.25 |

`SimulationManager` is the only owner of purchased IDs. The purchase sequence is:

1. resolve and validate the requested definition;
2. reject duplicate ownership or a missing target machine;
3. check affordability through `Economy` without mutating state;
4. flush pending simulation time under the old capacities;
5. spend the exact price through `Economy`;
6. append the ID once;
7. derive all machine upgrade multipliers from the complete ownership list;
8. emit production and upgrade change signals.

The public debug modifier seam rejects machines managed by real upgrades. The
old free Sorter x1/x2 dashboard controls were removed from player flow.

## Progression

```text
Start
0.75 items/s — Basic Sorter bottleneck

Buy Sorter Motor I
1.00 items/s — Basic Scanner bottleneck

Buy Scanner Motor I
1.25 items/s — Receiving Desk reported for the Receiving/Scanner tie
```

Each completed item continues to award two Credits.

## Saving and migration

Save schema version 3 stores primitive production state:

```json
{
  "fractional_progress": 0.5,
  "machines": {
    "basic_sorter": {
      "enabled": true,
      "runtime_capacity_multiplier": 1.0
    }
  },
  "owned_upgrade_ids": ["sorter_motor_1", "scanner_motor_1"]
}
```

Upgrade-controlled multipliers are deliberately absent. After validation and
restore, they are recomputed from `owned_upgrade_ids`. Duplicate or unknown IDs,
malformed machine state, and unsupported versions are rejected before live
state mutation.

Migration is deterministic:

- Version 1 saves receive the default production line and no upgrades.
- Version 2 data-driven line saves preserve enabled states, fractional progress,
  and unrelated machine modifiers. Existing `scanner_motor_1` ownership is
  retained and the old redundant Scanner multiplier is normalized to runtime ×1.
- An exact legacy Basic Sorter multiplier of ×2 maps to `sorter_motor_1`; its
  runtime multiplier becomes ×1 so the new upgrade is applied exactly once.
- A non-×2 legacy Sorter multiplier is treated as unrelated runtime state and is
  preserved without granting Sorter Motor I.
- The older version 2 Scanner-only shape retains Scanner enabled state,
  fractional progress, and `scanner_motor_1` ownership. Its obsolete queued
  incoming-item value has no equivalent in the current four-stage line and is
  intentionally not restored.

## UI boundary

The dashboard builds its upgrade shop from domain definitions and calls the
generic purchase API. It displays Credits, stage capacities, throughput,
bottleneck, ownership, price, descriptions, purchase feedback, and a projected
throughput/bottleneck preview. It does not calculate authoritative production,
prices, ownership, or save data.

## Rules for future systems

- Keep state ownership explicit and avoid duplicate authoritative totals.
- Advance production with aggregate numbers, never one Node per processed item.
- Keep rendering downstream of simulation results.
- Add Autoloads only for truly session-wide single authorities.
- Keep machine and upgrade configuration in data Resources.
- Derive upgrade effects from ownership; never serialize them as a second truth.
- Version save changes and validate a complete payload before applying it.
- Add signals only when a current consumer benefits from decoupling.

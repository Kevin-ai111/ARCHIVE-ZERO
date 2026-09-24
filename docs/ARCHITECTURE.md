# ARCHIVE ZERO Architecture

## Foundation

ARCHIVE ZERO separates authoritative numerical simulation from presentation.
Four session-wide services remain Autoloads:

1. `GameState` owns session totals.
2. `Economy` validates currency transactions.
3. `SimulationManager` advances time, owns purchased upgrade IDs, and commits output.
4. `SaveManager` persists and restores supported state.

Machine definitions, installed machines, upgrade definitions, and production
lines are domain objects rather than Nodes or additional Autoloads.

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

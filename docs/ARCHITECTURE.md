# ARCHIVE ZERO Architecture

## Foundation

ARCHIVE ZERO separates authoritative numerical simulation from presentation.
Four session-wide services remain Autoloads:

1. `GameState` owns session totals.
2. `Economy` validates currency transactions.
3. `SimulationManager` advances time and commits completed output.
4. `SaveManager` persists and restores supported state.

Machine definitions, installed machines, upgrades, and production lines are
domain objects rather than Nodes or Autoloads.

## Production domain

### MachineDefinition

`MachineDefinition` is a Godot `Resource` containing static machine-type data:
stable ID, display name, description, base processing rate, and purchase cost.
The development definitions live in `data/machines/` and contain no installed
or mutable state.

### MachineRuntime

`MachineRuntime` represents one installed stage. It references a definition and
owns only runtime state: enabled state and a capacity multiplier. Its configured
capacity is:

```text
definition.base_processing_rate × capacity_multiplier
```

The multiplier is the integration point for upgrades and remains available as
a debug seam for validating capacity changes.

### ProductionLine

`ProductionLine` owns the ordered relationship between runtime stages. Machine
objects do not know whether they belong to a line, graph, or future branch.
The current factory builds one linear development line:

```text
Receiving Desk → Basic Scanner → Basic Sorter → Archive Intake
```

Every stage is required. A disabled or zero-capacity stage stops the entire line.
When running, throughput is the minimum positive effective capacity. The first
stage matching that calculated minimum is reported as the bottleneck; no machine
ID or stage position is special-cased.

Stage utilization is `line throughput / effective stage capacity`, clamped to
0–100%. A stopped line, disabled stage, missing stage, or zero capacity reports
0% and never divides by zero.

### Fractional production

`ProductionLine.simulate_elapsed()` adds `throughput × elapsed seconds` to one
fractional accumulator. Only complete items are returned; the remainder stays
in the line for later calls. One large elapsed interval and many smaller
intervals therefore preserve equivalent output without spawning item Nodes.

### Scanner upgrades

`ScannerUpgrades` is the small catalog for purchasable Scanner modifiers. The
current Scanner Motor I costs 50 Credits and applies a `1.25×` capacity
multiplier. `SimulationManager` owns purchased upgrade IDs, spends through
`Economy`, applies the resulting multiplier to the Scanner `MachineRuntime`, and
rejects duplicate or unaffordable purchases. Upgrade definitions and ownership
do not live in UI code. Scanner upgrade ownership is authoritative for its
capacity multiplier: the generic debug modifier API cannot change the Scanner,
and loading normalizes the serialized derived multiplier from owned upgrade IDs.
This prevents an upgrade from being applied twice or a Scanner capacity from
changing across a save/load cycle.

### SimulationManager

`SimulationManager` schedules fixed simulation ticks and delegates production
math to `ProductionLine`. It commits completed item totals to `GameState` and
credits through `Economy`. The temporary prototype output value of two credits
per completed item lives here, outside all machine definitions.

Before a machine state change, upgrade purchase, or save, pending sub-tick time
is simulated using the previous configuration. This prevents the scheduler
remainder from being lost or retroactively processed with a new capacity.

The manager does not calculate bottlenecks, utilization, machine configuration,
or UI formatting.

## Saving

Save schema version 2 stores a `production_line` dictionary:

```json
{
  "fractional_progress": 0.5,
  "machines": {
    "basic_scanner": {
      "enabled": true,
      "capacity_multiplier": 1.25
    }
  },
  "scanner_upgrades": ["scanner_motor_1"]
}
```

Only primitive data keyed by stable machine and upgrade IDs is serialized.
Nodes, scenes, and Resource objects are never stored. The entire production
payload is validated before live state changes. Version 1 development saves
load with the new line's default runtime state.

Two independently developed version-2 shapes existed before the production
branches were reconciled. Loading accepts both the current `production_line`
shape and the earlier Scanner-only `production` shape, then normalizes them to
the current data-driven line. Existing current-main saves that predate upgrade
ownership receive an empty upgrade list.

## Simulation and visuals

Simulation values are authoritative. Visual scenes may sample and illustrate
them, but visible objects must never determine throughput, inventory, or income.
Fifty rendered objects may represent millions of numerically processed items.

The debug UI calls service APIs and reads domain results. It does not calculate
throughput, bottlenecks, utilization, rewards, upgrade prices, or save data.

## Future extension

Branching belongs in a future production-network domain that can compose the
same `MachineDefinition` and `MachineRuntime` objects. It should replace or sit
beside the current linear relationship without adding graph assumptions to the
machine types themselves.

## Rules for future systems

- Keep state ownership explicit and avoid duplicate authoritative totals.
- Advance production with aggregate numbers, never one Node per processed item.
- Keep rendering downstream of simulation results.
- Add Autoloads only for truly session-wide single authorities.
- Keep machine type configuration in data resources.
- Version save changes and validate a complete payload before applying it.
- Keep upgrade definitions out of UI and machine runtime state.
- Add signals only when a current consumer benefits from decoupling.

# ARCHIVE ZERO Architecture

## Foundation

ARCHIVE ZERO separates authoritative numerical simulation from presentation.
The current runtime is deliberately small and consists of four project-wide
services plus one temporary production source.

Autoload order is significant:

1. `GameState` owns session state.
2. `Economy` validates currency transactions and delegates state changes.
3. `SimulationManager` advances numerical production.
4. `SaveManager` persists and restores supported state.

These services are Autoloads because they represent one session-wide authority
and must remain available across future scene changes. The Basic Scanner and UI
are not Autoloads.

## Responsibilities

### GameState

- Owns money, lifetime earnings, processed-item totals, and playtime.
- Provides controlled mutation methods and read-only access through getters.
- Emits state-change signals needed by observers.
- Contains no UI, production, or file-format logic.

### Economy

- Checks affordability and validates positive transaction amounts.
- Routes accepted additions and spending through `GameState`.
- Prevents normal transactions from making money negative.

### SimulationManager

- Schedules simulation at a configurable fixed interval.
- Can advance an arbitrary elapsed duration in one numerical operation.
- Commits aggregate item and credit totals; it never spawns an item Node.
- Owns the temporary Basic Scanner instance and exposes its current rates.

`BasicScanner` retains fractional numerical progress between ticks. At its
current rate it completes one item per second and awards two credits per item.
This makes results independent of rendering frame rate and provides the basis
for later offline progress.

### SaveManager

- Serializes supported game data only, never Nodes or scene state.
- Uses a versioned JSON file at `user://archive_zero_save.json`.
- Writes a temporary file before replacing the main save.
- Validates the complete payload before changing live state.
- Rejects missing, malformed, negative, or unsupported-version saves safely.
- Provides a version boundary where migrations can be added later.

The Basic Scanner's enabled flag and fractional progress are intentionally not
part of save version 1. Loading clears transient fractional progress.

## Simulation and visuals

Simulation values are authoritative. Visual scenes may sample and illustrate
those values, but visible objects must not determine throughput, inventory, or
earnings. Fifty rendered objects may represent millions of numerically processed
items. Removing or simplifying visuals must never change economic results.

## UI interaction

UI code calls public service APIs and observes signals. It must not write state
fields, calculate authoritative production, or serialize data. The current
dashboard follows this rule for manual processing, transactions, scanner control,
and save/load actions.

## Rules for future systems

- Keep state ownership explicit; do not duplicate authoritative totals.
- Advance production with aggregate numbers, not one Node per item.
- Keep rendering and animation downstream of simulation results.
- Add an Autoload only when a service truly spans scenes and has one authority.
- Prefer focused data and composition over manager growth or inheritance trees.
- Add save fields deliberately and increment `save_version` when compatibility
  requires a migration.
- Keep source definitions data-driven once multiple machines or items exist;
  avoid building that abstraction before the production-chain design is known.
- Add signals only when a current consumer benefits from decoupling.

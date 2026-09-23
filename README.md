# ARCHIVE ZERO

ARCHIVE ZERO is a premium incremental/automation game for PC/Steam.

The player begins as a night-shift worker manually processing ordinary lost
property. The archive gradually becomes a vast automated facility for sorting,
researching, and containing increasingly impossible objects.

## Project

| | |
| --- | --- |
| **Genre** | Incremental / Automation |
| **Engine** | Godot 4.7.x |
| **Language** | GDScript |
| **Platform** | PC / Steam |
| **Status** | Early Development |

The current build provides authoritative session state, transaction-safe
currency handling, fixed-interval numerical simulation, a data-driven four-stage
production line, a purchasable Scanner Motor I capacity upgrade, versioned JSON
saving, and a minimal debug dashboard.

## Open locally

1. Install a stable Godot 4.7.x release.
2. Clone this repository.
3. Import `project.godot` from the repository root in Godot Project Manager.
4. Open the project and press **F6**/**F5** to run the configured debug scene.

No third-party addons are required.

Run the headless production and persistence validation from the repository root
with:

```bash
godot --headless --path . tests/production_pipeline_test.tscn
```

Manual runtime checks are listed in
[`docs/VALIDATION.md`](docs/VALIDATION.md).

## Development notes

The repository root is the Godot project root. Runtime simulation is numerical;
visual objects must never be the authoritative source of production progress.
See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) before adding systems.

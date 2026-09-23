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

The current build includes the first production pipeline: incoming items feed a
throughput-limited Scanner, processed items generate Credits, and Scanner Motor I
can be purchased to increase capacity. Production remains aggregate and numerical.

## Open locally

1. Install a stable Godot 4.7.x release.
2. Clone this repository.
3. Import `project.godot` from the repository root in Godot Project Manager.
4. Open the project and press **F6**/**F5** to run the configured debug scene.

No third-party addons are required.

## Tests

Run the headless production and persistence suite from the project root:

```bash
godot --headless --path . --script tests/production_pipeline_test.gd
```

## Development notes

The repository root is the Godot project root. Runtime simulation is numerical;
visual objects must never be the authoritative source of production progress.
See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) before adding systems.

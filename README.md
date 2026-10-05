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
production line, a data-driven two-step motor upgrade loop, versioned JSON saving,
an initial fixed-camera Archive Room with its first production environment and
modular conveyor, the layered production-art Basic Scanner and Receiving Desk,
the layered production-art Basic Sorter and Archive Intake, a minimal gameplay
HUD, and a separate development dashboard. All four current production stages
now have dedicated presentation scenes.

The Archive Room also includes the Phase 4I unified environment polish:
cool archive depth, four worklights, institutional signage, and machine
grounding. Integration evidence and exact asset provenance are documented in
[`docs/ARCHIVE_ROOM_POLISH.md`](docs/ARCHIVE_ROOM_POLISH.md).

## Open locally

1. Install a stable Godot 4.7.x release.
2. Clone this repository.
3. Import `project.godot` from the repository root in Godot Project Manager.
4. Open the project and press **F6**/**F5** to run the Archive Room.

The project uses a 1920×1080 logical canvas and starts in a practical 1280×720
window. Use the HUD button to switch fullscreen mode. The full development
dashboard remains available from the bottom-left HUD button.

No third-party addons are required.

On a fresh checkout, import once and then run the headless production and
persistence validation (including the independent case foundation) from the repository root:

```bash
godot --headless --editor --path . --quit
godot --headless --path . tests/case_foundation_test.tscn
godot --headless --path . tests/manual_case_processing_test.tscn
godot --headless --path . tests/commissioning_test.tscn
godot --headless --path . tests/progressive_room_states_test.tscn
godot --headless --path . tests/production_pipeline_test.tscn
godot --headless --path . tests/visual_foundation_test.tscn
godot --headless --path . --quit-after 120
```

Manual Case UI and actual three-resolution runtime proofs are documented in
[`docs/MANUAL_CASE_PROCESSING_UI.md`](docs/MANUAL_CASE_PROCESSING_UI.md).
Run `tests/manual_case_processing_visual_test.tscn` for explicit developer QA;
normal game startup still initializes no cases.

Progressive room commissioning is an independent stage domain. Normal startup
remains fully commissioned; no First Shift gameplay is activated yet. Run
`tests/progressive_room_states_visual_test.tscn` for explicit stage/Case QA.
The contract, three-resolution runtime evidence and deferred gameplay boundary
are in [`docs/PROGRESSIVE_ROOM_STATES.md`](docs/PROGRESSIVE_ROOM_STATES.md).

Manual runtime checks are listed in
[`docs/VALIDATION.md`](docs/VALIDATION.md).

## Development notes

The repository root is the Godot project root. Runtime simulation is numerical;
visual objects must never be the authoritative source of production progress.
See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) before adding systems.

The concrete lost-property case foundation is documented in
[`docs/CASE_SYSTEM.md`](docs/CASE_SYSTEM.md). Its queue starts empty, remains
independent of aggregate production, and is not yet part of the live v3 save.

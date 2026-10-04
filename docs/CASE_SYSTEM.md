# Item and case foundation — Phase 5B / PR #14

## Authority boundary

A concrete lost-property case is **not** one aggregate ProductionLine item.
The numerical `SimulationManager → ProductionLine → MachineRuntime` pipeline
continues to own automated output and throughput; GameState/Economy own totals
and transactions. Case completion grants no Credits and produces no aggregate
items. CaseManager has no dependency on those services and never calls
`SimulationManager.process_manual_items()`. That existing API is unchanged.

CaseManager is an additional session-wide Autoload. It starts empty, has no
processing callback, and never initializes First Shift or the later keycard hook.
The current enabled machine defaults, two-Credit reward, art, conveyor, HUD and
existing purchase/save behavior are unchanged.

## Definitions and progress

| Class / location | Responsibility |
| --- | --- |
| `CaseCategoryDefinition`, `data/cases/categories/` | Stable StringName ID and display name; extensible without an enum |
| `ArchiveItemDefinition`, `data/cases/items/` | Object identity, category and ordinary description; no textures or progression |
| `CaseDefinition`, `data/cases/records/` | Authored found-location/time/condition, expected category and data-only routing |
| `CaseCatalog` | Validates IDs, uniqueness, field content and cross-references; preserves authored order |
| `CaseProgress` | Only case ID, lifecycle state and selected category |
| `CaseManager`, `scripts/cases/case_manager.gd` | Queue, single active slot, transition validation and progress authority |

Definitions are immutable from the consumer's perspective: the catalog copies
input resources and returns detached definition copies. Progress, queue and save
queries also return detached snapshots, not mutable references to live authority.
The catalog rejects a case whose expected category disagrees with its item type.

Canonical categories: `PERS` Personal Items, `ELEC` Electronics, `DOCS` Documents,
`BAG` Bags / Containers. Initial case IDs and authored categories:

| ID | Item | Expected category | Routing |
| --- | --- | --- | --- |
| CASE_0001 | Red Folding Umbrella | PERS | NORMAL |
| CASE_0002 | Smartphone | ELEC | NORMAL |
| CASE_0003 | Backpack | BAG | NORMAL |
| CASE_0004 | Passport Wallet | DOCS | NORMAL |
| CASE_0005 | Wireless Earbuds | ELEC | NORMAL |
| CASE_0006 | Canvas Tote Bag | BAG | NORMAL |
| CASE_0007 | House Keys | PERS | NORMAL |
| CASE_0008 | Tablet | ELEC | NORMAL |
| CASE_0009 | Document Folder | DOCS | NORMAL |
| CASE_0010 | Black Hotel Keycard | PERS | MANUAL_REVIEW |

CASE_0001 preserves `Central Station — Platform 4`, `22:41`, `Wet / minor wear`.
Cases 0002–0009 have mundane metadata in their `.tres` records. CASE_0010 is
authored at `Archive Sector A1`; MANUAL_REVIEW is only a routing value and does
not trigger any story behavior. The keycard category is PERS for this foundation.

## Queue and lifecycle

The only normal lifecycle is:

`QUEUED → ACTIVE → INSPECTED → CLASSIFIED → ARCHIVED`

`enqueue_case()` / `enqueue_cases()` append in caller order. Batch insertion is
atomic: an invalid ID anywhere rejects the whole batch. Unknown IDs, duplicates
within the batch, and any already recorded queued/active/archived case reject.
`activate_next_case()` consumes the queue head only when no case is active.
It returns a detached CaseProgress or null on rejection.

`mark_active_case_inspected()`, `classify_active_case(category_id)` and
`archive_active_case()` require their exact preceding state and return booleans.
No skipping, replaying a step, reclassification or backwards transition is
permitted. Archiving clears the active slot but retains the progress record.
Archived IDs are returned in catalog order, not completion order.

A chosen category is empty until classification. Any **known** category may be
chosen, including a wrong one: expected ELEC / selected PERS is valid progress.
`is_case_classification_correct()` compares the choice to authored data only in
CLASSIFIED/ARCHIVED states; it is false for unclassified or unknown cases.

`reset_cases()` is an explicit new-session boundary that clears queue, active
slot and recorded history, not a lifecycle transition. It returns false when
already empty. Only that boundary or an explicit restore can replace history;
ordinary queue/transition APIs cannot reactivate archived cases.

Signals describe changed components of a fully committed operation:

- `queue_changed`: once when queue order/content changes.
- `active_case_changed`: once when the active **ID** changes.
- `case_progress_changed(case_id)`: once for each changed/removed record, in
  catalog order; classification/inspection notify here rather than duplicating
  the active-ID notification.

Rejected operations emit nothing. Identical valid restore succeeds without
signals. Reentrant mutations from signal handlers reject until the current
notification batch is complete; getters remain usable and see committed state.

## Independent serialization v1

Global `SaveManager.SAVE_VERSION` remains **3**. No case fields are written to
or read from the live user save. This independently testable payload is exposed
only through CaseManager's `get_case_save_data()`, `get_default_case_save_data()`,
`is_valid_case_save_data()` and `restore_case_save_data()`:

```json
{
  "case_save_version": 1,
  "queue": ["CASE_0003"],
  "active_case_id": "CASE_0002",
  "progress": [
    {"case_id": "CASE_0001", "state": "ARCHIVED", "selected_category_id": "PERS"},
    {"case_id": "CASE_0002", "state": "INSPECTED", "selected_category_id": ""},
    {"case_id": "CASE_0003", "state": "QUEUED", "selected_category_id": ""}
  ]
}
```

Queue order is retained; progress is serialized in deterministic catalog order.
Definitions, found metadata, item text, rewards and machine state are absent.
The empty default contains an empty queue/progress array and empty active ID.

Validation requires exactly these root/entry keys and primitive types. The
version must equal numeric 1: integer 1 and JSON-parsed float 1.0 are accepted;
bool/string/fractional/non-finite values are not. IDs and state labels must be
strings. Unknown/duplicate cases, unknown categories, impossible queue/active
membership, absent progress records, multiple active records, archived queued
records, early selection and missing classified/archived selection all reject.
Every queued record must be in the queue and every active lifecycle record must
match the one active ID. Every queued/active ID must have its progress record.

Restore validates the whole payload and constructs replacement progress before
committing anything. Invalid restore leaves state and signals unchanged.
The snapshot is a checkpoint, not an event log: it validates structurally possible
states, not historical proof of earlier inspection. Explicit restore may return
to a previous valid checkpoint; normal gameplay transitions remain forward-only.

## Validation and later integration

`tests/case_foundation_test.tscn` covers catalog references and extension, detached
data, ordered/atomic enqueue, lifecycle and exact signal counts, wrong/correct
classification, reentrant notification safety, JSON round-trip, strict corrupt
restore rejection, and every legal saved lifecycle representation.

Authority isolation includes money, earned Credits, processed totals, fraction,
pending time, throughput, owned upgrades, all enabled flags, full production-save
data and playtime. Completing a case and resetting/restoring case history leaves
all values unchanged, both with an enabled line and with a disabled Intake.

Run sequentially from the project root with an official Godot 4.7.x release:

```bash
godot --headless --editor --path . --quit
godot --headless --path . tests/case_foundation_test.tscn
godot --headless --path . tests/production_pipeline_test.tscn
godot --headless --path . tests/visual_foundation_test.tscn
godot --headless --path . --quit-after 120
```

CI adds the case suite alongside all existing import, production, visual and main
smoke steps. Existing graphical checks remain in the visual suite; this milestone
adds no presentation to render.

Local validation with official Godot `4.7.2.stable.official.ed1daf0bf` passed:

- Project import and main-scene smoke (`--quit-after 120`, 120 frames): exit 0.
- Case foundation: **474 checks**, including **79 invalid save payloads** rejected
  atomically and without notifications.
- Production/upgrade/save/migration suite: exit 0. Pending purchase:
  `balance=1, owned=true, multiplier=2.00, fraction=0.05000, pending=0.00`.
- Visual suite at 1920×1080, 1280×720 and 960×540: exit 0. Numerical invariance
  with/without ArchiveRoom: `items=75, credits=150, fraction=0.00000, throughput=0.75`.
- Case completion/reset/restore: money **175**, earned **300**, processed **7**,
  fraction **0.45**, pending **0.2**, Sorter Motor I ownership, all machine flags
  and production-save state unchanged. Throughput remains **1.0/s** with all
  stages enabled and **0.0/s** with Intake disabled. No live save is written by
  the new test scene. These are headless regressions, not new graphical captures.

PR #15+ must deliberately decide playable First Shift initialization, UI and
case-reward semantics. Live persistence must separately decide whether global
save v4 is needed and migrate v3 saves by inserting default case state. Do not
silently extend the existing v3 user save. Item artwork, commissioning, tutorial
sequence and story behavior are deferred. Intake parcel-outline Issue #13 is
unrelated and untouched.

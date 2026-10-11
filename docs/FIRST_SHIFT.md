# First Shift

PR #18 established the transaction-safe opening shift. Phase 5E-B1 keeps that
architecture while making every classification player-owned, rewarding only
correct work and removing Credit requirements from the three commissioning gates.

## Player progression

```text
MANUAL_CASES   CASE_0001..0006   player Inspect + Classify + Archive
SCANNER_READY  explicitly commission Scanner for 0 C
SCANNER_CASES  0007, 0008, 0009, 0011   auto-Inspect; player Classify + Archive
SORTER_READY   explicitly commission Sorter for 0 C
SORTER_CASES   0012..0015   auto-Inspect; player Classify + Archive
INTAKE_READY   explicitly commission Archive Intake for 0 C
COMPLETE       all four runtimes enabled; aggregate line begins at 0.75/s
```

The exact fresh queue is `0001, 0002, 0003, 0004, 0005, 0006, 0007, 0008,
0009, 0011, 0012, 0013, 0014, 0015`. `CASE_0010` remains the unchanged Black
Hotel Keycard in the catalog and is deliberately neither queued nor rewarded.

`FirstShiftManager` is an event-driven Autoload with no `_process` loop. It owns
only phase, phase Case groups, one-time reward claims, committed result snapshot and the
upgrade-unlock gate. Case lifecycle remains in `CaseManager`; ordered machine
commissioning remains in `CommissioningManager`; machine flags and throughput
remain in `SimulationManager → ProductionLine → MachineRuntime`.

Scanner/Sorter assistance calls only the normal Inspect transition after its
current notification batch completes. This preserves CaseManager's reentrant
mutation protection. The Sorter no longer auto-classifies; recommendation and
confidence are deferred to PR #20. Classification and Archive remain explicit
player actions in every phase.

## Economy and authority

An archived First Shift Case grants **5 Credits when correct** and **0 Credits
when misrouted**. There is no base reward. It never calls
`SimulationManager.process_manual_items()`. Claimed Case IDs are persisted, so
restore notifications or a duplicate archive observation cannot pay twice.
Reward publication is signal-safe: the claim is reserved before Economy emits
`money_changed`, the Credit and progression gate are committed while the First
Shift transaction guard is active, and First Shift signals publish only after
the complete state is observable. If Economy rejects the Credit, the claim and
phase are rolled back before the guard is released. A zero-credit result still
commits exactly one claim and advances progression, but deliberately makes no
Economy call. `case_result_committed` publishes only after archive, claim,
Credits and gate state are coherent.

All wrong: `14×0 = 0 Credits`. All correct: `14×5 = 70 Credits`.
Mixed: exactly `5 × correct Case count`. Scanner, Sorter and Intake each cost
0 C, so accuracy can never softlock First Shift. Credits now measure performance
and remain spendable on the unchanged upgrades after Full Line is online.

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

Commissioning is a cross-authority transaction. Preflight validates the exact
phase/stage relationship and target runtime. A transaction snapshot
still covers GameState totals for exact invariance, Commissioning stage, Production save,
pending simulation/tick state and First Shift phase. Scanner, Sorter and Intake
must satisfy all postconditions after their normal public APIs run; otherwise
every authority is restored and the exact snapshot is verified before a failure
is returned. No coordinator writes another authority's private fields.

Rollback uses narrow authority-owned silent APIs in `GameState`,
`CommissioningManager`, and `SimulationManager`. They validate and restore only
their own transaction snapshots without emitting normal gameplay signals. A
persistent synchronous listener therefore receives no `money_changed` and no second
`processed_items_changed`, `state_restored`, `commissioning_stage_changed`,
`production_line_changed`, `upgrades_changed`, or `simulation_updated` wave
during rollback. Normal save/load restore functions retain their existing
notification behavior.

After exact silent restoration and verification, FirstShiftManager emits one
dedicated `transaction_rolled_back` reconciliation signal. ArchiveRoom and the
gameplay HUD respond only by re-reading the completed authority state. This
returns a failed Scanner attempt to dormant Manual presentation without
publishing fake domain mutations or success-facing First Shift state.

`SaveManager` rejects save and load requests while this critical section is
active, before flushing simulation or touching either save path. Therefore
synchronous listeners on `commissioning_stage_changed` or
`production_line_changed` cannot persist a partially committed transaction,
cannot replace a prior valid file, and cannot emit `game_saved`. Native v4
validation additionally requires phase/stage agreement and a one-to-one match
between archived First Shift Cases and reward claims. The explicit
`COMPLETE`+zero-claim legacy marker remains accepted for pre-v4 migrations.

## Runtime evidence and performance

Current inspection/Directive/result captures are documented in
[ARCHIVE_DIRECTIVES.md](ARCHIVE_DIRECTIVES.md). They include zero-Credit Scanner
commissioning and a Sorter Case waiting in INSPECTED for the player's category.
The older PR #18 images below remain historical evidence of its original economy
and temporary auto-classification behavior.

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

`tests/first_shift_test.tscn` performs 438 checks covering the exact queue and
gates, both economy paths, automation, reward idempotency, authority isolation,
all commissioning failures, save checkpoints, every legacy migration, the
upgrade guard, dormant/disabled semantics, the 300-second no-backlog case and
the 100-second Full-Line invariant, strict/atomic First Shift v1 payload
validation, adversarial rollback at all three commissioning gates, synchronous
signal-save rejection, exact 5-Credit reward replay, and native v4 cross-domain
composition checks. Persistent commissioning listeners attempt nested public
commissioning and public machine-state interference at Scanner, Sorter and
Intake while remaining connected through rollback; production listeners and seven signal
counters prove silent restoration, exact snapshots, successful retry, and
presentation reconciliation.

`tests/archive_inspection_rules_test.tscn` covers Directive validity/priority,
all normal First Shift evaluations, the same-art evidence override, mutable
classification/Case-v1 round-trip, no precommit answer feedback, committed
correct/misrouted result snapshots, zero-reward idempotency, all three zero-cost
commissions and the exact 35-Credit mixed path. The all-wrong 0 C and all-correct
70 C paths remain explicit in the First Shift suite.

`tests/first_shift_visual_test.tscn` is an opt-in graphical evidence driver. It
uses public gameplay APIs and captures ArchiveRoom; it is not part of runtime.

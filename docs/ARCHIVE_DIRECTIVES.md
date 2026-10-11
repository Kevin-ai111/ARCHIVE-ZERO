# Archive Directives — Phase 5E-B1

Archive Directives are normal-work rules for comparing inspected evidence with
an institutional route. They establish the first `inspection → evidence → rules
→ player decision → commit → consequence` loop without implementing mystery
content, Scanner reports or Sorter recommendations.

## Data and evaluation

The runtime foundation has three narrow classes:

- `ArchiveDirectiveDefinition`: Resource fields for stable ID, title, display
  text, integer priority, target category, evidence field and exact match values.
- `ArchiveDirectiveCatalog`: validates nonempty data, unique IDs, unique
  priorities, allowed evidence fields and existing category references.
- `ArchiveDirectiveEvaluator`: sorts by descending priority (ID tie-breaker for
  deterministic defensive behavior) and returns the first matching category.

This is intentionally a predicate list, not a scripting language. Later Shifts
can provide a different catalog or staged availability without changing Case
save data. `CaseDefinition.expected_category_id` remains the authority and can
support future exceptions. CASE_0010 is excluded from normal-work validation.

## Shift-01 rules

| Priority | Directive | Evidence | Route |
| ---: | --- | --- | --- |
| 400 | 01-C Documents — Priority | Identifier is `Document ID` or `File reference` | DOCS |
| 300 | 01-B Electronics | Item identity is Smartphone, Tablet or Wireless Earbuds | ELEC |
| 200 | 01-D Bags & Containers | Item identity is Backpack or Canvas Tote Bag | BAG |
| 100 | 01-A Personal Items | Item identity is Folding Umbrella or House Keys | PERS |

Document evidence outranks container form. CASE_0006 and CASE_0011 therefore
share the Canvas Tote Bag texture but resolve differently: `None` → BAG versus
`File reference` → DOCS. The second record is ordinary lost-property handling,
not an anomaly.

## Presentation and commitment

The compact in-panel drawer is available throughout the First Shift. It uses
existing panel assets, 18px logical body text and an opaque petroleum backdrop.
Opening/closing it is presentation-only. All category buttons remain available
after the first choice. No green/red correctness, expected category or answer
hint appears before `RELEASE TO ARCHIVE`.

After the complete archive/reward/gate transaction, FirstShiftManager publishes
an immutable `case_result_committed` snapshot. Correct results show +5 C;
misroutes show selected, expected and +0 C. Opening the next Case clears only the
presentation snapshot.

## Runtime evidence

All images are actual Godot 4.7.2 Compatibility viewport readbacks. Each folder
contains all seven states plus renderer metadata:

- [1920×1080](screenshots/archive-inspection-rules/1920x1080/)
- [1280×720](screenshots/archive-inspection-rules/1280x720/)
- [960×540](screenshots/archive-inspection-rules/960x540/)

Representative proofs: [Full-HD Directives](screenshots/archive-inspection-rules/1920x1080/a-inspected-directives.png),
[960×540 misroute](screenshots/archive-inspection-rules/960x540/e-misrouted-result.png),
and [transitional Sorter decision](screenshots/archive-inspection-rules/960x540/g-sorter-awaiting-player-classification.png).
Independent QA and visual approval remain required.

# Manual case processing UI — Phase 5C / PR #15

## Package and immutable imports

Source: `ARCHIVE_ZERO_Phase5C_B_Manual_Case_Processing_UI_v1.1_PRODUCTION_REVIEW.zip`.
Verified ZIP SHA-256:
`8d07948e2fd15c9c098ace65220c281d14e67445d991a546c902230cd0222a1e`.

The packaged `validation_report.json` reports **97/97 PASS**. The supplied
deterministic verifier was independently executed, with full SHA checking enabled:
**53/53 PASS**, including the complete package file set, editable references and
exact native-to-runtime item exports. No package build/regeneration was run.

Only **31 original runtime PNGs** are integrated: 17 UI surfaces/controls plus
4 category icons in `assets/ui/case_panel/`, and 10 items in `assets/cases/items/`.
Original filenames and bytes are preserved. Every SHA-256 and export dimension is
recorded in [CASE_PANEL_ASSETS.json](CASE_PANEL_ASSETS.json) and rechecked in CI.
All originals are 8-bit RGBA PNGs. All item PNGs are 512×512 and display uniformly
in a centered 256×256 TextureRect, preserving aspect and alpha. Source PNGs,
ORA files, packaged scripts/verifier and offline composites remain outside the
Godot runtime directory and are not committed.

Generated `.png.import` files follow repository convention: lossless mode 0,
mipmaps disabled, alpha remap preserved, no premultiplication. Panel descendants
inherit explicit LINEAR filtering, matching existing fractional canvas scaling.
No new font files are introduced.

## Presentation and authority

`scenes/ui/case_panel.tscn` is a reusable CanvasLayer at layer 1. Its controller
`scripts/ui/case_panel.gd` constructs native Controls, Labels, Buttons and modular
NinePatchRects, never a single flattened panel Sprite. The approved logical
rectangle remains **(1028,176), 824×708** on the unchanged 1920×1080 canvas.

Texture-pixel patch margins are twice the manifest's logical margins. Each
NinePatch surface is drawn at 0.5 scale with twice its logical size, so both the
corner sampling and the visible border thickness are correct. Text and hit
targets are independent unscaled native Controls. Header/status/body/label/button/
category-code/subtitle sizes remain **30/18/22/16/22/20/16**.

FOUND has two lines of space; item names ellipsize without reducing font size.
CONDITION uses a full-width value below its label so the longest authored values
remain completely readable at body size 22. This is native layout adaptation,
not altered or regenerated artwork.

`CaseItemPresentationCatalog` maps item IDs to approved textures only in
presentation. CaseManager contains no textures or UI state. CaseDefinition gains
three validated nonblank authored strings: `inspection_material`,
`inspection_identifier`, `inspection_risk`. All ten records use the exact
requested values; these strings drive no gameplay decisions. CaseProgress and
CaseManager code/schema are unchanged; inspection values never enter case-save v1.
Global SaveManager stays **v3**, with no case data added to the live user save.

The panel reconstructs presentation from CaseManager queries on
`active_case_changed` and `case_progress_changed`. Refresh/restore signal handling
calls no mutation API. All input mutations go through public CaseManager APIs.
There is no local authoritative case or selected-category cache.

| Authority state | Inspect | Categories | Release |
| --- | --- | --- | --- |
| ACTIVE | Enabled | Disabled | Disabled |
| INSPECTED | Disabled | All four enabled | Disabled |
| CLASSIFIED | Disabled | Locked; chosen category amber + check | Enabled |
| ARCHIVED | Panel closes; active clears | — | — |

ACTIVE displays SCAN DATA / PENDING. Inspection reveals authored Material,
Identifier and Risk with a small green check only. Incorrect but known choices
are accepted: the umbrella can be classified ELEC without any correctness label,
penalty or feedback. Presentation never reads expected_category_id or calls the
correctness query. The first keyboard focus after inspection is always PERS,
regardless of expected category; its cyan focus ring is navigation, not an answer
hint. All unselected/unfocused categories share identical base treatment.

Focus order is deterministic and skips disabled controls. Native Enter/Space
activate focused buttons; Tab cycles the currently available controls. Focus moves
from Inspect to the first enabled category, then to Release. Focus has a shaped
outline; chosen categories have a checkmark as well as amber treatment. Disabled
callbacks are guarded even if a signal is artificially emitted.

Close/Escape only hide presentation and preserve case/selection/queue. Reopening
ACTIVE, INSPECTED or CLASSIFIED rebuilds the exact authority state. Archiving
closes the panel and never activates the next queued case. MANUAL_REVIEW only adds
the supplied amber administrative strip; CASE_0010 retains exact authored
location/time/condition and the ordinary lifecycle, with no story or anomaly.

Existing HUD moves to CanvasLayer 2 and its empty full-rect root ignores mouse
input. Its actual controls are unchanged and still receive input. Top values and
bottom controls do not overlap the panel; the modal upgrade shop draws above it.
No fullscreen opaque case overlay is added; the left room remains visible.

## Startup and explicit QA access

ArchiveRoom contains the hidden panel, but startup remains empty: no enqueue,
activation, machine disable, room power change or First Shift initialization.
No release shortcut or new main-HUD case entry point is added.

Run `tests/manual_case_processing_visual_test.tscn` with F6 for explicit developer
buttons: CASE #0001, CASE #0010 and Reopen. Its production clock is frozen and it
does not write user saves. These fixtures exist only in the QA scene.

## Actual runtime evidence

Official Godot **4.7.2-stable**, OpenGL compatibility renderer, NVIDIA RTX 3060 Ti.
Screenshots are actual viewport readbacks, not offline ART composites. Captures
exercise native Godot mouse events and verify authoritative transitions before
recording the corresponding state. The source fixture is reproducible:

```bash
godot --path . tests/manual_case_processing_visual_test.tscn -- --capture=true --size=1280x720 --out=C:/temp/case-proof
```

| Physical resolution | ACTIVE | INSPECTED | Wrong ELEC choice | MANUAL REVIEW |
| --- | --- | --- | --- | --- |
| 1920×1080 | [image](screenshots/manual-case-processing/1920x1080/active.png) | [image](screenshots/manual-case-processing/1920x1080/inspected.png) | [image](screenshots/manual-case-processing/1920x1080/classified-wrong-elec.png) | [image](screenshots/manual-case-processing/1920x1080/manual-review-inspected.png) |
| 1280×720 | [image](screenshots/manual-case-processing/1280x720/active.png) | [image](screenshots/manual-case-processing/1280x720/inspected.png) | [image](screenshots/manual-case-processing/1280x720/classified-wrong-elec.png) | [image](screenshots/manual-case-processing/1280x720/manual-review-inspected.png) |
| 960×540 | [image](screenshots/manual-case-processing/960x540/active.png) | [image](screenshots/manual-case-processing/960x540/inspected.png) | [image](screenshots/manual-case-processing/960x540/classified-wrong-elec.png) | [image](screenshots/manual-case-processing/960x540/manual-review-inspected.png) |

[Archived/closed Full-HD proof](screenshots/manual-case-processing/1920x1080/archived-closed.png)
and per-resolution runtime metadata accompany the images. Every target preserves
the complete panel, centered item, readable top HUD and reachable lower controls.
The smallest category subtitles are 16px / 10.7px / **8px** physically, respectively.
960×540 meets the supplied minimum but remains visibly less comfortable than Full
HD; fractional linear scaling softens fine pixel detail. No text was shrunk.

The Computer-Use skill's Windows capture helper failed with `FrameArrived timed
out`, then `window capture timed out` on its recovery attempt. No OS-injected
hands-on mouse proof is claimed. Actual OpenGL rendering and native Godot mouse/
keyboard input regression testing succeeded independently; this limitation does
not mean screenshots were generated offline.

The captured final state reports 136 draw calls; texture-memory monitors are
recorded per resolution. These are scene-wide snapshots (including room, existing
art and render targets), not a sustained FPS benchmark or incremental UI residency
measurement. The case controller has no `_process`/continuous redraw loop.

## Automated validation and boundaries

All six requested headless commands passed with official Godot 4.7.2. Case
foundation: **477 checks** (79 corrupt-save payloads). Manual UI: **520 checks**,
also passed with the real OpenGL renderer. Tests include all 31 source hashes,
original RGBA/dimensions/import parameters, all authored inspection values, full
condition/scan text fit, exact state/button behavior, wrong choices, close/reopen,
fresh-instance reconstruction, read-only restore, native mouse hit testing,
Tab/Enter/Space/Escape, existing upgrade-shop access and all three layouts.

UI isolation, both running and stopped: money **175**, earned **300**, processed
**7**, fraction **0.45**, pending **0.2**, Sorter Motor I ownership, all flags and
production-save data are unchanged. Throughput stays **1.0/s** or **0.0/s**.
No case rewards, aggregate items or production mutations occur.

Existing numerical regressions remain: 100 seconds = **75 items, 150 Credits,
0.75 throughput, 0.00000 fraction**. Pending purchase = **balance 1, owned true,
multiplier 2.00, fraction 0.05000, pending 0.00**. Existing production/upgrade/save/
migration and visual suites and the 120-frame main-scene smoke all pass.

CI is pinned to official checksum-verified **Godot 4.7.2** and runs import, case
foundation, manual UI, production, visual and main smoke in order. Existing steps
are retained; main smoke is strengthened from 2 to 120 frames.

PR #16+ retains commissioning and progressive room states; PR #17 retains First
Shift sequencing. Rewards, live-save migration, story behavior, owner matching,
automatic next case, player-visible queues and Issue #13 are outside this PR.

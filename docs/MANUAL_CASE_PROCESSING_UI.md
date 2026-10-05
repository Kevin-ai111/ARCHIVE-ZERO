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
category-code/subtitle sizes are now **30/18/22/18/22/20/18**. The correction
raises only panel secondary typography; no font asset or global filtering changes.

FOUND has 68 logical pixels for two lines; item names retain their ellipsis
policy without reducing font size (all ten current names fit in full).
CONDITION uses a full-width value below its label so the longest authored values
remain completely readable at body size 22. This is native layout adaptation,
not altered or regenerated artwork.

### PR #15 correction: actual wrapped-line visibility

Previous reviewed head: `48d1dd9ad3851652989d2dfc4beca8ee94bef71b`.
The original 63px FOUND region showed only **1 of 2** wrapped lines for
CASE_0003/0004/0006/0008/0009 at every supported resolution. Before changing the
panel, the new native measurement test reproduced exactly **15 failures**:
five authored cases times three resolutions. All authored text is unchanged.

Godot 4.7.2 measures each body-size-22 line at 31px plus 3px line spacing:
**31 + 3 + 31 = 65px**. FOUND now uses 68px, leaving 3px safety margin.
Its top/width stay y=151/324; TIME moves y=214→219, CONDITION label y=245→250
and value y=267→276. The secondary CONDITION label has 26px height at font 18.
The information surface alone grows 220→228px to keep 4px bottom padding;
it still ends before the unchanged Scan Data section at y=316. Panel bounds,
item size, buttons, colors, HUD and all other section positions remain unchanged.

`tests/case_panel_text_metrics.gd` reads each live shaped Label's
[`get_line_count()` and `get_visible_line_count()`](https://docs.godotengine.org/en/4.7/classes/class_label.html), measured per-line height,
theme line spacing, width and visibility. The check requires all lines to be
visible and the full measured text to fit; it does not substitute a node-bounds
or nonempty-string assertion. It also checks TIME, CONDITION, item name and all
three inspected values, plus every requested secondary label/category subtitle.
The test checks all ten cases at all three resolutions. A negative control
temporarily restores CASE_0003's actual Label to 63px at each resolution and
requires **2 total / 1 visible** lines and a failed completeness measurement.
Thus the previous implementation cannot silently pass the new regression.

All requested secondary labels and category subtitles move **16→18 logical px**;
their native text measurements fit without truncation, including Bags / Containers.
Heading/subtitle heights grow 24→26px where necessary, within existing sections
and unchanged category hit targets. Physical secondary font sizes are now
**18 / 12 / 9px** at 1920×1080 / 1280×720 / 960×540. Source body text stays 22px.

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
The smallest panel secondary text is now 18px / 12px / **9px** physically,
respectively. At 960×540 it is more legible than the former 8px treatment and all
category subtitles fit. It remains smaller/softer than Full HD, so this is not a
claim of accessibility for every user or display. Fractional linear scaling is
unchanged. No text was shrunk.

### All-ten-case correction render proofs

Each link below is a complete actual Godot runtime capture in INSPECTED state.
Per-resolution metadata records native dynamic/secondary Label measurements for
all ten cases. The dedicated capture scene uses real rendering and native mouse
events, and fails with a nonzero exit code if any text is incomplete.
All five QA-blocking cases were additionally inspected visually at every target;
their second lines, TIME, CONDITION and scan values are complete and nonoverlapping.
All ten cases were also visually inspected at the smallest 960×540 target.

| Case | FOUND visible/total (all resolutions) | 1920×1080 | 1280×720 | 960×540 |
| --- | --- | --- | --- | --- |
| CASE_0001 | 1/1 | [image](screenshots/manual-case-processing/1920x1080/case_0001-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0001-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0001-inspected.png) |
| CASE_0002 | 1/1 | [image](screenshots/manual-case-processing/1920x1080/case_0002-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0002-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0002-inspected.png) |
| CASE_0003 | 2/2 | [image](screenshots/manual-case-processing/1920x1080/case_0003-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0003-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0003-inspected.png) |
| CASE_0004 | 2/2 | [image](screenshots/manual-case-processing/1920x1080/case_0004-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0004-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0004-inspected.png) |
| CASE_0005 | 1/1 | [image](screenshots/manual-case-processing/1920x1080/case_0005-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0005-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0005-inspected.png) |
| CASE_0006 | 2/2 | [image](screenshots/manual-case-processing/1920x1080/case_0006-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0006-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0006-inspected.png) |
| CASE_0007 | 1/1 | [image](screenshots/manual-case-processing/1920x1080/case_0007-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0007-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0007-inspected.png) |
| CASE_0008 | 2/2 | [image](screenshots/manual-case-processing/1920x1080/case_0008-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0008-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0008-inspected.png) |
| CASE_0009 | 2/2 | [image](screenshots/manual-case-processing/1920x1080/case_0009-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0009-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0009-inspected.png) |
| CASE_0010 | 1/1 | [image](screenshots/manual-case-processing/1920x1080/case_0010-inspected.png) | [image](screenshots/manual-case-processing/1280x720/case_0010-inspected.png) | [image](screenshots/manual-case-processing/960x540/case_0010-inspected.png) |

During the original integration the Computer-Use skill's Windows capture helper failed with `FrameArrived timed
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
foundation: **477 checks** (79 corrupt-save payloads). Corrected Manual UI: **1873 checks**,
also passed with the real OpenGL renderer. Tests include all 31 source hashes,
original RGBA/dimensions/import parameters, all authored inspection values, full
actual wrapped-line visibility (including the original-layout negative control),
condition/item/time/scan and secondary text fit, exact state/button behavior, wrong choices, close/reopen,
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

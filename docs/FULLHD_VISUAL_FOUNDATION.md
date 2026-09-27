# Full-HD Visual Foundation

## Resolution strategy

ARCHIVE ZERO now uses a 1920×1080 logical design canvas. Godot scales
`canvas_items`, preserves the 16:9 aspect ratio, and allows fractional scale
factors. Full HD is the primary visual target; 1280×720 is the default
development window, and 960×540 remains the readability regression floor.

This also provides a clean path to 2560×1440 and 3840×2160: both are exact 16:9
upscales of the logical canvas. Non-16:9 displays retain the complete composition
with letterboxing rather than exposing additional world space or cropping HUD.

## Approved room geometry

| Element | Pivot | Greybox size |
| --- | ---: | ---: |
| Receiving Desk | (268, 920) | 336×352 |
| Basic Scanner | (708, 920) | 384×416 |
| Basic Sorter | (1204, 920) | 480×360 |
| Archive Intake | (1668, 920) | 304×464 |

The common decorative item path is Y=688, the machine ground baseline is Y=920,
and the fixed camera is centered at (960, 540). These measurements are authored
for readability and silhouette balance rather than by blindly doubling the old
960×540 UI.

## Scene and gameplay boundary

The Archive Room contains named distant-background, architectural-midground,
playable-ground, conveyor, machine, foreground, effects, camera, and HUD layers.
The four machines use deliberately simple vector-like greybox shapes. The Basic
Scanner reads its enabled, active, bottleneck, and Motor I ownership state from
`SimulationManager`.

The moving conveyor parcels are decorative. They do not represent queued items,
run production, award Credits, or participate in save data. The existing
numerical simulation remains authoritative.

## UI adaptation

The gameplay HUD uses large logical type and controls whose smallest tested
physical output at 960×540 is 12-pixel text and 120×32-pixel primary actions.
The upgrade shop has a vertical `ScrollContainer`, disables horizontal scrolling,
and contains only Sorter Motor I and Scanner Motor I.

The development dashboard remains separate. Its content, fonts, and input targets
were resized for the Full-HD logical canvas while preserving its top alignment,
horizontal centering, vertical scrolling, transaction controls, Save/Load, and
status feedback.

## Current limitations

- Visuals are greybox placeholders and intentionally contain no final artwork.
- The first room is fixed-camera and has no player navigation.
- The display-mode toggle provides practical windowed/fullscreen switching, but
  platform-specific exclusive-fullscreen behavior is not introduced in this milestone.
- Automated tests validate layout contracts and physical readability floors;
  committed GPU renders provide the complementary graphical evidence.

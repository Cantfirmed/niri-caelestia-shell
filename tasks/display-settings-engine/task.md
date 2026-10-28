# Display Settings Engine & Multi-Monitor Hotplug

## Status: Done

## Description
Overhaul the Niri display management workflow in Caelestia Shell:
1. Replace fragile regex-based KDL updates (`scripts/update_display.py`) with a robust parser/serializer that safely updates `~/.config/niri/niri/output.kdl` while preserving comments, blocks, and formatting.
2. Remove hardcoded absolute paths (`/home/patrick/...`) in `modules/nexus/pages/DisplayPage.qml`.
3. Enhance the Nexus Display settings UI with magnetic monitor snapping, fractional scaling selection (1.0x, 1.25x, 1.5x, etc.), refresh rate / VRR controls, and display rotation (90°, 180°, 270°).
4. Add a safety confirmation modal ("Reverting in 15s...") when changing modes to prevent black screens.
5. Harmonize with `niri-display.py` and `niri-display-monitor.py` for headless/lid-closed/docked scenarios.

## Checklist
- [x] Implement robust KDL serializer for `output.kdl` (handling `position`, `mode`, `scale`, `transform`, `vrr`)
- [x] Fix hardcoded script path in `modules/nexus/pages/DisplayPage.qml` to use dynamic project paths
- [x] Add display rotation / transform support to Nexus Display UI
- [x] Add VRR (Variable Refresh Rate) and fractional scaling options to the UI
- [x] Add 15-second test timer / revert modal for display configuration changes
- [x] Verify multi-monitor arrangement and lid-closed state transitions with `niri-display-monitor.py`

# Design: Display Settings Engine & Multi-Monitor Hotplug

## Overview
Currently, `modules/nexus/pages/DisplayPage.qml` writes display updates by shelling out to `scripts/update_display.py` with a hardcoded absolute path (`/home/patrick/.config/quickshell/niri-caelestia-shell/scripts/update_display.py`).
`scripts/update_display.py` uses crude regular expressions to find `output "..." { ... }` blocks and replace lines. When an output configuration contains comments, nested settings, or unknown properties, regex replacement frequently malforms the KDL syntax.

Furthermore, changing screen resolution or mode can occasionally cause display loss without an automated revert mechanism.

## Architecture & Implementation

### 1. Robust KDL Configuration Management
- Replace regex replacements in `scripts/update_display.py` with a structured parser or AST manipulator (or a helper using Python's `kdl-py` or an AST serializer).
- Preserve existing non-managed attributes (e.g. `variable-refresh-rate`, `background-color`, `transform`, comments).
- Support standard Niri output attributes:
  ```kdl
  output "eDP-1" {
      mode "2880x1800@120.000"
      scale 1.5
      position x=0 y=0
      transform "normal" // or "90", "180", "270", "flipped"
      variable-refresh-rate
  }
  ```

### 2. Relative & Configurable Paths
- In `modules/nexus/pages/DisplayPage.qml`, eliminate the `/home/patrick/...` hardcoded path:
  ```qml
  // Use Paths.config / Quickshell execution directory
  const scriptPath = Paths.config + "/scripts/update_display.py";
  ```

### 3. Nexus Display UI Enhancements
- **Rotation / Transform**: Add dropdown/icon toggles for 0°, 90°, 180°, and 270°.
- **Scale Selector**: Provide quick presets for fractional scaling (1.0, 1.25, 1.33, 1.5, 1.75, 2.0).
- **VRR Toggle**: Switch for adaptive sync / variable refresh rate where supported.
- **Confirmation Countdown Modal**:
  - When applying a new mode or layout, show a toast/modal: *"Applying new display configuration. Click Confirm to keep, reverting in 15 seconds..."*
  - Automatically revert if not confirmed within 15 seconds.

### 4. Hardware & Lid Synchronization
- Ensure smooth interplay with `niri/niri-display.py` and `niri/niri-display-monitor.py`.
- Prevent configuration writes from re-enabling an internal laptop screen when the lid is closed and external displays are active.

# Design: Niri Infinite Ribbon Mini-Map for Taskbar

## Overview
Niri organizes windows as an infinite horizontal ribbon of columns on each workspace.
The standard Caelestia Shell workspace bar uses discrete icons grouped by application (`modules/bar/components/workspaces/DraggableWindowColumn.qml`), which was inherited from traditional tiling window managers (Hyprland/Sway).

This task creates a native Niri **Ribbon Mini-Map** that gives the user immediate spatial awareness of their infinite desktop ribbon.

## Architecture & Implementation

### 1. Data Model
- Niri's IPC returns:
  - `is_active` / `is_focused` for windows and columns.
  - Column dimensions, window titles, and application IDs.
- Derive a normalized horizontal geometry array:
  ```json
  [
    { "columnIndex": 0, "widthProportion": 0.5, "windows": [ { "id": 101, "app_id": "kitty" } ] },
    { "columnIndex": 1, "widthProportion": 0.33, "windows": [ { "id": 102, "app_id": "firefox" }, { "id": 103, "app_id": "spotify" } ] },
    { "columnIndex": 2, "widthProportion": 0.5, "windows": [ { "id": 104, "app_id": "slack" } ] }
  ]
  ```

### 2. UI Representation (`RibbonStrip.qml`)
- A continuous horizontal strip where each column is drawn with its proportional width.
- A glowing viewport frame (`Tokens.color.primary` or Material 3 container) showing which columns currently sit inside the monitor view.
- Columns outside the physical screen viewport fade slightly into the background with peek indicators at the screen edges.
- Multi-window columns (stacked or tabbed) display stacked pill/tab dividers.

### 3. Interactivity
- **Click**: Dispatches `Niri.focusWindow(id)` or `Niri.centerColumn()`.
- **Wheel**: Scrolling over the widget scrolls columns (`focus-column-left` / `focus-column-right`).
- **Drag**: Reorders columns directly on the ribbon.

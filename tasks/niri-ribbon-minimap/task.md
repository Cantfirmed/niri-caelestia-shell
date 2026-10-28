# Niri Infinite Ribbon Mini-Map for Taskbar

## Status: Done

## Description
Design and implement a native Niri ribbon visualization widget for Caelestia's taskbar.
Rather than treating Niri workspaces as static Hyprland-style workspace numbers/dots, this component visually represents the horizontal scrollable ribbon of columns, highlighting column widths, the active viewport, off-screen windows, and stacked vertical tabs within a column.

## Checklist
- [x] Inspect Niri IPC workspace/column layout payload (`layout` and `column_width` per window)
- [x] Create `RibbonStrip.qml` component representing columns with proportional widths
- [x] Add active viewport highlight box that moves as the user scrolls horizontally in Niri
- [x] Support mouse-wheel scrolling and click-to-center navigation on ribbon columns
- [x] Render indicators for vertically stacked/tabbed windows inside columns
- [x] Add configuration toggle in `shell.json` (`bar.workspaces.style: "minimap" | "classic"`)

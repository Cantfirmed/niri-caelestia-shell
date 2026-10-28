# Design: Compositor Abstraction Layer for Upstream Syncs

## Overview
`niri-caelestia-shell` is a fork of `caelestia-dots/shell` (which was written for Hyprland).
Whenever upstream ships updates (v2.4 -> v2.5+), changes to session drawers, lockscreens, and bars collide with custom Niri deltas documented in `NIRI-DELTAS.md`.
Simultaneously, stubbed files like `services/Hypr.qml` and `services/GameMode.qml` exist simply to prevent `ReferenceError` crashes in upstream QML files.

## Architecture & Implementation

### 1. `Compositor` Singleton Interface
Create `services/Compositor.qml` as the single point of entry for compositor state:
```qml
pragma Singleton
import QtQuick
import qs.services

Singleton {
    id: root

    // Core Properties
    readonly property string backendName: Niri.niriAvailable ? "niri" : "wayland"
    readonly property var activeWindow: Niri.focusedWindow
    readonly property string activeWindowTitle: Niri.focusedWindowTitle
    readonly property var workspaces: Niri.allWorkspaces
    readonly property int focusedWorkspaceIndex: Niri.focusedWorkspaceIndex
    readonly property var outputs: Niri.outputs

    // Actions
    function focusWindow(id) { Niri.focusWindow(id); }
    function closeWindow(id) { Niri.closeWindow(id); }
    function focusWorkspace(idx) { Niri.focusWorkspace(idx); }
    function toggleOverview() { Niri.toggleOverview(); }
}
```

### 2. Module Decoupling
- Update bar, windowinfo, popouts, and launcher to bind against `Compositor.*` instead of checking `typeof Hypr !== "undefined"` or hardcoding `Niri.*`.
- Keep Niri-specific extensions (like Biri shaders and ribbon layout) cleanly grouped under `qs.services.niri`.

### 3. Automated Delta Verification
- Update `scripts/verify-deltas.sh` so CI can automatically verify upstream commits without human intervention.

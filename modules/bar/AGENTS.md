# Bar Module (Taskbar) — Agent Guide

This folder contains the custom Niri workspace bar, which replaced the original Hyprland bar.

## Overview

The `bar/` module provides the taskbar for the shell. It includes workspaces, window icons, tray area, and status elements.

### Key Components

- **`Bar.qml`**: The main bar component.
- **`components/workspaces/WindowIcon.qml`**: Displays the icon for a single window. Uses either `IconImage` (for desktop entries) or `MaterialIcon` (for font icons), configured by `windowIconImage` in `shell.json`.
- **`components/workspaces/WorkspaceIcon.qml`**: Displays the workspace label/icon.

## Modifying UI Scale & Fallbacks (CRITICAL)

When modifying the scaling or size of elements (like `WindowIcon` or `WorkspaceIcon`) based on configuration variables:

1. **Fallback Pattern (`??`)**: You **MUST** use a fallback value when referencing properties on `Config.bar.workspaces` (e.g., `Config.bar.workspaces.windowIconScale ?? 0.6`).
2. **Why?** The C++ `ConfigObject` backend provides these properties. If a new property is added to C++ but the system's Quickshell plugin hasn't been globally re-installed via `sudo cmake --install build`, the QML environment will evaluate the property as `undefined`. 
3. Without a fallback, math operations (`36 * undefined`) will result in `NaN`. A `NaN` size will cause QtQuick components (like `MaterialIcon` or `StyledText`) to completely vanish without throwing a hard crash, resulting in "disappearing icons" bugs.

### Example

**Correct (Safe):**
```qml
size: Tokens.sizes.bar.innerWidth * (Config.bar.workspaces.windowIconScale ?? 0.6)
```

**Incorrect (Dangerous):**
```qml
size: Tokens.sizes.bar.innerWidth * Config.bar.workspaces.windowIconScale
```

## Adding Settings to Nexus (The Settings Panel)

If you are asked to add a new slider or toggle to the `nexus` settings panel (e.g., `modules/nexus/pages/panels/taskbar/BarWorkspaces.qml`):

1. **C++ Requirement**: You must first add the property to the C++ backend (e.g., `plugin/src/Caelestia/Config/barconfig.hpp` using the `CONFIG_PROPERTY` macro).
2. **Global Install Required**: Because Quickshell loads plugins from the system library paths (`/usr/lib/` or `/usr/local/lib/`), any C++ changes **require a global installation** (`sudo cmake --install build`). 
3. **If you lack `sudo` access**: Do not add settings sliders! A slider bound to a non-existent C++ property will throw a `TypeError: Cannot assign to non-existent property` when moved, and won't save. 
4. Instead, if `sudo` is unavailable, rely on hardcoded "sweet spot" values directly in QML, or use existing generic config overrides if absolutely necessary.

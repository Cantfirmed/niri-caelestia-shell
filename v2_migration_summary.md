# Upgrading Caelestia Shell to v2 (Nexus): Migration Summary

This document summarizes the major architectural shifts, modifications, and porting efforts completed during the upgrade of the **Niri Caelestia Shell** from v1 to v2.

---

## 1. Core Architectural Shift (v1 vs. v2)

The upgrade synchronizes the repository with the upstream v2 ("Nexus") release of Caelestia Shell. Upstream v2 introduces massive performance and code cleanliness improvements:
* **Compiled C++ QML Plugin**: A substantial portion of the configuration parsing, system monitoring (CPU/GPU/Storage), audio/cava analysis, and image rendering was moved into a custom compiled C++ QML plugin (`libcaelestia.so` / `libcaelestiaplugin.so`).
* **From `Appearance` to `Tokens`**: The visual styling properties (fonts, spacing, padding, animations, roundings) were redesigned. Upstream replaced the old dynamic `Appearance` singleton with a strongly-typed `Tokens` engine compiled directly in the C++ plugin.
* **Declarative Settings (`shell.json`)**: Config settings (like session configs, sidebar items) are now managed declaratively via `shell.json`, making it much easier to serialize and persist state.

---

## 2. Porting Custom User Modules

The local repository had several custom modules that were missing in upstream Caelestia. We successfully preserved and adapted all of them:

### A. Novel & Manga Readers
* **`CachingImageManager` Deprecation**: The C++ image-caching plugin was completely rewritten in v2 to use `Caelestia.Images` (with a caching provider). Custom reader QML components were refactored to use the new image cacher.
* **Toggle Buttons API**: Upstream v2 changed the property signatures for toggle components. We simplified the `isToggle` property names across manga and novel components to match the new `ButtonBase` standard.

### B. Quicktoggles & Panel Drawers
* Updated custom toggles in `quicktoggles/Content.qml` to conform to the M3-style layout changes.
* Replaced custom brightness/idle logic with the new v2 service equivalents.

### C. Polkit Agent
* Restored the custom Polkit agent daemon dialog (`services/PolkitService.qml`) from history, hooking it into the v2 quickshell session management.

---

## 3. Niri Compositor & Wayland-First Integration

Since Caelestia Shell is originally built for Hyprland, several parts of the upstream v2 shell referenced X11 or Hyprland-specific utilities. We adapted these to build a pure Wayland/Niri desktop shell:

* **Removed `Hypr` Singleton Dependencies**: Eliminated references to the `Hypr` C++ IPC singleton from:
  - `services/Colours.qml`
  - `services/Notifs.qml`
  - `services/NotifData.qml`
  - `services/Brightness.qml`
* **Custom Niri Workspaces Panel**: Integrated the custom Niri workspace layout logic and icons in `Bar.qml`.
* **Stubbed GameMode**: Replaced the Hyprland-specific gamemode service with a clean, compositor-agnostic stub.
* **Niri IPC Socket**: Retained the custom C++ Niri IPC plugin that binds workspaces and layout events directly to the bar.

---

## 4. Design & Sizing Compatibility Layer

To prevent breaking custom drawers, panels, and layouts, we introduced a compatibility singleton:

* **[services/Appearance.qml](services/Appearance.qml)**: Acts as a bridge between the old v1 `Appearance` namespace and the new v2 `Tokens` namespace. It automatically maps properties (like `Appearance.padding.xl` -> `Tokens.padding.extraLarge`) to ensure existing styles load warning-free.
* **Font Family & Color Fixes**: Resolved all remaining console type warnings in standard components (like the reload popup overlay) by aligning font family lookups and ensuring proper `m3` color prefixes are used.

---

## 5. File Changes Summary Table

Here is a high-level mapping of what happened to the codebase:

| Category | Path | Action | Description |
| :--- | :--- | :--- | :--- |
| **C++ Source** | `plugin/src/...` | **Upgraded** | Integrated v2 config models, image cacher, and storage/GPU monitoring plugins. |
| **Services** | `services/Colours.qml`, `Notifs.qml`, etc. | **Ported** | Stripped Hyprland logic, ported notifications data handling, and hooked in system brightness. |
| **Custom Modules** | `modules/novel/`, `modules/manga/` | **Ported** | Upgraded image loading references and toggle buttons. |
| **New Compatibility** | `services/Appearance.qml` | **Created** | Bridge singleton routing old `Appearance` lookups to new `Tokens`. |
| **Cleanup** | `scripts/colors/...`, `scripts/setup/...` | **Deleted** | Removed redundant setup utilities, wallpaper scrapers, and KDE wrappers. |
| **Configuration** | `shell.json` | **Created** | Declarative configuration sheet for Caelestia v2 panels. |
| **Main Window** | `shell.qml` | **Upgraded** | Simplified main window layout, loading order, and reload popups. |


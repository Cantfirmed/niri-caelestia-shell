# Caelestia Shell (quickshell) Codebase Directory & Architecture Guide

Welcome, coding agent! This document describes the structure and architecture of the **niri-caelestia-shell** (Caelestia Quickshell) project to help you navigate and find files quickly.

---

## 1. Project & Profile Integration

* **Relationship with Dotfile Manager (DFM)**:
  * Profiles are stored under `~/.config/dfm/profiles/`.
  * The active caelestia configuration resides in `~/.config/dfm/profiles/caelestia/niri_caelestia`.
  * System symlinks exist at:
    * `~/.config/quickshell/niri-caelestia-shell` -> points to this directory.
    * `~/.config/niri_caelestia` -> points to this directory.
    * `~/.config/niri` -> points to `~/.config/dfm/profiles/caelestia/niri`.

---

## 2. Directory Structure

Here is a breakdown of where to find things:

### Root Files
* `shell.qml`: Root entry point for Quickshell. It instantiates the persistent background services, shortcuts, and handles output screen enumeration.
* `shell.json`: Serialized settings for the shell, loaded/saved by the `Config.qml` singleton.

### Components (`components/`)
Contains shared graphical components used across all modules. Avoid using raw Qt Quick components where these styled versions are available:
* `StateLayer.qml`: Customized hover/click/ripple effect `MouseArea`.
* `MaterialIcon.qml`: Renders Material Design icons.
* `StyledRect.qml`: Styled rectangle with glassmorphic backing/colors.
* `TextButton.qml` / `IconButton.qml`: Custom pre-styled control buttons.

### Configuration (`config/`)
* `Config.qml`: Singleton representing the loaded config (`shell.json`). To trigger config saves, modify a property and call `Config.markDirty("section")`.
* `SessionConfig.qml`, `GeneralConfig.qml`, etc.: Definitions of configuration sheets.

### Services (`services/`)
Persistent background processes and IPC event controllers:
* `Visibilities.qml`: Singleton managing the visibility/state of all drawer panels.
* `BatteryMonitor.qml`: Dispatches notifications and hibernates system on low battery.
* `Brightness.qml`: Manages backlight adjustment using `brightnessctl`, `ddcutil`, etc.
* `IdleInhibitor.qml` / `LidInhibitor.qml`: Handles system state inhibition based on user activity/lid position.
* `Wallpapers.qml`: Manages background/wallpaper settings.

### Modules (`modules/`)
The visual panels, status bars, and drawers of the environment:
* `drawers/`
  * `Drawers.qml`: Manages fullscreen layer, windows, backdrop, and keyboard focus grab rules.
  * `Panels.qml`: Places individual drawers (Launcher, Dashboard, Session Drawer, etc.) relative to the screen.
  * `Interactions.qml`: Touch/drag controls and mouse-hover monitoring for panel toggles.
* `session/`
  * `Content.qml`: Power menu drawer (Shutdown, Sleep, Reboot, Logout buttons).
* `launcher/`
  * `Content.qml`: Main search/application launcher with clipboard, calculations, and emoji support.
* `dashboard/`
  * `Content.qml`: Top status dashboard with weather, clocks, and resource monitors.
* `controlcenter/`
  * `ControlCenter.qml`: Pane settings overlay for audio, network, displays, and visual appearance themes.
* `lock/`
  * `LockSurface.qml`: Custom lock screen interface.
* `bar/`
  * Bottom/Side status bar layout, workspace icons, and system trays.
* `areapicker/`
  * Screenshot region visualizer and OCR area selector.

### Scripts (`scripts/`)
Helper backends spawned or managed by the QML frontend:
* `manga/manga_server.py`: Local service for the built-in manga reader.
* `novel/main.py` / `server.py`: Local service for the light novel reader.
* `setup/setup.sh`: Installation script.
* `areaPicker/region_ocr.sh` / `region_search.sh`: OCR and screenshot processing helpers.

---

## 3. Useful Commands for Development

### Start or Restart Quickshell
To apply modifications, kill and restart the quickshell daemon:
```bash
qs kill -c niri-caelestia-shell && qs -c niri-caelestia-shell -d
```

### Inspect IPC Targets and Signals
```bash
qs -c niri-caelestia-shell ipc show
```

### View Live Shell Logs
```bash
quickshell log -c niri-caelestia-shell
```

### Verify Custom Niri Deltas
Run the automated verification suite to confirm no custom Niri features or fixes were broken or overwritten:
```bash
./scripts/verify-deltas.sh
```

---

## 4. Custom Niri Deltas & Upstream Preservation

Refer to [`NIRI-DELTAS.md`](file:///home/patrick/.config/niri_caelestia/NIRI-DELTAS.md) and [`AGENTS.md`](file:///home/patrick/.config/niri_caelestia/AGENTS.md) for a comprehensive list of all custom modifications that must **never** be overwritten during upstream merges or rebases.

> [!CAUTION]
> **NEVER run blind `git merge upstream/main` or `git pull upstream`.**
> Upstream merges silently wipe out customized features (Sleep button, Niri window detail popup, power auto-balance, build configs).
> Always use `scripts/port-upstream.sh` (which auto-excludes protected files) and verify with `./scripts/verify-deltas.sh`.
> Git hooks installed via `./scripts/install-hooks.sh` automatically enforce these checks on commit and merge.

---

## 5. Auto-lock, DPMS, and Display Monitor Guidelines

- **DPMS & Display Fallback Daemon:** `niri-display-monitor.py` must check `is_session_locked()` and never trigger display fallbacks when monitors are powered off for DPMS sleep. Reverting to internal screen is only for genuine cable disconnects (`status != "connected"` in DRM).
- **Preserve `QSG_RENDER_LOOP=threaded`:** Do not downgrade to `basic` for stability workarounds; keep `threaded` for multi-refresh (144Hz + 120Hz) fluid rendering and fix the underlying surface lifecycle instead.
- **Root-Cause Invariant:** Never propose changing idle/lock timers to "fix" crashes; timers only postpone the trigger.



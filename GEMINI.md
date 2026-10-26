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

- **Pre-Start Display Sanity Invariant:** `~/.config/systemd/user/niri.service.d/display-sanity.conf` runs `niri-display.py --sanity-check` via `ExecStartPre=` to guarantee that `eDP-1` is active before Niri starts if no external display is connected, preventing black screens on standalone boot.
- **Socket Auto-Discovery Invariant:** `niri-display-monitor.py` must discover active sockets by scanning `$XDG_RUNTIME_DIR/niri*.sock` and `/run/user/<uid>/niri*.sock` when `$NIRI_SOCKET` is not exported in the service environment.
- **DPMS & Display Fallback Daemon:** `niri-display-monitor.py` must check `is_session_locked()` and never trigger display fallbacks when monitors are powered off for DPMS sleep. Reverting to internal screen is only for genuine cable disconnects (`status != "connected"` in DRM).
- **Preserve `QSG_RENDER_LOOP=threaded`:** Do not downgrade to `basic` for stability workarounds; keep `threaded` for multi-refresh (144Hz + 120Hz) fluid rendering and fix the underlying surface lifecycle instead.
- **Root-Cause Invariant:** Never propose changing idle/lock timers to "fix" crashes; timers only postpone the trigger.
- **Sleep Spurious Resume & Wakeup Invariant:**
  - On this machine (Lenovo IdeaPad AMD Phoenix/Hawk Point), premature wakeups (2–5s after sleep) are caused by hardware wakeup lines (`XHC0..XHC4`, `GPP1..GPP6`, `ELAN06FA:00`), NOT Niri or Quickshell.
  - **Reciprocal Invariant:** If the user reports that the laptop **cannot be woken up** by external keyboards, mice, or the touchpad, check `disable-spurious-wakeups.service` and `/proc/acpi/wakeup`. When `XHC*` and `ELAN` wakeups are disabled, only the **Power Button** and **Lid** can wake the machine from `s2idle`.
- **Strict Edge-Triggered Lock Invariant:** Session locking (`lock.locked = true`) must **always** be strictly edge-triggered: driven only by explicit user keybindings, systemd logind events (`AboutToSleep`, `LockRequested`), or system idle timeouts. **Never** attempt to track or restore lock state using filesystem marker files, `FileView` watchers, or watchdog poll loops (`launch-quickshell.sh`). Marker files and polling loops cause self-reinforcing feedback loops and random desktop re-locking.
- **Suspend-Resume Handshake Grace Period Invariant:** When waking from system suspend (`s2idle` / `deep`), external display link training (HDMI / DisplayPort) takes 1–3 seconds, during which DRM connectors may transiently drop or report no active outputs. Display monitoring daemons (`niri-display-monitor.py`) must detect sleep resume (e.g. `time.time() - last_tick > 3.5s` in a 1.5s select loop) and grant an **8-second grace period** before evaluating display fallbacks or triggering display reconfigurations.
- **Boot-Aware Rescue Shortcuts Invariant:** Quickshell takes ~3–4 seconds to boot and register Wayland IPC handlers. Emergency recovery shortcuts (such as `Super+Alt+L`) must **never** use inline short-timeout cascades (`timeout 2s ... || pkill -9 ...`). They must invoke a dedicated rescue script (e.g. `scripts/rescue-lock.sh`) that checks daemon process age (`ps -o etimes=`) and polls until IPC is available, ensuring newly spawned booting instances are never killed.
- **Quickshell Watchdog & Process Reaping Invariant:** Never kill or restart Quickshell in watchdog loops based on transient child processes in zombie/defunct state (`ps -eo ppid,stat | grep Z`). Subprocesses naturally linger in state `Z` until reaped by the Qt/Quickshell event loop; killing the shell for transient zombies causes an 8.6-second restart loop. Watchdogs must rely solely on consecutive IPC ping timeouts and grant a startup grace period of at least 15 seconds.
- **Persistent Wrapper Logging Invariant:** `scripts/launch-quickshell.sh` must always redirect stdout and stderr to `~/.local/state/caelestia/quickshell-wrapper.log` with timestamps rather than discarding output to `/dev/null`, ensuring all watchdog actions and exit codes remain auditable.
- **No Startup Config Reload Invariant:** Services generating compositor configuration files (`BiriShaders.qml`, `NiriTiling.qml`, `NiriBlur.qml`) must never call `saveImmediately()` or reload compositor configuration (`niri msg action load-config-file`) when successfully loading existing valid state from disk. Always use `Quickshell.execDetached()` for one-shot commands instead of dynamically created `Qt.createQmlObject` Process instances.

---

## 6. Drawer & Panel Interaction Guidelines

- **Interactive Panels & Shortcut Precedence**: Interactive drawers (`utilities`) must retain shortcut active state while hovered. Never let cursor presence inside an open panel override an explicit close shortcut.
- **Compound Drawer Coordination**: Attached drawers (`sidebar` and `utilities`) must synchronize dismissals so closing either panel resets both states to prevent ghost/detached panels.
- **Zero Inactive Hit-Test Height**: Hit-test functions (`inBottomPanel`) must evaluate `panelHeight` as 0 when `!shouldBeActive` to prevent exit animations from re-triggering opens.
- **Hover Retrigger Guard**: When an interactive panel is closed via keyboard or IPC while the cursor is over its region, hover retriggering must be blocked until the cursor moves out of the region.
- **New Panel Registration Invariant:** Any new panel or modal overlay MUST be registered in both `components/ScreenState.qml` and `components/DrawerVisibilities.qml`, aliased in `Panels.qml`, and punched through the surface mask in `Regions.qml`.
- **Modal Layout Sizing:** Modals centered in `Wrapper.qml` must declare explicit `width` and `height` to prevent horizontal layout collapse.
- **Shell-to-Compositor Fallback Invariant:** Keybindings invoking shell IPC should chain a fallback to the compositor's built-in equivalent via `||` (e.g. `qs ... || niri msg action ...`) to ensure essential functions remain operable when Quickshell is stopped or recovering.

---

## 7. Niri IPC Event Stream & Animation Invariants

- **Filter Viewport Animations**: Niri emits `WindowLayoutsChanged` on every frame of horizontal camera scrolling (`tile_pos_in_workspace_view`). Event handlers in `niriipc.cpp` must filter out sub-pixel animation updates and only trigger model resets (`resetData()`) when structural layout (`pos_in_scrolling_layout`) or dimensions (`window_size`) change.
- **Prevent Socket Buffer Starvation**: Niri's IPC server enforces a strict 64-item event stream channel buffer. Blocking the Qt main thread during event bursts causes buffer overflow and forced client disconnection. Maintain socket receive buffer (`SO_RCVBUF`) at 1MB and avoid heavy synchronous operations in IPC callbacks.


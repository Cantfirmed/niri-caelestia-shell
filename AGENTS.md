# Caelestia Shell (quickshell) — Agent Guide

Welcome, coding agent! This document describes the architecture, key patterns, and gotchas of the **niri-caelestia-shell** (Caelestia Quickshell) project — a Wayland shell UI built on [Quickshell](https://github.com/Quickshell/quickshell) for the [Niri](https://github.com/YaLTeR/niri) compositor.

---

## 1. Project & Profile Integration

* **Dotfile Manager (DFM):** Profiles live under `~/.config/dfm/profiles/`. The active config is at `~/.config/dfm/profiles/caelestia/niri_caelestia`.
* **System symlinks:**
  * `~/.config/quickshell/niri-caelestia-shell` → this directory
  * `~/.config/niri_caelestia` → this directory
  * `~/.config/niri` → `~/.config/dfm/profiles/caelestia/niri` (compositor config)

---

## 2. Root Files

| File | Purpose |
|------|---------|
| `shell.qml` | Root entry point. Instantiates persistent services, shortcuts, backgrounds, lock screen, polkit agent, etc. |
| `shell.json` | Declarative settings sheet. Loaded by the C++ `GlobalConfig` singleton. **This is the primary config file** — all panel visibility, sizing, behaviour toggles live here. |

---

## 3. Architecture — v2 (Nexus) Changes

This repo was upgraded from v1 to v2 ("Nexus"). Key architectural shifts:

* **Compiled C++ QML Plugin** (`Caelestia.Internal`, `Caelestia.Config`, `Caelestia.Blobs`, etc.) — config parsing, system monitoring, SDF blob rendering, and image caching moved into a C++ plugin built at `build/plugin/`.
* **`Tokens` styling engine** — replaced the old dynamic `Appearance` singleton. Strongly-typed tokens (font, spacing, padding, animation curves) compiled in C++. A compatibility shim at `services/Appearance.qml` maps old `Appearance.*` lookups to `Tokens.*`.
* **`PersistentProperties`** — QML type that automatically persists properties to disk. Used by `DrawerVisibilities` to save/restore panel open states across shell restarts.
* **`Config.extra`** — dynamic extra config with only `manga` and `novel` booleans. Adding new config sections requires creating a C++ config class, adding it to `plugin/src/Caelestia/Config/config.hpp`, and rebuilding.

### Niri Compositor Migration (Hyprland → Wayland)

Caelestia Shell was originally built for Hyprland. v2 stripped Hyprland-specific dependencies for pure Wayland/Niri:

* **Removed `Hypr` C++ singleton** references from `services/Colours.qml`, `services/Notifs.qml`, `services/NotifData.qml`, and `services/Brightness.qml`.
* **Custom Niri Workspaces Panel** — the bar's workspace icons, layout, and drag/drop logic were built from scratch for Niri's IPC.
* **Niri IPC Socket** — a custom C++ `NiriIpc` plugin (`Caelestia.Internal`) that binds workspace/layout events directly to the bar, replacing Hyprland's IPC.
* **Stubbed GameMode** — the Hyprland-specific gamemode service was replaced with a clean, compositor-agnostic stub.
* **Fallback detection** — `ContentWindow.qml` has `typeof Hypr !== "undefined"` guards with an `else if (typeof NiriIpc !== "undefined")` fallback, allowing the same QML to work on both compositors.

### Custom Module Porting

* **Image caching** — the old `CachingImageManager` C++ plugin was rewritten as `Caelestia.Images` with a new caching provider. Manga/novel reader QML components were refactored to use the new API.
* **Toggle Buttons** — upstream v2 changed `isToggle` property signatures in `ButtonBase`. Custom toggles in manga, novel, and quicktoggles panels were updated to match.
* **Polkit Agent** — the custom Polkit authentication dialog (`modules/polkit/`) was restored from git history and hooked into v2's session management.
* **Quicktoggles** — the bottom-right quicktoggles panel (Super+N) was removed as it was redundant with the utilities panel (idle inhibit + screen recorder + quick toggles on the right side). Notifications remain via the top-right panel and sidebar NotifDock.

---

## 4. Directory Structure

### `components/`
Shared graphical components. Always prefer these over raw Qt Quick:

| Component | Purpose |
|-----------|---------|
| `StateLayer.qml` | Hover/click/ripple `MouseArea` |
| `MaterialIcon.qml` | Material Symbols icon renderer (extends `StyledText`, uses `Tokens.font.icon` builder for variable-axis fonts) |
| `StyledRect.qml` | Glassmorphic/coloured rectangle |
| `TextButton.qml` / `IconButton.qml` | Pre-styled control buttons (IconButton uses MaterialIcon internally) |
| `DrawerVisibilities.qml` | **Key file** — `PersistentProperties` singleton per screen tracking all panel visibilities. Add new boolean properties here when creating new panels. |

### `services/`
Background processes and state managers:

| Service | Purpose |
|---------|---------|
| `Visibilities.qml` | Singleton registry of `DrawerVisibilities` per screen. `getForActive()` returns the focused screen's visibilities. |
| `Niri.qml` | Niri compositor integration — workspace tracking via `Caelestia.Internal.NiriIpc` |
| `Brightness.qml` | Backlight control via `brightnessctl` / `ddcutil` |
| `Notifs.qml` | Notification state management |
| `Recorder.qml` | Screen recording service (pipewire/wf-recorder) |
| `Appearance.qml` | Compatibility shim mapping old v1 `Appearance.*` → new `Tokens.*` |
| `BatteryMonitor.qml`, `IdleInhibitor.qml`, `LidInhibitor.qml` | Power/hardware state management |

### `modules/drawers/` — The Drawer System (Critical)

This is the core panel infrastructure. Understand these files before modifying panels:

| File | Purpose |
|------|---------|
| `Drawers.qml` | Manages fullscreen layer, backdrop, keyboard focus grab for each screen |
| **`ContentWindow.qml`** | **The main window layer.** Contains the mask, bar, interactions, panels, and blob/SDF rendering. Key properties: `dragMaskPadding` (controls edge hover zones), `hasFullscreen`, `fsTransitionProg`. |
| **`Panels.qml`** | **Positions all panels** relative to the screen. Add new panels here with proper anchors. Exports `readonly property alias` for each panel so `Interactions.qml` and `Regions.qml` can reference them. |
| **`Regions.qml`** | **Mask regions** defining which parts of the window are visible. Uses `Intersection.Xor` on the outer region and `Intersection.Subtract` on per-panel `R` components to punch holes for visible panels. |
| **`Interactions.qml`** | **Hover/drag detection** for panel toggles. Uses `CustomMouseArea` with hit-test functions (`inTopPanel`, `inBottomPanel`, `inRightPanel`). Implements the "shortcut mode" pattern. |
| `Exclusions.qml` | Layer-shell exclusion zones |

#### How dragMaskPadding works

`dragMaskPadding` in `ContentWindow.qml` controls whether the window mask includes padded edge zones for hover detection:

- When **non-zero**: the mask is inset from the window edges, creating visible hover zones at screen edges. Mouse events reach the `Interactions` area.
- When **zero**: the mask covers the full content area, no hover zones at edges.
- **Critical rule**: `dragMaskPadding` must stay non-zero on all workspaces for hover to work. Window-detection checks (Hyprland `windows > 0`, Niri `hasWindows`) that return 0 should be **removed** if you want hover on all workspaces.
- Computed as `Math.max(...dragThresholds)` of enabled panels (dashboard, launcher, session, sidebar).

#### The "shortcut mode" pattern (Interactions.qml)

Each panel that supports hover-to-reveal has a corresponding `*ShortcutActive` boolean:

```
dashboardShortcutActive, osdShortcutActive, utilitiesShortcutActive
```

- **Hover mode**: Panel shows when mouse enters its zone, hides when mouse leaves.
- **Shortcut mode**: Panel was opened via keyboard/API call. Stays visible until dismissed (explicit close or entering the hover zone transitions to hover control).
- Detection: when a visibility property changes, the `Connections` handler checks if the mouse is currently in the panel's hover zone. If not, it sets the shortcut flag.
- The `onPositionChanged` handler checks the shortcut flag: if active, hover detection is skipped (panel stays open). If the mouse enters the zone, it transitions to hover control.

#### Panels Layout (right side)

The right side has stacked panels from top to bottom:

```
┌─────────────────────┐
│  notifications      │  Top-right — standalone notification panel
├─────────────────────┤
│  sidebar            │  Middle — NotifDock (notification dock)
├─────────────────────┤
│  utilities          │  Bottom-right — idle inhibit, screen recorder, quick toggles
└─────────────────────┘
```

Plus floating/detached panels:
- `osd` (volume/brightness sliders) — right edge, vertically centered
- `session` (power menu) — right edge
- `popouts` (tray menus, control center)

### `modules/` — Panel Modules

| Module | Description |
|--------|-------------|
| `dashboard/` | Top status dashboard — weather, clocks, resource monitors, media player |
| `launcher/` | App launcher with clipboard, calculator, emoji support |
| `session/` | Power menu (shutdown, sleep, reboot, logout) |
| `sidebar/` | Notification dock (NotifDock) |
| `utilities/` | Idle inhibit + screen recorder + quick toggles (WiFi, BT, mic, game mode, DND, VPN) |
| `notifications/` | Standalone notification panel at top-right |
| `osd/` | Volume/brightness OSD sliders |
| `soundpanel/` | Full overlay with per-app audio controls and MPRIS integration (Mod+A) |
| `displayselect/` | Display/output switcher overlay |
| `bar/` | Left-side status bar with workspaces, tray, clock |
| `controlcenter/` | Control center settings pane (audio, network, displays, themes) |
| `manga/` / `novel/` | Reader modules (IPC toggle via `mangaReader` / `novelReader`) |
| `lock/` | Lock screen |
| `areapicker/` | Screenshot region picker and OCR |
| `nexus/` | Settings/config UI (the "Nexus" control panel) |
| `polkit/` | Polkit authentication agent |
| `windowinfo/` | Ported to Niri — Active window detail view showing client info (PID, floating, workspace, position, size) and action buttons (move workspace, maximize, float, kill) |

### `plugin/src/Caelestia/`
C++ QML plugin source:

| Directory | Contents |
|-----------|----------|
| `Config/` | Config classes for each `shell.json` section (bar, dashboard, launcher, etc.). Each has `CONFIG_PROPERTY` macros. `config.hpp` central registry with `CONFIG_SUBOBJECT` entries. |
| `Internal/` | NiriIpc (workspace/window IPC), plus internal helpers |
| `Blobs/` | Signed Distance Field (SDF) blob rendering — the glassmorphic border/background effect |

### `scripts/`
Helper backends:
- `manga/manga_server.py` — manga reader backend
- `novel/main.py` / `server.py` — novel reader backend
- `areaPicker/region_ocr.sh` / `region_search.sh` — OCR helpers

---

## 5. IPC & Keybinding System

### Flow

```
niri config (caelestia.kdl)
  → spawn-sh "qs -c niri-caelestia-shell ipc call <target> <action>"
    → QML IpcHandler { target: "..." }
      → modifies DrawerVisibilities (PersistentProperties)
        → panel state bindings react
          → animations play
```

### Keybinding locations

| File | Purpose |
|------|---------|
| `niri/niri/caelestia.kdl` | Shell-specific keybindings: panel toggles, clipboard, screenshot tools, media/brightness keys |
| `niri/niri/binds.kdl` | General niri keybindings: workspace nav, window management, app launchers |
| `modules/Shortcuts.qml` | Internal QML shortcuts (global shortcuts via `GlobalShortcut` protocol — may not work on niri) and IPC handler definitions |

### IPC handler registration

IPC handlers are defined in `modules/Shortcuts.qml` for general-purpose handlers, or in module-specific files for module-specific handlers. Pattern:

```qml
IpcHandler {
    target: "myTarget"
    function open() { ... }
    function close() { ... }
    function toggle() { ... }
}
```

**Gotcha**: If an IPC handler is in a standalone `.qml` file (like `QuickTogglesPanel.qml`), that file **must be instantiated** in the QML tree (e.g., via a `Loader` or direct instantiation in a Wrapper). Unreferenced `.qml` files with `IpcHandler` will **silently not register** — the IPC call will do nothing with no error.

---

## 6. C++ Plugin Configuration

Config sections are defined as C++ classes in `plugin/src/Caelestia/Config/`. To add a new config section:

1. Create `newconfig.hpp` with a class using `CONFIG_PROPERTY` macros
2. Add `CONFIG_SUBOBJECT(NewConfig, newSection)` to `config.hpp`
3. Rebuild the plugin
4. Add `"newSection": { ... }` to `shell.json`

For simple boolean toggles that don't warrant a full C++ class, `Config.extra` (manga, novel) can be extended.

---

## 7. Common Gotchas & Patterns

### Modal panels (launcher, session) not receiving keyboard focus

**Symptom**: Opening the launcher (Super+Space) or session panel via keyboard shortcut doesn't grab keyboard input. Text typed still goes to the previously focused window.

**Root cause**: `WlrLayershell.keyboardFocus` was being set to `WlrKeyboardFocus.OnDemand` for modal panels via a `Binding` override in `ContentWindow.qml`. With `OnDemand`, `forceActiveFocus()` in QML doesn't reliably trigger a Wayland keyboard focus request for layer-shell surfaces — the compositor doesn't know to switch focus.

**Fix**: Modal panels (launcher, session) must use `WlrKeyboardFocus.Exclusive` instead of `OnDemand`. The `Binding` in `ContentWindow.qml` now excludes launcher and session:

```qml
Binding {
    target: QsWindow.window
    property: "WlrLayershell.keyboardFocus"
    value: WlrKeyboardFocus.OnDemand
    when: root._needsKeyboardFocus && !visibilities.launcher && !visibilities.session
}
```

With `Exclusive`, the compositor automatically grants keyboard focus to the shell surface when the panel opens. The `forceActiveFocus()` call in the launcher's `checkLauncherState()` then sets Qt-level focus to the specific text field (already within a window that has compositor-level focus).

**Also add** `win.requestActivate()` before `forceActiveFocus()` calls as a safety net — this is the pattern used by the Quickshell DankDash popout for requesting window activation from the compositor.

**Checklist when fixing keyboard focus for a new panel**:
1. Add the panel's visibility to the `WlrLayershell.keyboardFocus` group property (use `Exclusive` for modal panels)
2. If the panel should use `OnDemand`, add it to the Binding's exclusion list or include it in `_needsKeyboardFocus`
3. In the panel's content, call `forceActiveFocus()` on the target control
4. Belt-and-suspenders: also call `win.requestActivate()` if available

### Hover zones not working on occupied workspaces

**Root cause**: `dragMaskPadding` in `ContentWindow.qml` had early-return checks that returned `0` when windows existed on the workspace (both Hyprland `windows > 0` and Niri `NiriIpc.windows.some(...)`). This zeroed out the mask padding, collapsing the hover zones.

**Fix**: Remove those checks so `dragMaskPadding` stays at the max threshold value.

### Panel appears via keyboard but immediately hides

The `onPositionChanged` handler in `Interactions.qml` normally hides panels when the mouse leaves their zone. If a panel is opened via keyboard shortcut, the `*ShortcutActive` flag keeps it visible. Make sure:
1. The `*ShortcutActive` property exists
2. The `Connections` handler for that visibility property sets the shortcut flag correctly
3. The `onContainsMouseChanged` handler checks the shortcut flag before hiding

### New panel not responding to IPC calls

Check that the `IpcHandler` component is actually **instantiated** in the QML tree. A `.qml` file sitting in a directory isn't enough — it needs to be loaded as a child component somewhere.

### Session & Lockscreen controls (Sleep button vs upstream Hibernate)

**Symptom**: Upstream v2.4 replaced the `sleep` action in `modules/session/Content.qml` with `hibernate` (downloading icon), removed `sleep` from `SessionIcons` and `SessionCommands` in `plugin/src/Caelestia/Config/sessionconfig.hpp`, and stripped the session buttons (Sleep, Restart, Shutdown) from the lockscreen in `modules/lock/Center.qml`.

**Fix / Preservation**:
- In `modules/session/Content.qml`, keep `sleep` (with `dark_mode` icon fallback) in button order: `["shutdown", "sleep", "profile", "reboot", "logout"]`.
- In `modules/lock/Center.qml`, keep the bottom `RowLayout` with `IconButton` elements for Sleep, Restart, and Shutdown, as well as the vertical flex centering spacers.
- In `plugin/src/Caelestia/Config/sessionconfig.hpp`, keep `CONFIG_PROPERTY(QString, sleep, u"dark_mode"_s)` and `CONFIG_PROPERTY(QStringList, sleep, { u"suspend"_s })`.
- In `shell.json`, keep `"icons": { "sleep": "dark_mode", ... }`.
- See `NIRI-DELTAS.md` for exact code snippets and details.

### C++ Plugin build errors and silent fallback to stale system libraries

**Symptom**: Config properties return `undefined` in QML (e.g. `Config.session.icons.sleep` is empty/blank), or QML changes to C++ types don't take effect even after rebuilding.

**Root causes**:
1. **AUTOMOC omission or missing headers**: If a header declaring QObjects (like `extraconfig.hpp`) is missing `#include "common.hpp"` or is omitted from `SOURCES` in `CMakeLists.txt`, `moc` fails or generates incomplete code, leading to undefined symbol errors (e.g., `_ZN9caelestia6config11ExtraConfig16staticMetaObjectE`) when loading `libcaelestia-config.so`.
2. **Silent fallback**: When the local `build/qml` plugin fails `dlopen`, Qt silently falls back to searching system paths like `/usr/lib/qt6/qml/Caelestia/`. If a stale build exists there, Quickshell loads that older version instead of raising a visible crash, hiding the new properties.
3. **QML Import Path Priority**: `scripts/launch-quickshell.sh` must export `QML2_IMPORT_PATH` and `QML_IMPORT_PATH` pointing to `$SCRIPT_DIR/build/qml` to prioritize the local build.

### Multiple Quickshell instances / Ghost daemons

**Symptom**: Shell appears unresponsive to changes, or old layer surfaces (like an old session drawer) remain stuck on screen.

**Root cause**: If quickshell is launched manually with `qs -c niri-caelestia-shell -d` while the systemd user service (`quickshell.service`) is running, two daemon instances coexist. Both register layer-shell surfaces.

**Fix**: Always kill existing processes cleanly before restarting:
```bash
killall -9 quickshell qs 2>/dev/null || true
systemctl --user restart quickshell
# Or if running manually:
pkill -9 quickshell; pkill -9 qs
```

### PersistentProperties overriding default state

`PersistentProperties` saves state to disk and restores it on restart. If a property was `true` when the shell was killed, it'll start `true` on next launch. This can cause unexpected panel visibility. Clear saved state or handle initial state explicitly.

### Multi-monitor workspace indexing and cross-output window leakage

**Symptom**: On an external monitor, workspace slots appear occupied or active (and may show window icons from other monitors) even if those workspaces don't exist on that monitor or have no windows.

**Root cause**:
1. In Niri, workspace `idx` is 1-based **per output/monitor** (e.g., both `eDP-1` and `HDMI-A-1` have workspaces with `idx: 1, 2...`), whereas workspace `id` is globally unique.
2. Indexing workspace occupancy by `idx` globally (e.g. `workspaceHasWindows[wsIdx]`) collides across displays: if monitor A has windows on `idx: 3`, monitor B's slot 3 is falsely marked occupied.
3. Window queries falling back to `allWorkspaces.find(w => w.idx === wsNum)` fetch windows belonging to a different monitor when that index doesn't exist on the local output.

**Invariants & Best Practices**:
- **Always scope by output:** Workspaces and window queries must be scoped to the specific monitor (`getWorkspacesForOutput(outputName)`).
- **Never fall back across outputs:** Do not fall back to global `allWorkspaces` when searching by `idx`. If a workspace does not exist in `outputWorkspaces`, return empty.
- **Guard non-existent slots:** When rendering fixed workspace slots (e.g., `GlobalConfig.bar.workspaces.shown = 4`), ensure slots beyond `outputWorkspaces.length` have `workspaceId = -1` and require `workspaceId > 0` before applying active or occupied styling.
- **Use `outputActiveWs` instead of global focus:** Determine the active workspace for a bar using the output's `is_active` workspace, not global `is_focused`.

### Auto-lock, DPMS Power-Off, and Display Monitor Conflicts

**Symptom**: Quickshell crashes (SIGSEGV) when the laptop auto-locks after a few minutes of idle, or when monitors wake from DPMS sleep.

**Root causes**:
1. **DPMS Sleep vs. Fallback Daemon:** `IdleMonitors.qml` powers off monitors via `niri msg action power-off-monitors` at 300s of inactivity. The `niri-display-monitor.py` daemon, polling every 1.5s, previously checked `has_active_display` and mistook DPMS sleep for a black-screen hardware failure, triggering `niri-display.py internal`, which sent `kill -9` to Quickshell and disabled external outputs while locked.
2. **LockSurface Null Dereference:** `LockSurface.qml` accessed `screen.name` without optional chaining during output state transitions, causing QtWayland `surface_enter` crashes.
3. **Render Loop Race Condition:** Under `QSG_RENDER_LOOP=threaded`, destroying layer-shell surfaces mid-flight caused `QQuickWindow::maybeUpdate()` to access deleted window `d_ptr`s.

**Invariants & Best Practices**:
- **Guard Display Daemon:** `niri-display-monitor.py` must check `is_session_locked()` and verify that external monitors are physically disconnected in DRM (`status != "connected"`) before triggering any display fallback. Never rewrite display configs or kill Quickshell during DPMS sleep.
- **Defensive Screen Property Access:** Always use `screen?.name ?? ""` in `LockSurface.qml` and `StyledWindow.qml`.
- **Do Not Downgrade Render Loop:** Keep `QSG_RENDER_LOOP=threaded` to maintain 144Hz/120Hz smooth rendering for SDF shaders and glassmorphic blurs; fix the underlying surface lifecycle instead of switching to `basic`.
- **Never "Fix" Crashes by Changing Timers:** Increasing or disabling timers only postpones the crash until the timer expires. Always resolve the root cause.

### Adding a new panel

1. Add a boolean property to `DrawerVisibilities.qml`
2. Create the panel's `Wrapper.qml` + `Content.qml` in a new `modules/myPanel/` directory
3. Add import + alias + instantiation in `Panels.qml`
4. Add an `R {}` entry in `Regions.qml` for mask punching
5. Add hover detection in `Interactions.qml` (if desired)
6. Register IPC handler if keyboard shortcut needed
7. Add niri keybinding in `niri/niri/caelestia.kdl`

### Testing changes

```bash
# Restart shell
qs kill -c niri-caelestia-shell && qs -c niri-caelestia-shell -d

# View live logs
quickshell log -c niri-caelestia-shell

# List IPC targets
qs -c niri-caelestia-shell ipc show

# Call an IPC handler directly
qs -c niri-caelestia-shell ipc call <target> <action>

# Rebuild C++ plugin after config changes
cd build && cmake --build .
```

---

## 8. Visual Rendering Pipeline

The shell uses **SDF (Signed Distance Field) blob rendering** for the glassmorphic border/background effect:

1. `BlobGroup` — composits SDF shapes
2. `BlobInvertedRect` — creates the main window shape with rounded corners and border thickness
3. `PanelBg` (per panel/`BlobRect`) — individual panel background shapes that merge with the group
4. `MultiEffect` on the group layer — shadow + blur

For the mask/clipping:
1. `mask: hasFullscreen ? emptyRegion : regions` — the window mask determines visibility
2. `Regions.qml` uses `Intersection.Xor` (show content outside the base region) + `Intersection.Subtract` per-panel (punch holes for visible panels)
3. `dragMaskPadding` adjusts the base region size to create edge hover zones

---

## 9. Porting Upstream Changes (caelestia-dots/shell)

This fork tracks upstream at [caelestia-dots/shell](https://github.com/caelestia-dots/shell). When a new upstream version drops, here's the workflow.

### Setup (already done)

```bash
# Upstream remote is configured
git remote -v | grep upstream
#   upstream	https://github.com/caelestia-dots/shell.git (fetch)

# Shared file manifest at .pi/upstream-files.txt
# Lists all files we sync from upstream (excluding niri-specific ones)

# Port script at scripts/port-upstream.sh
```

### Workflow for new upstream version

```bash
# 1. Fetch upstream tags
git fetch upstream --tags

# 2. Preview changes to shared files only
scripts/port-upstream.sh v2.0.2 v2.0.3

# 3. Apply the patch (auto-apply)
scripts/port-upstream.sh v2.0.2 v2.0.3 --apply

# 4. Review and fix any niri-specific conflicts
#    Check `git diff --stat` and test with a restart

# 5. Rebuild C++ plugin if any plugin files changed
cd build && cmake --build .

# 6. Verify that no custom Niri deltas were broken or overwritten!
scripts/verify-deltas.sh
```

> [!CAUTION]
> **NEVER run blind `git merge upstream/main` or `git pull upstream`.**
> Upstream refactors will silently clobber our customizations (sleep button, Niri popouts, power auto-balance, build fixes).
> Always use `scripts/port-upstream.sh` or selective cherry-picks, and verify using `scripts/verify-deltas.sh`. Git hooks (`pre-commit` and `post-merge`) installed via `scripts/install-hooks.sh` enforce this check automatically.

### What to do when a patch doesn't apply cleanly

1. Run `scripts/port-upstream.sh v2.0.2 v2.0.3 --patch` to save the diff
2. Apply each file manually using the saved patch as reference
3. Look out for niri-specific overrides and protected features (see `NIRI-DELTAS.md` for full details):
   - `modules/session/Content.qml` — **DO NOT OVERWRITE**: keep `sleep` button (`dark_mode` icon); do not accept upstream's `hibernate` replacement.
   - `modules/lock/Center.qml` — **DO NOT OVERWRITE**: keep lockscreen session buttons (Sleep, Restart, Shutdown) and vertical flex spacers.
   - `plugin/src/Caelestia/Config/sessionconfig.hpp` — **DO NOT OVERWRITE**: keep `sleep` in `SessionIcons` and `SessionCommands`.
   - `plugin/src/Caelestia/Config/extraconfig.hpp` & `CMakeLists.txt` — keep `#include "common.hpp"` and `extraconfig.hpp` in `SOURCES`.
   - `scripts/launch-quickshell.sh` — keep `QML2_IMPORT_PATH` and `QML_IMPORT_PATH` exports.
   - `services/NetworkUsage.qml` — keep `import Caelestia`.
   - `modules/drawers/ContentWindow.qml` — has niri-specific window detection and IPC
   - `modules/drawers/Interactions.qml` — may reference niri-specific panels
   - `modules/drawers/Panels.qml` — different panel set from upstream
   - `modules/bar/popouts/ActiveWindow.qml` — **DO NOT OVERWRITE**: keep Niri active window popout (`Niri.lastFocusedWindow`, title, app_id, chevron button opening `winfo` drawer); reject upstream Hyprland ScreencopyView layout which collapses popup width.
   - `modules/bar/popouts/Battery.qml` — **DO NOT OVERWRITE**: keep 4th power profile selector with `auto_mode` and `services/PowerManagement.qml` integration.
   - `modules/bar/` — completely custom niri workspace bar, not in upstream
   - `services/Niri.qml` — niri-specific compositor integration
4. Always consult `NIRI-DELTAS.md` before and after any rebase or patch application to verify nothing was reverted.
5. Always run `scripts/verify-deltas.sh` and ensure all checks pass.

### What the port script does

1. Fetches upstream tags
2. Generates a filtered `git diff` using `.pi/upstream-files.txt`, automatically excluding protected files in `.pi/protected-files.txt`
3. Shows a summary + full diff, or applies it with `--apply`
4. Automatically runs `scripts/verify-deltas.sh` on `--apply`
5. Saves a `.patch` file with `--patch`

### Manual alternative (if git fetch fails)

```bash
# Get the diff URL from GitHub
curl -sL "https://github.com/caelestia-dots/shell/compare/v2.0.1...v2.0.2.diff" > /tmp/upstream.diff

# Apply with git
cd /path/to/niri_caelestia
git apply --recount /tmp/upstream.diff
```

### Niri-specific files NOT in upstream

These files are custom to this fork and won't appear in upstream diffs:
- `modules/bar/` — niri workspace bar (Hyprland bar replaced)
- `modules/windowinfo/` — ported to Niri (provides active window detail popup/drawer)
- `services/Niri.qml` — niri IPC wrapper
- `services/Players.qml` — niri-specific player integration
- `services/Brightness.qml` — modified for niri
- `services/Colours.qml` — modified for niri
- `services/Notifs.qml` — modified for niri
- `plugin/src/Caelestia/Internal/niriipc*` — niri IPC socket (replaced Hyprland IPC)
- `plugin/src/Caelestia/Internal/hypr*` — removed Hyprland files

---

## 10. Theming & Matugen Integration

In v2, color generation and wallpaper switching are handled locally in Quickshell, triggering `matugen` directly without needing the external `caelestia-cli` tool:

* **Wallpaper Switching (`services/Wallpapers.qml`):**
  * When a wallpaper is selected (via launcher or settings), `setWallpaper(path)` is called.
  * It writes the wallpaper path to `~/.local/state/caelestia/wallpaper/path.txt` using a `FileView` (with `id: stateFile`).
  * It invokes `matugen image <path> -m <mode> -t <schemeType> --source-color-index 0` via a QML `Process` named `matugenProcess`.
  * For wallpaper previews (hover/peek), it invokes a local Python script `scripts/preview.py` via `getPreviewColoursProc`, which runs `matugen` dry-run and formats the JSON for the shell.
  * It also implements a localized `setRandom()` function that picks a random file from the wallpapers directory in JS.
* **Color Palette (`services/Colours.qml`):**
  * Listens to changes in `~/.local/state/caelestia/scheme.json` via a `FileView`.
  * When the scheme changes, it loads the JSON, parses the colors, and updates the active Material You palette (`palette` / `tPalette`).
  * If the dark/light mode is changed, `setMode(mode)` runs `matugen` on the current wallpaper to regenerate the theme colors.
* **Matugen Configuration (`~/.config/matugen/config.toml`):**
  * Managed by `dotfile-manager` profiles.
  * Contains templates for Niri (`colors.kdl`), GTK, btop, mpv, Spicetify, and the shell (`scheme.json`).
  * The `wallpaper` template is configured to output back to `~/.local/state/caelestia/wallpaper/path.txt` to keep the active path synchronized.

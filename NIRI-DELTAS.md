# Niri Caelestia Shell — Custom Deltas & Upstream Preservation Guide

This document tracks all intentional divergences from upstream [caelestia-dots/shell](https://github.com/caelestia-dots/shell).

> [!IMPORTANT]
> **DO NOT OVERWRITE THESE CHANGES DURING REBASES OR UPSTREAM PORTS.**
> When running `scripts/port-upstream.sh` or applying patches from upstream, review this document to ensure our customized session controls, lockscreen features, and build fixes are preserved.

---

## 1. Protected Files Summary

| File | Type | Reason to Protect / Never Overwrite |
|------|------|-------------------------------------|
| `modules/session/Content.qml` | UI | Retains **Sleep** button (`dark_mode` icon) instead of upstream **Hibernate** (`downloading` icon). Retains button ordering: Shutdown → Sleep → Profile GIF → Reboot → Logout. |
| `modules/lock/Center.qml` | UI | Retains lockscreen quick action buttons (Sleep, Reboot, Shutdown) and vertical centering spacers (`Layout.fillHeight: true`). Upstream removed these. |
| `plugin/src/Caelestia/Config/sessionconfig.hpp` | C++ | Retains `sleep` in `SessionIcons` (`"dark_mode"`) and `SessionCommands` (`["suspend"]`). Upstream deleted sleep in favor of hibernate. |
| `plugin/src/Caelestia/Config/extraconfig.hpp` | C++ | Includes `#include "common.hpp"` so `CONFIG_NODE` is properly expanded by Qt AUTOMOC / `moc`. |
| `plugin/src/Caelestia/Config/CMakeLists.txt` | Build | Registers `extraconfig.hpp` in `SOURCES` to ensure meta-object code is generated and linked into `libcaelestia-config.so`. |
| `scripts/launch-quickshell.sh` | Shell | Exports `QML2_IMPORT_PATH` and `QML_IMPORT_PATH` pointing to `$SCRIPT_DIR/build/qml` to prevent falling back to stale system libraries in `/usr/lib/qt6/qml/`. |
| `services/NetworkUsage.qml` | QML | Imports `Caelestia` (where `CircularBuffer` resides). |
| `shell.json` | Config | Retains `"icons": { "sleep": "dark_mode", ... }` and commands for `"sleep": ["systemctl", "suspend"]`. |
| `modules/bar/popouts/ActiveWindow.qml` | UI | Retains Niri active window popout (`Niri.lastFocusedWindow`, title, app_id, chevron button opening `winfo` drawer). Upstream replaces this with broken Hyprland layout collapsing popup width. |
| `modules/bar/popouts/Battery.qml` | UI | Retains 4th power profile button (`auto_mode`) and integration with `services/PowerManagement.qml` (`autoBalance`, `setAutoBalance`, `setManualProfile`). |
| `modules/launcher/Content.qml` | UI | Retains `checkLauncherState()` on component completion so Super+W (`>wallpaper `) and Super+V (`>clip `) initialize properly when launcher loads dynamically. |
| `services/Wallpapers.qml` | Service | Retains IPC `toggle()` and `close()` in addition to `open()`. |
| `modules/nexus/pages/PluginsPage.qml` | UI | Fork-specific Nexus **Plugins** page: Manga / Novel readers as enable/disable plugin cards (`GlobalConfig.extra.manga` / `.novel`). Does not exist upstream. |
| `modules/nexus/common/PluginRow.qml` | UI | Fork-specific plugin card row (icon, title, description, status, open button, enable switch) used by the Plugins page. |
| `modules/nexus/PageCompRegistry.qml` | UI | System → **Plugins** must stay wired to `PluginsPage` (upstream merges silently reset it to `PlaceholderComp`). |
| `modules/bar/*` | Custom | Entire Niri workspaces panel and status bar (completely custom, replaces Hyprland bar). |
| `modules/windowinfo/*` | Custom | Active window detail drawer ported to Niri IPC. |
| `services/Niri.qml` | Service | Custom Niri compositor integration. |
| `plugin/src/Caelestia/Internal/niriipc*` | C++ | Custom Niri IPC socket plugin. |

---

## 2. Issues Encountered & Detailed Solutions

### A. Session Drawer (Ctrl+Alt+Del) Sleep Button Replaced by Hibernate

* **Symptom:** The Ctrl+Alt+Del session drawer displayed an "update" button with a downloading icon instead of the sleep button.
* **Root Cause:** Upstream v2.4 replaced the `sleep` action with `hibernate` in `modules/session/Content.qml`, changing the icon to `"downloading"` and command to `hibernate`.
* **Fix & Preservation Rule:**
  - In `modules/session/Content.qml`, use `modelData === "sleep"` rather than `"hibernate"`.
  - Icon binding: `icon: modelData === "sleep" ? (Config.session.icons.sleep || "dark_mode") : Config.session.icons[modelData]`.
  - Order must be:
    ```qml
    readonly property list<string> buttonOrder: [
        "shutdown",
        "sleep",
        "profile",
        "reboot",
        "logout"
    ]
    ```
  - When upstream changes this file, **never** allow upstream's hibernate replacement to overwrite this.

---

### B. Missing Lockscreen Quick Session Controls (Shutdown, Reboot, Sleep)

* **Symptom:** Lockscreen only had password entry, time, and notifications; shutdown, reboot, and sleep buttons were completely absent, and content alignment was displaced.
* **Root Cause:** Upstream stripped the bottom session buttons and vertical spacers from `modules/lock/Center.qml`.
* **Fix & Preservation Rule:**
  - Keep the flex spacers before and after the center content:
    ```qml
    Item {
        Layout.fillHeight: true
        Layout.preferredHeight: 1
    }
    ```
  - Keep the session buttons `RowLayout` at the bottom of the center column:
    ```qml
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Tokens.spacing.large

        IconButton {
            icon: Config.session.icons.sleep || "dark_mode"
            tooltipText: "Sleep"
            onClicked: Actions.sleep()
        }

        IconButton {
            icon: Config.session.icons.reboot || "cached"
            tooltipText: "Restart"
            onClicked: Actions.reboot()
        }

        IconButton {
            icon: Config.session.icons.shutdown || "power_settings_new"
            tooltipText: "Shutdown"
            onClicked: Actions.shutdown()
        }
    }
    ```

---

### C. Disappearing Moon Icon (`dark_mode`)

* **Symptom:** The sleep button in both the session drawer and lockscreen rendered as a blank/empty circle with no icon.
* **Root Causes:**
  1. **Config property removed upstream:** Upstream removed `sleep` from `SessionIcons` in C++, so `Config.session.icons.sleep` returned `undefined`. In QML, `undefined` passed to `MaterialIcon` displays nothing.
  2. **Failed C++ plugin loading / Silent fallback to `/usr/lib`:** When `Config` C++ plugin was rebuilt, `libcaelestia-config.so` failed to load in Quickshell with:
     ```
     undefined symbol: _ZN9caelestia6config11ExtraConfig16staticMetaObjectE
     ```
     Qt silently fell back to loading an obsolete `/usr/lib/qt6/qml/Caelestia/lib/libcaelestia-config.so` (installed months earlier), which did not have `sleep` defined.
* **Fix & Preservation Rule:**
  - In `plugin/src/Caelestia/Config/sessionconfig.hpp`:
    ```cpp
    CONFIG_PROPERTY(QString, sleep, u"dark_mode"_s)
    ```
    and in `SessionCommands`:
    ```cpp
    CONFIG_PROPERTY(QStringList, sleep, { u"suspend"_s })
    ```
  - In `plugin/src/Caelestia/Config/extraconfig.hpp`:
    Ensure `#include "common.hpp"` is present at the top of the header so `CONFIG_NODE` is defined during AUTOMOC.
  - In `plugin/src/Caelestia/Config/CMakeLists.txt`:
    Ensure `extraconfig.hpp` is explicitly listed under `SOURCES`:
    ```cmake
    set(SOURCES
        # ...
        extraconfig.hpp
    )
    ```
  - In `shell.json`:
    Ensure `"session"` has:
    ```json
    "icons": {
        "sleep": "dark_mode",
        "shutdown": "power_settings_new",
        "reboot": "cached",
        "logout": "logout"
    }
    ```
  - In QML components (`Content.qml`, `Center.qml`):
    Always use fallback `Config.session.icons.sleep || "dark_mode"`.

---

### D. QML Import Path Priority in `scripts/launch-quickshell.sh`

* **Symptom:** Quickshell loads plugins from system paths (`/usr/lib/qt6/qml`) instead of the workspace build output (`$REPO/build/qml`).
* **Fix & Preservation Rule:**
  - `scripts/launch-quickshell.sh` must export:
    ```bash
    export QML2_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML2_IMPORT_PATH:-}"
    export QML_IMPORT_PATH="$SCRIPT_DIR/build/qml:${QML_IMPORT_PATH:-}"
    ```
  - This ensures the freshly compiled plugin in `build/qml` is always loaded first.

---

### E. Multiple Quickshell Instances / Ghost Daemons

* **Symptom:** Changes to QML or C++ seem to have no effect or icons don't update even after restarting the service or rebuilding.
* **Root Cause:** A detached `qs -c niri-caelestia-shell -d` was started manually while systemd user service `quickshell.service` was also active. The old instance kept holding Wayland layer surfaces.
* **Fix & Testing Rule:**
  - Before testing or restarting:
    ```bash
    killall -9 quickshell qs 2>/dev/null || true
    systemctl --user restart quickshell
    ```
  - Check active processes:
    ```bash
    pgrep -a quickshell
    ```
  - Check live logs:
    ```bash
    quickshell log -c niri-caelestia-shell
    ```

---

### F. Active Window Details Popup Broken / Not Opening (`modules/bar/popouts/ActiveWindow.qml`)

* **Symptom:** Clicking the active window info on the bar does not open the detail drawer (`modules/windowinfo/`) or renders an invisible / 0-width popout.
* **Root Cause:** Upstream replaced the Niri-native popout with a Hyprland ScreencopyView layout. Furthermore, the upstream layout had a `Column` containing an anchored `RowLayout` with `anchors.left: parent.left; anchors.right: parent.right`, which in Qt Quick breaks implicit width calculation and collapses the popup width to zero.
* **Fix & Preservation Rule:**
  - In `modules/bar/popouts/ActiveWindow.qml`, preserve the clean Niri layout:
    - Binds to `client: Niri.lastFocusedWindow`
    - Displays `root.client?.title` and `root.client?.app_id`
    - Wire chevron expand button to `root.popouts.detachRequested("winfo")`
  - Do NOT accept upstream Hyprland ScreencopyView or `Column` anchored layouts.

---

### G. Battery / Power Profile Popout Missing Auto-Balance Mode (`modules/bar/popouts/Battery.qml`)

* **Symptom:** Power profile switcher only displays Power Saver, Balanced, and Performance. The auto-balance profile option (`auto_mode` icon) is missing.
* **Root Cause:** Upstream `modules/bar/popouts/Battery.qml` hardcodes 3 profiles and lacks support for `services/PowerManagement.qml`.
* **Fix & Preservation Rule:**
  - Preserve `autoMode` profile button (`icon: "auto_mode"`, `isAuto: true`) in `modules/bar/popouts/Battery.qml`.
  - Connect clicks to `PowerManagement.setAutoBalance(true)` or `PowerManagement.setManualProfile(parent.profile)`.
  - Display dynamic profile label: `PowerManagement.autoBalance ? qsTr("Auto (%1)").arg(PowerManagement.profileName) : PowerManagement.profileName`.

---

### H. Launcher Not Auto-Typing `>wallpaper ` / `>clip ` on Super+W / Super+V (`modules/launcher/Content.qml`)

* **Symptom:** Pressing Super+W opens the launcher with an empty search bar (`""`) instead of automatically typing `>wallpaper ` to show wallpapers.
* **Root Cause:** In v2, `Content.qml` is loaded dynamically by `Loader` in `modules/launcher/Wrapper.qml`. When `wallpaper open` or `clipboard open` sets `screenState.wallpaperRequested = true` and `screenState.launcher = true`, the `Loader` instantiates `Content.qml` *after* those properties have already changed. The `Connections` handler only detects future property changes, not the initial state upon component creation.
* **Fix & Preservation Rule:**
  - In `modules/launcher/Content.qml`, add `checkLauncherState()` and call it on `Component.onCompleted: search.checkLauncherState()`.
  - Ensure `search.cursorPosition` is updated to the end of the text.
  - In `modules/launcher/ContentList.qml`, ensure `showWallpapers` check is case-insensitive: `search.text.toLowerCase().startsWith(...)`.
  - In `services/Wallpapers.qml`, implement `close()` and `toggle()` in addition to `open()`.

---

## 3. Rebase / Upstream Sync Checklist

When merging or cherry-picking from upstream `caelestia-dots/shell`:

1. **Before Running Merge / Port:**
   - Note the current `HEAD` commit.
2. **Review Diff of Shared Files:**
   - If using `scripts/port-upstream.sh <from> <to>`, inspect `modules/session/Content.qml`, `modules/lock/Center.qml`, `modules/bar/popouts/ActiveWindow.qml`, `modules/bar/popouts/Battery.qml`, `plugin/src/Caelestia/Config/sessionconfig.hpp`, and `shell.json`.
3. **If Upstream Changes These Files:**
   - **`modules/session/Content.qml`**: Reject any change replacing `sleep` with `hibernate`.
   - **`modules/lock/Center.qml`**: Preserve the bottom session buttons (`RowLayout` with `IconButton` for sleep, reboot, shutdown) and flex spacers.
   - **`modules/bar/popouts/ActiveWindow.qml`**: Preserve Niri active window title/app_id and chevron button requesting `"winfo"`. Reject Hyprland ScreencopyView.
   - **`modules/bar/popouts/Battery.qml`**: Preserve 4th profile `auto_mode` button and `services/PowerManagement.qml` integration.
   - **`plugin/src/Caelestia/Config/sessionconfig.hpp`**: Ensure `sleep` remains in `SessionIcons` and `SessionCommands`.
   - **`plugin/src/Caelestia/Config/extraconfig.hpp` & `CMakeLists.txt`**: Ensure `#include "common.hpp"` and `extraconfig.hpp` in `SOURCES` are intact.
   - **`scripts/launch-quickshell.sh`**: Ensure `QML2_IMPORT_PATH` and `QML_IMPORT_PATH` exports remain.
   - **`services/NetworkUsage.qml`**: Ensure `import Caelestia` remains.
4. **Rebuild C++ Plugin:**
   ```bash
   cmake --build build
   ```
5. **Restart and Verify:**
   ```bash
   killall -9 quickshell qs 2>/dev/null || true
   systemctl --user restart quickshell
   ```
   - Press `Ctrl+Alt+Delete` and verify the moon icon and Sleep button appear and work.
   - Lock the screen (Super+Escape or lock command) and verify the Sleep, Restart, and Shutdown buttons appear at the bottom of the screen.
   - Click active window on the bar, verify popout appears with app icon and title, and chevron button opens the windowinfo detail drawer.
   - Click the battery icon on the bar, verify all 4 power profiles (Saver, Balanced, Performance, Auto) appear and switching works.
   - Run `./scripts/verify-deltas.sh` to confirm 11/11 automated checks pass.

---

## 4. Automated Protection & Verification Tooling

To ensure customizations are never silently lost during future upstream pulls or rebases, the following automated tools are configured:

1. **`scripts/verify-deltas.sh`**:
   - Programmatically tests all 11 protected features across QML, C++, and config files.
   - Exits with return code 1 if any protected feature or file has been overwritten or removed.
   - Can be run at any time via:
     ```bash
     ./scripts/verify-deltas.sh
     ```

2. **`.pi/protected-files.txt`**:
   - Central manifest of files that must never be overwritten by upstream changes.
   - Referenced by `scripts/port-upstream.sh` to automatically exclude these files from patch generation and application.

3. **`scripts/port-upstream.sh`**:
   - Uses `:(exclude)` / `:!` pathspecs generated from `.pi/protected-files.txt` to prevent upstream diffs from touching protected files.
   - Automatically executes `verify-deltas.sh` after applying patches with `--apply`.

4. **Git Hooks (`scripts/install-hooks.sh`)**:
   - **`pre-commit`**: Prevents committing any change that breaks or deletes a protected delta.
   - **`post-merge`**: Alerts the user/agent immediately if a git merge introduced a regression to protected deltas.
   - Reinstall hooks at any time via:
     ```bash
     ./scripts/install-hooks.sh
     ```

---

## 5. Display Sanity & Upstream v2.5.0 Architecture

### A. Display Sanity & Black Screen Boot Prevention
* **Systemd Pre-Start Drop-in:** `~/.config/systemd/user/niri.service.d/display-sanity.conf` executes `ExecStartPre=/usr/bin/python3 ~/.config/niri/niri-display.py --sanity-check` before Niri launches.
* **Guarantee:** If no external monitor is attached and `output.kdl` has `eDP-1` turned off, the sanity check rewrites `output.kdl` with `output "eDP-1" { scale 1.0 }`, preventing a black screen on standalone boot.
* **Socket Auto-Discovery:** `niri-display-monitor.py` implements socket auto-discovery across `$XDG_RUNTIME_DIR/niri*.sock` and `/run/user/<uid>/niri*.sock` if `$NIRI_SOCKET` is not exported into user session environment.

### B. Upstream v2.5.0 Framework Alignment
* **Strict Qt 6.8+ `QChar` Comparison:** In `plugin/src/Caelestia/Internal/niriipc.cpp`, character comparisons must use `c == QLatin1Char('-')` or `c == u'-'` to satisfy strict Qt 6.8+ typing.
* **`m3shapes` System Package Separation:** Root `CMakeLists.txt` must not declare `m3shapes` in `ENABLE_MODULES`. The system package `qt6-m3shapes-git` provides `/usr/lib/qt6/qml/M3Shapes/`.
* **`Caelestia.I18n` Translation Engine:** Upstream migrated UI strings and byte formats to `Tr.tr()`, `Tr.trCtx()`, and `Units.formatBytes()`. Custom panels adhere to `Tr.tr()` instead of legacy `qsTr()`.
* **Typed `ListNode` Properties:** `services/VPN.qml` retains OpenVPN and NMCLI adapters alongside `selectAndConnect()` while adopting upstream's type-safe `GlobalConfig.utilities.vpn.provider` `ListNode` API.

### C. Dynamic Output Toggling via Runtime IPC
* **Symptom:** Quickshell trapped in a 2-second crash/restart loop when clamshell mode or display switching is triggered.
* **Root Cause:** Niri's `load-config-file` action does not turn off outputs that are already logically mapped. Display switching scripts (`niri-display.py`) must issue explicit IPC calls (`niri msg output <name> off` / `on`). Without this, `outputs[name].logical` persists, causing `niri-display-monitor.py` to continuously re-trigger `niri-display.py external`, repeatedly sending `SIGKILL` to Quickshell via the display change crash guard.
* **Fix & Guarantee:**
  - `niri-display.py` calls `niri msg output {internal} off` when switching to external-only mode, `niri msg output {external} off` when switching to internal-only mode, and `on` for both when extending/mirroring.
  - Early-return checks in `niri-display.py` verify that `outputs[name].logical` matches the desired layout before initiating surface teardown and Quickshell termination.
  - `niri-display-monitor.py` invokes `niri msg output {internal_name} off` directly as a fallback defense-in-depth measure.

### D. High-Frequency Viewport Scroll Throttling & IPC Event Stream Buffer Safeguard
* **Symptom:** Switching windows causes window icons in the workspace bar (left sidebar) to turn invisible and reappear after a ~5s delay. Niri logs `WARN niri::ipc::server: disconnecting IPC event stream client because it is reading events too slowly`.
* **Root Cause:** During window switching and scrolling navigation, Niri emits continuous `WindowLayoutsChanged` events at high display refresh rates (60–144Hz) to animate viewport offsets (`tile_pos_in_workspace_view`). Previously, `NiriIpc::handleWindowLayoutsChanged` ran `sortWindowsList()`, `m_windowsModel->resetData()`, and `emit windowsChanged()` for every single frame event. This triggered hundreds of complete model resets and delegate recreations in QML per second, completely saturating the Qt GUI thread. The Unix domain socket buffer overflowed, causing Niri's bounded internal channel (size 64) to fill up and forcibly disconnect Quickshell. Quickshell's exponential reconnect timer then took several seconds before reconnecting and fetching initial state.
* **Fix & Guarantee:**
  - In `plugin/src/Caelestia/Internal/niriipc.cpp` (`handleWindowLayoutsChanged`), compare `pos_in_scrolling_layout` and `window_size`. If only viewport scroll offsets (`tile_pos_in_workspace_view`) changed, early-return immediately without sorting or emitting `windowsChanged()`. Model sorting and `windowsChanged` emissions are only executed when genuine structural or size changes occur.
  - In `plugin/src/Caelestia/Internal/nirisocket.cpp` (`onConnected`), set `SO_RCVBUF` to 1MB (`1024 * 1024`) via `setsockopt` to provide headroom against burst events.
  - In `plugin/src/Caelestia/Internal/nirisocket.cpp` (`scheduleReconnect`), cap the maximum reconnect delay to 5000ms.

---

## 6. Nexus Plugins Page (Manga / Novel Readers)

### A. Readers Exposed as Enable/Disable Plugins
* **Location:** `modules/nexus/pages/PluginsPage.qml` plus the reusable `modules/nexus/common/PluginRow.qml`, registered in `modules/nexus/PageCompRegistry.qml` (System → Plugins).
* **Behaviour:**
  - Each reader (Manga, Novel) is a plugin card with icon, description, `Enabled`/`Disabled` status, an **open** button, and an enable/disable switch bound to `GlobalConfig.extra.manga` / `GlobalConfig.extra.novel`.
  - Disabling a reader persists `false` into `shell.json` (`extra.*`), closes the reader drawer on **every** screen (all `Visibilities.screens` entries, not just the active one), and fires the `Connections` on `GlobalConfig.extra` in `services/Manga.qml` / `services/Novel.qml`, which stops the local Python backend immediately.
  - Re-enabling restores everything; nothing is deleted. The draw opening is re-checked against `GlobalConfig.extra.*` by the `mangaReader` / `novelReader` IPC handlers in `modules/Shortcuts.qml`.
* **Set-from-QML contract:** `SETTINGS_PROPERTY` in `plugin/src/Caelestia/Settings/macros.hpp` expands to `Q_PROPERTY(... READ ... WRITE set_<name> NOTIFY <name>Changed)`, so `GlobalConfig.extra.manga = false` from QML notifies and persists.

### B. Merge Hazard: Plugins Entry Reverts to “Page under construction”
* **Symptom:** System → **Plugins** in Nexus shows the `PlaceholderComp` “Page under construction” text even though `modules/nexus/pages/PluginsPage.qml` exists and contains the reader toggles.
* **Root Cause:** The upstream `PageCompRegistry.qml` merge for v2.5.0 (commit `140d25a8`) silently reverted our second `// System` entry from `StackPage { PluginsPage {} }` back to `PlaceholderComp {}` without raising a conflict. The page file survived, so nothing looked broken until the page was opened.
* **Fix & Guarantee:** Keep the System → Plugins entry wired as `StackPage { Component { PluginsPage {} } }`. `scripts/verify-deltas.sh` check **#12** asserts both the registration and the `GlobalConfig.extra.manga` / `.novel` bindings, so the pre-commit / post-merge hooks catch any future regression.

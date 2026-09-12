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
   - Run `./scripts/verify-deltas.sh` to confirm 10/10 automated checks pass.

---

## 4. Automated Protection & Verification Tooling

To ensure customizations are never silently lost during future upstream pulls or rebases, the following automated tools are configured:

1. **`scripts/verify-deltas.sh`**:
   - Programmatically tests all 10 protected features across QML, C++, and config files.
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



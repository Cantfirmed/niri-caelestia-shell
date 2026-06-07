# Niri-Caelestia Shell: Developer Guide

This developer guide provides a quick reference for writing, modifying, and debugging the Quickshell and Niri components in this repository.

---

## 🏗️ Core Architecture

This shell is built using [Quickshell](https://quickshell.pw/), a Wayland shell scripting system using QML and JavaScript.

```
niri-caelestia-shell/
├── shell.qml                 # Root shell component & singleton service instantiations
├── config/                   # Configuration schemas & main Config.qml singleton
├── services/                 # Singleton system services (Battery, Brightness, Niri, LidInhibitor)
├── components/               # Glassmorphic controls, layouts, and panels
└── modules/                  # Main UI panes (Control Center, App Launcher, Dashboard, Bar)
```

### 1. Root Shell Setup (`shell.qml`)
Any service that needs to run continuously in the background (like inhibitors, notification listeners, battery checkers) must be registered in the root shell context as a property:
```qml
// shell.qml
ShellRoot {
    ...
    property var _myBackgroundService: MyService
}
```

### 2. Configuration System (`config/`)
All settings are stored in `~/.config/quickshell/niri-caelestia-shell/shell.json`.
* **Adding a Setting**:
  1. Add the property to the corresponding sub-config sheet (e.g., `config/SessionConfig.qml`).
  2. Map and serialize the property in the main `config/Config.qml` singleton serialize methods (e.g. `serializeSession()`).
* **Saving Settings**:
  UI panes should set the property directly in QML and call `Config.markDirty("sectionName")`. Config will debounce and serialize it back to `shell.json` automatically:
  ```qml
  Config.session.myProperty = value;
  Config.markDirty("session");
  ```

---

## 🎨 UI & Styling Guidelines (Quickshell QML)

### 1. Do Not Use Raw QtQuick Controls Directly
The shell uses a custom glassmorphic theme. Avoid using standard types like `Button`, `TextField`, or `Text` unless wrapping them. Instead, import and use the custom controls:
* **Custom Imports**:
  ```qml
  import qs.components
  import qs.components.controls
  import qs.components.effects
  ```
* **Pre-styled Equivalents**:
  * `StyledText` instead of `Text`.
  * `TextButton` or `IconButton` instead of `Button`.
  * `StyledFlickable` instead of `Flickable`.
  * `SwitchRow` or `StyledRadioButton` instead of raw checkboxes/radios.
  * Use design variables from the `Appearance` singleton (e.g. `Appearance.padding.md`, `Appearance.spacing.lg`, `Appearance.font.size.bodyMedium`).

### 2. Standard Buttons Gotcha
Using a raw `Button` without `import QtQuick.Controls` causes compilation errors such as `Button is not a type`, rendering the parent page completely blank. Always prefer `TextButton` or `IconButton`.

### 3. Loader & Destruction Gotcha (Segmentation Faults)
When displays/outputs disconnect and reconnect (such as during sleep/wake or monitor hotplugging events), Quickshell destroys and recreates the shell windows and their child elements.
If a `Loader` has its `active` property bound directly or indirectly to transient window manager states (like `Niri.wsContextType` or `Niri.focusedWorkspaceIndex`), and a state update occurs while the parent element is being torn down, QML will attempt to evaluate the binding and unload the Loader. This can trigger a `Segmentation fault (11)` in Qt's item parenting code (`QQuickItemPrivate::dirty()`).

**Prevention**:
Use the custom `SafeLoader` component (from `qs.components`) instead of a raw `Loader` for any dynamic/toggled loading that depends on transient window manager states.
`SafeLoader` internally wraps `Loader`, tracks its own destruction lifecycle state, and uses a destruction-guarded `Binding` element to set `active` safely.

**Usage**:
```qml
import qs.components

SafeLoader {
    id: myLoader
    activeState: someCondition // Use activeState instead of active!
    sourceComponent: myComponent
}
```

---


## 🎛️ Niri Window Manager Integration

The shell communicates with Niri using a custom C++ IPC wrapper exposed through the `Niri` singleton.

### 1. Niri Service (`services/Niri.qml`)
* **Properties**:
  * `Niri.outputs`: Key-value map of current displays (`eDP-1`, `HDMI-A-1`, etc.).
  * `Niri.focusedMonitorName`: Currently active display name.
  * `Niri.windows`: Active window list.
* **Executing Actions**:
  To trigger a window manager layout action, run:
  ```javascript
  Niri.action("action-name", [args]);
  ```
  Example: `Niri.action("focus-workspace", ["1"])`.

---

## 💻 Spawning Subprocesses (Process Component)

To invoke background tasks or system blockers (like `systemd-inhibit` or custom scripts), use Quickshell's `Process` component:
```qml
Process {
    running: condition
    command: ["my-command", "--arg1", "val"]
}
```
* **Process Lifecycle**: The lifetime of the spawned command is bound to the containing context. If Quickshell exits or reloads, all child processes spawned this way are cleanly killed.

---

## 🛠️ Development & Debugging Flow

### 1. Quickshell Logs
Quickshell logs all QML errors, component warnings, and prints to a standard user-level log file:
* Log Location: `/run/user/1000/quickshell/by-id/<shell-id>/log.qslog`
* You can check the current running log path using:
  ```bash
  ps aux | grep quickshell
  ```
  Or read logs dynamically:
  ```bash
  quickshell log -c niri-caelestia-shell
  ```

### 2. Reloading the Shell
To restart or hot-reload configurations while testing:
* **Reload**:
  ```bash
  quickshell reload -c niri-caelestia-shell
  ```
* **Full Restart**:
  ```bash
  quickshell kill -c niri-caelestia-shell && quickshell -c niri-caelestia-shell -d
  ```

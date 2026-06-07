# Laptop Lid Behavior Customization

This feature allows users to customize the behavior of their laptop when the lid is closed. In particular, it supports preventing the laptop from entering suspend/sleep mode when an external monitor is connected (frequently referred to as "docked mode" or "clamshell mode") or always ignoring the lid close switch.

## Feature Modes

The configuration supports three states under `session.lidBehavior`:
1. **Suspend (`"suspend"`)**: The default behavior. Closing the lid allows systemd/logind to handle the lid switch (typically suspending the laptop).
2. **Ignore when external monitor is connected (`"ignoreExternal"`)**: Inhibits the lid switch ONLY when at least one external monitor is connected to the laptop.
3. **Always ignore (`"ignore"`)**: Inhibits the lid switch regardless of connected monitors.

---

## Architecture & Code Structure

The implementation spans the following components:

### 1. Configuration & Serialization
* **[config/SessionConfig.qml](file:///home/patrick/.config/quickshell/niri-caelestia-shell/config/SessionConfig.qml)**:
  Defines `property string lidBehavior: "suspend"` inside the session configuration schema.
* **[config/Config.qml](file:///home/patrick/.config/quickshell/niri-caelestia-shell/config/Config.qml)**:
  Serializes `lidBehavior` inside the `serializeSession()` method to save selection choices persistently to `~/.config/quickshell/niri-caelestia-shell/shell.json`.

### 2. Inhibitor Service
* **[services/LidInhibitor.qml](file:///home/patrick/.config/quickshell/niri-caelestia-shell/services/LidInhibitor.qml)**:
  A singleton background service that dynamically manages the systemd inhibitor process.
  * **Display Detection**: Uses `Niri.outputs` to check for external monitors. It classifies internal display panels by identifying connectors starting with `eDP`, `LVDS`, or `DSI` (case-insensitive). Any connector not matching these prefixes is classified as an external monitor.
  * **Inhibition Mechanism**: Utilizes the Quickshell `Process` component to execute:
    ```bash
    systemd-inhibit --what=handle-lid-switch --who=caelestia-shell --why="Lid close setting active" --mode=block sleep inf
    ```
    The `Process` component automatically ties the lifecycle of the child process to Quickshell. If Quickshell exits, reloads, or the `Process.running` property changes to `false`, the inhibitor is cleanly terminated.
* **[shell.qml](file:///home/patrick/.config/quickshell/niri-caelestia-shell/shell.qml)**:
  Instantiates the singleton service:
  ```qml
  property var _lidInhibitor: LidInhibitor
  ```

### 3. User Interface
* **[modules/controlcenter/session/SessionPane.qml](file:///home/patrick/.config/quickshell/niri-caelestia-shell/modules/controlcenter/session/SessionPane.qml)**:
  Contains the settings panel interface. Implements the radio buttons using `StyledRadioButton` and `ButtonGroup` to choose between **Suspend**, **Ignore when external monitor is connected**, and **Always ignore (docked mode)**. Changing the selection triggers `saveConfig()`, which marks the session configuration as dirty and serializes the new state.

---

## Troubleshooting & Verification

### 1. Check Active Inhibitors
To verify if `caelestia-shell` has successfully inhibited the lid close switch:
```bash
systemd-inhibit --list --no-pager
```
* **Expected Output when Inhibited**:
  ```
  WHO             UID  USER    PID   COMM            WHAT              WHY   MODE
  caelestia-shell 1000 patrick 40864 systemd-inhibit handle-lid-switch Lid … block
  ```

### 2. Check Niri Outputs
To see the names of current display connectors as reported by Niri (which the inhibitor uses to determine if an external monitor is connected):
```bash
niri msg outputs
```
* Look for names like `HDMI-A-1`, `DP-1`, etc. (which trigger the external monitor condition) vs. `eDP-1` (which matches the internal panel criteria).

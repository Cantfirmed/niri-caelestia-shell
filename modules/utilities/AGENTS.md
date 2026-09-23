# Utilities Drawer — Developer & Agent Guide

The **Utilities Drawer** (`modules/utilities/`) is a bottom-right panel housing quick system controls, hardware toggles, screen recording, and service cards (VPN, Keep Awake). It can appear standalone (Super+N / edge hover) or attached to the bottom of the notification `sidebar` (Super+Shift+N).

---

## 1. Directory Structure

| File / Directory | Purpose |
|------------------|---------|
| `Wrapper.qml` | Outer drawer container, screen-relative positioning, attach animation to `sidebar`, `offsetScale` animation, layer-shell integration. |
| `Content.qml` | Main card stack (`ColumnLayout`). Dynamically loads cards via `Loader` based on config toggles and calculates `nonAnimHeight`. |
| `Background.qml` | Styled glassmorphic backing for the utilities drawer. |
| `cards/` | Individual card components loaded by `Content.qml`. |
| `cards/Toggles.qml` | Grid of quick toggle buttons (WiFi, Bluetooth, Mic, Settings, GameMode, DND, VPN). |
| `cards/IdleInhibit.qml` | Keep-awake toggle with sleep timer options. |
| `cards/Record.qml` | Screen recording controls (fullscreen / window / region, audio source, quality). |
| `cards/Vpn.qml` | VPN status card, connect/disconnect button, and provider dropdown switcher. |
| `cards/RecordingList.qml`| Saved recordings browser and player. |
| `toasts/` | Toast notification manager attached above the utilities drawer. |

---

## 2. Adding a Quick Toggle Button

Quick toggles live inside `cards/Toggles.qml`. They appear in the horizontal/flow grid of circular icon buttons.

### Step 1: Add Configuration Entry
In `plugin/src/Caelestia/Config/utilitiesconfig.hpp`, ensure your toggle ID is registered in `quickToggles`:
```cpp
CONFIG_LIST(EntryList, quickToggles,
    DEFAULT_ARG({
        LIST_ENTRY(wifi, true),
        LIST_ENTRY(bluetooth, true),
        LIST_ENTRY(mic, true),
        LIST_ENTRY(settings, true),
        LIST_ENTRY(gameMode, true),
        LIST_ENTRY(dnd, true),
        LIST_ENTRY(vpn, false),
        LIST_ENTRY(myFeature, true), // <-- Add your toggle here
    }))
```
Rebuild the plugin if adding to C++ defaults, or define it in `shell.json` under `"utilities": { "quickToggles": [ ... ] }`.

### Step 2: Implement the Button in `cards/Toggles.qml`
Add your button mapping to the `toggleMap` in `cards/Toggles.qml`:
```qml
myFeature: {
    name: "My Feature",
    icon: MyService.enabled ? "feature_on_icon" : "feature_off_icon",
    active: MyService.enabled,
    action: () => MyService.toggle(),
    secondaryAction: () => {
        // Optional right-click or long-press action (e.g. open settings)
        root.popouts.open("mySettingsPopout");
    }
}
```

---

## 3. Adding a New Full Card

Cards are modular components stacked vertically inside `Content.qml`.

### Step 1: Create `modules/utilities/cards/MyCard.qml`
```qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Caelestia
import qs.components

StyledRect {
    id: root
    readonly property real nonAnimHeight: implicitHeight
    implicitWidth: parent.width
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        // Card content here (headers, toggles, sliders)
    }
}
```

### Step 2: Register Config Toggle in `plugin/src/Caelestia/Config/utilitiesconfig.hpp`
Add a boolean property to `UtilitiesCards`:
```cpp
class UtilitiesCards : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesCards, settings::ObjectNode)

    CONFIG_PROPERTY(bool, keepAwake, true)
    CONFIG_PROPERTY(bool, recorder, true)
    CONFIG_PROPERTY(bool, quickToggles, true)
    CONFIG_PROPERTY(bool, vpn, true)
    CONFIG_PROPERTY(bool, myCard, true) // <-- Add here
};
```

### Step 3: Instantiate in `modules/utilities/Content.qml`
1. Add a `Loader` in `ColumnLayout`:
```qml
Loader {
    id: myCardLoader
    Layout.fillWidth: true
    active: GlobalConfig.utilities.cards?.myCard ?? true
    visible: active

    sourceComponent: MyCard {
        objectName: "utilitiesMyCard"
        screenState: root.screenState
    }
}
```
2. Update `enabledCards` and `nonAnimHeight` in `Content.qml`:
```qml
readonly property int enabledCards: (idleInhibit.active ? 1 : 0) + (record.active ? 1 : 0) + (vpnCard.active ? 1 : 0) + (toggles.active ? 1 : 0) + (myCardLoader.active ? 1 : 0)
readonly property real nonAnimHeight: ((idleInhibit.item as IdleInhibit)?.nonAnimHeight ?? 0)
    + ((record.item as Record)?.nonAnimHeight ?? 0)
    + ((vpnCard.item as Vpn)?.nonAnimHeight ?? 0)
    + ((toggles.item as Toggles)?.implicitHeight ?? 0)
    + ((myCardLoader.item as MyCard)?.nonAnimHeight ?? 0)
    + layout.spacing * Math.max(0, enabledCards - 1)
```

### Step 4: Add Nexus Settings Toggle (Optional)
Expose the toggle switch in `modules/nexus/pages/panels/UtilitiesPanel.qml` under the Cards section so users can enable/disable it graphically.

---

## 4. Hover & Shortcut Interaction Invariants

When working with utilities drawer behavior, you MUST adhere to these rules in `modules/drawers/Interactions.qml` and `modules/Shortcuts.qml`:

1. **Hover Detection (`inBottomPanel`)**:
   - Hover hit-testing is defined in `inBottomPanel(panels.utilities, x, y, true)`.
   - When inactive (`!panel.shouldBeActive`), `panelHeight` evaluates to `0`, restricting the open trigger strictly to the bottom edge/corner of the screen (`y > height - border - rounding`).
   - While open (`panel.shouldBeActive == true`), `panelHeight` evaluates to full height so the cursor can interact anywhere inside the drawer.
2. **Never Clear `utilitiesShortcutActive` on Hover**:
   - Because Utilities is an interactive panel with buttons and sliders, moving the mouse over the panel must **never** set `utilitiesShortcutActive = false`.
   - Doing so would switch the panel to hover mode and prevent keyboard shortcuts (`Super+N`) from closing it.
3. **Hover Retrigger Blocking (`utilitiesHoverBlocked`)**:
   - When closed via shortcut or IPC, if the mouse is still inside the panel hit zone, `utilitiesHoverBlocked` is set to `true`.
   - This prevents the cursor from immediately snapping the panel back open until the cursor exits the zone.
4. **Sidebar Isolation**:
   - In `Interactions.qml`, `showUtilities` is guarded by `!screenState.sidebar`. Hovering over utilities when attached to the sidebar must never set `screenState.utilities = true`.
5. **Coupled Dismissal**:
   - Toggling or closing `utilities` in `Shortcuts.qml` must reset **both** `screenState.utilities = false` and `screenState.sidebar = false` if either is active.

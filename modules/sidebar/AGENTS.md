# Sidebar Drawer (NotifDock) — Developer & Agent Guide

The **Sidebar** (`modules/sidebar/`) is the right-edge drawer housing the notification dock (NotifDock). It manages incoming notifications grouped by application, inline action triggers, and clearance controls. It also anchors the `utilities` drawer to its bottom edge when active.

---

## 1. Directory Structure

| File | Purpose |
|------|---------|
| `Wrapper.qml` | Outer layer-shell drawer container, width sizing (`Tokens.sizes.sidebar.width`), right slide animation (`offsetScale`). |
| `Content.qml` | Layout wrapping `NotifDock` inside a styled card container. |
| `NotifDock.qml` | Notification manager surface: header (count, title, action buttons), empty state art, scrollable list, and floating clear button. |
| `NotifGroupList.qml` | List of application notification groups. |
| `NotifGroup.qml` | Per-application collapsible group container with header, app icon, and action triggers. |
| `Notif.qml` | Individual notification item card with app name, summary, body, and timestamp. |
| `NotifActionList.qml` | Notification action buttons (Reply, Mark as Read, custom app actions). |
| `Props.qml` | State holder for sidebar properties. |

---

## 2. Adding Buttons & Controls to the Sidebar

### Adding Header Action Buttons (e.g. DND Toggle, Settings)
The header in `modules/sidebar/NotifDock.qml` currently displays notification count and title:
```qml
Item {
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    // ...
}
```

To add buttons (such as a DND toggle or Clear button) in the header:
1. Place a `RowLayout` anchored to `title.right`:
```qml
RowLayout {
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    spacing: Tokens.spacing.small

    IconButton {
        icon: Notifs.dnd ? "notifications_off" : "notifications"
        font: Tokens.font.icon.medium
        onClicked: Notifs.dnd = !Notifs.dnd
        // Style with Tokens and Colours
    }
}
```
2. Adjust `titleText.anchors.right` to anchor to your button row's left instead of `parent.right` to prevent text overlap.

### Adding New Sections to `Content.qml`
If adding persistent widgets to the sidebar (e.g. mini calendar, status widget):
1. Open `modules/sidebar/Content.qml`.
2. Add your component to the `ColumnLayout` above or below the `StyledRect` containing `NotifDock`.
3. Set `Layout.fillWidth: true` and appropriate height constraints.

---

## 3. Hover Detection & Configuration

Hover-to-reveal for the sidebar is implemented in `modules/drawers/Interactions.qml` and configured in `shell.json`.

### How Hover Works
In `modules/drawers/Interactions.qml` (lines 186-196):
- **Trigger Zone**: Top-right screen edge below the notifications popup area, bounded by `minHoverThreshold`:
  ```qml
  const sidebarTriggerY = Math.max(Config.sidebar.minHoverThreshold, panels.notifications.y + panels.notifications.height + borderThickness);
  const showSidebarHover = x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x) && y <= sidebarTriggerY;
  ```
- **Exit Zone**: When the cursor exits `inRightPanel(panels.sidebar, x, y)` and `inRightPanel(panels.sessionWrapper, x, y)`, `screenState.sidebar` is set to `false`.

### Enabling Hover
By default, sidebar hover is **disabled** (`showOnHover: false`).
To enable hover detection for the sidebar:
1. In `shell.json`, add/set:
   ```json
   "sidebar": {
     "showOnHover": true,
     "minHoverThreshold": 200,
     "dragThreshold": 80
   }
   ```
2. C++ config class: `plugin/src/Caelestia/Config/sidebarconfig.hpp`.

---

## 4. Compound Drawer Coupling with Utilities

The sidebar and utilities drawer share an attached layout:
- In `modules/drawers/Panels.qml`:
  ```qml
  Sidebar.Wrapper {
      id: sidebar
      anchors.top: notifications.bottom
      anchors.bottom: utilities.top
      anchors.right: parent.right
  }
  ```
- In `modules/utilities/Wrapper.qml`:
  ```qml
  readonly property bool shouldBeActive: screenState.sidebar || (screenState.utilities && Config.utilities.enabled ...)
  ```
  When `screenState.sidebar` is `true`, `utilities` automatically activates and animates attached to the bottom of the sidebar.

### Critical Invariants
1. **Synchronized Close**: In `modules/Shortcuts.qml`, toggling or closing either `sidebar` (`Super+Shift+N`) or `utilities` (`Super+N`) when either is active MUST clear **both** `screenState.sidebar = false` and `screenState.utilities = false`.
2. **Hover Isolation**: In `modules/drawers/Interactions.qml`, `showUtilities` is guarded by `!screenState.sidebar` so moving the cursor over the attached utilities panel never leaks `screenState.utilities = true`.

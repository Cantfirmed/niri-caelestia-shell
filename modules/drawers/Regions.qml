pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property real borderThickness: win.contentItem.Config.border.thickness
    readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness
    readonly property real maskBorderThickness: win.dragMaskPadding > 0 ? borderThickness : 0
    readonly property real maskClampedThickness: win.dragMaskPadding > 0 ? clampedThickness : 0

    readonly property real topOffset: Math.max(win.dragMaskPadding, (win.contentItem.Config.dashboard && win.contentItem.Config.dashboard.enabled && win.contentItem.Config.dashboard.showOnHover) ? clampedThickness : 0)
    readonly property real bottomOffset: Math.max(win.dragMaskPadding, (win.contentItem.Config.launcher && win.contentItem.Config.launcher.enabled && win.contentItem.Config.launcher.showOnHover) ? clampedThickness : 0, (win.contentItem.Config.utilities && win.contentItem.Config.utilities.enabled) ? clampedThickness : 0)
    readonly property real rightOffset: Math.max(win.dragMaskPadding, (win.contentItem.Config.osd && win.contentItem.Config.osd.enabled) ? clampedThickness : 0)

    x: bar.clampedWidth + win.dragMaskPadding
    y: maskBorderThickness + topOffset
    width: win.width - bar.clampedWidth - maskBorderThickness - win.dragMaskPadding - rightOffset
    height: win.height - maskBorderThickness * 2 - topOffset - bottomOffset
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: 0
        height: panel.height * (1 - root.panels.dashboard.offsetScale) + root.maskClampedThickness
    }

    R {
        panel: root.panels.launcher
        y: root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.maskClampedThickness
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.session.offsetScale) + root.maskClampedThickness + sidebarRegion.width
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.win.width - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + root.maskClampedThickness
    }

    R {
        panel: root.panels.osdWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + root.maskClampedThickness + sessionRegion.width
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.maskClampedThickness
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.maskClampedThickness
    }

    R {
        panel: root.panels.popoutsWrapper
        width: panel.width * (1 - root.panels.popoutsWrapper.offsetScale)
    }

    R {
        panel: root.panels.manga
    }

    R {
        panel: root.panels.novel
    }

    R {
        panel: root.panels.displayselect
        width: panel.visible ? panel.width : 0
        height: panel.visible ? panel.height : 0
    }

    R {
        panel: root.panels.soundpanel
        width: panel.visible ? panel.width : 0
        height: panel.visible ? panel.height : 0
    }

    // Right-side corner preservation — always punch through the Xor'd region
    // at the top-right and bottom-right corners so the SDF border's rounded
    // corners remain visible even when maskBorderThickness is 0 (i.e. when
    // app windows are present and the right-edge border strip is hidden).
    // Child regions use parent-relative coordinates, so we offset to account
    // for the parent XOR's position in window space.
    readonly property real _cornerSize: root.win.contentItem.Config.border.rounding
    // Inset the right side of each corner region by borderThickness so the
    // mask does not expose the opaque 5px SDF frame strip (which would
    // overlay app-window content). Only the transparent interior is shown.
    Region {
        x: root.width - _cornerSize
        y: -root.y
        width: _cornerSize - root.borderThickness
        height: _cornerSize
        intersection: Intersection.Subtract
    }
    Region {
        x: root.width - _cornerSize
        y: root.height - _cornerSize
        width: _cornerSize - root.borderThickness
        height: _cornerSize
        intersection: Intersection.Subtract
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.bar.implicitWidth
        y: panel.y + root.borderThickness
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}

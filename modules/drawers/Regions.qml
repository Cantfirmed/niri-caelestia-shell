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
    readonly property real bottomOffset: Math.max(win.dragMaskPadding, (win.contentItem.Config.launcher && win.contentItem.Config.launcher.enabled && win.contentItem.Config.launcher.showOnHover) ? clampedThickness : 0)

    x: bar.clampedWidth + win.dragMaskPadding
    y: maskBorderThickness + topOffset
    width: win.width - bar.clampedWidth - maskBorderThickness - win.dragMaskPadding * 2
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
        panel: root.panels.quicktoggles
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

    component R: Region {
        required property Item panel

        x: panel.x + root.bar.implicitWidth
        y: panel.y + root.borderThickness
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}

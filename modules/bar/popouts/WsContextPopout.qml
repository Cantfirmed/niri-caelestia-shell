pragma ComponentBehavior: Bound

import qs.services
import Caelestia.Config
import QtQuick

Item {
    id: root

    // Constants
    readonly property Item anchorWs: Niri.wsContextAnchor
    readonly property int anchorWsCount: {
        if (Niri.wsContextType === "workspace" || Niri.wsContextType === "workspaces")
            return 1;
        // For item context, check if anchor has wsWindowCount (WindowIcon) or use 1
        return anchorWs?.wsWindowCount ?? anchorWs?.windowCount ?? 1;
    }
    readonly property real itemH: anchorWs ? (anchorWs.height + Config.bar.workspaces.windowIconGap * 2) : (Tokens.sizes.bar.innerWidth - Appearance.padding.xs * 2)
    readonly property real expandedW: Config.bar.workspaces.windowContextWidth - (Tokens.sizes.bar.innerWidth - Appearance.padding.xs * 2)

    implicitHeight: anchorWs ? ((itemH + Appearance.padding.xs) * anchorWsCount) : itemH - Appearance.padding.md
    implicitWidth: root.expandedW
}

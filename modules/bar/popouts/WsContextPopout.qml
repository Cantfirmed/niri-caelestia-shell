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
    readonly property int scaledGap: Math.round((Config.bar.workspaces.windowIconGap ?? 5) * Tokens.uiScale)
    readonly property int scaledContextWidth: Math.round((Config.bar.workspaces.windowContextWidth ?? 250) * Tokens.uiScale)
    readonly property int cellWidth: Math.max(1, Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2)
    readonly property real itemH: anchorWs ? (anchorWs.height + scaledGap * 2) : cellWidth
    readonly property real expandedW: Math.max(0, scaledContextWidth - cellWidth)

    implicitHeight: anchorWs ? ((itemH + Tokens.padding.extraSmall) * anchorWsCount) : Math.max(0, itemH - Tokens.padding.medium)
    implicitWidth: root.expandedW
}

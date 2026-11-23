pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components.effects
import qs.services
import qs.utils

MouseArea {
    id: root

    required property SystemTrayItem modelData

    readonly property int iconSize: Math.max(1, Math.min(Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2, Math.round(Tokens.font.body.small.pointSize * 2)))

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: iconSize
    implicitHeight: iconSize

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}

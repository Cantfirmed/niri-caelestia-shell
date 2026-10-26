pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property PersistentProperties visibilities

    anchors.fill: parent

    visible: opacity > 0
    opacity: (visibilities?.hotkeys ?? false) ? 1.0 : 0.0

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.normal
        }
    }

    // Semi-transparent scrim background to dim other contents
    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: 0.6
    }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.visibilities.hotkeys = false;
        }
    }

    Content {
        id: content

        visibilities: root.visibilities
        anchors.centerIn: parent
    }
}

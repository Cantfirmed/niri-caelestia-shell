pragma ComponentBehavior: Bound

import qs.components
import Caelestia.Config
import qs.services
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities

    anchors.fill: parent

    visible: opacity > 0
    opacity: visibilities.displaySelect ? 1.0 : 0.0

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.normal
        }
    }

    // Semi-transparent scrim background
    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: 0.6
    }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.visibilities.displaySelect = false;
        }
    }

    Content {
        id: content
        visibilities: root.visibilities
        anchors.centerIn: parent
    }
}

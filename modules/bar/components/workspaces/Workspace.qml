pragma ComponentBehavior: Bound

import qs.components
import qs.services
import Caelestia.Config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property int index
    required property var occupied
    required property int groupOffset
    required property int focusedWindowId
    required property int activeWsId

    required property Item windowPopoutSignal

    readonly property bool isWorkspace: true // Flag for finding workspace children
    readonly property int size: isWorkspace ? implicitHeight + (hasWindows ? Appearance.padding.xs : 0) : 0
    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows

    Behavior on scale {
        Anim {}
    }

    Behavior on Layout.preferredHeight {
        Anim {}
    }

    Layout.alignment: Qt.AlignLeft
    Layout.preferredHeight: size

    spacing: 0

    WorkspaceIcon {
        workspace: root
    }

    SafeLoader {
        id: windows

        Layout.alignment: Qt.AlignCenter
        // Layout.fillHeight: true
        Layout.topMargin: -Tokens.sizes.bar.innerWidth / 10

        visible: active
        asynchronous: true
        activeState: root.hasWindows

        sourceComponent: DraggableWindowColumn {
            id: dragDropLayout
            spacing: 0

            workspace: root
            focusedWindowId: root.focusedWindowId
            activeWsId: root.activeWsId
            ws: root.ws
            windowPopoutSignal: root.windowPopoutSignal
            idx: root.index
            groupOffset: root.groupOffset
        }
    }
}

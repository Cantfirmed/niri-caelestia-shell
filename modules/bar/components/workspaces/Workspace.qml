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
    required property int workspaceId
    required property int virtualIdx
    required property string outputName

    required property Item windowPopoutSignal

    readonly property bool isWorkspace: true // Flag for finding workspace children
    readonly property string workspaceStyle: String(Config.bar.workspaces.style ?? GlobalConfig.bar?.workspaces?.style ?? "classic").toLowerCase()
    readonly property bool isMinimap: workspaceStyle === "minimap"
    readonly property int size: isWorkspace ? implicitHeight + (hasWindows ? Appearance.padding.xs : 0) : 0
    readonly property int indicatorSize: isMinimap && hasWindows ? wsIcon.implicitHeight : size
    readonly property int ws: virtualIdx
    readonly property bool isOccupied: workspaceId > 0 && (occupied && (occupied[ws.toString()] ?? false))
    readonly property bool hasWindows: isOccupied && (GlobalConfig.bar?.workspaces?.showWindows ?? true)
    readonly property bool isWsFocused: workspaceId > 0 && activeWsId === ws

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
        id: wsIcon
        workspace: root
    }

    SafeLoader {
        id: windows

        Layout.alignment: Qt.AlignCenter
        Layout.topMargin: root.isMinimap ? 2 : -(Tokens.sizes.bar.innerWidth ?? 40) / 10

        visible: active
        asynchronous: true
        activeState: root.hasWindows

        sourceComponent: root.isMinimap ? minimapComp : classicComp

        Component {
            id: classicComp

            DraggableWindowColumn {
                spacing: 0
                workspace: root
                focusedWindowId: root.focusedWindowId
                activeWsId: root.activeWsId
                ws: root.ws
                windowPopoutSignal: root.windowPopoutSignal
                idx: root.index
                groupOffset: root.groupOffset
                outputName: root.outputName
            }
        }

        Component {
            id: minimapComp

            RibbonStrip {
                workspace: root
                workspaceId: root.workspaceId
                outputName: root.outputName
                focusedWindowId: root.focusedWindowId
                isWsFocused: root.isWsFocused
            }
        }
    }
}

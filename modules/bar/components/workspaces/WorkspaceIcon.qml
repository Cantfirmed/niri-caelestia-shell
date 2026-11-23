pragma ComponentBehavior: Bound

import qs.services
import qs.components
import Caelestia.Config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var workspace
    property bool popupActive: (Niri.wsContextAnchor === root) || (Niri.wsContextAnchor === workspace) || (Niri.wsContextType === "workspaces")

    readonly property int cellWidth: Math.max(1, Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2)
    readonly property int scaledContextWidth: Math.round((Config.bar.workspaces.windowContextWidth ?? 250) * Tokens.uiScale)

    Layout.alignment: Qt.AlignLeft | Qt.AlignTop
    implicitHeight: cellWidth
    Layout.preferredHeight: implicitHeight

    implicitWidth: cellWidth + (popupActive ? scaledContextWidth : 0)
    width: implicitWidth
    height: implicitHeight
    Behavior on implicitWidth {
        Anim {
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    z: popupActive ? 90 : 0

    RowLayout {
        id: content
        anchors.left: parent.left
        spacing: Tokens.padding.extraSmall

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.cellWidth
            Layout.preferredHeight: root.cellWidth

            StyledText {
                id: indicator
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                fontSizeMode: Text.Fit
                minimumPointSize: 1

                animate: true
                text: {
                    //TODO: Add config option to choose between name/number/both for workspaces

                    const _ = Niri.allWorkspaces;
                    const wsName = root.workspace.workspaceId > 0 ? Niri.getWorkspaceNameById(root.workspace.workspaceId) : "";
                    const label = wsName || root.workspace.ws;
                    const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
                    const isWsActive = root.workspace.workspaceId > 0 && root.workspace.activeWsId === root.workspace.ws;
                    const activeLabel = Config.bar.workspaces.activeLabel || (root.workspace.isOccupied ? occupiedLabel : label);
                    return isWsActive ? activeLabel : root.workspace.isOccupied ? occupiedLabel : label;
                }

                color: Config.bar.workspaces.occupiedBg || root.workspace.isOccupied || (root.workspace.workspaceId > 0 && root.workspace.activeWsId === root.workspace.ws) ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
                opacity: root.workspace.isOccupied || (root.workspace.workspaceId > 0 && root.workspace.activeWsId === root.workspace.ws) ? 1.0 : 0.35
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        SafeLoader {
            id: nameLoader
            // anchors.verticalCenter: parent.verticalCenter
            // anchors.left: parent.right
            // anchors.leftMargin: Appearance.padding.xl
            activeState: root.popupActive
            sourceComponent: StyledText {
                color: Config.bar.workspaces.occupiedBg || root.workspace.isOccupied || root.workspace.activeWsId === root.workspace.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)

                font.pointSize: Tokens.font.body.small.pointSize * (Config.bar.workspaces.workspaceIconScale ?? 1.0)
                font.family: Tokens.font.mono.medium.family
                text: {
                    const _ = Niri.allWorkspaces;
                    return root.workspace.workspaceId > 0 ? Niri.getWorkspaceNameById(root.workspace.workspaceId) : "Workspace " + (root.workspace.ws)
                }
            }
        }

        z: 1
    }

    Interaction {
        id: interactionArea
    }

    // --------------------------
    // Interaction / Drag Handling
    // --------------------------
    component Interaction: StateLayer {
        id: mouseArea
        anchors.fill: root
        acceptedButtons: Qt.LeftButton
        cursorShape: (Qt.PointingHandCursor)
        pressAndHoldInterval: Tokens.anim.durations.small

        radius: Tokens.rounding.small

        hoverEnabled: true

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                const targetId = root.workspace.workspaceId;
                if (targetId > 0)
                    Niri.switchToWorkspaceById(targetId);
                return;
            }
        }
    }
}

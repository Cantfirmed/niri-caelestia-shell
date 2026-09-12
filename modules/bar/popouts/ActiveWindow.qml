pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Internal
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property PopoutState popouts

    readonly property var client: Niri.lastFocusedWindow
    readonly property bool hasActiveWindow: !!client && client.id !== undefined && client.id !== null

    Component.onCompleted: {
        console.log("[ActiveWindowPopout] Loaded. client id:", root.client?.id, "title:", root.client?.title, "app_id:", root.client?.app_id, "hasActiveWindow:", root.hasActiveWindow);
    }
    onClientChanged: {
        console.log("[ActiveWindowPopout] client changed. id:", root.client?.id, "title:", root.client?.title, "app_id:", root.client?.app_id, "hasActiveWindow:", root.hasActiveWindow);
    }
    onHasActiveWindowChanged: {
        console.log("[ActiveWindowPopout] hasActiveWindow changed:", root.hasActiveWindow);
    }

    implicitWidth: hasActiveWindow ? (detailsRow.implicitWidth + Tokens.padding.medium * 2) : -Tokens.padding.extraLargeIncreased
    implicitHeight: detailsRow.implicitHeight + Tokens.padding.medium * 2

    RowLayout {
        id: detailsRow

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        IconImage {
            id: icon

            asynchronous: true
            Layout.alignment: Qt.AlignVCenter
            implicitSize: 40
            source: Icons.getAppIcon(root.client?.app_id ?? "", "image-missing")
        }

        ColumnLayout {
            id: details

            spacing: 0
            Layout.preferredWidth: 250
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: root.client?.title ?? ""
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.client?.app_id ?? ""
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        Item {
            implicitWidth: expandIcon.implicitHeight + Tokens.padding.small
            implicitHeight: expandIcon.implicitHeight + Tokens.padding.small

            Layout.alignment: Qt.AlignVCenter

            StateLayer {
                radius: Tokens.rounding.large
                onClicked: root.popouts.detachRequested("winfo")
            }

            MaterialIcon {
                id: expandIcon

                anchors.centerIn: parent
                anchors.horizontalCenterOffset: font.pointSize * 0.05

                text: "chevron_right"

                fontStyle: Tokens.font.icon.large
            }
        }
    }
}

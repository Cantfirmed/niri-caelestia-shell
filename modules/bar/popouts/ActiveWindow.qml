pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property PopoutState popouts

    readonly property var niriClient: (typeof Niri !== "undefined" && Niri.niriAvailable) ? Niri.lastFocusedWindow : null
    readonly property bool hasActiveWindow: (typeof Niri !== "undefined" && Niri.niriAvailable) ? (!!niriClient && niriClient.id !== undefined && niriClient.id !== null) : (typeof Hypr !== "undefined" && !!Hypr.activeToplevel)

    readonly property string title: (typeof Niri !== "undefined" && Niri.niriAvailable) ? (niriClient?.title ?? "") : (typeof Hypr !== "undefined" ? (Hypr.activeToplevel?.title ?? "") : "")
    readonly property string appClass: (typeof Niri !== "undefined" && Niri.niriAvailable) ? (niriClient?.app_id ?? "") : (typeof Hypr !== "undefined" ? (Hypr.activeToplevel?.lastIpcObject.class ?? "") : "")

    implicitWidth: hasActiveWindow ? child.implicitWidth : -Tokens.padding.extraLargeIncreased
    implicitHeight: child.implicitHeight

    Column {
        id: child

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        RowLayout {
            id: detailsRow

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Tokens.spacing.medium

            IconImage {
                id: icon

                asynchronous: true
                Layout.alignment: Qt.AlignVCenter
                implicitSize: details.implicitHeight
                source: Icons.getAppIcon(root.appClass, "image-missing")
            }

            ColumnLayout {
                id: details

                spacing: 0
                Layout.preferredWidth: 250
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.appClass
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

        Loader {
            active: typeof Hypr !== "undefined" && !!Hypr.activeToplevel
            sourceComponent: ClippingWrapperRectangle {
                color: "transparent"
                radius: Tokens.rounding.medium

                ScreencopyView {
                    id: preview

                    captureSource: typeof Hypr !== "undefined" ? (Hypr.activeToplevel?.wayland ?? null) : null // qmllint disable unresolved-type
                    live: visible

                    constraintSize.width: Tokens.sizes.bar.windowPreviewSize
                    constraintSize.height: Tokens.sizes.bar.windowPreviewSize
                }
            }
        }
    }
}


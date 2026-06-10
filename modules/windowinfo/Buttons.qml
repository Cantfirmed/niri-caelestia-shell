pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property var client
    property bool moveToWsExpanded

    anchors.fill: parent
    spacing: Tokens.spacing.small

    RowLayout {
        Layout.topMargin: Tokens.padding.large
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large

        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Move to workspace")
            elide: Text.ElideRight
        }

        StyledRect {
            color: Colours.palette.m3primary
            radius: Tokens.rounding.medium

            implicitWidth: moveToWsIcon.implicitWidth + Tokens.padding.small
            implicitHeight: moveToWsIcon.implicitHeight + Tokens.padding.extraSmall

            StateLayer {
                color: Colours.palette.m3onPrimary
                onClicked: root.moveToWsExpanded = !root.moveToWsExpanded
            }

            MaterialIcon {
                id: moveToWsIcon

                anchors.centerIn: parent

                animate: true
                text: root.moveToWsExpanded ? "expand_more" : "keyboard_arrow_right"
                color: Colours.palette.m3onPrimary
                fontStyle: Tokens.font.icon.large
            }
        }
    }

    WrapperItem {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.extraLargeIncreased
        Layout.rightMargin: Tokens.padding.extraLargeIncreased

        Layout.preferredHeight: root.moveToWsExpanded ? implicitHeight : 0
        clip: true

        topMargin: Tokens.spacing.medium
        bottomMargin: Tokens.spacing.medium

        GridLayout {
            id: wsGrid

            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.medium
            columns: 5

            Repeater {
                model: Niri.allWorkspaces

                Button {
                    required property var modelData
                    readonly property int wsIdx: modelData.idx
                    readonly property int wsId: modelData.id
                    readonly property bool isCurrent: root.client?.workspace_id === wsId

                    onClicked: {
                        Niri.moveWindowToWorkspace(wsIdx);
                    }

                    color: isCurrent ? Colours.tPalette.m3surfaceContainerHighest : Colours.palette.m3tertiaryContainer
                    onColor: isCurrent ? Colours.palette.m3onSurface : Colours.palette.m3onTertiaryContainer
                    text: modelData.name || (wsIdx + 1).toString()
                    disabled: isCurrent
                }
            }
        }

        Behavior on Layout.preferredHeight {
            Anim {}
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.bottomMargin: Tokens.padding.large

        spacing: Tokens.spacing.medium

        Button {
            color: Colours.palette.m3secondaryContainer
            onColor: Colours.palette.m3onSecondaryContainer
            text: root.client?.is_floating ? qsTr("Tile") : qsTr("Float")
            onClicked: Niri.toggleWindowFloating(root.client?.id)
        }

        Button {
            color: Colours.palette.m3secondaryContainer
            onColor: Colours.palette.m3onSecondaryContainer
            text: qsTr("Maximize")
            onClicked: Niri.toggleMaximize()
        }

        Button {
            color: Colours.palette.m3errorContainer
            onColor: Colours.palette.m3onErrorContainer
            text: qsTr("Kill")
            onClicked: Niri.closeWindow(root.client?.id)
        }
    }

    component Button: StyledRect {
        property color onColor: Colours.palette.m3onSurface
        property alias disabled: stateLayer.disabled
        property alias text: label.text

        signal clicked

        radius: Tokens.rounding.medium

        Layout.fillWidth: true
        implicitHeight: label.implicitHeight + Tokens.padding.small

        StateLayer {
            id: stateLayer

            color: parent.onColor
            onClicked: parent.clicked()
        }

        StyledText {
            id: label

            anchors.centerIn: parent

            animate: true
            color: parent.onColor
            font: Tokens.font.body.medium
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    width: 310
    spacing: Tokens.spacing.small

    readonly property var card: BluetoothAudio.activeCard

    // Header: Device Info
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.small
        Layout.bottomMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.medium

        StyledRect {
            implicitWidth: 36
            implicitHeight: 36
            radius: Tokens.rounding.full
            color: Colours.palette.m3primaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                text: "headphones"
                color: Colours.palette.m3onPrimaryContainer
                fontStyle: Tokens.font.icon.medium
                fill: 1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.card ? root.card.description : Tr.tr("Bluetooth Audio")
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.card ? Tr.tr("Current Codec: %1").arg(root.card.activeCodecName || Tr.tr("Default")) : Tr.tr("No device connected")
                font: Tokens.font.body.small
                color: root.card ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }
        }

        // Active Codec Badge
        StyledRect {
            visible: !!root.card && !!root.card.activeCodecName
            radius: Tokens.rounding.small
            color: Qt.alpha(Colours.palette.m3primary, 0.15)
            border.color: Qt.alpha(Colours.palette.m3primary, 0.4)
            border.width: 1
            implicitWidth: badgeText.implicitWidth + Tokens.padding.small * 2
            implicitHeight: badgeText.implicitHeight + Tokens.padding.extraSmall

            StyledText {
                id: badgeText
                anchors.centerIn: parent
                text: root.card?.activeCodecName ?? ""
                font: Tokens.font.label.small
                color: Colours.palette.m3primary
            }
        }
    }

    // Divider
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(Colours.palette.m3outline, 0.2)
    }

    // Empty state if no bluetooth card
    ColumnLayout {
        visible: !root.card
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.medium
        Layout.bottomMargin: Tokens.spacing.medium
        spacing: Tokens.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "headset_off"
            fontStyle: Tokens.font.icon.large
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr("No Bluetooth headphones connected")
            font: Tokens.font.body.medium
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    // Codec list when card is present
    ColumnLayout {
        visible: !!root.card
        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.topMargin: Tokens.spacing.extraSmall
            Layout.bottomMargin: 2
            text: Tr.tr("Select Audio Codec")
            font: Tokens.font.label.medium
            color: Colours.palette.m3onSurfaceVariant
        }

        Repeater {
            model: root.card ? root.card.profiles : []

            StyledRect {
                id: profileItem

                required property var modelData

                readonly property bool isActive: root.card?.activeProfile === modelData.id
                readonly property bool isHfp: modelData.isHeadset

                Layout.fillWidth: true
                implicitHeight: 40
                radius: Tokens.rounding.medium
                color: isActive ? Qt.alpha(Colours.palette.m3primary, 0.12) : "transparent"
                border.color: isActive ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.15)
                border.width: isActive ? 1.5 : 1

                StateLayer {
                    radius: parent.radius
                    onClicked: {
                        if (root.card) {
                            BluetoothAudio.setProfile(root.card.name, profileItem.modelData.id);
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: profileItem.isActive ? "radio_button_checked" : "radio_button_unchecked"
                        color: profileItem.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                        animate: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: profileItem.modelData.codec
                            font: profileItem.isActive ? Tokens.font.body.builders.medium.weight(Font.Bold).build() : Tokens.font.body.medium
                            color: profileItem.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: profileItem.modelData.mode
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    MaterialIcon {
                        visible: profileItem.isHfp
                        text: "mic"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledRect {
                        visible: profileItem.isActive
                        radius: Tokens.rounding.small
                        color: Colours.palette.m3primary
                        implicitWidth: activeLabel.implicitWidth + Tokens.padding.small
                        implicitHeight: activeLabel.implicitHeight + 2

                        StyledText {
                            id: activeLabel
                            anchors.centerIn: parent
                            text: Tr.tr("Active")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onPrimary
                        }
                    }
                }

                Behavior on border.color {
                    CAnim {}
                }

                Behavior on color {
                    CAnim {}
                }
            }
        }
    }

    // Footer action buttons
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        spacing: Tokens.spacing.small

        IconTextButton {
            Layout.fillWidth: true
            inactiveColour: Colours.palette.m3surfaceContainerHigh
            inactiveOnColour: Colours.palette.m3onSurface
            verticalPadding: Tokens.padding.extraSmall
            text: Tr.tr("Bluetooth")
            icon: "bluetooth"
            onClicked: root.popouts.currentName = "bluetooth"
        }

        IconTextButton {
            Layout.fillWidth: true
            inactiveColour: Colours.palette.m3surfaceContainerHigh
            inactiveOnColour: Colours.palette.m3onSurface
            verticalPadding: Tokens.padding.extraSmall
            text: Tr.tr("Audio")
            icon: "tune"
            onClicked: root.popouts.currentName = "audio"
        }
    }
}

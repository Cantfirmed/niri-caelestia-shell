pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property PopoutState popouts

    implicitWidth: Tokens.sizes.bar.audioWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium

        StyledText {
            text: Tr.trCtx("Output device", "audio output device")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Repeater {
            model: Audio.sinks

            StyledRadioButton {
                id: control

                required property PwNode modelData

                Layout.fillWidth: true
                ButtonGroup.group: sinks
                checked: Audio.sink?.id === modelData.id
                onClicked: Audio.setAudioSink(modelData)
                text: modelData.description
            }
        }

        ColumnLayout {
            visible: !!BluetoothAudio.activeCard
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: Tr.tr("Bluetooth Codec")
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                }

                Item { Layout.fillWidth: true }

                StyledRect {
                    visible: !!BluetoothAudio.activeCard?.activeCodecName
                    radius: Tokens.rounding.small
                    color: Qt.alpha(Colours.palette.m3primary, 0.15)
                    implicitWidth: codecBadge.implicitWidth + Tokens.padding.small
                    implicitHeight: codecBadge.implicitHeight + 2

                    StyledText {
                        id: codecBadge
                        anchors.centerIn: parent
                        text: BluetoothAudio.activeCard?.activeCodecName ?? ""
                        font: Tokens.font.label.small
                        color: Colours.palette.m3primary
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: BluetoothAudio.activeCard ? BluetoothAudio.activeCard.profiles : []

                    StyledRect {
                        id: chipItem
                        required property var modelData
                        readonly property bool isActive: BluetoothAudio.activeCard?.activeProfile === modelData.id

                        radius: Tokens.rounding.full
                        implicitHeight: chipText.implicitHeight + Tokens.padding.extraSmall
                        implicitWidth: chipText.implicitWidth + Tokens.padding.medium
                        color: isActive ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6)
                        border.color: isActive ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.2)
                        border.width: 1

                        StateLayer {
                            radius: parent.radius
                            onClicked: {
                                if (BluetoothAudio.activeCard) {
                                    BluetoothAudio.setProfile(BluetoothAudio.activeCard.name, chipItem.modelData.id);
                                }
                            }
                        }

                        StyledText {
                            id: chipText
                            anchors.centerIn: parent
                            text: chipItem.modelData.codec
                            font: Tokens.font.label.medium
                            color: chipItem.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: Tr.trCtx("Input device", "audio input device")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Repeater {
            model: Audio.sources

            StyledRadioButton {
                required property PwNode modelData

                Layout.fillWidth: true
                ButtonGroup.group: sources
                checked: Audio.source?.id === modelData.id
                onClicked: Audio.setAudioSource(modelData)
                text: modelData.description
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: Audio.muted ? Tr.tr("Volume (muted)") : Tr.tr("Volume (%1%)").arg(Math.round(Audio.volume * 100))
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 3

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: parent.implicitHeight

                value: Audio.volume
                onInteraction: value => Audio.setVolume(value)
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.extraSmall
            text: Tr.tr("Open settings")
            icon: "settings"

            onClicked: root.popouts.detachRequested("audio")
        }
    }
}

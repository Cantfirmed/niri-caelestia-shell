import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: card

    /// Cap for the container list so a large number of containers cannot
    /// blow up the dashboard; the list scrolls instead.
    readonly property real maxListHeight: 420

    /// Width is driven by the Dev tab so both cards stay equal.
    property real cardWidth: Tokens.sizes.dashboard.perfHeroCardWidth
    /// Roomy insets — the rows carry an image label line plus buttons.
    readonly property real contentPadding: Tokens.padding.extraLargeIncreased

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.large

    implicitWidth: card.cardWidth
    implicitHeight: layout.implicitHeight + card.contentPadding * 2

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.contentPadding
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "deployed_code"
                color: Colours.palette.m3secondary
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                text: Tr.tr("Docker")
                font: Tokens.font.title.medium
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                visible: Dev.containers.length > 0
                text: Dev.containers.length.toString()
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurfaceVariant
            }

            IconButton {
                id: refreshBtn

                type: IconButton.Text
                icon: "refresh"
                onClicked: Dev.refresh()

                Tooltip {
                    target: refreshBtn
                    text: Tr.tr("Refresh")
                }
            }
        }

        // Error / missing daemon
        ColumnLayout {
            Layout.fillWidth: true
            visible: !Dev.dockerAvailable
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.topMargin: Tokens.spacing.small
                text: Dev.dockerInstalled ? Tr.tr("Docker daemon unreachable") : Tr.tr("Docker not installed")
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: Dev.dockerInstalled ? Tr.tr("Is the Docker daemon running?") : Tr.tr("Install docker to manage containers from here")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Dev.dockerAvailable && Dev.containers.length === 0
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.topMargin: Tokens.spacing.small
                text: Tr.tr("No containers")
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Running containers show up here with stop and restart controls")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }

        Flickable {
            id: listFlick

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, card.maxListHeight)
            visible: Dev.dockerAvailable && Dev.containers.length > 0
            contentWidth: width
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: list

                width: listFlick.width
                spacing: Tokens.spacing.small

                Repeater {
                    model: ScriptModel {
                        values: Dev.containers
                    }

                    delegate: ContainerRow {}
                }
            }

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: listFlick
            }
        }
    }

    component ContainerRow: Item {
        id: row

        required property var modelData

        readonly property bool isRunning: modelData.state === "running"
        readonly property string portsLabel: Dev.formatPorts(modelData.ports)
        readonly property string subLabel: {
            const parts = [];
            if (row.modelData.image)
                parts.push(row.modelData.image);
            if (row.modelData.status)
                parts.push(row.modelData.status);
            if (row.portsLabel)
                parts.push(row.portsLabel);
            return parts.join(" • ");
        }

        Layout.fillWidth: true
        implicitHeight: Math.max(44, inner.implicitHeight)

        RowLayout {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: row.isRunning ? "circle" : "stop_circle"
                fill: row.isRunning ? 1 : 0
                color: row.isRunning ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    font: Tokens.font.body.medium
                    color: row.isRunning ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: row.subLabel
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideMiddle
                }
            }

            RowLayout {
                id: actionRow

                readonly property bool busy: Dev.busy[row.modelData.id] !== undefined

                spacing: Tokens.spacing.extraSmall

                IconButton {
                    id: stopBtn

                    type: IconButton.Tonal
                    icon: "stop"
                    visible: row.isRunning
                    disabled: actionRow.busy

                    onClicked: Dev.stopContainer(row.modelData.id)

                    Tooltip {
                        target: stopBtn
                        text: Tr.tr("Stop container")
                    }
                }

                IconButton {
                    id: restartBtn

                    type: IconButton.Tonal
                    icon: "restart_alt"
                    visible: row.isRunning
                    disabled: actionRow.busy

                    onClicked: Dev.restartContainer(row.modelData.id)

                    Tooltip {
                        target: restartBtn
                        text: Tr.tr("Restart container")
                    }
                }

                IconButton {
                    id: startBtn

                    type: IconButton.Tonal
                    icon: "play_arrow"
                    visible: !row.isRunning
                    disabled: actionRow.busy

                    onClicked: Dev.startContainer(row.modelData.id)

                    Tooltip {
                        target: startBtn
                        text: Tr.tr("Start container")
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

StyledRect {
    id: card

    /// Width is driven by the Dev tab so both cards stay equal.
    property real cardWidth: Tokens.sizes.dashboard.perfHeroCardWidth
    /// Roomy insets — the rows carry three lines of text plus buttons.
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
                text: "http"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                text: Tr.tr("Web servers")
                font: Tokens.font.title.medium
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                visible: Dev.servers.length > 0
                text: Dev.servers.length.toString()
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

        ColumnLayout {
            id: list

            Layout.fillWidth: true
            visible: Dev.servers.length > 0
            spacing: Tokens.spacing.small

            Repeater {
                model: ScriptModel {
                    values: Dev.servers
                }

                delegate: ServerRow {}
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Dev.servers.length === 0
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.topMargin: Tokens.spacing.small
                text: Tr.tr("No local web servers detected")
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Dev servers (Vite, Next, Angular, ...) show up here while they are running")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }
    }

    component ServerRow: Item {
        id: row

        required property var modelData

        readonly property string key: modelData.pid
        readonly property string cwdName: {
            if (!modelData.cwd)
                return "";
            const parts = modelData.cwd.split("/").filter(p => p.length > 0);
            return parts.length > 0 ? parts[parts.length - 1] : "";
        }
        readonly property bool cwdIsHome: !!modelData.cwd && modelData.cwd === Paths.home
        readonly property string cmdName: (modelData.cmdline || modelData.comm || "").split(/\s+/)[0].split("/").pop()
        // Best-effort "script" token from the command line (e.g. vite, manage.py)
        readonly property string scriptName: {
            for (const tok of (modelData.cmdline || "").split(/\s+/)) {
                if (tok.startsWith("-"))
                    continue;
                const base = tok.split("/").pop();
                if (base && base.includes(".") && !base.startsWith(".") && base !== row.cmdName)
                    return base;
            }
            return "";
        }
        readonly property string title: {
            if (row.modelData.project && row.cwdName.length > 0 && !row.cwdIsHome)
                return row.cwdName;
            return row.scriptName || row.cmdName || row.modelData.comm;
        }
        readonly property string portLabel: row.modelData.ports.map(p => ":" + p).join(", ")
        readonly property string command: row.modelData.cmdline === row.cmdName ? "" : row.modelData.cmdline

        Layout.fillWidth: true
        implicitHeight: Math.max(44, inner.implicitHeight)

        RowLayout {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "code"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: row.title
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: `${row.portLabel} • pid ${row.modelData.pid}`
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: row.command.length > 0
                    text: row.command
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideMiddle
                }
            }

            IconButton {
                id: openBtn

                type: IconButton.Text
                icon: "open_in_new"
                onClicked: Dev.openServer(row.modelData.ports[0])

                Tooltip {
                    target: openBtn
                    text: Tr.tr("Open in browser")
                }
            }

            IconButton {
                id: stopBtn

                type: IconButton.Tonal
                icon: "stop"
                disabled: Dev.killing[row.key] ?? false

                onClicked: Dev.stopServer([row.modelData.pid])

                Tooltip {
                    target: stopBtn
                    text: Tr.tr("Stop server")
                }
            }
        }
    }
}

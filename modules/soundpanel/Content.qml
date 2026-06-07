pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import Caelestia.Config
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Card {
    id: root

    required property PersistentProperties visibilities

    variant: Card.Variant.Elevated
    padding: Appearance.padding.xl
    radius: Appearance.rounding.large

    implicitWidth: 460
    implicitHeight: layout.implicitHeight + padding * 2

    property var clientMap: ({})

    Process {
        id: clientMapper
        command: ["sh", "-c", "pw-dump | jq -r '.[] | select(.type == \"PipeWire:Interface:Client\") | \"\\(.id):\\(.info.props[\"application.name\"] // .info.props[\"application.process.binary\"] // .info.props[\"node.name\"] // \"\")\"'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n");
                let map = {};
                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].split(":");
                    if (parts.length >= 2) {
                        map[parts[0]] = parts.slice(1).join(":");
                    }
                }
                root.clientMap = map;
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 3000
        running: root.visibilities.soundPanel
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            clientMapper.running = true;
        }
    }

    function getAppName(node) {
        if (node && node.properties) {
            const appName = node.properties["application.name"];
            if (appName) return appName;

            const clientId = node.properties["client.id"];
            if (clientId && root.clientMap[clientId]) {
                return root.clientMap[clientId];
            }
        }
        return node && node.name ? node.name : qsTr("Unknown Application");
    }
    function getAppIcon(node) {
        if (node && node.properties && node.properties["application.icon-name"]) {
            return node.properties["application.icon-name"];
        }
        const name = getAppName(node).toLowerCase();
        if (name === "spotify") return "spotify";
        return name || "audio-x-generic";
    }

    function getPlayerForNode(node) {
        if (!node) return null;
        const appName = getAppName(node).toLowerCase();
        const list = Players.list;
        for (let i = 0; i < list.length; i++) {
            const player = list[i];
            const identity = player.identity.toLowerCase();
            const entry = player.desktopEntry ? player.desktopEntry.toLowerCase() : "";
            if (identity.indexOf(appName) !== -1 || appName.indexOf(identity) !== -1 ||
                entry.indexOf(appName) !== -1 || appName.indexOf(entry) !== -1) {
                return player;
            }
        }
        return null;
    }
    // Filter active application stream nodes.
    // Ensure it is a stream with audio features and has a valid application name.
    // This automatically filters out internal streams like audio-src (CAVA visualizer helper).
    readonly property var streamNodes: {
        const list = Audio.streams;
        let activeStreams = [];
        for (let i = 0; i < list.length; i++) {
            const node = list[i];
            if (node) {
                const appName = getAppName(node).toLowerCase();
                if (appName !== "quickshell" && appName !== "unknown" && appName !== "unknown application") {
                    activeStreams.push(node);
                }
            }
        }
        return activeStreams;
    }
    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: root.padding
        spacing: Appearance.spacing.lg

        // Placeholder when no applications are playing sound
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.streamNodes.length === 0
            spacing: Appearance.spacing.md
            Layout.topMargin: Appearance.spacing.lg
            Layout.bottomMargin: Appearance.spacing.lg

            MaterialIcon {
                text: "volume_mute"
                font.pointSize: 48
                color: Colours.palette.m3outline
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                text: qsTr("No applications playing sound")
                font.pointSize: Appearance.font.size.bodyMedium
                color: Colours.palette.m3outline
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // List of applications currently playing sound
        ColumnLayout {
            id: streamsList
            Layout.fillWidth: true
            visible: root.streamNodes.length > 0
            spacing: Appearance.spacing.md

            Repeater {
                model: root.streamNodes

                delegate: RowLayout {
                    id: streamItem
                    required property PwNode modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: Appearance.spacing.md
                    
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8

                    // App Icon with tooltip showing application name
                    IconImage {
                        id: appIcon
                        source: Quickshell.iconPath(
                            getAppIcon(streamItem.modelData),
                            "audio-x-generic"
                        )
                        implicitSize: 32
                        Layout.alignment: Qt.AlignVCenter

                        HoverHandler {
                            id: appHover
                        }

                        Tooltip {
                            target: appIcon
                            text: getAppName(streamItem.modelData)
                            visible: appHover.hovered
                        }
                    }

                    // 0% label
                    StyledText {
                        text: "0%"
                        font.pointSize: Appearance.font.size.labelMedium
                        color: Colours.palette.m3outline
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Volume Slider
                    StyledSlider {
                        Layout.fillWidth: true
                        implicitHeight: 24
                        value: streamItem.modelData.audio.volume
                        onMoved: {
                            Audio.setStreamVolume(streamItem.modelData, value);
                        }
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // 100% label
                    StyledText {
                        text: "100%"
                        font.pointSize: Appearance.font.size.labelMedium
                        color: Colours.palette.m3outline
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Play/Pause button
                    IconButton {
                        readonly property var player: {
                            const map = root.clientMap;
                            const list = Players.list;
                            const len = list.length;
                            return getPlayerForNode(streamItem.modelData);
                        }
                        visible: player !== null
                        disabled: player ? !player.canTogglePlaying : true
                        icon: player && player.isPlaying ? "pause" : "play_arrow"
                        type: IconButton.Tonal
                        onClicked: {
                            if (player) player.togglePlaying();
                        }
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Mute button
                    IconButton {
                        icon: streamItem.modelData.audio.muted ? "volume_off" : "volume_up"
                        type: IconButton.Tonal
                        isToggle: true
                        checked: streamItem.modelData.audio.muted
                        onClicked: {
                            Audio.setStreamMuted(streamItem.modelData, !streamItem.modelData.audio.muted);
                        }
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Bluetooth
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.bar.popouts as BarPopouts

StyledRect {
    id: root

    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts

    Process {
        id: btUnblockProc
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: {
            const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
            if (adapter && !adapter.enabled)
                adapter.enabled = true;
        }
    }

    readonly property var quickToggles: {
        const seenIds = new Set();
        const raw = GlobalConfig.utilities?.quickToggles ?? Config.utilities?.quickToggles;
        let list = [];
        if (raw) {
            if (Array.isArray(raw)) list = raw;
            else if (raw.values) {
                list = Array.from(typeof raw.values === "function" ? raw.values() : raw.values);
            }
        }
        if (!list || list.length === 0) {
            list = [
                { id: "wifi", enabled: true },
                { id: "bluetooth", enabled: true },
                { id: "mic", enabled: true },
                { id: "settings", enabled: true },
                { id: "gameMode", enabled: true },
                { id: "dnd", enabled: true },
                { id: "vpn", enabled: false }
            ];
        }

        return list.filter(item => {
            if (!item || !item.enabled)
                return false;

            if (seenIds.has(item.id))
                return false;

            if (item.id === "vpn")
                return (GlobalConfig.utilities?.vpn?.selectedProvider?.length ?? 0) > 0;

            seenIds.add(item.id);
            return true;
        });
    }
    readonly property int splitIndex: Math.ceil(quickToggles.length / 2)
    readonly property bool needExtraRow: quickToggles.length > 6

    implicitHeight: layout.implicitHeight + Tokens.padding.extraLargeIncreased

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledText {
            text: qsTr("Quick Toggles")
            font: Tokens.font.body.medium
        }

        QuickToggleRow {
            model: root.needExtraRow ? root.quickToggles.slice(0, root.splitIndex) : root.quickToggles
        }

        QuickToggleRow {
            visible: root.needExtraRow
            model: root.needExtraRow ? root.quickToggles.slice(root.splitIndex) : []
        }
    }

    component QuickToggleRow: ButtonRow {
        property alias model: repeater.model

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        Repeater {
            id: repeater

            Loader {
                id: toggleLoader
                required property var modelData
                Layout.fillWidth: true

                sourceComponent: {
                    switch (modelData.id) {
                    case "wifi": return wifiComp;
                    case "bluetooth": return bluetoothComp;
                    case "mic": return micComp;
                    case "settings": return settingsComp;
                    case "gameMode": return gameModeComp;
                    case "dnd": return dndComp;
                    case "vpn": return vpnComp;
                    default: return null;
                    }
                }
            }
        }
    }

    Component {
        id: wifiComp
        Toggle {
            icon: "wifi"
            checked: Nmcli.wifiEnabled
            onClicked: Nmcli.toggleWifi()
        }
    }

    Component {
        id: bluetoothComp
        Toggle {
            icon: "bluetooth"
            checked: Bluetooth.defaultAdapter?.enabled ?? false // qmllint disable unresolved-type
            onClicked: {
                const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
                if (adapter) {
                    if (!adapter.enabled)
                        btUnblockProc.running = true;
                    adapter.enabled = !adapter.enabled;
                } else {
                    btUnblockProc.running = true;
                }
            }
        }
    }

    Component {
        id: micComp
        Toggle {
            icon: "mic"
            checked: !Audio.sourceMuted
            onClicked: {
                const audio = Audio.source?.audio;
                if (audio)
                    audio.muted = !audio.muted;
            }
        }
    }

    Component {
        id: settingsComp
        Toggle {
            icon: "settings"
            inactiveOnColour: Colours.palette.m3onSurfaceVariant
            isToggle: false
            onClicked: {
                root.screenState.utilities = false;
                WindowFactory.create();
            }
        }
    }

    Component {
        id: gameModeComp
        Toggle {
            icon: "gamepad"
            checked: GameMode.enabled
            onClicked: GameMode.enabled = !GameMode.enabled
        }
    }

    Component {
        id: dndComp
        Toggle {
            icon: "notifications_off"
            checked: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }
    }

    Component {
        id: vpnComp
        Toggle {
            icon: "vpn_key"
            checked: VPN.connected && VPN.status.state !== "needs-auth" && VPN.status.state !== "error"
            enabled: !VPN.connecting && !VPN.disconnecting
            isToggle: VPN.status.state !== "needs-auth" && VPN.status.state !== "error"
            inactiveOnColour: Colours.palette.m3onSurfaceVariant
            onClicked: VPN.toggle()
        }
    }

    component Toggle: IconButton {
        inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        fillWidth: true
        isToggle: true
        isRound: true
        shapeMorph: true
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.bar.components.status

StyledRect {
    id: root

    property color colour: Colours.palette.m3secondary
    readonly property alias items: iconColumn

    readonly property int spacing: Tokens.spacing.medium / 2

    // Index of the first/last entry that isn't collapsed, for edge margin gating
    readonly property int firstPresent: {
        const values = model.values;
        for (let i = 0; i < values.length; i++)
            if (!collapsed(values[i]))
                return i;
        return -1;
    }
    readonly property int lastPresent: {
        const values = model.values;
        for (let i = values.length - 1; i >= 0; i--)
            if (!collapsed(values[i]))
                return i;
        return -1;
    }

    // Entries that can shrink to nothing, spacing included
    function collapsed(entry: var): bool {
        if (entry.id === "lockStatus") {
            const caps = (typeof Niri !== "undefined" && Niri.niriAvailable) ? Niri.capsLock : (typeof Hypr !== "undefined" ? Hypr.capsLock : false);
            const num = (typeof Niri !== "undefined" && Niri.niriAvailable) ? Niri.numLock : (typeof Hypr !== "undefined" ? Hypr.numLock : false);
            return !caps && !num;
        }
        return false;
    }

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    clip: true
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: iconColumn.implicitHeight + Tokens.padding.medium * 2
    width: implicitWidth
    height: implicitHeight

    ColumnLayout {
        id: iconColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.medium

        spacing: 0

        Repeater {
            model: ScriptModel {
                id: model

                values: {
                    const raw = GlobalConfig.bar?.statusIcons ?? Config.bar?.statusIcons;
                    let list = [];
                    if (raw) {
                        if (Array.isArray(raw)) list = raw;
                        else if (raw.values) {
                            list = Array.from(typeof raw.values === "function" ? raw.values() : raw.values);
                        }
                    }
                    if (!list || list.length === 0) {
                        list = [
                            { id: "lockStatus", enabled: true },
                            { id: "network", enabled: true },
                            { id: "bluetooth", enabled: true },
                            { id: "battery", enabled: true }
                        ];
                    }
                    return list.filter(e => e && e.enabled);
                }
            }

        delegate: Loader {
            id: iconLoader
            required property var modelData
            required property int index

            property int margin: (modelData.id === "audio" || modelData.id === "microphone") ? Tokens.spacing.extraSmall / 2 : root.spacing / 2
            readonly property bool present: !root.collapsed(modelData)
            property real topGap: present && index !== root.firstPresent ? margin : 0
            property real bottomGap: present && index !== root.lastPresent ? margin : 0
            readonly property string name: (modelData.id === "microphone") ? "audio" : modelData.id.toLowerCase()

            Layout.topMargin: Math.round(topGap)
            Layout.bottomMargin: Math.round(bottomGap)
            Layout.alignment: Qt.AlignHCenter

            Behavior on topGap {
                Anim {
                    type: Anim.SlowEffects
                }
            }

            Behavior on bottomGap {
                Anim {
                    type: Anim.SlowEffects
                }
            }

            sourceComponent: {
                switch (iconLoader.modelData.id) {
                case "lockStatus": return lockStatusComp;
                case "audio": return audioComp;
                case "microphone": return micComp;
                case "kbLayout": return kbLayoutComp;
                case "network": return networkComp;
                case "bluetooth": return bluetoothComp;
                case "battery": return batteryComp;
                default: return null;
                }
            }
        }
    }
}

    Component {
        id: lockStatusComp
        LockStatus {
            colour: root.colour
            parentSpacing: root.spacing
        }
    }

    Component {
        id: audioComp
        MaterialIcon {
            animate: true
            text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            color: root.colour
            fontStyle: Tokens.font.icon.medium
            fill: 1
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Component {
        id: micComp
        MaterialIcon {
            animate: true
            text: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            color: root.colour
            fontStyle: Tokens.font.icon.medium
            fill: 1
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Component {
        id: kbLayoutComp
        StyledText {
            animate: true
            text: (typeof Niri !== "undefined" && Niri.niriAvailable) ? Niri.kbLayout : (typeof Hypr !== "undefined" ? Hypr.kbLayout : "EN")
            color: root.colour
            font: Tokens.font.mono.medium
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Component {
        id: networkComp
        MaterialIcon {
            animate: true
            text: Nmcli.activeEthernet ? "cable" : Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
            color: root.colour
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Component {
        id: bluetoothComp
        BluetoothStatus {
            colour: root.colour
        }
    }

    Component {
        id: batteryComp
        BatteryStatus {
            colour: root.colour
        }
    }
}

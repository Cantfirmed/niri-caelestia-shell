pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.utils

Item {
    id: root

    required property color colour

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    function checkPopout(localY: real): var {
        const layoutY = layout.mapFromItem(root, 0, localY).y;

        for (let i = 0; i < devicesRepeater.count; i++) {
            const item = devicesRepeater.itemAt(i);
            if (item) {
                const halfSpacing = layout.spacing / 2;
                if (layoutY >= (item.y - halfSpacing) && layoutY <= (item.y + item.height + halfSpacing)) {
                    const iconName = Icons.getBluetoothIcon(item.modelData?.icon);
                    if (iconName === "headphones" || iconName === "speaker" || (item.modelData?.icon && (item.modelData.icon.includes("head") || item.modelData.icon.includes("audio")))) {
                        return {
                            name: "btcodec",
                            item: item
                        };
                    }
                }
            }
        }

        return {
            name: "bluetooth",
            item: btIcon
        };
    }

    ColumnLayout {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.medium / 2

        // Bluetooth icon
        MaterialIcon {
            id: btIcon

            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            animate: true
            text: {
                if (!Bluetooth.defaultAdapter?.enabled) // qmllint disable unresolved-type
                    return "bluetooth_disabled";
                if (Bluetooth.devices.values.some(d => d.connected)) // qmllint disable unresolved-type
                    return "bluetooth_connected";
                return "bluetooth";
            }
            color: root.colour
        }

        // Connected bluetooth devices
        Repeater {
            id: devicesRepeater

            model: ScriptModel {
                values: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected) // qmllint disable unresolved-type
            }

            MaterialIcon {
                id: device

                required property BluetoothDevice modelData

                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                animate: true
                text: Icons.getBluetoothIcon(modelData?.icon)
                color: root.colour
                fill: 1

                SequentialAnimation on opacity {
                    running: device.modelData?.state !== BluetoothDeviceState.Connected // qmllint disable unresolved-type
                    alwaysRunToEnd: true
                    loops: Animation.Infinite

                    Anim {
                        from: 1
                        to: 0
                        duration: Tokens.anim.durations.large
                        easing: Tokens.anim.standardAccel
                    }
                    Anim {
                        from: 0
                        to: 1
                        duration: Tokens.anim.durations.large
                        easing: Tokens.anim.standardDecel
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

Column {
    id: root

    spacing: Tokens.spacing.medium
    width: Tokens.sizes.bar.batteryWidth

    StyledText {
        text: UPower.displayDevice.isLaptopBattery ? qsTr("Remaining: %1%").arg(Math.round(UPower.displayDevice.percentage * 100)) : qsTr("No battery detected")
    }

    StyledText {
        function formatSeconds(s: int, fallback: string): string {
            const day = Math.floor(s / 86400);
            const hr = Math.floor(s / 3600) % 24;
            const min = Math.floor(s / 60) % 60;

            let comps = [];
            if (day > 0)
                comps.push(`${day} days`);
            if (hr > 0)
                comps.push(`${hr} hours`);
            if (min > 0)
                comps.push(`${min} mins`);

            return comps.join(", ") || fallback;
        }

        text: UPower.displayDevice.isLaptopBattery ? qsTr("Time %1: %2").arg(UPower.onBattery ? "remaining" : "until charged").arg(UPower.onBattery ? formatSeconds(UPower.displayDevice.timeToEmpty, "Calculating...") : formatSeconds(UPower.displayDevice.timeToFull, "Fully charged!")) : qsTr("Power profile: %1").arg(PowerManagement.autoBalance ? qsTr("Auto (%1)").arg(PowerManagement.profileName) : PowerManagement.profileName)
    }

    StyledText {
        text: qsTr("Power profile: %1").arg(PowerManagement.autoBalance ? qsTr("Auto (%1)").arg(PowerManagement.profileName) : PowerManagement.profileName)
        visible: UPower.displayDevice.isLaptopBattery
    }

    Loader {
        asynchronous: true
        anchors.horizontalCenter: parent.horizontalCenter

        active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

        height: active ? ((item as Item)?.implicitHeight ?? 0) : 0

        sourceComponent: StyledRect {
            implicitWidth: child.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: child.implicitHeight + Tokens.padding.large

            color: Colours.palette.m3error
            radius: Tokens.rounding.large

            Column {
                id: child

                anchors.centerIn: parent

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -font.pointSize / 10

                        text: "warning"
                        color: Colours.palette.m3onError
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Performance Degraded")
                        color: Colours.palette.m3onError
                        font: Tokens.font.mono.builders.medium.weight(Font.Medium).build()
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -font.pointSize / 10

                        text: "warning"
                        color: Colours.palette.m3onError
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: qsTr("Reason: %1").arg(PerformanceDegradationReason.toString(PowerProfiles.degradationReason))
                    color: Colours.palette.m3onError
                }
            }
        }
    }

    StyledRect {
        id: profiles

        property string current: {
            if (PowerManagement.autoBalance)
                return autoMode.icon;
            const p = PowerProfiles.profile;
            if (p === PowerProfile.PowerSaver)
                return saver.icon;
            if (p === PowerProfile.Performance)
                return perf.icon;
            return balance.icon;
        }

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: saver.implicitHeight + balance.implicitHeight + perf.implicitHeight + autoMode.implicitHeight + Tokens.padding.extraSmall * 2 + Tokens.spacing.largeIncreased * 3
        implicitHeight: Math.max(saver.implicitHeight, balance.implicitHeight, perf.implicitHeight, autoMode.implicitHeight) + Tokens.padding.small

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        StyledRect {
            id: indicator

            color: Colours.palette.m3primary
            radius: Tokens.rounding.full
            state: profiles.current

            states: [
                State {
                    name: saver.icon

                    Fill {
                        item: saver
                    }
                },
                State {
                    name: balance.icon

                    Fill {
                        item: balance
                    }
                },
                State {
                    name: perf.icon

                    Fill {
                        item: perf
                    }
                },
                State {
                    name: autoMode.icon

                    Fill {
                        item: autoMode
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }
        }

        Profile {
            id: saver

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.extraSmall

            profile: PowerProfile.PowerSaver
            icon: "energy_savings_leaf"
        }

        Profile {
            id: balance

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: saver.right
            anchors.leftMargin: Tokens.spacing.largeIncreased

            profile: PowerProfile.Balanced
            icon: "balance"
        }

        Profile {
            id: perf

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: balance.right
            anchors.leftMargin: Tokens.spacing.largeIncreased

            profile: PowerProfile.Performance
            icon: "rocket_launch"
        }

        Profile {
            id: autoMode

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: perf.right
            anchors.leftMargin: Tokens.spacing.largeIncreased
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.extraSmall

            isAuto: true
            icon: "auto_mode"
        }
    }

    component Fill: AnchorChanges {
        required property Item item

        target: indicator
        anchors.left: item.left
        anchors.right: item.right
        anchors.top: item.top
        anchors.bottom: item.bottom
    }

    component Profile: Item {
        required property string icon
        property int profile: PowerProfile.Balanced
        property bool isAuto: false

        implicitWidth: icon.implicitHeight + Tokens.padding.small
        implicitHeight: icon.implicitHeight + Tokens.padding.small

        StateLayer {
            radius: Tokens.rounding.full
            color: profiles.current === parent.icon ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: {
                if (parent.isAuto)
                    PowerManagement.setAutoBalance(true);
                else
                    PowerManagement.setManualProfile(parent.profile);
            }
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent

            text: parent.icon
            fontStyle: Tokens.font.icon.large
            color: profiles.current === text ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            fill: profiles.current === text ? 1 : 0

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Card {
    id: root

    required property PersistentProperties visibilities

    readonly property bool hasExternalMonitor: {
        const outputs = Niri.outputs;
        if (!outputs) return false;
        for (const connector in outputs) {
            const lower = connector.toLowerCase();
            if (!lower.startsWith("edp") && !lower.startsWith("lvds") && !lower.startsWith("dsi")) {
                return true;
            }
        }
        return false;
    }

    onHasExternalMonitorChanged: {
        if (!hasExternalMonitor) {
            internalCard.focus = true;
        }
    }

    variant: Card.Variant.Elevated
    padding: Appearance.padding.xl

    radius: Appearance.rounding.large

    Column {
        id: container
        spacing: Appearance.spacing.xl

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Select Display Mode")
            font.pointSize: Appearance.font.size.large
            font.weight: 600
            color: Colours.palette.m3onSurface
        }

        Row {
            spacing: Appearance.spacing.lg

            DisplayCard {
                id: internalCard
                icon: "laptop"
                label: qsTr("Laptop Only")
                mode: "internal"

                KeyNavigation.right: root.hasExternalMonitor ? externalCard : null

                Connections {
                    target: root.visibilities

                    function onDisplaySelectChanged(): void {
                        if (root.visibilities.displaySelect) {
                            internalCard.focus = true;
                        }
                    }
                }
            }

            DisplayCard {
                id: externalCard
                icon: "desktop_windows"
                label: qsTr("External Only")
                mode: "external"
                visible: root.hasExternalMonitor

                KeyNavigation.left: internalCard
                KeyNavigation.right: extendCard
            }

            DisplayCard {
                id: extendCard
                icon: "space_dashboard"
                label: qsTr("Extend Screen")
                mode: "extend"
                visible: root.hasExternalMonitor

                KeyNavigation.left: externalCard
                KeyNavigation.right: duplicateCard
            }

            DisplayCard {
                id: duplicateCard
                icon: "screen_share"
                label: qsTr("Duplicate Screen")
                mode: "duplicate"
                visible: root.hasExternalMonitor

                KeyNavigation.left: extendCard
            }
        }
    }

    implicitWidth: container.implicitWidth + padding * 2
    implicitHeight: container.implicitHeight + padding * 2

    Timer {
        id: executionTimer
        interval: 300 // Allow overlay to fade out completely before triggering layout change
        repeat: false
        property string pendingMode
        onTriggered: {
            Quickshell.execDetached([Paths.absolutePath("~/.config/niri/niri-display.py"), pendingMode]);
        }
    }

    component DisplayCard: StyledRect {
        id: button

        required property string icon
        required property string label
        required property string mode

        implicitWidth: 160
        implicitHeight: 160

        radius: Appearance.rounding.large
        color: button.activeFocus ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

        function trigger(): void {
            executionTimer.pendingMode = button.mode;
            executionTimer.start();
            root.visibilities.displaySelect = false;
        }

        Keys.onEnterPressed: trigger()
        Keys.onReturnPressed: trigger()
        Keys.onEscapePressed: root.visibilities.displaySelect = false

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left && KeyNavigation.left) {
                KeyNavigation.left.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right && KeyNavigation.right) {
                KeyNavigation.right.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                if (event.modifiers & Qt.ShiftModifier) {
                    if (KeyNavigation.left) {
                        KeyNavigation.left.focus = true;
                        event.accepted = true;
                    }
                } else {
                    if (KeyNavigation.right) {
                        KeyNavigation.right.focus = true;
                        event.accepted = true;
                    }
                }
            }
        }

        StateLayer {
            radius: parent.radius
            color: button.activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface

            function onClicked(): void {
                button.trigger();
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Appearance.spacing.md

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.icon
                color: button.activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                font.pointSize: 40
                font.weight: 500
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.label
                color: button.activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.bodyMedium
                font.weight: 500
            }
        }
    }
}

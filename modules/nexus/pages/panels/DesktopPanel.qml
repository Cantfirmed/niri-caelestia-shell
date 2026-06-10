pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> positionItems: [
        MenuItem { text: qsTr("Top Left") },
        MenuItem { text: qsTr("Top Center") },
        MenuItem { text: qsTr("Top Right") },
        MenuItem { text: qsTr("Middle Left") },
        MenuItem { text: qsTr("Middle Center") },
        MenuItem { text: qsTr("Middle Right") },
        MenuItem { text: qsTr("Bottom Left") },
        MenuItem { text: qsTr("Bottom Center") },
        MenuItem { text: qsTr("Bottom Right") }
    ]

    readonly property var positionValues: [
        "top-left", "top-center", "top-right",
        "middle-left", "middle-center", "middle-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]

    title: qsTr("Desktop")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Desktop Clock
        SectionHeader {
            first: true
            text: qsTr("Desktop Clock")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Enabled")
            subtext: qsTr("Show a large clock on the desktop background")
            checked: Config.background.desktopClock.enabled
            onToggled: GlobalConfig.background.desktopClock.enabled = checked
        }

        SelectRow {
            Layout.fillWidth: true
            label: qsTr("Position")
            subtext: qsTr("Screen position of the clock")
            menuItems: root.positionItems
            active: {
                const idx = root.positionValues.indexOf(Config.background.desktopClock.position);
                return idx !== -1 ? root.positionItems[idx] : root.positionItems[8];
            }
            onSelected: item => {
                const idx = root.positionItems.indexOf(item);
                if (idx !== -1) {
                    GlobalConfig.background.desktopClock.position = root.positionValues[idx];
                }
            }
        }

        StepperRow {
            Layout.fillWidth: true
            last: true
            label: qsTr("Clock scale")
            subtext: qsTr("Size scale factor of the clock")
            value: Config.background.desktopClock.scale
            from: 0.5
            to: 3.0
            stepSize: 0.1
            onMoved: v => GlobalConfig.background.desktopClock.scale = v
        }

        // Clock Background
        SectionHeader {
            text: qsTr("Clock Background")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Background enabled")
            subtext: qsTr("Show a card behind the clock")
            checked: Config.background.desktopClock.background.enabled
            onToggled: GlobalConfig.background.desktopClock.background.enabled = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Blur background")
            subtext: qsTr("Apply blur under the clock background (disabled in Game Mode)")
            checked: Config.background.desktopClock.background.blur
            onToggled: GlobalConfig.background.desktopClock.background.blur = checked
        }

        SliderRow {
            Layout.fillWidth: true
            last: true
            label: qsTr("Background opacity")
            valueLabel: Math.round(value * 100) + "%"
            value: Config.background.desktopClock.background.opacity
            onMoved: v => GlobalConfig.background.desktopClock.background.opacity = v
        }

        // Clock Shadow
        SectionHeader {
            text: qsTr("Clock Shadow")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Shadow enabled")
            subtext: qsTr("Draw a drop shadow behind the clock text")
            checked: Config.background.desktopClock.shadow.enabled
            onToggled: GlobalConfig.background.desktopClock.shadow.enabled = checked
        }

        SliderRow {
            Layout.fillWidth: true
            label: qsTr("Shadow opacity")
            valueLabel: Math.round(value * 100) + "%"
            value: Config.background.desktopClock.shadow.opacity
            onMoved: v => GlobalConfig.background.desktopClock.shadow.opacity = v
        }

        SliderRow {
            Layout.fillWidth: true
            last: true
            label: qsTr("Shadow blur")
            valueLabel: Math.round(value * 100) + "%"
            value: Config.background.desktopClock.shadow.blur
            onMoved: v => GlobalConfig.background.desktopClock.shadow.blur = v
        }

        // Music Visualizer
        SectionHeader {
            text: qsTr("Music Visualizer")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Enabled")
            subtext: qsTr("Show a music visualizer on the desktop background")
            checked: Config.background.visualiser.enabled
            onToggled: GlobalConfig.background.visualiser.enabled = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Auto-hide")
            subtext: qsTr("Hide the visualizer when active windows exist on the workspace")
            checked: Config.background.visualiser.autoHide
            onToggled: GlobalConfig.background.visualiser.autoHide = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Blur background")
            subtext: qsTr("Apply blur to the wallpaper under visualizer bars (disabled in Game Mode)")
            checked: Config.background.visualiser.blur
            onToggled: GlobalConfig.background.visualiser.blur = checked
        }

        StepperRow {
            Layout.fillWidth: true
            label: qsTr("Bar rounding")
            subtext: qsTr("Rounding factor for the visualizer bars")
            value: Config.background.visualiser.rounding
            from: 0.0
            to: 3.0
            stepSize: 0.1
            onMoved: v => GlobalConfig.background.visualiser.rounding = v
        }

        StepperRow {
            Layout.fillWidth: true
            last: true
            label: qsTr("Bar spacing")
            subtext: qsTr("Spacing factor between visualizer bars")
            value: Config.background.visualiser.spacing
            from: 0.0
            to: 5.0
            stepSize: 0.1
            onMoved: v => GlobalConfig.background.visualiser.spacing = v
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Utilities")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            last: true
            text: qsTr("Enabled")
            checked: Config.utilities.enabled
            onToggled: GlobalConfig.utilities.enabled = checked
        }

        SectionHeader {
            text: qsTr("Toasts")
        }

        StepperRow {
            Layout.fillWidth: true
            first: true
            label: qsTr("Max toasts")
            subtext: qsTr("Maximum number of notifications shown simultaneously")
            value: Config.utilities.maxToasts
            from: 1
            to: 10
            stepSize: 1
            onMoved: v => GlobalConfig.utilities.maxToasts = v
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("VPN Status changes")
            checked: Config.utilities.toasts.vpnChanged
            onToggled: GlobalConfig.utilities.toasts.vpnChanged = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Audio Output changes")
            checked: Config.utilities.toasts.audioOutputChanged
            onToggled: GlobalConfig.utilities.toasts.audioOutputChanged = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Caps Lock changes")
            checked: Config.utilities.toasts.capsLockChanged
            onToggled: GlobalConfig.utilities.toasts.capsLockChanged = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Num Lock changes")
            checked: Config.utilities.toasts.numLockChanged
            onToggled: GlobalConfig.utilities.toasts.numLockChanged = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Now Playing notifications")
            checked: Config.utilities.toasts.nowPlaying
            onToggled: GlobalConfig.utilities.toasts.nowPlaying = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: qsTr("DND status changes")
            checked: Config.utilities.toasts.dndChanged
            onToggled: GlobalConfig.utilities.toasts.dndChanged = checked
        }
    }
}

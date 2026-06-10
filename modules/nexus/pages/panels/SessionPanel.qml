pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Session")
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
            text: qsTr("Enabled")
            checked: Config.session.enabled
            onToggled: GlobalConfig.session.enabled = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Vim Keybinds")
            checked: Config.session.vimKeybinds
            onToggled: GlobalConfig.session.vimKeybinds = checked
        }

        StepperRow {
            Layout.fillWidth: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the power menu opens")
            value: Config.session.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.session.dragThreshold = v
        }

        InputRow {
            Layout.fillWidth: true
            last: true
            label: qsTr("Session GIF")
            subtext: qsTr("Path to the GIF shown in the Ctrl+Alt+Delete Menu")
            text: Config.paths.sessionGif
            onEditingFinished: text => {
                if (GlobalConfig.paths.sessionGif !== text) {
                    GlobalConfig.paths.sessionGif = text;
                }
            }
        }
    }
}

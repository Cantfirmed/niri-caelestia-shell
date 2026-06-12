pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Plugins")
    isSubPage: false

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Readers")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Manga reader")
            subtext: qsTr("Browse and read manga, manhwa, and manhua")
            checked: GlobalConfig.extra.manga
            onToggled: {
                GlobalConfig.extra.manga = checked
                if (!checked) {
                    const v = Visibilities.getForActive()
                    if (v) v.manga = false
                }
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: qsTr("Novel reader")
            subtext: qsTr("Browse and read light novels and web novels")
            checked: GlobalConfig.extra.novel
            onToggled: {
                GlobalConfig.extra.novel = checked
                if (!checked) {
                    const v = Visibilities.getForActive()
                    if (v) v.novel = false
                }
            }
        }
    }
}

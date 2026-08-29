import "center"
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    required property var lock
    readonly property real centerScale: Math.min(1, (lock.screen?.height ?? 1440) / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

    Layout.preferredWidth: centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    spacing: Tokens.spacing.largeIncreased

    // Top flex spacer to push the content down and center it vertically
    Item {
        Layout.fillHeight: true
        Layout.preferredHeight: 1
    }

    Clock {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.padding.large
        Layout.bottomMargin: Tokens.spacing.medium
        centerScale: root.centerScale
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter

        text: Time.format("dddd • d MMM").toUpperCase()
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
    }

    ProfilePic {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.extraExtraLarge * root.centerScale
        Layout.bottomMargin: Tokens.spacing.extraLarge * root.centerScale
        centerWidth: root.centerWidth
    }

    PasswordInput {
        Layout.alignment: Qt.AlignHCenter
        centerWidth: root.centerWidth
        lock: root.lock
    }

    StateMessage {
        Layout.fillWidth: true
        pam: root.lock.pam
    }

    // ── Session controls ───────────────────────────────────────────────────────
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.medium
        Layout.bottomMargin: Tokens.spacing.medium
        spacing: Tokens.spacing.extraExtraLarge

        component SessionBtn: IconButton {
            id: sBtn
            required property var command

            implicitWidth: 48 * root.centerScale
            implicitHeight: 48 * root.centerScale
            radius: Tokens.rounding.full
            inactiveColour: "transparent"
            inactiveOnColour: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.icon.builders.large.scale(1.3 * root.centerScale).build()

            onClicked: Quickshell.execDetached(sBtn.command)
        }

        SessionBtn {
            icon: Config.session.icons.logout
            command: Config.session.commands.logout
        }
        SessionBtn {
            icon: Config.session.icons.sleep
            command: Config.session.commands.sleep
        }
        SessionBtn {
            icon: Config.session.icons.shutdown
            command: Config.session.commands.shutdown
        }
    }

    // Bottom flex spacer
    Item {
        Layout.fillHeight: true
        Layout.preferredHeight: 1
    }
}

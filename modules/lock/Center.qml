import "center"
import Quickshell
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    required property var lock
    readonly property real fontScale: Math.max(0.5, Config.appearance.font.scale)
    readonly property real centerScale: {
        const ref = root.height > 0 ? root.height / (976 * Tokens.uiScale) : ((lock.screen?.height ?? 1440) / Tokens.uiScale) / 1440;
        return Math.max(0.45, Math.min(1, ref));
    }
    readonly property real clockScale: centerScale * Math.min(1.1, fontScale) / fontScale
    readonly property int centerWidth: {
        const scaled = Math.round(Tokens.sizes.lock.centerWidth * centerScale);
        const maxFromParent = parent && parent.width > 0 ? Math.round(parent.width * 0.45) : scaled;
        return Math.min(scaled, maxFromParent);
    }
    readonly property int fixedChildrenHeight: clock.implicitHeight + dateText.implicitHeight
        + passwordInput.implicitHeight + stateMessage.implicitHeight + sessionRow.implicitHeight
        + clock.Layout.topMargin + clock.Layout.bottomMargin
        + sessionRow.Layout.topMargin + sessionRow.Layout.bottomMargin
        + spacing * 7
    readonly property int maxProfileHeight: Math.max(Math.round(64 * Tokens.uiScale), root.height - fixedChildrenHeight - profilePic.Layout.topMargin - profilePic.Layout.bottomMargin)

    Layout.preferredWidth: centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    spacing: Math.min(Math.round(Tokens.spacing.largeIncreased * centerScale), Math.max(4, Math.round(root.height * 0.02)))

    // Top flex spacer to push the content down and center it vertically
    Item {
        Layout.fillHeight: true
        Layout.preferredHeight: 1
    }

    Clock {
        id: clock

        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Math.round(Tokens.padding.large * root.centerScale)
        Layout.bottomMargin: Math.round(Tokens.spacing.medium * root.centerScale)
        centerScale: root.clockScale
    }

    StyledText {
        id: dateText

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight

        text: Time.format("dddd • d MMM").toUpperCase()
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
    }

    ProfilePic {
        id: profilePic

        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Math.round(Tokens.spacing.extraLarge * root.centerScale)
        Layout.bottomMargin: Math.round(Tokens.spacing.large * root.centerScale)
        centerWidth: root.centerWidth
        maxHeight: root.height > 0 ? root.maxProfileHeight : -1
    }

    PasswordInput {
        id: passwordInput

        Layout.alignment: Qt.AlignHCenter
        centerScale: Math.max(0.8, root.centerScale)
        centerWidth: root.centerWidth
        lock: root.lock
    }

    StateMessage {
        id: stateMessage

        Layout.fillWidth: true
        pam: root.lock.pam
    }

    // ── Session controls ───────────────────────────────────────────────────────
    RowLayout {
        id: sessionRow

        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Math.round(Tokens.spacing.medium * root.centerScale)
        Layout.bottomMargin: Math.round(Tokens.spacing.medium * root.centerScale)
        spacing: Math.round(Tokens.spacing.extraExtraLarge * root.centerScale)

        component SessionBtn: IconButton {
            id: sBtn
            required property var command

            readonly property real iconScale: Math.min(1.25, root.fontScale) / root.fontScale

            font: Tokens.font.icon.builders.large.scale(1.3 * root.centerScale * iconScale).build()
            implicitWidth: Math.max(Math.round(48 * Tokens.uiScale * root.centerScale), Math.round(font.pointSize * 1.33 + Tokens.padding.small * 2 * root.centerScale))
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            inactiveColour: "transparent"
            inactiveOnColour: Colours.palette.m3onSurfaceVariant

            function exec(): void {
                if (sBtn === sReboot || sBtn === sShutdown)
                    Notifs.clearRebootNotifs();
                if (!SessionManager.exec(sBtn.command))
                    Quickshell.execDetached(sBtn.command);
            }

            onClicked: exec()
        }

        SessionBtn {
            id: sSleep
            icon: Config.session.icons.sleep || "dark_mode"
            command: Config.session.commands.sleep
        }
        SessionBtn {
            id: sReboot
            icon: Config.session.icons.reboot
            command: Config.session.commands.reboot
        }
        SessionBtn {
            id: sShutdown
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

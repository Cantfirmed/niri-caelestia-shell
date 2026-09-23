pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    width: Tokens.sizes.bar.networkWidth
    spacing: Tokens.spacing.small

    Timer {
        running: root.visible
        repeat: true
        triggeredOnStart: true
        interval: 3000
        onTriggered: {
            VPN.checkStatus();
            if (VPN.connected)
                VPN.refreshStats();
        }
    }

    // Header Row
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.medium
        Layout.rightMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: "vpn_key"
            color: VPN.connected ? Colours.palette.m3primary : Colours.palette.m3onSurface
            fontStyle: Tokens.font.icon.medium
            fill: VPN.connected ? 1 : 0
            animate: true
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("VPN")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        StyledText {
            text: {
                if (VPN.connecting)
                    return qsTr("Connecting...");
                if (VPN.disconnecting)
                    return qsTr("Disconnecting...");
                if (VPN.connected)
                    return qsTr("Connected");
                return qsTr("Off");
            }
            color: {
                if (VPN.connected)
                    return Colours.palette.m3primary;
                if (VPN.connecting || VPN.disconnecting)
                    return Colours.palette.m3secondary;
                return Colours.palette.m3outline;
            }
            font: Tokens.font.label.small
            animate: true
        }
    }

    // Master Toggle
    Toggle {
        label: qsTr("Enabled")
        checked: VPN.connected
        toggle.disabled: VPN.connecting || VPN.disconnecting || VPN.providers.length === 0
        toggle.onToggled: VPN.toggle()
    }

    // Active Connection Info
    RowLayout {
        visible: VPN.connected
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Tunnel: %1").arg(VPN.active.interface || "active")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }

        RowLayout {
            visible: VPN.pingMs >= 0
            spacing: Tokens.spacing.extraSmall

            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 8
                implicitHeight: 8
                radius: Tokens.rounding.full
                color: VPN.pingMs <= 80 ? Colours.palette.m3primary : VPN.pingMs <= 150 ? Colours.palette.m3tertiary : Colours.palette.m3error
            }

            StyledText {
                text: qsTr("%1 ms").arg(VPN.pingMs)
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }

    // Section Subtitle
    StyledText {
        Layout.topMargin: Tokens.spacing.extraSmall
        Layout.rightMargin: Tokens.padding.extraSmall
        text: {
            if (VPN.providers.length === 0)
                return qsTr("No VPN providers configured");
            return qsTr("Providers (%1 configured)").arg(VPN.providers.length);
        }
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    // Provider List
    Repeater {
        model: ScriptModel {
            values: [...VPN.providers]
        }

        StyledRect {
            id: providerRow

            required property var modelData
            readonly property bool isSelected: modelData.providerId === VPN.selectedProvider
            readonly property bool isConnected: isSelected && VPN.connected
            readonly property bool isPending: isSelected && (VPN.connecting || VPN.disconnecting)

            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.extraSmall
            implicitHeight: providerLayout.implicitHeight + Tokens.padding.extraSmall * 2
            radius: Tokens.rounding.small
            color: isConnected ? Qt.alpha(Colours.palette.m3primaryContainer, 0.45) : isSelected ? Qt.alpha(Colours.palette.m3secondaryContainer, 0.35) : "transparent"

            Behavior on color {
                CAnim {}
            }

            StateLayer {
                anchors.fill: parent
                radius: parent.radius
                onClicked: {
                    VPN.selectAndConnect(providerRow.modelData.index);
                }
            }

            RowLayout {
                id: providerLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.small

                StyledRect {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Tokens.rounding.full
                    color: providerRow.isConnected ? Colours.palette.m3primary : providerRow.isSelected ? Colours.palette.m3secondary : Colours.palette.m3surfaceContainerHighest

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: providerRow.isConnected ? "vpn_key" : "shield"
                        fontStyle: Tokens.font.icon.small
                        fill: providerRow.isConnected ? 1 : 0
                        color: providerRow.isConnected ? Colours.palette.m3onPrimary : providerRow.isSelected ? Colours.palette.m3onSecondary : Colours.palette.m3onSurfaceVariant
                        animate: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: providerRow.modelData.displayName
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (providerRow.isConnected)
                                return qsTr("Connected • %1").arg(providerRow.modelData.iface || "active");
                            if (providerRow.isPending)
                                return VPN.connecting ? qsTr("Connecting...") : qsTr("Disconnecting...");
                            if (providerRow.isSelected)
                                return qsTr("Selected • tap to connect");
                            return qsTr("Tap to switch & connect");
                        }
                        color: providerRow.isConnected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                StyledRect {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Tokens.rounding.full
                    color: providerRow.isConnected ? Colours.palette.m3primaryContainer : "transparent"

                    CircularIndicator {
                        anchors.fill: parent
                        running: providerRow.isPending
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !providerRow.isPending
                        text: providerRow.isConnected ? "check" : providerRow.isSelected ? "radio_button_checked" : "radio_button_unchecked"
                        color: providerRow.isConnected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.small
                        animate: true
                    }
                }
            }
        }
    }

    // Open Settings Button
    IconTextButton {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.extraSmall
        text: qsTr("Open VPN settings")
        icon: "settings"
        onClicked: root.popouts.detachRequested("vpn")
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: parent.label
        }

        StyledSwitch {
            id: toggle
        }
    }
}

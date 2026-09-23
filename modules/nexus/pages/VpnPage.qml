pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("VPN")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

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

        // ---- Master Toggle ---------------------------------------------------
        ToggleRow {
            first: true
            text: qsTr("VPN")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: VPN.connected
            disabled: VPN.connecting || VPN.disconnecting || VPN.providers.length === 0
            onToggled: VPN.toggle()
        }

        // ---- Providers List --------------------------------------------------
        ItemList {
            id: providerList

            showList: true
            placeholderIcon: "vpn_key_off"
            placeholderText: qsTr("No VPN providers configured")

            model: ScriptModel {
                values: [...VPN.providers]
            }

            delegate: Item {
                id: provider

                required property var modelData
                readonly property bool isSelected: modelData.providerId === VPN.selectedProvider
                readonly property bool isConnected: isSelected && VPN.connected

                anchors.left: providerList.list.contentItem.left
                anchors.right: providerList.list.contentItem.right
                implicitHeight: providerLayout.implicitHeight + providerLayout.anchors.margins * 2

                StateLayer {
                    radius: Tokens.rounding.extraSmall
                    onClicked: {
                        if (!provider.isSelected) {
                            VPN.selectAndConnect(provider.modelData.index);
                        } else if (!VPN.connected) {
                            VPN.connect();
                        } else {
                            VPN.disconnect();
                        }
                    }
                }

                RowLayout {
                    id: providerLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: providerIcon.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: provider.isConnected ? Colours.palette.m3primaryContainer : provider.isSelected ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHighest

                        MaterialIcon {
                            id: providerIcon

                            anchors.centerIn: parent
                            text: provider.isConnected || provider.isSelected ? "vpn_key" : "vpn_key_off"
                            fill: provider.isConnected ? 1 : 0
                            color: provider.isConnected ? Colours.palette.m3onPrimaryContainer : provider.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                            animate: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: provider.modelData.displayName
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (!provider.isSelected)
                                    return qsTr("Tap to connect");
                                if (VPN.connecting)
                                    return qsTr("Connecting...");
                                if (VPN.disconnecting)
                                    return qsTr("Disconnecting...");
                                switch (VPN.status.state) {
                                case "connected":
                                    return qsTr("Connected");
                                case "needs-auth":
                                    return VPN.status.reason || qsTr("Authentication required");
                                case "error":
                                    return VPN.status.reason || qsTr("An error occurred");
                                default:
                                    return qsTr("Ready to connect");
                                }
                            }
                            color: {
                                if (!provider.isSelected)
                                    return Colours.palette.m3onSurfaceVariant;
                                switch (VPN.status.state) {
                                case "connected":
                                    return Colours.palette.m3primary;
                                case "needs-auth":
                                case "error":
                                    return Colours.palette.m3error;
                                default:
                                    return Colours.palette.m3secondary;
                                }
                            }
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            animate: true
                        }
                    }

                    Item {
                        Layout.rightMargin: Tokens.spacing.small
                        opacity: provider.isConnected ? 1 : 0
                        visible: opacity > 0

                        implicitWidth: provider.isConnected ? providerDetailRow.implicitWidth : 0
                        implicitHeight: providerDetailRow.implicitHeight

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        RowLayout {
                            id: providerDetailRow

                            anchors.right: parent.right
                            spacing: Tokens.spacing.large

                            ColumnLayout {
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: qsTr("Interface")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: provider.modelData.iface || "-"
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            ColumnLayout {
                                spacing: 0
                                visible: VPN.pingMs >= 0

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: qsTr("Latency")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: Tokens.spacing.small

                                    StyledRect {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: Math.round(Tokens.font.body.small.pointSize * 0.7)
                                        implicitHeight: implicitWidth
                                        radius: Tokens.rounding.full
                                        color: VPN.pingMs <= 80 ? Colours.palette.m3primary : VPN.pingMs <= 150 ? Colours.palette.m3tertiary : Colours.palette.m3error
                                    }

                                    StyledText {
                                        text: qsTr("%1 ms").arg(VPN.pingMs)
                                        color: Colours.palette.m3outline
                                        font: Tokens.font.label.small
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    IconButton {
                        implicitWidth: implicitHeight + (Tokens.padding.large - padding) * 2
                        type: IconButton.Tonal
                        isRound: true
                        icon: "edit"
                        onClicked: {
                            root.nState.editingVpnIndex = provider.modelData.index;
                            root.nState.vpnPreset = "";
                            root.nState.openSubPage(1);
                        }
                    }
                }
            }
        }

        // ---- Add Provider Button ---------------------------------------------
        RowButton {
            last: true
            icon: "add"
            text: qsTr("Add provider")
            subtext: qsTr("Configure a new VPN connection")
            trailingIcon: "chevron_right"
            onClicked: {
                root.nState.editingVpnIndex = -1;
                root.nState.vpnPreset = "";
                root.nState.openSubPage(1);
            }
        }

        // ---- Active Connection Details ---------------------------------------
        SectionHeader {
            Layout.topMargin: Tokens.spacing.large
            text: qsTr("Connection details")
            visible: VPN.connected
        }

        StyledRect {
            Layout.fillWidth: true
            visible: VPN.connected
            radius: Tokens.rounding.extraLarge
            color: Colours.palette.m3surfaceContainerHigh
            implicitHeight: activeDetailsLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: activeDetailsLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "verified_user"
                            fill: 1
                            color: Colours.palette.m3onPrimaryContainer
                            fontStyle: Tokens.font.icon.medium
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: VPN.active.displayName
                            font: Tokens.font.title.small
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: qsTr("Secure tunnel active on %1").arg(VPN.active.interface || "virtual interface")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    TextButton {
                        type: TextButton.Tonal
                        isRound: true
                        text: qsTr("Disconnect")
                        onClicked: VPN.disconnect()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraLarge

                    ColumnLayout {
                        spacing: 2
                        StyledText {
                            text: qsTr("Interface")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledText {
                            text: VPN.active.interface || qsTr("Default")
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3onSurface
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        StyledText {
                            text: qsTr("Status")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledText {
                            text: qsTr("Connected")
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3primary
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        visible: VPN.pingMs >= 0
                        StyledText {
                            text: qsTr("Ping")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledText {
                            text: qsTr("%1 ms").arg(VPN.pingMs)
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3onSurface
                        }
                    }
                }
            }
        }

        // ---- Quick Presets ---------------------------------------------------
        SectionHeader {
            Layout.topMargin: Tokens.spacing.large
            text: qsTr("Quick setup presets")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.extraSmall
            text: qsTr("Select a preset to quickly configure your VPN service:")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        RowButton {
            first: true
            icon: "shield"
            text: qsTr("WireGuard")
            subtext: qsTr("Fast, modern, and secure kernel-level VPN (wg-quick)")
            trailingIcon: "chevron_right"
            onClicked: {
                root.nState.editingVpnIndex = -1;
                root.nState.vpnPreset = "wireguard";
                root.nState.openSubPage(1);
            }
        }

        RowButton {
            icon: "hub"
            text: qsTr("Tailscale")
            subtext: qsTr("Zero-config mesh VPN based on WireGuard protocol")
            trailingIcon: "chevron_right"
            onClicked: {
                root.nState.editingVpnIndex = -1;
                root.nState.vpnPreset = "tailscale";
                root.nState.openSubPage(1);
            }
        }

        RowButton {
            icon: "lan"
            text: qsTr("NetBird")
            subtext: qsTr("Zero-trust peer-to-peer overlay network with SSO")
            trailingIcon: "chevron_right"
            onClicked: {
                root.nState.editingVpnIndex = -1;
                root.nState.vpnPreset = "netbird";
                root.nState.openSubPage(1);
            }
        }

        RowButton {
            icon: "cloud"
            text: qsTr("Cloudflare WARP")
            subtext: qsTr("Fast, private DNS and tunnel via Cloudflare network")
            trailingIcon: "chevron_right"
            onClicked: {
                root.nState.editingVpnIndex = -1;
                root.nState.vpnPreset = "warp";
                root.nState.openSubPage(1);
            }
        }

        RowButton {
            last: true
            icon: "lock"
            text: qsTr("OpenVPN")
            subtext: qsTr("Standard SSL/TLS VPN client configuration")
            trailingIcon: "chevron_right"
            onClicked: {
                root.nState.editingVpnIndex = -1;
                root.nState.vpnPreset = "openvpn";
                root.nState.openSubPage(1);
            }
        }
    }
}

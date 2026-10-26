pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus

StyledRect {
    id: root

    required property ScreenState screenState

    readonly property real nonAnimHeight: layout.implicitHeight + layout.anchors.margins * 2

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    Timer {
        running: root.visible
        repeat: true
        interval: 3000
        triggeredOnStart: true
        onTriggered: {
            VPN.checkStatus();
            if (VPN.connected)
                VPN.refreshStats();
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        // Header Row
        RowLayout {
            id: headerRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Tokens.padding.large

                radius: Tokens.rounding.full
                color: VPN.connected ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: VPN.connected ? "vpn_key" : "vpn_key_off"
                    color: VPN.connected ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.builders.large.scale(1.15).build()
                    animate: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("VPN")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (VPN.connecting)
                            return qsTr("Connecting to %1...").arg(VPN.active.displayName || "VPN");
                        if (VPN.disconnecting)
                            return qsTr("Disconnecting...");
                        if (VPN.connected)
                            return qsTr("Connected • %1").arg(VPN.active.displayName || "VPN");
                        if (VPN.status.state === "needs-auth")
                            return VPN.status.reason || qsTr("Authentication required");
                        if (VPN.status.state === "error")
                            return VPN.status.reason || qsTr("Connection error");
                        if (VPN.providers.length > 0 && VPN.active.displayName)
                            return qsTr("Disconnected • %1").arg(VPN.active.displayName);
                        return qsTr("Disconnected");
                    }
                    color: {
                        if (VPN.connected)
                            return Colours.palette.m3primary;
                        if (VPN.status.state === "needs-auth" || VPN.status.state === "error")
                            return Colours.palette.m3error;
                        return Colours.palette.m3onSurfaceVariant;
                    }
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                    animate: true
                }
            }

            StyledSwitch {
                checked: VPN.connected
                disabled: VPN.connecting || VPN.disconnecting || VPN.providers.length === 0
                onToggled: VPN.toggle()
            }
        }

        // Empty state when no providers exist
        ColumnLayout {
            Layout.fillWidth: true
            visible: VPN.providers.length === 0
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("No VPN providers configured")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }

            TextButton {
                Layout.fillWidth: true
                type: TextButton.Tonal
                text: qsTr("Configure VPN in Settings")
                isRound: true
                onClicked: {
                    root.screenState.utilities = false;
                    WindowFactory.create();
                }
            }
        }

        // Provider Selector Section
        ColumnLayout {
            Layout.fillWidth: true
            visible: VPN.providers.length > 0
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Choose a VPN")
                    font: Tokens.font.label.medium
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    text: qsTr("%1 available").arg(VPN.providers.length)
                    font: Tokens.font.label.small
                    color: Colours.palette.m3outline
                }
            }

            Repeater {
                model: ScriptModel {
                    values: [...VPN.providers]
                }

                delegate: StyledRect {
                    id: providerItem

                    required property var modelData
                    readonly property bool isSelected: modelData.providerId === VPN.selectedProvider
                    readonly property bool isConnected: isSelected && VPN.connected
                    readonly property bool isBusy: isSelected && (VPN.connecting || VPN.disconnecting)

                    Layout.fillWidth: true
                    implicitHeight: providerRow.implicitHeight + Tokens.padding.medium * 2
                    radius: Tokens.rounding.medium

                    color: providerItem.isConnected
                        ? Colours.palette.m3primaryContainer
                        : providerItem.isSelected
                            ? Colours.palette.m3secondaryContainer
                            : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

                    StateLayer {
                        radius: parent.radius
                        disabled: providerItem.isBusy
                        onClicked: VPN.selectAndConnect(providerItem.modelData.index)
                    }

                    RowLayout {
                        id: providerRow

                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.large
                        anchors.rightMargin: Tokens.padding.large
                        spacing: Tokens.spacing.medium

                        StyledRect {
                            implicitWidth: implicitHeight
                            implicitHeight: providerIcon.implicitHeight + Tokens.padding.small * 2
                            radius: Tokens.rounding.full
                            color: providerItem.isConnected
                                ? Colours.palette.m3primary
                                : providerItem.isSelected
                                    ? Colours.palette.m3secondary
                                    : Colours.palette.m3surfaceContainerHigh

                            MaterialIcon {
                                id: providerIcon

                                anchors.centerIn: parent
                                text: providerItem.isConnected ? "shield" : "vpn_key"
                                fontStyle: Tokens.font.icon.small
                                color: providerItem.isConnected
                                    ? Colours.palette.m3onPrimary
                                    : providerItem.isSelected
                                        ? Colours.palette.m3onSecondary
                                        : Colours.palette.m3onSurfaceVariant
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: providerItem.modelData.displayName
                                font: providerItem.isSelected ? Tokens.font.body.builders.medium.weight(Font.Medium).build() : Tokens.font.body.medium
                                color: providerItem.isConnected
                                    ? Colours.palette.m3onPrimaryContainer
                                    : providerItem.isSelected
                                        ? Colours.palette.m3onSecondaryContainer
                                        : Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    if (providerItem.isBusy)
                                        return VPN.connecting ? qsTr("Connecting...") : qsTr("Disconnecting...");
                                    if (providerItem.isConnected) {
                                        let detail = qsTr("Connected");
                                        if (VPN.pingMs > 0)
                                            detail += ` • ${VPN.pingMs} ms`;
                                        if (providerItem.modelData.iface)
                                            detail += ` (${providerItem.modelData.iface})`;
                                        return detail;
                                    }
                                    if (providerItem.isSelected)
                                        return qsTr("Selected • Tap to connect");
                                    const iface = providerItem.modelData.iface || providerItem.modelData.name;
                                    return iface ? qsTr("%1 • Tap to connect").arg(iface) : qsTr("Tap to connect");
                                }
                                font: Tokens.font.label.small
                                color: providerItem.isConnected
                                    ? Colours.palette.m3primary
                                    : providerItem.isSelected
                                        ? Colours.palette.m3secondary
                                        : Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                        // Right-hand indicator or connect icon
                        Item {
                            implicitWidth: rightIcon.implicitWidth
                            implicitHeight: rightIcon.implicitHeight

                            CircularIndicator {
                                anchors.centerIn: parent
                                implicitSize: 18
                                strokeWidth: 2
                                running: providerItem.isBusy
                                visible: providerItem.isBusy
                            }

                            MaterialIcon {
                                id: rightIcon

                                anchors.centerIn: parent
                                visible: !providerItem.isBusy
                                text: providerItem.isConnected ? "link_off" : providerItem.isSelected ? "play_arrow" : "chevron_right"
                                fontStyle: Tokens.font.icon.medium
                                color: providerItem.isConnected
                                    ? Colours.palette.m3primary
                                    : providerItem.isSelected
                                        ? Colours.palette.m3secondary
                                        : Colours.palette.m3outline
                            }
                        }
                    }
                }
            }
        }

        // Live stats row when connected
        RowLayout {
            Layout.fillWidth: true
            visible: VPN.connected
            spacing: Tokens.spacing.small

            Chip {
                visible: VPN.interfaceName.length > 0
                icon: "lan"
                text: VPN.interfaceName
                selected: false
            }

            Chip {
                visible: VPN.pingMs >= 0
                icon: "speed"
                text: qsTr("%1 ms").arg(VPN.pingMs)
                selected: false
            }

            Chip {
                visible: VPN.bytesIn.length > 0
                icon: "arrow_downward"
                text: VPN.bytesIn
                selected: false
            }

            Chip {
                visible: VPN.bytesOut.length > 0
                icon: "arrow_upward"
                text: VPN.bytesOut
                selected: false
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // Footer / Manage button
        RowLayout {
            Layout.fillWidth: true
            visible: VPN.providers.length > 0

            Item {
                Layout.fillWidth: true
            }

            ButtonRow {
                TextButton {
                    type: TextButton.Text
                    isRound: true
                    text: qsTr("Manage VPNs in Settings")
                    onClicked: {
                        root.screenState.utilities = false;
                        WindowFactory.create();
                    }
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}

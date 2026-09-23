pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Add or edit a VPN provider. editingVpnIndex (-1 = add) is read from NexusState.
PageBase {
    id: root

    readonly property int editIndex: nState.editingVpnIndex
    readonly property bool editing: editIndex >= 0
    readonly property var existing: editing ? (VPN.providers[editIndex] ?? null) : null

    function splitCmd(arr: var): string {
        return arr?.join(" ") ?? "";
    }

    function joinCmd(str: string): var {
        const t = str.trim();
        return t.length > 0 ? t.split(/\s+/) : [];
    }

    function arrEq(a: var, b: var): bool {
        return a.length === b.length && a.every((x, i) => x === b[i]);
    }

    function submit(): void {
        const name = nameField.text.trim();
        if (name.length === 0) {
            nameField.isError = true;
            nameField.forceActiveFocus();
            return;
        }

        const data = {
            name: name,
            displayName: displayField.text.trim() || name,
            interface: interfaceField.text.trim(),
            connectCmd: joinCmd(connectField.text),
            disconnectCmd: joinCmd(disconnectField.text)
        };

        if (editing) {
            const needsReload = existing.id === VPN.selectedProvider && VPN.connected && (existing.name !== name || existing.interface !== data.interface || !arrEq(existing.connectCmd, data.connectCmd) || !arrEq(existing.disconnectCmd, data.disconnectCmd));
            if (needsReload)
                VPN.disconnect();
            VPN.updateProvider(editIndex, data);
            if (needsReload) {
                if (!VPN.connecting && !VPN.disconnecting) {
                    VPN.connect();
                } else if (VPN.disconnecting) {
                    let onConnChanged = () => {
                        if (onConnChanged && !VPN.disconnecting) {
                            VPN.disconnectingChanged.disconnect(onConnChanged);
                            onConnChanged = null;
                            if (!VPN.connected)
                                VPN.connect();
                        }
                    };
                    VPN.disconnectingChanged.connect(onConnChanged);
                }
            }
        } else {
            VPN.addProvider(data);
        }

        nState.closeSubPage();
    }

    function applyPreset(preset: string): void {
        switch (preset) {
        case "wireguard":
            nameField.text = "wireguard";
            displayField.text = "WireGuard";
            interfaceField.text = "wg0";
            connectField.text = "wg-quick up wg0";
            disconnectField.text = "wg-quick down wg0";
            break;
        case "tailscale":
            nameField.text = "tailscale";
            displayField.text = "Tailscale";
            interfaceField.text = "tailscale0";
            connectField.text = "tailscale up";
            disconnectField.text = "tailscale down";
            break;
        case "warp":
            nameField.text = "warp";
            displayField.text = "Cloudflare WARP";
            interfaceField.text = "cloudflarewarp";
            connectField.text = "warp-cli connect";
            disconnectField.text = "warp-cli disconnect";
            break;
        case "netbird":
            nameField.text = "netbird";
            displayField.text = "NetBird";
            interfaceField.text = "wt0";
            connectField.text = "netbird up";
            disconnectField.text = "netbird down";
            break;
        case "openvpn":
            nameField.text = "openvpn";
            displayField.text = "OpenVPN";
            interfaceField.text = "tun0";
            connectField.text = "openvpn --config /etc/openvpn/client.ovpn";
            disconnectField.text = "killall openvpn";
            break;
        case "custom":
            nameField.text = "";
            displayField.text = "";
            interfaceField.text = "";
            connectField.text = "";
            disconnectField.text = "";
            break;
        }
    }

    title: editing ? Tr.tr("Edit VPN provider") : Tr.tr("Add VPN provider")
    isSubPage: true

    Component.onCompleted: {
        if (existing) {
            nameField.text = existing.name;
            displayField.text = existing.displayName;
            interfaceField.text = existing.interface;
            connectField.text = splitCmd(existing.connectCmd);
            disconnectField.text = splitCmd(existing.disconnectCmd);
        } else if (nState.vpnPreset) {
            applyPreset(nState.vpnPreset);
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true
            visible: !root.editing
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("Preset:")
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurfaceVariant
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: [
                        { id: "wireguard", label: "WireGuard" },
                        { id: "tailscale", label: "Tailscale" },
                        { id: "netbird", label: "NetBird" },
                        { id: "warp", label: "WARP" },
                        { id: "openvpn", label: "OpenVPN" },
                        { id: "custom", label: "Custom" }
                    ]

                    TextButton {
                        required property var modelData
                        isRound: true
                        type: nameField.text === modelData.id ? TextButton.Filled : TextButton.Tonal
                        text: modelData.label
                        horizontalPadding: Tokens.padding.medium
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: root.applyPreset(modelData.id)
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            text: Tr.tr("Built-in names (wireguard, warp, tailscale, netbird, openvpn) auto-fill their commands. For others, provide the connect/disconnect commands.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledTextField {
            id: nameField

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            placeholderText: Tr.tr("Provider name")
            leadingIcon: "vpn_key"
            // TRANSLATORS: id here means the provider identifier, e.g. wireguard
            supportingText: Tr.tr("Built-in id or a custom name")
            errorText: Tr.tr("Provider name is required")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: displayField.forceActiveFocus()
        }

        StyledTextField {
            id: displayField

            Layout.fillWidth: true
            placeholderText: Tr.tr("Display name")
            // TRANSLATORS: the name shown in the VPN provider list on the network page
            supportingText: Tr.tr("Shown in the list")
            leadingIcon: "label"
            inputMethodHints: Qt.ImhNoPredictiveText

            onAccepted: interfaceField.forceActiveFocus()
        }

        StyledTextField {
            id: interfaceField

            Layout.fillWidth: true
            placeholderText: Tr.trCtx("Interface", "network interface")
            leadingIcon: "lan"
            supportingText: Tr.tr("Network interface (for WireGuard / status checks)")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: connectField.forceActiveFocus()
        }

        SectionHeader {
            text: Tr.tr("Custom commands (optional)")
        }

        StyledTextField {
            id: connectField

            Layout.fillWidth: true
            placeholderText: Tr.tr("Connect command")
            leadingIcon: "play_arrow"
            supportingText: Tr.tr("Leave empty to use the built-in default")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: disconnectField.forceActiveFocus()
        }

        StyledTextField {
            id: disconnectField

            Layout.fillWidth: true
            placeholderText: Tr.tr("Disconnect command")
            leadingIcon: "stop"
            supportingText: Tr.tr("Leave empty to use the built-in default")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: root.submit()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: (root.editing ? Tokens.spacing.medium : Tokens.spacing.extraSmall) - parent.spacing
            spacing: Tokens.spacing.small

            IconTextButton {
                visible: root.editing
                isRound: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                inactiveColour: Colours.palette.m3errorContainer
                inactiveOnColour: Colours.palette.m3onErrorContainer
                iconLabel.fill: 1
                iconLabel.grade: 25
                icon: "delete_forever"
                text: Tr.tr("Delete")
                onClicked: {
                    if (root.existing.id === VPN.selectedProvider && VPN.connected)
                        VPN.disconnect();
                    VPN.deleteProvider(root.editIndex);
                    root.nState.closeSubPage();
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ButtonRow {
                spacing: parent.spacing

                TextButton {
                    isRound: true
                    shapeMorph: true
                    horizontalPadding: Tokens.padding.extraLarge
                    verticalPadding: Tokens.padding.medium
                    type: TextButton.Tonal
                    text: Tr.trCtx("Cancel", "button")
                    onClicked: root.nState.closeSubPage()
                }

                TextButton {
                    isRound: true
                    shapeMorph: true
                    horizontalPadding: Tokens.padding.extraLarge
                    verticalPadding: Tokens.padding.medium
                    text: root.editing ? Tr.trCtx("Save", "button") : Tr.trCtx("Add", "button")
                    disabled: !nameField.text.trim()
                    onClicked: root.submit()
                }
            }
        }
    }
}

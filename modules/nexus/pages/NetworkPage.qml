pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    signal networkSelected(ap: Nmcli.AccessPoint)

    title: qsTr("Network")

    property var passwordNetwork: null
    property bool showPasswordDialog: false
    property string passwordValue: ""
    property string connectionError: ""
    property bool connecting: false

    function closePasswordDialog(): void {
        showPasswordDialog = false;
        passwordNetwork = null;
        passwordValue = "";
        connectionError = "";
        connecting = false;
    }

    onShowPasswordDialogChanged: {
        if (showPasswordDialog) {
            const win = root.window;
            if (win && win.requestActivate) {
                win.requestActivate();
            }
            Qt.callLater(() => {
                passwordInput.forceFocus();
            });
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible && Nmcli.wifiEnabled
            repeat: true
            triggeredOnStart: true
            interval: GlobalConfig.nexus.networkRescanInterval
            onTriggered: Nmcli.rescanWifi()
        }

        Timer {
            id: wifiScanDelay

            interval: 100
            onTriggered: Nmcli.rescanWifi()
        }

        Connections {
            function onWifiEnabledChanged(): void {
                if (Nmcli.wifiEnabled)
                    wifiScanDelay.start();
            }

            target: Nmcli
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Wi-Fi")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: Nmcli.wifiEnabled
            onToggled: Nmcli.enableWifi(checked)
        }

        ItemList {
            id: networkList

            showList: Nmcli.wifiEnabled
            placeholderIcon: Nmcli.wifiEnabled ? "wifi_find" : "signal_wifi_off"
            placeholderText: Nmcli.wifiEnabled ? qsTr("No networks found") : qsTr("Wi-Fi disabled")
            extraHeight: Nmcli.scanning ? Tokens.rounding.extraSmall : 0 // Inline so it isn't affected by anim
            list.anchors.top: scanningIndicator.bottom

            model: ScriptModel {
                values: {
                    const connecting = Nmcli.connectingSsid();
                    // Lower rank sorts higher in the list
                    const rank = n => n.active ? 0 : n.ssid === connecting ? 1 : Nmcli.hasSavedProfile(n.ssid) ? 2 : 3;
                    return [...Nmcli.networks].sort((a, b) => rank(a) - rank(b) || b.strength - a.strength);
                }
            }

            delegate: StateLayer {
                id: network

                required property Nmcli.AccessPoint modelData
                property bool currentSelected
                property real textOpacity: disabled ? 0.5 : 1

                disabled: currentSelected || Nmcli.connectingSsid() === modelData.ssid

                anchors.left: networkList.list.contentItem.left
                anchors.right: networkList.list.contentItem.right
                implicitHeight: networkLayout.implicitHeight + networkLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                anchors.fill: undefined

                onClicked: {
                    if (!modelData.active) {
                        NetworkConnection.handleConnect(modelData, null, network => {
                            root.passwordNetwork = network;
                            root.showPasswordDialog = true;
                            root.passwordValue = "";
                            root.connectionError = "";
                            root.connecting = false;
                        });
                        currentSelected = true;
                        root.networkSelected(modelData);
                    }
                }

                Behavior on textOpacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Connections {
                    function onActiveChanged(): void {
                        if (network.modelData.active)
                            network.currentSelected = false;
                    }

                    target: network.modelData
                }

                Connections {
                    function onNetworkSelected(ap: Nmcli.AccessPoint): void {
                        if (ap !== network.modelData)
                            network.currentSelected = false;
                    }

                    target: root
                }

                RowLayout {
                    id: networkLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.extraLarge
                    anchors.rightMargin: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: Icons.getNetworkIcon(network.modelData.strength)
                        color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.icon.medium
                        opacity: network.textOpacity
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        opacity: network.textOpacity

                        StyledText {
                            Layout.fillWidth: true
                            text: network.modelData.ssid
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Security: %1%2").arg(network.modelData.security).arg(Nmcli.hasSavedProfile(network.modelData.ssid) ? qsTr(" • Saved") : "")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    AnimLoader {
                        sourceComp: Nmcli.connectingSsid() === network.modelData.ssid ? loadingComp : iconComp

                        Component {
                            id: iconComp

                            MaterialIcon {
                                text: network.modelData.active ? "settings" : "lock"
                                color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.icon.medium
                                opacity: network.textOpacity
                            }
                        }

                        Component {
                            id: loadingComp

                            LoadingIndicator {
                                implicitSize: Math.round(Tokens.font.icon.medium.pointSize * 1.3)
                            }
                        }
                    }
                }
            }

            StyledProgressBar {
                id: scanningIndicator

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                implicitHeight: Nmcli.scanning ? Tokens.rounding.extraSmall : 0
                indeterminate: true

                Behavior on implicitHeight {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: addNetworkLayout.implicitHeight + addNetworkLayout.anchors.margins * 2
            last: true

            StateLayer {}

            RowLayout {
                id: addNetworkLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased

                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "add"
                    font: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Add network")
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }
    }

    // Password dialog overlay
    StyledRect {
        id: passwordOverlay
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.4)
        visible: root.showPasswordDialog
        z: 100

        // Intercept mouse/key events
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }

        StyledRect {
            id: passwordDialog
            anchors.centerIn: parent
            width: Math.min(parent.width - Tokens.padding.large * 2, 400)
            implicitHeight: dialogLayout.implicitHeight + Tokens.padding.extraLarge * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: dialogLayout
                anchors.fill: parent
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.medium

                StyledText {
                    text: qsTr("Enter password for %1").arg(root.passwordNetwork ? root.passwordNetwork.ssid : "")
                    font: Tokens.font.body.medium
                    Layout.fillWidth: true
                }

                StyledInputField {
                    id: passwordInput
                    Layout.fillWidth: true
                    placeholderText: qsTr("Password")
                    echoMode: TextInput.Password
                    text: root.passwordValue
                    onTextEdited: text => {
                        root.passwordValue = text;
                        if (root.connectionError.length > 0) {
                            root.connectionError = "";
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            if (passwordInput.text.length > 0 && !root.connecting) {
                                connectBtn.clicked();
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.closePasswordDialog();
                            event.accepted = true;
                        }
                    }
                }

                StyledText {
                    id: errorText
                    visible: text.length > 0
                    text: root.connectionError
                    color: Colours.palette.m3error
                    font: Tokens.font.body.small
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Tokens.spacing.small

                    TextButton {
                        text: qsTr("Cancel")
                        onClicked: root.closePasswordDialog()
                    }

                    TextButton {
                        id: connectBtn
                        text: root.connecting ? qsTr("Connecting...") : qsTr("Connect")
                        disabled: passwordInput.text.length === 0 || root.connecting

                        onClicked: {
                            if (root.connecting) return;
                            root.connecting = true;
                            root.connectionError = "";

                            const targetNetwork = root.passwordNetwork;
                            NetworkConnection.connectWithPassword(targetNetwork, passwordInput.text, result => {
                                if (result && result.success) {
                                    root.closePasswordDialog();
                                } else {
                                    root.connecting = false;
                                    root.connectionError = (result && result.error) ? result.error : qsTr("Connection failed");
                                }
                            });
                        }
                    }
                }
            }
        }
    }
}

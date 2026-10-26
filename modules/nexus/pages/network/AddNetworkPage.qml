pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Sub-page for manually adding a (hidden or enterprise) Wi-Fi network. Reached from
// the "Add network" row on NetworkPage via nState.openSubPage.
PageBase {
    id: root

    // Security model: Personal, Enterprise (802.1X), or None (open).
    readonly property bool isEnterprise: securitySelect.active === enterpriseItem
    readonly property bool isPersonal: securitySelect.active === personalItem
    readonly property bool secured: isPersonal || isEnterprise
    property bool connecting: false
    property bool failed: false
    property bool success: false

    function submit(): void {
        const ssid = ssidField.text.trim();
        if (ssid.length === 0) {
            ssidField.isError = true;
            ssidField.forceActiveFocus();
            return;
        }

        if (root.isEnterprise) {
            if (identityField.text.trim().length === 0) {
                identityField.isError = true;
                identityField.forceActiveFocus();
                return;
            }
            if (passwordField.text.length === 0) {
                passwordField.isError = true;
                passwordField.forceActiveFocus();
                return;
            }
        } else if (root.isPersonal) {
            if (passwordField.text.length < 8) {
                passwordField.isError = true;
                passwordField.forceActiveFocus();
                return;
            }
        }

        root.failed = false;
        root.connecting = true;

        if (root.isEnterprise) {
            Nmcli.addEnterpriseNetwork(
                ssid,
                identityField.text.trim(),
                passwordField.text,
                caCertField.text.trim(),
                anonIdentityField.text.trim(),
                hiddenToggle.checked,
                result => {
                    root.connecting = false;
                    if (result && result.success) {
                        root.success = true;
                        root.nState.closeSubPage();
                    } else {
                        root.failed = true;
                        passwordField.isError = true;
                        Nmcli.forgetNetwork(ssid);
                    }
                }
            );
        } else {
            Nmcli.addHiddenNetwork(
                ssid,
                root.isPersonal ? passwordField.text : "",
                root.isPersonal ? "wpa" : "none",
                hiddenToggle.checked,
                result => {
                    root.connecting = false;
                    if (result && result.success) {
                        root.success = true;
                        root.nState.closeSubPage();
                    } else {
                        root.failed = true;
                        if (root.isPersonal)
                            passwordField.isError = true;
                        Nmcli.forgetNetwork(ssid);
                    }
                }
            );
        }
    }

    title: Tr.tr("Add network")
    isSubPage: true

    Component.onCompleted: {
        if (root.nState?.selectedNetworkSsid) {
            const ap = Nmcli.findNetwork(root.nState.selectedNetworkSsid);
            if (ap && ap.isEnterprise) {
                securitySelect.active = enterpriseItem;
            }
        }
    }

    property Process certPickerProc: Process {
        id: certPickerProc

        command: ["zenity", "--file-selection", "--file-filter=Certificates (*.crt *.pem *.cer) | *.crt *.pem *.cer", "--title=Select CA Certificate"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim().length > 0) {
                    caCertField.text = text.trim();
                }
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        Connections {
            function onSubPageClosed(): void {
                if (root.success)
                    return;

                if (root.failed) {
                    const ssid = ssidField.text.trim();
                    if (ssid)
                        Nmcli.forgetNetwork(ssid);
                }
            }

            target: root.nState
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.extraSmall
            text: Tr.tr("Enter the details below to manually connect to a network.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledTextField {
            id: ssidField

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            // TRANSLATORS: SSID is a protocol term, leave it untranslated
            placeholderText: Tr.tr("Network name (SSID)")
            supportingText: Tr.tr("e.g. MyHiddenNetwork")
            leadingIcon: "wifi"
            errorText: Tr.tr("Network name is required")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            text: root.nState?.selectedNetworkSsid || ""

            onAccepted: {
                if (root.isEnterprise)
                    identityField.forceActiveFocus();
                else if (root.isPersonal)
                    passwordField.forceActiveFocus();
                else
                    root.submit();
            }
        }

        ToggleRow {
            id: hiddenToggle

            first: true
            text: Tr.tr("Hidden network")
            subtext: Tr.tr("Actively probe for a network that doesn't broadcast its name")
            checked: !root.nState?.selectedNetworkSsid
        }

        SelectRow {
            id: securitySelect

            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: !root.secured
            label: Tr.tr("Security")
            fallbackText: Tr.tr("WPA/WPA2/WPA3 Personal")
            fallbackIcon: "lock"

            menuItems: [
                MenuItem {
                    id: personalItem

                    icon: "lock"
                    // TRANSLATORS: WPA/WPA2/WPA3 are protocol names, leave them untranslated
                    text: Tr.tr("WPA/WPA2/WPA3 Personal")
                },
                MenuItem {
                    id: enterpriseItem

                    icon: "badge"
                    text: Tr.tr("WPA/WPA2 Enterprise (802.1X)")
                },
                MenuItem {
                    id: noneItem

                    icon: "lock_open"
                    text: Tr.trCtx("None (open)", "wifi security type")
                }
            ]

            Behavior on bottomLeftRadius {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on bottomRightRadius {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Enterprise fields (Username, CA cert, Anonymous identity)
        Item {
            Layout.fillWidth: true
            Layout.bottomMargin: root.isEnterprise ? 0 : -parent.spacing
            implicitHeight: root.isEnterprise ? enterpriseColumn.implicitHeight : 0
            opacity: root.isEnterprise ? 1 : 0

            Behavior on Layout.bottomMargin {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on implicitHeight {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            ColumnLayout {
                id: enterpriseColumn

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Tokens.spacing.large

                StyledTextField {
                    id: identityField

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Username / Identity")
                    leadingIcon: "person"
                    supportingText: Tr.tr("e.g. username@institution.edu or username")
                    errorText: Tr.tr("Username is required")
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    onAccepted: passwordField.forceActiveFocus()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledTextField {
                        id: caCertField

                        Layout.fillWidth: true
                        placeholderText: Tr.tr("CA certificate path (.crt / .pem)")
                        leadingIcon: "verified_user"
                        supportingText: Tr.tr("Path to CA certificate file, e.g. /home/.../cert.crt")
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        type: IconButton.Tonal
                        icon: "folder_open"
                        onClicked: certPickerProc.running = true
                    }
                }

                StyledTextField {
                    id: anonIdentityField

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Anonymous identity (optional)")
                    leadingIcon: "visibility_off"
                    supportingText: Tr.tr("e.g. anonymous@institution.edu")
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.bottomMargin: root.secured ? 0 : -parent.spacing
            implicitHeight: root.secured ? passwordField.implicitHeight : 0
            opacity: root.secured ? 1 : 0

            Behavior on Layout.bottomMargin {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on implicitHeight {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            StyledTextField {
                id: passwordField

                anchors.left: parent.left
                anchors.right: parent.right

                enabled: root.secured
                placeholderText: Tr.tr("Password")
                leadingIcon: "key"
                echoMode: TextInput.Password
                supportingText: root.isEnterprise ? Tr.tr("Account password") : Tr.tr("WPA passwords are at least 8 characters")
                errorText: root.failed ? Tr.tr("Connection failed — check credentials") : (root.isEnterprise ? Tr.tr("Password is required") : Tr.tr("Password must be at least 8 characters"))

                onAccepted: root.submit()
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.extraSmall - parent.spacing
            spacing: Tokens.spacing.small

            TextButton {
                Layout.fillHeight: true
                isRound: true
                horizontalPadding: Tokens.padding.extraLarge
                type: TextButton.Tonal
                text: Tr.trCtx("Cancel", "button")
                onClicked: root.nState.closeSubPage()
            }

            // Connect button — swaps to a loading spinner while connecting,
            // matching the Wi-Fi list connect animation.
            ButtonBase {
                id: connectBtn

                shapeMorph: true
                isRound: true
                inactiveColour: Colours.palette.m3primary
                inactiveOnColour: Colours.palette.m3onPrimary
                stateLayer.disabled: root.connecting || ssidField.text.trim().length === 0

                implicitWidth: connectMetrics.width + Tokens.padding.extraLarge * 2
                implicitHeight: connectMetrics.height + Tokens.padding.medium * 2

                onClicked: {
                    if (!root.connecting && ssidField.text.trim().length > 0)
                        root.submit();
                }

                TextMetrics {
                    id: connectMetrics

                    text: Tr.tr("Connect")
                    font: connectBtn.font
                }

                AnimLoader {
                    id: connectContent

                    anchors.centerIn: parent
                    sourceComp: root.connecting ? connectLoadingComp : connectTextComp
                    outAnimType: Anim.SlowEffects
                    inAnimType: Anim.SlowEffects
                }

                Component {
                    id: connectLoadingComp

                    LoadingIndicator {
                        implicitSize: Math.round(Tokens.font.body.medium.pointSize * 1.4)
                        color: connectBtn.onColour
                    }
                }

                Component {
                    id: connectTextComp

                    StyledText {
                        text: connectMetrics.text
                        font: connectBtn.font
                        color: connectBtn.onColour
                    }
                }
            }
        }
    }
}

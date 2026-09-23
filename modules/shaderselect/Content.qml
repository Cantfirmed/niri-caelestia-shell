pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Card {
    id: root

    required property PersistentProperties visibilities

    readonly property list<var> presetsList: [
        { id: "off", label: "Off", icon: "block", hotkey: "0" },
        { id: "cyberpunk", label: "Cyberpunk", icon: "auto_awesome", hotkey: "1" },
        { id: "electric", label: "Electric", icon: "bolt", hotkey: "2" },
        { id: "retro", label: "Retro CRT", icon: "tv", hotkey: "3" },
        { id: "minimal", label: "Minimal", icon: "lens_blur", hotkey: "4" },
        { id: "tunnel", label: "Tunnel", icon: "cyclone", hotkey: "5" }
    ]

    variant: Card.Variant.Elevated
    padding: Appearance.padding.xl
    radius: Appearance.rounding.large
    implicitWidth: 680
    implicitHeight: mainLayout.implicitHeight + padding * 2
    focus: true

    Keys.onEscapePressed: root.visibilities.shaderSelect = false

    Keys.onPressed: event => {
        if (event.key === Qt.Key_0) {
            BiriShaders.applyPreset("off");
            event.accepted = true;
        } else if (event.key === Qt.Key_1) {
            BiriShaders.applyPreset("cyberpunk");
            event.accepted = true;
        } else if (event.key === Qt.Key_2) {
            BiriShaders.applyPreset("electric");
            event.accepted = true;
        } else if (event.key === Qt.Key_3) {
            BiriShaders.applyPreset("retro");
            event.accepted = true;
        } else if (event.key === Qt.Key_4) {
            BiriShaders.applyPreset("minimal");
            event.accepted = true;
        } else if (event.key === Qt.Key_5) {
            BiriShaders.applyPreset("tunnel");
            event.accepted = true;
        }
    }

    Connections {
        function onShaderSelectChanged(): void {
            if (root.visibilities.shaderSelect) {
                root.forceActiveFocus();
            }
        }

        target: root.visibilities
    }

    ColumnLayout {
        id: mainLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: root.padding
        spacing: Appearance.spacing.lg

        // Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            MaterialIcon {
                text: "auto_awesome"
                size: 26
                color: Colours.palette.m3primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: qsTr("Shader & FX Quick Menu")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 600
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: qsTr("Biri Compositor Shaders (Mod+B)")
                    font.pointSize: Appearance.font.size.bodySmall
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            IconButton {
                icon: "close"
                onClicked: root.visibilities.shaderSelect = false
            }
        }

        // Section: Presets
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            StyledText {
                text: qsTr("Presets (Press 0-5 to switch)")
                font.pointSize: Appearance.font.size.bodySmall
                font.weight: 600
                color: Colours.palette.m3primary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.sm

                Repeater {
                    model: root.presetsList

                    PresetCard {
                        Layout.fillWidth: true
                        presetId: modelData.id
                        label: modelData.label
                        icon: modelData.icon
                        hotkey: modelData.hotkey
                        isActive: BiriShaders.activePreset === modelData.id
                    }
                }
            }
        }

        // Section: Focus Ring
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xs

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: qsTr("Focus Ring / Border")
                    font.pointSize: Appearance.font.size.bodySmall
                    font.weight: 600
                    color: Colours.palette.m3onSurface
                }

                Item { Layout.fillWidth: true }

                FXChip {
                    label: BiriShaders.lightSpillEnabled ? qsTr("Light Spill: ON") : qsTr("Light Spill: OFF")
                    isSelected: BiriShaders.focusRingEnabled && BiriShaders.lightSpillEnabled
                    onTriggered: {
                        BiriShaders.lightSpillEnabled = !BiriShaders.lightSpillEnabled;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xs

                FXChip {
                    label: qsTr("Off")
                    isSelected: !BiriShaders.focusRingEnabled
                    onTriggered: BiriShaders.selectFocusRing("none")
                }

                FXChip {
                    label: qsTr("Rainbow Ripple")
                    isSelected: BiriShaders.focusRingEnabled && BiriShaders.focusRingPreset === "rainbow-ripple"
                    onTriggered: BiriShaders.selectFocusRing("rainbow-ripple")
                }

                FXChip {
                    label: qsTr("Lightning Glow")
                    isSelected: BiriShaders.focusRingEnabled && BiriShaders.focusRingPreset === "lightning"
                    onTriggered: BiriShaders.selectFocusRing("lightning")
                }

                FXChip {
                    label: qsTr("Cyan Pulse")
                    isSelected: BiriShaders.focusRingEnabled && BiriShaders.focusRingPreset === "pulse"
                    onTriggered: BiriShaders.selectFocusRing("pulse")
                }
            }
        }

        // Section: Window Animation
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xs

            StyledText {
                text: qsTr("Window Animations")
                font.pointSize: Appearance.font.size.bodySmall
                font.weight: 600
                color: Colours.palette.m3onSurface
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xs

                FXChip {
                    label: qsTr("Off")
                    isSelected: !BiriShaders.windowAnimEnabled
                    onTriggered: BiriShaders.selectWindowAnim("none")
                }

                FXChip {
                    label: qsTr("Whirlpool")
                    isSelected: BiriShaders.windowAnimEnabled && BiriShaders.windowAnimPreset === "whirlpool"
                    onTriggered: BiriShaders.selectWindowAnim("whirlpool")
                }

                FXChip {
                    label: qsTr("Melt")
                    isSelected: BiriShaders.windowAnimEnabled && BiriShaders.windowAnimPreset === "melt"
                    onTriggered: BiriShaders.selectWindowAnim("melt")
                }

                FXChip {
                    label: qsTr("Lightning")
                    isSelected: BiriShaders.windowAnimEnabled && BiriShaders.windowAnimPreset === "lightning"
                    onTriggered: BiriShaders.selectWindowAnim("lightning")
                }

                FXChip {
                    label: qsTr("Ripple")
                    isSelected: BiriShaders.windowAnimEnabled && BiriShaders.windowAnimPreset === "ripple"
                    onTriggered: BiriShaders.selectWindowAnim("ripple")
                }
            }
        }

        // Section: Global / Screen / Cursor FX
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xs

            StyledText {
                text: qsTr("Cursor & Screen FX")
                font.pointSize: Appearance.font.size.bodySmall
                font.weight: 600
                color: Colours.palette.m3onSurface
            }

            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xs

                FXChip {
                    label: qsTr("Off")
                    isSelected: !BiriShaders.globalShaderEnabled
                    onTriggered: BiriShaders.selectGlobalShader("none")
                }

                FXChip {
                    label: qsTr("Comet Glow")
                    isSelected: BiriShaders.globalShaderEnabled && BiriShaders.globalShaderPreset === "comet-glow"
                    onTriggered: BiriShaders.selectGlobalShader("comet-glow")
                }

                FXChip {
                    label: qsTr("Blue Glow")
                    isSelected: BiriShaders.globalShaderEnabled && BiriShaders.globalShaderPreset === "blueglow"
                    onTriggered: BiriShaders.selectGlobalShader("blueglow")
                }

                FXChip {
                    label: qsTr("Shockwave")
                    isSelected: BiriShaders.globalShaderEnabled && BiriShaders.globalShaderPreset === "shockwave"
                    onTriggered: BiriShaders.selectGlobalShader("shockwave")
                }

                FXChip {
                    label: qsTr("CRT Lines")
                    isSelected: BiriShaders.globalShaderEnabled && BiriShaders.globalShaderPreset === "crt"
                    onTriggered: BiriShaders.selectGlobalShader("crt")
                }

                FXChip {
                    label: qsTr("Vignette")
                    isSelected: BiriShaders.globalShaderEnabled && BiriShaders.globalShaderPreset === "vignette"
                    onTriggered: BiriShaders.selectGlobalShader("vignette")
                }

                FXChip {
                    label: qsTr("Grayscale")
                    isSelected: BiriShaders.globalShaderEnabled && BiriShaders.globalShaderPreset === "grayscale"
                    onTriggered: BiriShaders.selectGlobalShader("grayscale")
                }
            }
        }

        // Footer Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Hotkeys: [0-5] Presets · [Esc] Dismiss")
                font.pointSize: Appearance.font.size.bodySmall
                color: Colours.palette.m3outline
            }

            TextButton {
                text: qsTr("Full Settings (Nexus)")
                icon: "settings"
                onClicked: {
                    root.visibilities.shaderSelect = false;
                    Quickshell.execDetached(["qs", "-c", "niri-caelestia-shell", "ipc", "call", "nexus", "open"]);
                }
            }
        }
    }

    component PresetCard: StyledRect {
        id: presetCard

        required property string presetId
        required property string label
        required property string icon
        required property string hotkey
        required property bool isActive

        implicitHeight: 74
        radius: Tokens.rounding.medium
        color: presetCard.isActive ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        border.color: presetCard.isActive ? Colours.palette.m3primary : "transparent"
        border.width: presetCard.isActive ? 2 : 0

        StateLayer {
            radius: parent.radius
            color: presetCard.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            onClicked: BiriShaders.applyPreset(presetCard.presetId)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: 2

            RowLayout {
                Layout.fillWidth: true

                MaterialIcon {
                    text: presetCard.icon
                    size: 20
                    color: presetCard.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurface
                }

                Item { Layout.fillWidth: true }

                StyledRect {
                    implicitWidth: 18
                    implicitHeight: 18
                    radius: Tokens.rounding.extraSmall
                    color: presetCard.isActive ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                    StyledText {
                        anchors.centerIn: parent
                        text: presetCard.hotkey
                        font.pointSize: Tokens.font.size.extraSmall
                        font.weight: 700
                        color: presetCard.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: presetCard.label
                font.pointSize: Tokens.font.size.small
                font.weight: presetCard.isActive ? 600 : 500
                color: presetCard.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                elide: Text.ElideRight
            }
        }
    }

    component FXChip: StyledRect {
        id: fxChip

        required property string label
        required property bool isSelected

        signal triggered()

        implicitHeight: 28
        implicitWidth: chipLabel.implicitWidth + 20
        radius: Tokens.rounding.full
        color: fxChip.isSelected ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
        border.color: fxChip.isSelected ? Colours.palette.m3primary : "transparent"
        border.width: 1

        StateLayer {
            radius: parent.radius
            color: fxChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: fxChip.triggered()
        }

        StyledText {
            id: chipLabel

            anchors.centerIn: parent
            text: fxChip.label
            font.pointSize: Tokens.font.size.extraSmall
            font.weight: fxChip.isSelected ? 600 : 400
            color: fxChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        }
    }
}

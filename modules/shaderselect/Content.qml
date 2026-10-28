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
        { id: "off", label: qsTr("Off"), icon: "block", hotkey: "0", subtext: qsTr("Vanilla") },
        { id: "ambient-glow", label: qsTr("Ambient Glow"), icon: "blur_on", hotkey: "1", subtext: qsTr("Soft theme spill") },
        { id: "minimal-clean", label: qsTr("Minimal Clean"), icon: "crop_free", hotkey: "2", subtext: qsTr("Subtle 1px") },
        { id: "focus", label: qsTr("Active Focus"), icon: "lens_blur", hotkey: "3", subtext: qsTr("Pulse ring") },
        { id: "locator", label: qsTr("Mouse Locator"), icon: "near_me", hotkey: "4", subtext: qsTr("Adaptive halo") },
        { id: "presentation", label: qsTr("Presentation"), icon: "present_to_all", hotkey: "5", subtext: qsTr("Spotlight beam") },
        { id: "retro", label: qsTr("Retro CRT"), icon: "tv", hotkey: "6", subtext: qsTr("Scanlines") },
        { id: "cyberpunk", label: qsTr("Cyberpunk"), icon: "auto_awesome", hotkey: "7", subtext: qsTr("Rainbow FX") }
    ]

    variant: Card.Variant.Elevated
    padding: Tokens.padding.large
    radius: Tokens.rounding.large
    implicitWidth: 840
    implicitHeight: mainLayout.implicitHeight + padding * 2
    focus: true

    Keys.onEscapePressed: root.visibilities.shaderSelect = false

    Keys.onPressed: event => {
        if (event.key === Qt.Key_0) {
            BiriShaders.applyPreset("off");
            event.accepted = true;
        } else if (event.key === Qt.Key_1) {
            BiriShaders.applyPreset("ambient-glow");
            event.accepted = true;
        } else if (event.key === Qt.Key_2) {
            BiriShaders.applyPreset("minimal-clean");
            event.accepted = true;
        } else if (event.key === Qt.Key_3) {
            BiriShaders.applyPreset("focus");
            event.accepted = true;
        } else if (event.key === Qt.Key_4) {
            BiriShaders.applyPreset("locator");
            event.accepted = true;
        } else if (event.key === Qt.Key_5) {
            BiriShaders.applyPreset("presentation");
            event.accepted = true;
        } else if (event.key === Qt.Key_6) {
            BiriShaders.applyPreset("retro");
            event.accepted = true;
        } else if (event.key === Qt.Key_7) {
            BiriShaders.applyPreset("cyberpunk");
            event.accepted = true;
        } else if (event.key === Qt.Key_Minus || event.key === Qt.Key_BracketLeft) {
            BiriShaders.lightSpread = Math.max(4, BiriShaders.lightSpread - 2);
            event.accepted = true;
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.key === Qt.Key_BracketRight) {
            BiriShaders.lightSpread = Math.min(60, BiriShaders.lightSpread + 2);
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
        anchors.margins: root.padding
        spacing: Tokens.spacing.medium

        // Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: 42
                implicitHeight: 42
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "auto_awesome"
                    size: 24
                    color: Colours.palette.m3primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Shader & Compositor FX")
                    font: Tokens.font.title.small
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Window Focus, Mouse Highlights, and Display Post-Processing (Mod+B)")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
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
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: qsTr("Presets")
                    font: Tokens.font.label.medium
                    color: Colours.palette.m3primary
                }

                StyledText {
                    text: qsTr("· Press 0-5 to switch quickly")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3outline
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.presetsList

                    PresetCard {
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Section 1: Active Window Focus Ring
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: focusSectionLayout.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerLow
            border.color: Colours.palette.m3outlineVariant
            border.width: 1

            ColumnLayout {
                id: focusSectionLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "crop_free"
                        size: 20
                        color: BiriShaders.focusRingEnabled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Active Window Focus Ring")
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Subtle theme-accent glow on focused window")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    FXChip {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        icon: BiriShaders.lightSpillEnabled ? "blur_on" : "blur_off"
                        label: BiriShaders.lightSpillEnabled ? qsTr("Glow Spill: ON") : qsTr("Glow Spill: OFF")
                        isSelected: BiriShaders.focusRingEnabled && BiriShaders.lightSpillEnabled
                        onTriggered: {
                            BiriShaders.lightSpillEnabled = !BiriShaders.lightSpillEnabled;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    FXChip {
                        label: qsTr("Off")
                        isSelected: !BiriShaders.focusRingEnabled
                        onTriggered: BiriShaders.selectFocusRing("none")
                    }

                    FXChip {
                        icon: "palette"
                        label: qsTr("Theme Pulse")
                        isSelected: BiriShaders.focusRingEnabled && BiriShaders.focusRingPreset === "pulse" && BiriShaders.pulseMatchTheme
                        onTriggered: {
                            BiriShaders.pulseMatchTheme = true;
                            BiriShaders.selectFocusRing("pulse");
                        }
                    }

                    FXChip {
                        label: qsTr("Cyan Pulse")
                        isSelected: BiriShaders.focusRingEnabled && BiriShaders.focusRingPreset === "pulse" && !BiriShaders.pulseMatchTheme
                        onTriggered: {
                            BiriShaders.pulseMatchTheme = false;
                            BiriShaders.selectFocusRing("pulse");
                        }
                    }

                    FXChip {
                        label: qsTr("Lightning")
                        isSelected: BiriShaders.focusRingEnabled && BiriShaders.focusRingPreset === "lightning"
                        onTriggered: BiriShaders.selectFocusRing("lightning")
                    }

                    FXChip {
                        label: qsTr("Rainbow")
                        isSelected: BiriShaders.focusRingEnabled && BiriShaders.focusRingPreset === "rainbow-ripple"
                        onTriggered: BiriShaders.selectFocusRing("rainbow-ripple")
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    opacity: (BiriShaders.focusRingEnabled && BiriShaders.lightSpillEnabled) ? 1.0 : 0.4
                    enabled: BiriShaders.focusRingEnabled && BiriShaders.lightSpillEnabled

                    Behavior on opacity {
                        Anim {}
                    }

                    MaterialIcon {
                        text: "blur_circular"
                        size: 18
                        color: Colours.palette.m3onSurfaceVariant
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: qsTr("Glow Spread")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 20
                        value: (BiriShaders.lightSpread - 4) / 56.0
                        onInteraction: v => {
                            BiriShaders.lightSpread = Math.max(4, Math.min(60, Math.round(4 + v * 56)));
                        }
                    }

                    StyledText {
                        text: `${Math.round(BiriShaders.lightSpread)} px`
                        font: Tokens.font.label.small
                        color: (BiriShaders.focusRingEnabled && BiriShaders.lightSpillEnabled) ? Colours.palette.m3primary : Colours.palette.m3outline
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // Section 2: Mouse & Pointer Locator (Presentations / Tracking)
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: mouseSectionLayout.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerLow
            border.color: Colours.palette.m3outlineVariant
            border.width: 1

            ColumnLayout {
                id: mouseSectionLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "near_me"
                        size: 20
                        color: BiriShaders.isCursorShaderActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Mouse & Pointer Locator")
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Find your cursor instantly on multi-monitor setups or during presentations")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                // Line 1: Off, Adaptive Halo, Presentation Spotlight, Motion Trail
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    FXChip {
                        label: qsTr("Off")
                        isSelected: !BiriShaders.isCursorShaderActive
                        onTriggered: BiriShaders.selectCursorShader("none")
                    }

                    FXChip {
                        icon: "adjust"
                        label: qsTr("Adaptive Halo (Recommended)")
                        isSelected: BiriShaders.isCursorShaderActive && BiriShaders.globalShaderPreset === "locator"
                        onTriggered: BiriShaders.selectCursorShader("locator")
                    }

                    FXChip {
                        icon: "present_to_all"
                        label: qsTr("Presentation Spotlight")
                        isSelected: BiriShaders.isCursorShaderActive && BiriShaders.globalShaderPreset === "spotlight"
                        onTriggered: BiriShaders.selectCursorShader("spotlight")
                    }

                    FXChip {
                        icon: "timeline"
                        label: qsTr("Motion Trail")
                        isSelected: BiriShaders.isCursorShaderActive && BiriShaders.globalShaderPreset === "trail"
                        onTriggered: BiriShaders.selectCursorShader("trail")
                    }

                    Item { Layout.fillWidth: true }
                }

                // Line 2 (starting after Motion Trail to prevent overflow):
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    FXChip {
                        icon: "blur_on"
                        label: qsTr("Soft Blue Glow")
                        isSelected: BiriShaders.isCursorShaderActive && BiriShaders.globalShaderPreset === "blueglow"
                        onTriggered: BiriShaders.selectCursorShader("blueglow")
                    }

                    FXChip {
                        icon: "auto_awesome"
                        label: qsTr("Comet Trail")
                        isSelected: BiriShaders.isCursorShaderActive && BiriShaders.globalShaderPreset === "comet-glow"
                        onTriggered: BiriShaders.selectCursorShader("comet-glow")
                    }

                    FXChip {
                        icon: "motion_photos_on"
                        label: qsTr("Ripple")
                        isSelected: BiriShaders.isCursorShaderActive && BiriShaders.globalShaderPreset === "ripple"
                        onTriggered: BiriShaders.selectCursorShader("ripple")
                    }

                    FXChip {
                        icon: "flare"
                        label: qsTr("Shockwave")
                        isSelected: BiriShaders.isCursorShaderActive && BiriShaders.globalShaderPreset === "shockwave"
                        onTriggered: BiriShaders.selectCursorShader("shockwave")
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        // Section 3: Screen Post-Process Filters (Clearly distinct from cursor!)
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: screenSectionLayout.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerLow
            border.color: Colours.palette.m3outlineVariant
            border.width: 1

            ColumnLayout {
                id: screenSectionLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "tv"
                        size: 20
                        color: BiriShaders.isScreenFilterActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Screen Post-Process Filters")
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Whole-display color grading and CRT monitor emulation (separate from cursor)")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    FXChip {
                        label: qsTr("Off")
                        isSelected: !BiriShaders.isScreenFilterActive
                        onTriggered: BiriShaders.selectScreenFilter("none")
                    }

                    FXChip {
                        icon: "tv"
                        label: qsTr("CRT Scanlines")
                        isSelected: BiriShaders.isScreenFilterActive && BiriShaders.globalShaderPreset === "crt"
                        onTriggered: BiriShaders.selectScreenFilter("crt")
                    }

                    FXChip {
                        icon: "vignette"
                        label: qsTr("Vignette")
                        isSelected: BiriShaders.isScreenFilterActive && BiriShaders.globalShaderPreset === "vignette"
                        onTriggered: BiriShaders.selectScreenFilter("vignette")
                    }

                    FXChip {
                        icon: "contrast"
                        label: qsTr("Grayscale")
                        isSelected: BiriShaders.isScreenFilterActive && BiriShaders.globalShaderPreset === "grayscale"
                        onTriggered: BiriShaders.selectScreenFilter("grayscale")
                    }

                    FXChip {
                        icon: "wb_sunny"
                        label: qsTr("Warm Night Tint")
                        isSelected: BiriShaders.isScreenFilterActive && BiriShaders.globalShaderPreset === "warmtint"
                        onTriggered: BiriShaders.selectScreenFilter("warmtint")
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        // Section 4: Window Dissolve Animations
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "animation"
                size: 18
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                text: qsTr("Window Close FX:")
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
            }

            FXChip {
                label: qsTr("Off")
                isSelected: !BiriShaders.windowAnimEnabled
                onTriggered: BiriShaders.selectWindowAnim("none")
            }

            FXChip {
                label: qsTr("Ripple")
                isSelected: BiriShaders.windowAnimEnabled && BiriShaders.windowAnimPreset === "ripple"
                onTriggered: BiriShaders.selectWindowAnim("ripple")
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

            Item { Layout.fillWidth: true }
        }

        // Footer Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Hotkeys: [0-7] Presets · [- / +] Spread · [Esc] Dismiss")
                font: Tokens.font.body.small
                color: Colours.palette.m3outline
            }

            IconTextButton {
                text: qsTr("Full Settings (Nexus)")
                icon: "tune"
                onClicked: {
                    root.visibilities.shaderSelect = false;
                    Quickshell.execDetached(["qs", "-c", "niri-caelestia-shell", "ipc", "call", "nexus", "open"]);
                }
            }
        }
    }

    component PresetCard: StyledRect {
        id: presetCard

        required property var modelData
        property string presetId: modelData.id
        property string label: modelData.label
        property string icon: modelData.icon
        property string hotkey: modelData.hotkey
        property string subtext: modelData.subtext ?? ""
        readonly property bool isActive: BiriShaders.activePreset === presetId

        implicitHeight: 76
        radius: Tokens.rounding.medium
        color: presetCard.isActive ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        border.color: presetCard.isActive ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
        border.width: presetCard.isActive ? 1.5 : 1

        Behavior on color {
            CAnim {}
        }
        Behavior on border.color {
            CAnim {}
        }

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

                StyledRect {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: Tokens.rounding.small
                    color: presetCard.isActive ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: presetCard.icon
                        size: 16
                        color: presetCard.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    }
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
                        font: Tokens.font.label.small
                        color: presetCard.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: presetCard.label
                font: Tokens.font.label.medium
                color: presetCard.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: presetCard.subtext
                font: Tokens.font.label.small
                color: presetCard.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                elide: Text.ElideRight
            }
        }
    }

    component FXChip: StyledRect {
        id: fxChip

        property string icon: ""
        required property string label
        required property bool isSelected

        signal triggered()

        implicitHeight: 30
        implicitWidth: chipContentLayout.implicitWidth + Tokens.padding.medium * 2
        radius: Tokens.rounding.full
        color: fxChip.isSelected ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
        border.color: fxChip.isSelected ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
        border.width: 1

        Behavior on color {
            CAnim {}
        }
        Behavior on border.color {
            CAnim {}
        }

        StateLayer {
            radius: parent.radius
            color: fxChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: fxChip.triggered()
        }

        RowLayout {
            id: chipContentLayout

            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                visible: fxChip.icon.length > 0
                text: fxChip.icon
                size: 14
                color: fxChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: fxChip.label
                font: Tokens.font.label.small
                color: fxChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}

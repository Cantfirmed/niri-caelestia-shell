pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<var> focusPresets: [
        { id: "rainbow-ripple", name: Tr.tr("Rainbow Ripple"), icon: "gradient", desc: Tr.tr("Flowing pastel wax colors") },
        { id: "lightning", name: Tr.tr("Lightning & Glow"), icon: "bolt", desc: Tr.tr("Traveling electric pulse with light spill") },
        { id: "pulse", name: Tr.tr("Cyan Pulse"), icon: "lens_blur", desc: Tr.tr("Subtle breathing cyan glow") }
    ]

    readonly property list<var> animPresets: [
        { id: "whirlpool", name: Tr.tr("Whirlpool"), icon: "cyclone", desc: Tr.tr("Vortex spiral collapse on close") },
        { id: "melt", name: Tr.tr("Melt"), icon: "water_drop", desc: Tr.tr("Liquid drip dissolving effect") },
        { id: "lightning", name: Tr.tr("Lightning Shock"), icon: "flash_on", desc: Tr.tr("Electrical discharge burn") },
        { id: "ripple", name: Tr.tr("Ripple"), icon: "waves", desc: Tr.tr("Water ripple distortion wave") }
    ]

    readonly property list<var> globalPresets: [
        { id: "comet-glow", name: Tr.tr("Comet Glow Trail"), icon: "auto_awesome", desc: Tr.tr("Rainbow cursor comet tail") },
        { id: "blueglow", name: Tr.tr("Blue Cursor Glow"), icon: "blur_on", desc: Tr.tr("Soft glowing aura around cursor") },
        { id: "rainbow-tunnel", name: Tr.tr("Rainbow Tunnel"), icon: "tunnel", desc: Tr.tr("Concentric rainbow tunnel at mouse") },
        { id: "ripple", name: Tr.tr("Cursor Ripple"), icon: "motion_photos_on", desc: Tr.tr("Expanding waves on mouse movement") },
        { id: "shockwave", name: Tr.tr("Shockwave"), icon: "flare", desc: Tr.tr("High-energy shockwave pulse") },
        { id: "spotlight", name: Tr.tr("Spotlight"), icon: "highlight", desc: Tr.tr("Dims screen with spotlight on cursor") },
        { id: "trail", name: Tr.tr("Motion Trail"), icon: "timeline", desc: Tr.tr("Smooth temporal cursor motion trail") },
        { id: "crt", name: Tr.tr("CRT Scanlines"), icon: "tv", desc: Tr.tr("Full-screen retro CRT monitor lines") },
        { id: "warmtint", name: Tr.tr("Warm Night Tint"), icon: "wb_sunny", desc: Tr.tr("Gentle amber evening color tint") },
        { id: "grayscale", name: Tr.tr("Grayscale"), icon: "contrast", desc: Tr.tr("Monochromatic black and white") },
        { id: "vignette", name: Tr.tr("Vignette"), icon: "vignette", desc: Tr.tr("Darkened cinematic screen edges") }
    ]

    readonly property list<var> fpsOptions: [
        { value: 0, text: Tr.tr("Monitor refresh (Uncapped)") },
        { value: 60, text: Tr.tr("60 FPS") },
        { value: 120, text: Tr.tr("120 FPS") },
        { value: 144, text: Tr.tr("144 FPS") }
    ]

    title: Tr.tr("Biri Shaders & FX")

    ColumnLayout {
        id: mainLayout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // ---------------- Visual Preview Card ----------------
        StyledRect {
            id: previewContainer

            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.medium
            implicitHeight: Math.min(Math.round(root.cappedWidth * 0.45), 230)

            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large
            clip: true

            FadeImage {
                anchors.fill: parent
                source: Wallpapers.current
                fillMode: Image.PreserveAspectCrop
                opacity: 0.6
            }

            StyledRect {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.45)
                radius: Tokens.rounding.large
            }

            // Mock window with dynamic focus ring border simulation
            StyledRect {
                id: mockWindow

                anchors.centerIn: parent
                width: Math.min(parent.width - Tokens.padding.extraLarge * 2, 400)
                height: Math.min(parent.height - Tokens.padding.extraLarge * 2, 160)
                radius: Tokens.rounding.medium
                color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.92)

                border.width: BiriShaders.focusRingEnabled ? Math.max(2, BiriShaders.focusRingWidth) : 1
                border.color: {
                    if (!BiriShaders.focusRingEnabled)
                        return Colours.palette.m3outlineVariant;
                    if (BiriShaders.focusRingPreset === "lightning")
                        return "#00E5FF";
                    if (BiriShaders.focusRingPreset === "pulse")
                        return "#26C6DA";
                    return "#FF80AB";
                }

                Behavior on border.color {
                    CAnim {}
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Row {
                            spacing: 6

                            Repeater {
                                model: [Colours.palette.m3error, Colours.palette.m3tertiary, Colours.palette.m3primary]

                                StyledRect {
                                    required property color modelData

                                    width: 10
                                    height: 10
                                    radius: Tokens.rounding.full
                                    color: modelData
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Tokens.padding.small
                            text: BiriShaders.focusRingEnabled
                                ? Tr.tr("Active Window (%1)").arg(
                                    root.focusPresets.find(p => p.id === BiriShaders.focusRingPreset)?.name ?? BiriShaders.focusRingPreset
                                )
                                : Tr.tr("Standard Solid Border")
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    // Status pill badges
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledRect {
                            radius: Tokens.rounding.full
                            color: BiriShaders.focusRingEnabled ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh
                            implicitWidth: borderBadgeText.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: borderBadgeText.implicitHeight + Tokens.padding.small

                            StyledText {
                                id: borderBadgeText

                                anchors.centerIn: parent
                                text: BiriShaders.focusRingEnabled ? Tr.tr("Ring: ON") : Tr.tr("Ring: OFF")
                                font: Tokens.font.label.small
                                color: BiriShaders.focusRingEnabled ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline
                            }
                        }

                        StyledRect {
                            radius: Tokens.rounding.full
                            color: BiriShaders.windowAnimEnabled ? Colours.palette.m3tertiaryContainer : Colours.tPalette.m3surfaceContainerHigh
                            implicitWidth: animBadgeText.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: animBadgeText.implicitHeight + Tokens.padding.small

                            StyledText {
                                id: animBadgeText

                                anchors.centerIn: parent
                                text: BiriShaders.windowAnimEnabled
                                    ? Tr.tr("Anim: %1").arg(BiriShaders.windowAnimPreset)
                                    : Tr.tr("Anim: Default")
                                font: Tokens.font.label.small
                                color: BiriShaders.windowAnimEnabled ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3outline
                            }
                        }

                        StyledRect {
                            radius: Tokens.rounding.full
                            color: BiriShaders.globalShaderEnabled ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh
                            implicitWidth: globalBadgeText.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: globalBadgeText.implicitHeight + Tokens.padding.small

                            StyledText {
                                id: globalBadgeText

                                anchors.centerIn: parent
                                text: BiriShaders.globalShaderEnabled
                                    ? Tr.tr("FX: %1").arg(BiriShaders.globalShaderPreset)
                                    : Tr.tr("FX: None")
                                font: Tokens.font.label.small
                                color: BiriShaders.globalShaderEnabled ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                            }
                        }
                    }
                }
            }
        }

        // ---------------- Section 1: Focus Ring & Border Shaders ----------------
        SectionHeader {
            first: true
            text: Tr.tr("Focus Ring & Border Shaders")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enable animated focus ring")
            subtext: Tr.tr("Replace static border with dynamic GLSL shader effect")
            checked: BiriShaders.focusRingEnabled
            onToggled: BiriShaders.focusRingEnabled = checked
        }

        SelectRow {
            label: Tr.tr("Focus ring style")
            subtext: root.focusPresets.find(p => p.id === BiriShaders.focusRingPreset)?.desc ?? ""
            enabled: BiriShaders.focusRingEnabled
            menuItems: focusMenuItems.instances
            active: focusMenuItems.instances.find(i => i.modelData?.id === BiriShaders.focusRingPreset) ?? null
            onSelected: item => {
                if (item.modelData)
                    BiriShaders.focusRingPreset = item.modelData.id;
            }

            Variants {
                id: focusMenuItems

                model: root.focusPresets

                MenuItem {
                    required property var modelData

                    text: modelData.name
                }
            }
        }

        SliderRow {
            icon: "line_weight"
            label: Tr.tr("Ring width")
            valueLabel: `${Math.round(BiriShaders.focusRingWidth)} px`
            value: (BiriShaders.focusRingWidth - 1) / 9.0
            enabled: BiriShaders.focusRingEnabled
            onMoved: v => BiriShaders.focusRingWidth = Math.max(1, Math.min(10, Math.round(1 + v * 9)))
        }

        SliderRow {
            icon: "aspect_ratio"
            label: Tr.tr("Shader padding")
            valueLabel: `${Math.round(BiriShaders.focusRingPadding)} px`
            value: Math.max(0, Math.min(30, BiriShaders.focusRingPadding)) / 30.0
            enabled: BiriShaders.focusRingEnabled
            onMoved: v => BiriShaders.focusRingPadding = Math.max(0, Math.min(30, Math.round(v * 30)))
        }

        ToggleRow {
            text: Tr.tr("Screen-space light spill")
            subtext: Tr.tr("Allow bright highlights to illuminate neighboring windows and background")
            enabled: BiriShaders.focusRingEnabled
            checked: BiriShaders.lightSpillEnabled
            onToggled: BiriShaders.lightSpillEnabled = checked
        }

        SliderRow {
            last: true
            icon: "blur_circular"
            label: Tr.tr("Light spread")
            valueLabel: `${Math.round(BiriShaders.lightSpread)} px`
            value: (BiriShaders.lightSpread - 20) / 130.0
            enabled: BiriShaders.focusRingEnabled && BiriShaders.lightSpillEnabled
            onMoved: v => BiriShaders.lightSpread = Math.max(20, Math.min(150, Math.round(20 + v * 130)))
        }

        // ---------------- Section 2: Window Open / Close Animations ----------------
        SectionHeader {
            text: Tr.tr("Window Animations")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Custom animation shader")
            subtext: Tr.tr("Apply dynamic GLSL dissolution shader when windows open or close")
            checked: BiriShaders.windowAnimEnabled
            onToggled: BiriShaders.windowAnimEnabled = checked
        }

        SelectRow {
            last: true
            label: Tr.tr("Animation effect")
            subtext: root.animPresets.find(p => p.id === BiriShaders.windowAnimPreset)?.desc ?? ""
            enabled: BiriShaders.windowAnimEnabled
            menuItems: animMenuItems.instances
            active: animMenuItems.instances.find(i => i.modelData?.id === BiriShaders.windowAnimPreset) ?? null
            onSelected: item => {
                if (item.modelData)
                    BiriShaders.windowAnimPreset = item.modelData.id;
            }

            Variants {
                id: animMenuItems

                model: root.animPresets

                MenuItem {
                    required property var modelData

                    text: modelData.name
                }
            }
        }

        // ---------------- Section 3: Global Screen & Cursor Shaders ----------------
        SectionHeader {
            text: Tr.tr("Global Screen & Cursor FX")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enable global post-process shader")
            subtext: Tr.tr("Run full-screen or cursor-following visual effects")
            checked: BiriShaders.globalShaderEnabled
            onToggled: BiriShaders.globalShaderEnabled = checked
        }

        SelectRow {
            last: true
            label: Tr.tr("Global effect preset")
            subtext: root.globalPresets.find(p => p.id === BiriShaders.globalShaderPreset)?.desc ?? ""
            enabled: BiriShaders.globalShaderEnabled
            menuItems: globalMenuItems.instances
            active: globalMenuItems.instances.find(i => i.modelData?.id === BiriShaders.globalShaderPreset) ?? null
            onSelected: item => {
                if (item.modelData)
                    BiriShaders.globalShaderPreset = item.modelData.id;
            }

            Variants {
                id: globalMenuItems

                model: root.globalPresets

                MenuItem {
                    required property var modelData

                    text: modelData.name
                }
            }
        }

        // ---------------- Section 4: Multi-Monitor Carousel Overview ----------------
        SectionHeader {
            text: Tr.tr("Carousel Overview")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Consolidated 3D carousel overview")
            subtext: Tr.tr("Browse multi-monitor workspaces as a single continuous 3D perspective cover-flow")
            checked: BiriShaders.carouselEnabled
            onToggled: BiriShaders.carouselEnabled = checked
        }

        // ---------------- Section 5: Performance & Reset ----------------
        SectionHeader {
            text: Tr.tr("Performance & Defaults")
        }

        SelectRow {
            first: true
            label: Tr.tr("Shader animation FPS limit")
            subtext: Tr.tr("Cap shader redraw rate independently of display refresh rate")
            menuItems: fpsMenuItems.instances
            active: fpsMenuItems.instances.find(i => i.modelData?.value === BiriShaders.shaderMaxFps) ?? fpsMenuItems.instances[0]
            onSelected: item => {
                if (item.modelData)
                    BiriShaders.shaderMaxFps = item.modelData.value;
            }

            Variants {
                id: fpsMenuItems

                model: root.fpsOptions

                MenuItem {
                    required property var modelData

                    text: modelData.text
                }
            }
        }

        RowButton {
            last: true
            label: Tr.tr("Reset Shaders to Default")
            subtext: Tr.tr("Turn off custom shaders and restore standard Niri rendering")
            onClicked: BiriShaders.resetToDefaults()
        }
    }
}

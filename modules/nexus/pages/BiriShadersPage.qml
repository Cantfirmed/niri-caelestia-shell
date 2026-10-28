pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<var> presetCards: [
        { id: "off", name: Tr.tr("Vanilla Off"), icon: "block", desc: Tr.tr("Stock compositor rendering") },
        { id: "minimal-clean", name: Tr.tr("Minimal Clean"), icon: "crop_free", desc: Tr.tr("Subtle 1px theme outline, no spill") },
        { id: "ambient-glow", name: Tr.tr("Ambient Glow"), icon: "blur_on", desc: Tr.tr("Soft wallpaper spill & gentle whirlpool") },
        { id: "focus", name: Tr.tr("Active Focus"), icon: "lens_blur", desc: Tr.tr("Standard focused window pulse") },
        { id: "locator", name: Tr.tr("Mouse Locator"), icon: "adjust", desc: Tr.tr("Adaptive high-contrast cursor halo") },
        { id: "presentation", name: Tr.tr("Presentation"), icon: "present_to_all", desc: Tr.tr("Spotlight beam on cursor for talks") },
        { id: "retro", name: Tr.tr("Retro CRT"), icon: "tv", desc: Tr.tr("Melt window dissolve & scanlines") },
        { id: "cyberpunk", name: Tr.tr("Cyberpunk"), icon: "auto_awesome", desc: Tr.tr("Wax rainbow ring & comet tail") }
    ]

    readonly property list<var> focusPresets: [
        { id: "rainbow-ripple", name: Tr.tr("Rainbow Ripple"), icon: "gradient", desc: Tr.tr("Flowing pastel wax colors") },
        { id: "lightning", name: Tr.tr("Lightning & Glow"), icon: "bolt", desc: Tr.tr("Traveling electric pulse with light spill") },
        { id: "pulse", name: BiriShaders.pulseMatchTheme ? Tr.tr("Theme Pulse") : Tr.tr("Cyan Pulse"), icon: "lens_blur", desc: BiriShaders.pulseMatchTheme ? Tr.tr("Breathing glow matching background colors") : Tr.tr("Subtle breathing cyan glow") }
    ]

    readonly property list<var> pulseModes: [
        { id: "blend", name: Tr.tr("Dual-Tone Shift (Primary + Accent)"), desc: Tr.tr("Breathing transition between primary and accent colors") },
        { id: "primary", name: Tr.tr("Primary Accent Only"), desc: Tr.tr("Pure pulse of the wallpaper primary accent") },
        { id: "spectrum", name: Tr.tr("Wallpaper Spectrum Cycle"), desc: Tr.tr("Tri-color cycle across primary, secondary, and tertiary tones") },
        { id: "cyan", name: Tr.tr("Classic Cyan"), desc: Tr.tr("Original fixed cyan pulse") }
    ]

    readonly property list<var> animPresets: [
        { id: "whirlpool", name: Tr.tr("Whirlpool"), icon: "cyclone", desc: Tr.tr("Vortex spiral collapse on close") },
        { id: "melt", name: Tr.tr("Melt"), icon: "water_drop", desc: Tr.tr("Liquid drip dissolving effect") },
        { id: "lightning", name: Tr.tr("Lightning Shock"), icon: "flash_on", desc: Tr.tr("Electrical discharge burn") },
        { id: "ripple", name: Tr.tr("Ripple"), icon: "waves", desc: Tr.tr("Water ripple distortion wave") }
    ]

    readonly property list<var> cursorPresets: [
        { id: "locator", name: Tr.tr("Adaptive Halo (Recommended)"), icon: "adjust", desc: Tr.tr("Compact 20px adaptive ring with contrast against light and dark content") },
        { id: "spotlight", name: Tr.tr("Presentation Spotlight"), icon: "present_to_all", desc: Tr.tr("Dims screen with focused beam and pointer ring for talks") },
        { id: "trail", name: Tr.tr("Motion Trail"), icon: "timeline", desc: Tr.tr("Smooth temporal cursor motion trail") },
        { id: "blueglow", name: Tr.tr("Soft Blue Glow"), icon: "blur_on", desc: Tr.tr("Compact glowing aura around cursor") },
        { id: "comet-glow", name: Tr.tr("Comet Glow Trail"), icon: "auto_awesome", desc: Tr.tr("Rainbow cursor comet tail") },
        { id: "ripple", name: Tr.tr("Cursor Ripple"), icon: "motion_photos_on", desc: Tr.tr("Expanding waves on mouse movement") },
        { id: "shockwave", name: Tr.tr("Shockwave"), icon: "flare", desc: Tr.tr("High-energy shockwave pulse") },
        { id: "rainbow-tunnel", name: Tr.tr("Rainbow Tunnel"), icon: "tunnel", desc: Tr.tr("Concentric rainbow tunnel at mouse") }
    ]

    readonly property list<var> screenPresets: [
        { id: "crt", name: Tr.tr("CRT Scanlines"), icon: "tv", desc: Tr.tr("Full-screen retro CRT monitor lines") },
        { id: "vignette", name: Tr.tr("Vignette"), icon: "vignette", desc: Tr.tr("Darkened cinematic screen edges") },
        { id: "grayscale", name: Tr.tr("Grayscale"), icon: "contrast", desc: Tr.tr("Monochromatic black and white") },
        { id: "warmtint", name: Tr.tr("Warm Night Tint"), icon: "wb_sunny", desc: Tr.tr("Gentle amber evening color tint") }
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

                border.width: BiriShaders.focusRingEnabled ? Math.max(1, BiriShaders.focusRingWidth) : 1
                border.color: {
                    if (!BiriShaders.focusRingEnabled)
                        return Colours.palette.m3outlineVariant;
                    if (BiriShaders.focusRingPreset === "lightning")
                        return "#00E5FF";
                    if (BiriShaders.focusRingPreset === "pulse")
                        return BiriShaders.pulseMatchTheme ? Colours.palette.m3primary : "#26C6DA";
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

        // ---------------- Quick Presets ----------------
        SectionHeader {
            first: true
            text: Tr.tr("Quick Presets")
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Tokens.spacing.extraSmall
            columnSpacing: Tokens.spacing.extraSmall

            Repeater {
                model: root.presetCards

                StyledRect {
                    id: presetBtn

                    required property var modelData

                    readonly property bool isActive: BiriShaders.activePreset === modelData.id

                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: Tokens.rounding.medium
                    color: presetBtn.isActive ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
                    border.color: presetBtn.isActive ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                    border.width: presetBtn.isActive ? 1.5 : 1

                    Behavior on color { CAnim {} }
                    Behavior on border.color { CAnim {} }

                    StateLayer {
                        radius: parent.radius
                        color: presetBtn.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        onClicked: BiriShaders.applyPreset(presetBtn.modelData.id)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        StyledRect {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Tokens.rounding.small
                            color: presetBtn.isActive ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: presetBtn.modelData.icon
                                size: 18
                                color: presetBtn.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: presetBtn.modelData.name
                                font: Tokens.font.label.medium
                                color: presetBtn.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: presetBtn.modelData.desc
                                font: Tokens.font.body.small
                                color: presetBtn.isActive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // ---------------- Section 1: Focus Ring & Border Shaders ----------------
        SectionHeader {
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

        ToggleRow {
            visible: BiriShaders.focusRingPreset === "pulse"
            text: Tr.tr("Match desktop background colors")
            subtext: Tr.tr("Dynamically synchronize pulse glow with your active wallpaper palette")
            enabled: BiriShaders.focusRingEnabled
            checked: BiriShaders.pulseMatchTheme
            onToggled: BiriShaders.pulseMatchTheme = checked
        }

        SelectRow {
            visible: BiriShaders.focusRingPreset === "pulse" && BiriShaders.pulseMatchTheme
            label: Tr.tr("Pulse color mode")
            subtext: root.pulseModes.find(p => p.id === BiriShaders.pulseColorMode)?.desc ?? ""
            enabled: BiriShaders.focusRingEnabled
            menuItems: pulseMenuItems.instances
            active: pulseMenuItems.instances.find(i => i.modelData?.id === BiriShaders.pulseColorMode) ?? null
            onSelected: item => {
                if (item.modelData)
                    BiriShaders.pulseColorMode = item.modelData.id;
            }

            Variants {
                id: pulseMenuItems

                model: root.pulseModes

                MenuItem {
                    required property var modelData

                    text: modelData.name
                }
            }
        }

        SliderRow {
            visible: BiriShaders.focusRingPreset === "pulse"
            icon: "speed"
            label: Tr.tr("Pulse speed")
            valueLabel: `${BiriShaders.pulseSpeed.toFixed(1)}x`
            value: (BiriShaders.pulseSpeed - 0.5) / 2.5
            enabled: BiriShaders.focusRingEnabled
            onMoved: v => BiriShaders.pulseSpeed = Math.max(0.5, Math.min(3.0, 0.5 + v * 2.5))
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
            visible: BiriShaders.lightSpillEnabled
            icon: "blur_circular"
            label: Tr.tr("Light spread")
            valueLabel: `${Math.round(BiriShaders.lightSpread)} px`
            value: (BiriShaders.lightSpread - 4) / 56.0
            enabled: BiriShaders.focusRingEnabled && BiriShaders.lightSpillEnabled
            onMoved: v => BiriShaders.lightSpread = Math.max(4, Math.min(60, Math.round(4 + v * 56)))
        }

        SliderRow {
            visible: BiriShaders.lightSpillEnabled
            icon: "wb_incandescent"
            label: Tr.tr("Light spill intensity")
            valueLabel: `${Math.round(BiriShaders.lightIntensity * 100)}%`
            value: (BiriShaders.lightIntensity - 0.1) / 0.9
            enabled: BiriShaders.focusRingEnabled && BiriShaders.lightSpillEnabled
            onMoved: v => BiriShaders.lightIntensity = Math.max(0.1, Math.min(1.0, 0.1 + v * 0.9))
        }

        SliderRow {
            last: true
            visible: BiriShaders.lightSpillEnabled
            icon: "tune"
            label: Tr.tr("Light spill threshold")
            valueLabel: `${Math.round(BiriShaders.lightThreshold * 100)}%`
            value: (BiriShaders.lightThreshold - 0.1) / 0.8
            enabled: BiriShaders.focusRingEnabled && BiriShaders.lightSpillEnabled
            onMoved: v => BiriShaders.lightThreshold = Math.max(0.1, Math.min(0.9, 0.1 + v * 0.8))
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

        SliderRow {
            icon: "timer"
            label: Tr.tr("Animation duration")
            valueLabel: `${BiriShaders.windowAnimDuration} ms`
            value: (BiriShaders.windowAnimDuration - 150) / 650.0
            enabled: BiriShaders.windowAnimEnabled
            onMoved: v => BiriShaders.windowAnimDuration = Math.round(150 + v * 650)
        }

        SliderRow {
            visible: BiriShaders.windowAnimPreset === "whirlpool"
            icon: "cyclone"
            label: Tr.tr("Whirlpool spiral twist")
            valueLabel: `${BiriShaders.whirlpoolTwist.toFixed(1)} turns`
            value: (BiriShaders.whirlpoolTwist - 0.5) / 2.5
            enabled: BiriShaders.windowAnimEnabled
            onMoved: v => BiriShaders.whirlpoolTwist = Math.max(0.5, Math.min(3.0, 0.5 + v * 2.5))
        }

        SliderRow {
            visible: BiriShaders.windowAnimPreset === "whirlpool"
            icon: "compress"
            label: Tr.tr("Scale damping")
            valueLabel: `${Math.round(BiriShaders.animScaleDamping * 100)}%`
            value: (BiriShaders.animScaleDamping - 0.1) / 0.8
            enabled: BiriShaders.windowAnimEnabled
            onMoved: v => BiriShaders.animScaleDamping = Math.max(0.1, Math.min(0.9, 0.1 + v * 0.8))
        }

        ToggleRow {
            last: true
            visible: BiriShaders.windowAnimPreset === "whirlpool"
            text: Tr.tr("Theme accent color dissolve")
            subtext: Tr.tr("Tint dissolving edges with Material 3 wallpaper palette")
            enabled: BiriShaders.windowAnimEnabled
            checked: BiriShaders.animThemeTint
            onToggled: BiriShaders.animThemeTint = checked
        }

        // ---------------- Section 3: Mouse & Pointer Locator FX ----------------
        SectionHeader {
            text: Tr.tr("Mouse & Pointer Locator FX")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enable cursor locator")
            subtext: Tr.tr("Highlight cursor position for easy tracking and presentations")
            checked: BiriShaders.isCursorShaderActive
            onToggled: {
                if (checked) {
                    const hasValidCursor = root.cursorPresets.some(p => p.id === BiriShaders.globalShaderPreset);
                    BiriShaders.selectCursorShader(hasValidCursor ? BiriShaders.globalShaderPreset : "locator");
                } else {
                    BiriShaders.selectCursorShader("none");
                }
            }
        }

        SelectRow {
            last: true
            label: Tr.tr("Cursor effect style")
            subtext: root.cursorPresets.find(p => p.id === BiriShaders.globalShaderPreset)?.desc ?? ""
            enabled: BiriShaders.isCursorShaderActive
            menuItems: cursorMenuItems.instances
            active: cursorMenuItems.instances.find(i => i.modelData?.id === BiriShaders.globalShaderPreset) ?? null
            onSelected: item => {
                if (item.modelData)
                    BiriShaders.selectCursorShader(item.modelData.id);
            }

            Variants {
                id: cursorMenuItems

                model: root.cursorPresets

                MenuItem {
                    required property var modelData

                    text: modelData.name
                }
            }
        }

        // ---------------- Section 4: Screen Post-Process Filters ----------------
        SectionHeader {
            text: Tr.tr("Screen Post-Process Filters")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enable screen filter")
            subtext: Tr.tr("Full-display post-processing, CRT scanlines, and color grading")
            checked: BiriShaders.isScreenFilterActive
            onToggled: {
                if (checked) {
                    const hasValidScreen = root.screenPresets.some(p => p.id === BiriShaders.globalShaderPreset);
                    BiriShaders.selectScreenFilter(hasValidScreen ? BiriShaders.globalShaderPreset : "crt");
                } else {
                    BiriShaders.selectScreenFilter("none");
                }
            }
        }

        SelectRow {
            label: Tr.tr("Screen filter style")
            subtext: root.screenPresets.find(p => p.id === BiriShaders.globalShaderPreset)?.desc ?? ""
            enabled: BiriShaders.isScreenFilterActive
            menuItems: screenMenuItems.instances
            active: screenMenuItems.instances.find(i => i.modelData?.id === BiriShaders.globalShaderPreset) ?? null
            onSelected: item => {
                if (item.modelData)
                    BiriShaders.selectScreenFilter(item.modelData.id);
            }

            Variants {
                id: screenMenuItems

                model: root.screenPresets

                MenuItem {
                    required property var modelData

                    text: modelData.name
                }
            }
        }

        SliderRow {
            visible: BiriShaders.isScreenFilterActive && BiriShaders.globalShaderPreset === "crt"
            icon: "density_medium"
            label: Tr.tr("Scanline density")
            valueLabel: `${BiriShaders.scanlineDensity.toFixed(1)}x`
            value: (BiriShaders.scanlineDensity - 0.5) / 1.5
            enabled: BiriShaders.isScreenFilterActive
            onMoved: v => BiriShaders.scanlineDensity = Math.max(0.5, Math.min(2.0, 0.5 + v * 1.5))
        }

        SliderRow {
            visible: BiriShaders.isScreenFilterActive && BiriShaders.globalShaderPreset === "crt"
            icon: "contrast"
            label: Tr.tr("Scanline darkness")
            valueLabel: `${Math.round(BiriShaders.scanlineDarkness * 100)}%`
            value: (BiriShaders.scanlineDarkness - 0.05) / 0.45
            enabled: BiriShaders.isScreenFilterActive
            onMoved: v => BiriShaders.scanlineDarkness = Math.max(0.05, Math.min(0.5, 0.05 + v * 0.45))
        }

        SliderRow {
            visible: BiriShaders.isScreenFilterActive && BiriShaders.globalShaderPreset === "vignette"
            icon: "vignette"
            label: Tr.tr("Vignette strength")
            valueLabel: `${Math.round(BiriShaders.vignetteStrength * 100)}%`
            value: (BiriShaders.vignetteStrength - 0.2) / 0.8
            enabled: BiriShaders.isScreenFilterActive
            onMoved: v => BiriShaders.vignetteStrength = Math.max(0.2, Math.min(1.0, 0.2 + v * 0.8))
        }

        SliderRow {
            last: true
            visible: BiriShaders.isScreenFilterActive && (BiriShaders.globalShaderPreset === "crt" || BiriShaders.globalShaderPreset === "vignette")
            icon: "lens"
            label: Tr.tr("Chromatic aberration")
            valueLabel: `${(BiriShaders.chromaticAberration * 1000).toFixed(1)} ‰`
            value: BiriShaders.chromaticAberration / 0.01
            enabled: BiriShaders.isScreenFilterActive
            onMoved: v => BiriShaders.chromaticAberration = Math.max(0.0, Math.min(0.01, v * 0.01))
        }

        // ---------------- Section 5: Multi-Monitor Carousel Overview ----------------
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

        // ---------------- Section 6: Per-Window Shaders & Cycler ----------------
        SectionHeader {
            text: Tr.tr("Per-Window Shaders & In-Flight Cycler")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enable per-window shaders")
            subtext: Tr.tr("Attach shaders to individual active windows and cycle them live")
            checked: BiriShaders.windowShadersEnabled
            onToggled: BiriShaders.windowShadersEnabled = checked
        }

        RowButton {
            icon: "cycle"
            text: Tr.tr("Cycle Window Shader (Mod+Shift+B)")
            subtext: Tr.tr("Walk focused window through CRT, Parchment, Pixel Mosaic, Mercury Sheen, Shimmer")
            enabled: BiriShaders.windowShadersEnabled
            onClicked: BiriShaders.cycleWindowShader()
        }

        RowButton {
            last: true
            icon: "power_settings_new"
            text: Tr.tr("Toggle Window Shader (Mod+Alt+B)")
            subtext: Tr.tr("Instantly toggle the active window's shader on or off")
            enabled: BiriShaders.windowShadersEnabled
            onClicked: BiriShaders.toggleWindowShader()
        }

        // ---------------- Section 7: Per-Output Colour Filters ----------------
        SectionHeader {
            text: Tr.tr("Per-Output Colour Filters")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enable per-output colour filters")
            subtext: Tr.tr("Built-in display color grades without writing custom GLSL")
            checked: BiriShaders.outputShadersEnabled
            onToggled: BiriShaders.outputShadersEnabled = checked
        }

        RowButton {
            icon: "palette"
            text: Tr.tr("Cycle Output Colour Filter (Mod+Shift+C)")
            subtext: Tr.tr("Rotate active display through Grayscale, Invert, Warm Night Tint, and Vivid")
            enabled: BiriShaders.outputShadersEnabled
            onClicked: BiriShaders.cycleOutputShader()
        }

        RowButton {
            last: true
            icon: "power_settings_new"
            text: Tr.tr("Toggle Output Colour Filter (Mod+Alt+C)")
            subtext: Tr.tr("Instantly toggle the active monitor's color filter on or off")
            enabled: BiriShaders.outputShadersEnabled
            onClicked: BiriShaders.toggleOutputShader()
        }

        // ---------------- Section 8: Performance & Reset ----------------
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
            icon: "restart_alt"
            text: Tr.tr("Reset Shaders to Default")
            subtext: Tr.tr("Turn off custom shaders and restore standard Niri rendering")
            onClicked: BiriShaders.resetToDefaults()
        }
    }
}

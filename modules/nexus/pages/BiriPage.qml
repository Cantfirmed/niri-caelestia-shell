pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Biri Compositor")

    ColumnLayout {
        id: mainLayout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // ---------------- Section 1: Floating PiP Video Rules ----------------
        SectionHeader {
            first: true
            text: Tr.tr("Picture-in-Picture & Floating Videos")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enable floating PiP rules")
            subtext: Tr.tr("Automatically configure Picture-in-Picture video windows")
            checked: Biri.pipFloatingEnabled
            onToggled: Biri.pipFloatingEnabled = checked
        }

        ToggleRow {
            text: Tr.tr("Float above fullscreen windows")
            subtext: Tr.tr("Keep floating PiP videos visible on top when applications or games enter fullscreen")
            checked: Biri.pipFloatAboveFullscreen
            enabled: Biri.pipFloatingEnabled
            onToggled: Biri.pipFloatAboveFullscreen = checked
        }

        ToggleRow {
            text: Tr.tr("Sticky across workspaces")
            subtext: Tr.tr("Pin PiP videos so they follow your screen across columns and workspace switches")
            checked: Biri.pipSticky
            enabled: Biri.pipFloatingEnabled
            onToggled: Biri.pipSticky = checked
        }

        SliderRow {
            icon: "straighten"
            label: Tr.tr("Default PiP width")
            valueLabel: `${Math.round(Biri.pipWidthProportion * 100)} %`
            value: (Biri.pipWidthProportion - 0.15) / 0.35
            enabled: Biri.pipFloatingEnabled
            onMoved: v => Biri.pipWidthProportion = Math.max(0.15, Math.min(0.50, 0.15 + v * 0.35))
        }

        SliderRow {
            icon: "height"
            label: Tr.tr("Default PiP height")
            valueLabel: `${Math.round(Biri.pipHeightProportion * 100)} %`
            value: (Biri.pipHeightProportion - 0.15) / 0.35
            enabled: Biri.pipFloatingEnabled
            onMoved: v => Biri.pipHeightProportion = Math.max(0.15, Math.min(0.50, 0.15 + v * 0.35))
        }

        TextFieldRow {
            last: true
            label: Tr.tr("Custom video app regex")
            subtext: Tr.tr("Additional app-id patterns to float and pin (e.g. mpv|celluloid)")
            value: Biri.pipCustomAppRegex
            placeholderText: "mpv|celluloid"
            enabled: Biri.pipFloatingEnabled
            onEditingFinished: v => Biri.pipCustomAppRegex = v
        }

        // ---------------- Section 2: Window Layout & Screen Gaps ----------------
        ScreenGapsSection {}

        // ---------------- Section 3: Display & Layout ----------------
        SectionHeader {
            text: Tr.tr("Display & Layout")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Vertical scrolling for portrait monitor")
            subtext: Tr.tr("Arrange windows in top-to-bottom rows instead of horizontal columns on rotated screens")
            checked: Biri.portraitVerticalLayoutEnabled
            onToggled: Biri.portraitVerticalLayoutEnabled = checked
        }

        TextFieldRow {
            label: Tr.tr("Portrait output name")
            subtext: Tr.tr("Monitor identifier (e.g. DP-2, HDMI-A-1)")
            value: Biri.portraitOutput
            placeholderText: "DP-2"
            enabled: Biri.portraitVerticalLayoutEnabled
            onEditingFinished: v => Biri.portraitOutput = v
        }

        SliderRow {
            icon: "table_rows"
            label: Tr.tr("Portrait row height")
            valueLabel: `${Math.round(Biri.verticalRowProportion * 100)} %`
            value: (Biri.verticalRowProportion - 0.25) / 0.50
            enabled: Biri.portraitVerticalLayoutEnabled
            onMoved: v => Biri.verticalRowProportion = Math.max(0.25, Math.min(0.75, 0.25 + v * 0.50))
        }

        ToggleRow {
            text: Tr.tr("Isolated presentation display")
            subtext: Tr.tr("Strip compositor UI (Overview, Alt-Tab, notifications) off a dedicated monitor or capture feed")
            checked: Biri.isolatedOutputEnabled
            onToggled: Biri.isolatedOutputEnabled = checked
        }

        TextFieldRow {
            last: true
            label: Tr.tr("Isolated output name")
            subtext: Tr.tr("Display name to isolate (e.g. HDMI-A-1)")
            value: Biri.isolatedOutputName
            placeholderText: "HDMI-A-1"
            enabled: Biri.isolatedOutputEnabled
            onEditingFinished: v => Biri.isolatedOutputName = v
        }

        // ---------------- Section 3: Overview & Capture ----------------
        SectionHeader {
            text: Tr.tr("Overview & Capture")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Dynamic multi-stage overview zoom")
            subtext: Tr.tr("Enable progressive zoom presets with Mod+Scroll while in the overview")
            checked: Biri.dynamicOverviewZoomEnabled
            onToggled: Biri.dynamicOverviewZoomEnabled = checked
        }

        TextFieldRow {
            label: Tr.tr("Overview zoom presets")
            subtext: Tr.tr("Space-separated zoom levels from standard to bird's-eye")
            value: Biri.overviewZoomPresets
            placeholderText: "0.5 0.25 0.1"
            enabled: Biri.dynamicOverviewZoomEnabled
            onEditingFinished: v => Biri.overviewZoomPresets = v
        }

        ToggleRow {
            last: true
            text: Tr.tr("Include shaders in screen recordings")
            subtext: Tr.tr("Allow compositor post-process shaders in portal screencasts and OBS/Discord streams")
            checked: Biri.shadersInCapture
            onToggled: Biri.shadersInCapture = checked
        }

        // ---------------- Section 4: Input & Trackpad ----------------
        SectionHeader {
            text: Tr.tr("Runtime Input Toggles")
        }

        RowButton {
            first: true
            icon: "touchpad_mouse"
            text: Tr.tr("Toggle Touchpad")
            subtext: Tr.tr("Instantly toggle the touchpad on or off via runtime IPC")
            onClicked: Biri.toggleTouchpad()
        }

        RowButton {
            last: true
            icon: "keyboard"
            text: Tr.tr("Toggle Disable-While-Typing (DWT)")
            subtext: Tr.tr("Toggle touchpad palm rejection while typing at runtime")
            onClicked: Biri.toggleDwt()
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Internal
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Window blur")

    property bool previewInactive: false
    property bool showAddManual: false
    property string manualId: ""
    property string manualType: "app-id"

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
            implicitHeight: Math.min(Math.round(root.cappedWidth * 0.45), 240)

            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large
            clip: true

            // Wallpaper backdrop
            FadeImage {
                anchors.fill: parent
                source: Wallpapers.current
                fillMode: Image.PreserveAspectCrop
                opacity: Config.background.wallpaperEnabled ? 0.7 : 0.2
            }

            // Darkening tint layer
            StyledRect {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.4)
                radius: Tokens.rounding.large
            }

            // Mock window floating in the center
            StyledRect {
                id: mockWindow

                anchors.centerIn: parent
                width: Math.min(parent.width - Tokens.padding.extraLarge * 2, 420)
                height: Math.min(parent.height - Tokens.padding.extraLarge * 2, 170)
                radius: Tokens.rounding.medium

                readonly property real targetOpacity: {
                    if (!NiriBlur.blurEnabled)
                        return 1.0;
                    return root.previewInactive && NiriBlur.inactiveOpacityEnabled ? NiriBlur.inactiveOpacity : NiriBlur.activeOpacity;
                }

                color: Qt.rgba(
                    Colours.palette.m3surface.r,
                    Colours.palette.m3surface.g,
                    Colours.palette.m3surface.b,
                    targetOpacity
                )
                border.color: Colours.palette.m3outlineVariant
                border.width: 1

                Behavior on color {
                    CAnim {}
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    // Title bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        // Window dots
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
                            text: !NiriBlur.blurEnabled
                                ? qsTr("Solid Window (100% Opacity)")
                                : (root.previewInactive && NiriBlur.inactiveOpacityEnabled)
                                    ? qsTr("Inactive Window (%1% Opacity)").arg(Math.round(NiriBlur.inactiveOpacity * 100))
                                    : qsTr("Active Window (%1% Opacity)").arg(Math.round(NiriBlur.activeOpacity * 100))
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        // Preview toggle chip
                        StyledRect {
                            implicitWidth: previewToggleText.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: previewToggleText.implicitHeight + Tokens.padding.extraSmall * 2
                            radius: Tokens.rounding.full
                            color: root.previewInactive ? Colours.palette.m3secondaryContainer : Colours.palette.m3primaryContainer

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                onClicked: root.previewInactive = !root.previewInactive
                            }

                            StyledText {
                                id: previewToggleText
                                anchors.centerIn: parent
                                text: root.previewInactive ? qsTr("Show Active") : qsTr("Show Inactive")
                                font: Tokens.font.label.small
                                color: root.previewInactive ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onPrimaryContainer
                            }
                        }
                    }

                    // Window content mockup
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Tokens.rounding.small
                        color: Qt.rgba(Colours.palette.m3surfaceContainerLowest.r, Colours.palette.m3surfaceContainerLowest.g, Colours.palette.m3surfaceContainerLowest.b, 0.45)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: NiriBlur.blurEnabled ? "blur_on" : "blur_off"
                                fontStyle: Tokens.font.icon.large
                                color: NiriBlur.blurEnabled ? Colours.palette.m3primary : Colours.palette.m3outline
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: NiriBlur.blurEnabled
                                    ? qsTr("Noise: %1%  •  Saturation: %2x").arg(Math.round(NiriBlur.noise * 100)).arg(NiriBlur.saturation.toFixed(1))
                                    : qsTr("Blur is disabled")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        // ---------------- Global Window Blur ----------------
        SectionHeader {
            first: true
            text: qsTr("Window Blur & Transparency")
        }

        ToggleRow {
            first: true
            text: qsTr("Enable window blur")
            subtext: qsTr("Apply background blur and opacity effects to niri windows")
            checked: NiriBlur.blurEnabled
            onToggled: NiriBlur.blurEnabled = checked
        }

        SliderRow {
            icon: "opacity"
            label: qsTr("Active window opacity")
            value: NiriBlur.activeOpacity
            valueLabel: Math.round(value * 100) + "%"
            enabled: NiriBlur.blurEnabled
            onMoved: v => NiriBlur.activeOpacity = Math.max(0.1, Math.min(1.0, Math.round(v * 100) / 100))
        }

        ToggleRow {
            text: qsTr("Separate inactive window opacity")
            subtext: qsTr("Apply different transparency when windows are not focused")
            checked: NiriBlur.inactiveOpacityEnabled
            enabled: NiriBlur.blurEnabled
            onToggled: NiriBlur.inactiveOpacityEnabled = checked
        }

        SliderRow {
            icon: "contrast"
            label: qsTr("Inactive window opacity")
            value: NiriBlur.inactiveOpacity
            valueLabel: Math.round(value * 100) + "%"
            enabled: NiriBlur.blurEnabled && NiriBlur.inactiveOpacityEnabled
            onMoved: v => NiriBlur.inactiveOpacity = Math.max(0.1, Math.min(1.0, Math.round(v * 100) / 100))
        }

        SliderRow {
            icon: "grain"
            label: qsTr("Blur noise")
            value: NiriBlur.noise
            valueLabel: Math.round(value * 100) + "%"
            enabled: NiriBlur.blurEnabled
            onMoved: v => NiriBlur.noise = Math.max(0.0, Math.min(1.0, Math.round(v * 100) / 100))
        }

        SliderRow {
            last: true
            icon: "palette"
            label: qsTr("Blur saturation")
            value: NiriBlur.saturation / 10.0
            valueLabel: (value * 10.0).toFixed(1) + "x"
            enabled: NiriBlur.blurEnabled
            onMoved: v => NiriBlur.saturation = Math.max(0.0, Math.min(10.0, Math.round(v * 100) / 10.0))
        }

        // ---------------- Videos & Media ----------------
        SectionHeader {
            text: qsTr("Videos & Media")
        }

        ToggleRow {
            first: true
            text: qsTr("Disable blur for video players")
            subtext: qsTr("mpv, VLC, Celluloid, Totem, Kodi, Plex, FreeTube, Jellyfin")
            checked: NiriBlur.videoPlayersEnabled
            onToggled: NiriBlur.videoPlayersEnabled = checked
        }

        ToggleRow {
            text: qsTr("Disable blur for Picture-in-Picture (PiP)")
            subtext: qsTr("Ensure floating PiP video windows are completely opaque")
            checked: NiriBlur.pipEnabled
            onToggled: NiriBlur.pipEnabled = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Disable blur on web video streaming tabs")
            subtext: qsTr("YouTube, Twitch, Netflix, Prime Video, Disney+, Hulu, Bilibili")
            checked: NiriBlur.videoStreamsEnabled
            onToggled: NiriBlur.videoStreamsEnabled = checked
        }

        // ---------------- Full Screen Videos ----------------
        SectionHeader {
            text: qsTr("Full Screen Videos")
        }

        ToggleRow {
            first: true
            text: qsTr("Disable blur on full screen video")
            subtext: qsTr("Force 100% opacity and disable blur when videos play in fullscreen")
            checked: NiriBlur.fullscreenVideoEnabled
            onToggled: NiriBlur.fullscreenVideoEnabled = checked
        }

        TextFieldRow {
            last: true
            label: qsTr("Full screen title match")
            subtext: qsTr("Regex pattern matching full screen video window titles")
            value: NiriBlur.fullscreenVideoRegex
            enabled: NiriBlur.fullscreenVideoEnabled
            onEditingFinished: v => {
                if (v && v.trim().length > 0)
                    NiriBlur.fullscreenVideoRegex = v.trim();
            }
        }

        // ---------------- Window Exceptions ----------------
        SectionHeader {
            text: qsTr("Window Exceptions")
        }

        // Quick add from running windows
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            implicitHeight: quickAddCol.implicitHeight + Tokens.padding.largeIncreased * 2

            ColumnLayout {
                id: quickAddCol
                anchors.fill: parent
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "apps"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Quick-add open window")
                        font: Tokens.font.body.small
                    }

                    IconButton {
                        icon: root.showAddManual ? "expand_less" : "add"
                        type: IconButton.Tonal
                        isRound: true
                        font: Tokens.font.icon.small
                        onClicked: root.showAddManual = !root.showAddManual
                    }
                }

                // Running window chip list
                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    readonly property var uniqueWindows: {
                        const wins = NiriIpc.windows || [];
                        const list = [];
                        const seen = new Set();
                        for (let i = 0; i < wins.length; i++) {
                            const w = wins[i];
                            if (w && w.app_id && !seen.has(w.app_id)) {
                                seen.add(w.app_id);
                                list.push(w);
                            }
                        }
                        return list;
                    }

                    Repeater {
                        model: parent.uniqueWindows

                        StyledRect {
                            id: winChip

                            required property var modelData
                            readonly property bool alreadyAdded: {
                                const list = NiriBlur.exceptions || [];
                                for (let i = 0; i < list.length; i++) {
                                    if (list[i].id === winChip.modelData.app_id || list[i].id === `${winChip.modelData.app_id}$`)
                                        return true;
                                }
                                return false;
                            }

                            implicitWidth: chipRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: chipRow.implicitHeight + Tokens.padding.extraSmall * 2
                            radius: Tokens.rounding.full
                            color: alreadyAdded ? Colours.tPalette.m3surfaceContainerHigh : Colours.palette.m3secondaryContainer

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                disabled: winChip.alreadyAdded
                                onClicked: {
                                    NiriBlur.addException(`${winChip.modelData.app_id}$`, "app-id", 1.0, false);
                                }
                            }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    text: winChip.alreadyAdded ? "check" : "add"
                                    fontStyle: Tokens.font.icon.small
                                    color: winChip.alreadyAdded ? Colours.palette.m3outline : Colours.palette.m3onSecondaryContainer
                                }

                                StyledText {
                                    text: winChip.modelData.app_id
                                    font: Tokens.font.label.small
                                    color: winChip.alreadyAdded ? Colours.palette.m3outline : Colours.palette.m3onSecondaryContainer
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: parent.uniqueWindows.length === 0
                        text: qsTr("No active windows detected")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3outline
                    }
                }

                // Manual add form if expanded
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.showAddManual
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledTextField {
                            id: manualField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Enter app-id or regex (e.g. discord$)")
                            onTextEdited: root.manualId = text
                        }

                        StyledRect {
                            implicitWidth: addBtnRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: manualField.implicitHeight
                            radius: Tokens.rounding.medium
                            color: Colours.palette.m3primary

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                disabled: root.manualId.trim().length === 0
                                onClicked: {
                                    if (root.manualId.trim().length > 0) {
                                        NiriBlur.addException(root.manualId.trim(), "app-id", 1.0, false);
                                        manualField.clear();
                                        root.manualId = "";
                                        root.showAddManual = false;
                                    }
                                }
                            }

                            RowLayout {
                                id: addBtnRow
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    text: "add"
                                    color: Colours.palette.m3onPrimary
                                    fontStyle: Tokens.font.icon.small
                                }

                                StyledText {
                                    text: qsTr("Add")
                                    color: Colours.palette.m3onPrimary
                                    font: Tokens.font.label.medium
                                }
                            }
                        }
                    }
                }
            }
        }

        // List of existing exceptions
        Repeater {
            model: NiriBlur.exceptions

            ConnectedRect {
                id: exItem

                required property var modelData
                required property int index

                Layout.fillWidth: true
                last: index === (NiriBlur.exceptions ? NiriBlur.exceptions.length - 1 : 0)
                implicitHeight: exRow.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: exRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: exItem.modelData.type === "title" ? "title" : "window"
                        color: exItem.modelData.enabled ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: exItem.modelData.id
                            font: Tokens.font.body.small
                            color: exItem.modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Type: %1  •  Opacity: %2%  •  Blur: %3")
                                .arg(exItem.modelData.type || "app-id")
                                .arg(Math.round((exItem.modelData.opacity !== undefined ? exItem.modelData.opacity : 1.0) * 100))
                                .arg(exItem.modelData.blur ? qsTr("on") : qsTr("off"))
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledSwitch {
                        checked: exItem.modelData.enabled
                        font: Tokens.font.icon.medium
                        onToggled: NiriBlur.toggleException(exItem.index, checked)
                    }

                    IconButton {
                        type: IconButton.Text
                        isRound: true
                        icon: "delete"
                        inactiveOnColour: Colours.palette.m3error
                        font: Tokens.font.icon.medium
                        label.fill: 0
                        onClicked: NiriBlur.removeException(exItem.index)
                    }
                }
            }
        }

        // ---------------- Reset Action ----------------
        SectionHeader {
            text: qsTr("Reset")
        }

        RowButton {
            first: true
            last: true
            icon: "restart_alt"
            text: qsTr("Reset to defaults")
            subtext: qsTr("Restore default Niri blur, opacity, and exception rules")
            onClicked: NiriBlur.resetToDefaults()
        }
    }
}

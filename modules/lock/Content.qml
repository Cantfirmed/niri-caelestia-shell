import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    required property var lock

    readonly property real contentScale: Math.max(0.75, Config.appearance.font.scale * 0.6 + Config.appearance.padding.scale * 0.25 + Config.appearance.spacing.scale * 0.15)
    readonly property real effectiveHeight: root.height / contentScale

    spacing: Math.min(Tokens.spacing.largeIncreased * 2, Math.max(Tokens.spacing.small, Math.round(root.width * 0.04)))

    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        Layout.fillHeight: true
        Layout.maximumHeight: root.height
        spacing: Tokens.spacing.medium

        WeatherInfo {
            Layout.fillWidth: true
            rootHeight: root.height
            effectiveHeight: root.effectiveHeight
        }

        Fetch {
            Layout.fillWidth: true
            rootHeight: root.height
            effectiveHeight: root.effectiveHeight
        }

        Media {
            Layout.fillWidth: true
            Layout.fillHeight: true
            rootHeight: root.height
            lock: root.lock
        }
    }

    Center {
        lock: root.lock
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        Layout.fillHeight: true
        Layout.maximumHeight: root.height
        spacing: Tokens.spacing.medium

        Resources {
            Layout.fillWidth: true
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            bottomRightRadius: Tokens.rounding.extraLarge
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainer

            NotifDock {
                lock: root.lock
            }
        }
    }
}

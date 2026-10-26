pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    property string keyString: ""
    spacing: Tokens.spacing.extraSmall

    readonly property var parts: keyString ? keyString.split(" + ") : []

    Repeater {
        model: root.parts

        RowLayout {
            required property string modelData
            required property int index

            spacing: Tokens.spacing.extraSmall

            StyledRect {
                implicitHeight: 22
                implicitWidth: keyLabel.implicitWidth + 12
                radius: Tokens.rounding.small
                color: Colours.tPalette.m3surfaceContainerHigh
                border.width: 1
                border.color: Colours.palette.m3outlineVariant

                StyledText {
                    id: keyLabel
                    anchors.centerIn: parent
                    text: modelData
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Colours.palette.m3primary
                }
            }

            StyledText {
                visible: index < root.parts.length - 1
                text: "+"
                font.family: "monospace"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: Colours.palette.m3outline
            }
        }
    }
}

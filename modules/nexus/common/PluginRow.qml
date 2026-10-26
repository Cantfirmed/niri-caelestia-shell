pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A card row for a shell "plugin" (feature module) with an enable/disable switch.
// Clicking anywhere on the row toggles it; the trailing button (if any) opens it.
ConnectedRect {
    id: root

    property alias icon: iconLabel.text
    property alias title: titleLabel.text
    property alias description: descriptionLabel.text
    property string statusText
    property bool actionVisible
    property alias checked: toggle.checked
    property alias disabled: stateLayer.disabled

    readonly property alias toggle: toggle

    signal toggled(bool checked)
    signal activated

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    StateLayer {
        id: stateLayer

        onClicked: root.toggled(!root.checked)
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            id: iconLabel

            Layout.alignment: Qt.AlignVCenter

            color: root.checked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
            fill: 1

            Behavior on color {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: titleLabel

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                id: descriptionLabel

                Layout.fillWidth: true
                visible: text
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: text
            text: root.statusText
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            visible: root.actionVisible

            icon: "open_in_new"
            type: IconButton.Tonal
            isRound: true
            onClicked: root.activated()
        }

        StyledSwitch {
            id: toggle

            Layout.alignment: Qt.AlignVCenter
            cLayer: 2

            onToggled: root.toggled(checked)
        }
    }
}

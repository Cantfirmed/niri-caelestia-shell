import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property var client
    signal close()

    implicitWidth: child.implicitWidth
    implicitHeight: screen.height * Tokens.sizes.winfo.heightMult

    // Floating close button in top right
    StyledRect {
        id: closeButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.medium
        z: 100

        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainerHigh
        implicitWidth: 32
        implicitHeight: 32

        StateLayer {
            color: Colours.palette.m3primary
            onClicked: root.close()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "close"
            fontStyle: Tokens.font.icon.medium
            color: Colours.palette.m3onSurface
        }
    }

    RowLayout {
        id: child

        anchors.fill: parent
        anchors.margins: Tokens.padding.large

        spacing: Tokens.spacing.medium

        Preview {
            screen: root.screen
            client: root.client
        }

        ColumnLayout {
            spacing: Tokens.spacing.medium

            Layout.preferredWidth: Tokens.sizes.winfo.detailsWidth
            Layout.fillHeight: true

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.large

                Details {
                    client: root.client
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: buttons.implicitHeight

                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.large

                Buttons {
                    id: buttons

                    client: root.client
                }
            }
        }
    }
}

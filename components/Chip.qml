import qs.services
import Caelestia.Config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    property string text
    property string icon
    property bool selected: false
    property bool closable: false

    signal clicked()
    signal closeClicked()

    radius: Tokens.rounding.small
    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: row.implicitHeight + Tokens.padding.extraSmall * 2

    color: selected ? Colours.palette.m3secondaryContainer : "transparent"
    border.width: selected ? 0 : 1
    border.color: Colours.palette.m3outline

    StateLayer {
        radius: root.radius
        color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface

        onClicked: root.clicked()
    }

    RowLayout {
        id: row

        anchors {
            verticalCenter: parent ? parent.verticalCenter : undefined
            horizontalCenter: parent ? parent.horizontalCenter : undefined
        }
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            visible: root.icon.length > 0
            text: root.icon
            fontStyle: Tokens.font.icon.small
            color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            text: root.text
            font: Tokens.font.label.large
            color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        }

        MaterialIcon {
            visible: root.closable
            text: "close"
            fontStyle: Tokens.font.icon.small
            color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeClicked()
            }
        }
    }
}


pragma ComponentBehavior: Bound

import qs.components
import qs.services
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    spacing: 0

    property Component leftContent: null
    property Component rightContent: null

    property real leftWidthRatio: 0.3
    property int leftMinimumWidth: 280
    property var leftLoaderProperties: ({})
    property var rightLoaderProperties: ({})

    property alias leftLoader: leftLoader
    property alias rightLoader: rightLoader

    Item {
        id: leftPane

        Layout.preferredWidth: Math.floor(parent.width * root.leftWidthRatio)
        Layout.minimumWidth: root.leftMinimumWidth
        Layout.fillHeight: true

        ClippingRectangle {
            id: leftClippingRect

            anchors.fill: parent
            anchors.margins: Appearance.padding.md
            anchors.leftMargin: 0
            anchors.rightMargin: Appearance.padding.md / 2

            radius: 0
            color: "transparent"

            Loader {
                id: leftLoader

                anchors.fill: parent
                anchors.margins: Appearance.padding.xl + Appearance.padding.md
                anchors.leftMargin: Appearance.padding.xl
                anchors.rightMargin: Appearance.padding.xl + Appearance.padding.md / 2

                sourceComponent: root.leftContent

                Component.onCompleted: {
                    for (const key in root.leftLoaderProperties) {
                        leftLoader[key] = root.leftLoaderProperties[key];
                    }
                }
            }
        }

        // Left pane's border removed — both panes were filling with grey
        Item { id: leftBorder }
    }

    Item {
        id: rightPane

        Layout.fillWidth: true
        Layout.fillHeight: true

        ClippingRectangle {
            id: rightClippingRect

            anchors.fill: parent
            anchors.margins: Appearance.padding.md
            anchors.leftMargin: 0
            anchors.rightMargin: Appearance.padding.md / 2

            radius: 0
            color: "transparent"

            Loader {
                id: rightLoader

                anchors.fill: parent
                anchors.margins: Appearance.padding.xl * 2

                sourceComponent: root.rightContent

                Component.onCompleted: {
                    for (const key in root.rightLoaderProperties) {
                        rightLoader[key] = root.rightLoaderProperties[key];
                    }
                }
            }
        }

        // Right pane's border removed — the left pane's InnerBorder already provides the divider
    }
}

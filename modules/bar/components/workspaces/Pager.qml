import qs.components
import qs.services
import Caelestia.Config
import QtQuick

StyledRect {
    id: root
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter

    required property int groupOffset
    required property string outputName

    readonly property var outputWorkspaces: {
        const _ = Niri.allWorkspaces;
        return Niri.getWorkspacesForOutput(outputName);
    }

    Component.onCompleted: active = true
    property bool active: false
    property bool entered: GlobalConfig.bar.workspaces.shown < outputWorkspaces.length && active

    property bool dying: false
    Component.onDestruction: dying = true

    readonly property int wsCount: outputWorkspaces.length
    readonly property int focusedIdx: {
        for (let i = 0; i < outputWorkspaces.length; i++) {
            if (outputWorkspaces[i].is_focused) return i;
        }
        return -1;
    }

    color: Colours.palette.m3surfaceContainer
    radius: entered ? Appearance.rounding.small / 2 : Appearance.rounding.full

    anchors.topMargin: entered ? -Appearance.padding.md : -Tokens.sizes.bar.innerWidth

    width: Tokens.sizes.bar.innerWidth - Appearance.spacing.sm
    height: minimap.height + Appearance.spacing.sm * 2

    Behavior on anchors.topMargin {
        enabled: !root.dying
        Anim {}
    }

    // Scroll-position minimap
    Row {
        id: minimap

        opacity: root.entered ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: root.wsCount

            Rectangle {
                required property int index

                width: Math.max(3, (root.width - minimap.spacing * (root.wsCount - 1) - Appearance.spacing.sm * 2) / root.wsCount)
                height: index === root.focusedIdx ? 6 : 3
                radius: height / 2
                color: index === root.focusedIdx ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    enabled: !root.dying
                    Anim {
                        duration: Appearance.anim.durations.small
                    }
                }

                CAnim on color {}
            }
        }

        Behavior on opacity {
            enabled: !root.dying
            Anim {}
        }
    }
}

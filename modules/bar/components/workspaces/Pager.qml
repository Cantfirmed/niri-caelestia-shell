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
        return Niri.getWorkspacesForOutput(outputName) ?? [];
    }

    Component.onCompleted: active = true
    property bool active: false
    property bool entered: outputWorkspaces && GlobalConfig.bar.workspaces.shown < outputWorkspaces.length && active

    property bool dying: false
    Component.onDestruction: dying = true

    readonly property int wsCount: outputWorkspaces?.length ?? 0
    readonly property int focusedIdx: {
        if (!outputWorkspaces) return -1;
        for (let i = 0; i < outputWorkspaces.length; i++) {
            if (outputWorkspaces[i]?.is_focused) return i;
        }
        return -1;
    }

    color: Colours.palette.m3surfaceContainer
    radius: entered ? Tokens.rounding.small / 2 : Tokens.rounding.full

    anchors.topMargin: entered ? -Tokens.padding.medium : -Tokens.sizes.bar.innerWidth

    width: Math.max(1, Tokens.sizes.bar.innerWidth - Tokens.spacing.small)
    height: minimap.height + Tokens.spacing.small * 2

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
        spacing: Math.max(1, Math.round(2 * Tokens.uiScale))

        Repeater {
            model: root.wsCount

            Rectangle {
                required property int index

                width: Math.max(Math.max(2, Math.round(3 * Tokens.uiScale)), (root.width - minimap.spacing * (root.wsCount - 1) - Tokens.spacing.small * 2) / root.wsCount)
                height: index === root.focusedIdx ? Math.max(3, Math.round(6 * Tokens.uiScale)) : Math.max(2, Math.round(3 * Tokens.uiScale))
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

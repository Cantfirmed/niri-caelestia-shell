import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property var client

    anchors.fill: parent
    spacing: Tokens.spacing.small

    Label {
        Layout.topMargin: Tokens.padding.extraLargeIncreased

        text: root.client?.title ?? qsTr("No active client")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere

        font: Tokens.font.body.builders.large.weight(Font.Medium).build()
    }

    Label {
        text: root.client?.app_id ?? qsTr("No active client")
        color: Colours.palette.m3tertiary

        font: Tokens.font.body.large
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.leftMargin: Tokens.padding.extraLargeIncreased
        Layout.rightMargin: Tokens.padding.extraLargeIncreased
        Layout.topMargin: Tokens.spacing.medium
        Layout.bottomMargin: Tokens.spacing.largeIncreased

        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "location_on"
        text: qsTr("ID: %1").arg(root.client?.id ?? "unknown")
        color: Colours.palette.m3primary
    }

    Detail {
        icon: "workspaces"
        text: {
            const wsId = root.client?.workspace_id;
            if (wsId !== undefined && wsId !== null) {
                const name = Niri.getWorkspaceNameById(wsId);
                return name ? qsTr("Workspace: %1 (%2)").arg(name).arg(wsId) : qsTr("Workspace ID: %1").arg(wsId);
            }
            return qsTr("Workspace: unknown");
        }
        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "desktop_windows"
        text: {
            const wsId = root.client?.workspace_id;
            if (wsId !== undefined && wsId !== null) {
                const ws = Niri.allWorkspaces.find(w => w.id === wsId);
                if (ws) {
                    return qsTr("Monitor: %1").arg(ws.output);
                }
            }
            return qsTr("Monitor: unknown");
        }
    }

    Detail {
        icon: "account_tree"
        text: qsTr("Process ID: %1").arg(root.client?.pid ?? -1)
        color: Colours.palette.m3primary
    }

    Detail {
        icon: "picture_in_picture_center"
        text: qsTr("Floating: %1").arg(root.client?.is_floating ? qsTr("yes") : qsTr("no"))
        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "resize"
        text: {
            const size = root.client?.layout?.window_size;
            if (size && size.length >= 2) {
                return qsTr("Size: %1 x %2").arg(size[0]).arg(size[1]);
            }
            return qsTr("Size: unknown");
        }
        color: Colours.palette.m3tertiary
    }

    Detail {
        icon: "location_searching"
        text: {
            const pos = root.client?.layout?.pos_in_scrolling_layout;
            if (pos && pos.length >= 2) {
                return qsTr("Position: col %1, tile %2").arg(pos[0]).arg(pos[1]);
            }
            return qsTr("Position: unknown");
        }
    }

    Item {
        Layout.fillHeight: true
    }

    component Detail: RowLayout {
        id: detail

        required property string icon
        required property string text
        property alias color: icon.color

        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true

        spacing: Tokens.spacing.medium

        MaterialIcon {
            id: icon

            Layout.alignment: Qt.AlignVCenter
            text: detail.icon
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: detail.text
            elide: Text.ElideRight
            font: Tokens.font.body.medium
        }
    }

    component Label: StyledText {
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        animate: true
    }
}

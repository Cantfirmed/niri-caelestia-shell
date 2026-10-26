import "dev"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    property ScreenState screenState

    /// A little wider than the performance hero cards (400) so the server /
    /// container detail rows are not squeezed against their action buttons.
    readonly property real cardWidth: 460

    // Poll while the dashboard is open (matches the Performance tab behaviour)
    readonly property bool dashboardOpen: (screenState?.dashboard) ?? false

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    onDashboardOpenChanged: dashboardOpen ? Dev.attach() : Dev.detach()

    Component.onCompleted: {
        if (dashboardOpen)
            Dev.attach();
    }

    Component.onDestruction: Dev.detach()

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.top: parent.top
        spacing: Tokens.spacing.large

        ServersCard {
            id: serversCard

            cardWidth: root.cardWidth
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
        }

        DockerCard {
            id: dockerCard

            cardWidth: root.cardWidth
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
        }
    }
}

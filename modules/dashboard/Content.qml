pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import qs.services as Services
Item {
    id: root

    required property ScreenState screenState
    required property FileDialog facePicker

    readonly property var dashboardTabs: {
        const allTabs = [
            {
                component: dashComponent,
                iconName: "dashboard",
                text: Tr.tr("Dashboard"),
                enabled: Config.dashboard.showDashboard
            },
            {
                component: mediaComponent,
                iconName: "queue_music",
                text: Tr.tr("Media"),
                enabled: Config.dashboard.showMedia
            },
            {
                component: performanceComponent,
                iconName: "speed",
                text: Tr.tr("Performance"),
                enabled: Config.dashboard.showPerformance
            },
            {
                component: weatherComponent,
                iconName: "cloud",
                text: Tr.tr("Weather"),
                enabled: Config.dashboard.showWeather
            },
            {
                component: devComponent,
                iconName: "code",
                text: Tr.tr("Dev"),
                enabled: Config.dashboard.showDeveloper
            }
        ];
        return allTabs.filter(tab => tab.enabled);
    }

    readonly property real nonAnimWidth: view.implicitWidth + viewWrapper.anchors.margins * 2
    readonly property real nonAnimHeight: tabs.implicitHeight + tabs.anchors.topMargin + view.implicitHeight + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    property int initialDashboardTab: screenState.dashboardTab
    property real lastTabWidth: Tokens.sizes.dashboard.mediaTabWidth
    property real lastTabHeight: Tokens.sizes.dashboard.mediaTabHeight + Tokens.padding.extraLarge

    Component.onCompleted: root.initialDashboardTab = root.screenState.dashboardTab;


    Tabs {
        id: tabs

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: CUtils.clamp(anchors.margins - Config.border.thickness, 0, anchors.margins)
        anchors.margins: Tokens.padding.large

        nonAnimWidth: root.nonAnimWidth - anchors.margins * 2
        screenState: root.screenState
        tabs: root.dashboardTabs
        onTabHovered: index => {
            if (!root.screenState.dashboard)
                return;

            const loader = repeater.itemAt(index);
            if (loader)
                loader.preloadRequested = true;
        }
    }

    ClippingRectangle {
        id: viewWrapper

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large

        radius: Tokens.rounding.large
        color: "transparent"

        Flickable {
            id: view

            readonly property int currentIndex: root.screenState.dashboardTab
            readonly property Item currentItem: {
                repeater.count; // Trigger update on count change
                return repeater.itemAt(currentIndex);
            }

            anchors.fill: parent

            flickableDirection: Flickable.HorizontalFlick

            implicitWidth: currentItem?.status === Loader.Ready ? currentItem.implicitWidth : root.lastTabWidth
            implicitHeight: currentItem?.status === Loader.Ready ? currentItem.implicitHeight : root.lastTabHeight

            contentX: currentItem?.x ?? 0
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight

            onCurrentIndexChanged: {
                if (currentItem?.status === Loader.Ready) {
                    root.lastTabWidth = currentItem.implicitWidth;
                    root.lastTabHeight = currentItem.implicitHeight;
                }
            }

            onContentXChanged: {
                if (!moving || !currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
            }

            onDragEnded: {
                if (!currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
                else
                    contentX = Qt.binding(() => currentItem?.x ?? 0);
            }

            RowLayout {
                id: row

                Repeater {
                    id: repeater

                    model: ScriptModel {
                        values: root.dashboardTabs
                    }

                    delegate: Loader {
                        id: paneLoader

                        required property int index
                        required property var modelData

                        property bool loaded: false
                        property bool preloadRequested: false

                        Layout.alignment: Qt.AlignTop

                        sourceComponent: modelData.component

                        active: loaded || (index === view.currentIndex) || preloadRequested
                        asynchronous: index !== root.initialDashboardTab

                        onStatusChanged: {
                            if (status === Loader.Ready) {
                                loaded = true;
                                if (index === view.currentIndex) {
                                    root.lastTabWidth = implicitWidth;
                                    root.lastTabHeight = implicitHeight;
                                }
                            }
                        }
                    }
                }
            }


            Component {
                id: dashComponent

                Dash {
                    screenState: root.screenState
                    facePicker: root.facePicker
                }
            }

            Component {
                id: mediaComponent

                Media {
                    screenState: root.screenState
                }
            }

            Component {
                id: performanceComponent

                Performance {
                    screenState: root.screenState
                }
            }

            Component {
                id: weatherComponent

                WeatherTab {
                    screenState: root.screenState
                }
            }

            Component {
                id: devComponent

                Dev {
                    screenState: root.screenState
                }
            }

            Behavior on contentX {
                Anim {}
            }
        }
        Item {
            z: 1

            anchors.fill: parent
            enabled: false
            visible: view.currentItem?.status === Loader.Loading

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: Services.Colours.palette.m3surfaceContainer
            }

            Row {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                Repeater {
                    model: 3

                    Item {
                        required property int index

                        width: (parent.width - parent.spacing * 2) / 3
                        height: parent.height * (index === 1 ? 0.9 : 0.68)
                        anchors.verticalCenter: parent.verticalCenter

                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.large
                            color: Services.Colours.palette.m3surfaceContainerHighest
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.large
                            spacing: Tokens.spacing.medium

                            Repeater {
                                model: 5

                                StyledRect {
                                    required property int index

                                    width: parent.width * (index === 0 ? 0.72 : 0.38 + (index % 3) * 0.12)
                                    height: index === 0 ? Tokens.padding.medium : Tokens.padding.small
                                    radius: Tokens.rounding.full
                                    color: Services.Colours.palette.m3surfaceContainerLow
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }
}

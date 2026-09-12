pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import M3Shapes
import qs.services

Item {
    id: root



    required property var visibilities

    readonly property DashboardState dashState: DashboardState {
        reloadableId: "calendarPopupState"
    }

    readonly property int currMonth: dashState.currentDate.getMonth()
    readonly property int currYear: dashState.currentDate.getFullYear()

    readonly property bool shouldBeActive: visibilities.calendar
    property real offsetScale: shouldBeActive ? 0 : 1
    clip: true
    visible: offsetScale < 1
    anchors.leftMargin: (-implicitWidth - 5) * offsetScale
    implicitWidth: content.implicitWidth || 340
    implicitHeight: content.implicitHeight || 360
    width: implicitWidth
    height: implicitHeight

    opacity: 1 - offsetScale


    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left

        active: root.shouldBeActive || root.visible

        sourceComponent: StyledRect {
            id: bg

            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.extraLarge

            implicitWidth: 340
            implicitHeight: 360
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        icon: "chevron_left"
                        type: IconButton.Text
                        font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                        padding: Tokens.padding.small
                        onClicked: root.dashState.currentDate = new Date(root.currYear, root.currMonth - 1, 1)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        implicitWidth: monthYearDisplay.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: monthYearDisplay.implicitHeight + Tokens.padding.extraSmall * 2

                        StateLayer {
                            color: Colours.palette.m3primary
                            radius: pressed ? Tokens.rounding.small : Tokens.rounding.large
                            disabled: {
                                const now = new Date();
                                return root.currMonth === now.getMonth() && root.currYear === now.getFullYear();
                            }
                            onClicked: root.dashState.currentDate = new Date()

                            Behavior on radius {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }
                        }

                        StyledText {
                            id: monthYearDisplay

                            anchors.centerIn: parent
                            text: grid.title
                            color: Colours.palette.m3primary
                            font: Tokens.font.title.builders.small.capitalisation(Font.Capitalize).build()
                        }
                    }

                    IconButton {
                        icon: "chevron_right"
                        type: IconButton.Text
                        font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                        padding: Tokens.padding.small
                        onClicked: root.dashState.currentDate = new Date(root.currYear, root.currMonth + 1, 1)
                    }
                }

                DayOfWeekRow {
                    id: daysRow

                    Layout.fillWidth: true
                    locale: grid.locale

                    delegate: StyledText {
                        required property var model

                        horizontalAlignment: Text.AlignHCenter
                        text: model.shortName
                        font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                        color: (model.day === 0 || model.day === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: grid.implicitHeight

                    MonthGrid {
                        id: grid

                        month: root.currMonth
                        year: root.currYear

                        anchors.fill: parent

                        spacing: 3
                        locale: Qt.locale()

                        delegate: Item {
                            id: dayItem

                            required property var model

                            implicitWidth: implicitHeight
                            implicitHeight: text.implicitHeight + Tokens.padding.small

                            StyledText {
                                id: text

                                anchors.centerIn: parent

                                horizontalAlignment: Text.AlignHCenter
                                text: grid.locale.toString(dayItem.model.day)
                                color: {
                                    const dayOfWeek = dayItem.model.date.getDay();
                                    if (dayOfWeek === 0 || dayOfWeek === 6)
                                        return Colours.palette.m3tertiary;

                                    return Colours.palette.m3onSurfaceVariant;
                                }
                                opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                                font: Tokens.font.body.small
                            }
                        }
                    }

                    MaterialShape {
                        id: todayIndicator

                        readonly property Item todayItem: grid.contentItem.children.find(c => c.model.today) ?? null
                        property Item today

                        onTodayItemChanged: {
                            if (todayItem)
                                today = todayItem;
                        }

                        x: today ? today.x + (today.width - implicitWidth) / 2 : 0
                        y: today ? today.y - Tokens.padding.extraSmall - 1 : 0

                        implicitSize: today ? Math.max(today.implicitWidth, today.implicitHeight) + Tokens.padding.extraSmall * 2 : 0
                        shape: MaterialShape.Sunny

                        clip: true
                        color: Colours.palette.m3primary

                        opacity: todayItem ? 1 : 0
                        scale: todayItem ? 1 : 0.7

                        Colouriser {
                            x: -todayIndicator.x
                            y: -todayIndicator.y

                            implicitWidth: grid.width
                            implicitHeight: grid.height

                            source: grid
                            sourceColor: Colours.palette.m3onSurface
                            colorizationColor: Colours.palette.m3onPrimary
                        }

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        Behavior on scale {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }

                        Behavior on x {
                            Anim {}
                        }

                        Behavior on y {
                            Anim {}
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

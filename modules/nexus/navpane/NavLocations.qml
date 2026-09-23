pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.nexus

VerticalFadeFlickable {
    id: root

    required property NexusState nState

    readonly property string query: (root.nState.searchQuery ?? "").trim().toLowerCase()
    readonly property bool isSearching: query.length > 0

    readonly property var allPagesWithIndex: {
        const pages = PageRegistry.pages;
        const res = [];
        for (let i = 0; i < pages.length; i++) {
            res.push({
                originalIndex: i,
                label: pages[i].label,
                icon: pages[i].icon,
                description: pages[i].description,
                category: pages[i].category,
                noFill: pages[i].noFill ?? false,
                keywords: pages[i].keywords ?? ""
            });
        }
        return res;
    }

    readonly property var displayedPages: {
        if (!isSearching)
            return allPagesWithIndex;
        return allPagesWithIndex.filter(p => {
            const label = (p.label ?? "").toLowerCase();
            const desc = (p.description ?? "").toLowerCase();
            const cat = (p.category ?? "").toLowerCase();
            const kw = (p.keywords ?? "").toLowerCase();
            return label.includes(query) || desc.includes(query) || cat.includes(query) || kw.includes(query);
        });
    }

    readonly property int firstIndex: displayedPages.length > 0 ? displayedPages[0].originalIndex : -1

    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.large
    contentHeight: content.implicitHeight

    TapHandler {
        onTapped: root.focus = true
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall

        Repeater {
            id: list

            model: root.displayedPages

            StyledRect {
                id: item

                required property var modelData
                required property int index

                readonly property bool isCurrentPage: modelData.originalIndex === root.nState.currentPageIdx
                readonly property bool isCategoryStart: !root.isSearching && (index === 0 || root.displayedPages[index - 1].category !== modelData.category)
                readonly property bool isCategoryEnd: !root.isSearching && (index === root.displayedPages.length - 1 || root.displayedPages[index + 1].category !== modelData.category)

                Layout.fillWidth: true
                Layout.topMargin: root.isSearching ? 0 : (index !== 0 && isCategoryStart ? Tokens.spacing.medium : 0)
                implicitHeight: {
                    const h = layout.implicitHeight + layout.anchors.margins * 2;
                    return h % 2 === 0 ? h : h + 1;
                }

                color: isCurrentPage ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : (root.isSearching || isCategoryStart) ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                topRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : (root.isSearching || isCategoryStart) ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : (root.isSearching || isCategoryEnd) ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                bottomRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : (root.isSearching || isCategoryEnd) ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                RadiusBehavior on topLeftRadius {}
                RadiusBehavior on topRightRadius {}
                RadiusBehavior on bottomLeftRadius {}
                RadiusBehavior on bottomRightRadius {}

                StateLayer {
                    id: stateLayer

                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    topRightRadius: parent.topRightRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    bottomRightRadius: parent.bottomRightRadius

                    onClicked: root.nState.currentPageIdx = item.modelData.originalIndex
                }

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        Layout.fillHeight: true
                        Layout.topMargin: -1
                        Layout.bottomMargin: -1
                        implicitWidth: height

                        radius: Tokens.rounding.full
                        color: item.isCurrentPage ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1

                            text: item.modelData.icon
                            color: item.isCurrentPage ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                            grade: 25
                            fill: item.modelData.noFill ? 0 : 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData.label
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData.description
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large
            visible: root.isSearching && root.displayedPages.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("No settings found for \"%1\"").arg(root.nState.searchQuery)
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}

pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.utils
import Caelestia.Config
import QtQuick
import Quickshell.Widgets
import "context"

Item {
    id: iconItem

    required property Item workspace
    required property var windowData
    required property var groupWindowData
    required property int wsWindowCount
    required property int windowCount
    required property bool isFocused
    required property bool isWsFocused
    required property int curWindowIndex

    property bool useImageIcon: GlobalConfig.bar.workspaces.windowIconImage ?? false
    property bool groupIconsByApp: GlobalConfig.bar.workspaces.groupIconsByApp ?? false
    readonly property int windowIconGap: Math.round((GlobalConfig.bar.workspaces.windowIconGap ?? 5) * Tokens.uiScale)
    readonly property int cellWidth: Math.max(1, Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2)
    readonly property int scaledContextWidth: Math.round((GlobalConfig.bar.workspaces.windowContextWidth ?? 250) * Tokens.uiScale)

    property int currentGroupIndex: 0

    property bool popupActive: (Niri.wsContextAnchor === iconItem) || (Niri.wsContextAnchor === workspace) || (Niri.wsContextType === "workspaces")

    // --- Drag Properties ---
    property bool dragActive: false
    property point startPos
    property real dragThreshold: 8
    property int dropTargetIndex: -1

    signal requestPopup(var groupWindowData, var iconItem)
    signal dragStart(var iconItem)
    signal dragUpdate(var iconItem, real mouseY, real mouseX)
    signal dragEnd(var iconItem)

    anchors.left: parent.left

    implicitWidth: iconLoader.implicitWidth + (popupActive ? scaledContextWidth : 0)
    implicitHeight: iconLoader.implicitHeight
    width: implicitWidth
    height: implicitHeight

    z: popupActive ? 90 : 0

    Behavior on implicitWidth {
        Anim {
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    SafeLoader {
        id: contextLoader
        anchors.left: parent.left
        anchors.leftMargin: iconLoader.implicitWidth + Tokens.padding.extraSmall
        anchors.verticalCenter: parent.verticalCenter
        activeState: (Niri.wsContextType !== "none" && (GlobalConfig.bar.workspaces.windowRighClickContext ?? true))
        sourceComponent: WindowIconContext {
            iconObj: iconItem
        }
    }


    Loader {
        id: iconLoader

        // anchors.centerIn: parent
        anchors.left: parent.left
        width: implicitWidth
        height: implicitHeight

        // anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: iconItem.useImageIcon ? imageIconComp : materialIconComp
        property var windowData: iconItem.windowData
        property var windowCount: iconItem.windowCount
        // anchors.margins: Appearance.padding.xs
    }

    Component {
        id: imageIconComp
        StyledRect {
            width: implicitWidth
            height: implicitHeight

            implicitHeight: iconItem.cellWidth + iconItem.windowIconGap
            implicitWidth: iconItem.cellWidth
            color: "transparent"
            radius: Tokens.rounding.small / 2

            IconImage {
                anchors.centerIn: parent
                property var windowData: iconItem.windowData
                property int windowCount: iconItem.windowCount
                width: Math.max(1, Math.round(iconItem.cellWidth * ((iconItem.isFocused && iconItem.isWsFocused) ? 0.85 : 0.72)))
                height: width
                source: Icons.getAppIcon(windowData?.app_id ?? "", "image-missing")
                Behavior on width {
                    Anim {
                        easing.bezierCurve: Appearance.anim.curves.emphasized
                    }
                }

                WindowGroupBadge {}
            }
        }
    }

    Component {
        id: materialIconComp
        StyledRect {
            width: implicitWidth
            height: implicitHeight

            implicitHeight: iconItem.cellWidth + iconItem.windowIconGap
            implicitWidth: iconItem.cellWidth

            MaterialIcon {
                anchors.centerIn: parent
                property var windowData: iconItem.windowData
                property int windowCount: iconItem.windowCount
                size: Math.max(1, Math.round(iconItem.cellWidth * ((iconItem.isFocused && iconItem.isWsFocused) ? 0.85 : 0.72) / 1.33))
                grade: 0
                text: Icons.getAppCategoryIcon(windowData?.app_id ?? "", "help_center")
                color: (iconItem.isWsFocused ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant)
                Behavior on size {
                    Anim {
                        easing.bezierCurve: Appearance.anim.curves.emphasized
                    }
                }

                WindowGroupBadge {}
            }
        }
    }

    property alias dgprw: dragPreview

    StyledRect {
        id: dragPreview
        visible: false
        z: 999
        width: iconLoader.width + Tokens.padding.extraSmall
        height: iconLoader.height + Tokens.padding.extraSmall

        color: iconItem.isWsFocused ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainer
        radius: Tokens.rounding.small / 2

        MouseArea {
            anchors.fill: parent
            enabled: true
            cursorShape: Qt.ClosedHandCursor
        }

        // We reuse the same loader as the original icon for preview
        Loader {
            id: dragLoader
            anchors.centerIn: parent
            sourceComponent: iconItem.useImageIcon ? imageIconComp : materialIconComp
            asynchronous: true
        }
    }

    Interaction {
        id: interactionArea
    }

    // --------------------------
    // Interaction / Drag Handling
    // --------------------------
    component Interaction: StateLayer {
        id: mouseArea
        anchors.fill: iconItem
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: (iconItem.dragActive ? Qt.ClosedHandCursor : (Qt.PointingHandCursor))
        pressAndHoldInterval: Tokens.anim.durations.small

        radius: Tokens.rounding.small

        hoverEnabled: true

        onPressAndHold: mouse => {
            iconItem.startPos = Qt.point(mouse.x, mouse.y);
            iconItem.dragActive = true;
        }

        onPositionChanged: mouse => {
            if (pressed && iconItem.dragActive) {
                let distance = Math.sqrt(Math.pow(mouse.x - iconItem.startPos.x, 2) + Math.pow(mouse.y - iconItem.startPos.y, 2));
                if (distance > iconItem.dragThreshold) {
                    iconItem.dragActive = true;
                    iconItem.dragStart(iconItem);
                }
            }
            if (iconItem.dragActive) {
                iconItem.dragUpdate(iconItem, mouse.y, mouse.x);
            }
        }

        onReleased: mouse => {
            if (iconItem.dragActive) {
                iconItem.dragEnd(iconItem);
                iconItem.dragActive = false;
            }
        }

        onCanceled: {
            if (iconItem.dragActive) {
                iconItem.dragEnd(iconItem);
                iconItem.dragActive = false;
            }
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && !iconItem.dragActive) {
                // cycle through group windows or focus single window
                if (Number(Niri.focusedWindowId) !== Number(iconItem.windowData.id)) {
                    Niri.focusWindow(iconItem.windowData.id);
                } else if (iconItem.groupIconsByApp && iconItem.windowCount > 1) {
                    let idx = iconItem.groupWindowData.findIndex(w => w.id === iconItem.windowData.id);
                    if (idx === -1)
                        idx = 0;
                    let nextIdx = (idx + 1) % iconItem.groupWindowData.length;
                    iconItem.currentGroupIndex = nextIdx;
                    iconItem.windowData = iconItem.groupWindowData[nextIdx];
                    Niri.focusWindow(iconItem.windowData.id);
                } else if (iconItem.windowData?.id) {
                    Niri.focusWindow(iconItem.windowData.id);
                }
            } else if (mouse.button === Qt.RightButton) {
                if (!(Niri.wsContextAnchor === iconItem)) {
                    Niri.wsContextAnchor = iconItem;
                    Niri.wsContextType = "item";
                } else {
                    Niri.wsContextAnchor = iconItem.workspace;
                    Niri.wsContextType = "workspace";
                }
                iconItem.requestPopup(iconItem.groupWindowData, iconItem);
            }
        }
    }

    // --------------------------
    // WindowGroupBadge component
    // --------------------------
    component WindowGroupBadge: Loader {
        id: badgeLoader
        active: iconItem.groupIconsByApp

        function calculateMargins() {
            if (iconItem.popupActive && Niri.wsContextType === "item")
                return {
                    right: -Tokens.padding.extraLarge,
                    bottom: (iconLoader.implicitHeight - badgeLoader.height) / 2 - (!iconItem.isFocused ? Tokens.padding.extraSmall / 2 : windowIconGap),
                    size: Tokens.padding.extraLarge
                };
            else if (iconItem.isFocused)
                return {
                    right: 0,
                    bottom: 0,
                    size: Tokens.padding.large
                };
            return {
                right: -Tokens.padding.extraSmall / 2,
                bottom: -Tokens.padding.extraSmall / 2,
                size: Tokens.padding.large
            };
        }

        anchors {
            bottom: parent.bottom
            right: parent.right
            rightMargin: calculateMargins().right
            bottomMargin: calculateMargins().bottom

            Behavior on rightMargin {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
            Behavior on bottomMargin {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
        }

        sourceComponent: Rectangle {
            visible: (iconItem.windowCount > 1)
            color: iconItem.isWsFocused ? (Colours.palette.m3tertiary) : Colours.palette.m3tertiaryContainer
            anchors.centerIn: parent
            radius: Tokens.rounding.small
            width: badgeLoader.calculateMargins().size
            height: badgeLoader.calculateMargins().size

            StyledText {
                animate: true
                anchors.centerIn: parent
                text: iconItem.windowCount
                font.family: Tokens.font.mono.medium.family
                color: iconItem.isWsFocused ? Colours.palette.m3onTertiary : Colours.palette.m3onTertiaryContainer
                font.pointSize: Math.max(1, Math.round(badgeLoader.calculateMargins().size * 0.6))
            }
        }
    }
}

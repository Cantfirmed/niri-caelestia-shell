pragma ComponentBehavior: Bound

import qs.services
import Caelestia.Config
import QtQuick
import qs.components

Item {
    id: root

    property var groupedWindowsArray: [] // Holds full group objects

    ListModel {
        id: groupedWindowsModel
    }

    // Public API
    property int spacing: 0
    property var model: groupedWindowsModel
    property real dragThreshold: 8

    // Properties passed through to WindowIcon
    required property Item workspace
    required property int focusedWindowId
    required property int activeWsId
    required property int ws
    required property int idx
    required property int groupOffset
    required property string outputName
    required property Item windowPopoutSignal

    property bool isWsFocused: root.activeWsId === root.ws

    property bool groupIconsByApp: GlobalConfig.bar.workspaces.groupIconsByApp ?? false
    property bool groupingRespectsLayout: GlobalConfig.bar.workspaces.groupingRespectsLayout ?? true
    property int windowIconGap: GlobalConfig.bar.workspaces.windowIconGap ?? 5

    property var wsWindows: {
        const wins = Niri.windows;
        const wsNum = root.ws;
        if (!root.outputName || wsNum <= 0)
            return [];
        const outputWsList = Niri.getWorkspacesForOutput(root.outputName);
        const niriWorkspace = outputWsList && outputWsList.find(w => w && w.idx === wsNum);
        if (!niriWorkspace)
            return [];
        return Niri.getWindowsByWorkspaceId(niriWorkspace.id);
    }

    function updateGroupedWindowsModel() {
        const wsWindows = root.wsWindows || [];
        var newGroups;

        if (root.groupIconsByApp && root.groupingRespectsLayout) {
            newGroups = Niri.groupWindowsByLayoutAndId(wsWindows);
        } else if (root.groupIconsByApp) {
            newGroups = Niri.groupWindowsByApp(wsWindows);
        } else {
            newGroups = wsWindows.map(w => ({
                        app_id: w.app_id,
                        id: w.id,
                        title: w.title,
                        windows: [w],
                        count: 1,
                        main: w
                    }));
        }

        root.groupedWindowsArray = newGroups;
    }

    onWsWindowsChanged: updateGroupedWindowsModel()
    Component.onCompleted: updateGroupedWindowsModel()

    // Drag state
    property Item draggedItem: null

    // Signals
    signal itemReordered(var item, int fromIndex, int toIndex)

    //Here for now, will be moved to Workspace.qml later for other features such as drag and drop to workspaces etc.
    onItemReordered: (item, fromIndex, toIndex) => {
        // 1. Flatten all windows

        if (fromIndex === toIndex - 1 || fromIndex === toIndex)
            return;

        let flatWindows = [];
        for (let group of root.groupedWindowsArray) {
            flatWindows = flatWindows.concat(group.windows);
        }

        // 2. Get dragged windows
        let draggedWindows = Array.isArray(item.groupWindowData) ? item.groupWindowData : [item.groupWindowData];

        // 3. Remove dragged windows from flat list
        flatWindows = flatWindows.filter(w => !draggedWindows.some(dw => dw.id === w.id));

        // 4. Calculate flat insertion index (add group sizes up to toIndex)
        let flatIndex = 0;
        for (let i = 0; i < toIndex; ++i) {
            let group = root.groupedWindowsArray[i];
            if (group && group.windows) {
                flatIndex += group.windows.length;
            }
        }

        // 5. Adjust insertion index if moving down (after removal, indices shift)
        if ((fromIndex < toIndex)) {
            flatIndex -= 1;
        }

        // 6. Insert dragged windows at new position
        flatWindows.splice(flatIndex, 0, ...draggedWindows);

        // 7. Compute new indices (1-based for backend)
        let indices = draggedWindows.map(w => flatWindows.findIndex(x => x.id === w.id));

        // 8. Call backend to update order
        Niri.moveGroupColumnsSequential(Niri.focusedWindowId, draggedWindows.map(w => w.id), flatIndex + 1);
    }

    // height: column.height
    // width: column.width
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // Drop indicator
    Rectangle {
        id: dropIndicator
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Appearance.padding.xs
        height: Appearance.padding.xs
        color: root.isWsFocused ? Colours.palette.m3primaryContainer : Colours.palette.m3primaryContainer
        radius: Appearance.rounding.small
        visible: false
        z: 200

        Behavior on y {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    Column {
        id: column

        add: Transition {
            NumberAnimation {
                properties: "scale"
                from: 0
                to: 1
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
        }

        move: Transition {
            NumberAnimation {
                properties: "scale"
                to: 1
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
            NumberAnimation {
                properties: "x,y"
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        populate: Transition {
            NumberAnimation {
                properties: "scale"
                from: 0
                to: 1
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
        }

        // anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            id: repeater
            model: root.groupedWindowsArray
            anchors.left: parent.left

            delegate: WindowIcon {
                id: icon
                workspace: root.workspace

                required property var modelData
                required property int index

                windowData: root.groupIconsByApp ? modelData.main : modelData
                groupWindowData: root.groupIconsByApp ? (modelData.windows || []) : [modelData]
                windowCount: root.groupIconsByApp ? modelData.count : 1
                isFocused: root.groupIconsByApp ? (modelData?.windows?.some(w => w?.id === root.focusedWindowId) ?? false) : root.focusedWindowId === modelData?.id
                isWsFocused: root.isWsFocused
                curWindowIndex: index
                wsWindowCount: root.groupedWindowsArray ? root.groupedWindowsArray.length : 0

                onDragStart: iconItem => {
                    if (root.draggedItem)
                        return;

                    // Position the preview under the cursor
                    icon.dgprw.visible = true;
                    icon.dgprw.x = iconItem.mapToItem(iconItem, iconItem.width / 2, 0).x;
                    icon.dgprw.y = iconItem.mapToItem(iconItem, 0, iconItem.height / 2).y;

                    root.draggedItem = icon;
                    icon.z = 100;
                    icon.opacity = 0.7;
                    dropIndicator.visible = true;
                    root.updateDropIndicator(icon.y);
                }

                onDragUpdate: (iconItem, mouseY, mouseX) => {
                    if (root.draggedItem !== icon)
                        return;

                    // Move preview with mouse
                    let globalPos = iconItem.mapToItem(iconItem, mouseX, mouseY);
                    icon.dgprw.x = globalPos.x - icon.dgprw.height / 2;
                    icon.dgprw.y = globalPos.y - icon.dgprw.height / 2;
                    root.updateDropIndicator(iconItem.mapToItem(iconItem, 0, mouseY).y);
                }

                onDragEnd: iconItem => {
                    if (root.draggedItem !== icon)
                        return;
                    icon.dgprw.visible = false;

                    icon.opacity = 1.0;
                    icon.z = 0;
                    dropIndicator.visible = false;

                    if (icon.dropTargetIndex !== undefined && icon.dropTargetIndex !== icon.index) {
                        root.itemReordered(icon, icon.index, icon.dropTargetIndex);
                    }

                    root.draggedItem = null;
                    icon.dropTargetIndex = -1;
                }

                onRequestPopup: (groupWindowData, iconItem) => {
                    root.windowPopoutSignal.requestWindowPopout();
                }
            }
        }
    }

    function updateDropIndicator(globalY) {
        let targetIndex = 0;
        let targetY = 0;

        for (let i = 0; i < repeater.count; i++) {
            let child = repeater.itemAt(i);

            if (!child || child === root.draggedItem)
                continue;

            let childY = child.y + child.height / 2;
            if (globalY < childY) {
                targetIndex = i;
                targetY = child.y - root.windowIconGap;
                break;
            }
            targetIndex = i + 1;
            targetY = child.y + child.height + root.spacing;
        }

        if (root.draggedItem) {
            root.draggedItem.dropTargetIndex = targetIndex;
        }
        dropIndicator.y = targetY;
    }
}

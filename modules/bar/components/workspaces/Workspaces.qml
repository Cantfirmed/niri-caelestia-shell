pragma ComponentBehavior: Bound

import qs.services
import Caelestia.Config
import qs.components
import QtQuick
import QtQuick.Layouts

import "context"

StyledRect {
    id: root

    required property string outputName

    // Per-output workspace data from niri
    property var outputWorkspaces: []

    function updateWorkspaces(): void {
        const list = Niri.getWorkspacesForOutput(outputName);
        outputWorkspaces = (list && (Array.isArray(list) || list.length !== undefined)) ? Array.from(list) : [];
        console.log("Workspaces.qml [" + outputName + "] updateWorkspaces: count=" + outputWorkspaces.length + " activeSlot=" + activeSlotIndex + " activeWsId=" + activeWsId + " ws=" + JSON.stringify(outputWorkspaces));
    }


    Component.onCompleted: updateWorkspaces()
    onOutputNameChanged: updateWorkspaces()

    // The active workspace on THIS output (is_active, not global is_focused)
    readonly property var outputActiveWs: {
        const wsList = outputWorkspaces;
        if (!wsList || !Array.isArray(wsList)) return null;
        for (let i = 0; i < wsList.length; i++) {
            if (wsList[i] && wsList[i].is_active) return wsList[i];
        }
        return wsList.length > 0 ? wsList[0] : null;
    }
    readonly property int activeWsId: outputActiveWs ? (outputActiveWs.idx ?? 1) : 1

    // Find the slot index of the active workspace on this output
    readonly property int activeSlotIndex: {
        const wsList = outputWorkspaces;
        if (!wsList || !Array.isArray(wsList)) return 0;
        for (let i = 0; i < wsList.length; i++) {
            if (wsList[i] && wsList[i].is_active) return i;
        }
        return 0;
    }

    // Array of booleans representing slot occupancy for background pills
    readonly property var occupiedSlots: {
        let arr = [];
        const wsList = outputWorkspaces;
        const wins = Niri.windows ? Array.from(Niri.windows) : [];
        const shownCount = GlobalConfig.bar?.workspaces?.shown ?? 4;
        for (let i = 0; i < shownCount; i++) {
            let hasWindows = false;
            let isActive = Boolean(wsList && i < wsList.length && i === activeSlotIndex);
            if (wsList && i < wsList.length && wsList[i]) {
                const ws = wsList[i];
                if (wins && Array.isArray(wins)) {
                    for (let j = 0; j < wins.length; j++) {
                        if (wins[j] && wins[j].workspace_id === ws.id) {
                            hasWindows = true;
                            break;
                        }
                    }
                }
            }
            arr.push(hasWindows || isActive);
        }
        return arr;
    }

    // Per-output occupied map: workspace number (idx) -> whether it has windows
    readonly property var occupied: {
        let map = {};
        const wsList = outputWorkspaces;
        const wins = Niri.windows ? Array.from(Niri.windows) : [];
        if (!wsList || !Array.isArray(wsList)) return map;

        // Mark workspaces that exist on this output
        for (let i = 0; i < wsList.length; i++) {
            const ws = wsList[i];
            if (!ws) continue;
            const wsNum = ws.idx;
            let hasWindows = false;
            if (wins && Array.isArray(wins)) {
                for (let j = 0; j < wins.length; j++) {
                    if (wins[j] && wins[j].workspace_id === ws.id) {
                        hasWindows = true;
                        break;
                    }
                }
            }
            map[wsNum.toString()] = hasWindows;
        }
        return map;
    }

    // Map of workspace number -> global workspace ID for click handling
    readonly property var workspaceIdMap: {
        let m = {};
        const wsList = outputWorkspaces;
        if (wsList && Array.isArray(wsList)) {
            for (let i = 0; i < wsList.length; i++) {
                if (wsList[i] && wsList[i].idx !== undefined) {
                    m[(wsList[i].idx).toString()] = wsList[i].id;
                }
            }
        }
        return m;
    }

    // groupOffset stays 0 for per-output — workspaces on each output start at idx 0
    readonly property int groupOffset: 0



    readonly property int focusedWindowId: Niri.focusedWindow?.id ?? -1

    implicitHeight: layout.implicitHeight + Appearance.padding.xs * 2
    implicitWidth: Tokens.sizes.bar.innerWidth

    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.full

    signal requestWindowPopout

    property bool dying: false
    Component.onDestruction: dying = true

    Connections {
        target: Niri
        function onWsContextTypeChanged() {
            if (Niri.wsContextType === "workspaces") {
                Niri.wsContextAnchor = root;
            }
        }
        function onWorkspacesChanged() {
            root.updateWorkspaces();
        }
    }


    Loader {
        active: GlobalConfig.bar.workspaces.occupiedBg
        asynchronous: true

        anchors.fill: parent
        anchors.margins: Appearance.padding.xs

        sourceComponent: OccupiedBg {
            workspaces: workspaces
            occupiedSlots: root.occupiedSlots
        }
    }

    Loader {
        id: contextBgLoader
        // Right click on window context menu
        asynchronous: true

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.xs

        z: Niri.wsContextType === "workspaces" ? -10 : 0

        sourceComponent: ContextBg {
            groupOffset: root.groupOffset
            wsOffset: root.y
            anchorWs: Niri.wsContextAnchor
        }
    }

    Binding {
        target: contextBgLoader
        property: "active"
        value: (GlobalConfig.bar.workspaces.windowRighClickContext ?? true) && Niri.wsContextType !== "none"
        restoreMode: Binding.RestoreNone
        when: !root.dying
    }

    ColumnLayout {
        id: layout

        z: 0

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Appearance.padding.xs
        spacing: Math.floor(Appearance.spacing.sm / 2)

        Repeater {
            id: workspaces

            model: GlobalConfig.bar.workspaces.shown

            delegate: Workspace {
                id: wsItem
                virtualIdx: {
                    const wsList = root.outputWorkspaces;
                    const sIdx = wsItem.index;
                    if (wsList && sIdx < wsList.length && wsList[sIdx]) {
                        return wsList[sIdx].idx;
                    } else if (wsList && wsList.length > 0 && wsList[wsList.length - 1]) {
                        return wsList[wsList.length - 1].idx + (sIdx - wsList.length + 1);
                    } else {
                        return sIdx + 1;
                    }
                }
                activeWsId: root.activeWsId
                occupied: root.occupied
                groupOffset: root.groupOffset
                focusedWindowId: root.focusedWindowId
                windowPopoutSignal: root
                workspaceId: (root.outputWorkspaces && wsItem.index < root.outputWorkspaces.length && root.outputWorkspaces[wsItem.index]) ? root.outputWorkspaces[wsItem.index].id : -1
                outputName: root.outputName
            }
        }
    }

    Loader {
        z: 1
        anchors.left: parent.left
        anchors.right: parent.right
        active: GlobalConfig.bar.workspaces.activeIndicator
        asynchronous: true

        sourceComponent: ActiveIndicator {
            activeSlotIndex: root.activeSlotIndex
            activeWsId: root.activeWsId
            workspaces: workspaces
            mask: layout
            groupOffset: root.groupOffset
        }
    }

    Loader {
        id: pager
        active: Config.bar.workspaces.pagerActive ?? true

        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        z: -1

        sourceComponent: Pager {
            groupOffset: root.groupOffset
            outputName: root.outputName
        }
    }
}

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Internal
import Caelestia.Config
import qs.services
import qs.utils

Singleton {
    id: root

    // --- Core ---
    readonly property bool niriAvailable: NiriIpc.available

    // --- Workspaces ---
    signal workspacesChanged()
    readonly property var allWorkspaces: NiriIpc.workspaces


    readonly property int focusedWorkspaceIndex: NiriIpc.focusedWorkspaceIndex
    readonly property int focusedWorkspaceId: NiriIpc.focusedWorkspaceId
    readonly property var currentOutputWorkspaces: NiriIpc.currentOutputWorkspaces
    readonly property string focusedMonitorName: NiriIpc.focusedMonitorName
    readonly property var workspaceHasWindows: {
        // Establish dependency on workspaces changes so that this re-evaluates
        // when workspaces are added, removed, or re-indexed.
        const workspaces = root.allWorkspaces;
        let map = {};
        const wins = root.windows;
        for (let i = 0; i < wins.length; i++) {
            const win = wins[i];
            const wsIdx = root.getWorkspaceIdxById(win.workspace_id);
            if (wsIdx >= 0) {
                map[(wsIdx).toString()] = true;
            }
        }
        return map;
    }

    // UI context menu state
    property bool wsContextExpanded: false
    property var wsContextAnchor: null
    property string wsContextType: "none"
    
    property Timer wsAnchorClearTimer: Timer {
        interval: Appearance.anim.durations.normal
        repeat: false
        onTriggered: {
            if (root.wsContextAnchor === null) {
                root.wsContextType = "none";
            }
        }
    }

    // State machine for moveColumnToIndexAfterFocus
    property var _moveAfterFocusPendingCb: null
    property string _moveAfterFocusPendingId: ""

    // State machine for sequential group column moves
    property var _seqState: null

    onFocusedWindowIdChanged: {
        // Handle single window move after focus
        if (_moveAfterFocusPendingCb && Number(focusedWindowId) === Number(_moveAfterFocusPendingId)) {
            var cb = _moveAfterFocusPendingCb;
            _moveAfterFocusPendingCb = null;
            _moveAfterFocusPendingId = "";
            cb();
        }

        // Handle sequential group moves
        var s = _seqState;
        if (s && Number(focusedWindowId) === Number(s.curWindowId)) {
            if (s.i >= s.windowIds.length) {
                // Done sequential moves, restore initial focus
                _seqState = null;
                root.focusWindow(Number(s.initialWindowId));
            } else {
                // Execute next move in sequence
                var wid = s.windowIds[s.i];
                s.curWindowId = wid; // Update what we are waiting for next
                s.i++;
                root.moveColumnToIndexAfterFocus(wid, s.targetIndex);
            }
        }
    }

    onWsContextAnchorChanged: {
        wsAnchorClearTimer.stop();
        if (wsContextAnchor === null) {
            wsAnchorClearTimer.start();
        }
    }

    Connections {
        target: root.wsContextAnchor
        ignoreUnknownSignals: true
        function onDestroyed() {
            root.wsContextAnchor = null;
            Qt.callLater(() => {
                if (root.wsContextAnchor === null) {
                    root.wsContextType = "none";
                }
            });
        }
    }

    // --- Windows ---
    readonly property var windows: NiriIpc.windows
    readonly property int focusedWindowIndex: NiriIpc.focusedWindowIndex
    readonly property string focusedWindowId: NiriIpc.focusedWindowId
    readonly property string focusedWindowTitle: NiriIpc.focusedWindowTitle
    readonly property string focusedWindowClass: NiriIpc.focusedWindowClass
    readonly property var focusedWindow: NiriIpc.focusedWindow
    readonly property var lastFocusedWindow: NiriIpc.lastFocusedWindow
    readonly property string scrollDirection: NiriIpc.scrollDirection
    readonly property bool inOverview: NiriIpc.inOverview
    signal windowOpenedOrChanged(var windowData)



    // --- Outputs ---
    readonly property var outputs: NiriIpc.outputs
    
    // --- Keyboard ---
    readonly property var kbLayoutsArray: NiriIpc.kbLayoutsArray
    readonly property int kbLayoutIndex: NiriIpc.kbLayoutIndex
    readonly property string kbLayouts: NiriIpc.kbLayouts
    readonly property string defaultKbLayout: NiriIpc.defaultKbLayout
    readonly property string kbLayout: NiriIpc.kbLayout
    readonly property bool capsLock: NiriIpc.capsLock
    readonly property bool numLock: NiriIpc.numLock

    property bool _lockKeysInitialized: false
    Timer { interval: 1500; running: true; onTriggered: root._lockKeysInitialized = true }

    onCapsLockChanged: {
        if (!_lockKeysInitialized || !Config.utilities.toasts.capsLockChanged)
            return;
        if (capsLock)
            Toaster.toast(qsTr("Caps lock enabled"), qsTr("Caps lock is currently enabled"), "keyboard_capslock_badge");
        else
            Toaster.toast(qsTr("Caps lock disabled"), qsTr("Caps lock is currently disabled"), "keyboard_capslock");
    }

    onNumLockChanged: {
        if (!_lockKeysInitialized || !Config.utilities.toasts.numLockChanged)
            return;
        if (numLock)
            Toaster.toast(qsTr("Num lock enabled"), qsTr("Num lock is currently enabled"), "looks_one");
        else
            Toaster.toast(qsTr("Num lock disabled"), qsTr("Num lock is currently disabled"), "timer_1");
    }

    onKbLayoutChanged: {
        if (!_lockKeysInitialized || !Config.utilities.toasts.kbLayoutChanged)
            return;
        Toaster.toast(qsTr("Keyboard layout changed"), qsTr("Layout changed to: %1").arg(kbLayout), "keyboard");
    }

    // --- Initialization ---
    Connections {
        target: NiriIpc
        function onWindowOpenedOrChanged(windowData) {
            root.windowOpenedOrChanged(windowData);
        }
        function onWorkspacesChanged() {
            root.workspacesChanged();
        }
        function onFocusedWorkspaceChanged() {
            root.workspacesChanged();
        }
    }



    Component.onCompleted: console.log("NiriService: Using native C++ IPC (NiriIpc)")

    // --- Workspace Functions ---
    function getWorkspaceIdxById(workspaceId) {
        if (typeof NiriIpc.getWorkspaceIdxById === "function") {
            try {
                const idx = NiriIpc.getWorkspaceIdxById(workspaceId);
                if (idx !== undefined && idx >= 0) return idx;
            } catch (e) {}
        }
        if (!allWorkspaces || !Array.isArray(allWorkspaces)) return -1;
        const ws = allWorkspaces.find(w => w && w.id === workspaceId);
        return ws ? (ws.idx ?? -1) : -1;
    }

    function getWorkspacesForOutput(outputName) {
        if (!outputName) return [];
        if (typeof NiriIpc.getWorkspacesForOutput === "function") {
            try {
                const list = NiriIpc.getWorkspacesForOutput(outputName);
                if (list && list.length > 0) return Array.from(list);
            } catch (e) {}
        }
        if (!allWorkspaces || allWorkspaces.length === undefined) return [];
        const all = Array.from(allWorkspaces);
        return all.filter(ws => ws && (!ws.output || ws.output === outputName));
    }




    function getActiveWorkspaceIndexForOutput(outputName) {
        const wsList = getWorkspacesForOutput(outputName);
        for (let i = 0; i < wsList.length; i++) {
            if (wsList[i].is_focused) return i;
        }
        return wsList.length > 0 ? 0 : -1;
    }

    function getFocusedWorkspaceIdForOutput(outputName) {
        const wsList = getWorkspacesForOutput(outputName);
        for (let i = 0; i < wsList.length; i++) {
            if (wsList[i].is_active) return wsList[i].id;
        }
        return wsList.length > 0 ? wsList[0].id : -1;
    }

    function getActiveWorkspaceName() {
        if (allWorkspaces && focusedWorkspaceIndex >= 0 && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].name || "";
        }
        return "";
    }

    function getWorkspaceNameByIndex(idx) {
        if (allWorkspaces && idx >= 0 && idx < allWorkspaces.length) {
            return allWorkspaces[idx].name || "";
        }
        return "";
    }

    function getWorkspaceNameByOutputIndex(outputName, idx) {
        const wsList = getWorkspacesForOutput(outputName);
        if (idx >= 0 && idx < wsList.length) {
            return wsList[idx].name || "";
        }
        return "";
    }

    function getWorkspaceNameById(id) {
        if (allWorkspaces && id >= 0) {
            const ws = allWorkspaces.find(w => w.id === id);
            return ws?.name || "";
        }
        return "";
    }

    function getWorkspaceByIndex(index) {
        if (index >= 0 && index < allWorkspaces.length) {
            return allWorkspaces[index];
        }
        return null;
    }

    function getWorkspaceCount() {
        return allWorkspaces.length;
    }

    function getOccupiedWorkspaceCount() {
        return allWorkspaces.filter(w => w.active_window_id !== "").length;
    }

    function getCurrentOutputWorkspaceNumbers() {
        return currentOutputWorkspaces.map(w => w.idx + 1);
    }

    function getCurrentWorkspaceNumber() {
        if (focusedWorkspaceIndex >= 0 && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].idx;
        }
        return 1;
    }

    function switchToWorkspace(workspaceId) {
        if (!niriAvailable) return false;
        return NiriIpc.action("focus-workspace", [workspaceId.toString()]);
    }

    function switchToWorkspaceById(workspaceId) {
        // Switch using the global workspace ID so it targets the correct output
        if (!niriAvailable) return false;
        return NiriIpc.action("focus-workspace", ["--id", workspaceId.toString()]);
    }

    function switchToWorkspaceUpDown(direction) {
        if (!niriAvailable) return false;
        return NiriIpc.action("focus-workspace-" + direction, []);
    }

    function switchToWorkspaceByIndex(index) {
        if (!niriAvailable || index < 0 || index >= allWorkspaces.length) return false;
        return switchToWorkspace(allWorkspaces[index].idx);
    }

    function switchToWorkspaceByNumber(number, output) {
        if (!niriAvailable) return false;
        const targetOutput = output || focusedMonitorName;
        if (!targetOutput) {
            console.warn("NiriService: No output specified for workspace switching");
            return false;
        }
        const outputWorkspaces = allWorkspaces
            .filter(w => w.output === targetOutput)
            .sort((a, b) => a.idx - b.idx);
        if (number >= 1 && number <= outputWorkspaces.length) {
            return switchToWorkspace(outputWorkspaces[number - 1].idx);
        }
        console.warn("NiriService: No workspace", number, "found on output", targetOutput);
        return false;
    }

    function moveWindowToWorkspace(workspaceIdx) {
        if (!niriAvailable) return false;
        return NiriIpc.action("move-window-to-workspace", [workspaceIdx.toString()]);
    }

    // --- Window Functions ---
    function getActiveWorkspaceWindows() {
        if (!allWorkspaces || focusedWorkspaceIndex === undefined) return [];
        const currentWs = allWorkspaces[focusedWorkspaceIndex];
        if (!currentWs?.id) return [];
        return windows.filter(w => w.workspace_id === currentWs.id);
    }

    function getWindowsByWorkspaceId(wsid) {
        return windows.filter(w => w.workspace_id === wsid);
    }

    function getWindowsByWorkspaceIndex(index) {
        if (index < 0 || index >= allWorkspaces.length) return [];
        const wsId = allWorkspaces[index].id;
        return windows.filter(w => w.workspace_id === wsId);
    }

    function getWindowsInScreen(screenX, screenY, screenWidth, screenHeight, windowBorder, padding) {
        if (!focusedWindow?.layout?.pos_in_scrolling_layout) return [];
        
        const focusedCol = focusedWindow.layout.pos_in_scrolling_layout[0];
        const focusedRow = focusedWindow.layout.pos_in_scrolling_layout[1];
        
        return getActiveWorkspaceWindows().map(window => {
            if (!window.layout?.pos_in_scrolling_layout || !window.layout?.window_size) return null;
            
            const colOffset = window.layout.pos_in_scrolling_layout[0] - focusedCol;
            const rowOffset = window.layout.pos_in_scrolling_layout[1] - focusedRow;
            const focusedWidth = focusedWindow.layout.window_size[0];
            
            let focusedScreenX;
            if (focusedWidth < screenWidth - windowBorder) {
                focusedScreenX = scrollDirection === "left" ? 5 : screenWidth - focusedWidth;
            } else {
                focusedScreenX = 0;
            }
            
            const winX = focusedScreenX + (colOffset * window.layout.window_size[0]) - windowBorder;
            const winY = rowOffset * window.layout.window_size[1] + windowBorder;
            const winW = window.layout.window_size[0] - padding * 2;
            const winH = window.layout.window_size[1] - padding * 2;
            
            if (winX < screenWidth + windowBorder && winY < screenHeight && winX + winW > 0 && winY + winH > 0) {
                return { window: window, screenX: winX, screenY: winY, screenW: winW, screenH: winH };
            }
            return null;
        }).filter(item => item !== null);
    }

    function focusWindow(windowID) {
        if (!niriAvailable) return false;
        if (Number(windowID) === Number(focusedWindowId) && Config.bar.workspaces.doubleClickToCenter) {
            return centerWindow();
        }
        return NiriIpc.action("focus-window", ["--id", windowID.toString()]);
    }

    function closeWindow(windowId) {
        if (!niriAvailable) return false;
        const id = windowId ? windowId.toString() : focusedWindowId.toString();
        return NiriIpc.action("close-window", ["--id", id]);
    }

    function closeFocusedWindow() {
        if (!niriAvailable) return false;
        return NiriIpc.action("close-window", []);
    }

    function toggleWindowFloating(windowId) {
        if (!niriAvailable) return false;
        const id = windowId ? windowId.toString() : focusedWindowId.toString();
        return NiriIpc.action("toggle-window-floating", ["--id", id]);
    }

    function toggleWindowOpacity() {
        if (!niriAvailable) return false;
        return NiriIpc.action("toggle-window-rule-opacity", []);
    }

    function expandColumnToAvailable() {
        if (!niriAvailable) return false;
        return NiriIpc.action("expand-column-to-available-width", []);
    }

    function centerWindow() {
        if (!niriAvailable) return false;
        return NiriIpc.action("center-window", []);
    }

    function screenshotWindow() {
        if (!niriAvailable) return false;
        return NiriIpc.action("screenshot-window", []);
    }

    function keyboardShortcutsInhibitWindow() {
        if (!niriAvailable) return false;
        return NiriIpc.action("toggle-keyboard-shortcuts-inhibit", []);
    }

    function toggleWindowedFullscreen() {
        if (!niriAvailable) return false;
        return NiriIpc.action("toggle-windowed-fullscreen", []);
    }

    function toggleFullscreen() {
        if (!niriAvailable) return false;
        return NiriIpc.action("fullscreen-window", []);
    }

    function toggleMaximize() {
        if (!niriAvailable) return false;
        return NiriIpc.action("maximize-column", []);
    }

    function toggleOverview() {
        if (!niriAvailable) return false;
        return NiriIpc.action("toggle-overview", []);
    }

    function doScreenTransition(delayMs) {
        if (!niriAvailable) return false;
        var delay = delayMs !== undefined ? delayMs : 500;
        return NiriIpc.action("do-screen-transition", ["-d", delay.toString()]);
    }

    function moveColumnToIndex(windowId, index) {
        if (!niriAvailable) return false;
        if (focusWindow(windowId)) {
            return NiriIpc.action("move-column-to-index", [index.toString()]);
        }
        return false;
    }

    function moveColumnToIndexAfterFocus(windowId, index) {
        if (!niriAvailable) return false;
        
        if (Number(windowId) === Number(focusedWindowId)) {
            return NiriIpc.action("move-column-to-index", [index.toString()]);
        }
        
        _moveAfterFocusPendingId = windowId.toString();
        _moveAfterFocusPendingCb = function() {
            NiriIpc.action("move-column-to-index", [index.toString()]);
        };
        
        focusWindow(windowId);
        return true;
    }

    function moveGroupColumnsSequential(initialWindowId, windowIds, targetIndex) {
        if (!windowIds || windowIds.length === 0) return;
        
        // Start the state machine logic
        _seqState = {
            initialWindowId: initialWindowId,
            curWindowId: windowIds[0], // We wait for the first window to gain focus
            windowIds: windowIds,
            targetIndex: targetIndex,
            i: 1 // Start at 1, since we're immediately dispatching index 0 below
        };
        
        // Dispatch the first sequence trigger
        moveColumnToIndexAfterFocus(windowIds[0], targetIndex);
    }

    // --- Grouping Functions ---
    function sortWindows(windowList) {
        return windowList.slice().sort((a, b) => {
            const aPos = Array.isArray(a.layout?.pos_in_scrolling_layout) 
                ? a.layout.pos_in_scrolling_layout : [0, 0];
            const bPos = Array.isArray(b.layout?.pos_in_scrolling_layout) 
                ? b.layout.pos_in_scrolling_layout : [0, 0];
            if (aPos[0] !== bPos[0]) return aPos[0] - bPos[0];
            return aPos[1] - bPos[1];
        });
    }

    function groupWindowsByApp(windowList) {
        windowList = sortWindows(windowList);
        var groups = {};
        
        for (var j = 0; j < windowList.length; j++) {
            var w = windowList[j];
            var appId = w.app_id || "unknown";
            if (!groups[appId]) {
                groups[appId] = {
                    app_id: appId,
                    id: w.id,
                    title: w.title,
                    index: w.index,
                    windows: []
                };
            }
            groups[appId].windows.push(w);
        }
        
        var result = [];
        for (var key in groups) {
            var g = groups[key];
            g.count = g.windows.length;
            g.main = g.windows[0];
            result.push(g);
        }
        return result;
    }

    function groupWindowsByLayoutAndId(windowList) {
        windowList = sortWindows(windowList);
        var groups = [];
        var currentGroup = null;

        for (var j = 0; j < windowList.length; j++) {
            var w = windowList[j];
            if (!currentGroup || currentGroup.app_id !== w.app_id) {
                currentGroup = {
                    app_id: w.app_id,
                    windows: [w],
                    count: 1,
                    title: w.title,
                    id: w.id,
                    main: w
                };
                groups.push(currentGroup);
            } else {
                currentGroup.windows.push(w);
                currentGroup.count = currentGroup.windows.length;
            }
        }
        return groups;
    }

    // --- Layout Config (Gaps) ---
    readonly property string layoutConfigPath: `${Paths.home}/.config/niri/niri/layout.kdl`
    property int gaps: 0
    readonly property bool gapsEnabled: gaps > 0

    FileView {
        id: layoutConfigFile
        path: root.layoutConfigPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const content = text();
            const match = content.match(/gaps\s+(\d+)/);
            if (match) {
                root.gaps = parseInt(match[1]);
            }
        }
    }

    function setGaps(val: int): void {
        val = Math.max(0, val);
        const content = layoutConfigFile.text();
        if (!content) return;

        let newContent = content;
        if (/gaps\s+\d+/.test(content)) {
            newContent = content.replace(/gaps\s+\d+/, `gaps ${val}`);
        } else {
            newContent = content.replace(/(layout\s*\{)/, `$1\n    gaps ${val}`);
        }

        // Clean up any remaining struts block if present
        newContent = newContent.replace(/\n?\s*struts\s*\{[^}]*\}/g, "");

        if (newContent !== content) {
            layoutConfigFile.watchChanges = false;
            layoutConfigFile.setText(newContent);
            layoutConfigFile.watchChanges = true;
            root.gaps = val;

            const proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["niri", "msg", "action", "load-config-file"] }', root);
            proc.exited.connect(() => proc.destroy());
            proc.running = true;
        }
    }

    function toggleGaps(): void {
        setGaps(gaps > 0 ? 0 : 20);
    }
}

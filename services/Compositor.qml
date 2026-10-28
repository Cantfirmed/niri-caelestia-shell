pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    // --- Core Backend ---
    readonly property string backendName: NiriCompositor.backendName
    readonly property bool available: NiriCompositor.available

    // --- Outputs ---
    readonly property var outputs: NiriCompositor.outputs
    readonly property string focusedMonitorName: NiriCompositor.focusedMonitorName
    readonly property bool hasExternalMonitor: NiriCompositor.hasExternalMonitor

    // --- Workspaces ---
    readonly property var workspaces: NiriCompositor.workspaces
    readonly property var allWorkspaces: NiriCompositor.allWorkspaces
    readonly property int focusedWorkspaceIndex: NiriCompositor.focusedWorkspaceIndex
    readonly property int focusedWorkspaceId: NiriCompositor.focusedWorkspaceId
    readonly property var currentOutputWorkspaces: NiriCompositor.currentOutputWorkspaces
    readonly property var workspaceHasWindows: NiriCompositor.workspaceHasWindows
    readonly property bool activeWorkspaceHasWindows: NiriCompositor.activeWorkspaceHasWindows

    // --- Windows ---
    readonly property var windows: NiriCompositor.windows
    readonly property int focusedWindowIndex: NiriCompositor.focusedWindowIndex
    readonly property string focusedWindowId: NiriCompositor.focusedWindowId
    readonly property string activeWindowId: NiriCompositor.activeWindowId
    readonly property string focusedWindowTitle: NiriCompositor.focusedWindowTitle
    readonly property string activeWindowTitle: NiriCompositor.activeWindowTitle
    readonly property string focusedWindowClass: NiriCompositor.focusedWindowClass
    readonly property string activeWindowClass: NiriCompositor.activeWindowClass
    readonly property var focusedWindow: NiriCompositor.focusedWindow
    readonly property var activeWindow: NiriCompositor.activeWindow
    readonly property var lastFocusedWindow: NiriCompositor.lastFocusedWindow
    readonly property string scrollDirection: NiriCompositor.scrollDirection
    readonly property bool inOverview: NiriCompositor.inOverview
    readonly property bool hasFullscreen: NiriCompositor.hasFullscreen

    // --- Keyboard & Lock ---
    readonly property var kbLayoutsArray: NiriCompositor.kbLayoutsArray
    readonly property int kbLayoutIndex: NiriCompositor.kbLayoutIndex
    readonly property string kbLayouts: NiriCompositor.kbLayouts
    readonly property string defaultKbLayout: NiriCompositor.defaultKbLayout
    readonly property string kbLayout: NiriCompositor.kbLayout
    readonly property bool capsLock: NiriCompositor.capsLock
    readonly property bool numLock: NiriCompositor.numLock

    // --- UI Context Menu State ---
    property bool wsContextExpanded: NiriCompositor.wsContextExpanded
    onWsContextExpandedChanged: if (NiriCompositor.wsContextExpanded !== wsContextExpanded) NiriCompositor.wsContextExpanded = wsContextExpanded

    property var wsContextAnchor: NiriCompositor.wsContextAnchor
    onWsContextAnchorChanged: if (NiriCompositor.wsContextAnchor !== wsContextAnchor) NiriCompositor.wsContextAnchor = wsContextAnchor

    property string wsContextType: NiriCompositor.wsContextType
    onWsContextTypeChanged: if (NiriCompositor.wsContextType !== wsContextType) NiriCompositor.wsContextType = wsContextType

    // --- Layout Config (Gaps) ---
    readonly property int gaps: NiriCompositor.gaps
    readonly property bool gapsEnabled: NiriCompositor.gapsEnabled

    // --- Signals ---
    signal windowOpenedOrChanged(var windowData)
    signal keyboardChanged()

    // --- Functions ---
    function cleanWindowTitle(title: string): string {
        return NiriCompositor.cleanWindowTitle(title);
    }

    function refreshOutputs(): void {
        NiriCompositor.refreshOutputs();
    }

    function powerOffMonitors(): void {
        NiriCompositor.powerOffMonitors();
    }

    function powerOnMonitors(): void {
        NiriCompositor.powerOnMonitors();
    }

    function getWorkspaceIdxById(workspaceId: int): int {
        return NiriCompositor.getWorkspaceIdxById(workspaceId);
    }

    function getWorkspacesForOutput(outputName: string): var {
        return NiriCompositor.getWorkspacesForOutput(outputName);
    }

    function getActiveWorkspaceIndexForOutput(outputName: string): int {
        return NiriCompositor.getActiveWorkspaceIndexForOutput(outputName);
    }

    function getFocusedWorkspaceIdForOutput(outputName: string): int {
        return NiriCompositor.getFocusedWorkspaceIdForOutput(outputName);
    }

    function getActiveWorkspaceName(): string {
        return NiriCompositor.getActiveWorkspaceName();
    }

    function getWorkspaceNameByIndex(idx: int): string {
        return NiriCompositor.getWorkspaceNameByIndex(idx);
    }

    function getWorkspaceNameByOutputIndex(outputName: string, idx: int): string {
        return NiriCompositor.getWorkspaceNameByOutputIndex(outputName, idx);
    }

    function getWorkspaceNameById(id: int): string {
        return NiriCompositor.getWorkspaceNameById(id);
    }

    function getWorkspaceByIndex(index: int): var {
        return NiriCompositor.getWorkspaceByIndex(index);
    }

    function getWorkspaceCount(): int {
        return NiriCompositor.getWorkspaceCount();
    }

    function getOccupiedWorkspaceCount(): int {
        return NiriCompositor.getOccupiedWorkspaceCount();
    }

    function getCurrentOutputWorkspaceNumbers(): var {
        return NiriCompositor.getCurrentOutputWorkspaceNumbers();
    }

    function getCurrentWorkspaceNumber(): int {
        return NiriCompositor.getCurrentWorkspaceNumber();
    }

    function switchToWorkspace(workspaceId: var): bool {
        return NiriCompositor.switchToWorkspace(workspaceId);
    }

    function switchToWorkspaceById(workspaceId: var): bool {
        return NiriCompositor.switchToWorkspaceById(workspaceId);
    }

    function focusWorkspace(workspaceIdxOrId: var): bool {
        return NiriCompositor.focusWorkspace(workspaceIdxOrId);
    }

    function focusWorkspaceById(workspaceId: var): bool {
        return NiriCompositor.focusWorkspaceById(workspaceId);
    }

    function focusWorkspaceRelative(delta: int): bool {
        return NiriCompositor.focusWorkspaceRelative(delta);
    }

    function switchToWorkspaceUpDown(direction: string): bool {
        return NiriCompositor.switchToWorkspaceUpDown(direction);
    }

    function switchToWorkspaceByIndex(index: int): bool {
        return NiriCompositor.switchToWorkspaceByIndex(index);
    }

    function switchToWorkspaceByNumber(number: int, output: string): bool {
        return NiriCompositor.switchToWorkspaceByNumber(number, output);
    }

    function moveWindowToWorkspace(workspaceIdx: var): bool {
        return NiriCompositor.moveWindowToWorkspace(workspaceIdx);
    }

    function getActiveWorkspaceWindows(): var {
        return NiriCompositor.getActiveWorkspaceWindows();
    }

    function getWindowsByWorkspaceId(wsid: var): var {
        return NiriCompositor.getWindowsByWorkspaceId(wsid);
    }

    function getWindowsByWorkspaceIndex(index: int): var {
        return NiriCompositor.getWindowsByWorkspaceIndex(index);
    }

    function getWindowsInScreen(screenX: real, screenY: real, screenWidth: real, screenHeight: real, windowBorder: real, padding: real): var {
        return NiriCompositor.getWindowsInScreen(screenX, screenY, screenWidth, screenHeight, windowBorder, padding);
    }

    function focusWindow(windowID: var): bool {
        return NiriCompositor.focusWindow(windowID);
    }

    function closeWindow(windowId: var): bool {
        return NiriCompositor.closeWindow(windowId);
    }

    function closeFocusedWindow(): bool {
        return NiriCompositor.closeFocusedWindow();
    }

    function toggleWindowFloating(windowId: var): bool {
        return NiriCompositor.toggleWindowFloating(windowId);
    }

    function toggleWindowOpacity(): bool {
        return NiriCompositor.toggleWindowOpacity();
    }

    function expandColumnToAvailable(): bool {
        return NiriCompositor.expandColumnToAvailable();
    }

    function centerWindow(): bool {
        return NiriCompositor.centerWindow();
    }

    function screenshotWindow(): bool {
        return NiriCompositor.screenshotWindow();
    }

    function keyboardShortcutsInhibitWindow(): bool {
        return NiriCompositor.keyboardShortcutsInhibitWindow();
    }

    function toggleWindowedFullscreen(): bool {
        return NiriCompositor.toggleWindowedFullscreen();
    }

    function toggleFullscreen(): bool {
        return NiriCompositor.toggleFullscreen();
    }

    function toggleMaximize(): bool {
        return NiriCompositor.toggleMaximize();
    }

    function toggleOverview(): bool {
        return NiriCompositor.toggleOverview();
    }

    function doScreenTransition(delayMs: int): bool {
        return NiriCompositor.doScreenTransition(delayMs);
    }

    function centerColumn(): bool {
        return NiriCompositor.centerColumn();
    }

    function focusColumnLeft(): bool {
        return NiriCompositor.focusColumnLeft();
    }

    function focusColumnRight(): bool {
        return NiriCompositor.focusColumnRight();
    }

    function reorderColumn(windowId: var, index: var): bool {
        return NiriCompositor.reorderColumn(windowId, index);
    }

    function moveColumnToIndex(windowId: var, index: var, restoreFocus = false): bool {
        return NiriCompositor.moveColumnToIndex(windowId, index, restoreFocus);
    }

    function moveColumnToIndexAfterFocus(windowId: var, index: var): bool {
        return NiriCompositor.moveColumnToIndexAfterFocus(windowId, index);
    }

    function moveGroupColumnsSequential(initialWindowId: var, windowIds: var, targetIndicesOrIndex: var): bool {
        return NiriCompositor.moveGroupColumnsSequential(initialWindowId, windowIds, targetIndicesOrIndex);
    }

    function switchKeyboardLayout(indexOrAction: var): void {
        NiriCompositor.switchKeyboardLayout(indexOrAction);
    }

    function setPerformanceMode(enabled: bool): void {
        NiriCompositor.setPerformanceMode(enabled);
    }

    function reloadDynamicConfs(): void {
        NiriCompositor.reloadDynamicConfs();
    }

    function groupWindowsByApp(windowList: var): var {
        return NiriCompositor.groupWindowsByApp(windowList);
    }

    function groupWindowsByLayoutAndId(windowList: var): var {
        return NiriCompositor.groupWindowsByLayoutAndId(windowList);
    }

    function setGaps(val: int): void {
        NiriCompositor.setGaps(val);
    }

    function toggleGaps(): void {
        NiriCompositor.toggleGaps();
    }

    Connections {
        function onWorkspacesChanged() {
            root.workspacesChanged();
        }

        function onActiveWindowChanged() {
            root.activeWindowChanged();
        }

        function onWindowOpenedOrChanged(windowData) {
            root.windowOpenedOrChanged(windowData);
        }

        function onKeyboardChanged() {
            root.keyboardChanged();
        }

        target: NiriCompositor
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config

Singleton {
    id: root

    readonly property var toplevels: ({ values: [] })
    readonly property var workspaces: ({ values: [] })
    readonly property var monitors: ({ values: [] })
    readonly property bool usingLua: false

    readonly property var activeToplevel: null
    readonly property var focusedWorkspace: null
    readonly property var focusedMonitor: null
    readonly property int activeWsId: 1

    readonly property var keyboard: null
    readonly property bool capsLock: false
    readonly property bool numLock: false
    readonly property string defaultKbLayout: "??"
    readonly property string kbLayoutFull: "Unknown"
    readonly property string kbLayout: "??"
    readonly property var kbMap: new Map()

    readonly property var extras: null
    readonly property var options: null
    readonly property var devices: null

    property string lastSpecialWorkspace: ""

    signal configReloaded

    function dispatch(request: string): void {}
    function cycleSpecialWorkspace(direction: string): void {}
    function monitorNames(): list<string> { return []; }
    function monitorFor(screen: ShellScreen): var { return null; }
    function toplevelsForWs(ws: int): var { return []; }
    function isToplevelIgnored(toplevel: var): bool { return true; }
    function reloadDynamicConfs(): void {}
}


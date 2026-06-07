pragma Singleton

import qs.services
import Quickshell
import QtQuick

Singleton {
    property var screens: ({})
    property var bars: new Map()

    property var activeScreens: []
    property bool hasPhysicalScreens: false

    function load(screen: ShellScreen, visibilities: var): void {
        screens[Niri.focusedMonitorName] = visibilities;
    }

    function getForActive(): PersistentProperties {
        const targetName = Niri.focusedMonitorName;
        if (!targetName) return null;
        return screens[targetName] ?? null;
    }

    function updateScreens() {
        var physical = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var screen = Quickshell.screens[i];
            if (screen.name !== "") {
                physical.push(screen);
            }
        }
        if (physical.length > 0) {
            activeScreens = physical;
            hasPhysicalScreens = true;
        } else {
            hasPhysicalScreens = false;
            if (Quickshell.screens.length > 0) {
                activeScreens = [Quickshell.screens[0]];
            } else {
                activeScreens = [];
            }
        }
    }

    Timer {
        id: screenUpdateTimer
        interval: 200 // Delay to avoid destroying QML Windows synchronously during Wayland/compositor hotplug events
        repeat: false
        onTriggered: {
            updateScreens();
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            screenUpdateTimer.restart();
        }
    }

    Component.onCompleted: {
        updateScreens();
    }
}

pragma Singleton

import Quickshell
import Caelestia.Config
import QtQuick

Singleton {
    id: root

    property list<ShellScreen> screens

    function updateScreens() {
        var filtered = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var s = Quickshell.screens[i];
            if (s && s.name && GlobalConfig.forScreen(s.name).enabled) {
                filtered.push(s);
            }
        }
        screens = filtered;
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

    function isExcluded(screen: ShellScreen): bool {
        return screen && screen.name ? !GlobalConfig.forScreen(screen.name).enabled : true;
    }
}

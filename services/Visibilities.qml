pragma Singleton

import qs.services
import Quickshell
import QtQuick

Singleton {
    property var screens: ({})
    property var bars: new Map()

    readonly property var activeScreens: {
        var physical = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var screen = Quickshell.screens[i];
            if (screen && screen.name && screen.name !== "") {
                physical.push(screen);
            }
        }
        return physical;
    }
    readonly property bool hasPhysicalScreens: activeScreens.length > 0

    function load(screen: ShellScreen, visibilities: var): void {
        const targetName = screen && screen.name ? screen.name : Niri.focusedMonitorName;
        if (!targetName)
            return;
        screens[targetName] = visibilities;
    }

    function getForActive(): PersistentProperties {
        const targetName = Niri.focusedMonitorName;
        if (targetName && screens[targetName])
            return screens[targetName];

        const screenNames = Object.keys(screens);
        if (screenNames.length > 0)
            return screens[screenNames[0]];

        return null;
    }
}

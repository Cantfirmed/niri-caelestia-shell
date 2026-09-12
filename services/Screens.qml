pragma Singleton

import Quickshell
import Caelestia.Config

Singleton {
    id: root

    readonly property list<ShellScreen> screens: Quickshell.screens.filter(s => s && s.name && (GlobalConfig.forScreen(s.name)?.enabled ?? false))

    function isExcluded(screen: ShellScreen): bool {
        return screen && screen.name ? !(GlobalConfig.forScreen(screen.name)?.enabled ?? false) : true;
    }
}


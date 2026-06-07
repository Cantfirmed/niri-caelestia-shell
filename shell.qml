//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "components"
import "modules/polkit"
import qs.services
import Quickshell
import QtQuick

ShellRoot {
    settings.watchFiles: true

    GSFLoader {}

    Background {}
    Drawers {}
    AreaPicker {}
    Lock {
        id: lock
    }

    ConfigToasts {}
    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }

    PolkitDialog {}
    ReloadPopup {}

    // Initialize LidInhibitor service
    property var _lidInhibitor: LidInhibitor

    // Fallback display watcher:
    // When the external screen is unplugged (no physical screens remain configured),
    // automatically switch back to the laptop's internal display.
    Connections {
        target: Visibilities

        function onHasPhysicalScreensChanged() {
            if (!Visibilities.hasPhysicalScreens) {
                fallbackTimer.restart();
            } else {
                fallbackTimer.stop();
            }
        }
    }

    Component.onCompleted: {
        if (!Visibilities.hasPhysicalScreens) {
            fallbackTimer.restart();
        }
    }

    Timer {
        id: fallbackTimer
        interval: 1500 // Wait 1.5 seconds to avoid conflicts during mode transitions
        repeat: false
        onTriggered: {
            console.log("[DisplayWatcher] No physical screens detected. Automatically reverting to internal laptop screen.");
            Quickshell.execDetached([`${Quickshell.env("HOME")}/.config/niri/niri-display.py`, "internal"]);
        }
    }
}

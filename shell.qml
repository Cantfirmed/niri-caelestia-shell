//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "components"
import "modules/drawers"
import "modules/areapicker"
import "modules/lock"
import "modules/quicktoggles"
import "modules/background"
import "modules/polkit"
import qs.modules.controlcenter
import qs.services

import Quickshell
import QtQuick

ShellRoot {
    Backdrop {}
    Background {}
    Drawers {}
    AreaPicker {}
    Lock {}

    Shortcuts {}
    QuickTogglesPanel {}

    // Native polkit authentication agent — replaces polkit-kde-authentication-agent-1
    PolkitDialog {}

    ReloadPopup {}

    // Initialize BatteryMonitor service
    property var _batteryMonitor: BatteryMonitor

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
            Quickshell.execDetached(["/home/patrick/.config/niri/niri-display.py", "internal"]);
        }
    }
}

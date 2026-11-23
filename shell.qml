//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QS_DROP_EXPENSIVE_FONTS=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "components"
import "modules/polkit"
import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

ShellRoot {
    id: root

    // Initialize LidInhibitor, PowerManagement and WallFx services
    property var _lidInhibitor: LidInhibitor
    property var _powerManagement: PowerManagement
    property var _wallFx: WallFx

    settings.watchFiles: true

    function syncScreenScales(): void {
        const outs = NiriCompositor.outputs;
        if (!outs)
            return;
        for (const [name, out] of Object.entries(outs)) {
            const s = out?.logical?.scale;
            if (s && s > 0)
                TokenConfig.setScreenScale(name, s);
        }
    }

    Component.onCompleted: syncScreenScales()

    Connections {
        target: NiriCompositor

        function onOutputsChanged(): void {
            root.syncScreenScales();
        }
    }

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    GSFLoader {}
    ServiceLoader {}

    Background {}
    Drawers {}
    AreaPicker {}
    Lock {
        id: lock
    }

    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }

    PolkitDialog {}
    ReloadPopup {}
}


pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.services

Singleton {
    id: root

    property alias enabled: props.enabled

    function setDynamicConfs(): void {
        Compositor.setPerformanceMode(props.enabled);
    }

    onEnabledChanged: {
        setDynamicConfs();
        if (enabled) {
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode enabled"), Tr.tr("Optimized performance mode active"), "gamepad");
        } else {
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode disabled"), Tr.tr("Standard settings restored"), "gamepad");
        }
    }

    PersistentProperties {
        id: props

        property bool enabled: false

        reloadableId: "gameMode"
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "gameMode"
    }
}

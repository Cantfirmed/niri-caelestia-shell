pragma Singleton

import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import QtQuick

Singleton {
    id: root

    property bool cleanedUp: false

    readonly property bool shouldInhibit: {
        const behavior = Config.session.lidBehavior ?? "suspend";
        if (behavior === "ignore") {
            return true;
        }
        if (behavior === "ignoreExternal") {
            return hasExternalMonitor;
        }
        return false;
    }

    readonly property bool hasExternalMonitor: {
        const outputs = Niri.outputs;
        if (!outputs) return false;
        for (const connector in outputs) {
            const lower = connector.toLowerCase();
            if (!lower.startsWith("edp") && !lower.startsWith("lvds") && !lower.startsWith("dsi")) {
                return true;
            }
        }
        return false;
    }

    Process {
        id: cleanupProcess
        running: true
        command: ["pkill", "-f", "who=caelestia-shell"]
        onExited: (code) => {
            root.cleanedUp = true;
        }
    }

    Process {
        id: inhibitProcess
        running: root.shouldInhibit && root.cleanedUp
        command: [
            "systemd-inhibit",
            "--what=handle-lid-switch",
            "--who=caelestia-shell",
            "--why=Lid close setting active",
            "--mode=block",
            "sleep",
            "inf"
        ]
    }

    Component.onDestruction: {
        inhibitProcess.running = false;
    }
}

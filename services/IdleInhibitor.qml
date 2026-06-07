pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property alias enabled: props.enabled

    PersistentProperties {
        id: props

        property bool enabled

        reloadableId: "idleInhibitor"
    }

    Process {
        id: idleProc
        running: root.enabled
        command: ["systemd-inhibit", "--what=idle", "--who=caelestia-shell", "--why=Idle inhibitor active", "--mode=block", "sleep", "inf"]
    }

    Component.onDestruction: {
        idleProc.running = false;
    }

    IpcHandler {
        target: "idleInhibitor"

        function isEnabled(): bool {
            return root.enabled;
        }

        function toggle(): void {
            root.enabled = !root.enabled;
        }

        function enable(): void {
            root.enabled = true;
        }

        function disable(): void {
            root.enabled = false;
        }
    }
}

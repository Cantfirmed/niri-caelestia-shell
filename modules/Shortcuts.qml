import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.components.misc
import qs.services
import qs.modules.nexus

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: false

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "nexus"
        description: "Open nexus"
        onPressed: WindowFactory.create()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "showall"
        description: "Toggle launcher, dashboard and osd"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = Visibilities.getForActive();
            v.launcher = v.dashboard = v.osd = v.utilities = !(v.launcher || v.dashboard || v.osd || v.utilities);
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.dashboard = !visibilities.dashboard;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "session"
        description: "Toggle session menu"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.session = !visibilities.session;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted && !root.hasFullscreen) {
                const visibilities = Visibilities.getForActive();
                visibilities.launcher = !visibilities.launcher;
            }
            root.launcherInterrupted = false;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.sidebar = !visibilities.sidebar;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.utilities = !visibilities.utilities;
        }
    }

    IpcHandler {
        function toggle(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                const visibilities = Visibilities.getForActive();
                visibilities[drawer] = !visibilities[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const visibilities = Visibilities.getForActive();
            return Object.keys(visibilities).filter(k => typeof visibilities[k] === "boolean").join("\n");
        }

        target: "drawers"
    }

    IpcHandler {
        function open(): void {
            WindowFactory.create();
        }

        target: "nexus"
    }

    IpcHandler {
        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }

        target: "toaster"
    }

    IpcHandler {
        target: "clipboard"

        function open(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.clipboardRequested = true
            visibilities.launcher = true
        }

        function close(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.launcher = false
        }

        function toggle(): void {
            const visibilities = Visibilities.getForActive()
            if (visibilities.launcher) {
                visibilities.launcher = false
            } else {
                visibilities.clipboardRequested = true
                visibilities.launcher = true
            }
        }

        function clear(): void {
            Quickshell.execDetached(["cliphist", "wipe"]);
            Quickshell.execDetached(["wl-copy", "--clear"]);
            Toaster.toast(qsTr("Clipboard cleared"), qsTr("The clipboard history has been wiped."), "content_paste_off");
        }
    }

    IpcHandler {
        target: "mangaReader"
        function toggle(): void {
            if (!GlobalConfig.extra.manga) {
                Toaster.toast(qsTr("Manga feature disabled"), qsTr("Enable it in the Control Center settings"), "manga", Toast.Warning)
                return
            }
            const visibilities = Visibilities.getForActive()
            visibilities.manga = !visibilities.manga
        }
    }

    IpcHandler {
        target: "novelReader"
        function toggle(): void {
            if (!GlobalConfig.extra.novel) {
                Toaster.toast(qsTr("Novel feature disabled"), qsTr("Enable it in the Control Center settings"), "book", Toast.Warning)
                return
            }
            const visibilities = Visibilities.getForActive()
            visibilities.novel = !visibilities.novel
        }
    }

    IpcHandler {
        target: "display"

        function open(): void {
            if (!root.hasExternalMonitor) {
                Toaster.toast(qsTr("Display Switcher"), qsTr("No external display connected"), "desktop_windows", Toast.Warning);
                return;
            }
            const visibilities = Visibilities.getForActive();
            if (visibilities) {
                visibilities.displaySelect = true;
            }
        }

        function close(): void {
            const visibilities = Visibilities.getForActive();
            if (visibilities) {
                visibilities.displaySelect = false;
            }
        }

        function toggle(): void {
            const visibilities = Visibilities.getForActive();
            if (visibilities) {
                if (!visibilities.displaySelect && !root.hasExternalMonitor) {
                    Toaster.toast(qsTr("Display Switcher"), qsTr("No external display connected"), "desktop_windows", Toast.Warning);
                    return;
                }
                visibilities.displaySelect = !visibilities.displaySelect;
            }
        }
    }

    IpcHandler {
        target: "soundPanel"

        function open(): void {
            const visibilities = Visibilities.getForActive();
            if (visibilities) visibilities.soundPanel = true;
        }

        function close(): void {
            const visibilities = Visibilities.getForActive();
            if (visibilities) visibilities.soundPanel = false;
        }

        function toggle(): void {
            const visibilities = Visibilities.getForActive();
            if (visibilities) visibilities.soundPanel = !visibilities.soundPanel;
        }
    }

    // Helper property to check for external monitors
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

    LoggingCategory {
        id: lc

        name: "caelestia.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}

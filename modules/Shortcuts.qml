import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services
import qs.modules.nexus
import Caelestia.Config

Scope {
    id: root

    readonly property bool hasFullscreen: false

    IpcHandler {
        function toggle(drawer: string): void {
            const visibilities = Visibilities.getForActive();
            if (!visibilities) {
                console.warn(lc, `No active drawer visibilities available for "${drawer}"`);
                return;
            }

            if (Object.keys(visibilities).filter(k => typeof visibilities[k] === "boolean").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                visibilities[drawer] = !visibilities[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const visibilities = Visibilities.getForActive();
            if (!visibilities)
                return "";
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
            if (visibilities) {
                visibilities.clipboardRequested = true
                visibilities.launcher = true
            }
        }

        function close(): void {
            const visibilities = Visibilities.getForActive()
            if (visibilities)
                visibilities.launcher = false
        }

        function toggle(): void {
            const visibilities = Visibilities.getForActive()
            if (visibilities) {
                if (visibilities.launcher) {
                    visibilities.launcher = false
                } else {
                    visibilities.clipboardRequested = true
                    visibilities.launcher = true
                }
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
            if (visibilities)
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
            if (visibilities)
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

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.Internal
import qs.components.misc
import qs.services
import qs.modules.nexus

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: {
        if (typeof Hypr !== "undefined" && Hypr.focusedWorkspace) {
            return Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
        }
        return false;
    }

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
            const v = ShellState.forActive();
            if (!v) return;
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
            const screenState = ShellState.forActive();
            if (screenState)
                screenState.dashboard = !screenState.dashboard;
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
            const screenState = ShellState.forActive();
            if (screenState)
                screenState.session = !screenState.session;
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
                const screenState = ShellState.forActive();
                if (screenState)
                    screenState.launcher = !screenState.launcher;
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
            const screenState = ShellState.forActive();
            if (screenState)
                screenState.sidebar = !screenState.sidebar;
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
            const screenState = ShellState.forActive();
            if (screenState)
                screenState.utilities = !screenState.utilities;
        }
    }

    IpcHandler {
        function toggle(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                const screenState = ShellState.forActive();
                if (screenState)
                    screenState[drawer] = !screenState[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const screenState = ShellState.forActive();
            if (!screenState) return "";
            return Object.keys(screenState).filter(k => typeof screenState[k] === "boolean").join("\n");
        }

        function isOpen(drawer: string): string {
            const screenState = ShellState.forActive();
            if (!screenState || typeof screenState[drawer] !== "boolean")
                return "unknown";
            return screenState[drawer] ? "1" : "0";
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
            const screenState = ShellState.forActive();
            if (screenState) {
                screenState.clipboardRequested = true;
                screenState.launcher = true;
            }
        }

        function close(): void {
            const screenState = ShellState.forActive();
            if (screenState)
                screenState.launcher = false;
        }

        function toggle(): void {
            const screenState = ShellState.forActive();
            if (screenState) {
                if (screenState.launcher) {
                    screenState.launcher = false;
                } else {
                    screenState.clipboardRequested = true;
                    screenState.launcher = true;
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
                Toaster.toast(qsTr("Manga feature disabled"), qsTr("Enable it in the Control Center settings"), "manga", Toast.Warning);
                return;
            }
            const screenState = ShellState.forActive();
            if (screenState)
                screenState.manga = !screenState.manga;
        }
    }

    IpcHandler {
        target: "novelReader"
        function toggle(): void {
            if (!GlobalConfig.extra.novel) {
                Toaster.toast(qsTr("Novel feature disabled"), qsTr("Enable it in the Control Center settings"), "book", Toast.Warning);
                return;
            }
            const screenState = ShellState.forActive();
            if (screenState)
                screenState.novel = !screenState.novel;
        }
    }

    IpcHandler {
        target: "display"

        function open(): void {
            const screenState = ShellState.forActive();
            if (screenState) {
                NiriIpc.fetchOutputs(); // Refresh outputs on opening
                screenState.displaySelect = true;
            }
        }

        function close(): void {
            const screenState = ShellState.forActive();
            if (screenState) {
                screenState.displaySelect = false;
            }
        }

        function toggle(): void {
            const screenState = ShellState.forActive();
            if (screenState) {
                if (!screenState.displaySelect) {
                    NiriIpc.fetchOutputs(); // Refresh outputs on opening
                }
                screenState.displaySelect = !screenState.displaySelect;
            }
        }
    }

    IpcHandler {
        target: "soundPanel"

        function open(): void {
            const screenState = ShellState.forActive();
            if (screenState) screenState.soundPanel = true;
        }

        function close(): void {
            const screenState = ShellState.forActive();
            if (screenState) screenState.soundPanel = false;
        }

        function toggle(): void {
            const screenState = ShellState.forActive();
            if (screenState) screenState.soundPanel = !screenState.soundPanel;
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

    IpcHandler {
        target: "niriLayout"

        function toggleGaps(): void {
            Niri.toggleGaps();
        }

        function setGaps(val: int): void {
            Niri.setGaps(val);
        }

        function getGaps(): int {
            return Niri.gaps;
        }
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}


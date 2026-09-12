pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Internal
import qs.components
import qs.services

ColumnLayout {
    id: root

    function getClockY(): real {
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item?.entryId === "clock")
                return item.y;
        }
        return vPadding;
    }

    function getClockHeight(): real {
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item?.entryId === "clock")
                return item.implicitHeight;
        }
        return 100;
    }

    function isClockAtY(y: real): bool {
        const ch = childAt(width / 2, y);
        return ch?.entryId === "clock";
    }

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int vPadding: Tokens.padding.large

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = repeater.itemAt(i)?.item as Tray;
            if (tray)
                tray.expanded = false;
        }
    }

    function checkPopout(y: real): void {
        const ch = childAt(width / 2, y);

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const top = ch.y;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const statusItem = ch.item;
            const items = statusItem ? statusItem.items : null;
            if (items) {
                const localPos = mapToItem(items, 0, y);
                const icon = items.childAt(items.width / 2, localPos.y);
                if (icon) {
                    popouts.currentName = icon.name;
                    popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
                    popouts.hasCurrent = true;
                    return;
                }
            }
            popouts.hasCurrent = false;
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item;
            if (tray) {
                if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, tray.implicitWidth / 2, y)))) {
                    const index = Math.floor(((y - top - tray.padding * 2 + tray.spacing) / tray.layout.implicitHeight) * tray.items.count);
                    const trayItem = tray.items.itemAt(index);
                    if (trayItem) {
                        popouts.currentName = `traymenu${index}`;
                        popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
                        popouts.hasCurrent = true;
                        return;
                    }
                } else {
                    tray.expanded = true;
                }
            }
            popouts.hasCurrent = false;
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            if (ch.item) {
                popouts.currentName = id.toLowerCase();
                popouts.currentCenter = ch.item.mapToItem(root, 0, ch.item.implicitHeight / 2).y ?? 0;
                popouts.hasCurrent = true;
                return;
            }
            popouts.hasCurrent = false;
        } else {
            popouts.hasCurrent = false;
        }
    }

    function handleWheel(y: real, angleDelta: point): void {
        const ch = childAt(width / 2, y);
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            if (typeof NiriIpc !== "undefined" && NiriIpc.available) {
                if (angleDelta.y < 0)
                    NiriIpc.action("focus-workspace-down");
                else if (angleDelta.y > 0)
                    NiriIpc.action("focus-workspace-up");
            } else if (typeof Hypr !== "undefined") {
                const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
                const specialWs = mon?.lastIpcObject.specialWorkspace.name;
                if (specialWs?.length > 0)
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
                else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
            }
        } else if (y < screen.height / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on top half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    spacing: Tokens.spacing.medium

    Repeater {
        id: repeater

        model: ScriptModel {
            values: {
                const raw = GlobalConfig.bar?.entries ?? Config.bar?.entries;
                let list = [];
                if (raw) {
                    if (Array.isArray(raw)) list = raw;
                    else if (raw.values) {
                        list = Array.from(typeof raw.values === "function" ? raw.values() : raw.values);
                    }
                }
                if (!list || list.length === 0) {
                    list = [
                        { id: "logo", enabled: true },
                        { id: "workspaces", enabled: true },
                        { id: "spacer", enabled: true },
                        { id: "activeWindow", enabled: true },
                        { id: "spacer", enabled: true },
                        { id: "tray", enabled: true },
                        { id: "clock", enabled: true },
                        { id: "statusIcons", enabled: true },
                        { id: "power", enabled: true }
                    ];
                }
                return list.filter(e => e && e.enabled);
            }
        }

        delegate: Loader {
            id: entryLoader
            required property var modelData
            required property int index

            readonly property string entryId: modelData.id

            Layout.topMargin: index === 0 ? root.vPadding : 0
            Layout.bottomMargin: index === repeater.count - 1 ? root.vPadding : 0
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: modelData.id === "spacer"

            sourceComponent: {
                switch (entryLoader.modelData.id) {
                case "spacer": return spacerComp;
                case "logo": return logoComp;
                case "workspaces": return workspacesComp;
                case "activeWindow": return activeWindowComp;
                case "tray": return trayComp;
                case "clock": return clockComp;
                case "statusIcons": return statusIconsComp;
                case "power": return powerComp;
                default: return null;
                }
            }
        }
    }

    Component {
        id: spacerComp
        Item {}
    }

    Component {
        id: logoComp
        OsIcon {
            objectName: "taskbarLogo"
        }
    }

    Component {
        id: workspacesComp
        Workspaces {
            objectName: "taskbarWorkspaces"
            outputName: root.screen.name
        }
    }

    Component {
        id: activeWindowComp
        ActiveWindow {
            objectName: "taskbarActiveWindow"
            bar: root
            monitor: Brightness.getMonitorForScreen(root.screen)
        }
    }

    Component {
        id: trayComp
        Tray {
            objectName: "taskbarTray"
        }
    }

    Component {
        id: clockComp
        Clock {
            objectName: "taskbarClock"
        }
    }

    Component {
        id: statusIconsComp
        StatusIcons {
            objectName: "taskbarStatusIcons"
        }
    }

    Component {
        id: powerComp
        Power {
            objectName: "taskbarPowerButton"
            screenState: root.screenState
        }
    }
}


pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Caelestia
import Caelestia.Internal
import Caelestia.Config
import Caelestia.I18n
import qs.components.misc
import qs.services
import qs.utils

Singleton {
    id: root

    property list<NotifData> list: []
    readonly property list<NotifData> notClosed: list.filter(n => !n.closed)
    readonly property list<NotifData> popups: list.filter(n => n.popup)
    property alias dnd: props.dnd

    property bool loaded
    property real systemUptime: 0
    property real bootTimestamp: 0

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: {
            const up = parseFloat(text().trim().split(/\s+/)[0] || "0");
            if (up > 0) {
                root.systemUptime = up;
                root.bootTimestamp = Date.now() - (up * 1000);
                Qt.callLater(() => root.cleanupStaleNotifs());
            }
        }
    }

    function isNetworkNotif(notif): bool {
        if (!notif)
            return false;

        const app = (notif.appName ?? "").toLowerCase();
        if (app.includes("network") || app === "nm-applet" || app === "wpa_supplicant" || app === "iwd")
            return true;

        const icon = (notif.appIcon ?? "").toLowerCase();
        if (icon.startsWith("network-") || icon.includes("network-wireless") || icon.includes("network-wired") || icon.includes("network-vpn"))
            return true;

        const cat = (notif.hints?.category ?? notif.hints?.["category"] ?? "").toLowerCase();
        if (cat.startsWith("network"))
            return true;

        const summary = (notif.summary ?? "").toLowerCase();
        const body = (notif.body ?? "").toLowerCase();
        if (body.includes("connection '") && (body.includes("activated") || body.includes("deactivated")))
            return true;
        if ((summary.includes("network") || summary.includes("wi-fi") || summary.includes("wifi")) &&
            (body.includes("connected") || body.includes("disconnected") || body.includes("activated") || body.includes("deactivated")))
            return true;

        return false;
    }

    function isRebootNotif(notif): bool {
        if (!notif)
            return false;

        const app = (notif.appName ?? "").toLowerCase();
        if (app === "cachyos update" || app === "needrestart" || app.includes("reboot"))
            return true;

        const icon = (notif.appIcon ?? "").toLowerCase();
        if (icon === "system-reboot" || icon === "system-restart" || icon.includes("reboot"))
            return true;

        const summary = (notif.summary ?? "").toLowerCase();
        if (summary.includes("reboot") || summary.includes("restart required") || summary.includes("restart recommended"))
            return true;

        const body = (notif.body ?? "").toLowerCase();
        if (body.includes("reboot is recommended") || body.includes("reboot required") || body.includes("system restart is required") || body.includes("system restart recommended"))
            return true;

        return false;
    }

    function clearRebootNotifs(): void {
        for (const notif of root.list.slice()) {
            if (!notif.closed && root.isRebootNotif(notif)) {
                notif.close();
            }
        }
    }

    function hasFullscreen(): bool {
        return Compositor.hasFullscreen;
    }

    function shouldShowPopup(): bool {
        if (props.dnd || ShellState.anySidebarOpen())
            return false;
        const isOff = (typeof NotifsFullscreen !== "undefined") ? (GlobalConfig.notifs.fullscreen === NotifsFullscreen.Off) : (GlobalConfig.notifs.fullscreen === 1);
        if (isOff && hasFullscreen())
            return false;
        return true;
    }

    function matchesApp(notif, appId, title) {
        if (!notif || !appId || appId === "Desktop")
            return false;

        const lowerAppId = String(appId).toLowerCase();

        // 1. Check desktop-entry hint
        const desktopEntry = (notif.hints?.["desktop-entry"] ?? "").toLowerCase();
        if (desktopEntry) {
            const cleanEntry = desktopEntry.replace(/\.desktop$/, "");
            const cleanAppId = lowerAppId.replace(/\.desktop$/, "");
            if (cleanEntry === cleanAppId || cleanAppId.includes(cleanEntry) || cleanEntry.includes(cleanAppId))
                return true;
        }

        // 2. Check appIcon & image
        const appIcon = (notif.appIcon ?? "").toLowerCase();
        const image = (notif.image ?? "").toLowerCase();
        const cleanAppId = lowerAppId.replace(/[\s\-_.]/g, "");
        if (appIcon && appIcon.length > 2) {
            const cleanIcon = appIcon.replace(/[\s\-_.]/g, "");
            if (cleanAppId.includes(cleanIcon) || cleanIcon.includes(cleanAppId))
                return true;
        }
        if (image && image.includes("image://icon/")) {
            const iconName = image.replace("image://icon/", "").replace(/[\s\-_.]/g, "");
            if (iconName && (cleanAppId.includes(iconName) || iconName.includes(cleanAppId)))
                return true;
        }

        // 3. Check appName
        const appName = (notif.appName ?? "").toLowerCase();
        if (appName && appName.length > 2) {
            const cleanName = appName.replace(/[\s\-_.]/g, "");
            if (cleanAppId.includes(cleanName) || cleanName.includes(cleanAppId))
                return true;
        }

        // 4. Fallback: check window title if appName is in window title
        if (title && appName && appName.length > 3) {
            const lowerTitle = String(title).toLowerCase();
            if (lowerTitle.includes(appName))
                return true;
        }

        return false;
    }

    function focusAppWindow(notif) {
        if (!notif)
            return false;

        if (Compositor.available && Compositor.windows) {
            const win = Compositor.windows.find(w => root.matchesApp(notif, w.app_id ?? "", w.title ?? ""));
            if (win && win.id !== undefined) {
                Compositor.focusWindow(win.id);
                return true;
            }
        }
        return false;
    }

    function cleanupStaleNotifs() {
        const hours = GlobalConfig.notifs.staleTimeoutHours ?? 24;
        const maxAgeMs = hours > 0 ? (hours * 3600 * 1000) : (24 * 3600 * 1000);
        const now = Date.now();
        const bootTime = root.bootTimestamp > 0 ? root.bootTimestamp : (root.systemUptime > 0 ? (now - root.systemUptime * 1000) : 0);

        for (const notif of root.list.slice()) {
            if (notif.closed)
                continue;

            // 1. Clean up network notifications immediately if lingering
            if (root.isNetworkNotif(notif)) {
                notif.close();
                continue;
            }

            // 2. Clean up reboot notifications if the system has rebooted/started since they were created
            if (root.isRebootNotif(notif)) {
                const notifTime = notif.time ? (notif.time instanceof Date ? notif.time.getTime() : new Date(notif.time).getTime()) : 0;
                if (bootTime > 0 && notifTime > 0 && notifTime < (bootTime - 5000)) {
                    console.log("[Notifs] Cleaning up reboot notification from previous boot session:", notif.summary, notif.time);
                    notif.close();
                    continue;
                }
            }

            // 3. Clean up stale notifications (older than staleTimeoutHours)
            if (notif.urgency !== NotificationUrgency.Critical) {
                const notifTime = notif.time ? (notif.time instanceof Date ? notif.time.getTime() : new Date(notif.time).getTime()) : 0;
                if (notifTime > 0 && (now - notifTime) > maxAgeMs) {
                    notif.close();
                }
            }
        }
    }

    Connections {
        target: Compositor

        function onActiveWindowChanged(): void {
            if (GlobalConfig.notifs.autoClearOnFocus ?? true) {
                autoClearTimer.restart();
            }
        }
    }

    Timer {
        id: autoClearTimer

        interval: Math.max(200, GlobalConfig.notifs.autoClearDelay ?? 1500)
        onTriggered: {
            if (!(GlobalConfig.notifs.autoClearOnFocus ?? true))
                return;

            const curClass = Compositor.activeWindowClass;
            const curTitle = Compositor.activeWindowTitle;
            if (!curClass || curClass === "Desktop")
                return;

            for (const notif of root.list.slice()) {
                if (!notif.closed && root.matchesApp(notif, curClass, curTitle)) {
                    console.log("[Notifs] Auto-clearing notification for focused app:", curClass, notif.appName, notif.summary);
                    notif.close();
                }
            }
        }
    }

    Timer {
        id: staleCleanupTimer

        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.cleanupStaleNotifs()
    }


    onDndChanged: {
        if (!GlobalConfig.utilities.toasts.dndChanged)
            return;

        if (dnd)
            Toaster.toast(Tr.tr("Do not disturb enabled"), Tr.tr("Popup notifications are now disabled"), "do_not_disturb_on");
        else
            Toaster.toast(Tr.tr("Do not disturb disabled"), Tr.tr("Popup notifications are now enabled"), "do_not_disturb_off");
    }

    onListChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: storage.setText(JSON.stringify(root.notClosed.filter(n => !n.isNetwork && !root.isNetworkNotif(n)).map(n => ({
                    time: n.time,
                    id: n.id,
                    summary: n.summary,
                    body: n.body,
                    appIcon: n.appIcon,
                    appName: n.appName,
                    image: n.image,
                    expireTimeout: n.expireTimeout,
                    urgency: n.urgency,
                    resident: n.resident,
                    hasActionIcons: n.hasActionIcons,
                    actions: n.actions
                }))))
    }

    PersistentProperties {
        id: props

        property bool dnd

        reloadableId: "notifs"
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;

            const curClass = Compositor.activeWindowClass;
            const isCurrentlyFocused = (GlobalConfig.notifs.autoClearOnFocus ?? true) && curClass && curClass !== "Desktop" && root.matchesApp(notif, curClass, Compositor.activeWindowTitle);

            const comp = notifComp.createObject(root, {
                popup: root.shouldShowPopup(),
                notification: notif
            });
            root.list = [comp, ...root.list];

            if (isCurrentlyFocused) {
                autoClearTimer.restart();
            }
        }
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/notifs.json`
        onLoaded: {
            const data = JSON.parse(text());
            const now = Date.now();
            const bootTime = root.bootTimestamp > 0 ? root.bootTimestamp : (root.systemUptime > 0 ? (now - root.systemUptime * 1000) : 0);

            for (const notif of data) {
                const properties = Object.assign({}, notif);

                // Discard any network notification from saved state
                if (root.isNetworkNotif(properties))
                    continue;

                // Discard any reboot notification from before the current boot session
                if (root.isRebootNotif(properties)) {
                    const notifTime = properties.time ? new Date(properties.time).getTime() : 0;
                    if (bootTime > 0 && notifTime > 0 && notifTime < (bootTime - 5000))
                        continue;
                }

                // Backwards compatibility for old notifications
                if (properties.notificationId === undefined && properties.id !== undefined)
                    properties.notificationId = properties.id;

                delete properties.id;
                root.list.push(notifComp.createObject(root, properties));
            }
            root.list.sort((a, b) => b.time - a.time);
            root.loaded = true;
            Qt.callLater(() => root.cleanupStaleNotifs());
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                Qt.callLater(() => setText("[]"));
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clearNotifs"
        description: "Clear all notifications"
        onPressed: {
            for (const notif of root.list.slice())
                notif.close();
        }
    }


    IpcHandler {
        function clear(): void {
            for (const notif of root.list.slice())
                notif.close();
        }

        function clearReboot(): void {
            root.clearRebootNotifs();
        }

        function isDndEnabled(): bool {
            return props.dnd;
        }

        function toggleDnd(): void {
            props.dnd = !props.dnd;
        }

        function enableDnd(): void {
            props.dnd = true;
        }

        function disableDnd(): void {
            props.dnd = false;
        }

        target: "notifs"
    }

    Component {
        id: notifComp

        NotifData {}
    }
}

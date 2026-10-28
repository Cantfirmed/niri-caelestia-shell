pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

Singleton {
    id: root

    property string osName
    property string osPrettyName
    property string osId
    property list<string> osIdLike
    property string osLogo: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/logo.svg`)
    property bool isDefaultLogo: true

    property string uptime
    // Uptime trimmed to its two largest components
    property string uptimeShort
    readonly property string user: Quickshell.env("USER")
    readonly property string wm: Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP")
    readonly property string shell: Quickshell.env("SHELL").split("/").pop()

    property string kernel
    property string hostname
    property string firmware

    // DMI vendor/model, combined into a single human-readable device name
    property string boardVendor
    property string boardName
    readonly property string device: {
        if (!boardName)
            return boardVendor;
        if (!boardVendor || boardName.toLowerCase().startsWith(boardVendor.toLowerCase()))
            return boardName;
        return `${boardVendor} ${boardName}`;
    }

    // Strips the placeholder strings OEMs commonly leave in DMI fields
    function sanitiseDmi(s: string): string {
        const t = s.trim();
        const junk = ["to be filled by o.e.m.", "system product name", "system manufacturer", "system version", "default string", "o.e.m.", "not specified", "not applicable", "unknown", "none", ""];
        return junk.includes(t.toLowerCase()) ? "" : t;
    }

    function resolveLogo(name: string): string {
        if (!name || name === "caelestia")
            return "";
        if (name.startsWith("/") || name.startsWith("~"))
            return "file://" + Paths.absolutePath(name);
        if (name.startsWith("file://"))
            return name;

        const themed = Quickshell.iconPath(name, true)
            || Quickshell.iconPath(`distributor-logo-${name}`, true)
            || (name !== "caelestia" ? Quickshell.iconPath("distributor-logo", true) : "");
        if (themed)
            return themed;

        if (name === "cachyos")
            return Qt.resolvedUrl(`${Quickshell.shellDir}/assets/cachyos.svg`);

        return "";
    }

    FileView {
        id: osRelease

        path: "/etc/os-release"
        onLoaded: {
            const lines = text().split("\n");

            const fd = key => lines.find(l => l.startsWith(`${key}=`))?.split("=")[1].replace(/"/g, "") ?? "";

            root.osName = fd("NAME");
            root.osPrettyName = fd("PRETTY_NAME");
            root.osId = fd("ID");
            root.osIdLike = fd("ID_LIKE").split(" ");

            const configuredLogo = GlobalConfig.general.logo;
            if (configuredLogo === "caelestia") {
                root.osLogo = Qt.resolvedUrl(`${Quickshell.shellDir}/assets/logo.svg`);
                root.isDefaultLogo = true;
            } else if (configuredLogo) {
                const resolved = root.resolveLogo(configuredLogo);
                root.osLogo = resolved || "file://" + Paths.absolutePath(configuredLogo);
                root.isDefaultLogo = false;
            } else {
                const target = fd("LOGO") || fd("ID") || "";
                const logo = root.resolveLogo(target);
                if (logo) {
                    root.osLogo = logo;
                    root.isDefaultLogo = false;
                } else {
                    root.osLogo = Qt.resolvedUrl(`${Quickshell.shellDir}/assets/logo.svg`);
                    root.isDefaultLogo = true;
                }
            }
        }
    }

    Connections {
        function onLogoChanged(): void {
            osRelease.reload();
        }

        target: GlobalConfig.general
    }

    FileView {
        path: "/proc/sys/kernel/osrelease"
        onLoaded: root.kernel = text().trim()
    }

    FileView {
        path: "/proc/sys/kernel/hostname"
        onLoaded: root.hostname = text().trim()
    }

    FileView {
        path: "/sys/class/dmi/id/sys_vendor"
        printErrors: false
        onLoaded: root.boardVendor = root.sanitiseDmi(text())
    }

    FileView {
        path: "/sys/class/dmi/id/product_name"
        printErrors: false
        onLoaded: root.boardName = root.sanitiseDmi(text())
    }

    FileView {
        path: "/sys/class/dmi/id/bios_version"
        printErrors: false
        onLoaded: root.firmware = root.sanitiseDmi(text())
    }

    Timer {
        running: true
        repeat: true
        interval: 15000
        onTriggered: fileUptime.reload()
    }

    FileView {
        id: fileUptime

        path: "/proc/uptime"
        onLoaded: {
            const up = parseInt(text().split(" ")[0] ?? 0);

            const days = Math.floor(up / 86400);
            const hours = Math.floor((up % 86400) / 3600);
            const minutes = Math.floor((up % 3600) / 60);

            // TRANSLATORS: joins uptime components, e.g. "2 days, 3 hours"
            const sep = Tr.trCtx(", ", "uptime component separator");

            const parts = [];
            if (days > 0)
                parts.push(Tr.trN("%n day", "%n days", days));
            if (hours > 0)
                parts.push(Tr.trN("%n hour", "%n hours", hours));
            if (minutes > 0 || parts.length === 0)
                parts.push(Tr.trN("%n minute", "%n minutes", minutes));

            root.uptime = parts.join(sep);
            root.uptimeShort = parts.slice(0, 2).join(sep);
        }
    }
}

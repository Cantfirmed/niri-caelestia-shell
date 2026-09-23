pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property list<var> pages: [
        // Appearance
        {
            label: qsTr("Wallpaper & style"),
            icon: "palette",
            description: qsTr("Wallpaper, fonts, colours"),
            category: "appearance",
            keywords: "wallpaper background style colors colours theme dark light accents font"
        },
        {
            label: qsTr("Window blur"),
            icon: "blur_on",
            description: qsTr("Niri transparency, blur, video rules"),
            category: "appearance",
            keywords: "blur transparency opacity effects window rules rounded corners compositor"
        },

        // Connectivity
        // TODO
        // {
        //     label: qsTr("Display"),
        //     icon: "monitor",
        //     description: qsTr("Output configuration"),
        //     category: "connectivity",
        //     keywords: "display monitor resolution refresh rate screen"
        // },
        {
            label: qsTr("Network"),
            icon: "wifi",
            description: qsTr("Wi-Fi, ethernet"),
            category: "connectivity",
            keywords: "network wifi wi-fi ethernet lan wlan internet ip subnet dns"
        },
        {
            label: qsTr("VPN"),
            icon: "vpn_key",
            description: qsTr("WireGuard, OpenVPN, Tailscale, custom"),
            category: "connectivity",
            keywords: "vpn wireguard openvpn tailscale netbird warp cloudflare proxy tunnel security private"
        },
        {
            label: qsTr("Connected devices"),
            icon: "devices_other",
            description: qsTr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true,
            keywords: "bluetooth devices pairing pair connect headset headphones mouse keyboard controller"
        },
        {
            label: qsTr("Audio"),
            icon: "volume_up",
            description: qsTr("App volumes, sound devices"),
            category: "connectivity",
            keywords: "audio sound volume speaker microphone sink source output input apps devices"
        },

        // System
        {
            label: qsTr("Updates"),
            icon: "update",
            description: qsTr("System updates"),
            category: "system",
            keywords: "updates system upgrade package manager dnf pacman apt zypper"
        },
        {
            label: qsTr("Plugins"),
            icon: "extension",
            description: qsTr("Manage plugins"),
            category: "system",
            keywords: "plugins extensions addons modules components"
        },

        // Shell
        {
            label: qsTr("Panels"),
            icon: "dock_to_bottom",
            description: qsTr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell",
            keywords: "panels taskbar dock bar dashboard launcher sidebar utilities drawers widgets statusbar"
        },
        {
            label: qsTr("Apps"),
            icon: "apps",
            description: qsTr("Default apps, favourites, tiling rules"),
            category: "shell",
            keywords: "apps applications default favorites favourites hidden mime desktop terminal browser tiling tiled rules window"
        },
        {
            label: qsTr("Services"),
            icon: "build",
            description: qsTr("Poll intervals, lyrics backend"),
            category: "shell",
            keywords: "services daemon background polling lyrics mpris notifications intervals"
        },
        {
            label: qsTr("Language & region"),
            icon: "globe",
            description: qsTr("UI language, weather location, display units"),
            category: "shell",
            keywords: "language region locale weather units celsius fahrenheit format date time"
        },

        // About
        {
            label: qsTr("About"),
            icon: "info",
            description: qsTr("System information, credits"),
            category: "about",
            keywords: "about system info specs version quickshell niri kernel os credits caelestia"
        },
    ]
}

pragma Singleton

import QtQuick
import Caelestia.I18n

QtObject {
    id: root

    readonly property list<var> pages: [
        // Appearance
        {
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Wallpaper, fonts, colours"),
            category: "appearance",
            keywords: "wallpaper background style colors colours theme dark light accents font"
        },
        {
            label: Tr.tr("Window blur"),
            icon: "blur_on",
            description: Tr.tr("Niri transparency, blur, video rules"),
            category: "appearance",
            keywords: "blur transparency opacity effects window rules rounded corners compositor"
        },
        {
            label: Tr.tr("Biri Shaders & FX"),
            icon: "auto_awesome",
            description: Tr.tr("Animated borders, light spill, screen/cursor shaders"),
            category: "appearance",
            keywords: "shaders biri focus ring glow lightning rainbow ripple cursor crt effects light spill"
        },

        // Connectivity
        {
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet"),
            category: "connectivity",
            keywords: "network wifi wi-fi ethernet lan wlan internet ip subnet dns"
        },
        {
            label: Tr.tr("VPN"),
            icon: "vpn_key",
            description: Tr.tr("WireGuard, OpenVPN, Tailscale, custom"),
            category: "connectivity",
            keywords: "vpn wireguard openvpn tailscale netbird warp cloudflare proxy tunnel security private"
        },
        {
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true,
            keywords: "bluetooth devices pairing pair connect headset headphones mouse keyboard controller"
        },
        {
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "connectivity",
            keywords: "audio sound volume speaker microphone sink source output input apps devices"
        },

        // System
        {
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("System updates"),
            category: "system",
            keywords: "updates system upgrade package manager dnf pacman apt zypper"
        },
        {
            label: Tr.tr("Plugins"),
            icon: "extension",
            description: Tr.tr("Manage plugins"),
            category: "system",
            keywords: "plugins extensions addons modules components"
        },

        // Shell
        {
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell",
            keywords: "panels taskbar dock bar dashboard launcher sidebar utilities drawers widgets statusbar"
        },
        {
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, tiling rules"),
            category: "shell",
            keywords: "apps applications default favorites favourites hidden mime desktop terminal browser tiling tiled rules window"
        },
        {
            label: Tr.tr("Services"),
            icon: "build",
            description: Tr.tr("Poll intervals, lyrics backend"),
            category: "shell",
            keywords: "services daemon background polling lyrics mpris notifications intervals"
        },
        {
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "shell",
            keywords: "language region locale weather units celsius fahrenheit format date time"
        },

        // About
        {
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about",
            keywords: "about system info specs version quickshell niri kernel os credits caelestia"
        },
    ]
}

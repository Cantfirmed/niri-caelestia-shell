pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Internal
import qs.utils

Singleton {
    id: root

    readonly property string blurConfigPath: `${Paths.home}/.config/niri/niri/blur.kdl`
    readonly property string statePath: `${Paths.home}/.local/state/caelestia/niri_blur.json`

    property bool loaded: false

    property bool blurEnabled: true
    property real activeOpacity: 0.90
    property bool inactiveOpacityEnabled: true
    property real inactiveOpacity: 0.95
    property real noise: 0.30
    property real saturation: 5.00

    property bool videoPlayersEnabled: true
    property string videoPlayersRegex: "(?i)(mpv|vlc|totem|celluloid|kodi|plex|freetube|jellyfin)"

    property bool pipEnabled: true
    property string pipRegex: "(?i)(Picture-in-Picture|PiP)"

    property bool videoStreamsEnabled: true
    property string videoStreamsRegex: "(?i)(youtube|twitch|netflix|prime video|disney\\+|hulu|crunchyroll|bilibili)"

    property bool fullscreenVideoEnabled: true
    property string fullscreenVideoRegex: "(?i)(full[- ]?screen|fullscreen)"

    property var exceptions: [
        {
            id: "firefox$",
            type: "app-id",
            opacity: 1.0,
            blur: false,
            enabled: true
        },
        {
            id: "code$",
            type: "app-id",
            opacity: 1.0,
            blur: false,
            enabled: true
        }
    ]

    onBlurEnabledChanged: requestSave()
    onActiveOpacityChanged: requestSave()
    onInactiveOpacityEnabledChanged: requestSave()
    onInactiveOpacityChanged: requestSave()
    onNoiseChanged: requestSave()
    onSaturationChanged: requestSave()
    onVideoPlayersEnabledChanged: requestSave()
    onVideoPlayersRegexChanged: requestSave()
    onPipEnabledChanged: requestSave()
    onPipRegexChanged: requestSave()
    onVideoStreamsEnabledChanged: requestSave()
    onVideoStreamsRegexChanged: requestSave()
    onFullscreenVideoEnabledChanged: requestSave()
    onFullscreenVideoRegexChanged: requestSave()

    function requestSave(): void {
        if (!root.loaded)
            return;
        saveDebounceTimer.restart();
    }

    Timer {
        id: saveDebounceTimer

        interval: 150
        onTriggered: root.saveImmediately()
    }

    function init(): void {
        console.log("[NiriBlur] Initializing service...");
        if (!root.loaded)
            initTimer.start();
    }

    Timer {
        id: initTimer

        interval: 150
        onTriggered: {
            if (!root.loaded) {
                root.loaded = true;
                root.saveImmediately();
            }
        }
    }

    // State file reading
    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        onLoaded: {
            const raw = text();
            if (raw && raw.trim().length > 0) {
                try {
                    const data = JSON.parse(raw);
                    if (data) {
                        if (data.blurEnabled !== undefined) root.blurEnabled = data.blurEnabled;
                        if (data.activeOpacity !== undefined) root.activeOpacity = data.activeOpacity;
                        if (data.inactiveOpacityEnabled !== undefined) root.inactiveOpacityEnabled = data.inactiveOpacityEnabled;
                        if (data.inactiveOpacity !== undefined) root.inactiveOpacity = data.inactiveOpacity;
                        if (data.noise !== undefined) root.noise = data.noise;
                        if (data.saturation !== undefined) root.saturation = data.saturation;
                        if (data.videoPlayersEnabled !== undefined) root.videoPlayersEnabled = data.videoPlayersEnabled;
                        if (data.videoPlayersRegex !== undefined) root.videoPlayersRegex = data.videoPlayersRegex;
                        if (data.pipEnabled !== undefined) root.pipEnabled = data.pipEnabled;
                        if (data.pipRegex !== undefined) root.pipRegex = data.pipRegex;
                        if (data.videoStreamsEnabled !== undefined) root.videoStreamsEnabled = data.videoStreamsEnabled;
                        if (data.videoStreamsRegex !== undefined) root.videoStreamsRegex = data.videoStreamsRegex;
                        if (data.fullscreenVideoEnabled !== undefined) root.fullscreenVideoEnabled = data.fullscreenVideoEnabled;
                        if (data.fullscreenVideoRegex !== undefined) root.fullscreenVideoRegex = data.fullscreenVideoRegex;
                        if (Array.isArray(data.exceptions)) root.exceptions = data.exceptions;
                    }
                } catch (e) {
                    console.warn("[NiriBlur] Failed to parse state file:", e);
                }
                root.loaded = true;
                root.saveImmediately();
            } else {
                root.loaded = true;
                root.saveImmediately();
            }
        }
        onLoadFailed: {
            root.loaded = true;
            root.saveImmediately();
        }
    }

    FileView {
        id: blurKdlWriter

        path: root.blurConfigPath
        printErrors: true
    }

    FileView {
        id: stateWriter

        path: root.statePath
        printErrors: true
    }

    function saveImmediately(): void {
        if (!root.loaded)
            return;

        const stateObj = {
            blurEnabled: root.blurEnabled,
            activeOpacity: root.activeOpacity,
            inactiveOpacityEnabled: root.inactiveOpacityEnabled,
            inactiveOpacity: root.inactiveOpacity,
            noise: root.noise,
            saturation: root.saturation,
            videoPlayersEnabled: root.videoPlayersEnabled,
            videoPlayersRegex: root.videoPlayersRegex,
            pipEnabled: root.pipEnabled,
            pipRegex: root.pipRegex,
            videoStreamsEnabled: root.videoStreamsEnabled,
            videoStreamsRegex: root.videoStreamsRegex,
            fullscreenVideoEnabled: root.fullscreenVideoEnabled,
            fullscreenVideoRegex: root.fullscreenVideoRegex,
            exceptions: root.exceptions
        };

        const jsonStr = JSON.stringify(stateObj, null, 2);
        stateWriter.setText(jsonStr);

        const kdl = generateKdl();
        console.log("[NiriBlur] Writing blur.kdl (length:", kdl.length, ")");
        blurKdlWriter.setText(kdl);

        // Reload niri config
        reloadNiriConfig();
    }

    function reloadNiriConfig(): void {
        Quickshell.execDetached(["niri", "msg", "action", "load-config-file"]);
    }

    function generateKdl(): string {
        let kdl = "// ============================================================================\n";
        kdl += "// NIRI BLUR & TRANSPARENCY CONFIGURATION\n";
        kdl += "// Generated automatically by Caelestia Nexus Settings. Edits may be overwritten.\n";
        kdl += "// ============================================================================\n\n";

        if (!root.blurEnabled) {
            kdl += "window-rule {\n";
            kdl += "    opacity 1.0\n";
            kdl += "    background-effect {\n";
            kdl += "        blur false\n";
            kdl += "    }\n";
            kdl += "}\n";
            return kdl;
        }

        const actOp = Math.max(0.1, Math.min(1.0, root.activeOpacity)).toFixed(2);
        const noiseVal = Math.max(0.0, Math.min(1.0, root.noise)).toFixed(2);
        const satVal = Math.max(0.0, Math.min(10.0, root.saturation)).toFixed(2);

        // 1. Base / Active window rule
        kdl += "// ---------------- Global / Active Windows ----------------\n";
        kdl += "window-rule {\n";
        kdl += `    opacity ${actOp}\n`;
        kdl += "    background-effect {\n";
        kdl += "        blur true\n";
        kdl += `        noise ${noiseVal}\n`;
        kdl += `        saturation ${satVal}\n`;
        kdl += "    }\n";
        kdl += "}\n\n";

        // 2. Inactive window rule
        if (root.inactiveOpacityEnabled) {
            const inactOp = Math.max(0.1, Math.min(1.0, root.inactiveOpacity)).toFixed(2);
            kdl += "// ---------------- Inactive Windows ----------------\n";
            kdl += "window-rule {\n";
            kdl += "    match is-active=false\n";
            kdl += `    opacity ${inactOp}\n`;
            kdl += "    background-effect {\n";
            kdl += "        blur true\n";
            kdl += `        noise ${noiseVal}\n`;
            kdl += `        saturation ${satVal}\n`;
            kdl += "    }\n";
            kdl += "}\n\n";
        }

        // 3. Video Players rule
        if (root.videoPlayersEnabled && root.videoPlayersRegex.trim().length > 0) {
            kdl += "// ---------------- Video Players (Opaque / No Blur) ----------------\n";
            kdl += "window-rule {\n";
            kdl += `    match app-id=r#"${root.videoPlayersRegex.trim()}"#\n`;
            kdl += "    opacity 1.00\n";
            kdl += "    background-effect {\n";
            kdl += "        blur false\n";
            kdl += "    }\n";
            kdl += "}\n\n";
        }

        // 4. Picture-in-Picture rule
        if (root.pipEnabled && root.pipRegex.trim().length > 0) {
            kdl += "// ---------------- Picture-in-Picture (Opaque / No Blur) ----------------\n";
            kdl += "window-rule {\n";
            kdl += `    match title=r#"${root.pipRegex.trim()}"#\n`;
            kdl += "    opacity 1.00\n";
            kdl += "    background-effect {\n";
            kdl += "        blur false\n";
            kdl += "    }\n";
            kdl += "}\n\n";
        }

        // 5. Video streaming websites rule
        if (root.videoStreamsEnabled && root.videoStreamsRegex.trim().length > 0) {
            kdl += "// ---------------- Video Streaming Sites (Opaque / No Blur) ----------------\n";
            kdl += "window-rule {\n";
            kdl += `    match title=r#"${root.videoStreamsRegex.trim()}"#\n`;
            kdl += "    opacity 1.00\n";
            kdl += "    background-effect {\n";
            kdl += "        blur false\n";
            kdl += "    }\n";
            kdl += "}\n\n";
        }

        // 6. Fullscreen video rule
        if (root.fullscreenVideoEnabled && root.fullscreenVideoRegex.trim().length > 0) {
            kdl += "// ---------------- Full Screen Video (Opaque / No Blur) ----------------\n";
            kdl += "window-rule {\n";
            kdl += `    match title=r#"${root.fullscreenVideoRegex.trim()}"#\n`;
            kdl += "    opacity 1.00\n";
            kdl += "    background-effect {\n";
            kdl += "        blur false\n";
            kdl += "    }\n";
            kdl += "}\n\n";
        }

        // 7. Custom user exceptions
        if (Array.isArray(root.exceptions) && root.exceptions.length > 0) {
            let userRulesAdded = false;
            for (let i = 0; i < root.exceptions.length; i++) {
                const ex = root.exceptions[i];
                if (!ex || !ex.enabled || !ex.id || ex.id.trim().length === 0) continue;
                if (!userRulesAdded) {
                    kdl += "// ---------------- Custom Exceptions ----------------\n";
                    userRulesAdded = true;
                }
                const op = (ex.opacity !== undefined ? Math.max(0.1, Math.min(1.0, ex.opacity)) : 1.0).toFixed(2);
                const blur = ex.blur ? "true" : "false";
                const type = ex.type === "title" ? "title" : "app-id";
                const cleanId = ex.id.trim();
                const matchStr = cleanId.includes('"') || cleanId.includes('\\') ? `r#"${cleanId}"#` : `"${cleanId}"`;

                kdl += "window-rule {\n";
                kdl += `    match ${type}=${matchStr}\n`;
                kdl += `    opacity ${op}\n`;
                kdl += "    background-effect {\n";
                kdl += `        blur ${blur}\n`;
                kdl += "    }\n";
                kdl += "}\n\n";
            }
        }

        return kdl;
    }

    function addException(id: string, type: string, opacity: real, blur: bool): void {
        const list = Array.from(root.exceptions);
        list.push({
            id: id,
            type: type || "app-id",
            opacity: opacity !== undefined ? opacity : 1.0,
            blur: blur !== undefined ? blur : false,
            enabled: true
        });
        root.exceptions = list;
        requestSave();
    }

    function removeException(index: int): void {
        if (index < 0 || index >= root.exceptions.length) return;
        const list = Array.from(root.exceptions);
        list.splice(index, 1);
        root.exceptions = list;
        requestSave();
    }

    function toggleException(index: int, enabled: bool): void {
        if (index < 0 || index >= root.exceptions.length) return;
        const list = Array.from(root.exceptions);
        list[index].enabled = enabled;
        root.exceptions = list;
        requestSave();
    }

    function resetToDefaults(): void {
        root.blurEnabled = true;
        root.activeOpacity = 0.90;
        root.inactiveOpacityEnabled = true;
        root.inactiveOpacity = 0.95;
        root.noise = 0.30;
        root.saturation = 5.00;
        root.videoPlayersEnabled = true;
        root.videoPlayersRegex = "(?i)(mpv|vlc|totem|celluloid|kodi|plex|freetube|jellyfin)";
        root.pipEnabled = true;
        root.pipRegex = "(?i)(Picture-in-Picture|PiP)";
        root.videoStreamsEnabled = true;
        root.videoStreamsRegex = "(?i)(youtube|twitch|netflix|prime video|disney\\+|hulu|crunchyroll|bilibili)";
        root.fullscreenVideoEnabled = true;
        root.fullscreenVideoRegex = "(?i)(full[- ]?screen|fullscreen)";
        root.exceptions = [
            {
                id: "firefox$",
                type: "app-id",
                opacity: 1.0,
                blur: false,
                enabled: true
            },
            {
                id: "code$",
                type: "app-id",
                opacity: 1.0,
                blur: false,
                enabled: true
            }
        ];
        requestSave();
    }
}

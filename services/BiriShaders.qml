pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Internal
import qs.utils

Singleton {
    id: root

    readonly property string shadersConfigPath: `${Paths.home}/.config/niri/niri/shaders.kdl`
    readonly property string shadersDir: `${Paths.home}/.config/niri/shaders`
    readonly property string statePath: `${Paths.home}/.local/state/caelestia/biri_shaders.json`

    property bool loaded: false

    // Focus Ring / Border Shader
    property bool focusRingEnabled: false
    property string focusRingPreset: "rainbow-ripple"
    property int focusRingWidth: 4
    property int focusRingPadding: 14
    property bool lightSpillEnabled: true
    property int lightSpread: 80
    property real lightIntensity: 1.0
    property real lightThreshold: 0.5

    // Window Open/Close Animation Shader
    property bool windowAnimEnabled: false
    property string windowAnimPreset: "whirlpool"
    property int windowAnimDuration: 400

    // Global / Screen / Cursor Shader
    property bool globalShaderEnabled: false
    property string globalShaderPreset: "comet-glow"

    // Consolidated Carousel Overview
    property bool carouselEnabled: false
    property real carouselRevealZoom: 0.7
    property real carouselAssembledZoom: 0.5

    // Shader Animation Max FPS (0 = monitor refresh rate)
    property int shaderMaxFps: 0

    function requestSave(): void {
        if (!root.loaded)
            return;
        saveDebounceTimer.restart();
    }

    function init(): void {
        console.log("[BiriShaders] Initializing service...");
        if (!root.loaded)
            initTimer.start();
    }

    function saveImmediately(): void {
        if (!root.loaded)
            return;

        const stateObj = {
            focusRingEnabled: root.focusRingEnabled,
            focusRingPreset: root.focusRingPreset,
            focusRingWidth: root.focusRingWidth,
            focusRingPadding: root.focusRingPadding,
            lightSpillEnabled: root.lightSpillEnabled,
            lightSpread: root.lightSpread,
            lightIntensity: root.lightIntensity,
            lightThreshold: root.lightThreshold,

            windowAnimEnabled: root.windowAnimEnabled,
            windowAnimPreset: root.windowAnimPreset,
            windowAnimDuration: root.windowAnimDuration,

            globalShaderEnabled: root.globalShaderEnabled,
            globalShaderPreset: root.globalShaderPreset,

            carouselEnabled: root.carouselEnabled,
            carouselRevealZoom: root.carouselRevealZoom,
            carouselAssembledZoom: root.carouselAssembledZoom,

            shaderMaxFps: root.shaderMaxFps
        };

        const jsonStr = JSON.stringify(stateObj, null, 2);
        stateWriter.setText(jsonStr);

        const kdl = generateKdl();
        shadersKdlWriter.setText(kdl);

        reloadNiriConfig();
    }

    function reloadNiriConfig(): void {
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["niri", "msg", "action", "load-config-file"] }', root);
        proc.exited.connect(() => proc.destroy());
        proc.running = true;
    }

    function generateKdl(): string {
        let kdl = "// ============================================================================\n";
        kdl += "// BIRI SHADERS & FX CONFIGURATION\n";
        kdl += "// Generated automatically by Caelestia Nexus Settings. Edits may be overwritten.\n";
        kdl += "// ============================================================================\n\n";

        // 1. Optional Shader Animation Max FPS
        if (root.shaderMaxFps > 0) {
            kdl += `shader-animation-max-fps ${root.shaderMaxFps}\n\n`;
        }

        // 2. Focus Ring / Border Shader
        if (root.focusRingEnabled && root.focusRingPreset !== "none") {
            let fragFile = "";
            let pad = root.focusRingPadding;

            if (root.focusRingPreset === "rainbow-ripple") {
                fragFile = `${root.shadersDir}/focus-ring/rainbow-ripple.frag`;
                if (pad <= 0) pad = 14;
            } else if (root.focusRingPreset === "lightning") {
                fragFile = `${root.shadersDir}/focus-ring/lightning.frag`;
                if (pad <= 0) pad = 24;
            } else if (root.focusRingPreset === "pulse") {
                fragFile = `${root.shadersDir}/focus-ring/pulse.frag`;
                if (pad <= 0) pad = 4;
            }

            if (fragFile.length > 0) {
                kdl += "// ---------------- Focus Ring Shader ----------------\n";
                kdl += "layout {\n";
                kdl += "    focus-ring {\n";
                kdl += "        on\n";
                kdl += `        width ${root.focusRingWidth}\n`;
                kdl += "        shader {\n";
                kdl += `            path "${fragFile}"\n`;
                kdl += `            padding ${pad}\n`;
                if (root.lightSpillEnabled) {
                    const spread = root.lightSpread;
                    const intensity = root.lightIntensity.toFixed(2);
                    const threshold = root.lightThreshold.toFixed(2);
                    kdl += `            light spread=${spread} intensity=${intensity} threshold=${threshold}\n`;
                }
                kdl += "        }\n";
                kdl += "    }\n";
                kdl += "}\n\n";
            }
        }

        // 3. Window Open/Close Animation Shader
        if (root.windowAnimEnabled && root.windowAnimPreset !== "none") {
            const animFile = `${root.shadersDir}/close/close-${root.windowAnimPreset}.kdl`;
            kdl += "// ---------------- Window Animation Shader ----------------\n";
            kdl += `include "${animFile}"\n\n`;
        }

        // 4. Global / Screen / Cursor Shader
        if (root.globalShaderEnabled && root.globalShaderPreset !== "none") {
            let shaderFile = "";
            const cursorPresets = ["comet-glow", "blueglow", "rainbow-tunnel", "ripple", "shockwave", "spotlight", "trail"];
            const screenPresets = ["crt", "warmtint", "grayscale", "vignette"];

            if (cursorPresets.includes(root.globalShaderPreset)) {
                shaderFile = `${root.shadersDir}/cursor/${root.globalShaderPreset}.kdl`;
            } else if (screenPresets.includes(root.globalShaderPreset)) {
                shaderFile = `${root.shadersDir}/screen/${root.globalShaderPreset}.kdl`;
            }

            if (shaderFile.length > 0) {
                kdl += "// ---------------- Global / Screen / Cursor Shader ----------------\n";
                kdl += `include "${shaderFile}"\n\n`;
            }
        }

        // 5. Consolidated Carousel Overview
        if (root.carouselEnabled) {
            const rz = root.carouselRevealZoom.toFixed(2);
            const az = root.carouselAssembledZoom.toFixed(2);
            kdl += "// ---------------- Consolidated Carousel Overview ----------------\n";
            kdl += "overview {\n";
            kdl += "    consolidated-carousel {\n";
            kdl += `        reveal-zoom ${rz}\n`;
            kdl += `        assembled-zoom ${az}\n`;
            kdl += "    }\n";
            kdl += "}\n\n";
        }

        return kdl;
    }

    function resetToDefaults(): void {
        root.focusRingEnabled = false;
        root.focusRingPreset = "rainbow-ripple";
        root.focusRingWidth = 4;
        root.focusRingPadding = 14;
        root.lightSpillEnabled = true;
        root.lightSpread = 80;
        root.lightIntensity = 1.0;
        root.lightThreshold = 0.5;

        root.windowAnimEnabled = false;
        root.windowAnimPreset = "whirlpool";
        root.windowAnimDuration = 400;

        root.globalShaderEnabled = false;
        root.globalShaderPreset = "comet-glow";

        root.carouselEnabled = false;
        root.carouselRevealZoom = 0.7;
        root.carouselAssembledZoom = 0.5;

        root.shaderMaxFps = 0;

        saveImmediately();
    }

    onFocusRingEnabledChanged: requestSave()
    onFocusRingPresetChanged: requestSave()
    onFocusRingWidthChanged: requestSave()
    onFocusRingPaddingChanged: requestSave()
    onLightSpillEnabledChanged: requestSave()
    onLightSpreadChanged: requestSave()
    onLightIntensityChanged: requestSave()
    onLightThresholdChanged: requestSave()

    onWindowAnimEnabledChanged: requestSave()
    onWindowAnimPresetChanged: requestSave()
    onWindowAnimDurationChanged: requestSave()

    onGlobalShaderEnabledChanged: requestSave()
    onGlobalShaderPresetChanged: requestSave()

    onCarouselEnabledChanged: requestSave()
    onCarouselRevealZoomChanged: requestSave()
    onCarouselAssembledZoomChanged: requestSave()

    onShaderMaxFpsChanged: requestSave()

    Timer {
        id: saveDebounceTimer

        interval: 150
        onTriggered: root.saveImmediately()
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
                        if (data.focusRingEnabled !== undefined) root.focusRingEnabled = data.focusRingEnabled;
                        if (data.focusRingPreset !== undefined) root.focusRingPreset = data.focusRingPreset;
                        if (data.focusRingWidth !== undefined) root.focusRingWidth = data.focusRingWidth;
                        if (data.focusRingPadding !== undefined) root.focusRingPadding = data.focusRingPadding;
                        if (data.lightSpillEnabled !== undefined) root.lightSpillEnabled = data.lightSpillEnabled;
                        if (data.lightSpread !== undefined) root.lightSpread = data.lightSpread;
                        if (data.lightIntensity !== undefined) root.lightIntensity = data.lightIntensity;
                        if (data.lightThreshold !== undefined) root.lightThreshold = data.lightThreshold;

                        if (data.windowAnimEnabled !== undefined) root.windowAnimEnabled = data.windowAnimEnabled;
                        if (data.windowAnimPreset !== undefined) root.windowAnimPreset = data.windowAnimPreset;
                        if (data.windowAnimDuration !== undefined) root.windowAnimDuration = data.windowAnimDuration;

                        if (data.globalShaderEnabled !== undefined) root.globalShaderEnabled = data.globalShaderEnabled;
                        if (data.globalShaderPreset !== undefined) root.globalShaderPreset = data.globalShaderPreset;

                        if (data.carouselEnabled !== undefined) root.carouselEnabled = data.carouselEnabled;
                        if (data.carouselRevealZoom !== undefined) root.carouselRevealZoom = data.carouselRevealZoom;
                        if (data.carouselAssembledZoom !== undefined) root.carouselAssembledZoom = data.carouselAssembledZoom;

                        if (data.shaderMaxFps !== undefined) root.shaderMaxFps = data.shaderMaxFps;
                    }
                } catch (e) {
                    console.warn("[BiriShaders] Failed to parse state file:", e);
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
        id: shadersKdlWriter

        path: root.shadersConfigPath
        printErrors: true
    }

    FileView {
        id: stateWriter

        path: root.statePath
        printErrors: true
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Internal
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property string shadersConfigPath: `${Paths.home}/.config/niri/niri/shaders.kdl`
    readonly property string shadersDir: `${Paths.home}/.config/niri/shaders`
    readonly property string statePath: `${Paths.home}/.local/state/caelestia/biri_shaders.json`

    property bool loaded: false

    // Focus Ring / Border Shader
    property bool focusRingEnabled: false
    property string focusRingPreset: "pulse"
    property int focusRingWidth: 2
    property int focusRingPadding: 3
    property bool lightSpillEnabled: true
    property int lightSpread: 14
    property real lightIntensity: 0.65
    property real lightThreshold: 0.55

    // Pulse Focus Ring Theme / Background Color Matching
    property bool pulseMatchTheme: true
    property string pulseColorMode: "blend" // "blend" (primary + tertiary), "primary", "spectrum", "cyan"
    readonly property color currentThemePrimary: Colours.palette.m3primary
    readonly property color currentThemeSecondary: Colours.palette.m3secondary
    readonly property color currentThemeTertiary: Colours.palette.m3tertiary

    // Window Open/Close Animation Shader
    property bool windowAnimEnabled: false
    property string windowAnimPreset: "whirlpool"
    property int windowAnimDuration: 400

    // Global / Screen / Cursor Shader
    property bool globalShaderEnabled: false
    property string globalShaderPreset: "locator"

    // Consolidated Carousel Overview
    property bool carouselEnabled: false
    property real carouselRevealZoom: 0.7
    property real carouselAssembledZoom: 0.5

    // Shader Animation Max FPS (0 = monitor refresh rate)
    property int shaderMaxFps: 0

    // Per-Window Shaders & In-Flight Cycler
    property bool windowShadersEnabled: true

    // Per-Output Colour Filters & Cycler
    property bool outputShadersEnabled: true

    readonly property list<string> cursorPresets: [
        "locator", "spotlight", "blueglow", "trail", "comet-glow", "rainbow-tunnel", "ripple", "shockwave"
    ]
    readonly property list<string> screenPresets: [
        "crt", "vignette", "grayscale", "warmtint"
    ]

    readonly property bool isCursorShaderActive: globalShaderEnabled && cursorPresets.includes(globalShaderPreset)
    readonly property bool isScreenFilterActive: globalShaderEnabled && screenPresets.includes(globalShaderPreset)
    readonly property string activeCursorPreset: isCursorShaderActive ? globalShaderPreset : "none"
    readonly property string activeScreenPreset: isScreenFilterActive ? globalShaderPreset : "none"

    readonly property string activePreset: {
        if (!focusRingEnabled && !windowAnimEnabled && !globalShaderEnabled)
            return "off";
        if (focusRingEnabled && focusRingPreset === "pulse" && !windowAnimEnabled && !globalShaderEnabled)
            return "focus";
        if (focusRingEnabled && focusRingPreset === "pulse" && !windowAnimEnabled && globalShaderEnabled && globalShaderPreset === "locator")
            return "locator";
        if (focusRingEnabled && focusRingPreset === "pulse" && !windowAnimEnabled && globalShaderEnabled && globalShaderPreset === "spotlight")
            return "presentation";
        if (focusRingEnabled && focusRingPreset === "pulse" && windowAnimEnabled && windowAnimPreset === "melt" && globalShaderEnabled && globalShaderPreset === "crt")
            return "retro";
        if (focusRingEnabled && focusRingPreset === "rainbow-ripple" && windowAnimEnabled && windowAnimPreset === "whirlpool" && globalShaderEnabled && globalShaderPreset === "comet-glow")
            return "cyberpunk";
        return "custom";
    }

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

    function applyPreset(name: string): void {
        if (name === "off") {
            root.focusRingEnabled = false;
            root.windowAnimEnabled = false;
            root.globalShaderEnabled = false;
        } else if (name === "focus") {
            root.focusRingEnabled = true;
            root.focusRingPreset = "pulse";
            root.focusRingWidth = 2;
            root.focusRingPadding = 3;
            root.lightSpillEnabled = true;
            root.lightSpread = 14;
            root.lightIntensity = 0.65;
            root.lightThreshold = 0.55;
            root.windowAnimEnabled = false;
            root.globalShaderEnabled = false;
        } else if (name === "locator") {
            root.focusRingEnabled = true;
            root.focusRingPreset = "pulse";
            root.focusRingWidth = 2;
            root.focusRingPadding = 3;
            root.lightSpillEnabled = true;
            root.lightSpread = 12;
            root.lightIntensity = 0.6;
            root.lightThreshold = 0.55;
            root.windowAnimEnabled = false;
            root.globalShaderEnabled = true;
            root.globalShaderPreset = "locator";
        } else if (name === "presentation") {
            root.focusRingEnabled = true;
            root.focusRingPreset = "pulse";
            root.focusRingWidth = 2;
            root.focusRingPadding = 3;
            root.lightSpillEnabled = true;
            root.lightSpread = 14;
            root.lightIntensity = 0.7;
            root.lightThreshold = 0.5;
            root.windowAnimEnabled = false;
            root.globalShaderEnabled = true;
            root.globalShaderPreset = "spotlight";
        } else if (name === "retro") {
            root.focusRingEnabled = true;
            root.focusRingPreset = "pulse";
            root.focusRingWidth = 2;
            root.focusRingPadding = 2;
            root.lightSpillEnabled = false;
            root.windowAnimEnabled = true;
            root.windowAnimPreset = "melt";
            root.globalShaderEnabled = true;
            root.globalShaderPreset = "crt";
        } else if (name === "cyberpunk") {
            root.focusRingEnabled = true;
            root.focusRingPreset = "rainbow-ripple";
            root.focusRingWidth = 3;
            root.focusRingPadding = 8;
            root.lightSpillEnabled = true;
            root.lightSpread = 22;
            root.lightIntensity = 0.85;
            root.lightThreshold = 0.5;
            root.windowAnimEnabled = true;
            root.windowAnimPreset = "whirlpool";
            root.globalShaderEnabled = true;
            root.globalShaderPreset = "comet-glow";
        }
        root.saveImmediately();
    }

    function selectFocusRing(preset: string): void {
        if (preset === "none") {
            root.focusRingEnabled = false;
        } else if (root.focusRingPreset === preset && root.focusRingEnabled) {
            root.focusRingEnabled = false;
        } else {
            root.focusRingPreset = preset;
            root.focusRingEnabled = true;
        }
        root.saveImmediately();
    }

    function selectWindowAnim(preset: string): void {
        if (preset === "none") {
            root.windowAnimEnabled = false;
        } else if (root.windowAnimPreset === preset && root.windowAnimEnabled) {
            root.windowAnimEnabled = false;
        } else {
            root.windowAnimPreset = preset;
            root.windowAnimEnabled = true;
        }
        root.saveImmediately();
    }

    function selectCursorShader(preset: string): void {
        if (preset === "none" || (root.globalShaderPreset === preset && root.globalShaderEnabled)) {
            if (root.cursorPresets.includes(root.globalShaderPreset)) {
                root.globalShaderEnabled = false;
            }
        } else {
            root.globalShaderPreset = preset;
            root.globalShaderEnabled = true;
        }
        root.saveImmediately();
    }

    function selectScreenFilter(preset: string): void {
        if (preset === "none" || (root.globalShaderPreset === preset && root.globalShaderEnabled)) {
            if (root.screenPresets.includes(root.globalShaderPreset)) {
                root.globalShaderEnabled = false;
            }
        } else {
            root.globalShaderPreset = preset;
            root.globalShaderEnabled = true;
        }
        root.saveImmediately();
    }

    function selectGlobalShader(preset: string): void {
        if (preset === "none") {
            root.globalShaderEnabled = false;
        } else if (root.globalShaderPreset === preset && root.globalShaderEnabled) {
            root.globalShaderEnabled = false;
        } else {
            root.globalShaderPreset = preset;
            root.globalShaderEnabled = true;
        }
        root.saveImmediately();
    }

    function toggleAll(): void {
        const anyOn = root.focusRingEnabled || root.windowAnimEnabled || root.globalShaderEnabled;
        if (anyOn) {
            applyPreset("off");
        } else {
            applyPreset("cyberpunk");
        }
    }

    function cycleWindowShader(): void {
        Quickshell.execDetached(["niri", "msg", "action", "cycle-window-shader"]);
    }

    function toggleWindowShader(): void {
        Quickshell.execDetached(["niri", "msg", "action", "toggle-window-shader"]);
    }

    function cycleOutputShader(): void {
        Quickshell.execDetached(["niri", "msg", "action", "cycle-output-shader"]);
    }

    function toggleOutputShader(): void {
        Quickshell.execDetached(["niri", "msg", "action", "toggle-output-shader"]);
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

            shaderMaxFps: root.shaderMaxFps,
            windowShadersEnabled: root.windowShadersEnabled,
            outputShadersEnabled: root.outputShadersEnabled,

            pulseMatchTheme: root.pulseMatchTheme,
            pulseColorMode: root.pulseColorMode
        };

        const jsonStr = JSON.stringify(stateObj, null, 2);
        stateWriter.setText(jsonStr);

        updatePulseShader();

        const kdl = generateKdl();
        shadersKdlWriter.setText(kdl);

        reloadNiriConfig();
    }

    function reloadNiriConfig(): void {
        Quickshell.execDetached(["niri", "msg", "action", "load-config-file"]);
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

            if (root.cursorPresets.includes(root.globalShaderPreset)) {
                shaderFile = `${root.shadersDir}/cursor/${root.globalShaderPreset}.kdl`;
            } else if (root.screenPresets.includes(root.globalShaderPreset)) {
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

        // 6. Per-Window Shaders & In-Flight Cycler
        if (root.windowShadersEnabled) {
            kdl += "// ---------------- Per-Window Shader Presets ----------------\n";
            kdl += "window-shaders {\n";
            kdl += `    preset "crt" { path "${root.shadersDir}/window/crt.frag"; }\n`;
            kdl += `    preset "parchment" { path "${root.shadersDir}/window/parchment.frag"; }\n`;
            kdl += `    preset "pixel-mosaic" { path "${root.shadersDir}/window/pixel-mosaic.frag"; }\n`;
            kdl += `    preset "mercury" { path "${root.shadersDir}/window/mercury-sheen.frag"; }\n`;
            kdl += `    preset "shimmer" { path "${root.shadersDir}/window/rgb-shimmer.frag"; }\n`;
            kdl += `    preset "ripple-drops" { path "${root.shadersDir}/window/ripple-drops.frag"; }\n`;
            kdl += `    preset "rorschach" { path "${root.shadersDir}/window/rorschach2.frag"; }\n`;
            kdl += "}\n\n";
        }

        // 7. Per-Output Colour Filter Presets
        if (root.outputShadersEnabled) {
            kdl += "// ---------------- Per-Output Colour Filter Presets ----------------\n";
            kdl += "output-shaders {\n";
            kdl += "    preset \"grayscale\" { preset \"grayscale\"; }\n";
            kdl += "    preset \"invert\" { preset \"invert\"; }\n";
            kdl += "    preset \"warm\" { preset \"temperature\" kelvin=4000; }\n";
            kdl += "    preset \"vivid\" { preset \"saturation\" amount=1.4; }\n";
            kdl += "}\n\n";
        }

        let bindsKdl = "";
        if (root.windowShadersEnabled) {
            bindsKdl += "    Mod+Shift+B { cycle-window-shader; }\n";
            bindsKdl += "    Mod+Alt+B { toggle-window-shader; }\n";
        }
        if (root.outputShadersEnabled) {
            bindsKdl += "    Mod+Shift+C { cycle-output-shader; }\n";
            bindsKdl += "    Mod+Alt+C { toggle-output-shader; }\n";
        }
        if (bindsKdl.length > 0) {
            kdl += "// ---------------- Shader Keybindings ----------------\n";
            kdl += "binds {\n" + bindsKdl + "}\n\n";
        }

        return kdl;
    }

    function resetToDefaults(): void {
        root.focusRingEnabled = false;
        root.focusRingPreset = "pulse";
        root.focusRingWidth = 2;
        root.focusRingPadding = 3;
        root.lightSpillEnabled = true;
        root.lightSpread = 14;
        root.lightIntensity = 0.65;
        root.lightThreshold = 0.55;

        root.windowAnimEnabled = false;
        root.windowAnimPreset = "whirlpool";
        root.windowAnimDuration = 400;

        root.globalShaderEnabled = false;
        root.globalShaderPreset = "locator";

        root.carouselEnabled = false;
        root.carouselRevealZoom = 0.7;
        root.carouselAssembledZoom = 0.5;

        root.shaderMaxFps = 0;

        root.pulseMatchTheme = true;
        root.pulseColorMode = "blend";

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

    onPulseMatchThemeChanged: {
        updatePulseShader();
        requestSave();
    }
    onPulseColorModeChanged: {
        updatePulseShader();
        requestSave();
    }
    onCurrentThemePrimaryChanged: updatePulseShader()
    onCurrentThemeSecondaryChanged: updatePulseShader()
    onCurrentThemeTertiaryChanged: updatePulseShader()

    onWindowAnimEnabledChanged: requestSave()
    onWindowAnimPresetChanged: requestSave()
    onWindowAnimDurationChanged: requestSave()

    onGlobalShaderEnabledChanged: requestSave()
    onGlobalShaderPresetChanged: requestSave()

    onCarouselEnabledChanged: requestSave()
    onCarouselRevealZoomChanged: requestSave()
    onCarouselAssembledZoomChanged: requestSave()

    onShaderMaxFpsChanged: requestSave()
    onWindowShadersEnabledChanged: requestSave()
    onOutputShadersEnabledChanged: requestSave()

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
                        if (data.windowShadersEnabled !== undefined) root.windowShadersEnabled = data.windowShadersEnabled;
                        if (data.outputShadersEnabled !== undefined) root.outputShadersEnabled = data.outputShadersEnabled;

                        if (data.pulseMatchTheme !== undefined) root.pulseMatchTheme = data.pulseMatchTheme;
                        if (data.pulseColorMode !== undefined) root.pulseColorMode = data.pulseColorMode;
                    }
                } catch (e) {
                    console.warn("[BiriShaders] Failed to parse state file:", e);
                }
                root.loaded = true;
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

    FileView {
        id: pulseFragWriter

        path: `${root.shadersDir}/focus-ring/pulse.frag`
        printErrors: true
    }

    function toVec3(c: color): string {
        if (!c) return "vec3(1.0, 0.7, 0.8)";
        const r = Math.max(0, Math.min(1, c.r)).toFixed(3);
        const g = Math.max(0, Math.min(1, c.g)).toFixed(3);
        const b = Math.max(0, Math.min(1, c.b)).toFixed(3);
        return `vec3(${r}, ${g}, ${b})`;
    }

    function generatePulseFrag(): string {
        let glsl = "// Biri Focus Ring - Dynamic Background / Theme Pulse Shader\n";
        glsl += "// Generated automatically by Caelestia Biri Shaders to match desktop wallpaper.\n";
        glsl += "vec4 ring_color(vec2 coords) {\n";
        glsl += "    float d = ring_distance(coords);\n";
        glsl += "    float half_px = 0.5 / niri_scale;\n";
        glsl += "    float coverage = smoothstep(-half_px, half_px, d)\n";
        glsl += "        * (1.0 - smoothstep(ring_width - half_px, ring_width + half_px, d));\n";
        glsl += "    float pulse = 0.65 + 0.35 * sin(niri_time * 2.0);\n";

        if (!root.pulseMatchTheme || root.pulseColorMode === "cyan") {
            glsl += "    vec3 col = vec3(0.15, 0.8, 1.0);\n";
        } else if (root.pulseColorMode === "primary") {
            const c1 = Colours.palette.m3primary;
            glsl += `    vec3 col = ${toVec3(c1)};\n`;
        } else if (root.pulseColorMode === "spectrum") {
            const c1 = Colours.palette.m3primary;
            const c2 = Colours.palette.m3secondary;
            const c3 = Colours.palette.m3tertiary;
            glsl += `    vec3 colA = ${toVec3(c1)};\n`;
            glsl += `    vec3 colB = ${toVec3(c2)};\n`;
            glsl += `    vec3 colC = ${toVec3(c3)};\n`;
            glsl += "    float t = fract(niri_time * 0.25);\n";
            glsl += "    vec3 col = (t < 0.333) ? mix(colA, colB, t * 3.0) : ((t < 0.666) ? mix(colB, colC, (t - 0.333) * 3.0) : mix(colC, colA, (t - 0.666) * 3.0));\n";
        } else { // "blend" (default)
            const c1 = Colours.palette.m3primary;
            const c2 = Colours.palette.m3tertiary;
            glsl += `    vec3 colA = ${toVec3(c1)}; // Background Primary\n`;
            glsl += `    vec3 colB = ${toVec3(c2)}; // Background Tertiary\n`;
            glsl += "    vec3 col = mix(colA, colB, 0.5 + 0.5 * sin(niri_time * 1.2));\n";
        }

        glsl += "    return vec4(col * pulse, coverage);\n";
        glsl += "}\n";
        return glsl;
    }

    function updatePulseShader(): void {
        pulseFragWriter.setText(generatePulseFrag());
    }
}

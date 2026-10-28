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
    property real pulseSpeed: 1.2

    // Pulse Focus Ring Theme / Background Color Matching
    property bool pulseMatchTheme: true
    property string pulseColorMode: "blend" // "blend" (primary + tertiary), "primary", "spectrum", "cyan"
    readonly property color currentThemePrimary: Colours.palette.m3primary
    readonly property color currentThemeSecondary: Colours.palette.m3secondary
    readonly property color currentThemeTertiary: Colours.palette.m3tertiary
    readonly property color currentThemeSurface: Colours.palette.m3surface

    // Window Open/Close Animation Shader
    property bool windowAnimEnabled: false
    property string windowAnimPreset: "whirlpool"
    property int windowAnimDuration: 400
    property real whirlpoolTwist: 1.5
    property real animScaleDamping: 0.5
    property bool animThemeTint: true

    // Global / Screen / Cursor Shader
    property bool globalShaderEnabled: false
    property string globalShaderPreset: "locator"
    property real vignetteStrength: 0.65
    property real scanlineDensity: 1.0
    property real scanlineDarkness: 0.15
    property real chromaticAberration: 0.0

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
        if (focusRingEnabled && focusRingPreset === "pulse" && focusRingWidth === 1 && !lightSpillEnabled && !windowAnimEnabled && !globalShaderEnabled)
            return "minimal-clean";
        if (focusRingEnabled && focusRingPreset === "pulse" && lightSpillEnabled && lightSpread >= 18 && windowAnimEnabled && windowAnimPreset === "whirlpool" && !globalShaderEnabled)
            return "ambient-glow";
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
        } else if (name === "minimal-clean") {
            root.focusRingEnabled = true;
            root.focusRingPreset = "pulse";
            root.focusRingWidth = 1;
            root.focusRingPadding = 2;
            root.lightSpillEnabled = false;
            root.pulseMatchTheme = true;
            root.pulseColorMode = "primary";
            root.pulseSpeed = 1.0;
            root.windowAnimEnabled = false;
            root.globalShaderEnabled = false;
        } else if (name === "ambient-glow") {
            root.focusRingEnabled = true;
            root.focusRingPreset = "pulse";
            root.focusRingWidth = 2;
            root.focusRingPadding = 4;
            root.lightSpillEnabled = true;
            root.lightSpread = 20;
            root.lightIntensity = 0.75;
            root.lightThreshold = 0.50;
            root.pulseMatchTheme = true;
            root.pulseColorMode = "blend";
            root.pulseSpeed = 1.2;
            root.windowAnimEnabled = true;
            root.windowAnimPreset = "whirlpool";
            root.windowAnimDuration = 400;
            root.whirlpoolTwist = 1.2;
            root.animScaleDamping = 0.5;
            root.animThemeTint = true;
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
            root.pulseMatchTheme = true;
            root.pulseColorMode = "blend";
            root.pulseSpeed = 1.2;
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
            root.pulseMatchTheme = true;
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
            root.pulseMatchTheme = true;
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
            root.windowAnimDuration = 450;
            root.globalShaderEnabled = true;
            root.globalShaderPreset = "crt";
            root.scanlineDensity = 1.0;
            root.scanlineDarkness = 0.20;
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
            root.windowAnimDuration = 450;
            root.whirlpoolTwist = 2.0;
            root.animScaleDamping = 0.6;
            root.globalShaderEnabled = true;
            root.globalShaderPreset = "comet-glow";
            root.chromaticAberration = 0.003;
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
            applyPreset("ambient-glow");
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
            pulseSpeed: root.pulseSpeed,

            windowAnimEnabled: root.windowAnimEnabled,
            windowAnimPreset: root.windowAnimPreset,
            windowAnimDuration: root.windowAnimDuration,
            whirlpoolTwist: root.whirlpoolTwist,
            animScaleDamping: root.animScaleDamping,
            animThemeTint: root.animThemeTint,

            globalShaderEnabled: root.globalShaderEnabled,
            globalShaderPreset: root.globalShaderPreset,
            vignetteStrength: root.vignetteStrength,
            scanlineDensity: root.scanlineDensity,
            scanlineDarkness: root.scanlineDarkness,
            chromaticAberration: root.chromaticAberration,

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

    function toVec3(c: color): string {
        if (!c) return "vec3(1.0, 0.7, 0.8)";
        const r = Math.max(0, Math.min(1, c.r)).toFixed(3);
        const g = Math.max(0, Math.min(1, c.g)).toFixed(3);
        const b = Math.max(0, Math.min(1, c.b)).toFixed(3);
        return `vec3(${r}, ${g}, ${b})`;
    }

    function generatePulseFrag(): string {
        const pSpeed = root.pulseSpeed.toFixed(2);
        const colPrimary = toVec3(Colours.palette.m3primary);
        const colSecondary = toVec3(Colours.palette.m3secondary);
        const colTertiary = toVec3(Colours.palette.m3tertiary);
        const colSurface = toVec3(Colours.palette.m3surface);

        let glsl = "// Biri Focus Ring - Dynamic Background / Theme Pulse Shader\n";
        glsl += "// Generated automatically by Caelestia Biri Shaders to match desktop wallpaper.\n";
        glsl += `const vec3 THEME_PRIMARY = ${colPrimary};\n`;
        glsl += `const vec3 THEME_SECONDARY = ${colSecondary};\n`;
        glsl += `const vec3 THEME_TERTIARY = ${colTertiary};\n`;
        glsl += `const vec3 THEME_SURFACE = ${colSurface};\n`;
        glsl += `const float PULSE_SPEED = ${pSpeed};\n\n`;

        glsl += "vec4 ring_color(vec2 coords) {\n";
        glsl += "    float d = ring_distance(coords);\n";
        glsl += "    float half_px = 0.5 / niri_scale;\n";
        glsl += "    float coverage = smoothstep(-half_px, half_px, d)\n";
        glsl += "        * (1.0 - smoothstep(ring_width - half_px, ring_width + half_px, d));\n";
        glsl += `    float pulse = 0.65 + 0.35 * sin(niri_time * PULSE_SPEED * 2.0);\n`;

        if (!root.pulseMatchTheme || root.pulseColorMode === "cyan") {
            glsl += "    vec3 col = vec3(0.15, 0.8, 1.0);\n";
        } else if (root.pulseColorMode === "primary") {
            glsl += "    vec3 col = THEME_PRIMARY;\n";
        } else if (root.pulseColorMode === "spectrum") {
            glsl += `    float t = fract(niri_time * PULSE_SPEED * 0.25);\n`;
            glsl += "    vec3 col = (t < 0.333) ? mix(THEME_PRIMARY, THEME_SECONDARY, t * 3.0) : ((t < 0.666) ? mix(THEME_SECONDARY, THEME_TERTIARY, (t - 0.333) * 3.0) : mix(THEME_TERTIARY, THEME_PRIMARY, (t - 0.666) * 3.0));\n";
        } else { // "blend" (default)
            glsl += `    vec3 col = mix(THEME_PRIMARY, THEME_TERTIARY, 0.5 + 0.5 * sin(niri_time * PULSE_SPEED * 1.2));\n`;
        }

        glsl += "    return vec4(col * pulse, coverage);\n";
        glsl += "}\n";
        return glsl;
    }

    function updatePulseShader(): void {
        pulseFragWriter.setText(generatePulseFrag());
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
            kdl += "// ---------------- Window Animation Shader ----------------\n";
            if (root.windowAnimPreset === "whirlpool") {
                const duration = Math.max(100, root.windowAnimDuration);
                const twist = root.whirlpoolTwist.toFixed(2);
                const damp = root.animScaleDamping.toFixed(2);
                const themeCol = toVec3(Colours.palette.m3primary);
                const themeTertiary = toVec3(Colours.palette.m3tertiary);

                kdl += "animations {\n";
                kdl += "    window-open {\n";
                kdl += `        duration-ms ${duration}\n`;
                kdl += "        curve \"linear\"\n";
                kdl += "        custom-shader r\"\n";
                kdl += `            const vec3 THEME_COL = ${themeCol};\n`;
                kdl += `            const float TWIST = ${twist};\n`;
                kdl += `            const float DAMP = ${damp};\n`;
                kdl += "            vec4 open_color(vec3 coords_geo, vec3 size_geo) {\n";
                kdl += "                float progress = niri_clamped_progress;\n";
                kdl += "                vec2 uv = coords_geo.xy;\n";
                kdl += "                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);\n";
                kdl += "                vec2 center = vec2(0.5, 0.5);\n";
                kdl += "                vec2 delta = uv - center;\n";
                kdl += "                float dist = length(delta);\n";
                kdl += "                float angle = atan(delta.y, delta.x);\n";
                kdl += "                float inv = 1.0 - progress;\n";
                kdl += "                float max_rot = 6.28318 * TWIST;\n";
                kdl += "                float rotation = inv * max_rot * (1.0 - dist * DAMP);\n";
                kdl += "                float pull = mix(0.2, 1.0, progress);\n";
                kdl += "                float new_dist = dist / max(pull, 0.001);\n";
                kdl += "                float new_angle = angle + rotation;\n";
                kdl += "                vec2 new_uv = center + new_dist * vec2(cos(new_angle), sin(new_angle));\n";
                kdl += "                if (new_uv.x < 0.0 || new_uv.x > 1.0 || new_uv.y < 0.0 || new_uv.y > 1.0) return vec4(0.0);\n";
                kdl += "                vec3 coords_tex = niri_geo_to_tex * vec3(new_uv, 1.0);\n";
                kdl += "                vec4 color = texture2D(niri_tex, coords_tex.st);\n";
                kdl += "                float fade = smoothstep(0.0, 0.5, progress);\n";
                kdl += "                return color * fade;\n";
                kdl += "            }\n";
                kdl += "        \"\n";
                kdl += "    }\n";
                kdl += "    window-close {\n";
                kdl += `        duration-ms ${duration}\n`;
                kdl += "        curve \"linear\"\n";
                kdl += "        custom-shader r\"\n";
                kdl += `            const vec3 THEME_COL = ${themeCol};\n`;
                kdl += `            const vec3 THEME_ACC = ${themeTertiary};\n`;
                kdl += `            const float TWIST = ${twist};\n`;
                kdl += `            const float DAMP = ${damp};\n`;
                kdl += "            vec4 close_color(vec3 coords_geo, vec3 size_geo) {\n";
                kdl += "                float progress = niri_clamped_progress;\n";
                kdl += "                vec2 uv = coords_geo.xy;\n";
                kdl += "                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);\n";
                kdl += "                vec2 center = vec2(0.5, 0.5);\n";
                kdl += "                vec2 delta = uv - center;\n";
                kdl += "                float dist = length(delta);\n";
                kdl += "                float angle = atan(delta.y, delta.x);\n";
                kdl += "                float max_rot = 6.28318 * TWIST;\n";
                kdl += "                float rotation = progress * max_rot * (1.0 - dist * DAMP);\n";
                kdl += "                float pull = 1.0 - progress * 0.8;\n";
                kdl += "                float new_dist = dist * pull;\n";
                kdl += "                float new_angle = angle + rotation;\n";
                kdl += "                vec2 new_uv = center + new_dist * vec2(cos(new_angle), sin(new_angle));\n";
                kdl += "                if (new_uv.x < 0.0 || new_uv.x > 1.0 || new_uv.y < 0.0 || new_uv.y > 1.0) return vec4(0.0);\n";
                kdl += "                vec3 coords_tex = niri_geo_to_tex * vec3(new_uv, 1.0);\n";
                kdl += "                vec4 color = texture2D(niri_tex, coords_tex.st);\n";
                kdl += "                float fade = 1.0 - smoothstep(0.1, 0.9, progress);\n";
                kdl += "                float dissolve = smoothstep(1.0 - progress * 1.1, 0.0, dist);\n";
                if (root.animThemeTint) {
                    kdl += "                vec3 tint = mix(color.rgb, THEME_ACC, progress * 0.25);\n";
                    kdl += "                return vec4(tint * color.a * fade * dissolve, color.a * fade * dissolve);\n";
                } else {
                    kdl += "                return color * fade * dissolve;\n";
                }
                kdl += "            }\n";
                kdl += "        \"\n";
                kdl += "    }\n";
                kdl += "}\n\n";
            } else {
                const animFile = `${root.shadersDir}/close/close-${root.windowAnimPreset}.kdl`;
                kdl += `include "${animFile}"\n\n`;
            }
        }

        // 4. Global / Screen / Cursor Shader
        if (root.globalShaderEnabled && root.globalShaderPreset !== "none") {
            kdl += "// ---------------- Global / Screen / Cursor Shader ----------------\n";
            if (root.cursorPresets.includes(root.globalShaderPreset)) {
                const shaderFile = `${root.shadersDir}/cursor/${root.globalShaderPreset}.kdl`;
                kdl += `include "${shaderFile}"\n\n`;
            } else if (root.globalShaderPreset === "crt") {
                const scanDens = root.scanlineDensity.toFixed(2);
                const scanDark = root.scanlineDarkness.toFixed(2);
                const aber = root.chromaticAberration.toFixed(4);
                kdl += "global-shader {\n";
                kdl += "    enable\n";
                kdl += "    source r\"\n";
                kdl += `        const float SCAN_DENS = ${scanDens};\n`;
                kdl += `        const float SCAN_DARK = ${scanDark};\n`;
                kdl += `        const float ABER = ${aber};\n`;
                kdl += "        vec4 global_color(vec3 c) {\n";
                kdl += "            vec2 uv = c.xy;\n";
                kdl += "            vec3 s;\n";
                kdl += "            if (ABER > 0.0001) {\n";
                kdl += "                float r = tex2D_screen(uv + vec2(ABER, 0.0)).r;\n";
                kdl += "                float g = tex2D_screen(uv).g;\n";
                kdl += "                float b = tex2D_screen(uv - vec2(ABER, 0.0)).b;\n";
                kdl += "                s = vec3(r, g, b);\n";
                kdl += "            } else {\n";
                kdl += "                s = tex2D_screen(uv).rgb;\n";
                kdl += "            }\n";
                kdl += "            float scan = 1.0 - SCAN_DARK * (0.5 + 0.5 * sin(uv.y * niri_size.y * 3.14159 * SCAN_DENS));\n";
                kdl += "            return vec4(s * scan, 1.0);\n";
                kdl += "        }\n";
                kdl += "    \"\n";
                kdl += "}\n\n";
            } else if (root.globalShaderPreset === "vignette") {
                const vig = root.vignetteStrength.toFixed(2);
                kdl += "global-shader {\n";
                kdl += "    enable\n";
                kdl += "    source r\"\n";
                kdl += `        const float VIG_STRENGTH = ${vig};\n`;
                kdl += "        vec4 global_color(vec3 c) {\n";
                kdl += "            vec3 s = tex2D_screen(c.xy).rgb;\n";
                kdl += "            float v = smoothstep(0.85, 0.35, length(c.xy - 0.5) * VIG_STRENGTH);\n";
                kdl += "            return vec4(s * mix(1.0 - VIG_STRENGTH * 0.5, 1.0, v), 1.0);\n";
                kdl += "        }\n";
                kdl += "    \"\n";
                kdl += "}\n\n";
            } else if (root.screenPresets.includes(root.globalShaderPreset)) {
                const shaderFile = `${root.shadersDir}/screen/${root.globalShaderPreset}.kdl`;
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
        root.pulseSpeed = 1.2;

        root.windowAnimEnabled = false;
        root.windowAnimPreset = "whirlpool";
        root.windowAnimDuration = 400;
        root.whirlpoolTwist = 1.5;
        root.animScaleDamping = 0.5;
        root.animThemeTint = true;

        root.globalShaderEnabled = false;
        root.globalShaderPreset = "locator";
        root.vignetteStrength = 0.65;
        root.scanlineDensity = 1.0;
        root.scanlineDarkness = 0.15;
        root.chromaticAberration = 0.0;

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
    onPulseSpeedChanged: {
        if (root.loaded) {
            updatePulseShader();
            requestSave();
        }
    }

    onPulseMatchThemeChanged: {
        if (root.loaded) {
            updatePulseShader();
            requestSave();
        }
    }
    onPulseColorModeChanged: {
        if (root.loaded) {
            updatePulseShader();
            requestSave();
        }
    }
    onCurrentThemePrimaryChanged: {
        if (root.loaded) updatePulseShader();
    }
    onCurrentThemeSecondaryChanged: {
        if (root.loaded) updatePulseShader();
    }
    onCurrentThemeTertiaryChanged: {
        if (root.loaded) updatePulseShader();
    }

    onWindowAnimEnabledChanged: requestSave()
    onWindowAnimPresetChanged: requestSave()
    onWindowAnimDurationChanged: requestSave()
    onWhirlpoolTwistChanged: requestSave()
    onAnimScaleDampingChanged: requestSave()
    onAnimThemeTintChanged: requestSave()

    onGlobalShaderEnabledChanged: requestSave()
    onGlobalShaderPresetChanged: requestSave()
    onVignetteStrengthChanged: requestSave()
    onScanlineDensityChanged: requestSave()
    onScanlineDarknessChanged: requestSave()
    onChromaticAberrationChanged: requestSave()

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
            initTimer.stop();
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
                        if (data.pulseSpeed !== undefined) root.pulseSpeed = data.pulseSpeed;

                        if (data.windowAnimEnabled !== undefined) root.windowAnimEnabled = data.windowAnimEnabled;
                        if (data.windowAnimPreset !== undefined) root.windowAnimPreset = data.windowAnimPreset;
                        if (data.windowAnimDuration !== undefined) root.windowAnimDuration = data.windowAnimDuration;
                        if (data.whirlpoolTwist !== undefined) root.whirlpoolTwist = data.whirlpoolTwist;
                        if (data.animScaleDamping !== undefined) root.animScaleDamping = data.animScaleDamping;
                        if (data.animThemeTint !== undefined) root.animThemeTint = data.animThemeTint;

                        if (data.globalShaderEnabled !== undefined) root.globalShaderEnabled = data.globalShaderEnabled;
                        if (data.globalShaderPreset !== undefined) root.globalShaderPreset = data.globalShaderPreset;
                        if (data.vignetteStrength !== undefined) root.vignetteStrength = data.vignetteStrength;
                        if (data.scanlineDensity !== undefined) root.scanlineDensity = data.scanlineDensity;
                        if (data.scanlineDarkness !== undefined) root.scanlineDarkness = data.scanlineDarkness;
                        if (data.chromaticAberration !== undefined) root.chromaticAberration = data.chromaticAberration;

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
            initTimer.stop();
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
}

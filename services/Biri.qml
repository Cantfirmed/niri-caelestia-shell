pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Internal
import qs.utils

Singleton {
    id: root

    readonly property string biriConfigPath: `${Paths.home}/.config/niri/niri/biri.kdl`
    readonly property string statePath: `${Paths.home}/.local/state/caelestia/biri_settings.json`

    property bool loaded: false

    // ---------------- 1. Floating PiP Videos (float-above-fullscreen & sticky) ----------------
    property bool pipFloatingEnabled: true
    property bool pipFloatAboveFullscreen: true
    property bool pipSticky: true
    property real pipWidthProportion: 0.30
    property real pipHeightProportion: 0.35
    property string pipCustomAppRegex: ""

    // ---------------- 2. Portrait / Vertical Scrolling ----------------
    property bool portraitVerticalLayoutEnabled: false
    property string portraitOutput: "DP-2"
    property real verticalRowProportion: 0.50

    // ---------------- 3. Isolated / Presentation Display ----------------
    property bool isolatedOutputEnabled: false
    property string isolatedOutputName: "HDMI-A-1"

    // ---------------- 4. Dynamic Overview Zoom ----------------
    property bool dynamicOverviewZoomEnabled: false
    property string overviewZoomPresets: "0.5 0.25 0.1"

    // ---------------- 5. Capture & Privacy ----------------
    property bool shadersInCapture: false

    // ---------------- 6. Screen Edge Gaps (Struts) ----------------
    property bool screenGapsLinked: true
    property int screenGapLinkedValue: 0
    property int screenGapTop: 0
    property int screenGapBottom: 0
    property int screenGapLeft: 0
    property int screenGapRight: 0

    onPipFloatingEnabledChanged: requestSave()
    onPipFloatAboveFullscreenChanged: requestSave()
    onPipStickyChanged: requestSave()
    onPipWidthProportionChanged: requestSave()
    onPipHeightProportionChanged: requestSave()
    onPipCustomAppRegexChanged: requestSave()

    onPortraitVerticalLayoutEnabledChanged: requestSave()
    onPortraitOutputChanged: requestSave()
    onVerticalRowProportionChanged: requestSave()

    onIsolatedOutputEnabledChanged: requestSave()
    onIsolatedOutputNameChanged: requestSave()

    onDynamicOverviewZoomEnabledChanged: requestSave()
    onOverviewZoomPresetsChanged: requestSave()

    onShadersInCaptureChanged: requestSave()

    onScreenGapsLinkedChanged: requestSave()
    onScreenGapLinkedValueChanged: requestSave()
    onScreenGapTopChanged: requestSave()
    onScreenGapBottomChanged: requestSave()
    onScreenGapLeftChanged: requestSave()
    onScreenGapRightChanged: requestSave()

    property string lastSavedState: ""
    property string lastSavedKdl: ""

    function setScreenGapsLinked(linked: bool): void {
        if (screenGapsLinked === linked)
            return;
        screenGapsLinked = linked;
        if (linked) {
            const newVal = screenGapTop > 0 ? screenGapTop : Math.max(screenGapBottom, screenGapLeft, screenGapRight);
            screenGapLinkedValue = newVal;
            screenGapTop = newVal;
            screenGapBottom = newVal;
            screenGapLeft = newVal;
            screenGapRight = newVal;
        }
        requestSave();
    }

    function setLinkedScreenGap(val: int): void {
        val = Math.max(0, val);
        if (screenGapLinkedValue === val && screenGapTop === val && screenGapBottom === val && screenGapLeft === val && screenGapRight === val)
            return;
        screenGapLinkedValue = val;
        screenGapTop = val;
        screenGapBottom = val;
        screenGapLeft = val;
        screenGapRight = val;
        requestSave();
    }

    function requestSave(): void {
        if (!root.loaded)
            return;
        saveDebounceTimer.restart();
    }

    function init(): void {
        console.log("[Biri] Initializing service...");
        if (!root.loaded)
            initTimer.start();
    }

    function toggleTouchpad(): void {
        Quickshell.execDetached(["niri", "msg", "action", "toggle-touchpad"]);
    }

    function toggleDwt(): void {
        Quickshell.execDetached(["niri", "msg", "action", "toggle-dwt"]);
    }

    function saveImmediately(): void {
        if (!root.loaded)
            return;

        const stateObj = {
            pipFloatingEnabled: root.pipFloatingEnabled,
            pipFloatAboveFullscreen: root.pipFloatAboveFullscreen,
            pipSticky: root.pipSticky,
            pipWidthProportion: root.pipWidthProportion,
            pipHeightProportion: root.pipHeightProportion,
            pipCustomAppRegex: root.pipCustomAppRegex,

            portraitVerticalLayoutEnabled: root.portraitVerticalLayoutEnabled,
            portraitOutput: root.portraitOutput,
            verticalRowProportion: root.verticalRowProportion,

            isolatedOutputEnabled: root.isolatedOutputEnabled,
            isolatedOutputName: root.isolatedOutputName,

            dynamicOverviewZoomEnabled: root.dynamicOverviewZoomEnabled,
            overviewZoomPresets: root.overviewZoomPresets,

            shadersInCapture: root.shadersInCapture,

            screenGapsLinked: root.screenGapsLinked,
            screenGapLinkedValue: root.screenGapLinkedValue,
            screenGapTop: root.screenGapTop,
            screenGapBottom: root.screenGapBottom,
            screenGapLeft: root.screenGapLeft,
            screenGapRight: root.screenGapRight
        };

        const jsonStr = JSON.stringify(stateObj, null, 2);
        const kdl = generateKdl();

        if (jsonStr === root.lastSavedState && kdl === root.lastSavedKdl)
            return;

        if (jsonStr !== root.lastSavedState) {
            root.lastSavedState = jsonStr;
            stateWriter.setText(jsonStr);
        }

        if (kdl !== root.lastSavedKdl) {
            root.lastSavedKdl = kdl;
            biriKdlWriter.setText(kdl);
            reloadNiriConfig();
        }
    }

    function reloadNiriConfig(): void {
        Quickshell.execDetached(["niri", "msg", "action", "load-config-file"]);
    }

    function generateKdl(): string {
        let kdl = "// ============================================================================\n";
        kdl += "// BIRI COMPOSITOR CONFIGURATION\n";
        kdl += "// Generated automatically by Caelestia Nexus Settings. Edits may be overwritten.\n";
        kdl += "// ============================================================================\n\n";

        // 1. Shaders in capture
        if (root.shadersInCapture) {
            kdl += "// ---------------- Screencast & Capture ----------------\n";
            kdl += "shaders-in-capture\n\n";
        }

        // 2. Dynamic Overview Zoom
        if (root.dynamicOverviewZoomEnabled && root.overviewZoomPresets.trim().length > 0) {
            kdl += "// ---------------- Dynamic Overview Zoom ----------------\n";
            kdl += "overview {\n";
            kdl += `    zoom-presets ${root.overviewZoomPresets.trim()}\n`;
            kdl += "}\n\n";
            kdl += "binds {\n";
            kdl += "    Mod+WheelScrollDown { overview-zoom-out; }\n";
            kdl += "    Mod+WheelScrollUp { overview-zoom-in; }\n";
            kdl += "}\n\n";
        }

        // 3. Isolated display
        if (root.isolatedOutputEnabled && root.isolatedOutputName.trim().length > 0) {
            kdl += "// ---------------- Isolated / Presentation Display ----------------\n";
            kdl += `output "${root.isolatedOutputName.trim()}" {\n`;
            kdl += "    isolated\n";
            kdl += "}\n\n";
        }

        // 4. Vertical scrolling for portrait output
        if (root.portraitVerticalLayoutEnabled && root.portraitOutput.trim().length > 0) {
            const prop = root.verticalRowProportion.toFixed(2);
            kdl += "// ---------------- Vertical Scrolling for Portrait Output ----------------\n";
            kdl += `output "${root.portraitOutput.trim()}" {\n`;
            kdl += "    layout {\n";
            kdl += '        main-axis "vertical"\n';
            kdl += `        default-column-width { proportion ${prop}; }\n`;
            kdl += "    }\n";
            kdl += "}\n\n";
        }

        // 5. Floating PiP Video rules (float-above-fullscreen & sticky)
        if (root.pipFloatingEnabled) {
            const wProp = root.pipWidthProportion.toFixed(2);
            const hProp = root.pipHeightProportion.toFixed(2);
            kdl += "// ---------------- Floating PiP Video Rules ----------------\n";
            kdl += "window-rule {\n";
            kdl += '    match app-id=r#"(?i)(firefox|chrom(e|ium)|brave|zen|vivaldi|edge|opera|librewolf|waterfox|mpv)"# title=r#"(?i)(Picture-in-Picture|PiP)"#\n';
            kdl += "    open-floating true\n";
            if (root.pipSticky) {
                kdl += "    open-sticky true\n";
            }
            if (root.pipFloatAboveFullscreen) {
                kdl += "    float-above-fullscreen true\n";
            }
            kdl += `    default-column-width { proportion ${wProp}; }\n`;
            kdl += `    default-window-height { proportion ${hProp}; }\n`;
            kdl += "}\n\n";

            if (root.pipCustomAppRegex.trim().length > 0) {
                kdl += "window-rule {\n";
                kdl += `    match app-id=r#"${root.pipCustomAppRegex.trim()}"#\n`;
                kdl += "    open-floating true\n";
                if (root.pipSticky) {
                    kdl += "    open-sticky true\n";
                }
                if (root.pipFloatAboveFullscreen) {
                    kdl += "    float-above-fullscreen true\n";
                }
                kdl += "}\n\n";
            }
        }

        // 6. Screen Edge Gaps (Struts)
        kdl += "// ---------------- Screen Edge Gaps (Struts) ----------------\n";
        kdl += "layout {\n";
        kdl += "    struts {\n";
        kdl += `        top ${root.screenGapTop}\n`;
        kdl += `        bottom ${root.screenGapBottom}\n`;
        kdl += `        left ${root.screenGapLeft}\n`;
        kdl += `        right ${root.screenGapRight}\n`;
        kdl += "    }\n";
        kdl += "}\n\n";

        return kdl;
    }

    Timer {
        id: saveDebounceTimer

        interval: 400
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
        watchChanges: false
        printErrors: false
        onLoaded: {
            const raw = text();
            if (raw && raw.trim().length > 0) {
                try {
                    const data = JSON.parse(raw);
                    if (data) {
                        if (data.pipFloatingEnabled !== undefined) root.pipFloatingEnabled = data.pipFloatingEnabled;
                        if (data.pipFloatAboveFullscreen !== undefined) root.pipFloatAboveFullscreen = data.pipFloatAboveFullscreen;
                        if (data.pipSticky !== undefined) root.pipSticky = data.pipSticky;
                        if (data.pipWidthProportion !== undefined) root.pipWidthProportion = data.pipWidthProportion;
                        if (data.pipHeightProportion !== undefined) root.pipHeightProportion = data.pipHeightProportion;
                        if (data.pipCustomAppRegex !== undefined) root.pipCustomAppRegex = data.pipCustomAppRegex;

                        if (data.portraitVerticalLayoutEnabled !== undefined) root.portraitVerticalLayoutEnabled = data.portraitVerticalLayoutEnabled;
                        if (data.portraitOutput !== undefined) root.portraitOutput = data.portraitOutput;
                        if (data.verticalRowProportion !== undefined) root.verticalRowProportion = data.verticalRowProportion;

                        if (data.isolatedOutputEnabled !== undefined) root.isolatedOutputEnabled = data.isolatedOutputEnabled;
                        if (data.isolatedOutputName !== undefined) root.isolatedOutputName = data.isolatedOutputName;

                        if (data.dynamicOverviewZoomEnabled !== undefined) root.dynamicOverviewZoomEnabled = data.dynamicOverviewZoomEnabled;
                        if (data.overviewZoomPresets !== undefined) root.overviewZoomPresets = data.overviewZoomPresets;

                        if (data.shadersInCapture !== undefined) root.shadersInCapture = data.shadersInCapture;

                        if (data.screenGapsLinked !== undefined) root.screenGapsLinked = data.screenGapsLinked;
                        if (data.screenGapLinkedValue !== undefined) root.screenGapLinkedValue = data.screenGapLinkedValue;
                        if (data.screenGapTop !== undefined) root.screenGapTop = data.screenGapTop;
                        if (data.screenGapBottom !== undefined) root.screenGapBottom = data.screenGapBottom;
                        if (data.screenGapLeft !== undefined) root.screenGapLeft = data.screenGapLeft;
                        if (data.screenGapRight !== undefined) root.screenGapRight = data.screenGapRight;
                    }
                } catch (e) {
                    console.warn("[Biri] Failed to parse state file:", e);
                }
                root.loaded = true;
                root.lastSavedState = JSON.stringify(data || {}, null, 2);
                root.lastSavedKdl = root.generateKdl();
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
        id: biriKdlWriter

        path: root.biriConfigPath
        printErrors: true
    }

    FileView {
        id: stateWriter

        path: root.statePath
        printErrors: true
    }
}

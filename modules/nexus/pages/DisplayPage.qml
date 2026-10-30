pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Internal
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Displays")

    property var outputsArray: []
    property var localOutputs: []
    property bool enableSnapping: true
    property bool isDragging: false
    property real frozenScale: 0.1
    property real frozenBoxCenterX: 0
    property real frozenBoxCenterY: 0
    property real snapGuideX: NaN
    property real snapGuideY: NaN

    readonly property var scalePresets: [1.0, 1.25, 1.33, 1.5, 1.75, 2.0]
    readonly property var rotationOptions: [
        { value: "normal", label: "0°", icon: "crop_landscape" },
        { value: "90", label: "90°", icon: "crop_portrait" },
        { value: "180", label: "180°", icon: "screen_rotation_alt" },
        { value: "270", label: "270°", icon: "stay_current_portrait" }
    ]

    function normalizeTransform(raw): string {
        if (!raw)
            return "normal";
        const key = String(raw).trim().toLowerCase();
        const map = {
            "normal": "normal",
            "0": "normal",
            "90": "90",
            "_90": "90",
            "180": "180",
            "_180": "180",
            "270": "270",
            "_270": "270",
            "flipped": "flipped",
            "flipped90": "flipped-90",
            "flipped-90": "flipped-90",
            "flipped_90": "flipped-90",
            "flipped180": "flipped-180",
            "flipped-180": "flipped-180",
            "flipped_180": "flipped-180",
            "flipped270": "flipped-270",
            "flipped-270": "flipped-270",
            "flipped_270": "flipped-270"
        };
        return map[key] ?? "normal";
    }

    function baseRotation(transform: string): string {
        const norm = normalizeTransform(transform);
        if (norm === "flipped")
            return "normal";
        if (norm.startsWith("flipped-"))
            return norm.slice("flipped-".length);
        return norm;
    }

    function isTransformFlipped(transform: string): bool {
        return normalizeTransform(transform).startsWith("flipped");
    }

    function composeTransform(rot: string, flipped: bool): string {
        if (!flipped)
            return rot;
        return rot === "normal" ? "flipped" : ("flipped-" + rot);
    }

    readonly property int activeOutputCount: {
        let count = 0;
        for (let i = 0; i < outputsArray.length; i++) {
            if (outputsArray[i].active)
                count++;
        }
        return count;
    }

    readonly property real currentScale: {
        if (isDragging)
            return frozenScale;

        let minX = 999999;
        let maxX = -999999;
        let minY = 999999;
        let maxY = -999999;
        let activeCount = 0;

        for (let i = 0; i < localOutputs.length; i++) {
            const out = localOutputs[i];
            if (!out.active)
                continue;
            activeCount++;
            if (out.x < minX)
                minX = out.x;
            if (out.x + out.logicalWidth > maxX)
                maxX = out.x + out.logicalWidth;
            if (out.y < minY)
                minY = out.y;
            if (out.y + out.logicalHeight > maxY)
                maxY = out.y + out.logicalHeight;
        }

        if (activeCount === 0)
            return 0.1;

        const totalWidth = Math.max(1, maxX - minX);
        const totalHeight = Math.max(1, maxY - minY);

        const padding = 30;
        const canvasWidth = displayCanvas.width > 0 ? displayCanvas.width - 2 * padding : 200;
        const canvasHeight = displayCanvas.height > 0 ? displayCanvas.height - 2 * padding : 150;

        const scaleX = canvasWidth / totalWidth;
        const scaleY = canvasHeight / totalHeight;

        const s = Math.min(scaleX, scaleY);
        return (s <= 0 || isNaN(s)) ? 0.1 : s;
    }

    readonly property real currentBoxCenterX: {
        if (isDragging)
            return frozenBoxCenterX;

        let minX = 999999;
        let maxX = -999999;
        let activeCount = 0;

        for (let i = 0; i < localOutputs.length; i++) {
            const out = localOutputs[i];
            if (!out.active)
                continue;
            activeCount++;
            if (out.x < minX)
                minX = out.x;
            if (out.x + out.logicalWidth > maxX)
                maxX = out.x + out.logicalWidth;
        }

        if (activeCount === 0)
            return 0;
        return minX + (maxX - minX) / 2;
    }

    readonly property real currentBoxCenterY: {
        if (isDragging)
            return frozenBoxCenterY;

        let minY = 999999;
        let maxY = -999999;
        let activeCount = 0;

        for (let i = 0; i < localOutputs.length; i++) {
            const out = localOutputs[i];
            if (!out.active)
                continue;
            activeCount++;
            if (out.y < minY)
                minY = out.y;
            if (out.y + out.logicalHeight > maxY)
                maxY = out.y + out.logicalHeight;
        }

        if (activeCount === 0)
            return 0;
        return minY + (maxY - minY) / 2;
    }

    readonly property bool hasUnappliedChanges: {
        if (localOutputs.length !== outputsArray.length)
            return false;
        for (let i = 0; i < localOutputs.length; i++) {
            const loc = localOutputs[i];
            const act = outputsArray.find(o => o.connector === loc.connector);
            if (!act)
                continue;
            if (loc.active && act.active) {
                if (Math.round(loc.x) !== Math.round(act.x) || Math.round(loc.y) !== Math.round(act.y))
                    return true;
            }
        }
        return false;
    }

    function initializeLocalOutputs(): void {
        const temp = [];
        for (let i = 0; i < root.outputsArray.length; i++) {
            const out = root.outputsArray[i];
            temp.push({
                connector: out.connector,
                name: out.name,
                logicalWidth: out.logicalWidth,
                logicalHeight: out.logicalHeight,
                x: out.x,
                y: out.y,
                scale: out.scale,
                transform: out.transform,
                vrrEnabled: out.vrrEnabled,
                active: out.active
            });
        }
        root.localOutputs = temp;
    }

    function freezeMapping(): void {
        if (!isDragging) {
            let minX = 999999;
            let maxX = -999999;
            let minY = 999999;
            let maxY = -999999;
            let activeCount = 0;

            for (let i = 0; i < localOutputs.length; i++) {
                const out = localOutputs[i];
                if (!out.active)
                    continue;
                activeCount++;
                if (out.x < minX)
                    minX = out.x;
                if (out.x + out.logicalWidth > maxX)
                    maxX = out.x + out.logicalWidth;
                if (out.y < minY)
                    minY = out.y;
                if (out.y + out.logicalHeight > maxY)
                    maxY = out.y + out.logicalHeight;
            }

            if (activeCount === 0)
                return;

            const totalWidth = Math.max(1, maxX - minX);
            const totalHeight = Math.max(1, maxY - minY);

            const padding = 30;
            const canvasWidth = displayCanvas.width > 0 ? displayCanvas.width - 2 * padding : 200;
            const canvasHeight = displayCanvas.height > 0 ? displayCanvas.height - 2 * padding : 150;

            const scaleX = canvasWidth / totalWidth;
            const scaleY = canvasHeight / totalHeight;

            frozenScale = Math.min(scaleX, scaleY);
            if (frozenScale <= 0 || isNaN(frozenScale))
                frozenScale = 0.1;

            frozenBoxCenterX = minX + totalWidth / 2;
            frozenBoxCenterY = minY + totalHeight / 2;
            isDragging = true;
        }
    }

    function unfreezeMapping(): void {
        isDragging = false;
        snapGuideX = NaN;
        snapGuideY = NaN;
    }

    function updateLocalPosition(idx: int, newX: real, newY: real): void {
        const arr = [];
        for (let i = 0; i < root.localOutputs.length; i++) {
            const item = root.localOutputs[i];
            if (i === idx) {
                arr.push({
                    connector: item.connector,
                    name: item.name,
                    logicalWidth: item.logicalWidth,
                    logicalHeight: item.logicalHeight,
                    x: Math.round(newX),
                    y: Math.round(newY),
                    scale: item.scale,
                    transform: item.transform,
                    vrrEnabled: item.vrrEnabled,
                    active: item.active
                });
            } else {
                arr.push(item);
            }
        }
        root.localOutputs = arr;
    }

    function snapPosition(dragIndex: int, proposedX: real, proposedY: real): var {
        const snapThreshold = 100; // logical pixels
        const A = root.localOutputs[dragIndex];
        let bestX = proposedX;
        let bestY = proposedY;
        let guideX = NaN;
        let guideY = NaN;

        for (let i = 0; i < root.localOutputs.length; i++) {
            if (i === dragIndex)
                continue;
            const B = root.localOutputs[i];
            if (!B.active)
                continue;

            const distLeft = Math.abs((proposedX + A.logicalWidth) - B.x);
            const distRight = Math.abs(proposedX - (B.x + B.logicalWidth));

            if (distLeft < snapThreshold) {
                bestX = B.x - A.logicalWidth;
                guideX = B.x;
                if (Math.abs(proposedY - B.y) < snapThreshold) {
                    bestY = B.y;
                    guideY = B.y;
                } else if (Math.abs((proposedY + A.logicalHeight) - (B.y + B.logicalHeight)) < snapThreshold) {
                    bestY = B.y + B.logicalHeight - A.logicalHeight;
                    guideY = B.y + B.logicalHeight;
                } else if (Math.abs((proposedY + A.logicalHeight / 2) - (B.y + B.logicalHeight / 2)) < snapThreshold) {
                    bestY = B.y + (B.logicalHeight - A.logicalHeight) / 2;
                    guideY = B.y + B.logicalHeight / 2;
                }
            } else if (distRight < snapThreshold) {
                bestX = B.x + B.logicalWidth;
                guideX = B.x + B.logicalWidth;
                if (Math.abs(proposedY - B.y) < snapThreshold) {
                    bestY = B.y;
                    guideY = B.y;
                } else if (Math.abs((proposedY + A.logicalHeight) - (B.y + B.logicalHeight)) < snapThreshold) {
                    bestY = B.y + B.logicalHeight - A.logicalHeight;
                    guideY = B.y + B.logicalHeight;
                } else if (Math.abs((proposedY + A.logicalHeight / 2) - (B.y + B.logicalHeight / 2)) < snapThreshold) {
                    bestY = B.y + (B.logicalHeight - A.logicalHeight) / 2;
                    guideY = B.y + B.logicalHeight / 2;
                }
            }

            const distTop = Math.abs((proposedY + A.logicalHeight) - B.y);
            const distBottom = Math.abs(proposedY - (B.y + B.logicalHeight));

            if (distTop < snapThreshold) {
                bestY = B.y - A.logicalHeight;
                guideY = B.y;
                if (Math.abs(proposedX - B.x) < snapThreshold) {
                    bestX = B.x;
                    guideX = B.x;
                } else if (Math.abs((proposedX + A.logicalWidth) - (B.x + B.logicalWidth)) < snapThreshold) {
                    bestX = B.x + B.logicalWidth - A.logicalWidth;
                    guideX = B.x + B.logicalWidth;
                } else if (Math.abs((proposedX + A.logicalWidth / 2) - (B.x + B.logicalWidth / 2)) < snapThreshold) {
                    bestX = B.x + (B.logicalWidth - A.logicalWidth) / 2;
                    guideX = B.x + B.logicalWidth / 2;
                }
            } else if (distBottom < snapThreshold) {
                bestY = B.y + B.logicalHeight;
                guideY = B.y + B.logicalHeight;
                if (Math.abs(proposedX - B.x) < snapThreshold) {
                    bestX = B.x;
                    guideX = B.x;
                } else if (Math.abs((proposedX + A.logicalWidth) - (B.x + B.logicalWidth)) < snapThreshold) {
                    bestX = B.x + B.logicalWidth - A.logicalWidth;
                    guideX = B.x + B.logicalWidth;
                } else if (Math.abs((proposedX + A.logicalWidth / 2) - (B.x + B.logicalWidth / 2)) < snapThreshold) {
                    bestX = B.x + (B.logicalWidth - A.logicalWidth) / 2;
                    guideX = B.x + B.logicalWidth / 2;
                }
            }
        }

        return { x: bestX, y: bestY, guideX: guideX, guideY: guideY };
    }

    // ── 15-second Safety Confirmation / Auto-Revert Modal State ──
    property bool confirmPending: false
    property int confirmRemaining: 15
    property string confirmSummary: ""
    property var revertSnapshot: []

    function captureSnapshot(): var {
        const snap = [];
        for (let i = 0; i < root.outputsArray.length; i++) {
            const o = root.outputsArray[i];
            snap.push({
                connector: o.connector,
                active: o.active,
                x: o.x,
                y: o.y,
                scale: o.scale,
                transform: o.transform,
                vrrEnabled: o.vrrEnabled,
                modeStr: (o.width > 0 && o.height > 0 && o.refresh_rate > 0)
                    ? (o.width + "x" + o.height + "@" + o.refresh_rate.toFixed(3))
                    : ""
            });
        }
        return snap;
    }

    function beginDisplayConfirm(summaryText: string): void {
        if (!root.confirmPending)
            root.revertSnapshot = root.captureSnapshot();
        root.confirmSummary = summaryText;
        root.confirmRemaining = 15;
        root.confirmPending = true;
        confirmCountdownTimer.restart();
    }

    function acceptDisplayChanges(): void {
        root.confirmPending = false;
        confirmCountdownTimer.stop();
        root.revertSnapshot = [];
    }

    function revertDisplayChanges(): void {
        const snap = root.revertSnapshot;
        root.confirmPending = false;
        confirmCountdownTimer.stop();
        root.revertSnapshot = [];

        for (let i = 0; i < snap.length; i++) {
            const s = snap[i];
            if (!s.active) {
                root.execNiriOutput([s.connector, "off"]);
                continue;
            }
            root.execNiriOutput([s.connector, "on"]);
            if (s.modeStr)
                root.execNiriOutput([s.connector, "mode", s.modeStr]);
            root.execNiriOutput([s.connector, "scale", String(s.scale)]);
            root.execNiriOutput([s.connector, "transform", s.transform]);
            root.execNiriOutput([s.connector, "position", "set", String(s.x), String(s.y)]);
            root.execNiriOutput([s.connector, "vrr", s.vrrEnabled ? "on" : "off"]);
        }
        refreshTimer.count = 0;
        refreshTimer.restart();
    }

    function execNiriOutput(argsList: var): void {
        const fullArgs = ["niri", "msg", "output"].concat(argsList);
        Quickshell.execDetached(fullArgs);
        refreshTimer.count = 0;
        refreshTimer.restart();
    }

    function applyPositions(): void {
        root.beginDisplayConfirm(Tr.tr("Updated multi-monitor arrangement"));
        for (let i = 0; i < localOutputs.length; i++) {
            const out = localOutputs[i];
            if (!out.active)
                continue;
            root.execNiriOutput([out.connector, "position", "set", String(out.x), String(out.y)]);
        }
    }

    function applyScale(connector: string, newScale: real): void {
        root.beginDisplayConfirm(Tr.tr("%1 scale → %2x").arg(connector).arg(newScale.toFixed(2)));
        root.execNiriOutput([connector, "scale", String(newScale)]);
    }

    function applyMode(connector: string, width: int, height: int, refreshHz: real): void {
        const modeStr = width + "x" + height + "@" + refreshHz.toFixed(3);
        root.beginDisplayConfirm(Tr.tr("%1 mode → %2×%3 @ %4 Hz").arg(connector).arg(width).arg(height).arg(refreshHz.toFixed(2)));
        root.execNiriOutput([connector, "mode", modeStr]);
    }

    function applyTransform(connector: string, transformVal: string): void {
        const norm = root.normalizeTransform(transformVal);
        root.beginDisplayConfirm(Tr.tr("%1 rotation → %2").arg(connector).arg(norm));
        root.execNiriOutput([connector, "transform", norm]);
    }

    function applyVrr(connector: string, enabled: bool): void {
        root.execNiriOutput([connector, "vrr", enabled ? "on" : "off"]);
    }

    function applyOutputEnabled(connector: string, enabled: bool): void {
        if (!enabled && root.activeOutputCount <= 1)
            return; // Never allow disabling the sole active display
        root.beginDisplayConfirm(Tr.tr("%1 %2").arg(connector).arg(enabled ? Tr.tr("enabled") : Tr.tr("disabled")));
        root.execNiriOutput([connector, enabled ? "on" : "off"]);
    }

    function saveDefaults(): void {
        const bulkList = [];
        for (let i = 0; i < root.localOutputs.length; i++) {
            const out = root.localOutputs[i];
            const actOut = root.outputsArray.find(o => o.connector === out.connector);
            const activeState = actOut ? actOut.active : out.active;
            let modeStr = null;
            if (actOut && actOut.width > 0 && actOut.height > 0 && actOut.refresh_rate > 0)
                modeStr = actOut.width + "x" + actOut.height + "@" + actOut.refresh_rate.toFixed(3);

            bulkList.push({
                connector: out.connector,
                active: activeState,
                off: !activeState,
                x: out.x,
                y: out.y,
                scale: actOut ? actOut.scale : out.scale,
                mode: modeStr,
                transform: actOut ? actOut.transform : out.transform,
                vrr: actOut ? actOut.vrrEnabled : out.vrrEnabled
            });
        }
        const scriptPath = Quickshell.shellPath("scripts/update_display.py");
        Quickshell.execDetached(["python3", scriptPath, "--bulk", JSON.stringify(bulkList)]);
        saveFeedbackTimer.restart();
        root.savedRecently = true;
    }

    property bool savedRecently: false

    function updateOutputs(): void {
        const res = [];
        const outputs = Niri.outputs;
        if (!outputs) {
            root.outputsArray = res;
            root.initializeLocalOutputs();
            return;
        }

        const keys = Object.keys(outputs).sort();
        for (let k = 0; k < keys.length; k++) {
            const connector = keys[k];
            const out = outputs[connector];
            const currentModeIdx = out.current_mode;
            const currentMode = out.modes && out.modes[currentModeIdx] ? out.modes[currentModeIdx] : null;

            const processedModes = [];
            const resMap = {};
            const resolutions = [];

            if (out.modes) {
                for (let i = 0; i < out.modes.length; i++) {
                    const m = out.modes[i];
                    const hz = m.refresh_rate / 1000.0;
                    const entry = {
                        width: m.width,
                        height: m.height,
                        refresh_rate: hz,
                        is_preferred: !!m.is_preferred,
                        is_current: i === currentModeIdx
                    };
                    processedModes.push(entry);

                    const resKey = m.width + "x" + m.height;
                    if (!resMap[resKey]) {
                        resMap[resKey] = {
                            key: resKey,
                            width: m.width,
                            height: m.height,
                            is_preferred: !!m.is_preferred,
                            is_current: i === currentModeIdx,
                            rates: []
                        };
                        resolutions.push(resMap[resKey]);
                    } else {
                        if (m.is_preferred)
                            resMap[resKey].is_preferred = true;
                        if (i === currentModeIdx)
                            resMap[resKey].is_current = true;
                    }
                    resMap[resKey].rates.push(entry);
                }
            }

            const item = {
                connector: connector,
                name: ((out.make || "") + " " + (out.model || "")).trim() || connector,
                width: currentMode ? currentMode.width : 0,
                height: currentMode ? currentMode.height : 0,
                refresh_rate: currentMode ? currentMode.refresh_rate / 1000.0 : 0,
                x: out.logical ? out.logical.x : 0,
                y: out.logical ? out.logical.y : 0,
                scale: out.logical ? out.logical.scale : 1.0,
                transform: root.normalizeTransform(out.logical ? out.logical.transform : "normal"),
                vrrSupported: !!out.vrr_supported,
                vrrEnabled: !!out.vrr_enabled,
                logicalWidth: out.logical ? out.logical.width : (currentMode ? currentMode.width : 1920),
                logicalHeight: out.logical ? out.logical.height : (currentMode ? currentMode.height : 1080),
                modes: processedModes,
                resolutions: resolutions,
                active: out.logical !== null && out.logical !== undefined
            };
            res.push(item);
        }

        root.outputsArray = res;
        if (root.selectedIndex >= res.length)
            root.selectedIndex = Math.max(0, res.length - 1);
        if (!root.isDragging)
            root.initializeLocalOutputs();
    }

    Component.onCompleted: updateOutputs()

    property int selectedIndex: 0
    readonly property var selectedOutput: outputsArray.length > selectedIndex ? outputsArray[selectedIndex] : null
    readonly property var selectedResolutionGroup: {
        if (!selectedOutput || !selectedOutput.resolutions)
            return null;
        for (let i = 0; i < selectedOutput.resolutions.length; i++) {
            if (selectedOutput.resolutions[i].is_current)
                return selectedOutput.resolutions[i];
        }
        return selectedOutput.resolutions.length > 0 ? selectedOutput.resolutions[0] : null;
    }

    ColumnLayout {
        id: mainLayout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // ── Empty State ──
        StyledRect {
            visible: root.outputsArray.length === 0
            Layout.fillWidth: true
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large
            implicitHeight: 200

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "desktop_access_disabled"
                    font: Tokens.font.icon.large
                    color: Colours.palette.m3outline
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    text: Tr.tr("No displays detected")
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3outline
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    text: Tr.tr("Niri Available: %1").arg(Niri.niriAvailable)
                    font: Tokens.font.body.small
                    color: Colours.palette.m3outlineVariant
                    Layout.alignment: Qt.AlignHCenter
                }
                TextButton {
                    text: Tr.tr("Retry Fetch")
                    Layout.alignment: Qt.AlignHCenter
                    type: TextButton.Tonal
                    onClicked: {
                        NiriIpc.fetchOutputs();
                        root.updateOutputs();
                    }
                }
            }
        }

        // ── Section 1: Arrangement & Positioning ──
        SectionHeader {
            first: true
            visible: root.outputsArray.length > 0
            text: Tr.tr("Arrangement & Positioning")
        }

        StyledRect {
            visible: root.outputsArray.length > 0
            Layout.fillWidth: true
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                StyledText {
                    text: Tr.tr("Drag displays to arrange virtual layout with magnetic edge snapping")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }

                Item {
                    id: displayCanvas
                    Layout.fillWidth: true
                    height: 240
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        color: Colours.layer(Colours.palette.m3surface, 1)
                        radius: Tokens.rounding.medium
                        border.color: Colours.palette.m3outlineVariant
                        border.width: 1
                    }

                    // Vertical magnetic snap guide line
                    Rectangle {
                        visible: root.isDragging && !isNaN(root.snapGuideX)
                        x: displayCanvas.width / 2 + (root.snapGuideX - root.currentBoxCenterX) * root.currentScale
                        y: 4
                        width: 1
                        height: parent.height - 8
                        color: Colours.palette.m3tertiary
                        opacity: 0.85
                    }

                    // Horizontal magnetic snap guide line
                    Rectangle {
                        visible: root.isDragging && !isNaN(root.snapGuideY)
                        x: 4
                        y: displayCanvas.height / 2 + (root.snapGuideY - root.currentBoxCenterY) * root.currentScale
                        width: parent.width - 8
                        height: 1
                        color: Colours.palette.m3tertiary
                        opacity: 0.85
                    }

                    Repeater {
                        id: canvasRepeater
                        model: root.localOutputs

                        delegate: Rectangle {
                            id: screenItem
                            required property var modelData
                            required property int index

                            visible: modelData.active

                            x: displayCanvas.width / 2 + (modelData.x - root.currentBoxCenterX) * root.currentScale
                            y: displayCanvas.height / 2 + (modelData.y - root.currentBoxCenterY) * root.currentScale
                            width: Math.max(24, modelData.logicalWidth * root.currentScale)
                            height: Math.max(18, modelData.logicalHeight * root.currentScale)

                            radius: Tokens.rounding.small
                            border.width: root.selectedIndex === index ? 2 : 1
                            border.color: root.selectedIndex === index ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                            color: root.selectedIndex === index ? Colours.layer(Colours.palette.m3primaryContainer, 1) : Colours.layer(Colours.palette.m3surfaceContainer, 3)

                            Behavior on x { enabled: !root.isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            Behavior on y { enabled: !root.isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            Behavior on width { enabled: !root.isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            Behavior on height { enabled: !root.isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                            clip: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                spacing: 2
                                visible: parent.width >= 50 && parent.height >= 35

                                StyledText {
                                    text: modelData.connector + (modelData.transform !== "normal" ? " (" + modelData.transform + ")" : "")
                                    font.weight: 600
                                    font.pointSize: 9.5
                                    color: root.selectedIndex === index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    Layout.alignment: Qt.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: modelData.logicalWidth + "×" + modelData.logicalHeight + " (" + modelData.scale.toFixed(2) + "x)"
                                    font.pointSize: 8
                                    color: root.selectedIndex === index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline
                                    Layout.alignment: Qt.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: "X: " + modelData.x + " Y: " + modelData.y
                                    font.pointSize: 7.5
                                    color: root.selectedIndex === index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline
                                    Layout.alignment: Qt.AlignHCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: dragIndex >= 0 ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        property int dragIndex: -1
                        property real dragStartX: 0
                        property real dragStartY: 0
                        property real dragStartLogicalX: 0
                        property real dragStartLogicalY: 0

                        function hitTest(mx: real, my: real): int {
                            for (let i = canvasRepeater.count - 1; i >= 0; i--) {
                                const item = canvasRepeater.itemAt(i);
                                if (!item || !item.visible || !item.modelData.active)
                                    continue;
                                if (mx >= item.x && mx <= item.x + item.width &&
                                    my >= item.y && my <= item.y + item.height) {
                                    return i;
                                }
                            }
                            return -1;
                        }

                        onPressed: (mouse) => {
                            const idx = hitTest(mouse.x, mouse.y);
                            if (idx < 0)
                                return;

                            dragIndex = idx;
                            root.selectedIndex = idx;

                            const out = root.localOutputs[idx];
                            dragStartX = mouse.x;
                            dragStartY = mouse.y;
                            dragStartLogicalX = out.x;
                            dragStartLogicalY = out.y;

                            root.freezeMapping();
                        }

                        onPositionChanged: (mouse) => {
                            if (dragIndex < 0)
                                return;

                            const dx = mouse.x - dragStartX;
                            const dy = mouse.y - dragStartY;
                            const dxLogical = dx / root.currentScale;
                            const dyLogical = dy / root.currentScale;

                            let newX = Math.round(dragStartLogicalX + dxLogical);
                            let newY = Math.round(dragStartLogicalY + dyLogical);

                            if (root.enableSnapping) {
                                const snapped = root.snapPosition(dragIndex, newX, newY);
                                newX = Math.round(snapped.x);
                                newY = Math.round(snapped.y);
                                root.snapGuideX = snapped.guideX;
                                root.snapGuideY = snapped.guideY;
                            } else {
                                root.snapGuideX = NaN;
                                root.snapGuideY = NaN;
                            }

                            root.updateLocalPosition(dragIndex, newX, newY);
                        }

                        onReleased: {
                            dragIndex = -1;
                            root.unfreezeMapping();
                        }
                    }
                }

                ToggleRow {
                    text: Tr.tr("Magnetic monitor snapping")
                    subtext: Tr.tr("Snap adjacent edges and centers while dragging displays")
                    checked: root.enableSnapping
                    onToggled: checked => root.enableSnapping = checked
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: root.hasUnappliedChanges ? Tr.tr("Unapplied position changes") : Tr.tr("Arrangement synchronized")
                        font: Tokens.font.body.small
                        color: root.hasUnappliedChanges ? Colours.palette.m3tertiary : Colours.palette.m3outline
                        Layout.fillWidth: true
                    }

                    TextButton {
                        text: Tr.tr("Reset Layout")
                        type: TextButton.Tonal
                        stateLayer.disabled: !root.hasUnappliedChanges
                        opacity: root.hasUnappliedChanges ? 1.0 : 0.5
                        onClicked: {
                            if (root.hasUnappliedChanges)
                                root.initializeLocalOutputs();
                        }
                    }

                    TextButton {
                        text: Tr.tr("Apply Layout")
                        type: TextButton.Filled
                        stateLayer.disabled: !root.hasUnappliedChanges
                        opacity: root.hasUnappliedChanges ? 1.0 : 0.5
                        onClicked: {
                            if (root.hasUnappliedChanges)
                                root.applyPositions();
                        }
                    }
                }
            }
        }

        // ── Section 2: Connected Displays Picker ──
        SectionHeader {
            visible: root.outputsArray.length > 0
            text: Tr.tr("Connected Displays")
        }

        RowLayout {
            visible: root.outputsArray.length > 0
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.outputsArray

                delegate: StyledRect {
                    id: outputChip
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    radius: Tokens.rounding.medium
                    color: root.selectedIndex === index
                        ? Colours.layer(Colours.palette.m3secondaryContainer, 2)
                        : Colours.tPalette.m3surfaceContainer

                    border.width: root.selectedIndex === index ? 2 : 1
                    border.color: root.selectedIndex === index
                        ? Colours.palette.m3primary
                        : Colours.palette.m3outlineVariant

                    StateLayer {
                        function onClicked(): void {
                            root.selectedIndex = index;
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: modelData.connector.startsWith("eDP") ? "laptop_chromebook" : "monitor"
                            font: Tokens.font.icon.medium
                            color: modelData.active ? Colours.palette.m3primary : Colours.palette.m3outline
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.extraSmall

                                StyledText {
                                    text: modelData.connector
                                    font: root.selectedIndex === index ? Tokens.font.title.small : Tokens.font.body.medium
                                }

                                StyledRect {
                                    visible: !modelData.active
                                    radius: Tokens.rounding.small
                                    color: Colours.palette.m3surfaceContainerHighest
                                    implicitWidth: offBadge.implicitWidth + 8
                                    implicitHeight: offBadge.implicitHeight + 2

                                    StyledText {
                                        id: offBadge
                                        anchors.centerIn: parent
                                        text: Tr.tr("OFF")
                                        font: Tokens.font.label.small
                                        color: Colours.palette.m3outline
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                font: Tokens.font.body.small
                                color: Colours.palette.m3outline
                                elide: Text.ElideRight
                            }
                        }
                    }
                    implicitHeight: 64
                }
            }
        }

        // ── Section 3: Display Power Toggle ──
        SectionHeader {
            visible: root.selectedOutput !== null
            text: Tr.tr("Display Settings — %1").arg(root.selectedOutput ? root.selectedOutput.connector : "")
        }

        StyledRect {
            visible: root.selectedOutput !== null
            Layout.fillWidth: true
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                ToggleRow {
                    first: true
                    last: true
                    visible: root.outputsArray.length > 1
                    text: Tr.tr("Enable display output")
                    subtext: root.selectedOutput && root.selectedOutput.active
                        ? Tr.tr("Currently active (%1)").arg(root.selectedOutput.connector)
                        : Tr.tr("Currently turned off")
                    checked: root.selectedOutput ? root.selectedOutput.active : false
                    enabled: root.selectedOutput ? (!root.selectedOutput.active || root.activeOutputCount > 1) : false
                    onToggled: checked => {
                        if (root.selectedOutput)
                            root.applyOutputEnabled(root.selectedOutput.connector, checked);
                    }
                }
            }
        }

        // ── Section 4: Scaling & Rotation ──
        SectionHeader {
            visible: root.selectedOutput !== null
            text: Tr.tr("Scaling & Rotation")
        }

        StyledRect {
            visible: root.selectedOutput !== null
            Layout.fillWidth: true
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Tr.tr("Fractional Scale")
                        font: Tokens.font.body.medium
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: root.selectedOutput ? (root.selectedOutput.scale.toFixed(2) + "x") : ""
                        font: Tokens.font.title.small
                        color: Colours.palette.m3primary
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.scalePresets

                        delegate: TextButton {
                            required property real modelData
                            Layout.fillWidth: true
                            text: modelData + "x"
                            isToggle: false
                            readonly property bool isCurrentScale: root.selectedOutput ? Math.abs(root.selectedOutput.scale - modelData) < 0.02 : false
                            type: isCurrentScale ? TextButton.Filled : TextButton.Tonal
                            onClicked: {
                                if (root.selectedOutput)
                                    root.applyScale(root.selectedOutput.connector, modelData);
                            }
                        }
                    }

                    StyledInputField {
                        id: scaleInput
                        placeholderText: Tr.tr("Custom")
                        horizontalAlignment: TextInput.AlignHCenter
                        Layout.preferredWidth: 78
                        Layout.fillHeight: true

                        onEditingFinished: {
                            const val = parseFloat(text);
                            if (!isNaN(val) && val >= 0.25 && val <= 4.0 && root.selectedOutput) {
                                root.applyScale(root.selectedOutput.connector, val);
                                text = "";
                            }
                        }
                    }
                }

                Rectangle { height: 1; color: Colours.palette.m3outlineVariant; Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Tr.tr("Orientation & Transform")
                        font: Tokens.font.body.medium
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: root.selectedOutput ? root.selectedOutput.transform : ""
                        font: Tokens.font.title.small
                        color: Colours.palette.m3primary
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: root.rotationOptions

                        delegate: IconTextButton {
                            required property var modelData
                            Layout.fillWidth: true
                            icon: modelData.icon
                            text: modelData.label
                            readonly property string currentBase: root.selectedOutput ? root.baseRotation(root.selectedOutput.transform) : "normal"
                            readonly property bool isCurrentRot: currentBase === modelData.value
                            type: isCurrentRot ? TextButton.Filled : TextButton.Tonal
                            onClicked: {
                                if (root.selectedOutput) {
                                    const flipped = root.isTransformFlipped(root.selectedOutput.transform);
                                    const nextTransform = root.composeTransform(modelData.value, flipped);
                                    root.applyTransform(root.selectedOutput.connector, nextTransform);
                                }
                            }
                        }
                    }
                }

                ToggleRow {
                    last: true
                    text: Tr.tr("Flip horizontal (mirrored)")
                    subtext: Tr.tr("Invert display orientation horizontally")
                    checked: root.selectedOutput ? root.isTransformFlipped(root.selectedOutput.transform) : false
                    onToggled: checked => {
                        if (root.selectedOutput) {
                            const baseRot = root.baseRotation(root.selectedOutput.transform);
                            const nextTransform = root.composeTransform(baseRot, checked);
                            root.applyTransform(root.selectedOutput.connector, nextTransform);
                        }
                    }
                }
            }
        }

        // ── Section 5: Resolution, Refresh Rate & VRR ──
        SectionHeader {
            visible: root.selectedOutput !== null
            text: Tr.tr("Resolution, Refresh Rate & VRR")
        }

        StyledRect {
            visible: root.selectedOutput !== null
            Layout.fillWidth: true
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                ToggleRow {
                    first: true
                    text: Tr.tr("Variable Refresh Rate (Adaptive Sync / VRR)")
                    subtext: root.selectedOutput && !root.selectedOutput.vrrSupported
                        ? Tr.tr("Unsupported by this display")
                        : Tr.tr("Eliminates screen tearing and reduces stuttering")
                    checked: root.selectedOutput ? root.selectedOutput.vrrEnabled : false
                    enabled: root.selectedOutput ? root.selectedOutput.vrrSupported : false
                    opacity: enabled ? 1.0 : 0.6
                    onToggled: checked => {
                        if (root.selectedOutput && root.selectedOutput.vrrSupported)
                            root.applyVrr(root.selectedOutput.connector, checked);
                    }
                }

                Rectangle { height: 1; color: Colours.palette.m3outlineVariant; Layout.fillWidth: true }

                StyledText {
                    text: Tr.tr("Refresh Rate (%1)").arg(
                        root.selectedResolutionGroup ? (root.selectedResolutionGroup.width + "×" + root.selectedResolutionGroup.height) : ""
                    )
                    font: Tokens.font.title.small
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.selectedResolutionGroup ? root.selectedResolutionGroup.rates : []

                        delegate: TextButton {
                            required property var modelData
                            text: modelData.refresh_rate.toFixed(2) + " Hz"
                            isToggle: false
                            type: modelData.is_current ? TextButton.Filled : TextButton.Tonal
                            onClicked: {
                                if (root.selectedOutput)
                                    root.applyMode(root.selectedOutput.connector, modelData.width, modelData.height, modelData.refresh_rate);
                            }
                        }
                    }
                }

                Rectangle { height: 1; color: Colours.palette.m3outlineVariant; Layout.fillWidth: true }

                StyledText {
                    text: Tr.tr("Resolution")
                    font: Tokens.font.title.small
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.selectedOutput ? root.selectedOutput.resolutions : []

                        delegate: StyledRect {
                            id: resCard
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: Tokens.rounding.small
                            color: modelData.is_current
                                ? Colours.palette.m3primaryContainer
                                : (root.selectedResolutionGroup && root.selectedResolutionGroup.key === modelData.key
                                    ? Colours.palette.m3surfaceContainerHighest
                                    : "transparent")

                            StateLayer {
                                function onClicked(): void {
                                    if (modelData.rates && modelData.rates.length > 0 && root.selectedOutput) {
                                        const bestRate = modelData.rates[0];
                                        root.applyMode(root.selectedOutput.connector, bestRate.width, bestRate.height, bestRate.refresh_rate);
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.padding.medium
                                spacing: Tokens.spacing.medium

                                StyledText {
                                    text: modelData.width + " × " + modelData.height
                                    font: modelData.is_current ? Tokens.font.title.small : Tokens.font.body.medium
                                    color: modelData.is_current ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                }

                                StyledText {
                                    text: {
                                        const r = modelData.width / modelData.height;
                                        if (Math.abs(r - 16/9) < 0.05) return "16:9";
                                        if (Math.abs(r - 16/10) < 0.05) return "16:10";
                                        if (Math.abs(r - 4/3) < 0.05) return "4:3";
                                        if (Math.abs(r - 21/9) < 0.05) return "21:9";
                                        return "";
                                    }
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.body.small
                                }

                                Item { Layout.fillWidth: true }

                                MaterialIcon {
                                    visible: modelData.is_preferred
                                    text: "star"
                                    font: Tokens.font.icon.small
                                    color: modelData.is_current ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Section 6: Persist Configuration ──
        RowLayout {
            visible: root.outputsArray.length > 0
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            Layout.bottomMargin: Tokens.spacing.extraLarge

            TextButton {
                Layout.fillWidth: true
                type: TextButton.Filled
                text: root.savedRecently
                    ? Tr.tr("Saved to ~/.config/niri/niri/output.kdl ✓")
                    : Tr.tr("Save Display Configuration as Default")
                onClicked: root.saveDefaults()
            }
        }
    }

    data: [
        Timer {
            id: confirmCountdownTimer
            interval: 1000
            repeat: true
            onTriggered: {
                root.confirmRemaining--;
                if (root.confirmRemaining <= 0) {
                    root.revertDisplayChanges();
                }
            }
        },

        Timer {
            id: saveFeedbackTimer
            interval: 2500
            repeat: false
            onTriggered: root.savedRecently = false
        },

        Connections {
            target: Niri
            function onOutputsChanged(): void {
                root.updateOutputs();
            }
        },

        Timer {
            id: refreshTimer
            interval: 350
            repeat: true
            property int count: 0
            onTriggered: {
                NiriIpc.fetchOutputs();
                count++;
                if (count >= 5) {
                    running = false;
                    count = 0;
                }
            }
        },

        // ── 15-Second Safety Confirmation Modal Overlay ──
        Rectangle {
            id: confirmModalBackdrop
            anchors.fill: root
            z: 9999
            color: Qt.rgba(0, 0, 0, 0.55)
            opacity: root.confirmPending ? 1.0 : 0.0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.confirmPending
                hoverEnabled: true
                onClicked: {} // Block clicks from leaking behind modal
            }

            StyledRect {
                id: confirmDialogCard
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 460)
                height: dialogCol.implicitHeight + Tokens.padding.extraLarge * 2
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainerHigh
                border.width: 1
                border.color: Colours.palette.m3outlineVariant

                ColumnLayout {
                    id: dialogCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: "settings_backup_restore"
                            font: Tokens.font.icon.large
                            color: Colours.palette.m3primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: Tr.tr("Keep these display settings?")
                                font: Tokens.font.title.medium
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                visible: root.confirmSummary !== ""
                                text: root.confirmSummary
                                font: Tokens.font.body.small
                                color: Colours.palette.m3primary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Tr.tr("Applying new display configuration. Click Confirm to keep, reverting in %1 seconds...").arg(root.confirmRemaining)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                    }

                    // Countdown progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Colours.palette.m3surfaceContainerHighest

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.confirmRemaining / 15.0))
                            height: parent.height
                            radius: 3
                            color: root.confirmRemaining <= 5 ? Colours.palette.m3error : Colours.palette.m3primary

                            Behavior on width {
                                NumberAnimation { duration: 900; easing.type: Easing.Linear }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        Item { Layout.fillWidth: true }

                        TextButton {
                            text: Tr.tr("Revert Now")
                            type: TextButton.Tonal
                            onClicked: root.revertDisplayChanges()
                        }

                        TextButton {
                            text: Tr.tr("Confirm (%1s)").arg(root.confirmRemaining)
                            type: TextButton.Filled
                            onClicked: root.acceptDisplayChanges()
                        }
                    }
                }
            }
        }
    ]
}
